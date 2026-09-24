-- The Game Corner price columns (PrizeMenu.lua) are right-aligned against a
-- fixed priceRight column per counter; a translated prize name longer than
-- the tile budget before that column would otherwise overlap or run into
-- the price digits Chrome.print draws right after it, since the name and
-- price are now two separate draw calls (#1642-adjacent). This drives
-- drawPanel() with an over-long name via a mod's strings override and
-- checks the drawn name never crosses into the price column.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
love = require("tests.love_stub")
require("src.core.Logger").warn = function() end

local drawn
package.loaded["src.ui.gen2.Chrome"] = setmetatable({
  print = function(text, x, y) drawn[#drawn + 1] = { text = text, x = x, y = y } end,
  clear = function() end,
  textbox = function() end,
  cursor = function() end,
}, { __index = require("src.ui.gen2.Chrome") })

local PrizeMenu = require("src.ui.gen2.PrizeMenu")
local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
Strings.load({ strings = { ["MR.MIME"] = "A NAME MUCH LONGER THAN THE COUNTER ROW" } })

local counter = PrizeMenu.COUNTERS.CELADON_MON
local prize = counter.prizes[1] -- MR.MIME, cost 3333
drawn = {}
local self = setmetatable({
  save = {}, phase = "menu", index = 1, counter = counter,
  prizes = { prize }, text = {},
}, PrizeMenu)
self:drawPanel()

-- drawn[1..2] are drawCoinBox()'s COIN label and coin count.
local nameDraw, priceDraw = drawn[3], drawn[4]
T.check(nameDraw and nameDraw.text:find("^A NAME"), "the translated name is drawn")
T.check(#nameDraw.text <= counter.priceRight - #tostring(prize.cost) - 2,
  "the drawn name is clamped to the tile budget before the price column")
T.eq(priceDraw and priceDraw.text, "3333", "the price still draws in full")
T.check(priceDraw.x > nameDraw.x + #nameDraw.text,
  "the price column starts after the clamped name ends")

-- The redrawn text must never exceed the tile budget either: byte length
-- alone is not the right measure once a macro is involved (see below).
T.check(#Font.split(nameDraw.text) <= counter.priceRight - #tostring(prize.cost) - 2,
  "the drawn name's glyph width (not byte length) fits the tile budget")

-- Font.split's "#" macro expands to four glyphs (POKé) from one source
-- byte; a naive byte-position cut lands inside that expansion and still
-- copies the whole "#" byte, which re-expands past the budget on redraw.
-- Position it so exactly one tile is free where the whole four-glyph
-- macro would be needed.
Strings.load({ strings = { ["EEVEE"] = "AAAAAAAAA#EXTRA" } })
drawn = {}
local eevee = counter.prizes[2] -- EEVEE, cost 6666
local self2 = setmetatable({
  save = {}, phase = "menu", index = 1, counter = counter,
  prizes = { eevee }, text = {},
}, PrizeMenu)
self2:drawPanel()
local macroNameDraw = drawn[3]
local macroBudget = counter.priceRight - #tostring(eevee.cost) - 2
T.check(macroNameDraw and macroNameDraw.text == ("A"):rep(9),
  "a macro straddling the budget is dropped whole, not cut mid-expansion")
T.check(#Font.split(macroNameDraw.text) <= macroBudget,
  "the macro-adjacent name's glyph width fits the tile budget after redraw")

Strings.load(nil)
T.finish("prize_counter_name_clamp_test")
