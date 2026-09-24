-- engine/overworld/player_movement.asm:93-110
local U = require("tests.drivers.util")

local Permissions = require("src.world.gen2.Permissions")

return function(game)
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/bump-anim-1978"
  local fails = 0
  local function say(line) print("[1978] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the gen2 world did not boot")
    love.event.quit(1)
    return
  end

  world:warpToMapId("CHERRYGROVE_CITY", 20, 10, "down")
  U.wait(45)
  local p = world.player
  local map = world.map

  local px, py
  for y = 0, (map.height or 9) * 2 - 1 do
    for x = 0, (map.width or 20) * 2 - 2 do
      if Permissions.isWalkable(map:cellCollision(x, y))
          and not Permissions.isWalkable(map:cellCollision(x + 1, y)) then
        px, py = x, y
        break
      end
    end
    if px then break end
  end
  if not px then
    say("FAIL no cell with a wall to its east")
    love.event.quit(1)
    return
  end
  world:warpToMapId("CHERRYGROVE_CITY", px, py, "right")
  U.wait(45)
  say("bumping east from " .. px .. "," .. py)

  local phases, moved = {}, false
  local shots = {}
  for f = 1, 40 do
    table.insert(game.input.pressQueue, "right")
    game.input.state.right = true
    coroutine.yield()
    if p.moving then moved = true end
    phases[p:walkPhase()] = true
    if f == 4 or f == 20 then
      shots[#shots + 1] = DIR .. "/1978-frame" .. f .. ".png"
      U.shot(game, shots[#shots])
    end
  end
  game.input.state.right = false
  ok(not moved, "the wall never let the step start")
  ok(phases[0] and phases[1],
    "both the standing and the walking pose were drawn while stuck")
  ok(#shots == 2, "captured the two poses")

  U.wait(2)
  -- engine/overworld/player_movement.asm:108
  ok(p:walkPhase() == 0, "the pose stands on the frame after the release")
  ok((p.bumpFrames or 0) == 0, "with no bump left to run out")
  U.wait(40)
  ok(p:walkPhase() == 0, "and stays standing")

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
