#!/usr/local/bin/lua
--
-- grassator.lua
--
local prog_name = "grassator"
local version = "v0.3.0"
local mod_date = "2012/05/06"
local author = "ZR(T.Yato)"
package.path = arg[0]:gsub("%w+%.lua$", "?.lua;")..package.path
planter = require 'planter'
bushfire = require 'bushfire'

from_lang, to_lang = nil, nil
exec_mode, out_sjis = false, false
use_debug, use_stat, use_quick = false, false, true
from_file_name, to_file_name = nil, nil

----------------------------------------
do

local homu = '\227\129\187\227\130\128'
local sjis_homu = '\130\217\130\222'

planter.register_from_source('grass', bushfire.parse_grass)

local function parse_homuhomu (source)
  local text = tostring(source):gsub("[wvV]", "x")
    :gsub('[ \t]+', ' ')
    :gsub(homu, 'w'):gsub("[^ w\n]+", "x")..'$'

  local syms, in_W = {}, false
  for i = 1, #text do
    local c = string.byte(text, i)
    if c == 10 then
      in_W = false
      table.insert(syms, 118)
    elseif c == 32 then
      in_W = (not in_W) -- and string.byte(text, i + 1) == 119
    elseif c == 119 then
      table.insert(syms, (in_W) and 87 or 119)
    end
  end

  local chunk = {}
  local prev, count = 118, 0
  for i = 1, #text do
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

local function generate_homuhomu(prog)
  local ohomu = (out_sjis) and sjis_homu or homu
  local function homuseq(n)
    return string.rep(ohomu, n)
  end
  local chunk = {}
  local prev_app = false
  for i = 1, #prog.code do
    local code = prog.code[i]
    if code.is_abs then
      if #chunk > 0 then
        table.insert(chunk, "\n")
      end
      table.insert(chunk, homuseq(code.arity))
      for i = 1, #code.body do
        local app = code.body[i]
        table.insert(chunk, " ")
        table.insert(chunk, homuseq(app.first))
        table.insert(chunk, " ")
        table.insert(chunk, homuseq(app.second))
      end
      prev_app = false
    else
      if not prev_app then
        table.insert(chunk, "\n")
      end
      table.insert(chunk, " ")
      table.insert(chunk, homuseq(code.first))
      table.insert(chunk, " ")
      table.insert(chunk, homuseq(code.second))
      prev_app = true
    end
  end
  table.insert(chunk, "\n")
  return table.concat(chunk)
end

planter.register_from_source('homuhomu', parse_homuhomu)
bushfire.register_from_source('homuhomu', parse_homuhomu)
planter.register_to_source('homuhomu', generate_homuhomu)

bushfire.register_from_source('seed', function(source)
  local t1 = planter.from_source('seed', source)
  local t2 = t1:grass_source()
  return bushfire.parse_grass(t2)
end)

end
----------------------------------------

function main()
  read_option()
  local fsource = read_whole()
  if exec_mode then
    io.input(io.stdin)
    bushfire.use_debug(use_debug)
    bushfire.use_stat(use_stat)
    bushfire.use_quick(use_quick)
    bushfire.run(from_lang, fsource)
  else
    local prog = planter.from_source(from_lang, fsource)
    if use_debug then prog:dump() end
    if to_lang ~= "none" then
      local tsource = prog:to_source(to_lang, prog)
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
  print(("This is %s, v%s<%s> by %s")
    :format(prog_name, version, mod_date, author))
  print(([=[
Usage:
(as interpreter)
  #PROG [-f LANG] [-d] [-s] [INFILE]
(as converter)
  #PROG [-f LANG] -t LANG [-d] [INFILE [OUTFILE]]
Options:
  -f lang    Input language name. The default value is 'grass' (in
             interpreter mode) or 'seed' (in converter mode).
  -t lang    Output language name.
  -d         Enable debug mode.
  -s         Enable stat mode.
  infile     Input file name (default=stdin).
  outfile    Output file name (default=stdout).
Supported languages:
  seed (only input) / grass / homuhomu
]=]):gsub("#PROG", prog_name), "")
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

---------------------------------------- go to main
main()
-- EOF
