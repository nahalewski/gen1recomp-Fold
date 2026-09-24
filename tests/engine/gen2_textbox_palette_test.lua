-- TextBox drew its box border and glyphs through Font.drawBox/drawCode
-- with a flat setColor, never touching GbcPalette, so dialogue text never
-- picked up a COLORS palette even though every other Chrome.lua-based
-- screen did.
--
-- No real shader runs headless, so this asserts on which seam gets called
-- rather than checking a rendered pixel; tests/drivers/gold_menu_shots.lua
-- is where a real box gets checked by eye.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local TextBox = require("src.render.TextBox")

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

local function newGame(generation)
  return {
    save = { player = { name = "RED" }, generation = generation,
             version = generation == 2 and "gold" or "red", options = {} },
    stringBuffer = "", boxNumString = "", boxMonNicks = {},
    data = {},
  }
end

do
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  local box = TextBox.new(newGame(2), "Hello world!", nil, {})
  box:draw()
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "Gen 2 dialogue box reaches the GbcPalette seam")
end

-- Gen 1 recolours through a whole-frame zone remap upstream of this file
-- (PaletteFX), not per draw call, so TextBox must not start touching
-- GbcPalette for a Gen 1 game.
do
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  local box = TextBox.new(newGame(1), "Hello world!", nil, {})
  box:draw()
  T.eq((calls.resolve or 0) + (calls.use or 0) + (calls.with or 0), 0,
    "Gen 1 dialogue box is untouched, it never calls GbcPalette")
end

T.finish()
