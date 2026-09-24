-- World's per-map colour bake keyed its cache on GbcPalette.mode alone, so
-- two different picked packs (both mode == "custom") kept showing
-- whichever was baked first until a full reload.
--   luajit tests/engine/gen2_color_cache_invalidation_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local GbcPalette = require("src.render.GbcPalette")
local BorderFill = require("src.world.gen2.BorderFill")
local World = require("src.world.gen2.World")

GbcPalette.setMode("gbc")
GbcPalette.setCustomRamp(nil)

-- ------- mapCacheKey: must depend on customRamp identity, not just mode

do
  local fakeSelf = { daytime = "DAY", flickerPhase = 1 }
  local key1 = World.mapCacheKey(fakeSelf, "map1")

  GbcPalette.setCustomRamp(
    { { 1, 1, 1 }, { 2, 2, 2 }, { 3, 3, 3 }, { 4, 4, 4 } })
  local key2 = World.mapCacheKey(fakeSelf, "map1")

  check(key1 ~= key2,
        "BUG FIX: mapCacheKey differs once a custom ramp is active, even " ..
        "though GbcPalette.mode ('gbc') never changed")

  GbcPalette.setCustomRamp(
    { { 9, 9, 9 }, { 8, 8, 8 }, { 7, 7, 7 }, { 6, 6, 6 } })
  local key3 = World.mapCacheKey(fakeSelf, "map1")
  check(key2 ~= key3,
        "BUG FIX: mapCacheKey differs again for a second, different ramp " ..
        "under the same mode")

  GbcPalette.setCustomRamp(nil)
  eq(World.mapCacheKey(fakeSelf, "map1"), key1,
     "clearing the ramp returns to the original no-ramp key")
end

-- ------- refreshColorMode: must refetch on a customRamp-only change

do
  local fakeSelf = { daytime = "DAY", flickerPhase = 1 }
  local calls = 0
  fakeSelf.imageFor = function(_, id) calls = calls + 1; return "img:" .. id end
  fakeSelf.rebuildNeighbors = function() end
  fakeSelf.map = { id = "map1" }

  World.refreshColorMode(fakeSelf)
  eq(calls, 1, "first refreshColorMode call bakes/fetches once")

  World.refreshColorMode(fakeSelf)
  eq(calls, 1, "a second call with nothing changed does not refetch")

  GbcPalette.setCustomRamp(
    { { 5, 5, 5 }, { 4, 4, 4 }, { 3, 3, 3 }, { 2, 2, 2 } })
  World.refreshColorMode(fakeSelf)
  eq(calls, 2,
     "BUG FIX: a customRamp change alone (mode unchanged) still refetches")

  GbcPalette.setCustomRamp(nil)
  World.refreshColorMode(fakeSelf)
  eq(calls, 3, "clearing the ramp (mode still unchanged) refetches too")
end

-- ------- World:borderImageFor: the void/border bake had the identical gap
-- in its own separately-inlined cache key (it doesn't call mapCacheKey). A
-- border baked while GEN 2 (no ramp) was active stayed cached forever,
-- since picking a pack never showed up in this key, only the mode did.

do
  local def = { id = "map1", tileset = "TILESET_JOHTO", borderBlock = 0 }
  local fakeSelf = {
    daytime = "DAY", flickerPhase = 1,
    maps = { map1 = def },
    tilesets = { TILESET_JOHTO = { blocks = { [1] = {} }, tilesPerRow = 16 } },
    mapImages = {},
    borderWaterFrame = function() return nil end,
    atlasFor = function() return nil end,
  }

  GbcPalette.setCustomRamp(nil)
  -- Seed the cache under exactly the key borderImageFor computes today for
  -- "no ramp active", with a sentinel, proving the fix without touching
  -- the real love.graphics bake pipeline.
  local keyNoRamp =
    BorderFill.cacheKey("map1|DAY|gbc|nil|1|fade|0|0")
  fakeSelf.mapImages[keyNoRamp] = "SENTINEL-no-ramp"
  eq(World.borderImageFor(fakeSelf, "map1"), "SENTINEL-no-ramp",
     "sanity: the no-ramp key matches what borderImageFor builds today")

  GbcPalette.setCustomRamp(
    { { 1, 1, 1 }, { 2, 2, 2 }, { 3, 3, 3 }, { 4, 4, 4 } })
  local got = World.borderImageFor(fakeSelf, "map1")
  check(got ~= "SENTINEL-no-ramp",
        "BUG FIX: borderImageFor must not reuse the no-ramp cached void " ..
        "bake once a custom ramp is active")

  GbcPalette.setCustomRamp(nil)
end

GbcPalette.setCustomRamp(nil)
GbcPalette.setMode("gbc")

T.finish("gen2 color cache invalidation")
