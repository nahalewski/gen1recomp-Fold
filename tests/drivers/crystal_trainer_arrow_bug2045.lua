local U = require("tests.drivers.util")

-- ../pokecrystal/maps/Route30.asm:426 TrainerYoungsterMikey
local MIKEY_MAP, MIKEY_X, MIKEY_Y = "ROUTE_30", 5, 24
local CYNDAQUIL = 155

local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

return function(game)
  local fails = 0
  local function say(line) print("[2045] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map and world.vm) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  game.save.party = {}
  world.vm.givePokeFn(CYNDAQUIL, 10, 0, nil)
  U.wait(5)
  ok(game.save.party[1] ~= nil, "the player has a mon to battle with")

  world:warpToMapId(MIKEY_MAP, MIKEY_X, MIKEY_Y, "up")
  U.wait(60)
  ok(world.map and world.map.def and world.map.def.id == MIKEY_MAP,
    "standing on Route 30 in front of Youngster Mikey")

  U.tap(game, "a")
  U.wait(90)

  local top = game.stack and game.stack:top()
  local isBox = top and top.isTextBox
  ok(isBox, "the trainer's seen text is up")
  if isBox then
    ok(top.waitButton == true, "the box carries WaitButton semantics")
    ok(not top:arrowVisible(), "and prints no blinking cursor")
  end
  U.shot(game, SHOT_DIR .. "/2045_trainer_seen.png")
  say("eyeball 2045_trainer_seen.png: no arrow in the bottom-right cell, "
    .. "and A starts the battle with no beep")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
