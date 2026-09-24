-- Chrome.List:draw() backs nearly every Gen 2 menu's row text, but drew
-- each row through flat, hardcoded-black Chrome.print/cursor, so rows
-- stayed black-on-white even though the box behind them recoloured. Fixed
-- by giving List a `palette` option that routes rows through
-- printThrough/cursorThrough.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local Chrome = require("src.ui.gen2.Chrome")

GbcPalette.available = function() return true end
GbcPalette.setCustomRamp({ { 255, 0, 255 }, { 200, 0, 200 }, { 100, 0, 100 },
                            { 0, 0, 0 } })

local calls
local function spy(name)
  local original = GbcPalette[name]
  GbcPalette[name] = function(...)
    calls[name] = (calls[name] or 0) + 1
    return original(...)
  end
end

do
  local list = Chrome.List.new({ items = { "POKEMON", "PACK", "QUIT" }, x = 2, y = 2 })
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  list:draw()
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "Chrome.List:draw() reaches the GbcPalette seam by default")
end

-- A caller that explicitly opts out (palette = false) keeps the old flat
-- black draw untouched by GbcPalette.
do
  local list = Chrome.List.new({ items = { "A", "B" }, x = 2, y = 2, palette = false })
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  list:draw()
  T.eq((calls.resolve or 0) + (calls.use or 0) + (calls.with or 0), 0,
    "Chrome.List:draw() with palette = false does not touch GbcPalette")
end

-- The scroll-hint down arrow, drawn only when the list is longer than its
-- visible rows, must also go through the palette rather than a bare
-- Font.drawCode.
do
  local items = {}
  for i = 1, 5 do items[i] = "ITEM " .. i end
  local list = Chrome.List.new({ items = items, x = 2, y = 2, rows = 2 })
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  list:draw()
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "Chrome.List:draw()'s scroll-hint arrow reaches the GbcPalette seam")
end

T.finish()
