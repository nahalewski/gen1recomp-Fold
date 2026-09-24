-- ../pokecrystal/engine/pokemon/mon_menu.asm:724 MonMenu_Softboiled_MilkDrink
-- ../pokecrystal/engine/items/item_effects.asm:1986 Softboiled_MilkDrinkFunction
--   POKEPORT_IDENTITY=crystal-aug31 POKEPORT_VERSION=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/crystal_softboiled_field_bug2041.lua \
--     POKEPORT_SHOT_DIR=/tmp/sb2041
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/sb2041"
  local fails = 0
  local function ok(cond, msg)
    if not cond then fails = fails + 1 end
    print("[2041] " .. (cond and "ok   " or "FAIL ") .. msg)
    return cond
  end
  local function tap(btn) U.tap(game, btn) U.wait(3) end
  local function top() return game.stack:top() end
  local function topId()
    local state = top()
    return state and state.screenId or nil
  end
  local function waitFor(id, limit)
    for _ = 1, limit or 120 do
      if topId() == id then return true end
      U.wait(1)
    end
    return topId() == id
  end

  U.wait(45)
  local world, save, data = game.world, game.save, game.data
  if not ok(world and world.map, "booted into the overworld") then
    love.event.quit(1)
    return
  end

  local healer = Mon.new(data, "CHANSEY", 30)
  Mon.learnMove(healer, "SOFTBOILED", data)
  local patient = Mon.new(data, "GEODUDE", 20)
  patient.hp = 1
  save.party = { healer, patient }

  world:warpToMapId("NEW_BARK_TOWN", 9, 8, "down")
  U.wait(30)
  for _ = 1, 240 do
    if not world:busy() then break end
    U.wait(2)
  end

  waitFor(nil, 240)
  local menu
  for _ = 1, 10 do
    tap("start")
    menu = top()
    if menu and menu.screenId == "Gen2StartMenu" then break end
    U.wait(6)
  end
  if not ok(menu and menu.screenId == "Gen2StartMenu", "START opened the menu") then
    love.event.quit(1)
    return
  end
  for _ = 1, 10 do
    if menu.list:current().value == "pokemon" then break end
    tap("down")
  end
  tap("a")
  waitFor("Gen2PartyMenu", 90)
  local party = top()
  if not ok(party and party.screenId == "Gen2PartyMenu",
      "POKeMON opened the party list") then
    love.event.quit(1)
    return
  end
  tap("a")
  local sub = party.submenu
  if not ok(sub ~= nil, "A opened the action submenu") then
    love.event.quit(1)
    return
  end
  local row
  for index, item in ipairs(sub.items) do
    if item.id == "SOFTBOILED" then row = index end
  end
  if not ok(row ~= nil, "which lists SOFTBOILED") then
    love.event.quit(1)
    return
  end
  for _ = 1, #sub.items do
    if sub.index == row then break end
    tap("down")
  end
  tap("a")
  U.wait(10)
  ok(party.softboiledFrom == 1, "the list stayed up asking for a recipient")
  ok(top() == party, "with no refusal box over it")
  U.shot(game, out .. "/2041_pick_recipient.png")

  tap("down")
  U.tap(game, "a")
  -- ../pokecrystal/engine/items/item_effects.asm:1999 HealHP_SFX_GFX
  local order = {}
  for _ = 1, 90 do
    local r = party.itemResult
    if r and order[#order] ~= r.slot then order[#order + 1] = r.slot end
    U.wait(1)
  end
  ok(order[1] == 1 and order[2] == 2,
    "the user's bar drops before the recipient's climbs")
  U.shot(game, out .. "/2041_recovered.png")
  ok((save.party[2].hp or 0) > 1, "GEODUDE gained HP")
  ok(save.party[1].hp < (save.party[1].stats and save.party[1].stats.hp or 0),
    "and CHANSEY paid for it")

  print("[2041] eyeball 2041_pick_recipient.png (\"Use on which #MON?\") "
    .. "and 2041_recovered.png (the HP bar climb + \"recovered NHP!\")")
  print("[2041] " .. (fails == 0 and "all claims passed"
    or (fails .. " claims failed")))
  love.event.quit(fails == 0 and 0 or 1)
end
