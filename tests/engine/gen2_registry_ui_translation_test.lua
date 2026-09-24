-- Runtime coverage for the registry-adjacent Gen 2 labels.  The Python
-- harvest test proves the keys enter a translation scaffold; this suite proves
-- that loading such a catalog changes what the actual screens draw.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")
require("src.core.Logger").warn = function() end

local Chrome = require("src.ui.gen2.Chrome")
local MainMenu = require("src.ui.gen2.MainMenu")
local PokedexMenu = require("src.ui.gen2.PokedexMenu")
local Pokegear = require("src.ui.gen2.Pokegear")
local Strings = require("src.core.Strings")

Strings.load({ strings = {
  AM = "MATIN", PM = "SOIR", DAY = "JOUR",
  [" PAGE AREA CRY PRNT"] = " PAGE ZONE CRI IMPR",
  lb = "liv", ["%s'S NEST"] = "NID DE %s",
  ["Press any button to exit."] = "Appuyez pour sortir.",
} })

-- MainMenu_PrintCurrentTimeAndDay: the clock box now goes through
-- MainMenu.timeString/InitClock.hourString (../pokecrystal/engine/menus/
-- main_menu.asm:286), whose MORN/DAY/NITE word -- not AM/PM -- is
-- Clock.daytimeLabel's own translated DAYTIME_LABEL entry; the no-weekday
-- fallback moved down one row (14 -> 15) with the box's own reposition.
do
  local oldPrint, oldTextbox = Chrome.print, Chrome.textbox
  local drawn = {}
  Chrome.print = function(text, x, y) drawn[x .. ":" .. y] = text end
  Chrome.textbox = function() end
  local menu = MainMenu.new({}, { hasSave = false, save = false,
    clock = { hour = 13, minute = 5, weekday = 99 } })
  menu:drawClockBox()
  T.eq(drawn["1:15"], "JOUR", "the main-menu DAY fallback is translated")
  T.eq(drawn["4:16"], "JOUR 1:05",
    "the main-menu daytime word (DAY, not PM) is translated")
  Chrome.print, Chrome.textbox = oldPrint, oldTextbox
end

-- Pokegear_UpdateClock uses the same keys in the styled card path.
do
  local gear = Pokegear.new({ data = {} }, {
    save = {}, clock = { hour = 1, minute = 2, weekday = 99 },
  })
  local drawn = {}
  gear.drawTilemap = function() end
  gear.drawStrip = function() end
  gear.cursor = function() end
  gear.textbox = function() end
  gear.printBoxText = function() end
  gear.text = function(_, text, x, y) drawn[x .. ":" .. y] = text end
  gear:drawClock()
  T.eq(drawn["12:8"], "MATIN", "the Pokegear AM half is translated")
  T.eq(gear:phoneText("PressButton"), "Appuyez pour sortir.",
    "a complete built-in Pokegear prompt is translated")
end

-- DexEntryScreen's action strip is one ROM string rather than four invented
-- fragments.  The unit and the grammatical nest title resolve independently.
do
  local save = { pokedex = { seen = { BULBASAUR = true }, caught = {} } }
  local game = { save = save, data = {
    pokemon = { BULBASAUR = { name = "BULBIZARRE" } },
    gen2Pokedex = { entries = {
      BULBASAUR = { dex = 1, kind = "GRAINE", height = 204, weight = 150 },
    }, newOrder = { "BULBASAUR" } },
  } }
  local dex = PokedexMenu.new(game, {})
  local drawn = {}
  dex.text = function(_, text, x, y) drawn[x .. ":" .. y] = text end
  dex.fill = function() end
  dex.border = function() end
  dex.tile = function() end
  dex.blank = function() end
  dex.drawPic = function() end
  dex.drawFootprint = function() end
  dex.cursorVisible = function() return false end
  dex:drawEntryBody(dex:current(), game.data.gen2Pokedex.entries.BULBASAUR)
  T.eq(drawn["1:17"], " PAGE ZONE CRI IMPR",
    "the complete Pokedex action strip is translated")
  T.eq(drawn["17:9"], "liv", "the Pokedex weight unit is translated")

  local title
  dex.drawAreaHeader = function(_, text) title = text end
  dex.areaBlink = 0
  dex:drawArea()
  T.eq(title, "NID DE BULBIZARRE",
    "the Pokedex nest template supports grammatical reordering")
end

Strings.load(nil)
T.finish()
