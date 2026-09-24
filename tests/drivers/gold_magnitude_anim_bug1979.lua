local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-magnitude"

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  local player = Mon.new(game.data, "CYNDAQUIL", 40)
  assert(player, "could not build a CYNDAQUIL")
  player.moves = { { id = "MAGNITUDE", pp = 30, maxPp = 30 } }
  game.save.party = { player }
  local wild = Mon.new(game.data, "RATTATA", 30)
  assert(world:startBattle({ wild = wild }), "startBattle failed")

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
  U.tap(game, "a")
  for _ = 1, 120 do
    if st.phase == "moves" then break end
    U.wait(1)
  end
  assert(st.phase == "moves", "FIGHT never opened the move list")
  U.tap(game, "a")

  local badFrames, animOnNumber, sawUsedLine, sawNumberLine = 0, false, false, false
  local shotUsed, shotNumber = false, false
  local lastMsg
  for _ = 1, 1200 do
    local msg = st.message or ""
    local anim = st.anim ~= nil
    if msg ~= lastMsg then
      lastMsg = msg
      print("[driver] msg: " .. msg:gsub("\n", " / ") .. " anim=" .. tostring(anim))
    end
    if msg:match("used MAGNITUDE") then
      sawUsedLine = true
      if anim then badFrames = badFrames + 1 end
      if not shotUsed then
        shotUsed = U.shot(game, out .. "/1979-used-line.png")
      end
    elseif msg:match("^Magnitude %d") then
      sawNumberLine = true
      if anim then
        animOnNumber = true
        if not shotNumber then
          shotNumber = U.shot(game, out .. "/1979-magnitude-line.png")
        end
      end
    end
    if st.battle.over then break end
    if (st.messageTimer or 0) > 0 and not anim then
      U.tap(game, "a")
    else
      U.wait(1)
    end
  end

  local ok = true
  if not sawUsedLine then
    print("[driver] FAIL never saw the used-move line") ok = false
  end
  if not sawNumberLine then
    print("[driver] FAIL never saw the Magnitude N! line") ok = false
  end
  if badFrames > 0 then
    print(("[driver] FAIL animation ran on the used-move line for %d frames")
      :format(badFrames))
    ok = false
  end
  if not animOnNumber then
    print("[driver] FAIL no animation while Magnitude N! was on screen")
    ok = false
  end
  if ok then
    print("[driver] PASS magnitude animates on its own line, shots in " .. out)
  end
  love.event.quit()
end
