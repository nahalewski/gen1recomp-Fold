-- BattleAnimView:fillBackground() used to draw a flat literal white
-- rectangle with no GbcPalette involvement, leaving a stark white gap
-- during the battle intro's slide-in under a custom COLORS ramp.
--
-- No real shader runs headless, so this asserts on which seam gets called
-- rather than on rendered pixels, same as every palette-seam test here.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

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
  local view = BattleAnimView.new({}, {})
  view:fillBackground()
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "BattleAnimView:fillBackground() reaches the GbcPalette seam")
end

-- Unthemed / no-shader boot must still degrade to the plain literal white
-- fill, byte-identical to before this fix.
do
  GbcPalette.available = function() return false end
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  local view = BattleAnimView.new({}, {})
  local ok = pcall(function() view:fillBackground() end)
  T.check(ok, "BattleAnimView:fillBackground() does not error with no shader")
  T.eq((calls.resolve or 0) + (calls.use or 0) + (calls.with or 0), 0,
    "BattleAnimView:fillBackground() does not touch GbcPalette with no shader")
end

T.finish()
