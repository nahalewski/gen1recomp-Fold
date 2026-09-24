local U = require("tests.drivers.util")
local GameVersion = require("src.core.GameVersion")

-- ../pokecrystal/maps/CeladonMansionRoof.asm:1
local MAP = "CELADON_MANSION_ROOF"
local STAIR_X, STAIR_Y = 1, 1

return function(game)
  local fails = 0

  local function say(line) print("[roof1964] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the gen 2 world did not boot")
    love.event.quit(1)
    return
  end

  local version = GameVersion.get()
  say("version " .. tostring(version))

  world.noWildEncounters = true
  world:warpToMapId(MAP, STAIR_X, STAIR_Y, "down")
  U.wait(90)
  ok(world.map and world.map.id == MAP, "arrived at " .. MAP)
  say(("after the staircase: (%d,%d)"):format(
    world.player.cellX, world.player.cellY))
  ok(world.player.cellY > STAIR_Y, "the stairs step the player onto the roof")

  U.hold(game, "right", 60)
  U.wait(30)
  say(("after holding right: (%d,%d)"):format(
    world.player.cellX, world.player.cellY))
  ok(world.player.cellX > STAIR_X, "and he can walk right off the stairs")
  if version == "crystal" then
    ok(world.player.cellX == 4, "the $b0 railing stops him at x=4")
  end

  U.hold(game, "down", 60)
  U.wait(30)
  say(("after holding down: (%d,%d)"):format(
    world.player.cellX, world.player.cellY))
  ok(world.player.cellY > 2, "the railing column walks down")

  U.shot(game, (os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots")
    .. "/mansion_roof_1964.png")

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
