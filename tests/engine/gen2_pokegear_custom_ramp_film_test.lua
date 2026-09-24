-- Follow-up to gen2_pokegear_native_colors_test.lua's "keep the gear
-- vanilla" fix: CLASSIC swept the native-coloured gear for free, so this
-- extends the same whole-panel tint to a picked custom COLORS ramp, with
-- Pokegear.CUSTOM_RAMP_FILM = false as an easy revert.
--
-- No real shader/asset loads headless, so this isolates drawPanel()'s new
-- branch with a minimal fake self, same "stub the rest, assert the seam"
-- approach as the TrainerCard drawPanel() test.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local Pokegear = require("src.ui.gen2.Pokegear")

GbcPalette.available = function() return true end

local calls
local function spy(name)
  local original = GbcPalette[name]
  GbcPalette[name] = function(...)
    calls[name] = (calls[name] or 0) + 1
    return original(...)
  end
end

local function hits()
  return (calls.resolve or 0) + (calls.use or 0) + (calls.useRaw or 0)
    + (calls.with or 0)
end

local function fakeGear()
  return {
    styled = function() return true end,
    groundColor = function() return { 0, 0, 0 } end,
    card = function() return { id = "clock" } end,
    drawClock = function() end,
    drawMap = function() end,
    drawRadio = function() end,
    drawPhone = function() end,
    drawModeArrow = function() end,
  }
end

do
  Pokegear.CUSTOM_RAMP_FILM = true
  GbcPalette.setCustomRamp({ { 227, 249, 227 }, { 180, 200, 180 },
                              { 90, 100, 90 }, { 0, 0, 0 } })
  calls = {}
  spy("resolve"); spy("use"); spy("useRaw"); spy("with")
  Pokegear.drawPanel(fakeGear())
  T.check(hits() > 0,
    "with the film on and a custom ramp active, drawPanel() reaches GbcPalette")
end

do
  Pokegear.CUSTOM_RAMP_FILM = false
  GbcPalette.setCustomRamp({ { 227, 249, 227 }, { 180, 200, 180 },
                              { 90, 100, 90 }, { 0, 0, 0 } })
  calls = {}
  spy("resolve"); spy("use"); spy("useRaw"); spy("with")
  Pokegear.drawPanel(fakeGear())
  T.eq(hits(), 0,
    "Pokegear.CUSTOM_RAMP_FILM = false is a one-line revert to fully native")
end

do
  Pokegear.CUSTOM_RAMP_FILM = true
  GbcPalette.setCustomRamp(nil)
  calls = {}
  spy("resolve"); spy("use"); spy("useRaw"); spy("with")
  Pokegear.drawPanel(fakeGear())
  T.eq(hits(), 0,
    "with no custom ramp picked, the film never engages -- native GEN 2 stays untouched")
end

Pokegear.CUSTOM_RAMP_FILM = true

T.finish()
