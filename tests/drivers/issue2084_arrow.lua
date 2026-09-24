local U = require("tests.drivers.util")

local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

return function(game)
  local function say(line) print("[2084] " .. line) end
  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the gen2 world did not boot")
    love.event.quit(1)
    return
  end

  -- pokegold maps/DayCare.asm:71
  world:warpToMapId("DAY_CARE", 3, 3, "left")
  U.wait(45)
  say("talking to the Day Care man")
  U.tap(game, "a")
  U.wait(40)
  U.shot(game, SHOT_DIR .. "/2084_man_a.png")
  U.wait(16)
  U.shot(game, SHOT_DIR .. "/2084_man_b.png")
  say("expect the arrow at tile 18,17 in exactly one of the two man shots")
  for _ = 1, 8 do
    U.tap(game, "a")
    U.wait(20)
  end

  -- pokegold maps/DayCare.asm:72
  world:warpToMapId("DAY_CARE", 4, 3, "right")
  U.wait(30)
  say("talking to the Day Care lady")
  U.tap(game, "a")
  U.wait(40)
  U.shot(game, SHOT_DIR .. "/2084_lady_a.png")
  U.wait(16)
  U.shot(game, SHOT_DIR .. "/2084_lady_b.png")
  say("expect the arrow at tile 18,17 in exactly one of the two lady shots")
  for _ = 1, 8 do
    U.tap(game, "a")
    U.wait(20)
  end

  say("done; shots in " .. SHOT_DIR)
  love.event.quit(0)
end
