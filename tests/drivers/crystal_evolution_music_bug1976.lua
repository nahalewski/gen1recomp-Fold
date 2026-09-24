local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local Music = require("src.core.Music")

-- ../pokecrystal/engine/pokemon/evolve.asm:331

return function(game)
  local fails = 0
  local function say(line) print("[1976] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world, save = game.world, game.save
  if not (world and world.map and save) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  world:warpToMapId("ROUTE_29", 20, 8, "down")
  U.wait(60)
  local want = Music.current()
  ok(want ~= nil, "the map theme is sounding (" .. tostring(want) .. ")")

  local function runEvolution(label, species, kick)
    save.party = { Mon.new(game.data, species, 20) }
    kick()
    U.wait(10)
    local menu = game.stack:top()
    if menu and menu.showItemResult then
      U.tap(game, "a")
      U.wait(10)
    end
    local screen
    for _ = 1, 240 do
      local top = game.stack:top()
      if top and top.phase and top.onDone then
        screen = top
        break
      end
      U.wait(1)
    end
    if not screen then
      ok(false, label .. ": the evolution screen never opened")
      return
    end
    local left = false
    for _ = 1, 900 do
      if game.stack:top() ~= screen then break end
      if Music.current() ~= want then left = true end
      U.tap(game, "a")
      U.wait(4)
    end
    ok(left, label .. ": the map theme went down under the screen")
    U.wait(30)
    ok(Music.current() == want, label .. ": map music back (got "
      .. tostring(Music.current()) .. ", want " .. tostring(want) .. ")")
  end

  runEvolution("FIRE STONE", "EEVEE", function()
    save.inventory = save.inventory or {}
    save.inventory.FIRE_STONE = 1
    game:usePartyItem("FIRE_STONE")
  end)

  runEvolution("RARE CANDY", "CYNDAQUIL", function()
    game:afterRareCandy(save.party[1], { learned = {} })
  end)

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
