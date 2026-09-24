-- ../pokegold/engine/battle/battle_transition.asm:164
-- ../pokecrystal/engine/battle/start_battle.asm:15-35
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-speckle"
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[speckle2090] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the gen2 world did not boot")

  local lead = Mon.new(game.data, "CYNDAQUIL", 14)
  assert(lead, "could not build a CYNDAQUIL")
  game.save.party = { lead }

  ok((world.staleEnemyMonLevel or 0) == 0,
    "a fresh session has no leftover enemy level")

  local function waitBattleScreen()
    for _ = 1, 900 do
      local top = game.stack:top()
      if top and top.battle then return top end
      U.wait(1)
    end
    return nil
  end

  local function endBattle(screen)
    for _ = 1, 900 do
      if game.stack:top() ~= screen then break end
      screen.battle.enemy.hp = 0
      U.tap(game, "a")
      U.wait(2)
    end
    for _ = 1, 120 do
      if not world.battleActive then break end
      U.tap(game, "a")
      U.wait(2)
    end
  end

  local wild = Mon.new(game.data, "PIDGEY", 10)
  assert(wild, "could not build a wild PIDGEY")
  assert(world:startBattle({ wild = wild }), "the wild battle did not start")
  local screen = waitBattleScreen()
  assert(screen, "the wild battle screen never came up")
  endBattle(screen)
  U.wait(30)

  ok(world.staleEnemyMonLevel == 10,
    "the wild battle left its level behind: "
      .. tostring(world.staleEnemyMonLevel))

  local trainerMon = Mon.new(game.data, "RATTATA", 4)
  assert(trainerMon, "could not build the trainer's RATTATA")
  ok(world:startBattle({ trainer = {
    class = 1, classId = "YOUNGSTER", name = "YOUNGSTER JOEY",
    trainerName = "JOEY", className = "YOUNGSTER",
    party = { trainerMon },
  } }), "the trainer battle started")

  local transition
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.style and top.phase then
      transition = top
      break
    end
    U.wait(1)
  end
  ok(transition ~= nil, "the transition screen came up")
  if transition then
    ok(transition.style == "speckle",
      "the second battle picked the speckle outro: "
        .. tostring(transition.style))
    local shot = 0
    for _ = 1, 1200 do
      if game.stack:top() ~= transition then break end
      if transition.phase == "outro" then
        shot = shot + 1
        U.shot(game, out .. ("/outro-%02d.png"):format(shot))
        if shot >= 4 then break end
        U.wait(6)
      else
        U.wait(1)
      end
    end
    ok(shot > 0, "shot the outro mid-speckle, see " .. out)
  end

  print(("[speckle2090] done, %d failures"):format(fails))
  U.wait(30)
  love.event.quit(fails == 0 and 0 or 1)
end
