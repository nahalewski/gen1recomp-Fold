-- engine/battle/core.asm:2396
--   SHOT_DIR=/tmp/shots POKEPORT_DRIVER=tests/drivers/battle_already_out_bug1953_test.lua love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  game.save.party = {
    Pokemon.new(game.data, "CHARMANDER", 12),
    Pokemon.new(game.data, "SQUIRTLE", 10),
  }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local ow = game.overworld

  local battle = BattleState.newWild(game, "PIDGEY", 8)
  battle.onFinish = function() end
  ow:pushBattle(battle)

  for _ = 1, 120 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(4)
  end
  U.log("battle phase:", battle.phase)

  local pm
  for _ = 1, 20 do
    local top = game.stack:top()
    if top and top.onSwitch ~= nil and top.index ~= nil then pm = top break end
    U.tap(game, "right"); U.wait(6)
    U.tap(game, "a"); U.wait(14)
  end
  U.log("party open:", pm ~= nil, "keepOpen:", pm and pm.keepOpen)
  if not pm then return end

  U.tap(game, "a"); U.wait(8) -- SWITCH / STATS / CANCEL
  U.tap(game, "a"); U.wait(90) -- SWITCH on the mon already out
  U.shot(game, DIR .. "/already_out_1_refusal.png")
  local top = game.stack:top()
  U.log("list still up:", top ~= pm and pm.submenu == nil)
  U.log("battle screen not back:", top ~= battle)

  for _ = 1, 6 do
    if game.stack:top() == pm then break end
    U.tap(game, "a"); U.wait(20)
  end
  U.shot(game, DIR .. "/already_out_2_list.png")
  U.log("back on the list:", game.stack:top() == pm)

  U.tap(game, "down"); U.wait(6)
  U.tap(game, "a"); U.wait(10)
  U.tap(game, "a"); U.wait(60)
  U.shot(game, DIR .. "/already_out_3_switched.png")
  U.log("picker closed:", game.stack:top() ~= pm)
end
