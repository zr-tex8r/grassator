--
-- bushfire.lua
-- Module 'bushfire' : interpreter for the Grass language
--
-- Author: Takayuki YATO (aka 'ZR')
-- Last modified: 2012/05/06

local M = {}
local sys, sys_proto
local gio_std, mower
local make_char, char_w, succ, out, in_, make_term

---------------------------------------- module main

local function map(fun, array)
  local res = {}
  for i = 1, #array do
    res[i] = fun(array[i])
  end
  return res
end

local function positive(o)
  return type(o) == "number" and o > 0
end

local function log_na() end
local function log_(format, ...)
  local arg = map(tostring, { ... })
  local s = string.format("planter>> "..format .. "\n", unpack(arg))
  io.stderr:write(s)
end

local log, debug_used
local function use_debug(value)
  debug_used = value and true
  log = debug_used and log_ or log_na
end

local stat_used
local function use_stat(value)
  local p = sys_proto
  stat_used = value and true
  p._set_level = value and p._set_level_ or p._set_level_na
end

local function use_quick(value)
  local p = sys_proto
  p._enter_local = value and p._enter_local_q or
    p._enter_local_nq
end

local proc_from_source = {}

local function register_from_source(lang, proc)
  proc_from_source[lang] = proc
end

local function parse(lang, source)
  local proc = proc_from_source[lang]
  if proc == nil then
    error("unknown language '"..lang.."'")
  end
  return proc(source)
end

local function parse_grass(source)
  return M.mower.parse(source)
end
register_from_source('grass', parse_grass)

local function run_array(list)
  local sys = sys.new(list)
  local ret = sys:run()
  sys:show_stat()
  return ret
end

local function run(lang, source)
  return run_array(parse(lang, source))
end

local function run_grass(source)
  return run_array(M.mower.parse(source))
end

---------------------------------------- inner class 'sys'
do
  sys = {}
  local proto = {}; sys_proto = proto
  local meta = {
    __index = proto,
    __tostring = nil
  }

  function sys.new(program)
    local genv = {
      in_, char_w, succ, out,
      level = 0
    }
    local self = setmetatable({
      prog = {}, appl = {}, genv = genv, env = genv,
      stat = { max_level = 0 }
    }, meta)
    self:_gather(program)
    genv.pc = 1; genv.epc = #self.prog
    genv.last = #genv
    return self
  end

  function proto:strvalue(flag)
    local delim = (flag) and "\n" or " | "
    local sb = {}
    table.insert(sb, "PROG=[")
    for i = 1, #self.prog do
      local ent = self.prog[i]
      local t = (not ent.arg) and ("!"..ent.pc) or
          (ent.arg..":"..ent.pc.."/"..ent.epc)
      table.insert(sb, " "..t)
    end
    table.insert(sb, " ]"..delim.."APPL=[")
    for i = 1, #self.appl do
      local ent = self.appl[i]
      table.insert(sb, " "..ent.r.."@"..ent.d)
    end
    table.insert(sb, " ]"..delim.."ENV=[")
    table.insert(sb, self:env_strvalue(self.env))
    table.insert(sb, "]")
    return table.concat(sb, "")
  end
  meta.__tostring = proto.strvalue

  function proto:env_strvalue(env)
    local sb = {}
    table.insert(sb, "lv="..(env.level or "?"))
    table.insert(sb, " pc="..env.pc.."/"..env.epc)
    for i = 1, env.last do
      table.insert(sb, " "..tostring(env[i]))
    end
    return table.concat(sb, "")
  end

  function proto:run()
    local ret = self:_global_run()
    if ret._class == 'char' then
      return string.char(ret:char())
    else
      return true
    end
  end

  function proto:get_stat()
    return stat_used and self.stat or nil
  end

  function proto:show_stat()
    if not stat_used then return end
    local s = self.stat
    local t = "[STAT: max_level="..s.max_level.." ]\n"
    io.stderr:write(t)
  end

  function proto:_global_run()
    local prog, appl, env = self.prog, self.appl, self.env
    while env.pc <= env.epc do
      local ent = prog[env.pc]
      if ent.arg then
        self:_do_abs(ent)
      else
        local app = appl[ent.pc]
        self:_do_app(app.r, app.d)
      end
      log("%s", self)
      env.pc = env.pc + 1
    end
    return env[env.last]
  end

  function proto:_do_abs(ent)
    local env = self.env -- always is genv
    local cenv = {
      pc = ent.pc, epc = ent.epc, arg = ent.arg - 1,
      last = env.last, glast = env.last
    }
    env.last = env.last + 1
    env[env.last] = make_term(cenv)
  end

  function proto:_do_app(rbi, dbi)
    local env = self.env
    local c = env.last + 1
    local oprr, oprd = env[c - rbi], env[c - dbi]
    -- log("##APP:%s:%s", oprr, oprd)
    local ret = oprr:app(oprd, self)
    env.last = env.last + 1
    env[env.last] = ret
  end

  function proto:term_app(cenv, oprd)
    local glast, last = cenv.glast, cenv.last
    local cenv1 = {
      pc = cenv.pc, epc = cenv.epc, arg = cenv.arg - 1,
      glast = glast, last = last + 1
    }
    for i = glast + 1, last do
      cenv1[i] = cenv[i]
    end
    cenv1[cenv1.last] = oprd
    if cenv1.arg < 0 then
      return self:_call(cenv1)
    else
      return make_term(cenv1)
    end
  end

  function proto:_call(lenv)
    log("******** _enter_local: %s", self)
    -- log("##ENV=%s", self:env_strvalue(lenv))
    self:_enter_local(lenv)
    local ret = self:_local_run()
    log("******** _leave_local")
    self:_leave_local()
    return ret
  end

  function proto:_local_run()
    local appl, env = self.appl, self.env
    while env.pc <= env.epc do
      local app = appl[env.pc]
      self:_do_app(app.r, app.d)
      log("%s", self)
      env.pc = env.pc + 1
    end
    return env[env.last]
  end

  function proto:_enter_local_q(lenv)
    local parent = self.env
    lenv.parent = parent
    self:_set_level(lenv)
    self.env = setmetatable(lenv, { __index = self.genv })
  end

  function proto:_enter_local_nq(lenv)
    local parent, genv = self.env, self.genv
    lenv.parent = parent
    self:_set_level(lenv)
    for i = 1, lenv.glast do
      lenv[i] = genv[i]
    end
    self.env = lenv
  end

  function proto:_leave_local()
    local parent = self.env.parent
    if parent == nil then
      error("no local environment to leave")
    end
    self.env = parent
  end

  function proto:_set_level_na(lenv)
  end
  function proto:_set_level_(lenv)
    local s = self.stat
    lenv.level = lenv.parent.level + 1
    s.max_level = math.max(s.max_level, lenv.level)
  end

  function proto:_gather(list)
    local prog, appl = self.prog, self.appl
    if type(list) ~= "table" or #list == 0 then
      error("program is empty or invalid", 0)
    end
    local ok = true
    for i = 1, #list do
      local ent = list[i]
      if not positive(ent[1]) then
        ok = false
      end
      if type(ent[2]) == "table" then
        local arg, chunk = ent[1], ent[2]
        local pc = #appl + 1
        for j = 1, #chunk do
          local ent = chunk[j]
          if not (positive(ent[1]) and positive(ent[2])) then
            ok = false
          end
          table.insert(appl, { r = ent[1], d = ent[2] })
        end
        local epc = #appl
        table.insert(prog, {
          arg = arg, pc = pc, epc = epc
        })
      elseif positive(ent[2]) then
        table.insert(appl, { r = ent[1], d = ent[2] })
        table.insert(prog, { pc = #appl })
      else
        ok = false
      end
    end
    if not ok then
      error("program array contains invalid objects", 0)
    elseif type(list[1][2]) ~= "table" then
      error("program starts with an application", 0)
    end
    appl[0] = { r = 3, d = 2 } -- for true_val
    table.insert(appl, { r = 1, d = 1 }) -- last action
    table.insert(prog, { pc = #appl })   --
  end

end
---------------------------------------- object 'bushfire.gio_std'
do
  gio_std = {}; local p = gio_std
  function p.read()
    return io.read(1)
  end
  function p.write(c)
    return io.write(c)
  end
end
---------------------------------------- values
do
  local true_term, false_term

  local proto = {
    char = function()
      error("not a character")
    end,
    app = function()
      error("app failed")
    end,
    strvalue = function(self)
      return '<'..self._class..'>'
    end
  }
  local meta = {
    __index = proto,
    __tostring = proto.strvalue
  }

  local make_char_proto = {
    _class = 'char',
    char = function(self)
      return self._cp
    end,
    app = function(self, v, sys)
      local b = (self._cp == v._cp)
      return (b) and true_term or false_term
    end,
    strvalue = function(self)
      local cp = self._cp
      if 0x21 <= cp and cp <= 0x7E then
        return '<'..string.char(cp)..'>'
      else
        return ('<%02X>'):format(cp)
      end
    end
  }
  local make_char_meta = {
    __index = make_char_proto,
    __tostring = make_char_proto.strvalue
  }

  function make_char(_cp)
    return setmetatable({
      _cp = _cp
    }, make_char_meta)
  end
  char_w = make_char(string.byte('w'))

  succ = setmetatable({
    _class = 'succ',
    app = function(self, char)
      return make_char((char:char() + 1) % 256)
    end
  }, meta)

  out = setmetatable({
    _class = 'out',
    app = function(self, char)
      M.gio.write(string.char(char:char()))
      return char
    end
  }, meta)

  in_ = setmetatable({
    _class = 'in',
    app = function(self, char)
      local r = M.gio.read()
      return (r) and make_char(r:byte()) or char
    end
  }, meta)

  local make_term_proto = {
    char = proto.char,
    app = function(self, oprd, sys)
      return sys:term_app(self._cenv, oprd)
    end,
    strvalue = function(self)
      local c, e = 'T', self._cenv
      return '<'..c..e.arg..":"..e.pc.."/"..e.epc..
          '{'..e.glast..':'..e.last..'}'..'>'
    end
  }
  local make_term_meta = {
    __index = make_term_proto,
    __tostring = make_term_proto.strvalue
  }

  function make_term(_cenv)
    return setmetatable({
      _class = 'term',
      _cenv = _cenv
    }, make_term_meta)
  end

  false_term = make_term({
    pc = 1, epc = 0, arg = 1, last = 0, glast = 0
  })
  local identity = make_term({
    pc = 1, epc = 0, arg = 0, last = 0, glast = 0
  })
  true_term = make_term({
    pc = 0, epc = 0, arg = 1, last = 1, glast = 0,
    identity
  })

end
---------------------------------------- class 'bushfire.mower'
do
  mower = {}; local p = mower

  function p.parse(source)
    return p.last_pass(p.first_pass(source))
  end

  function p.first_pass(source)
    local text = tostring(source):gsub('\239\189\151', 'w')
      :gsub('\239\188\183', 'W')
      :gsub('\239\189\150', 'v')
      :gsub("[^wWv]", "") ..'$'
    local chunk = {}
    local prev, count = 0, 0
    for i = 1, #text do
      local cur = string.byte(text, i)
      if cur == prev then
        count = count + 1
      else
        local l = string.char(prev)
        if #chunk > 0 or l == 'w' then
          table.insert(chunk, { l = l, c = count })
        end
        prev, count = cur, 1
      end
    end
    table.insert(chunk, { l = 'v', c = 1 })
    return chunk
  end

  local function add_abs(code, abs)
    if abs[1] == 0 then
      for i = 1, #abs[2] do
        table.insert(code, abs[2][i])
      end
    else
      table.insert(code, abs)
    end
  end

  function p.last_pass(chunk)
    local state = 'v'
    local abs, app; local code = {}
    for i = 1, #chunk do
      local sym = chunk[i]
      local pair = state..sym.l
      if pair == 'vw' then
        abs = { sym.c, {} }
      elseif pair == 'vW' then
        abs = { 0, {} }
        app = { sym.c, 0 }
      elseif pair == 'wv' then
        add_abs(code, abs)
      elseif pair == 'wW' then
        app = { sym.c, 0 }
      elseif pair == 'Wv' then
        table.insert(abs[2], app)
        add_abs(code, abs)
      elseif pair == 'Ww' then
        app[2] = sym.c
        table.insert(abs[2], app)
      else
        return nil
      end
      state = sym.l
    end
    return code
  end
end
---------------------------------------- initial settings
use_debug(false)
use_stat(false)
use_quick(true)
---------------------------------------- export
M.use_debug = use_debug
M.use_stat = use_stat
M.use_quick = use_quick
M.register_from_source = register_from_source
M.parse = parse
M.parse_grass = parse_grass
M.run_array = run_array
M.run = run
M.run_grass = run_grass
M.gio_std = gio_std
M.gio = gio_std
M.mower = mower
return M
-- EOF
