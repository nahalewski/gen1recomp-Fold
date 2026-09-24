-- pokecrystal constants/engine_flags.asm:66-92 vs pokegold :65-91

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local FieldMoves = require("src.world.gen2.FieldMoves")

-- pokegold constants/engine_flags.asm:65-91, in const_def order from
-- ENGINE_RADIO_CARD = 0: PALLET 52 .. INDIGO_PLATEAU 63, NEW_BARK 64 ..
-- SILVER_CAVE 75.
local GOLD_IDS = {
  SPAWN_PALLET = 52, SPAWN_VIRIDIAN = 53, SPAWN_PEWTER = 54,
  SPAWN_CERULEAN = 55, SPAWN_ROCK_TUNNEL = 56, SPAWN_VERMILION = 57,
  SPAWN_LAVENDER = 58, SPAWN_SAFFRON = 59, SPAWN_CELADON = 60,
  SPAWN_FUCHSIA = 61, SPAWN_CINNABAR = 62, SPAWN_INDIGO = 63,
  SPAWN_NEW_BARK = 64, SPAWN_CHERRYGROVE = 65, SPAWN_VIOLET = 66,
  SPAWN_AZALEA = 67, SPAWN_CIANWOOD = 68, SPAWN_GOLDENROD = 69,
  SPAWN_OLIVINE = 70, SPAWN_ECRUTEAK = 71, SPAWN_MAHOGANY = 72,
  SPAWN_LAKE_OF_RAGE = 73, SPAWN_BLACKTHORN = 74, SPAWN_MT_SILVER = 75,
}

local function byFlag()
  local out = {}
  for _, row in ipairs(FieldMoves.FLYPOINTS) do out[row.spawn] = row.flag end
  return out
end

-- A Gold cache carries no engineFlagOrder; the table keeps its literal ids.
FieldMoves.bindEngineFlags(nil)
local gold = byFlag()
for spawn, id in pairs(GOLD_IDS) do
  T.eq(gold[spawn], id, spawn .. " keeps the pokegold id with no order")
end

-- pokecrystal constants/engine_flags.asm:25 ENGINE_MOBILE_SYSTEM at index 16
-- shifts every later id up exactly one.
local crystalOrder = {}
for _, row in ipairs(FieldMoves.FLYPOINTS) do
  -- order[i] names id i-1, so the Crystal id (gold + 1) sits at gold + 2
  crystalOrder[GOLD_IDS[row.spawn] + 2] = row.name
end
FieldMoves.bindEngineFlags(crystalOrder)
local crystal = byFlag()
for spawn, id in pairs(GOLD_IDS) do
  T.eq(crystal[spawn], id + 1, spawn .. " rebinds one higher under Crystal")
end

-- The Kanto gate reads SPAWN_INDIGO through the rebound id: Crystal's 64,
-- which the old table misread as Gold's SPAWN_NEW_BARK.
local save = { engineFlags = { [64] = true } }
T.check(FieldMoves.hasVisitedSpawn(save, "SPAWN_INDIGO"),
  "Crystal flag 64 is the INDIGO_PLATEAU flypoint")
local kanto = FieldMoves.flyPoints(save, nil, "kanto")
T.eq(#kanto, 1, "the Kanto half opens on it")
T.eq(kanto[1].spawn, "SPAWN_INDIGO", "with the plateau row itself")

-- And a rebind back to a Gold cache restores the literal ids.
FieldMoves.bindEngineFlags(nil)
local again = byFlag()
for spawn, id in pairs(GOLD_IDS) do
  T.eq(again[spawn], id, spawn .. " returns to the pokegold id")
end
local goldSave = { engineFlags = { [63] = true } }
T.check(FieldMoves.hasVisitedSpawn(goldSave, "SPAWN_INDIGO"),
  "Gold flag 63 is INDIGO_PLATEAU again")

T.finish("gen2 flypoint rebind bug 1836")
