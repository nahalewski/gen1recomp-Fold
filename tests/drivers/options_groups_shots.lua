-- Driver: the grouped OPTION screen -- the top level with its group openers,
-- one group's page, and the COLORS row scrolling its overlong value.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local menu = OptionsMenu.new(game)
  game.stack:push(menu)
  U.wait(5)
  U.shot(game, DIR .. "/opt_0_top.png")

  menu:focusRow("group.battle")
  U.wait(2)
  U.shot(game, DIR .. "/opt_1_battle_opener.png")
  U.tap(game, "a"); U.wait(3)
  U.shot(game, DIR .. "/opt_2_battle_page.png")
  U.tap(game, "b"); U.wait(3)

  game.save.options.palette = "1-A (Default) (BGB)"
  -- COLORS is on the GRAPHICS page, so focusRow hands back that page.
  local graphics = menu:focusRow("colors")
  U.wait(2)
  U.shot(game, DIR .. "/opt_3_colors_start.png")
  U.wait(85)
  U.shot(game, DIR .. "/opt_4_colors_scrolled.png")

  graphics.index = #graphics.rows + 1 -- the page's own BACK
  U.wait(3)
  U.shot(game, DIR .. "/opt_5_back.png")
  U.log("OPTIONS_GROUPS_SHOTS_DONE")
  game.driverDone = true
end
