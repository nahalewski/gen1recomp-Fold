-- UnownWords:draw already routed its tile art through GbcPalette.with, but
-- drew the frame around it with a plain Font.drawBox, so the puzzle's own
-- glyphs picked up a selected COLORS palette while the box border stayed
-- white/black, the same shape of gap gen2_textbox_palette_test.lua found
-- in TextBox.lua. Fixed by routing the box through Chrome.paletteBox.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local UnownWords = require("src.world.gen2.UnownWords")

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

-- data/events/unown_walls.asm:15 MenuHeaders_UnownWalls's ESCAPE row, the
-- same fixture tests/gen2_unown_words_test.lua uses for boxRect.
local ESCAPE_WALL = { x1 = 3, y1 = 4, x2 = 16, y2 = 9,
                       chars = { 0x08, 0x44, 0x04, 0x00, 0x2e, 0x08 } }

do
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  -- no opts.world -> :tileset() returns nil -> draw() exits right after the
  -- box, isolating the box's own palette seam from the tile-art body wrap
  local words = UnownWords.new({}, { wall = ESCAPE_WALL })
  words:draw()
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "Unown wall box reaches the GbcPalette seam")
end

T.finish()
