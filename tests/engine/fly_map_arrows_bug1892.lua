-- engine/items/town_map.asm:150, 167, 176, 185 (#1892)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Font = require("src.render.Font")
local Theme = require("src.ui.Theme")
local TownMap = require("src.ui.TownMap")

local LOCATIONS = {
  PALLET_TOWN = { x = 4, y = 12, name = "PALLET TOWN" },
  VIRIDIAN_CITY = { x = 4, y = 11, name = "VIRIDIAN CITY" },
  CINNABAR_ISLAND = { x = 2, y = 15, name = "CINNABAR ISLAND" },
}

local function newGame()
  local pressed = {}
  local game = {
    data = {
      field = {
        townMap = {
          locations = LOCATIONS,
          background = {
            map = { 1 },
            tiles = { path = "assets/generated/townmap/tiles.png" },
          },
        },
        playerSprites = { walk = "SPRITE_RED", fly = "SPRITE_BIRD" },
        flyOrder = { "PALLET_TOWN", "VIRIDIAN_CITY", "CINNABAR_ISLAND" },
        flyWarps = {
          PALLET_TOWN = { x = 1, y = 1 },
          VIRIDIAN_CITY = { x = 1, y = 1 },
          CINNABAR_ISLAND = { x = 1, y = 1 },
        },
      },
      sprites = {
        SPRITE_RED = { image = "assets/generated/sprites/red_walk.png" },
        SPRITE_BIRD = { image = "assets/generated/sprites/bird.png" },
      },
      maps = {
        PALLET_TOWN = { id = "PALLET_TOWN", index = 0 },
        VIRIDIAN_CITY = { id = "VIRIDIAN_CITY", index = 1 },
        CINNABAR_ISLAND = { id = "CINNABAR_ISLAND", index = 2 },
      },
    },
    save = {
      visited = { PALLET_TOWN = true, VIRIDIAN_CITY = true,
                  CINNABAR_ISLAND = true },
    },
    overworld = { map = { id = "PALLET_TOWN" } },
    input = { wasPressed = function(_, name)
      local p = pressed[name]
      pressed[name] = nil
      return p
    end },
    stack = { pop = function() end },
  }
  return game, function(name) pressed[name] = true end
end

local function capture(tm)
  local texts, codes, draws, polys = {}, {}, {}, {}
  local realDraw, realPoly = love.graphics.draw, love.graphics.polygon
  local realText, realCode = Font.draw, Font.drawCode
  love.graphics.draw = function(img, quadOrX, x, y)
    draws[#draws + 1] = { img = img, quad = quadOrX, x = x, y = y }
  end
  love.graphics.polygon = function(mode, ...)
    polys[#polys + 1] = { mode = mode, ... }
  end
  Font.draw = function(text, x, y)
    texts[#texts + 1] = { text = text, x = x, y = y }
    return 0
  end
  Font.drawCode = function(code, x, y)
    codes[#codes + 1] = { code = code, x = x, y = y }
  end
  tm:draw()
  love.graphics.draw, love.graphics.polygon = realDraw, realPoly
  Font.draw, Font.drawCode = realText, realCode
  return texts, codes, draws, polys
end

local function findText(texts, want)
  for _, t in ipairs(texts) do
    if t.text == want then return t end
  end
  return nil
end

local function upArrowAt(tm, draws, polys)
  if tm.upArrow then
    for _, d in ipairs(draws) do
      if d.img == tm.upArrow then return d.quad end
    end
    return nil
  end
  for _, p in ipairs(polys) do
    if p.mode == "fill" then return p[1] end
  end
  return nil
end

local function codeAt(codes, code, x, y)
  for _, c in ipairs(codes) do
    if c.code == code and c.x == x and c.y == y then return true end
  end
  return false
end

local game, tap = newGame()
local tm = TownMap.new(game, { fly = true, onFly = function() end })
check(tm.fly == true, "the picker opens in fly mode")
eq(tm.mode, "grid", "the picker draws the Kanto map, not the name list")

local texts, codes, draws, polys = capture(tm)
local banner = findText(texts, "To PALLET TOWN")
check(banner ~= nil, "the fly prefix and destination are one format string")
if banner then eq(banner.x, 0, "the composed banner starts at hlcoord 0, 0") end
check(findText(texts, "To") == nil and findText(texts, "PALLET TOWN") == nil,
      "the prefix and destination are not drawn at fixed separate columns")

check(codeAt(codes, Theme.moreArrow, 152, 0),
      "the down arrow is drawn at hlcoord 19, 0")
for _, c in ipairs(codes) do
  check(c.code ~= Theme.cursor,
        "the up arrow is never the $ED right-pointing cursor glyph")
end

check(upArrowAt(tm, draws, polys) == nil,
      "the up arrow is blank for the opening 15 frames")
for _ = 1, 15 do tm:update(0) end
local _, _, draws3, polys3 = capture(tm)
eq(upArrowAt(tm, draws3, polys3), 144,
   "after 15 frames the up arrow is drawn at hlcoord 18, 0")

tap("down") tm:update(0)
local _, codes4, draws4, polys4 = capture(tm)
eq(upArrowAt(tm, draws4, polys4), 144, "the up arrow stays put on DOWN")
check(not codeAt(codes4, Theme.moreArrow, 152, 0),
      "the down arrow blanks while DOWN is held")
for _ = 1, 15 do tm:update(0) end
local _, codes5 = capture(tm)
check(codeAt(codes5, Theme.moreArrow, 152, 0),
      "both arrows are back 15 frames later")

tap("up") tm:update(0)
local _, codes6, draws6, polys6 = capture(tm)
check(upArrowAt(tm, draws6, polys6) == nil, "the up arrow blanks on UP")
check(codeAt(codes6, Theme.moreArrow, 152, 0),
      "the down arrow stays put on UP")

local game7 = newGame()
local tm7 = TownMap.new(game7, { fly = true, onFly = function() end })
tm7.sel = 3
local texts7 = capture(tm7)
local long = findText(texts7, "To CINNABAR ISLAND")
check(long ~= nil, "the longest composed fly banner is printed")
if long then
  check(long.x + Font.width(long.text) <= 144,
        "the composed banner ends before the arrow columns")
end

T.finish("fly map arrows bug 1892")
