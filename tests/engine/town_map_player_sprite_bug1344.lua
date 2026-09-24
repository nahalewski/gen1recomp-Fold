-- The TOWN MAP drew a blinking black square for the player instead of their
-- walk sprite, because the marker was a placeholder rectangle instead of the
-- OAM sprite the cart draws (#1344).
-- engine/items/town_map.asm:347
--   luajit tests/engine/town_map_player_sprite_bug1344.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local TownMap = require("src.ui.TownMap")

local function newGame()
  return {
    data = {
      field = {
        townMap = { PALLET_TOWN = { x = 1, y = 2, name = "PALLET TOWN" } },
        playerSprites = { walk = "SPRITE_RED" },
        -- no townMap.background: forces the stale-asset fallback draw path,
        -- which is the one #1344's repro screenshot came from
      },
      sprites = { SPRITE_RED = { image = "assets/generated/sprites/red_walk.png" } },
      maps = {},
    },
    save = {},
    overworld = { map = { id = "PALLET_TOWN" } },
  }
end

local game = newGame()
local tm = TownMap.new(game, {})

eq(tm.mode, "grid", "one located entry puts the screen in grid mode")
check(tm.bg == nil, "no background.map means the stale-asset fallback draws")
check(tm.playerLoc ~= nil, "the player's map resolved to a location")
check(tm.playerSheet ~= nil,
  "TownMap.new resolved the walk sheet (the fix this test guards)")

-- capture what :draw() actually paints, without a real screen
local draws, rects = {}, {}
local realDraw, realRect = love.graphics.draw, love.graphics.rectangle
love.graphics.draw = function(img, quadOrX, x, y)
  draws[#draws + 1] = { img = img, quad = quadOrX, x = x, y = y }
end
love.graphics.rectangle = function(mode, x, y, w, h)
  rects[#rects + 1] = { mode = mode, x = x, y = y, w = w, h = h }
end

tm.blink = 0 -- (0 < 20): the player marker is in its "on" blink phase
tm:draw()

love.graphics.draw = realDraw
love.graphics.rectangle = realRect

local function drewSprite()
  for _, d in ipairs(draws) do
    if d.img == tm.playerSheet and d.quad == tm.playerQuad then
      return d
    end
  end
  return nil
end

local spriteDraw = drewSprite()
check(spriteDraw ~= nil, "the player's walk sprite was drawn, not a placeholder")
if spriteDraw then
  -- engine/items/town_map.asm:449 WriteTownMapSpriteOAM's -4,-3 carry quirk
  eq(spriteDraw.x, tm.playerLoc.x * 8 - 4, "sprite x is markerXY - 4")
  eq(spriteDraw.y, tm.playerLoc.y * 8 - 3, "sprite y is markerXY - 3")
end

local function blackDotAtPlayer()
  for _, r in ipairs(rects) do
    if r.mode == "fill" and r.w == 4 and r.h == 4
       and r.x == tm.playerLoc.x * 8 + 2 and r.y == tm.playerLoc.y * 8 + 2 then
      return true
    end
  end
  return false
end
check(not blackDotAtPlayer(),
  "the old 4x4 placeholder square is not drawn once a sprite is available")

T.finish("town map player sprite bug 1344")
