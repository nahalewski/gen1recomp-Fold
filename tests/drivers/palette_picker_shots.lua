-- The COLORS picker after the palette rename: the root folder list and one
-- pack's contents.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  local Screens = require("src.ui.Screens")
  Screens.push(game, "PaletteScreen")
  U.wait(5)
  U.shot(game, DIR .. "/pal_0_root.png")
  for _ = 1, 6 do U.tap(game, "down"); U.wait(1) end
  U.shot(game, DIR .. "/pal_1_scrolled.png")
  U.tap(game, "a"); U.wait(4)
  U.shot(game, DIR .. "/pal_2_inside.png")
  U.log("PALETTE_PICKER_SHOTS_DONE")
  game.driverDone = true
end
