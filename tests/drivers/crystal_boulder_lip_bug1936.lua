local U = require("tests.drivers.util")
local World = require("src.world.gen2.World")

-- ../pokecrystal/maps/MountMortarB1F.asm:150
local MAP = "MOUNT_MORTAR_B1F"
local START_X, START_Y = 9, 9
local LIP_Y = 12

return function(game)
  local fails = 0

  local function say(line) print("[boulder1936] " .. line) end
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

  world:warpToMapId(MAP, START_X, START_Y, "down")
  U.wait(60)
  ok(world.map and world.map.id == MAP, "arrived at " .. MAP)

  world.strengthActive = true
  world.noWildEncounters = true

  local boulder
  for _, npc in ipairs(world.npcs or {}) do
    if World.isStrengthBoulder(npc) then boulder = npc end
  end
  ok(boulder ~= nil, "the Strength boulder spawned")
  if not boulder then love.event.quit(1) return end

  local lowest = boulder.cellY
  for _ = 1, 12 do
    U.hold(game, "down", 24)
    U.wait(24)
    if boulder.cellY > lowest then lowest = boulder.cellY end
  end

  say(("boulder rests at (%d,%d); player at (%d,%d)"):format(
    boulder.cellX, boulder.cellY, world.player.cellX, world.player.cellY))
  ok(lowest < LIP_Y, "the boulder never crossed the $b2 lip at y=" .. LIP_Y)
  ok(boulder.cellY == 11, "it stops on the cell above the lip")
  ok(world.player.cellY < boulder.cellY, "and the player is bumping into it")

  U.shot(game, "/tmp/pokeport-shots/boulder1936.png")

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
