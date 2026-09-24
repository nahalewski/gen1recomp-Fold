return function(game)
  local U = dofile("tests/drivers/util.lua")
  local TouchControls = require("src.core.TouchControls")
  local Pokemon = require("src.pokemon.Pokemon")

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  game.save.party = {
    Pokemon.new(game.data, "CHARIZARD", 50),
    Pokemon.new(game.data, "PIKACHU", 30),
  }
  game.save.player.name = "bryan"
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(8)

  check("the overlay is on screen (POKEPORT_TOUCH=1?)", TouchControls:visible())
  check("and the strip is enabled", TouchControls:hotbarShown())

  local L = TouchControls:layout()
  local z = L.hotbar
  if not check("the toggle has a zone", z ~= nil) then
    while true do coroutine.yield() end
  end

  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  U.shot(game, SHOT_DIR .. "/hotbar_folded.png")

  TouchControls:touchpressed("probe", z.cx, z.cy)
  TouchControls:touchreleased("probe", z.cx, z.cy)
  U.wait(2)
  check("tapping the toggle opens the strip", TouchControls.hotbarOpen == true)
  U.shot(game, SHOT_DIR .. "/hotbar_open.png")

  local cells = TouchControls:hotbarStrip() or {}
  check("the strip laid out its cells", #cells > 0)
  local save = cells[1]
  if save then
    local before = game.save.player.name
    TouchControls:touchpressed("probe", save.x + save.w / 2, save.y + save.h / 2)
    U.wait(2)
    TouchControls:touchreleased("probe", save.x + save.w / 2, save.y + save.h / 2)
    U.wait(4)
    check("tapping " .. tostring(save.label) .. " left the game running",
          game.save ~= nil and game.save.player.name == before)
  end

  TouchControls:touchpressed("probe", z.cx, z.cy)
  TouchControls:touchreleased("probe", z.cx, z.cy)
  U.wait(2)
  check("tapping it again folds the strip away",
        TouchControls.hotbarOpen == false)
  U.shot(game, SHOT_DIR .. "/hotbar_refolded.png")

  U.log("The window is live and the mouse is a finger. The chevron sits at the")
  U.log("top right: tapping it should slide a semitransparent bar of SAVE, LOAD,")
  U.log("SPEED, COLOR, TILT and ZOOM under it, and a second tap should fold it")
  U.log("away. SPEED/COLOR/TILT/ZOOM must change the picture exactly as keys")
  U.log("1/2/3/4 do; LOAD must jump to the last save. The bar must never cover")
  U.log("the d-pad or A/B, and no cell may leave a key held after the finger")
  U.log("lifts -- walk with the d-pad straight after tapping one to be sure.")
  U.log("Options > KEY BAR OFF should remove the chevron entirely.")

  while true do
    coroutine.yield()
  end
end
