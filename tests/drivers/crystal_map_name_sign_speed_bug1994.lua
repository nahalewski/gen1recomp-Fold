local U = require("tests.drivers.util")

-- ../pokecrystal/engine/events/map_name_sign.asm:41-44
local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

return function(game)
  local fails = 0

  local function say(line) print("[mapsign1994] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  local DESTS = {
    { "ROUTE_29", 10, 8, "left" },
    { "NEW_BARK_TOWN", 5, 6, "down" },
  }
  local nextDest = 1

  local function raise()
    local d = DESTS[nextDest]
    nextDest = nextDest % #DESTS + 1
    world:warpToMapId(d[1], d[2], d[3], d[4])
    for _ = 1, 240 do
      if world.mapSign then return true end
      U.wait(1)
    end
    return false
  end

  local function measure(speed)
    game.speedOverride = speed
    if not raise() then
      ok(false, speed .. "X: no sign came up to time")
      return nil
    end
    say(("%dX: game:logicSpeed() reports %s")
      :format(speed, tostring(game:logicSpeed())))
    -- ../pokecrystal/data/maps/setup_scripts.asm:32-56
    for _ = 1, 120 do
      if not world.mapSetup then break end
      U.wait(1)
    end
    local frames, t0 = 0, love.timer.getTime()
    local shownAt
    for _ = 1, 60 * 60 do
      if not world.mapSign then break end
      if world.mapSign.shown and not shownAt then shownAt = frames end
      U.wait(1)
      frames = frames + 1
    end
    local elapsed = love.timer.getTime() - t0
    say(("%dX: %d rendered frames (shown from %s), %.3f real seconds")
      :format(speed, frames, tostring(shownAt), elapsed))
    ok(world.mapSign == nil, speed .. "X: the sign expired")
    return frames, elapsed, shownAt
  end

  -- ../pokecrystal/engine/overworld/events.asm:177-191
  for _, speed in ipairs({ 1, 4, 10, 20, 200 }) do
    local frames, elapsed, shownAt = measure(speed)
    if frames then
      ok(math.abs(frames - 122) <= 6,
        ("%dX: %d rendered frames is within 6 of 122"):format(speed, frames))
      ok(elapsed >= 1.8 and elapsed <= 2.4,
        ("%dX: %.3fs of wall clock is the two-second hold"):format(speed, elapsed))
      ok(shownAt ~= nil and shownAt <= 6,
        ("%dX: the sign came on within the first HandleMap calls (frame %s)")
          :format(speed, tostring(shownAt)))
    end
  end

  game.speedOverride = 200
  if raise() then
    U.wait(60)
    ok(world.mapSign ~= nil and world.mapSign.shown,
      "200X: the banner is still up one real second in")
    U.shot(game, SHOT_DIR .. "/mapsign1994_200x_onesecond.png")
  else
    ok(false, "200X: no sign came up for the screenshot")
  end
  game.speedOverride = nil

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
