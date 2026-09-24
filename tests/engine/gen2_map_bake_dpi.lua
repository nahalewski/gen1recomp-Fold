-- Gen 2 map bakes take dpiscale 1 so map pixels stay square LCD pixels
-- (#208 #1301, constants/hardware.inc:932; see src/render/PixelCanvas.lua).
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local g = love.graphics
local seen = {}
local realNewCanvas = g.newCanvas
g.newCanvas = function(w, h, settings)
  seen[#seen + 1] = { w = w, h = h, dpiscale = settings and settings.dpiscale }
  local c = realNewCanvas(w, h)
  c.renderTo = function(_, fn) fn() end
  c.setFilter = function() end
  return c
end

local World = require("src.world.gen2.World")
local MapPreview = require("src.world.gen2.MapPreview")

local atlas = {
  getDimensions = function() return 128, 128 end,
  setFilter = function() end,
}
local tileset = { blocks = { [1] = {} }, tilesPerRow = 16 }
local map = { def = { tileset = "TILESET_JOHTO" }, width = 20, height = 18,
              blocks = {}, borderBlock = 0 }

local world = setmetatable({
  atlasCache = {},
  atlasFor = function() return atlas, tileset end,
}, { __index = World })

World.bakeMapImage(world, map, nil, nil)
local bakeCount = #seen
T.check(bakeCount >= 1, "the map bake allocated a canvas")

World.scrollStrip(world, map.def, tileset, 3, { h = 1, v = 0 })
T.check(#seen > bakeCount, "the scroll strip allocated a canvas")
local stripCount = #seen

local origAtlasFor = MapPreview.atlasFor
MapPreview.atlasFor = function() return atlas, tileset end
MapPreview.bake({ tilesets = {}, atlasCache = {}, mapImages = {} }, map, "DAY")
MapPreview.atlasFor = origAtlasFor
T.check(#seen > stripCount, "the save-editor bake allocated a canvas")

for i, c in ipairs(seen) do
  T.eq(c.dpiscale, 1,
    ("canvas %d (%dx%d) is allocated at dpiscale 1"):format(i, c.w, c.h))
end

g.newCanvas = realNewCanvas
T.finish("gen2 map bake dpi")
