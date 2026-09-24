-- engine/battle/core.asm:339, :416, :454
-- engine/battle/trainer_ai.asm:290-320, :357-362, :453-456
--   POKEPORT_DRIVER=tests/drivers/brock_full_heal_bug2076_test.lua \
--     POKEPORT_IDENTITY=red-sep01 POKEPORT_VERSION=red POKEPORT_TOUCH=0 \
--     SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  game.save.party = { Pokemon.new(game.data, "BUTTERFREE", 50) }
  U.teleport(game, "PEWTER_GYM", 4, 3, "up")
  U.wait(20)
  local ow = game.overworld
  check("the overworld is up", ow ~= nil)

  local battle = BattleState.newTrainer(game, "OPP_BROCK", 1)
  battle.onFinish = function() end
  ow:pushBattle(battle)
  for _ = 1, 900 do
    if game.stack:top() == battle and (battle.introSlide or 0) == 0 then break end
    U.wait(1)
  end
  check("the battle reached the screen", game.stack:top() == battle)
  check("BROCK carries five FULL HEALs (wAICount)", battle.aiUses == 5)

  battle.player.curMoves = { { id = "TOXIC", pp = 10 } }

  local function textNow()
    local c = battle.current
    return c and c.text or nil
  end

  local sawStatus, sawHeal = false, false
  for _ = 1, 3000 do
    if battle.phase == "menu" then U.tap(game, "a") end
    if battle.enemy.mon.status then sawStatus = true end
    local t = textNow()
    if t and t:find("FULL HEAL", 1, true) then sawHeal = true break end
    U.tap(game, "a")
    U.wait(2)
  end
  check("TOXIC put a status on GEODUDE", sawStatus)
  check("BROCK answered with a FULL HEAL", sawHeal)
  U.shot(game, DIR .. "/brock2076_1_full_heal.png")
  check("the status is gone (AICureStatus)", battle.enemy.mon.status == nil)
  check("a use was spent (DecrementAICount)", battle.aiUses == 4)

  U.wait(30)
  battle.enemy.mon.status = "PSN"
  battle.enemy.bideTurns = 2
  battle.enemy.bideDamage = 0
  local before = battle.enemy.bideTurns
  local healedInBide = false
  for _ = 1, 3000 do
    if battle.phase == "menu" then U.tap(game, "a") end
    local t = textNow()
    if t and t:find("FULL HEAL", 1, true) then healedInBide = true break end
    U.tap(game, "a")
    U.wait(2)
  end
  check("the FULL HEAL still fires mid-Bide", healedInBide)
  U.shot(game, DIR .. "/brock2076_2_bide_heal.png")
  check("the Bide counter did not advance", battle.enemy.bideTurns == before)

  U.log("Shots: " .. DIR .. "/brock2076_*.png")
  U.log("Shot 1 must read 'BROCK used FULL HEAL on GEODUDE!' on the turn")
  U.log("TOXIC landed, not a turn later. Shot 2 is the same message with")
  U.log("the foe mid-Bide. Broken looked like Brock never using an item at")
  U.log("all, and never once while Onix was biding.")

  while true do coroutine.yield() end
end
