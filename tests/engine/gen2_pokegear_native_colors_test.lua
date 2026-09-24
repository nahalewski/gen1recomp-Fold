-- The Pokegear's six hardware palette banks guarantee a highlighted cell
-- contrasts with its text, a guarantee GbcPalette.resolve() breaks by
-- collapsing every bank onto the same 4 shades. Product decision: the
-- Pokegear stays on native hardware colours always, via a `raw` path
-- (GbcPalette.withRaw, Chrome.*Through's `raw` param, TileSheet's `raw`
-- option) that calls useRaw directly and skips resolve.
--
-- No real shader runs headless, so this asserts on which entry point gets
-- called rather than on rendered pixels.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local Chrome = require("src.ui.gen2.Chrome")
local TileSheet = require("src.ui.gen2.TileSheet")
local Pokegear = require("src.ui.gen2.Pokegear")

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

local BANK_1 = { { 227, 249, 227 }, { 180, 200, 180 }, { 90, 100, 90 },
                 { 0, 0, 0 } }

do
  calls = {}
  spy("resolve"); spy("useRaw")
  Pokegear.text({ pals = function() return { BANK_1 } end }, "SUNDAY", 6, 6)
  T.eq(calls.resolve or 0, 0,
    "Pokegear:text() never substitutes the active COLORS ramp")
  T.check((calls.useRaw or 0) > 0,
    "Pokegear:text() still shades its own native colours through the shader")
end

do
  local sheet = TileSheet.new({ palette = BANK_1, raw = true })
  -- No real image asset in the headless harness, so this exercises the
  -- option's plumbing (raw stored, read by :draw) rather than a full
  -- render; gen2_trainer_card_text_palette_test.lua and friends take the
  -- same "assert the seam, not the pixel" approach one level up.
  T.check(sheet.raw == true, "TileSheet:new stores the raw option")
end

-- A sheet built without raw must still go through the normal substituting
-- seam, guarding the new option from silently becoming the default for
-- every other Gen 2 screen's tile art.
do
  local sheet = TileSheet.new({ palette = BANK_1 })
  T.eq(sheet.raw, nil, "TileSheet:new defaults raw to unset")
end

T.finish()
