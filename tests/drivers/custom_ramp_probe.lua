-- Diagnostic probe: forces a loud custom COLORS ramp (hot pink paper, blue
-- ink) and shoots StartMenu, PartyMenu, and PackMenu, so a gap between
-- those screens and the rest of the UI can be checked by eye.
--
--   POKEPORT_GAME=gold POKEPORT_DRIVER=tests/drivers/custom_ramp_probe.lua love .
local U = require("tests.drivers.util")

local GbcPalette = require("src.render.GbcPalette")
local StartMenu = require("src.ui.gen2.StartMenu")
local PartyMenu = require("src.ui.gen2.PartyMenu")
local PackMenu = require("src.ui.gen2.PackMenu")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/custom-ramp-probe"

  local function shot(name)
    U.wait(3)
    U.shot(game, ("%s/%s.png"):format(out, name))
  end

  local function show(name, state)
    game.stack:push(state)
    shot(name)
    game.stack:pop()
  end

  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")

  print("[driver] GbcPalette.available() = " .. tostring(GbcPalette.available()))

  GbcPalette.setCustomRamp({
    { 255, 100, 220 }, { 220, 60, 180 }, { 140, 20, 120 }, { 20, 0, 60 },
  })
  print("[driver] customRamp set, mode=" .. tostring(GbcPalette.mode))

  local save = game.save
  save.party = save.party or {}
  save.inventory = { POTION = 5, SUPER_POTION = 2, ANTIDOTE = 1 }

  show("01-startmenu-custom-ramp", StartMenu.new(game, { save = save }))
  show("02-party-custom-ramp", PartyMenu.new(game, { prompt = "choose" }))
  show("03-pack-items-custom-ramp", PackMenu.new(game, { pocket = "ITEM" }))

  print("[driver] PASS custom ramp probe shots in " .. out)
end
