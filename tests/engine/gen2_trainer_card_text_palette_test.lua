-- TrainerCard had two palette gaps: its own text drew through flat
-- Chrome.print/cursor, fixed with a print/:cursor pair routed through
-- printThrough/cursorThrough via self:colorsAt; and drawPanel() painted
-- the screen with a flat white rectangle before anything else, leaving the
-- NAME/ID/MONEY/STATUS/BADGES interiors white, fixed by routing that fill
-- through Chrome.paletteFill.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local TrainerCard = require("src.ui.gen2.TrainerCard")
local Strings = require("src.core.Strings")

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

local function fakeCard()
  return {
    colorsAt = function() return { { 255, 255, 255 }, { 200, 0, 200 },
                                    { 100, 0, 100 }, { 0, 0, 0 } } end,
  }
end

do
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  TrainerCard.print(fakeCard(), "NAME/", 2, 2)
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "TrainerCard:print() reaches the GbcPalette seam via self:colorsAt")
end

do
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  TrainerCard.cursor(fakeCard(), 18, 15)
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "TrainerCard:cursor() reaches the GbcPalette seam via self:colorsAt")
end

-- drawPanel() painted the whole screen with a flat white rectangle before
-- drawing the card, and self:frame only draws border tiles, so panel
-- interiors stayed white regardless of the picked palette. drawCard is
-- stubbed here to isolate that base fill from the print/cursor seam
-- covered above.
do
  local fake = { styled = function() return true end, page = 1,
                 drawCard = function() end }
  calls = {}
  spy("resolve"); spy("use"); spy("with")
  TrainerCard.drawPanel(fake)
  T.check((calls.resolve or 0) > 0 or (calls.use or 0) > 0 or (calls.with or 0) > 0,
    "TrainerCard:drawPanel()'s base fill reaches the GbcPalette seam")
end

-- Text labels are catalog-backed, while the player's chosen name is content
-- and must remain verbatim.
do
  local Chrome = require("src.ui.gen2.Chrome")
  local priorPrintThrough = Chrome.printThrough
  local printed = {}
  Chrome.printThrough = function(text) printed[#printed + 1] = text end
  Strings.load({ strings = {
    ["NAME/"] = "NOM/", MONEY = "ARGENT", ["POKéDEX"] = "DEX-FR",
    ["PLAY TIME"] = "TEMPS", BADGES = "BADGES-FR", GOLD = "INTERDIT",
  } })
  TrainerCard.drawPlain({
    page = 1,
    save = { player = { name = "GOLD", id = 7, money = 12 }, playTime = {} },
    caughtCount = function() return 0 end,
  })
  local all = table.concat(printed, "|")
  T.check(all:find("NOM/", 1, true) and all:find("ARGENT", 1, true)
      and all:find("DEX-FR", 1, true) and all:find("TEMPS", 1, true),
    "Trainer Card's finite labels pass through Strings")
  T.check(all:find("GOLD", 1, true) and not all:find("INTERDIT", 1, true),
    "the player's name stays raw")
  Strings.load({})
  Chrome.printThrough = priorPrintThrough
end

-- Badge names are finite UI labels too; unlike the player's name above they
-- must be looked up when the page is drawn (and then shortened to four chars).
do
  local Chrome = require("src.ui.gen2.Chrome")
  local priorPrintThrough = Chrome.printThrough
  local printed = {}
  Chrome.printThrough = function(text) printed[#printed + 1] = text end
  Strings.load({ strings = {
    ["JOHTO BADGES"] = "BADGES JOHTO",
    ZEPHYR = "ÉCLAIR",
  } })
  TrainerCard.drawPlain({
    page = 2,
    save = { player = { badges = { ZEPHYR = true } } },
  })
  local all = table.concat(printed, "|")
  T.check(all:find("BADGES JOHTO", 1, true) and all:find("ÉCLA", 1, true),
    "Trainer Card translates and clips badge names on font-glyph boundaries")
  Strings.load({})
  Chrome.printThrough = priorPrintThrough
end

T.finish()
