-- Parity: the elevator floor menu belongs to the panel, not to map entry (#395).
--
-- Oracle: data/maps/objects/CeladonMartElevator.asm declares
-- `bg_event 3, 0, TEXT_CELADONMARTELEVATOR` (SilphCoElevator.asm the same
-- cell, RocketHideoutElevator.asm `bg_event 1, 1`), and only
-- CeladonMartElevatorText reaches `predef DisplayElevatorFloorMenu`
-- (scripts/CeladonMartElevator.asm).  Map entry runs
-- CeladonMartElevatorStoreWarpEntriesScript alone, so warping into the car
-- must open nothing.  DisplayElevatorFloorMenu (engine/events/elevator.asm)
-- rewrites wWarpEntries through .UpdateWarp and returns: it never moves the
-- player, so nothing may walk them out of the car after the ride.
--
-- Self-contained: `luajit tests/parity_elevator_panel.lua`; also dofile'd by
-- tests/run_tests.lua.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end
local Data = require("src.core.Data")
if not (Data.maps and Data.maps.CELADON_MART_ELEVATOR) then Data:load() end
local MapLoader = require("src.world.MapLoader")
local mapScripts = require("data.scripts.init")

local S = require("tests.harness").suite("parity elevator panel")
local check, eq = S.check, S.eq

-- restored at the bottom so the suites after this file see the real states
local realList = package.loaded["src.ui.ListMenu"]
local realShake = package.loaded["src.world.ElevatorShake"]
local realTextBox = package.loaded["src.render.TextBox"]
package.loaded["src.ui.ListMenu"] = {
  new = function(game, title, items, opts)
    local list
    list = { kind = "list", title = title, items = items, opts = opts,
             close = function()
               if game.stack:top() == list then game.stack:pop() end
             end }
    return list
  end,
}
package.loaded["src.world.ElevatorShake"] = {
  new = function(_, _, opts) return { kind = "shake", opts = opts } end,
}
package.loaded["src.render.TextBox"] = {
  new = function(_, text, done, opts)
    return { kind = "text", text = text, done = done, opts = opts }
  end,
}

-- panel cell / reading cell from the bg_event coordinates above; facing is
-- the direction that looks at the panel from the reading cell
local CARS = {
  { map = "CELADON_MART_ELEVATOR", text = "TEXT_CELADONMARTELEVATOR",
    panelX = 3, panelY = 0, readX = 3, readY = 1, facing = "up",
    from = "CELADON_MART_3F", pick = "CELADON_MART_2F", floors = 5 },
  { map = "SILPH_CO_ELEVATOR", text = "TEXT_SILPHCOELEVATOR_ELEVATOR",
    panelX = 3, panelY = 0, readX = 3, readY = 1, facing = "up",
    from = "SILPH_CO_5F", pick = "SILPH_CO_11F", floors = 11 },
  { map = "ROCKET_HIDEOUT_ELEVATOR", text = "TEXT_ROCKETHIDEOUTELEVATOR",
    panelX = 1, panelY = 1, readX = 2, readY = 1, facing = "left",
    from = "ROCKET_HIDEOUT_B2F", pick = "ROCKET_HIDEOUT_B4F", floors = 3,
    key = "LIFT_KEY", keyText = "_RocketHideoutElevatorAppearsToNeedKeyText" },
}

-- ow stub: the car's warps are copied out of Data so a rewrite here cannot
-- leak into the suites that read the same map defs later.  scriptMove /
-- takeWarp are the walk-out primitives the fix deleted; leaving them here as
-- tripwires is what makes "nothing moves the player" an assertion.
local function fakeCar(car)
  local warps = {}
  for i, w in ipairs(Data.maps[car.map].warps) do
    warps[i] = { x = w.x, y = w.y, destMap = w.destMap, destWarp = w.destWarp }
  end
  local moves = 0
  return {
    map = { id = car.map, def = { warps = warps, label = Data.maps[car.map].label } },
    player = { cellX = car.readX, cellY = car.readY, facing = car.facing },
    npcs = {}, entities = {}, scriptMoves = {},
    scriptMove = function() moves = moves + 1 end,
    takeWarp = function() moves = moves + 1 end,
    moveCount = function() return moves end,
  }
end

local function fakeGame(inventory)
  local pushed = {}
  return {
    data = Data,
    save = { flags = {}, inventory = inventory or {} },
    stack = {
      pushed = pushed,
      push = function(_, state) pushed[#pushed + 1] = state end,
      pop = function() pushed[#pushed] = nil end,
      top = function() return pushed[#pushed] end,
    },
  }, pushed
end

local function destinations(ow)
  local maps = {}
  for _, w in ipairs(ow.map.def.warps) do maps[w.destMap] = true end
  local list = {}
  for m in pairs(maps) do list[#list + 1] = m end
  table.sort(list)
  return table.concat(list, ",")
end

for _, car in ipairs(CARS) do
  local tag = car.map
  local entry = mapScripts.get(car.map)
  check(type(entry) == "table" and type(entry.onEnter) == "function",
        tag .. ": map entry still stores the car's warps")

  -- the panel is map data, and it is unreachable except by facing it
  local map = MapLoader.load(Data, car.map)
  local sign = map:signAtCell(car.panelX, car.panelY)
  check(sign ~= nil,
        ("%s: bg_event at (%d,%d) is extracted as a sign")
          :format(tag, car.panelX, car.panelY))
  eq(sign and sign.text, car.text, tag .. ": that sign carries the panel text")
  check(not map:isWalkableCell(car.panelX, car.panelY),
        tag .. ": the panel cell is wall, so it can only be read by facing it")
  check(map:isWalkableCell(car.readX, car.readY),
        ("%s: (%d,%d) is the walkable cell the panel is read from")
          :format(tag, car.readX, car.readY))

  local panel = mapScripts.talkScript(car.map, car.text)
  check(type(panel) == "function",
        tag .. ": the panel text runs a hand-ported handler")

  -- warping in: warps seeded to the floor just left, nothing on the stack
  local game, pushed = fakeGame()
  local ow = fakeCar(car)
  entry.onEnter(game, ow, car.from)
  eq(#pushed, 0, tag .. ": entering the car pushes no menu and no text")
  eq(destinations(ow), car.from,
     tag .. ": entry only points the car's exit warps back at " .. car.from)
  local seeded = destinations(ow)

  if car.key then
    -- RocketHideoutElevatorText with no LIFT_KEY: the line, and no menu
    local box = nil
    local done = false
    panel(game, ow, nil, function() done = true end)
    box = pushed[#pushed]
    eq(#pushed, 1, tag .. ": the keyless panel pushes exactly one state")
    eq(box and box.kind, "text", tag .. ": and that state is the text box")
    eq(box and box.text, Data.text[car.keyText],
       tag .. ": it is the appears-to-need-a-key line")
    if box and box.done then box.done() end
    check(done, tag .. ": the keyless panel hands control back")
    eq(destinations(ow), seeded,
       tag .. ": a keyless read leaves the exit warps alone")
    pushed[1] = nil
    game.save.inventory[car.key] = 1
  end

  -- (engine/events/elevator.asm:2-3), then the LIST_MENU_BOX over the map
  local done = false
  panel(game, ow, nil, function() done = true end)
  local prompt = pushed[#pushed]
  eq(#pushed, 1, tag .. ": the panel pushes the prompt box and nothing else")
  eq(prompt and prompt.kind, "text", tag .. ": and that state is a text box")
  eq(prompt and prompt.text, Data.text._WhichFloorText,
     tag .. ": carrying _WhichFloorText, not an invented title")
  check(prompt and prompt.opts and prompt.opts.stay
        and type(prompt.opts.stay.onShown) == "function",
        tag .. ": a `done` box that stays up while the list opens over it")
  prompt.opts.stay.onShown()
  local list = pushed[#pushed]
  eq(list and list.kind, "list", tag .. ": reading the panel opens a list menu")
  eq(list and list.title, nil, tag .. ": the box has no title row")
  eq(list and list.opts.itemBox, true,
     tag .. ": drawn as LIST_MENU_BOX over the still-visible map")
  eq(list and #list.items, car.floors + 1,
     tag .. ": every floor that warps into this car, plus the terminator")
  local last = list and list.items[#list.items]
  eq(last and last.cancel, true, tag .. ": the last row is the $ff terminator")
  eq(last and last.label, "CANCEL", tag .. ": printed as CANCEL")
  eq(destinations(ow), seeded,
     tag .. ": opening the menu has not rewritten anything yet")

  -- `ret c` on B: no warp rewrite, no ride, player still in the car
  local cancelGame, cancelPushed = fakeGame(car.key and { [car.key] = 1 } or nil)
  local cancelOw = fakeCar(car)
  entry.onEnter(cancelGame, cancelOw, car.from)
  local cancelDone = false
  panel(cancelGame, cancelOw, nil, function() cancelDone = true end)
  cancelPushed[#cancelPushed].opts.stay.onShown()
  local cancelList = cancelPushed[#cancelPushed]
  cancelGame.stack:pop()
  cancelList.opts.onCancel()
  check(cancelDone, tag .. ": B closes the panel")
  eq(#cancelPushed, 0, tag .. ": and the prompt box goes with it")
  eq(destinations(cancelOw), car.from,
     tag .. ": B leaves the exit warps on the floor entered from")
  eq(cancelOw.moveCount(), 0, tag .. ": B moves nobody")

  -- A on the CANCEL row exits exactly like B (home/list_menu.asm:105-110)
  local rowGame, rowPushed = fakeGame(car.key and { [car.key] = 1 } or nil)
  local rowOw = fakeCar(car)
  entry.onEnter(rowGame, rowOw, car.from)
  local rowDone = false
  panel(rowGame, rowOw, nil, function() rowDone = true end)
  rowPushed[#rowPushed].opts.stay.onShown()
  local rowList = rowPushed[#rowPushed]
  rowList.opts.onChoose(rowList.items[#rowList.items], rowList)
  check(rowDone, tag .. ": the CANCEL row closes the panel")
  eq(#rowPushed, 0, tag .. ": leaving nothing on the stack")
  eq(destinations(rowOw), car.from,
     tag .. ": the CANCEL row rewrites no warps")
  eq(rowOw.moveCount(), 0, tag .. ": the CANCEL row moves nobody")

  -- choosing a floor: the ride first, the .UpdateWarp rewrite when it ends
  local chosen
  for _, item in ipairs(list.items) do
    if item.value and item.value.map == car.pick then chosen = item end
  end
  check(chosen ~= nil, tag .. ": " .. car.pick .. " is on the floor list")
  list.opts.onChoose(chosen, list)
  local shake = pushed[#pushed]
  eq(shake and shake.kind, "shake", tag .. ": choosing a floor starts the ride")
  eq(destinations(ow), seeded,
     tag .. ": the warps are still the entry floor's while the car shakes")
  shake.opts.onDone()
  check(done, tag .. ": the ride hands control back to the player")
  eq(destinations(ow), car.pick,
     tag .. ": the finished ride points the car's exits at " .. car.pick)
  eq(ow.moveCount(), 0,
     tag .. ": no scripted walk-out -- the player leaves the car themselves")
  eq(ow.player.cellX .. "," .. ow.player.cellY,
     car.readX .. "," .. car.readY,
     tag .. ": they are still standing at the panel")

  -- the rewrite has to land on the floor's own warp back into the car, the
  -- reciprocal pair wElevatorWarpMaps holds
  for _, w in ipairs(ow.map.def.warps) do
    local back = Data.maps[car.pick].warps[w.destWarp]
    check(back ~= nil and back.destMap == car.map,
          tag .. ": rewritten exit lands on " .. car.pick .. "'s elevator door")
  end
end

package.loaded["src.ui.ListMenu"] = realList
package.loaded["src.world.ElevatorShake"] = realShake
package.loaded["src.render.TextBox"] = realTextBox
S.finish()
