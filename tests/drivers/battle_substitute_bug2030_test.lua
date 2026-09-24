-- ../pokered/engine/battle/move_effects/substitute.asm:2-3, :47-55
-- ../pokered/engine/battle/animations.asm:1936-1973
--   POKEPORT_DRIVER=tests/drivers/battle_substitute_bug2030_test.lua \
--     POKEPORT_IDENTITY=red-aug28 POKEPORT_VERSION=red POKEPORT_TOUCH=0 \
--     SHOT_DIR=/tmp/shots love .
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
  U.log("SUBSTITUTE doll timing, animations", animsOff and "OFF" or "ON")

  game.save.party = { Pokemon.new(game.data, "PARASECT", 40) }
  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  U.wait(20)
  local ow = game.overworld
  check("the overworld is up", ow ~= nil)

  local battle = BattleState.newWild(game, "RATTATA", 5)
  battle.onFinish = function() end
  ow:pushBattle(battle)
  for _ = 1, 600 do
    if game.stack:top() == battle and (battle.introSlide or 0) == 0 then break end
    U.wait(1)
  end
  check("the battle reached the screen", game.stack:top() == battle)

  battle.player.curMoves = { { id = "SUBSTITUTE", pp = 10 } }
  battle.enemy.curMoves = { { id = "TAIL_WHIP", pp = 30 } }

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

  local sawUsed = waitForText("SUBSTITUTE!", 900)
  check("the 'used SUBSTITUTE!' page is on screen", sawUsed)
  U.shot(game, DIR .. "/sub2030_" .. tag .. "_1_announce.png")
  check("the substitute is up in RAM", battle.player.substituteHP ~= nil)
  check("but the doll is not on screen yet (#2030)",
        battle.player.substitutePending == true)
  check("so the pic slot still reports the mon's own pic",
        battle:faintPicKind(battle.player) == "pic")

  U.wait(40)
  U.shot(game, DIR .. "/sub2030_" .. tag .. "_2_hold.png")

  local sawDoll = false
  for _ = 1, 900 do
    if not battle.player.substitutePending then sawDoll = true break end
    U.wait(1)
  end
  check("the doll lands with the animation", sawDoll)
  U.wait(2)
  U.shot(game, DIR .. "/sub2030_" .. tag .. "_3_doll.png")
  check("and the pic slot reports the doll",
        battle:faintPicKind(battle.player) == "doll")

  local sawCreated = waitForText("created", 900)
  check("'It created a SUBSTITUTE!' prints after the doll", sawCreated)
  U.shot(game, DIR .. "/sub2030_" .. tag .. "_4_created.png")

  U.log("Shots: " .. DIR .. "/sub2030_" .. tag .. "_*.png")
  U.log("Shot 1 (the announcement) must still be the PARASECT back pic.")
  U.log("Shot 2 is 40 frames later: with animations ON that is the 50-frame")
  U.log("entry hold or the slide-off, never the doll. Shot 3 is the doll,")
  U.log("shot 4 the doll under 'It created a SUBSTITUTE!'. Broken looked")
  U.log("like the doll in ALL FOUR shots, with no slide-off at all.")

  while true do coroutine.yield() end
end
