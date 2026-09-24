-- ../pokecrystal/engine/events/pokecenter_pc.asm:568
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

local SHOTS = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

return function(game)
  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")
  local save, data = game.save, game.data

  save.party = { Mon.new(data, "CYNDAQUIL", 12) }
  save.pcItems = { POTION = 4, ANTIDOTE = 2, SUPER_POTION = 3 }
  save.pcOrder = nil

  assert(game.world:openPc(), "openPc failed")
  U.wait(30)
  U.tap(game, "a")      -- _PokecenterPCTurnOnText
  U.wait(12)
  U.tap(game, "down")   -- <PLAYER>'s PC
  U.wait(8)
  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")      -- .AccessedOwnPCText page 1
  U.wait(12)
  U.tap(game, "a")      -- .AccessedOwnPCText page 2
  U.wait(20)
  U.tap(game, "a")      -- WITHDRAW ITEM
  U.wait(30)
  U.shot(game, SHOTS .. "/1962_before.png")
  U.log("order before:", table.concat(save.pcOrder or {}, ","))

  U.tap(game, "select")
  U.wait(12)
  U.tap(game, "down")
  U.wait(10)
  U.tap(game, "down")
  U.wait(10)
  U.shot(game, SHOTS .. "/1962_held.png")
  U.tap(game, "a")
  U.wait(30)
  U.shot(game, SHOTS .. "/1962_after.png")
  U.log("order after:", table.concat(save.pcOrder or {}, ","))

  U.log("done -- ANTIDOTE should now sit last; the controls are yours")
end
