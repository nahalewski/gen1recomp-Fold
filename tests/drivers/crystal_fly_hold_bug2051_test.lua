-- ../pokecrystal/engine/pokegear/pokegear.asm:2026-2046
-- ../pokecrystal/engine/pokegear/pokegear.asm:2062-2087
-- ../pokecrystal/home/map.asm:1927-1940
-- ../pokecrystal/engine/events/field_moves.asm:305-311
--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_SPEED=1 POKEPORT_DRIVER=tests/drivers/crystal_fly_hold_bug2051_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-fly2051
local U = require("tests.drivers.util")

local FieldMoves = require("src.world.gen2.FieldMoves")
local Mon = require("src.battle.gen2.Mon")
local World = require("src.world.gen2.World")

local FLY_SPECIES = "PIDGEOTTO"

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-fly2051"
  local fails = 0

  local function ok(cond, msg)
    if cond then
      print("[fly2051] ok   " .. msg)
    else
      fails = fails + 1
      print("[fly2051] FAIL " .. msg)
    end
    return cond
  end

  local function tap(btn) U.tap(game, btn) U.wait(3) end
  local function top() return game.stack:top() end
  local function topId()
    local state = top()
    return state and state.screenId or nil
  end

  local counts = { blank = 0, white = 0, preroll = 0, cancel = 0 }
  local counting = nil
  local shotAt = {}
  local realDraw = love.draw
  love.draw = function(...)
    realDraw(...)
    if not counting then return end
    local world = game.world
    local id = topId()
    if counting == "in" or counting == "cancel" then
      if id == "Gen2BlankScreen" then
        counts[counting == "in" and "blank" or "cancel"] =
          counts[counting == "in" and "blank" or "cancel"] + 1
      end
    elseif counting == "out" then
      if id == nil and world.fade == "white" and (world.fadeLevel or 0) >= 1 then
        counts.white = counts.white + 1
      end
      if id == nil and world.fade == nil and world.mapSetup == nil
          and (not world.flyAnim or (world.flyAnim.preroll or 0) > 0) then
        counts.preroll = counts.preroll + 1
      end
      local _, hidden = world:flyHides()
      if id == nil and not hidden then counts.player = (counts.player or 0) + 1 end
    end
  end

  U.wait(45)
  local world = game.world
  local save, data = game.save, game.data
  if not ok(world and world.map, "booted into the overworld") then
    error("fly2051: no world")
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
  world:warpToMapId("NEW_BARK_TOWN", 9, 8, "down")
  U.wait(15)
  ok(world.map.id == "NEW_BARK_TOWN", "standing in New Bark Town")

  for _ = 1, 240 do
    if not world:busy() then break end
    U.wait(2)
  end

  local function openFlyRow()
    for _ = 1, 120 do
      if topId() == nil then break end
      U.wait(1)
    end
    local menu
    for _ = 1, 10 do
      tap("start")
      menu = top()
      if menu and menu.screenId == "Gen2StartMenu" then break end
      U.wait(6)
    end
    if not ok(menu and menu.screenId == "Gen2StartMenu",
        "START opened the menu") then
      error("fly2051: no start menu")
    end
    for _ = 1, 10 do
      if menu.list:current().value == "pokemon" then break end
      tap("down")
    end
    tap("a")
    for _ = 1, 60 do
      if topId() == "Gen2PartyMenu" then break end
      U.wait(1)
    end
    local party = top()
    if not ok(party and party.screenId == "Gen2PartyMenu",
        "POKeMON opened the party list") then
      error("fly2051: no party list")
    end
    tap("a")
    local sub = party.submenu
    if not ok(sub ~= nil, "A opened the action submenu") then
      error("fly2051: no submenu")
    end
    local flyRow
    for index, item in ipairs(sub.items) do
      if item.id == "FLY" then flyRow = index end
    end
    if not ok(flyRow ~= nil, "which lists FLY") then
      error("fly2051: the submenu has no FLY row")
    end
    for _ = 1, #sub.items do
      if sub.index == flyRow then break end
      tap("down")
    end
    return party
  end

  openFlyRow()
  counting = "in"
  U.tap(game, "a")
  for _ = 1, 120 do
    U.wait(1)
    if counts.blank == 14 and not shotAt.blank then
      shotAt.blank = true
      U.shot(game, out .. "/01-blank-in.png")
    end
    if topId() == "Gen2Pokegear" then break end
  end
  counting = nil
  ok(counts.blank == World.FLY_MAP_BUILD_FRAMES,
    ("_FlyMap held white for %d drawn frames (want %d)")
      :format(counts.blank, World.FLY_MAP_BUILD_FRAMES))
  if not ok(topId() == "Gen2Pokegear", "then the town map took over") then
    error("fly2051: no picker")
  end
  U.wait(6)
  U.shot(game, out .. "/02-fly-map.png")

  counting = "cancel"
  U.tap(game, "b")
  for _ = 1, 120 do
    U.wait(1)
    if topId() == "Gen2PartyMenu" then break end
  end
  counting = nil
  local wantCancel = World.flyCancelBlankFrames(#save.party)
  ok(counts.cancel == wantCancel,
    ("B whited out for %d drawn frames (want %d)"):format(counts.cancel, wantCancel))
  ok(topId() == "Gen2PartyMenu", ("B returned to the party list (top is %s)")
    :format(tostring(topId())))
  U.shot(game, out .. "/03-b-back-to-party.png")

  tap("b")
  tap("b")
  U.wait(10)
  openFlyRow()
  U.tap(game, "a")
  for _ = 1, 120 do
    U.wait(1)
    if topId() == "Gen2Pokegear" then break end
  end
  if not ok(topId() == "Gen2Pokegear", "the picker is back up") then
    error("fly2051: no picker on the second pass")
  end
  tap("up")
  U.wait(6)

  counting = "out"
  U.tap(game, "a")
  local sawBird = false
  for _ = 1, 300 do
    U.wait(1)
    if counts.white == 14 and not shotAt.white then
      shotAt.white = true
      U.shot(game, out .. "/04-exit-white.png")
    end
    local ms = world.mapSetup
    if ms and ms.phase == "in" and (ms.step or 9) <= 2 and not shotAt.ramp then
      shotAt.ramp = true
      U.shot(game, out .. "/05-fade-in.png")
    end
    if world.flyAnim and (world.flyAnim.preroll or 0) == 0 then
      sawBird = true
      break
    end
  end
  counting = nil
  ok(counts.white == World.FLY_EXIT_WHITE_FRAMES,
    ("the exit held full white for %d drawn frames (want %d)")
      :format(counts.white, World.FLY_EXIT_WHITE_FRAMES))
  ok(counts.preroll == World.FLY_FROM_PREROLL,
    ("the map stood clear for %d drawn frames before the bird (want %d)")
      :format(counts.preroll, World.FLY_FROM_PREROLL))
  ok((counts.player or 0) == 0,
    ("HideSprites: the player never showed on the way out (%d frame(s))")
      :format(counts.player or 0))
  ok(sawBird, "then the take-off sprite appeared")
  U.wait(4)
  U.shot(game, out .. "/06-takeoff.png")

  for _ = 1, 1800 do
    U.wait(1)
    if world.flyAnim == nil and world.map.id ~= "NEW_BARK_TOWN" then break end
  end
  U.wait(20)
  ok(world.map.id ~= "NEW_BARK_TOWN",
    ("landed on %s"):format(tostring(world.map.id)))
  U.shot(game, out .. "/07-landed.png")

  love.draw = realDraw
  U.log("fly hold frames (#2051): blank in " .. counts.blank .. ", cancel "
    .. counts.cancel .. ", exit white " .. counts.white .. ", preroll "
    .. counts.preroll .. ".")
  U.log("01-blank-in.png / 04-exit-white.png are the two holds, edge to edge.")
  U.log("shots are in " .. out .. ".")
  if fails > 0 then
    U.log(("%d assertion(s) failed above."):format(fails))
    love.event.quit(1)
    return
  end
  love.event.quit()
end
