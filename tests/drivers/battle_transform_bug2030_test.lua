-- animation ahead of the cart.  transform.asm:37-45 plays the animation
-- data/battle_anims/special_effect_pointers.asm:30), then copies the data
-- and prints _TransformedText (transform.asm:57-134).
--   POKEPORT_DRIVER=tests/drivers/battle_transform_bug2030_test.lua \
--     POKEPORT_IDENTITY=bug2030 POKEPORT_TOUCH=0 SHOT_DIR=/tmp/shots love .
--   BUG2030_ANIMS_OFF=1 POKEPORT_DRIVER=tests/drivers/battle_transform_bug2030_test.lua \
--     POKEPORT_IDENTITY=bug2030 POKEPORT_TOUCH=0 SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local animsOff = os.getenv("BUG2030_ANIMS_OFF") == "1"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  local tag = animsOff and "animoff" or "animon"
  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  game.save.options = game.save.options or {}
  game.save.options.animations = not animsOff
  U.log("issue #2030 -- TRANSFORM pic timing, animations",
        animsOff and "OFF" or "ON")

  game.save.party = { Pokemon.new(game.data, "PARASECT", 24) }
  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  U.wait(20)
  local ow = game.overworld
  check("the overworld is up", ow ~= nil)

  local battle = BattleState.newWild(game, "DITTO", 26)
  battle.onFinish = function() end
  ow:pushBattle(battle)
  for _ = 1, 600 do
    if game.stack:top() == battle and (battle.introSlide or 0) == 0 then break end
    U.wait(1)
  end
  check("the battle reached the screen", game.stack:top() == battle)

  battle.enemy.curMoves = { { id = "TRANSFORM", pp = 10 } }
  battle.player.curMoves = { { id = "GROWL", pp = 40 } }
  local dittoPic = battle.enemy.sprite
  local copiedPic = battle:speciesSprite(battle.player.mon.species, false)
  check("the enemy starts on the DITTO pic", dittoPic ~= nil)
  check("the PARASECT front pic is loadable", copiedPic ~= nil)
  check("they are different images, so the swap is visible",
        dittoPic ~= copiedPic)

  for _ = 1, 400 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(6)
  end
  check("the battle reached its FIGHT/PKMN/ITEM/RUN menu", battle.phase == "menu")

  U.tap(game, "a")
  U.wait(20)
  U.tap(game, "a")

  local function textNow()
    local c = battle.current
    return c and c.text or nil
  end
  local function waitForText(needle, frames)
    for _ = 1, frames do
      local t = textNow()
      if t and t:find(needle, 1, true) then return true end
      if battle.phase == "menu" then U.tap(game, "a") end
      U.wait(1)
    end
    return false
  end

  local sawUsed = waitForText("TRANSFORM!", 900)
  check("the 'used TRANSFORM!' page is on screen", sawUsed)
  local picAtAnnounce = battle.enemy.sprite
  U.shot(game, DIR .. "/bug2030_" .. tag .. "_1_announce.png")
  check("the enemy is STILL the DITTO blob while the move is announced (#2030)",
        picAtAnnounce == dittoPic)

  local sawTransformed = waitForText("transformed", 900)
  check("the '...transformed into...' page is on screen", sawTransformed)
  U.wait(2)
  U.shot(game, DIR .. "/bug2030_" .. tag .. "_2_transformed.png")
  check("the enemy is the copied species by then",
        battle.enemy.sprite == copiedPic)

  U.log("Shots: " .. DIR .. "/bug2030_" .. tag .. "_*.png")
  U.log("Shot 1 (the announcement) must still be the pink DITTO blob; the")
  U.log("black blocks of the animation only start after it. Shot 2 must be")
  U.log("PARASECT. Broken looked like PARASECT in BOTH shots. The near miss")
  U.log("to watch for is the swap landing mid-animation instead of on its")
  U.log("last row -- the blob should still be a blob under the green ring.")
  U.log("Run again with BUG2030_ANIMS_OFF=1 for the OPTION -> ANIMATION OFF")
  U.log("path: there is no animation to watch, but the pic must still hold")
  U.log("the blob through the announcement and swap before 'transformed'.")
  U.log("The pad is yours -- GROWL keeps the DITTO alive, so you can watch")
  U.log("it again on the next turn.")

  while true do coroutine.yield() end
end
