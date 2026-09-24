-- ../pokecrystal/engine/items/pack.asm:313, ../pokegold/engine/items/pack.asm:313
-- ../pokecrystal/engine/events/pokecenter_pc.asm:628, :641
-- ../pokecrystal/engine/items/buy_sell_toss.asm:205
--   POKEPORT_IDENTITY=crystal-aug31 POKEPORT_VERSION=crystal POKEPORT_SHOT_DIR=/tmp/pack2012 POKEPORT_DRIVER=tests/drivers/gen2_pack_pc_menus_2012.lua love .
--   POKEPORT_IDENTITY=gold-aug30    POKEPORT_VERSION=gold    POKEPORT_SHOT_DIR=/tmp/pack2012 POKEPORT_DRIVER=tests/drivers/gen2_pack_pc_menus_2012.lua love .
local U = require("tests.drivers.util")

local Bag = require("src.inventory.Bag")
local Mon = require("src.battle.gen2.Mon")

local SHOTS = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"
local TAG = os.getenv("POKEPORT_VERSION") or "gen2"

return function(game)
  U.wait(45)
  assert(game.world and game.world.map, "gen2 world did not boot")
  local save, data = game.save, game.data

  save.party = { Mon.new(data, "CYNDAQUIL", 12) }
  save.inventory, save.bagOrder = {}, nil
  Bag.add(save, "POTION", 5, data)
  Bag.add(save, "ANTIDOTE", 3, data)
  Bag.add(save, "SUPER_POTION", 2, data)
  save.pcItems = { POTION = 4, ANTIDOTE = 2, SUPER_POTION = 3 }
  save.pcOrder = nil

  assert(game.world:openPc(), "openPc failed")
  U.wait(30)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "down")
  U.wait(8)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")
  U.wait(20)
  U.tap(game, "a")
  U.wait(30)
  U.shot(game, SHOTS .. "/2012_" .. TAG .. "_pc_list.png")

  U.tap(game, "a")
  U.wait(30)
  U.shot(game, SHOTS .. "/2012_" .. TAG .. "_pc_qty.png")

  U.tap(game, "b")
  U.wait(20)
  U.tap(game, "b")
  U.wait(20)
  for _ = 1, 6 do
    U.tap(game, "b")
    U.wait(20)
  end

  game:openStartMenuItem("pack")
  U.wait(30)
  U.shot(game, SHOTS .. "/2012_" .. TAG .. "_pack_list.png")
  U.tap(game, "a")
  U.wait(30)
  U.shot(game, SHOTS .. "/2012_" .. TAG .. "_pack_submenu.png")

  U.log("done --",
    "pc_list: cursor col 4, names col 5, xNN flush right at col 14;",
    "pc_qty: the x01 box bottom-right at (15,9), list arrow hollow;",
    "pack_submenu: crystal draws USE/GIVE/TOSS/QUIT on the RIGHT (col 13),",
    "gold on the LEFT (col 0), list arrow hollow in both.")
end
