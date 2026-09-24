local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

-- ../pokecrystal/engine/items/item_effects.asm:1654

return function(game)
  local shots = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"
  local fails = 0
  local function say(line) print("[1977] " .. line) end
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
  save.party = { Mon.new(game.data, "CYNDAQUIL", 30) }
  world:warpToMapId("NEW_BARK_TOWN", 4, 6, "down")
  U.wait(30)

  local mon = save.party[1]
  local maxHp = mon.maxHp or (mon.stats and mon.stats.hp)
  mon.hp = 1
  save.inventory = save.inventory or {}
  save.inventory.HYPER_POTION = 5

  game:usePartyItem("HYPER_POTION")
  U.wait(10)
  local menu = game.stack:top()
  ok(menu ~= nil and menu.showItemResult ~= nil, "the party list opened")
  if not (menu and menu.showItemResult) then
    love.event.quit(1)
    return
  end

  U.tap(game, "a")
  U.wait(4)
  ok(menu.itemResult ~= nil, "the pick stayed inside the list")
  ok(game.stack:top() == menu, "with the list still the top state")
  U.shot(game, shots .. "/1977_bar_mid.png")

  U.wait(40)
  ok(menu.itemResult ~= nil, "the list is still up after the climb")
  ok(menu.itemResult == nil or not menu:itemResultClimbing(),
    "the bar reached the healed value")
  U.shot(game, shots .. "/1977_text.png")

  U.wait(60)
  U.tap(game, "a")
  U.wait(10)
  ok(game.stack:top() ~= menu, "the button dropped the list")
  ok(mon.hp == maxHp, "and the mon came out at full HP")
  ok(save.inventory.HYPER_POTION == 4, "with one HYPER POTION spent")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
