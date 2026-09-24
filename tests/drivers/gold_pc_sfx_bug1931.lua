-- #1931: home/menu.asm:746
local U = require("tests.drivers.util")

local Boxes = require("src.core.gen2.Boxes")
local Mon = require("src.battle.gen2.Mon")

return function(game)
  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")
  local save, data = game.save, game.data

  save.party = {}
  for _, species in ipairs({ "CYNDAQUIL", "PIDGEY", "SENTRET" }) do
    save.party[#save.party + 1] = Mon.new(data, species, 12)
  end
  local stored = Boxes.box(save, 1)
  for i = #stored, 1, -1 do stored[i] = nil end
  for i, species in ipairs({ "GEODUDE", "ZUBAT", "RATTATA" }) do
    stored[i] = Mon.new(data, species, 10 + i)
  end
  save.currentBox = 1
  save.pcItems = { POTION = 5, ANTIDOTE = 2 }

  assert(game.world:openPc(), "openPc failed")
  U.wait(8)
  U.log("done -- the whose-PC menu is open; the controls are yours")
end
