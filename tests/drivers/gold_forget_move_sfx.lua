local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  local player = Mon.new(game.data, "TOTODILE", 30)
  assert(player, "could not build a TOTODILE")
  player.moves = {
    { id = "SCRATCH", pp = 35, maxPp = 35 },
    { id = "LEER", pp = 30, maxPp = 30 },
    { id = "RAGE", pp = 20, maxPp = 20 },
    { id = "WATER_GUN", pp = 25, maxPp = 25 },
  }
  game.save.party = { player }

  print("[driver] overworld learn: listen for the poof at 'Poof!',"
    .. " then the fanfare at 'learned'")
  local learned = nil
  game:learnMoveOn(player, "ICE_PUNCH", function(ok) learned = ok end)

  local list
  for _ = 1, 200 do
    local top = game.stack:top()
    if top and top.forget then list = top break end
    U.tap(game, "a")
    U.wait(8)
  end
  assert(list, "the forget-move list never appeared")
  U.wait(10)
  U.tap(game, "a")

  U.wait(150)
  for _ = 1, 200 do
    if learned ~= nil then break end
    U.tap(game, "a")
    U.wait(10)
  end
  assert(learned == true, "the overworld learn did not finish")
  U.wait(30)

  print("[driver] battle learn: same two sounds, in-battle message path")
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

  st.pendingLearn = { index = 1, move = "MEGA_PUNCH", moveName = "MEGA PUNCH" }
  st.phase = "choose-forget"
  st.forgetIndex = 1
  st.messageTimer = 0
  st.message = "Which move should\nbe forgotten?"
  U.wait(10)
  U.tap(game, "a")
  for _ = 1, 120 do
    if (st.messageTimer or 0) > 0 then
      U.tap(game, "a")
      U.wait(12)
    else
      U.wait(1)
    end
  end

  print("[driver] PASS both learn paths shown; verify poof + fanfare by ear")
  U.wait(60)
  love.event.quit()
end
