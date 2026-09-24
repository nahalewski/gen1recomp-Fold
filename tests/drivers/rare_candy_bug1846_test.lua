-- Rare Candy's "grew to level N!" line carries a jingle (#1846): pokered's
-- RareCandyText is text_far _RareCandyText / sound_get_item_1 /
-- text_promptbutton (engine/menus/party_menu.asm:289-293), and outside
-- battle that command plays SFX_GET_ITEM_1 (home/text.asm:546).
--   POKEPORT_DRIVER=tests/drivers/rare_candy_bug1846_test.lua POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local Bag = require("src.inventory.Bag")
  local Sound = require("src.core.Sound")
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
  Bag.add(game.save, "RARE_CANDY", 3, game.data)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  local heard = {}
  local realPlay = Sound.play
  Sound.play = function(data, name, ...)
    heard[#heard + 1] = name
    return realPlay(data, name, ...)
  end

  -- bag -> RARE CANDY -> USE -> the only party member
  Screens.push(game, "BagMenu", {})
  U.wait(12)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")
  U.wait(12)
  local level = mon.level
  U.tap(game, "a")
  U.wait(40)

  Sound.play = realPlay
  check("the candy raised the level", mon.level == level + 1)
  U.log("sounds heard:", table.concat(heard, " "))
  local jingle = false
  for _, name in ipairs(heard) do
    if name == "Get_Item1" then jingle = true end
  end
  check("the level line carried SFX_GET_ITEM_1", jingle)

  U.shot(game, SHOT_DIR .. "/bug1846_rare_candy.png")
  U.log("captured", SHOT_DIR .. "/bug1846_rare_candy.png")

  U.log("NIDORINO grew to level 21 just now: the short item fanfare should")
  U.log("sound as that line finishes typing, and the box waits for A after")
  U.log("it. Silence there is the bug. The other near-miss is the longer")
  U.log("level-up fanfare, which only belongs to a candy used in battle.")
  U.log("Two candies are left in the bag to hear it again.")

  while true do
    coroutine.yield()
  end
end
