local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

-- pokecrystal maps/MoveDeletersHouse.asm:9-14

return function(game)
  local shots = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"
  local fails = 0
  local function say(line) print("[2095] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world, save = game.world, game.save
  if not (world and world.map and save) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end
  save.party = { Mon.new(game.data, "CYNDAQUIL", 30) }
  world:warpToMapId("MOVE_DELETERS_HOUSE", 2, 4, "up")
  U.wait(30)
  ok(world.map and world.map.id == "MOVE_DELETERS_HOUSE",
    "standing in the MOVE DELETER's house")

  U.tap(game, "a")
  U.wait(120)
  U.shot(game, shots .. "/2095_page1.png")
  U.wait(120)
  U.shot(game, shots .. "/2095_page1_still.png")

  U.tap(game, "a")
  U.wait(60)
  U.shot(game, shots .. "/2095_page2.png")

  U.tap(game, "a")
  U.wait(60)
  U.shot(game, shots .. "/2095_page3_yesno.png")

  U.tap(game, "down")
  U.wait(10)
  U.tap(game, "a")
  U.wait(60)
  U.shot(game, shots .. "/2095_declined.png")

  U.tap(game, "a")
  U.wait(30)

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
