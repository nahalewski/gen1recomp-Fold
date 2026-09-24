local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local Screens = require("src.ui.Screens")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-forget"

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  local player = Mon.new(game.data, "TOTODILE", 30)
  assert(player, "could not build a TOTODILE")
  player.moves = {
    { id = "SURF", pp = 15, maxPp = 15 },
    { id = "SCRATCH", pp = 35, maxPp = 35 },
    { id = "LEER", pp = 30, maxPp = 30 },
    { id = "RAGE", pp = 20, maxPp = 20 },
  }
  game.save.party = { player }

  Screens.push(game, "Gen2MoveDeleter", {
    mon = player,
    moves = game.data.moves,
    layout = "forget",
    onChoose = function() game.stack:pop() end,
    onCancel = function() game.stack:pop() end,
  })
  U.wait(6)
  U.shot(game, out .. "/1980-overworld-list.png")
  U.tap(game, "down")
  U.wait(4)
  U.shot(game, out .. "/1980-overworld-list-row2.png")
  U.tap(game, "b")
  U.wait(6)

  assert(world:startBattle({ wild = Mon.new(game.data, "RATTATA", 5) }),
    "startBattle failed")
  local st
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then st = top break end
    U.wait(1)
  end
  assert(st and st.battle, "battle screen is not on the stack")
  for _ = 1, 1800 do
    if st.phase == "menu" then break end
    if (st.messageTimer or 0) > 0 and not st.anim then
      U.tap(game, "a")
    else
      U.wait(1)
    end
  end
  assert(st.phase == "menu", "battle never reached the command menu")

  st.pendingLearn = { index = 1, move = "ICE_PUNCH", moveName = "ICE PUNCH" }
  st.phase = "choose-forget"
  st.forgetIndex = 1
  st.messageTimer = 0
  st.message = "Which move should\nbe forgotten?"
  U.wait(6)
  U.shot(game, out .. "/1980-battle-list.png")
  U.tap(game, "down")
  U.wait(4)
  U.shot(game, out .. "/1980-battle-list-row2.png")

  st.forgetIndex = 1
  U.tap(game, "a")
  U.wait(6)
  U.shot(game, out .. "/1980-battle-hm-refusal.png")
  print("[driver] message after picking the HM slot: "
    .. tostring(st.message):gsub("\n", " / "))
  U.tap(game, "a")
  U.wait(6)
  U.shot(game, out .. "/1980-battle-list-reprint.png")

  print("[driver] PASS forget-move shots in " .. out)
  love.event.quit()
end
