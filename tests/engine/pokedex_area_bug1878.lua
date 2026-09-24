-- engine/items/town_map.asm:124, 403 (#1878)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Font = require("src.render.Font")
local TownMap = require("src.ui.TownMap")

local LOCATIONS = {
  ROUTE_2 = { x = 2, y = 6, name = "ROUTE 2" },
  VIRIDIAN_FOREST = { x = 2, y = 4, name = "VIRIDIAN FOREST" },
  CERULEAN_CAVE_1F = { x = 9, y = 1, name = "CERULEAN CAVE" },
  PALLET_TOWN = { x = 1, y = 12, name = "PALLET TOWN" },
}

local function grass(species)
  return { grass = { slots = { { species = species, level = 3 } } } }
end

local function newGame(encounters)
  return {
    data = {
      field = {
        townMap = {
          locations = LOCATIONS,
          background = {
            map = { 1 },
            tiles = { path = "assets/generated/townmap/tiles.png" },
          },
        },
        playerSprites = { walk = "SPRITE_RED" },
      },
      sprites = { SPRITE_RED = { image = "assets/generated/sprites/red_walk.png" } },
      pokemon = {
        BULBASAUR = { name = "BULBASAUR" },
        CATERPIE = { name = "CATERPIE" },
        MEWTWO = { name = "MEWTWO" },
      },
      maps = {},
      encounters = encounters,
    },
    save = {},
    overworld = { map = { id = "PALLET_TOWN" } },
  }
end

local function capture(tm)
  local texts, draws, boxes = {}, {}, {}
  local realDraw = love.graphics.draw
  local realText, realBox = Font.draw, Font.drawBox
  love.graphics.draw = function(img, quadOrX, x, y)
    draws[#draws + 1] = { img = img, quad = quadOrX, x = x, y = y }
  end
  Font.draw = function(text, x, y)
    texts[#texts + 1] = { text = text, x = x, y = y }
    return 0
  end
  Font.drawBox = function(tx, ty, tw, th)
    boxes[#boxes + 1] = { tx = tx, ty = ty, tw = tw, th = th }
  end
  tm.blink = 0
  tm:draw()
  love.graphics.draw, Font.draw, Font.drawBox = realDraw, realText, realBox
  return texts, draws, boxes
end

local function findText(texts, want)
  for _, t in ipairs(texts) do
    if t.text == want then return t end
  end
  return nil
end

local tm = TownMap.new(newGame({}), { nestSpecies = "BULBASAUR" })
eq(#tm.nests, 0, "no encounters means no nests")
check(tm.playerLoc ~= nil, "the player's location still resolves in AREA mode")

local texts, draws, boxes = capture(tm)
check(findText(texts, "BULBASAUR's NEST") ~= nil,
      "row 0 always reads \"<NAME>'s NEST\"")
check(findText(texts, "BULBASAUR AREA UNKNOWN") == nil,
      "the cropped concatenated title is gone")
local unknown = findText(texts, " AREA UNKNOWN")
check(unknown ~= nil, "AREA UNKNOWN is printed in the middle of the map")
if unknown then
  eq(unknown.x, 16, "AreaUnknownText sits at hlcoord 2, 9")
  eq(unknown.y, 72, "AreaUnknownText sits at hlcoord 2, 9")
end
local box
for _, b in ipairs(boxes) do
  if b.tx == 1 and b.ty == 7 then box = b end
end
check(box ~= nil, "TextBoxBorder at hlcoord 1, 7")
if box then
  eq(box.tw, 17, "the border is 15 interior columns wide")
  eq(box.th, 4, "the border is 2 interior rows tall")
end
local drewPlayer = false
for _, d in ipairs(draws) do
  if d.img == tm.playerSheet then drewPlayer = true end
end
check(not drewPlayer,
      "DrawPlayerOrBirdSprite is skipped when no nest OAM was written")

local tm2 = TownMap.new(
  newGame({ ROUTE_2 = grass("CATERPIE"), VIRIDIAN_FOREST = grass("CATERPIE") }),
  { nestSpecies = "CATERPIE" })
eq(#tm2.nests, 2, "ROUTE 2 and VIRIDIAN FOREST are separate nest squares")

local texts2, draws2, boxes2 = capture(tm2)
check(findText(texts2, "CATERPIE's NEST") ~= nil, "the title is unchanged")
check(findText(texts2, " AREA UNKNOWN") == nil,
      "no AREA UNKNOWN text once a nest was drawn")
eq(#boxes2, 0, "no mid-screen box once a nest was drawn")
local playerDraw
for _, d in ipairs(draws2) do
  if d.img == tm2.playerSheet and d.quad == tm2.playerQuad then playerDraw = d end
end
check(playerDraw ~= nil, "the player's walk sprite is drawn on the AREA map")
if playerDraw then
  -- town_map.asm:454
  eq(playerDraw.x, tm2.playerLoc.x * 8 + 16 - 4, "player x is markerXY - 4")
  eq(playerDraw.y, tm2.playerLoc.y * 8 + 8 - 3, "player y is markerXY - 3")
end

local tm3 = TownMap.new(
  newGame({ CERULEAN_CAVE_1F = grass("MEWTWO") }), { nestSpecies = "MEWTWO" })
eq(#tm3.nests, 0, "packed coords $19 (Cerulean Cave) are skipped")

T.finish("pokedex area bug 1878")
