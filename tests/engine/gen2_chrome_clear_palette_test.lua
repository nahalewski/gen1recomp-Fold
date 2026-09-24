-- Chrome.clear() is the base background wipe ~30 opaque Gen 2 menu screens
-- start their frame with. It used to draw a flat literal white rectangle,
-- never touching GbcPalette, so every screen's background stayed white
-- regardless of a picked COLORS palette even though its boxes and text
-- already recoloured correctly.
--
-- No real shader runs headless, so this can't check a rendered pixel, same
-- limitation gen2_textbox_palette_test notes: force GbcPalette.available()
-- true and assert on which seam gets called, not on pixels.
-- tests/drivers/gold_menu_shots.lua is where a real rendered screen gets
-- checked by eye.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local Chrome = require("src.ui.gen2.Chrome")

local calls
local function spy(name)
  local original = GbcPalette[name]
  GbcPalette[name] = function(...)
    calls[name] = (calls[name] or 0) + 1
    return original(...)
  end
end

do
  GbcPalette.available = function() return true end
  GbcPalette.setCustomRamp({ { 255, 0, 255 }, { 200, 0, 200 }, { 100, 0, 100 },
                              { 0, 0, 0 } })
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  Chrome.clear()
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "Chrome.clear() reaches the GbcPalette seam when a shader is available")
end

-- Unthemed / no-shader boot must still degrade to the plain literal white
-- wipe, byte-identical to before this fix, same guard Chrome.paletteBox
-- already takes.
do
  GbcPalette.available = function() return false end
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  local ok = pcall(Chrome.clear)
  T.check(ok, "Chrome.clear() does not error with no shader available")
  T.eq((calls.resolve or 0) + (calls.use or 0) + (calls.with or 0), 0,
    "Chrome.clear() does not touch GbcPalette when no shader is available")
end

T.finish()
