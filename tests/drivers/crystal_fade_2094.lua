local U = require("tests.drivers.util")
local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-fade2094"
  os.execute("mkdir -p '" .. out .. "'")
  local shotN = 0
  local function shot(tag)
    shotN = shotN + 1
    U.shot(game, string.format("%s/%03d_%s.png", out, shotN, tag))
  end
  local fails = 0
  local function ok(cond, msg)
    if cond then
      print("[fade2094] ok   " .. msg)
    else
      fails = fails + 1
      print("[fade2094] FAIL " .. msg)
    end
    return cond
  end

  U.wait(60)
  local world = game.world
  if not ok(world and world.map, "booted into the overworld") then
    error("fade2094: no world")
  end
  local save, data = game.save, game.data

  save.party = { Mon.new(data, "CYNDAQUIL", 12) }

  world.mapScenes = world.mapScenes or {}
  world.mapScenes.NEW_BARK_TOWN = 1
  world:warpToMapId("NEW_BARK_TOWN", 13, 7, "up")
  for _ = 1, 60 do
    if not world:busy() then break end
    U.wait(1)
  end
  U.wait(10)
  ok(world.map.id == "NEW_BARK_TOWN", "standing outside the player's house")
  shot("town")

  U.hold(game, "up", 24)
  local entered = false
  for _ = 1, 90 do
    U.wait(1)
    shot("door_in")
    if world.map and world.map.id == "PLAYERS_HOUSE_1F"
        and not world:busy() then
      entered = true
      break
    end
  end
  ok(entered, "the door warp finished (watch the shots for the 4-step wash)")
  U.wait(10)
  shot("inside")

  U.hold(game, "down", 4)
  local exited = false
  for _ = 1, 90 do
    U.wait(1)
    shot("door_out")
    if world.map and world.map.id == "NEW_BARK_TOWN"
        and not world:busy() then
      exited = true
      break
    end
  end
  ok(exited, "the way back out finished")
  U.wait(10)
  shot("outside")

  local wild = Mon.new(data, "SENTRET", 3)
  ok(world:startBattle({ wild = wild }), "a wild battle starts")
  for _ = 1, 360 do
    U.wait(1)
    if shotN < 260 then shot("battle_wipe") end
    local top = game.stack:top()
    if top and top.screenId == "Gen2BattleState" then break end
  end
  local top = game.stack:top()
  ok(top and top.screenId == "Gen2BattleState", "the battle screen is up")
  U.wait(240)
  shot("battle_menu")

  local popped = false
  local function waitShooting(frames)
    for _ = 1, frames do
      U.wait(1)
      local t = game.stack:top()
      if not (t and t.screenId) then
        if not popped then
          popped = world.mapSetup ~= nil or world.fade ~= nil
        end
        shot("battle_return")
      end
    end
  end
  for _ = 1, 12 do
    U.tap(game, "a")
    waitShooting(20)
    top = game.stack:top()
    if not (top and top.screenId) then break end
    U.tap(game, "down")
    U.wait(4)
    U.tap(game, "right")
    U.wait(4)
    U.tap(game, "a")
    waitShooting(30)
    U.tap(game, "a")
    waitShooting(30)
    top = game.stack:top()
    if not (top and top.screenId) then break end
  end
  for _ = 1, 240 do
    top = game.stack:top()
    if not (top and top.screenId) then break end
    U.tap(game, "a")
    waitShooting(10)
  end
  ok(popped, "the battle popped into the return fade")
  for _ = 1, 20 do
    shot("battle_return")
    U.wait(1)
  end
  ok(world.mapSetup == nil and world.fade == nil,
    "the return fade ran its eight frames and cleared")
  shot("done")

  print(string.format("[fade2094] %s (%d shots in %s)",
    fails == 0 and "ALL OK" or (fails .. " FAILURES"), shotN, out))
end
