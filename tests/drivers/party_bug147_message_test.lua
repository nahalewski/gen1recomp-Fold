-- Driver: party menu bottom context message (#147).
--   Gen1 (pokered engine/menus/party_menu.asm PartyMenuMessage) always prints
--   the bottom text box message (core.asm:2315, #1901).
--   The recomp handled only the swap / item / TM-HM ids and printed NOTHING for
--   the default field and battle voluntary-switch cases -- reporter's "NO TEXT
--   BOX".  This driver opens the party menu in both contexts, screenshots each,
--   and asserts PartyMenu:bottomMessage() returns the correct Gen1 string.
--   POKEPORT_DRIVER=tests/drivers/party_bug147_message_test.lua \
--     POKEPORT_IDENTITY=bug147 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Screens = require("src.ui.Screens")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
  end

  game.save.party = {
    Pokemon.new(game.data, "CHARMANDER", 12),
    Pokemon.new(game.data, "SQUIRTLE", 10),
  }

  -- FIELD case: party menu opened from the overworld (StartMenu path).
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local ow = game.overworld
  Screens.push(game, "PartyMenu")
  U.wait(8)
  U.shot(game, DIR .. "/party_field_message.png")
  local pm = game.stack:top()
  local fieldMsg = pm and pm.bottomMessage and pm:bottomMessage()
  U.log("field bottomMessage:", tostring(fieldMsg))
  check("field message == 'Choose a POKéMON.'",
        fieldMsg == "Choose a POKéMON.")

  -- back to the overworld before starting the battle
  while game.stack:top() and game.stack:top() ~= ow do game.stack:pop() end
  U.wait(2)

  -- BATTLE case: voluntary PKMN switch (BattleState:openParty).
  local battle = BattleState.newWild(game, "PIDGEY", 8)
  battle.onFinish = function() end
  ow:pushBattle(battle)

  local function mashUntil(cond, max)
    for _ = 1, max or 200 do
      if cond() then return true end
      U.tap(game, "a")
      for _ = 1, 4 do
        if cond() then return true end
        U.wait(1)
      end
    end
    return cond()
  end
  check("reached battle menu", mashUntil(function()
    return battle.phase == "menu"
  end))

  -- FIGHT/PKMN/ITEM/RUN: RIGHT to PKMN, then A to open the party
  U.tap(game, "right"); U.wait(4)
  U.tap(game, "a"); U.wait(12)
  U.shot(game, DIR .. "/party_battle_message.png")
  pm = game.stack:top()
  local battleMsg = pm and pm.bottomMessage and pm:bottomMessage()
  U.log("battle party open (onSwitch set):", pm and pm.onSwitch ~= nil)
  U.log("battle bottomMessage:", tostring(battleMsg))
  check("voluntary battle message == 'Choose a POKéMON.'",
        battleMsg == "Choose a POKéMON.")

  local forced = require("src.ui.PartyMenu").new(game, {
    battle = battle, party = game.save.party, forceSwitch = true,
    onSwitch = function() end,
  })
  local forcedMsg = forced:bottomMessage()
  U.log("forced-switch bottomMessage:", tostring(forcedMsg))
  check("forced switch message == 'Bring out which\\nPOKéMON?'",
        forcedMsg == "Bring out which\nPOKéMON?")

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
