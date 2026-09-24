-- UI LETTERBOX (save.options.uiLetterbox): what fills the window around a
-- 160x144 screen. AUTO keeps what each screen was authored with, so the
-- default is byte-identical to the look before the option existed.
--   luajit tests/engine/ui_letterbox_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Letterbox = require("src.render.Letterbox")

T.eq(require("src.core.SaveData").newGame().options.uiLetterbox, "auto",
  "Gen 1 starts on AUTO")
T.eq(require("src.core.gen2.Save").DEFAULT_OPTIONS.uiLetterbox, "auto",
  "so does Gen 2")

-- AUTO hands back the colour the caller was authored with, untouched: the
-- Pokedex stays black, a menu stays white, the naming screen stays paper.
Letterbox.setMode("auto")
T.same({ Letterbox.fill(0, 0, 0) }, { 0, 0, 0 }, "AUTO keeps an authored black")
T.same({ Letterbox.fill(1, 1, 1) }, { 1, 1, 1 }, "AUTO keeps an authored white")
T.same({ Letterbox.fill(0.5, 0.25, 0.75) }, { 0.5, 0.25, 0.75 },
  "AUTO keeps an authored paper colour")

-- PALETTE reads the caller's paper, because the two generations keep a picked
-- ramp in different modules. Gen 1 used to come back white here: anything that
-- sniffed for GbcPalette found it present on Gen 1 too and answered with Gen
-- 2's white default instead of PaletteFX's actual paper.
Letterbox.setMode("palette")
T.same({ Letterbox.fill(0, 0, 0, function() return 0.25, 0.5, 1 end) },
  { 0.25, 0.5, 1 }, "PALETTE takes the caller's paper")
T.same({ Letterbox.fill(0, 0, 0) }, { 0, 0, 0 },
  "with no paper reader it falls back to the authored colour, never to white")
T.same({ Letterbox.fill(1, 1, 1, function() return nil end) }, { 1, 1, 1 },
  "and a reader that cannot answer falls back too")

Letterbox.setMode("black")
T.same({ Letterbox.fill(1, 1, 1) }, { 0, 0, 0 }, "BLACK overrides a white screen")
Letterbox.setMode("white")
T.same({ Letterbox.fill(0, 0, 0) }, { 1, 1, 1 }, "WHITE overrides a black screen")

-- An unknown or absent value degrades to AUTO rather than to a colour, so a
-- save written before the option existed keeps its look.
T.eq(Letterbox.normalize(nil), "auto", "no stored value is AUTO")
T.eq(Letterbox.normalize("nonsense"), "auto", "and so is a value we cannot read")
Letterbox.setMode(nil)
T.same({ Letterbox.fill(0, 0, 0) }, { 0, 0, 0 }, "so an old save is unchanged")

-- The ladder wraps both ways, like every other option row.
T.eq(Letterbox.cycle("auto", 1), "black", "right steps off AUTO")
T.eq(Letterbox.cycle("palette", 1), "auto", "and wraps at the end")
T.eq(Letterbox.cycle("auto", -1), "palette", "left wraps back")
for _, id in ipairs(Letterbox.MODES) do
  T.check(Letterbox.label(id) ~= nil, id .. " has a label")
end
T.eq(Letterbox.label("uiLetterbox"), "AUTO", "an unknown id still labels")

-- applyOptions is the seam both Game:applyOptions and Game2:applyOptions call.
Letterbox.applyOptions({ uiLetterbox = "white" })
T.eq(Letterbox.mode, "white", "applyOptions installs the saved mode")
Letterbox.applyOptions({})
T.eq(Letterbox.mode, "auto", "and an options table without one is AUTO")

Letterbox.setMode("auto")
T.finish("ui letterbox")
