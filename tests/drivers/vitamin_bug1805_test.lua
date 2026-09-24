-- Vitamins (#1805): pokered's .useVitamin plays SFX_HEAL_AILMENT, then
-- prints VitaminStatRoseText over the still-drawn party menu and ends at
-- RemoveUsedItem, which only strips the item from the bag
-- (engine/items/item_effects.asm:1313-1322, :2274).
--   POKEPORT_DRIVER=tests/drivers/vitamin_bug1805_test.lua POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local Bag = require("src.inventory.Bag")
  local Sound = require("src.core.Sound")
  local PartyMenu = require("src.ui.PartyMenu")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  if (game.save.options and game.save.options.sfxVol or 1) == 0 then
    U.log("WARNING: sfxVol is 0, so nothing here can be heard.")
    U.log("WARNING: set SFX volume in OPTION before judging this driver.")
  end

  local mon = Pokemon.new(game.data, "NIDORINO", 20)
  game.save.party = { mon }
  game.save.player.name = "bryan"
  game.save.inventory = {}
  Bag.add(game.save, "HP_UP", 3, game.data)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  local heard = {}
  local realPlay = Sound.play
  Sound.play = function(data, name, ...)
    heard[#heard + 1] = name
    return realPlay(data, name, ...)
  end

  -- bag -> HP UP -> USE -> the only party member
  Screens.push(game, "BagMenu", {})
  U.wait(12)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")
  U.wait(30)

  Sound.play = realPlay
  check("the vitamin was consumed", (game.save.inventory.HP_UP or 0) == 2)
  check("HP stat exp went up", (mon.statExp and mon.statExp.hp or 0) == 2560)
  U.log("sounds heard:", table.concat(heard, " "))
  local jingle = false
  for _, name in ipairs(heard) do
    if name == "Heal_Ailment" then jingle = true end
  end
  check("the stat line carried SFX_HEAL_AILMENT", jingle)

  local partyUp = false
  for _, s in ipairs(game.stack.states or {}) do
    if getmetatable(s) == PartyMenu then partyUp = true end
  end
  check("the party menu is still drawn under the message", partyUp)

  U.shot(game, SHOT_DIR .. "/bug1805_vitamin.png")
  U.log("captured", SHOT_DIR .. "/bug1805_vitamin.png")

  U.log("NIDORINO's HEALTH rose just now: the short cure jingle should sound")
  U.log("as that line types, with the party list still on screen behind the")
  U.log("box, and only then does the menu come down. The bug was silence")
  U.log("plus the list vanishing to the map the instant A was pressed.")
  U.log("Two HP UPs are left in the bag to try it again.")

  while true do
    coroutine.yield()
  end
end
