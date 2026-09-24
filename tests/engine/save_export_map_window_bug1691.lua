-- home/overworld.asm:2016 (#1691)
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MapContext = require("src.save_convert.MapContext")
local GenSave = require("src.save_convert.GenSave")

local O = MapContext.OFFSETS
local SAVE = GenSave.OFFSETS
local stampMapWindow = loadfile("tests/fixture_data/map_window.lua")()

GenSave.setCharmap(loadfile("src/save_convert/data/charmap.lua")())

local function fixtureData()
  local maps = {}
  for id, map in pairs(dofile("tests/fixture_data/maps.lua")) do
    local copy = {}
    for k, v in pairs(map) do copy[k] = v end
    maps[id] = copy
  end
  local data = {
    maps = maps,
    pokemon = dofile("tests/fixture_data/pokemon.lua"),
    moves = dofile("tests/fixture_data/moves.lua"),
    items = dofile("tests/fixture_data/items.lua"),
  }
  return stampMapWindow(data, "FIX_TOWN")
end

local function newSave()
  return {
    player = { name = "RED", rival = "BLUE", map = "FIX_TOWN", x = 7, y = 4 },
    money = 3000, inventory = {}, pokedex = { seen = {}, owned = {} },
    flags = {}, party = {}, boxes = {},
  }
end

do
  local bytes = GenSave.encode(newSave(), fixtureData(), nil)
  T.eq(#bytes, GenSave.SAVE_SIZE, "a complete cache still exports")
  T.check(bytes:byte(SAVE.mainData + O.curMapHeader + 3) ~= 0,
    "with a map width the game can walk")
  T.check(bytes:byte(SAVE.mainData + O.tilesetHeader + 1) ~= 0,
    "and a tileset bank that is not bank 0")
end

local CASES = {
  {
    label = "no saved-map bytes",
    want = "saved%-map bytes",
    strip = function(data) data.maps.FIX_TOWN.sram = nil end,
  },
  {
    label = "no tileset header",
    want = "tileset bytes",
    strip = function(data) data.tilesets = {} end,
  },
  {
    label = "no map music",
    want = "map music",
    strip = function(data) data.audio = {} end,
  },
}

for _, case in ipairs(CASES) do
  local data = fixtureData()
  case.strip(data)
  local ok, err = pcall(GenSave.encode, newSave(), data, nil)
  T.eq(ok, false, case.label .. ": the export is refused, not written")
  T.check(type(err) == "string" and err:find(case.want) ~= nil,
    case.label .. ": and says what is missing -- " .. tostring(err))
  T.check(type(err) == "string" and err:find("re%-import the ROM") ~= nil,
    case.label .. ": and what to do about it -- " .. tostring(err))
end

do
  local data = fixtureData()
  local template = GenSave.encode(newSave(), data, nil)
  local moved = template:sub(1, SAVE.curMap) .. string.char(0xFE)
    .. template:sub(SAVE.curMap + 2)
  data.maps.FIX_TOWN.sram = nil
  local ok, err = pcall(GenSave.encode, newSave(), data, moved)
  T.eq(ok, false, "a stale template is refused rather than exported as it is")
  T.check(type(err) == "string" and err:find("saved%-map bytes") ~= nil,
    "for the same missing bytes -- " .. tostring(err))
end

T.finish("save export map window bug1691")
