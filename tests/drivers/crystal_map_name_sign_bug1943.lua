local U = require("tests.drivers.util")

-- ../pokecrystal/engine/events/map_name_sign.asm:3
local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

return function(game)
  local fails = 0

  local function say(line) print("[mapsign1943] " .. line) end
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

  local function go(mapId, x, y, facing)
    world:warpToMapId(mapId, x, y, facing)
    U.wait(20)
  end

  -- ../pokecrystal/engine/menus/intro_menu.asm:69-70
  go("NEW_BARK_TOWN", 5, 6, "down")
  ok(world.mapSign == nil, "the boot landmark raises no sign")
  U.shot(game, SHOT_DIR .. "/mapsign1943_newbark.png")

  go("ROUTE_29", 10, 8, "left")
  ok(world.mapSign ~= nil, "crossing into ROUTE 29 raises a sign")
  if world.mapSign then say("name: " .. tostring(world.mapSign.name)) end
  U.shot(game, SHOT_DIR .. "/mapsign1943_route29.png")

  go("ROUTE_29", 12, 8, "left")
  ok(world.mapSign == nil, "a second load in the same landmark shows nothing")
  U.shot(game, SHOT_DIR .. "/mapsign1943_same_landmark.png")

  go("ROUTE_35_NATIONAL_PARK_GATE", 4, 6, "up")
  ok(world.mapSign == nil, "the national park gate is forced to -1")
  U.shot(game, SHOT_DIR .. "/mapsign1943_park_gate.png")

  go("ROUTE_43_GATE", 4, 4, "up")
  ok(world.mapSign == nil, "a GATE environment gets no sign")

  go("CHERRYGROVE_CITY", 20, 10, "down")
  ok(world.mapSign ~= nil, "CHERRYGROVE CITY raises a sign")
  U.shot(game, SHOT_DIR .. "/mapsign1943_cherrygrove.png")
  for _ = 1, 61 do U.wait(1) end
  ok(world.mapSign == nil, "and it is gone 60 frames later")
  U.shot(game, SHOT_DIR .. "/mapsign1943_expired.png")

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
