-- ../pokecrystal/engine/events/pokecenter_pc.asm:15 (#2049)
-- ../pokecrystal/engine/menus/save.asm:1 (#2053)
local U = require("tests.drivers.util")

local POKECENTER = os.getenv("POKEPORT_PC_MAP") or "CHERRYGROVE_POKECENTER_1F"
local COLL_PC = 0x93

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-pc-overlay"
  local failed = 0

  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  -- ../pokecrystal/home/print_text.asm:59
  local function settle()
    for _ = 1, 600 do
      local top = game.stack:top()
      local typer = top and top.typer
      if not typer or typer:done() then break end
      U.wait(1)
    end
  end

  local function tap(btn, frames)
    settle()
    U.tap(game, btn)
    U.wait(frames or 6)
    settle()
  end

  local function topId()
    local top = game.stack:top()
    return top and top.screenId or nil
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gen2 world did not boot")

  local Mon = require("src.battle.gen2.Mon")
  game.save.party = { Mon.new(game.data, "CYNDAQUIL", 10) }

  world:warpToMapId(POKECENTER, 4, 4, "up")
  U.wait(20)

  local pcX, pcY
  for cy = 0, world.map.heightCells - 1 do
    for cx = 0, world.map.widthCells - 1 do
      if world.map:cellCollision(cx, cy) == COLL_PC then pcX, pcY = cx, cy end
    end
  end
  assert(pcX, "no COLL_PC tile on " .. POKECENTER)
  world:warpToMapId(POKECENTER, pcX, pcY + 1, "up")
  U.wait(20)

  tap("a", 10)
  pass(topId() == "Gen2CenterPcMenu",
    "A on the PC tile opens the whose-PC screen (top: "
      .. tostring(topId()) .. ")")
  local pc = game.stack:top()
  pass(pc ~= nil and pc.isOpaque == false,
    "PokemonCenterPC is a window, not an opaque page")

  U.log("01-turn-on: '<PLAYER> turned on the PC.' in the bottom box, with the")
  U.log("Pokecenter floor, the counter and the player sprite still drawn")
  U.log("above it. A pure white field above the box is the bug.")
  U.shot(game, out .. "/01-turn-on.png")

  tap("a", 10)
  U.log("02-whose-pc: the whose-PC list over 'Access whose PC?', with the map")
  U.log("still showing in the four tile columns right of the menu box.")
  U.shot(game, out .. "/02-whose-pc.png")

  tap("a", 10)
  U.log("03-bills-accessed: \"BILL's PC accessed.\" prints WITH the whose-PC")
  U.log("menu box still standing above it, and the map beside it.")
  U.shot(game, out .. "/03-bills-accessed.png")

  for _ = 1, 8 do
    if topId() == nil then break end
    tap("b", 12)
  end
  pass(topId() == nil, "B backs all the way out of the PC (top: "
    .. tostring(topId()) .. ")")

  world:warpToMapId(POKECENTER, pcX, pcY + 2, "down")
  U.wait(20)
  tap("start", 12)
  U.log("04-start-menu: the START menu over the Pokecenter.")
  U.shot(game, out .. "/04-start-menu.png")

  local Screens = require("src.ui.Screens")
  Screens.push(game, "Gen2SaveMenu", {
    save = game.save,
    existed = false,
    writer = function() return true end,
    onDone = function() game.stack:pop() end,
  })
  U.wait(8)
  local saveMenu = game.stack:top()
  pass(saveMenu ~= nil and saveMenu.isOpaque == false,
    "SaveMenu is a window over the tilemap, not an opaque page")
  settle()
  U.log("05-save-prompt: the continue panel, the YES/NO box and 'Would you")
  U.log("like to save the game?' over the LIVE map, with the START menu's own")
  U.log("rows still visible in the gap between them.")
  U.shot(game, out .. "/05-save-prompt.png")

  tap("a", 10)
  U.log("06-saving: 'SAVING... DON'T TURN OFF THE POWER.' up, map")
  U.log("still behind it.")
  U.shot(game, out .. "/06-saving.png")

  U.log(("%d check(s) failed"):format(failed))

  while true do coroutine.yield() end
end
