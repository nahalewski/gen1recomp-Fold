-- ../pokecrystal/engine/pokemon/mon_menu.asm:609
-- ../pokecrystal/engine/events/overworld.asm:556
-- ../pokecrystal/engine/pokegear/pokegear.asm:2026
-- ../pokecrystal/home/map.asm:1927
--   POKEPORT_IDENTITY=crystal-aug31 POKEPORT_GAME=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/crystal_fly_flash_bug2020_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-fly2020
local U = require("tests.drivers.util")

local FieldMoves = require("src.world.gen2.FieldMoves")
local Mon = require("src.battle.gen2.Mon")

local FLY_SPECIES = "PIDGEOTTO"

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-fly2020"
  local fails = 0

  local function ok(cond, msg)
    if cond then
      print("[fly2020] ok   " .. msg)
    else
      fails = fails + 1
      print("[fly2020] FAIL " .. msg)
    end
    return cond
  end

  local function tap(btn) U.tap(game, btn) U.wait(3) end
  local function top() return game.stack:top() end
  local function topId()
    local state = top()
    return state and state.screenId or nil
  end

  U.wait(45)
  local world = game.world
  local save, data = game.save, game.data
  if not ok(world and world.map, "booted into the overworld") then
    error("fly2020: no world")
  end

  save.player = save.player or {}
  if type(save.player.badges) ~= "table" then save.player.badges = {} end
  save.player.badges.STORM = true
  save.engineFlags = save.engineFlags or {}
  for _, row in ipairs(FieldMoves.FLYPOINTS) do
    save.engineFlags[row.flag] = true
  end

  local flyer = Mon.new(data, FLY_SPECIES, 24)
  table.remove(flyer.moves, 1)
  Mon.learnMove(flyer, "FLY", data)
  save.party = { flyer }

  world.mapScenes = world.mapScenes or {}
  world.mapScenes.NEW_BARK_TOWN = 1
  world:setMap("NEW_BARK_TOWN", 9, 8, "down")
  U.wait(15)
  ok(world.map.id == "NEW_BARK_TOWN", "standing in New Bark Town")

  for _ = 1, 240 do
    if not world:busy() then break end
    U.wait(2)
  end

  local function waitFor(id, limit)
    for _ = 1, limit or 120 do
      if topId() == id then return true end
      U.wait(1)
    end
    return topId() == id
  end

  local function openFlyRow()
    waitFor(nil, 240)
    local menu
    for _ = 1, 10 do
      tap("start")
      menu = top()
      if menu and menu.screenId == "Gen2StartMenu" then break end
      U.wait(6)
    end
    if not ok(menu and menu.screenId == "Gen2StartMenu",
        "START opened the menu") then
      error("fly2020: no start menu")
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
      error("fly2020: no party list")
    end
    tap("a")
    local sub = party.submenu
    if not ok(sub ~= nil, "A opened the action submenu") then
      error("fly2020: no submenu")
    end
    local flyRow
    for index, item in ipairs(sub.items) do
      if item.id == "FLY" then flyRow = index end
    end
    if not ok(flyRow ~= nil, "which lists FLY") then
      error("fly2020: the submenu has no FLY row")
    end
    for _ = 1, #sub.items do
      if sub.index == flyRow then break end
      tap("down")
    end
    return party
  end

  local party = openFlyRow()
  U.tap(game, "a")

  local empties, blankFrames, seenBlank, shotBlank = 0, 0, false, false
  local underneath = true
  for _ = 1, 90 do
    U.wait(1)
    local id = topId()
    if id == nil then empties = empties + 1 end
    if id == "Gen2BlankScreen" then
      seenBlank = true
      blankFrames = blankFrames + 1
      local states = game.stack.states or {}
      if states[#states - 1] ~= party then underneath = false end
      if not shotBlank then
        shotBlank = true
        U.shot(game, out .. "/01-blank-in.png")
      end
    end
    if id == "Gen2Pokegear" then break end
  end

  ok(seenBlank, ("_FlyMap blanked to white first (%d frame(s))")
    :format(blankFrames))
  ok(empties == 0,
    ("no live overworld frame leaked on the way in (%d empty stack frame(s))")
      :format(empties))
  ok(underneath, "and the party list stayed underneath the blank")

  local picker = top()
  if not ok(picker and picker.screenId == "Gen2Pokegear" and picker.fly,
      "then the destination map took over") then
    error("fly2020: no picker")
  end
  U.wait(6)
  U.shot(game, out .. "/02-fly-map.png")

  tap("b")
  -- engine/pokegear/pokegear.asm:2062-2078
  for _ = 1, 120 do
    if topId() == "Gen2PartyMenu" then break end
    U.wait(1)
  end
  ok(topId() == "Gen2PartyMenu", ("B returned to the party list (top is %s)")
    :format(tostring(topId())))
  ok(world.queuedFieldMove == nil, "with no fly queued behind it")
  U.shot(game, out .. "/03-b-back-to-party.png")

  for _ = 1, 6 do
    if topId() == nil then break end
    tap("b")
    waitFor(nil, 60)
  end
  U.wait(10)
  party = openFlyRow()
  U.tap(game, "a")
  for _ = 1, 90 do
    U.wait(1)
    if topId() == "Gen2Pokegear" then break end
  end
  if not ok(topId() == "Gen2Pokegear", "the picker is back up") then
    error("fly2020: no picker on the second pass")
  end
  tap("up")
  U.wait(6)

  U.tap(game, "a")
  local held, whiteHeld, sawRamp, shotWhite, shotRamp = 0, 0, false, false, false
  local leaked, startedEarly, sawHold = 0, false, false
  for _ = 1, 240 do
    U.wait(1)
    if topId() ~= nil then leaked = leaked + 1 end
    local ms = world.mapSetup
    if ms and ms.phase == "in" and (ms.wait or 0) > 2 then sawHold = true end
    if world.fade == "white" and (world.fadeLevel or 0) >= 1 then
      whiteHeld = whiteHeld + 1
      if world.flyAnim then startedEarly = true end
      if not shotWhite then
        shotWhite = true
        U.shot(game, out .. "/04-exit-white.png")
      end
    end
    if ms and ms.phase == "in" and (ms.step or 9) < 4 then
      sawRamp = true
      if not shotRamp and (ms.step or 9) <= 2 then
        shotRamp = true
        U.shot(game, out .. "/05-fade-in.png")
      end
    end
    held = held + 1
    if world.flyAnim then break end
  end

  ok(leaked == 0,
    ("the menus were gone the moment the spawn was taken (%d menu frame(s))")
      :format(leaked))
  ok(whiteHeld > 0 and sawHold,
    ("ExitAllMenus put the white up and held it (%d frame(s))")
      :format(whiteHeld))
  ok(not startedEarly, "and FlyFromAnim waited for it")
  ok(sawRamp, "FadeInFromWhite ramped back in")
  ok(world.flyAnim ~= nil and world.flyAnim.phase == "from",
    ("then the take-off ran, %d frame(s) after the press"):format(held))
  U.shot(game, out .. "/06-takeoff.png")

  for _ = 1, 1800 do
    U.wait(1)
    if world.flyAnim == nil and world.map.id ~= "NEW_BARK_TOWN" then break end
  end
  U.wait(20)
  ok(world.map.id ~= "NEW_BARK_TOWN",
    ("landed on %s"):format(tostring(world.map.id)))
  U.shot(game, out .. "/07-landed.png")

  U.log("flew out of New Bark Town from the party list (#2020). judge these:")
  U.log("01-blank-in.png -- a WHITE screen, edge to edge, on the way into the")
  U.log("town map. no overworld tiles, no sliver of the party list.")
  U.log("03-b-back-to-party.png -- B on the town map must land back on the")
  U.log("party list, not in the overworld.")
  U.log("04-exit-white.png and 05-fade-in.png -- the exit is white again and")
  U.log("then fades in; the bird only lifts off after that (06-takeoff.png).")
  U.log("shots are in " .. out .. ".")
  if fails > 0 then
    U.log(("%d assertion(s) failed above -- read those before the pictures.")
      :format(fails))
  end
  U.log("the party still holds a flyer and the badge, so FLY again whenever")
  U.log("you want another look. the controls are yours.")

  while true do
    coroutine.yield()
  end
end
