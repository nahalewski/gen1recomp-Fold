-- The Pokédex list was a generic ListMenu with a title and a footer instead
-- of the cart's CONTENTS screen, and Left/Right dragged the cursor with the
-- page (#1829).
-- engine/menus/pokedex.asm:161-199 (furniture), :242-273 (rows), :314-342
-- (Left/Right move wListScrollOffset only), :208-222 (wDexMaxSeenMon).
--   luajit tests/engine/pokedex_contents_bug1829.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

-- stub Font: the screen draws through Font.draw/Font.drawCode only, and the
-- real Font needs loaded page images this suite has no reason to touch.
local calls = {}
package.loaded["src.render.Font"] = {
  draw = function(text, x, y) calls[#calls + 1] = { text = text, x = x, y = y } end,
  drawCode = function(code, x, y) calls[#calls + 1] = { code = code, x = x, y = y } end,
  width = function(text) return #text * 8 end,
  split = function(text)
    local out = {}
    for i = 1, #text do out[i] = { from = i, to = i } end
    return out
  end,
}

local PokedexMenu = require("src.ui.PokedexMenu")
local Theme = require("src.ui.Theme")

local function hasText(text, x, y)
  for _, c in ipairs(calls) do
    if c.text == text and c.x == x and c.y == y then return true end
  end
  return false
end
local function hasCode(code, x, y)
  for _, c in ipairs(calls) do
    if c.code == code and c.x == x and c.y == y then return true end
  end
  return false
end

local DEX_SIZE = 151
local data = {
  pokemon = {},
  constants = { dexSize = DEX_SIZE, dexDigits = 3 },
}
for n = 1, DEX_SIZE do
  local id = ("DEXMON_%03d"):format(n)
  data.pokemon[id] = { id = id, name = ("MON%03d"):format(n), dex = n }
end

-- seen 1..20, owned 1..3, so the list stops at 20 and row 2 carries a ball
local function newGame()
  local save = { pokedex = { seen = {}, owned = {} } }
  for n = 1, 20 do save.pokedex.seen[("DEXMON_%03d"):format(n)] = true end
  for n = 1, 3 do save.pokedex.owned[("DEXMON_%03d"):format(n)] = true end
  return { data = data, save = save,
           stack = { push = function() end, pop = function() end,
                     top = function() end } }
end

local dex = PokedexMenu.new(newGame(), {})

-- ------------------------------------------------ wDexMaxSeenMon caps it
eq(#dex.items, 20, "the list stops at the highest seen number, not at 151")
eq(dex.items[20].name, "MON020", "the last row is the highest seen species")

-- ------------------------------------------------ Left / Right scroll only
dex.index, dex.scroll = 3, 0
dex:pageScroll(1)
eq(dex.scroll, 7, "Right pages the scroll offset down seven rows")
eq(dex.index - dex.scroll, 3, "the cursor keeps the screen row it was on")
dex:pageScroll(1)
eq(dex.scroll, 13, "the second page clamps to wDexMaxSeenMon - 7")
eq(dex.index - dex.scroll, 3, "the clamped page still keeps the cursor row")
dex:pageScroll(-1)
eq(dex.scroll, 6, "Left pages back seven rows")
eq(dex.index - dex.scroll, 3, "Left keeps the cursor row too")
dex:pageScroll(-1)
eq(dex.scroll, 0, "Left stops at the top of the list")
eq(dex.index, 3, "the cursor is back where it started")

-- the witness for the bug: a whole-page jump used to move the cursor to the
-- bottom row, which is what a page jump on any other list does
check(dex.index - dex.scroll ~= 7,
      "the cursor did not slide to the last screen row (the ListMenu bug)")

-- ------------------------------------------------------------- the screen
dex.index, dex.scroll = 1, 0
calls = {}
dex:draw()
check(hasText("CONTENTS", 8, 8), "CONTENTS at hlcoord 1,1, not a POKéDEX title")
check(hasText("SEEN", 128, 16), "SEEN label at hlcoord 16,2")
check(hasText("20", 136, 24), "the seen count right-aligned in its 3-tile field")
check(hasText("OWN", 128, 40), "OWN label at hlcoord 16,5")
check(hasText("3", 144, 48), "the owned count right-aligned under it")
check(not hasText("SEEN  20  OWN   3", 8, 136),
      "the counts are not a bottom footer line any more")
check(hasText("DATA", 128, 80) and hasText("CRY", 128, 96)
      and hasText("AREA", 128, 112) and hasText("QUIT", 128, 128),
      "DATA/CRY/AREA/QUIT are permanent furniture at hlcoord 16,10")

check(hasText("001", 8, 16), "row 1's number sits one row above its name")
check(hasText("MON001", 32, 24), "row 1's name is at column 4")
check(hasCode(Theme.cursor, 0, 24), "the cursor is at column 0 on row 3")
check(hasText("007", 8, 112) and hasText("MON007", 32, 120),
      "seven rows, two tiles apart, end on row 15")
check(not hasText("MON008", 32, 136), "there is no eighth row")

-- the hollow ▷ pokered leaves under the side menu (PlaceUnfilledArrowMenuCursor)
dex.hollowIndex = 1
calls = {}
dex:draw()
check(hasCode(Theme.cursorHollow, 0, 24),
      "the chosen row keeps a hollow cursor while the side menu is open")

-- ------------------------------------------------------ unseen dashed rows
local partial = newGame()
partial.save.pokedex.seen.DEXMON_005 = nil
local gapped = PokedexMenu.new(partial, {})
eq(gapped.items[5].name, "----------",
   "an unseen number inside the range prints the dashed line")
check(gapped.items[5].value == nil, "and cannot be chosen")

T.finish("pokedex contents bug 1829")
