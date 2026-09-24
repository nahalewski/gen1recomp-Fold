-- engine/menus/pokedex.asm:256
-- engine/gfx/load_pokedex_tiles.asm:8-11
-- engine/battle/draw_hud_pokeball_gfx.asm:189-192
--   luajit tests/engine/pokedex_ball_tile_bug2067.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local draws, prims, texts = {}, {}, {}
local function colorNow()
  local r, g, b = love.graphics.getColor()
  return { r, g, b }
end
love.graphics.draw = function(img, quad, x, y)
  draws[#draws + 1] = { img = img, quad = quad, x = x, y = y,
                        color = colorNow() }
end
love.graphics.circle = function(_, x, y)
  prims[#prims + 1] = { shape = "circle", x = x, y = y }
end
love.graphics.rectangle = function(_, x, y, w, h)
  prims[#prims + 1] = { shape = "rectangle", x = x, y = y, w = w, h = h }
end

package.loaded["src.render.Font"] = {
  draw = function(text, x, y)
    texts[#texts + 1] = { text = text, x = x, y = y, color = colorNow() }
  end,
  drawCode = function() end,
  width = function(text) return #text * 8 end,
  split = function(text)
    local out = {}
    for i = 1, #text do out[i] = { from = i, to = i } end
    return out
  end,
}

local PokedexMenu = require("src.ui.PokedexMenu")

local DEX_SIZE = 151
local data = {
  pokemon = {},
  constants = { dexSize = DEX_SIZE, dexDigits = 3 },
}
for n = 1, DEX_SIZE do
  local id = ("DEXMON_%03d"):format(n)
  data.pokemon[id] = { id = id, name = ("MON%03d"):format(n), dex = n }
end

local save = { pokedex = { seen = {}, owned = {} } }
for n = 1, 20 do save.pokedex.seen[("DEXMON_%03d"):format(n)] = true end
save.pokedex.owned.DEXMON_001 = true
local game = { data = data, save = save,
               stack = { push = function() end, pop = function() end,
                         top = function() end } }

local dex = PokedexMenu.new(game, {})
check(dex.items[1].ball == true, "row 1 is owned, so it carries the marker")
check(dex.items[2].ball ~= true, "row 2 is seen only, so it carries none")
dex:draw()

local ball
for _, d in ipairs(draws) do
  local path = d.img and d.img.path
  if type(path) == "string" and path:find("balls%.png") then ball = d end
end
check(ball ~= nil, "the owned marker blits the extracted PokeballTileGraphics")
eq(ball and ball.x, 24, "the marker sits in the column left of the name")
eq(ball and ball.y, 24, "on row 1's tile row")
eq(ball and ball.quad and ball.quad.x, 0, "tile 0 of the four-ball sheet")
eq(ball and ball.quad and ball.quad.y, 0, "top row of the sheet")
eq(ball and ball.quad and ball.quad.w, 8, "one 8x8 tile wide")
eq(ball and ball.quad and ball.quad.h, 8, "one 8x8 tile tall")
check(ball and ball.color[1] == 1 and ball.color[2] == 1 and ball.color[3] == 1,
      "the blit is untinted, so the tile keeps its own four shades")

local marker = 0
for _, p in ipairs(prims) do
  if not (p.shape == "rectangle" and p.x == 0 and p.y == 0
          and p.w == 160 and p.h == 144) then
    marker = marker + 1
  end
end
eq(marker, 0, "nothing but the screen clear is painted with vector primitives")

local name
for _, t in ipairs(texts) do
  if t.text == "MON001" and t.x == 32 then name = t end
end
check(name ~= nil, "row 1's name still prints")
check(name and name.color[1] == 0 and name.color[2] == 0 and name.color[3] == 0,
      "the marker restores black, so the names do not go white")

local balls = 0
for _, d in ipairs(draws) do
  local path = d.img and d.img.path
  if type(path) == "string" and path:find("balls%.png") then balls = balls + 1 end
end
eq(balls, 1, "one marker for the one owned mon on screen")

T.finish("pokedex ball tile bug 2067")
