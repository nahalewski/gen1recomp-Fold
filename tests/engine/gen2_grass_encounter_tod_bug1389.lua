-- Grass encounters must key off the CLOCK (wTimeOfDay), never the palette
-- set a map header pins (wTimeOfDayPal): engine/overworld/wildmons.asm:283
-- reads wTimeOfDay for both the rate (GetMapEncounterRate) and the slot list
-- (ChooseWildEncounter).  A PALETTE_DAY tower like Sprout Tower must still
-- roll its night table after dark (#1389, Gastly unobtainable), and a
-- PALETTE_NITE cave must still roll its morning/day table at noon.
--   luajit tests/engine/gen2_grass_encounter_tod_bug1389.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

local World = require("src.world.gen2.World")

local DATA = {
  pokemon = {
    RATTATA = {
      name = "RATTATA", types = { "NORMAL", "NORMAL" },
      baseStats = { hp = 30, attack = 56, defense = 35, speed = 72,
        specialAttack = 25, specialDefense = 35 },
      levelMoves = {},
    },
    GASTLY = {
      name = "GASTLY", types = { "GHOST", "POISON" },
      baseStats = { hp = 30, attack = 35, defense = 30, speed = 80,
        specialAttack = 100, specialDefense = 35 },
      levelMoves = {},
    },
  },
}

local function fullList(species)
  local slots = {}
  for i = 1, 7 do slots[i] = { species = species, level = 10 } end
  return slots
end

-- data/wild/johto_grass.asm's own shape for a pinned tower: day is common
-- and worthless, night is the whole reason the room exists.  A second,
-- separate map stands in for a PALETTE_NITE dungeon (Ilex Forest, Mt Moon):
-- the rates are flipped so the two fixtures cannot agree by accident.
local ENCOUNTERS = {
  grass = {
    SPROUT_TOWER_2F = {
      rates = { MORN = 0, DAY = 0, NITE = 256 },
      slots = {
        MORN = fullList("RATTATA"),
        DAY = fullList("RATTATA"),
        NITE = fullList("GASTLY"),
      },
    },
    ILEX_FOREST = {
      rates = { MORN = 256, DAY = 256, NITE = 0 },
      slots = {
        MORN = fullList("RATTATA"),
        DAY = fullList("RATTATA"),
        NITE = fullList("GASTLY"),
      },
    },
  },
}

local COLL_FLOOR = 0x00

local function fakeWorld(mapId, tod, daytime)
  local game = { data = DATA,
    save = { party = { { species = "RATTATA", level = 5 } } } }
  local world = World.new(game)
  world.map = {
    id = mapId,
    def = { environment = "DUNGEON" },
    cellCollision = function() return COLL_FLOOR end,
  }
  world.maps = { [mapId] = world.map.def }
  world.encounters = ENCOUNTERS
  world.player = { cellX = 5, cellY = 5, facing = "down" }
  -- World:applyPalettes writes both fields every load; a PALETTE_DAY tower
  -- pins `daytime` to DAY no matter the hour, while `tod` keeps tracking the
  -- clock (src/world/gen2/World.lua:8271-8326).
  world.tod = tod
  world.daytime = daytime
  local battled
  world.startBattle = function(_, opts)
    battled = opts.wild and opts.wild.species
    return true
  end
  return world, function() return battled end
end

-- ---- PALETTE_DAY tower, at night: the clock says NITE, the pin says DAY --
do
  local world, battled = fakeWorld("SPROUT_TOWER_2F", "NITE", "DAY")
  check(world:tryWildEncounter(), "the tower rolls at night despite the pin")
  eq(battled(), "GASTLY",
    "the night list wins because the lookup is the clock, not the pin")
end

-- ---- the same tower at actual daytime: the clock and the pin now agree ---
do
  local world, battled = fakeWorld("SPROUT_TOWER_2F", "DAY", "DAY")
  check(not world:tryWildEncounter(),
    "DAY's rate is zero, so a daytime step in the tower rolls nothing")
  eq(battled(), nil, "and nothing battled")
end

-- ---- a PALETTE_NITE dungeon at actual noon: the pin says NITE, clock DAY --
do
  local world, battled = fakeWorld("ILEX_FOREST", "DAY", "NITE")
  check(world:tryWildEncounter(),
    "a pinned-night map still rolls its day table at the clock's noon")
  eq(battled(), "RATTATA",
    "the day list wins because the lookup ignores the palette pin")
end

T.finish("gen2 grass encounter tod bug1389")
