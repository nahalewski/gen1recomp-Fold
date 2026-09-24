-- engine/menus/start_sub_menus.asm:330-345
--   POKEPORT_VERSION=red POKEPORT_DRIVER=tests/drivers/bag_use_toss_cursor_2063.lua love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local Screens = require("src.ui.Screens")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/2063"

  game.save.player.name = "bryan"
  Bag.add(game.save, "POTION", 3)
  Bag.add(game.save, "SUPER_ROD", 1)
  Bag.add(game.save, "TOWN_MAP", 1)

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")

  Screens.push(game, "BagMenu", {})
  U.wait(20)
  local list = game.stack:top()
  for i, row in ipairs(list.items or {}) do
    if row.value == "SUPER_ROD" then list.index = i end
  end
  U.wait(5)
  U.shot(game, DIR .. "/2063_0_list.png")       

  U.tap(game, "a")
  U.wait(20)
  U.shot(game, DIR .. "/2063_1_usetoss.png")    

  U.tap(game, "b")
  U.wait(20)
  U.shot(game, DIR .. "/2063_2_back.png")       

  U.log("2063: shots in " .. DIR)
  while true do
    coroutine.yield()
  end
end
