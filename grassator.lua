--#!/usr/local/bin/lua
--
-- grassator.lua
--
local prog_name = "grassator"
local version = "1.1.0"
local mod_date = "2017/08/20"
local author = "ZR(T.Yato)"
package.path = arg[0]:gsub("[%.%w]+$", "?.lua;")..package.path
planter = require 'planter'
bushfire = require 'bushfire'

from_lang, to_lang = nil, nil
exec_mode, out_sjis = false, false
use_debug, use_stat, use_quick = false, false, true
from_file_name, to_file_name = nil, nil

---------------------------------------- helpers
do
  function guess_charcode(bytes)
    if type(bytes) ~= "string" then return end
    local ptn_ascii = "^[\001-\127]+$"
    if bytes:find(ptn_ascii) then return "ascii"
    elseif bytes:gsub("[\192-\223][\128-\191]",'2')
                :gsub("[\224-\239][\128-\191][\128-\191]",'3')
                :gsub("[\240-\247][\128-\191][\128-\191][\128-\191]",'4')
                :find(ptn_ascii) then return "utf8"
     elseif bytes:gsub("[\129-\159\224-\252][\064-\126\128-\252]", '2')
                :gsub("[\160-\223]", '1')
                :find(ptn_ascii) then return "sjis"
     end
  end

  function listify(v)
    return (type(assert(v)) == "table") and v or { v }
  end

  function subst_symbol(src, fsym, tsym)
    fsym = listify(fsym)
    for i = 1, #fsym do
      src = src:gsub(fsym[i], tsym)
    end
    return src
  end

  function sure(value, errmsg, level)
    if value then return value end
    error(errmsg, 2)
  end
end
---------------------------------------- 'grassoid'
do
  grassoid = {}
  local proto = {}

  function grassoid.new(sym, prop)
    return setmetatable({
      sym = assert(sym), prop = prop or {},
    }, { __index = proto })
  end

  function proto:parse(source)
    local sym = self.sym
    source = tostring(source):gsub("[\001-\003]", ' ')
    source = subst_symbol(source, sym.w, "\001")
    source = subst_symbol(source, sym.W, "\002")
    source = subst_symbol(source, sym.v, "\003")
    source = source:gsub("[^\001-\003]", "")
        :gsub("\001", "w"):gsub("\002", "W"):gsub("\003", "v")
        :gsub("v+$", "")
    return bushfire.parse_grass(source)
  end

  function proto:generate(list)
    local source = planter.from_array(list):to_grass()
    if self.prop.grass then return source end
    if self.prop.append_v then source = source.."v" end
    local sym = assert(self.sym)
    return source:gsub("w", "\001"):gsub("W", "\002"):gsub("v", "\003")
        :gsub("\001", listify(sym.w)[1])
        :gsub("\002", listify(sym.W)[1])
        :gsub("\003", listify(sym.v)[1])
  end
end
---------------------------------------- 'homuoid'
do
  homuoid = {}
  local proto = {}

  function homuoid.new(sym)
    return setmetatable({
      sym = assert(sym)
    }, { __index = proto })
  end

  function proto:parse(source)
    local sym = self.sym
    source = tostring(source):gsub("\001", "\002"):gsub("[ \t]+", ' ')
    source = subst_symbol(source, sym, "\001")
    source = source:gsub("[^ \001\n]+", "\002")..'$'

    local syms, in_W = {}, false
    for i = 1, #source do
      local c = string.byte(source, i)
      if c == 10 then
        in_W = false
        table.insert(syms, 118)
      elseif c == 32 then
        in_W = (not in_W) -- and string.byte(text, i + 1) == 2
      elseif c == 1 then
        table.insert(syms, (in_W) and 87 or 119)
      end
    end

    local chunk = {}
    local prev, count = 118, 0
    for i = 1, #syms do
      local cur = syms[i]
      if cur == prev then
        count = count + 1
      else
        local l = string.char(prev)
        if #chunk > 0 or l ~= 'v' then
          table.insert(chunk, { l = l, c = count })
        end
        prev, count = cur, 1
      end
    end
    if #chunk > 0 and chunk[#chunk].l ~= 'v' then
      table.insert(chunk, { l = 'v', c = 1 })
    end

    return bushfire.mower.last_pass(chunk)
  end

  function proto:generate(list)
    local prog = planter.from_array(list)
    local sym = listify(self.sym)[1]
    local function symseq(n)
      return string.rep(sym, n)
    end
    local chunk = {}
    local prev_app = false
    for i = 1, #prog.code do
      local code = prog.code[i]
      if code.is_abs then
        if #chunk > 0 then
          table.insert(chunk, "\n")
        end
        table.insert(chunk, symseq(code.arity))
        for i = 1, #code.body do
          local app = code.body[i]
          table.insert(chunk, " ")
          table.insert(chunk, symseq(app.first))
          table.insert(chunk, " ")
          table.insert(chunk, symseq(app.second))
        end
        prev_app = false
      else
        if not prev_app then
          table.insert(chunk, "\n")
        end
        table.insert(chunk, " ")
        table.insert(chunk, symseq(code.first))
        table.insert(chunk, " ")
        table.insert(chunk, symseq(code.second))
        prev_app = true
      end
    end
    table.insert(chunk, "\n")
    return table.concat(chunk)
  end
end
---------------------------------------- 'seed'
do
  seed = {}
  function seed:parse(source)
    local prog = planter.from_seed(source)
    return bushfire.parse_grass(prog:to_grass())
  end
end
---------------------------------------- main

languages = { seed = seed }
language_order = { "seed" }
function register_language(name, lang_class, sym_utf8, sym_sjis, prop)
  local sym = sym_utf8
  if out_sjis then sym = sym_sjis end
  if not sym then return end
  languages[name] = lang_class.new(sym, prop)
  table.insert(language_order, name)
end

function main()
  read_option()
  register_all_languages()
  local fsource = read_whole()
  local flang = sure(languages[from_lang],
      "unknown language '"..from_lang.."'", 1)
  if exec_mode then
    io.input(io.stdin)
    bushfire.use_debug(use_debug)
    bushfire.use_stat(use_stat)
    bushfire.use_quick(use_quick)
    local list = flang:parse(fsource)
    bushfire.run_array(list)
  else
    local list = flang:parse(fsource)
    if use_debug then planter.from_array(list):dump() end
    if to_lang ~= "none" then
      local tlang = sure(languages[to_lang],
          "unknown language '"..to_lang.."'", 2)
      sure(tlang.generate, "cannot use '"..to_lang.."' as target", 1)
      local tsource = tlang:generate(list)
      write_whole(tsource)
    end
  end
end

function read_whole()
  io.input(from_file_name)
  return io.read("*a")
end

function write_whole(text)
  io.output(to_file_name)
  io.write(text)
  io.flush()
end

function show_usage()
  register_all_languages()
  print(("This is %s, v%s<%s> by %s")
    :format(prog_name, version, mod_date, author))
  print((([=[
Usage:
(as interpreter)
  #PROG [-f LANG] [-d] [-s] [-S] [INFILE]
(as converter)
  #PROG [-f LANG] -t LANG [-d] [-S] [INFILE [OUTFILE]]
Options:
  -f lang    Input language name. The default value is 'grass' (in
             interpreter mode) or 'seed' (in converter mode).
  -t lang    Output language name.
  -d         Enable debug mode.
  -s         Enable stat mode.
  -S         Assume program source is in SJIS instead of UTF-8
  infile     Input file name (default=stdin).
  outfile    Output file name (default=stdout).
Supported languages:]=]):gsub("#PROG", prog_name)))
  local names = table.concat(language_order, " / ")
  print("  "..names)
  print("  ('seed' can be used only as input)")
end

function read_option()
  local i = 0
  exec_mode = true
  while true do
    i = i + 1; local arg1 = arg[i]
    if type(arg1) ~="string" or arg1:sub(1, 1) ~= "-" then
      break
    end
    if arg1 == "-h" or arg1 == "-help" or arg1 == "--help" then
      show_usage()
      os.exit()
    elseif arg1 == "-S" then
      out_sjis = true
    elseif arg1 == "-d" then
      use_debug = true
    elseif arg1 == "-s" then
      use_stat = true
    elseif arg1 == "-Q" then
      use_quick = false
    elseif arg1 == "-f" and i < #arg then
      i = i + 1; from_lang = arg[i]
    elseif arg1 == "-t" and i < #arg then
      i = i + 1; to_lang = arg[i]
      exec_mode = false
    else
      error("unknown option '"..arg1.."'")
    end
  end
  from_lang = from_lang or ((exec_mode) and "grass" or "seed")
  from_file_name = arg[i]
  to_file_name = arg[i + 1]
end

---------------------------------------- languages
function register_all_languages()

register_language('grass', grassoid, {
    w = {'w', "\239\189\151"},
    W = {'W', "\239\188\183"},
    v = {'v', "\239\189\150"},
  }, {
    w = {'w', "\130\151"},
    W = {'W', "\130\118"},
    v = {'v', "\130\150"},
  }, { grass = true })

register_language('homuhomu', homuoid,
  '\227\129\187\227\130\128', -- HOMU
  '\130\217\130\222')

register_language('snowman', grassoid, {
    w = "\226\152\131", -- SNOWMAN
    W = "\226\155\132", -- SNOWMAN WITHOUT SNOW
    v = "\226\155\135", -- BLACK SNOWMAN
  }, nil)

register_language('duck', homuoid,
  '\240\159\166\134', -- DUCK
  nil)

local kysu = "\227\130\173\227\131\187\227\131\168"..
    "\227\131\187\227\130\183\239\188\129"
local kyss = "\131\076\129\069\131\136\129\069\131\086\129\073"
register_language('zundoko', grassoid, {
    w = "\227\131\137\227\130\179", -- DOKO
    W = "\227\130\186\227\131\179", -- ZUN
    v = {kysu.."\n", kysu}, -- KI.YO.SHI!
  }, {
    w = "\131\104\131\082",
    W = "\131\089\131\147",
    v = {kyss.."\n", kyss},
  }, { append_v = true })

register_language('expandafter', homuoid,
  '\\expandafter', '\\expandafter')

end
---------------------------------------- go to main
main()
-- EOF
