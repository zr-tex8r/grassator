--
-- planter.lua
-- Module 'planter' : converter for auxiliary languages for Grass
--
-- Author: Takayuki YATO (aka 'ZR')

local M = {}

local debug_mode = false
local initial_var = { 'In', 'w', 'Succ', 'Out' }

local sys, exphndl, exp_app, term_inter, term_env
local asg_inter, code_app, code_abs, program

---------------------------------------- module main

local function log(format, ...)
  if debug_mode then
    io.stderr:write(string.format("planter>> "..format .. "\n", ...))
  end
end

local function map(fun, array)
  local res = {}
  for i = 1, #array do
    res[i] = fun(array[i])
  end
  return res
end

local function append(array1, array2)
  for i = 1, #array2 do
    table.insert(array1, array2[i])
  end
end

local function xtype(o)
  if type(o) == "table" then
    return o._class_ or "table"
  else
    return type(o)
  end
end

local function compile(desc)
  local lsys = sys.new()
  lsys:stagify(desc)
  desc()
  return lsys:finalize()
end

local function from_array(list)
  local prog = program.from_array(list)
  prog:validate()
  return prog
end

local function from_source(lang, source)
  return program.from_source(lang, source)
end

local function register_from_source(lang, proc)
  program.proc_from_source[lang] = proc
end

local function register_to_source(lang, proc)
  program.proc_to_source[lang] = proc
end

---------------------------------------- class 'exphndl'
do
  exphndl = {}
  local proto = { _class_ = 'exphndl' }

  function exphndl.new(exp)
    local function strvalue()
      return ("<%s>"):format(tostring(exp))
    end
    local obj = setmetatable({
      exp = exp
    }, {
      __index = proto,
      __call = exphndl.call,
      __lt = exphndl.lt,
      __le = exphndl.le,
      __tostring = strvalue
    })
    return obj
  end

  function exphndl.call(v1, v2)
    if xtype(v1) ~= "exphndl" or xtype(v1) ~= "exphndl" then
      error("illegal object in expression")
    end
    return exphndl.new(exp_app.new(v1.exp, v2.exp))
  end

  function exphndl.lt(var, value)
    if xtype(var) ~= "exphndl" or xtype(value) ~= "exphndl" then
      error("illegal object in expression")
    elseif not var:is_atom() then
      error("inter-assignment to non-variable")
    end
    exphndl.interim = asg_inter.new(var.exp, value)
    return true
  end

  function exphndl.le()
    error("unexpected '<=' operator")
  end

  function proto:is_atom()
    return (xtype(self.exp) ~= "exp_app")
  end

end
---------------------------------------- class 'asg_inter'
do
  asg_inter = {}
  function asg_inter.new(var, value)
    local function strvalue()
      return ("%s < %s"):format(tostring(var), tostring(value))
    end
    return setmetatable({
      var = var, value = value, _class_ = 'asg_inter'
    }, { __tostring = strvalue })
  end
end
---------------------------------------- class 'exp_app'
do
  exp_app = {}
  function exp_app.new(first, second)
    local function strvalue()
      return ("%s(%s)"):format(tostring(first), tostring(second))
    end
    return setmetatable({
      first = first, second = second, _class_ = 'exp_app'
    }, { __tostring = strvalue })
  end
end
---------------------------------------- class 'term_inter'
do
  term_inter = {}
  function term_inter.new(index)
    local function strvalue()
      return ("_M[%s]"):format(index)
    end
    return setmetatable({
      index = index, _class_ = 'term_inter'
    }, { __tostring = strvalue })
  end
end
---------------------------------------- class 'term_env'
do
  term_env = {}
  function term_env.new(index)
    local function strvalue()
      return ("_E[%s]"):format(index)
    end
    return setmetatable({
      index = index, _class_ = 'term_env'
    }, { __tostring = strvalue })
  end
end
---------------------------------------- class 'code_app'
do
  code_app = {}
  function code_app.new(first, second)
    local function strvalue()
      return ("App(%s,%s)"):format(first, second)
    end
    return setmetatable({
      first = first, second = second,
      is_abs = false, _class_ = 'code_app'
    }, { __tostring = strvalue })
  end
end
---------------------------------------- class 'code_abs'
do
  code_abs = {}
  function code_abs.new(arity, body)
    local function strvalue()
      local t = table.concat(map(tostring, body), ", ")
      return ("Abs(%s, [%s])"):format(arity, t)
    end
    return setmetatable({
      arity = arity, body = body,
      is_abs = true, _class_ = 'code_abs'
    }, { __tostring = strvalue })
  end

end
---------------------------------------- class 'program'
do
  program = {}
  local proto = {}
  program.proc_from_source = {}
  program.proc_to_source = {}

  function program.new(code)
    local function strvalue()
      return ("Program[len=%s]"):format(#code)
    end
    return setmetatable({
      code = code, _class_ = 'code_abs'
    }, { __index = proto, __tostring = strvalue })
  end

  function proto:log_dump()
    if not debug_mode then return end
    log("generic code start")
    self:dump()
    log("end")
  end

  function proto:dump()
    log("generic code start")
    local t = map(tostring, self.code)
    for i = 1, #self.code do
      io.stderr:write(("%04d: %s\n"):format(i, tostring(self.code[i])))
    end
    log("end")
  end

  function proto:validate()
    if type(self.code) ~= "table" then
      error("program has no code table", 0)
    elseif #self.code == 0 then
      error("program is empty", 0)
    end
    for i = 1, #self.code do
      local code = self.code[i]
      local type1 = xtype(code)
      if type1 == "code_abs" and
          (type(code.arity) == "number" and code.arity > 0) and
          (type(code.body) == "table") then
        ok = true
      elseif type1 == "code_app" and
          (type(code.first) == "number" and code.first > 0) and
          (type(code.second) == "number" and code.second > 0) then
        ok = true
      end
      if not ok then
        error("program has illegal objects", 0)
      end
    end
    if not self.code[1].is_abs then
      error("program starts with an application", 0)
    end
    log("validate ok")
  end

  function proto:to_source(lang)
    if lang == "grass" then
      return self:grass_source()
    end
    local proc = program.proc_to_source[lang]
    if proc == nil then
      error("unknown language '"..lang.."'", 2)
    end
    self:validate()
    local source = proc(self)
    if source == nil then
      error("failure in source generation", 2)
    end
    return source
  end

  function program.from_source(lang, source)
    if lang == "seed" then
      local desc = assert(loadstring(source))
      return compile(desc)
    end
    local proc = program.proc_from_source[lang]
    if proc == nil then
      error("unknown language '"..lang.."'", 2)
    end
    local array = proc(source)
    if type(array) ~= "table" then
      error("failure in compilation", 2)
    end
    local prog = program.from_array(array)
    prog:validate()
    return prog
  end

  function proto:grass_source()
    local chunk = {}
    local prev_app = false
    for i = 1, #self.code do
      local code = self.code[i]
      if code.is_abs then
        if #chunk > 0 then
          table.insert(chunk, "v")
        end
        table.insert(chunk, string.rep("w", code.arity))
        for i = 1, #code.body do
          local app = code.body[i]
          table.insert(chunk, string.rep("W", app.first))
          table.insert(chunk, string.rep("w", app.second))
        end
        prev_app = false
      else
        if not prev_app then
          table.insert(chunk, "v")
        end
        table.insert(chunk, string.rep("W", code.first))
        table.insert(chunk, string.rep("w", code.second))
        prev_app = true
      end
    end
    return table.concat(chunk)
  end

  function program.from_array(list)
    if type(list) ~= "table" then
      return program.new(nil)
    end
    local prog = {}
    for i = 1, #list do
      local elem = list[i]
      if type(elem) ~= "table" or #elem ~= 2 then
        return program.new(nil)
      end
      local second = elem[2]
      if type(second) == "table" then
        local body = {}
        for i = 1, #second do
          table.insert(body, code_app.new(second[i][1], second[i][2]))
        end
        table.insert(prog, code_abs.new(elem[1], body))
      else
        table.insert(prog, code_app.new(elem[1], elem[2]))
      end
    end
    return program.new(prog)
  end

end
---------------------------------------- class 'sys'
do
  sys = {}
  local proto = { _class_ = 'sys' }
  local ARG, INTER, FIN = 0, 1, 2

  function sys.new()
    local obj = setmetatable({
      env = {},
      code = {},
      stage = {}
    }, { __index = proto })
    obj.access = obj:_the_accessor()
    obj.getinter = obj:_the_getinter()
    obj.getenv = obj:the_getenv()
    obj.last = #initial_var
    for i = 1, obj.last do
      obj.env[initial_var[i]] = i
    end
    obj:_reset_stmt()
    return obj
  end

  function proto:_the_accessor()
    return setmetatable({}, {
      __index = function(_, index)
        self:_refer(index)
        return self.access
      end,
      __call = function(_, arg)
        return self:_call(arg)
      end
    })
  end

  function proto:_the_getinter()
    return setmetatable({}, {
      __index = function(_, index)
        if type(index) ~= "number" or index < 1 then
          error("bad index for _M[]", 2)
        end
        return exphndl.new(term_inter.new(index))
      end
    })
  end

  function proto:the_getenv()
    return setmetatable({}, {
      __index = function(_, index)
        if type(index) ~= "number" or index < 1 then
          error("bad index for _E[]", 2)
        end
        return exphndl.new(term_env.new(index))
      end
    })
  end

  function proto:stagify(fun)
    if self.orig_fenv ~= nil then
      error("stagify already called", 2)
    end
    local stg_meta = {
      __index = function (_, index)
        return exphndl.new(index)
      end,
      __newindex = function (_, index, value)
        self:_assign(index, value)
      end
    }
    local stg_fenv = {
      _ = self.access,
      _M = self.getinter,
      _E = self.getenv
    }
    setmetatable(stg_fenv, stg_meta)
    self.stage_fun = fun
    self.orig_fenv = getfenv(fun)
    setfenv(fun, stg_fenv)
  end

  function proto:finalize()
    local prog = program.new(self.code)
    prog:log_dump()
    self:_unstagify()
    prog:validate()
    return prog
  end

  function proto:_unstagify()
    if self.stage_fun == nil then
      error("stagify not yet called", 2)
    end
    setfenv(self.stage_fun, self.orig_fenv)
  end

  function proto:_reset_stmt()
    self.lenv = setmetatable({}, { __index = self.env })
    self.llast = self.last
    self.arg = {}
    self.interim = {}
    self.chunk = {}
    self.lcode = {}
    self.phase = FIN
  end

  function proto:_refer(value)
    if xtype(value) == "string" then -- variable ".x"
      if value == "_class_" then
        error("misplaced '_' symbol in statement", 0)
      end
      if self.phase == INTER then
        error("premature statement found", 3);
      end
      self:_new_arg(value)
    elseif xtype(value) == "exphndl" then -- interim "[f(x)]"
      if self.phase == ARG then 
        self:_end_arg()
      elseif self.phase == FIN then
        error("statement has no argument", 3)
      end
      self:_new_interim(value)
    elseif xtype(value) == "boolean" and value == true
        and exphndl.interim ~= nil then -- interim "[y < f(x)]"
      value = exphndl.interim
      if self.phase == ARG then 
        self:_end_arg()
      elseif self.phase == FIN then
        error("statement has no argument", 3)
      end
      self:_new_interim(value.value, value.var)
    else
      error("bad value in []", 3)
    end
    exphndl.interim = nil
  end

  function proto:_call(value)
    if value == nil then
      value = exphndl.new()
    end
    if xtype(value) == "exphndl" then -- final "(f(x))"
      if self.phase == ARG then
        self:_end_arg()
      end
      if self.phase == FIN then
        return self:_immediate(value)
      elseif value.exp == nil then
        return self:_body_empty(value)
      else
        return self:_body(value)
      end
    else
      error("bad value in ()", 3)
    end
    exphndl.interim = nil
  end

  function proto:_new_arg(var)
    log("new_arg(%s)", var)
    if rawget(self.lenv, var) ~= nil then
      error("argument '"..var.."' duplicated", 4);
    end
    self.lenv[var] = -1;
    table.insert(self.arg, var)
    self.phase = ARG
  end

  function proto:_end_arg()
    log("end_arg")
    local arg, lenv = self.arg, self.lenv
    for i = 1, #arg do
      self.llast = self.llast + 1
      self.lenv[arg[i]] = self.llast
      log("%s <- %s", arg[i], self.llast)
    end
  end

  function proto:_new_interim(x, var)
    log("new_interim(%s, %s)", tostring(x), var or "*")
    self:_flatten(x)
    append(self.lcode, self.chunk)
    local list = map(tostring, self.chunk)
    log("interim -> %s", table.concat(list, ","))
    if var ~= nil then
      self.lenv[var] = self.llast
      log("%s <- %s", var, self.llast)
    end
    table.insert(self.interim, self.llast)
    log("_M[%s] <- %s", #self.interim, self.llast)
    self.phase = INTER
  end

  function proto:_body_empty(x)
    log("body()", tostring(x))
    local cod = code_abs.new(#self.arg, self.lcode)
    log("statement -> %s", tostring(cod))
    table.insert(self.code, cod)
    self.last = self.last + 1
    log("last -> %s", self.last)
    self:_reset_stmt()
    return self.last
  end

  function proto:_body(x)
    log("body(%s)", tostring(x))
    self:_flatten(x)
    append(self.lcode, self.chunk)
    local cod = code_abs.new(#self.arg, self.lcode)
    log("statement -> %s", tostring(cod))
    table.insert(self.code, cod)
    self.last = self.last + 1
    log("last -> %s", self.last)
    self:_reset_stmt()
    return self.last
  end

  function proto:_immediate(x)
    log("immediate(%s)", tostring(x))
    self:_flatten(x)
    local list = map(tostring, self.chunk)
    log("statement -> %s", table.concat(list, ","))
    append(self.code, self.chunk)
    self.last = self.llast
    log("last -> %s", self.last)
    self:_reset_stmt()
    return self.last
  end

  function proto:_flatten(exph)
    log("flatten")
    local function rel_pos(i, cur)
      return (i < 0) and -i or (cur - i)
    end
    local function process(exp, q)
      local type = xtype(exp)
      if type == "exp_app" then
        local f = process(exp.first, q + 1)
        local s = process(exp.second, q + 1)
        local l = self.llast + 1
        f, s = rel_pos(f, l), rel_pos(s, l)
        table.insert(self.chunk, code_app.new(f, s))
        self.llast = l
        return l
      elseif type == "term_env" then
        return -exp.index
      elseif type == "term_inter" then
        local p = self.interim[exp.index]
        if p == nil then
          error("invalid interim index '"..exp.index.."'", q)
        end
        return p
      else
        local p = self.lenv[exp]
        if p == nil then
          error("undefined variable '"..exp.."'", q)
        end
        return p
      end
    end
    local exp = exph.exp
    if xtype(exp) ~= "exp_app" then
      error("simple variable disallowed", 5)
    end
    self.chunk = {}
    return process(exp, 6)
  end

  function proto:_assign(var, val)
    if val == self.access then
      error("bad global assignemnt", 3)
    end
    if xtype(val) == "number" then
      log("%s <- %s", var, val)
      self.env[var] = val
    elseif xtype(val) == "exphndl" and val:is_atom() then
      log("%s <- %s (%s)", var, self.env[val.exp], val.exp)
      self.env[var] = self.env[val.exp]
    else
      error("bad global assignemnt", 3)
    end
  end

end

---------------------------------------- export
M.compile = compile
M.from_array = from_array
M.from_source = from_source
M.register_from_source = register_from_source
M.register_to_source = register_to_source
return M
-- EOF
