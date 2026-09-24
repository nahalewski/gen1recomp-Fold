-- The grouped Gen 2 OPTION screen: the top level, one page, and a long
-- COLOR value scrolling under the cursor.
--
--   POKEPORT_GAME=gold POKEPORT_DRIVER=tests/drivers/gold_options_groups_shots.lua love .
local U = require("tests.drivers.util")

return function(game)
  local OptionsMenu = require("src.ui.gen2.OptionsMenu")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  U.wait(5)
  local menu = OptionsMenu.new(game, { options = game.options })
  game.stack:push(menu)
  U.wait(3)
  U.shot(game, DIR .. "/g2_0_top.png")

  local page = menu:focusRow("color")
  U.wait(2)
  U.shot(game, DIR .. "/g2_1_graphics.png")
  game.options.palette = "1-A (Default) (BGB)"
  U.wait(2)
  U.shot(game, DIR .. "/g2_2_color_start.png")
  U.wait(85)
  U.shot(game, DIR .. "/g2_3_color_scrolled.png")

  page.index = #page.view
  U.wait(3)
  U.shot(game, DIR .. "/g2_4_back.png")
  U.log("GOLD_OPTIONS_GROUPS_DONE")
  game.driverDone = true
end
