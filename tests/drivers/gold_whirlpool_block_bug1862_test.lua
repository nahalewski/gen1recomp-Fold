-- #1862: the whirlpool must stay on screen for the whole surf wash.
-- DisappearWhirlpool blanks hBGMapMode before the redraw, plays the sound and
-- only then buffers the screen -- engine/events/overworld.asm:1150-1165,
-- engine/events/field_moves.asm:5-10.  No POKEPORT_SPEED: audio runs on its
-- own real-time accumulator and the ordering is the whole point.
--   POKEPORT_IDENTITY=c10-gold POKEPORT_GAME=gold POKEPORT_TOUCH=0 POKEPORT_DRIVER=tests/drivers/gold_whirlpool_block_bug1862_test.lua POKEPORT_SHOT_DIR=/tmp/gold-bug1862 love .
local U = require("tests.drivers.util")

local FieldMoves = require("src.world.gen2.FieldMoves")
local Mon = require("src.battle.gen2.Mon")
local Permissions = require("src.world.gen2.Permissions")

-- data/generated/maps.lua, ROUTE_41: whirlpools at (22,12), (42,24), (6,30)
-- and (28,48).  Stand one cell north of the first and face it.
local MAP = "ROUTE_41"
local WHIRL = { x = 22, y = 12 }

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-bug1862"
  local fails, lines = 0, {}
  local function claim(ok, text)
    if not ok then fails = fails + 1 end
    lines[#lines + 1] = (ok and "PASS " or "FAIL ") .. text
    return ok
  end
  local function report()
    for _, line in ipairs(lines) do U.log(line) end
    U.log(("%d checks, %d failed"):format(#lines, fails))
  end

  U.wait(45)
  local world = game.world
  if not (world and world.map) then
    U.log("FAIL the gold world never booted, nothing to drain")
    while true do coroutine.yield() end
  end

  local vol = game.save.options and game.save.options.sfxVol
  claim(vol ~= 0, ("SFX VOL is %s"):format(tostring(vol)))
  if vol == 0 then
    U.log("SFX VOL is ZERO, so the wash this is timed against is inaudible;")
    U.log("turn it up in OPTION before judging anything by ear.")
  end

  local badges = game.save.player.badges or {}
  game.save.player.badges = badges
  for _, badge in pairs(FieldMoves.BADGE) do badges[badge] = true end
  local swimmer = Mon.new(game.data, "LAPRAS", 30,
    { moves = { { id = "SURF" }, { id = "WHIRLPOOL" } } })
  claim(swimmer ~= nil, "a LAPRAS that knows SURF and WHIRLPOOL")
  game.save.party = { swimmer }

  world:applyPlayerState(FieldMoves.PLAYER_SURF)
  world:setMap(MAP, WHIRL.x, WHIRL.y - 1, "down")
  U.wait(15)
  world.noWildEncounters = true

  local ctx = world:fieldContext()
  local facing = Permissions.isWhirlpool(ctx.facingColl)
  if not facing then
    -- A re-import moved it: take any whirlpool with open water above it.
    local def = world.maps[MAP]
    for y = 1, (def.height or 0) * 2 - 1 do
      for x = 0, (def.width or 0) * 2 - 1 do
        if not facing and Permissions.isWhirlpool(world.map:cellCollision(x, y))
           and Permissions.isWater(world.map:cellCollision(x, y - 1)) then
          WHIRL.x, WHIRL.y = x, y
          world:setMap(MAP, x, y - 1, "down")
          world:applyPlayerState(FieldMoves.PLAYER_SURF)
          U.wait(10)
          ctx = world:fieldContext()
          facing = Permissions.isWhirlpool(ctx.facingColl)
          U.log(("note: using the whirlpool at (%d,%d)"):format(x, y))
        end
      end
    end
  end
  claim(facing, ("facing the whirlpool at (%d,%d) on %s"):format(
    WHIRL.x, WHIRL.y, MAP))
  local blocks = world.maps[MAP] and world.maps[MAP].blocks
  local index = ctx.facingBlockIndex
  local before = blocks and index and blocks[index]
  claim(before ~= nil, "and the block behind it is readable")
  if not (facing and before) then
    report()
    U.log("nothing to drive; stopping rather than faking the moment")
    while true do coroutine.yield() end
  end
  U.shot(game, out .. "/01-facing.png")

  local function tap(button, gap)
    table.insert(game.input.pressQueue, button)
    game.input.state[button] = true
    coroutine.yield()
    game.input.state[button] = false
    for _ = 1, (gap or 8) do coroutine.yield() end
  end

  -- A into the whirlpool, then A through the ask box (YES is the default) and
  -- the USED WHIRLPOOL line.
  for _ = 1, 24 do
    if world.fieldMove and world.fieldMove.phase == "whirlpoolsfx" then break end
    tap("a")
  end
  claim(world.fieldMove and world.fieldMove.phase == "whirlpoolsfx",
    "the drain reached PlayWhirlpoolSound")
  claim(blocks[index] == before,
    "the whirlpool is still in the block buffer as the wash starts")
  U.shot(game, out .. "/02-wash-starts.png")

  local swapped, phaseFrames = nil, 0
  for _ = 1, 300 do
    if world.fieldMove and world.fieldMove.phase == "whirlpoolsfx" then
      phaseFrames = phaseFrames + 1
      if blocks[index] ~= before and not swapped then swapped = phaseFrames end
      if phaseFrames == 6 then U.shot(game, out .. "/03-mid-wash.png") end
    end
    if not world:busy() then break end
    coroutine.yield()
  end
  claim(swapped == nil,
    "and it stayed there for every frame of the wash")
  claim(blocks[index] ~= before,
    "the block was swapped once the wash ended")
  claim(phaseFrames > 0 and phaseFrames < 180,
    ("the wash ended on its own after %d frames"):format(phaseFrames))
  U.wait(4)
  U.shot(game, out .. "/04-drained.png")

  report()
  if fails > 0 then
    U.log("a FAIL above means the run is not showing what it claims to")
  end
  U.log("what right looks like: the whirlpool keeps spinning through the whole")
  U.log("surf wash and only pops out of the water when the sound has finished.")
  U.log("water where the whirlpool was while the wash is still playing is the")
  U.log("bug; a whirlpool still there after control comes back is the overshoot.")
  U.log("the pad is yours -- the other whirlpools are further south.")

  while true do coroutine.yield() end
end
