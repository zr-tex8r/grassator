--
-- ixgrassator.lua
--
luatexbase.provides_module({
  name = 'ixgrassator',
  date = '2011/12/23',
  version = '0.2.3',
  description = 'Grass environment in LaTeX',
})
require 'bushfire'
module(..., package.seeall)
-- local err, warn, info, log = luatexbase.errwarinf(_NAME)
local gio = bushfire.gio

---------------------------------------- redefinition of 'gio'
do
  local inbuf, outbuf, cur
  function gio.setup(str)
    inbuf = tostring(str):explode("")
    outbuf = {}
    cur = 0
  end
  function gio.read()
    if cur >= #inbuf then return nil end
    cur = cur + 1
    return inbuf[cur]
  end
  function gio.write(c)
    table.insert(outbuf, c)
  end
  function gio.output()
    return table.concat(outbuf, "")
  end
end
---------------------------------------- additional parsers
do
  bushfire.register_from_source('homuhomu', function(source)
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
  end)

  --[[
  bushfire.register_from_source('seed', function(source)
    local t1 = planter.from_source('seed', source)
    local t2 = t1:grass_source()
    return bushfire.parse_grass(t2)
  end)
  ]]
end
---------------------------------------- module main
do
  procedure = {}

  function register(id, lang, outverb, source)
    id, outverb = tonumber(id), tonumber(outverb)
    source = source:gsub("^\r", ""):gsub("\r", "\n")
    if not (id or outverb or source) then error("INTERNAL1") end
    procedure[id] = {
      outverb = (outverb ~= 0),
      prog = bushfire.parse(lang, source)
    }
  end

  function invoke(id, input)
    id = tonumber(id)
    if not id then error("INTERNAL2") end
    local proc = assert(procedure[id], "invalid proc id")
    gio.setup(input)
    bushfire.run_array(proc.prog)
    local output = gio.output()
    if proc.outverb then
      tex.write(output)
    else
      tex.print(output:explode("\n"))
    end
  end
end
---------------------------------------- all done
-- EOF
