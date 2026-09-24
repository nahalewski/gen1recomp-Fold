-- ../pokecrystal/engine/menus/save.asm:242 SavedTheGame
--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gen2_save_order_s5.lua \
--     POKEPORT_SHOT_DIR=/tmp/save-order love .

local U = require("tests.drivers.util")

local POKECENTER = os.getenv("POKEPORT_PC_MAP") or "CHERRYGROVE_POKECENTER_1F"

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/save-order"
  local failed = 0
  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  if not (world and world.map) then
    U.log("FAIL the world did not boot")
    love.event.quit(1)
    return
  end
  world:warpToMapId(POKECENTER, 5, 5, "down")
  U.wait(30)

  local Sound = require("src.core.Sound")
  local Screens = require("src.ui.Screens")
  local realPlay = Sound.play
  local frames, wrote, rang = 0, nil, nil
  Sound.play = function(data, name)
    if name and tostring(name):find("Save") then rang = frames end
    return realPlay(data, name)
  end

  local closed = nil
  Screens.push(game, "Gen2SaveMenu", {
    save = game.save,
    existed = false,
    writer = function() wrote = frames return true end,
    onDone = function() closed = frames game.stack:pop() end,
  })
  U.wait(8)
  local menu = game.stack:top()

  local function step()
    frames = frames + 1
    U.wait(1)
  end
  local function settle()
    for _ = 1, 600 do
      if not menu.typer or menu.typer:done() then break end
      step()
    end
  end

  settle()
  U.tap(game, "a")
  U.wait(4)
  settle()
  pass(menu.phase == "saving", "YES opens SavingDontTurnOffThePower")
  U.shot(game, out .. "/01-saving-line.png")

  local typedAt = frames
  for _ = 1, 200 do
    if wrote then break end
    step()
  end
  pass(wrote ~= nil, "the write landed")
  U.log(("write landed %d frames after the SAVING line"):format(
    (wrote or 0) - typedAt))
  pass(menu.phase == "saving", "and the SAVING page is still up at the write")
  U.shot(game, out .. "/02-write-frame.png")

  for _ = 1, 200 do
    if menu.phase ~= "saving" then break end
    step()
  end
  U.log(("the saved line came up %d frames after the write"):format(
    frames - (wrote or 0)))
  pass(rang == nil, "no chime before the line")
  U.shot(game, out .. "/03-saved-line-starts.png")

  settle()
  step()
  U.shot(game, out .. "/04-saved-line-and-chime.png")
  pass(rang ~= nil, "SFX_SAVE rings under the saved line")

  for _ = 1, 400 do
    if closed then break end
    step()
  end
  pass(closed ~= nil, "the box closes")
  U.log(("and closes %d frames after the chime"):format(
    (closed or 0) - (rang or 0)))
  U.shot(game, out .. "/05-closed.png")

  Sound.play = realPlay
  U.log(("%d check(s) failed"):format(failed))
  love.event.quit(failed == 0 and 0 or 1)
end
