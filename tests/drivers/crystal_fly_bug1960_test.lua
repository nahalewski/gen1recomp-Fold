-- ../pokecrystal/engine/sprite_anims/functions.asm:681
-- ../pokecrystal/engine/events/field_moves.asm:434
-- ../pokecrystal/engine/events/overworld.asm:610-628
--   POKEPORT_IDENTITY=crystal-aug28 POKEPORT_GAME=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/crystal_fly_bug1960_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-fly1960 \
local U = require("tests.drivers.util")

local FieldMoves = require("src.world.gen2.FieldMoves")
local Mon = require("src.battle.gen2.Mon")
local World = require("src.world.gen2.World")

local FLY_SPECIES = "PIDGEOTTO"

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-fly1960"
  local fails = 0

  local function ok(cond, msg)
    if cond then
      print("[fly1960] ok   " .. msg)
    else
      fails = fails + 1
      print("[fly1960] FAIL " .. msg)
    end
    return cond
  end

  local function tap(btn) U.tap(game, btn) U.wait(3) end
  local function top() return game.stack:top() end
  local function waitFor(id, limit)
    for _ = 1, limit or 120 do
      local state = top()
      if (state and state.screenId or nil) == id then return true end
      U.wait(1)
    end
    return false
  end

  U.wait(45)
  local world = game.world
  local save, data = game.save, game.data
  if not ok(world and world.map, "booted into the overworld") then
    error("fly1960: no world")
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
  local p = world.player
  ok(world.map.id == "NEW_BARK_TOWN", "standing in New Bark Town")
  ok(#world.npcs > 0,
    ("with %d object(s) on the map to hide"):format(#world.npcs))

  for _ = 1, 240 do
    if not world:busy() then break end
    U.wait(2)
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
    error("fly1960: no start menu")
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
    error("fly1960: no party list")
  end
  tap("a")
  local sub = party.submenu
  if not ok(sub ~= nil, "A opened the action submenu") then
    error("fly1960: no submenu")
  end
  local flyRow
  for index, item in ipairs(sub.items) do
    if item.id == "FLY" then flyRow = index end
  end
  if not ok(flyRow ~= nil, "which lists FLY") then
    error("fly1960: the submenu has no FLY row")
  end
  for _ = 1, #sub.items do
    if sub.index == flyRow then break end
    tap("down")
  end
  tap("a")
  U.wait(10)
  waitFor("Gen2Pokegear", 120)

  local picker = top()
  if not ok(picker and picker.screenId == "Gen2Pokegear" and picker.fly,
      "FLY opened the destination map") then
    error("fly1960: no picker")
  end
  tap("up")
  U.wait(6)

  U.tap(game, "a")
  -- ExitAllMenus runs before .FlyScript (../pokecrystal/home/map.asm:1927)
  for _ = 1, 120 do
    if world.flyAnim then break end
    U.wait(1)
  end
  if not ok(world.flyAnim ~= nil and world.flyAnim.phase == "from",
      "A started FlyFromAnim") then
    error("fly1960: the flight collapsed into a warp")
  end
  ok(world.flyHidden == "from", "HideSprites emptied the map")
  ok(select(1, world:flyHides()), "so nothing at all is drawn on it")

  local leafSeen, leafLeftOfWindow, leafRightOfWindow = 0, 0, 0
  local leafMinX, leafMaxX, leafNearPlayer = nil, nil, 0
  local shots = { leaves = false, fadeOut = false, fadeIn = false }
  local hidThroughFadeOut, hidThroughFadeIn = true, true
  local sawTo, sawFadeOut, sawFadeIn = false, false, false

  for _ = 1, 1800 do
    local fa = world.flyAnim
    local sox, soy = world:gbScreenOrigin()
    if fa and fa.leaves then
      for _, leaf in ipairs(fa.leaves) do
        local lx = select(1, World.leafScreenPos(leaf)) + sox
        leafSeen = leafSeen + 1
        if lx < sox - 16 then leafLeftOfWindow = leafLeftOfWindow + 1 end
        if lx > sox + 192 then leafRightOfWindow = leafRightOfWindow + 1 end
        leafMinX = math.min(leafMinX or lx, lx)
        leafMaxX = math.max(leafMaxX or lx, lx)
        local px = (p.px or 0) - (world.camera.x or 0)
        if math.abs(lx - px) <= 40 then leafNearPlayer = leafNearPlayer + 1 end
      end
      if not shots.leaves and leafSeen >= 12 then
        shots.leaves = true
        U.shot(game, out .. "/01-fly-leaves.png")
      end
    end
    local ms = world.mapSetup
    if ms and ms.phase == "out" then
      sawFadeOut = true
      if not select(1, world:flyHides()) then hidThroughFadeOut = false end
      if not shots.fadeOut then
        shots.fadeOut = true
        U.shot(game, out .. "/02-fade-out.png")
      end
    elseif ms and ms.phase == "in" then
      sawFadeIn = true
      local _, hidePlayer = world:flyHides()
      if not hidePlayer then hidThroughFadeIn = false end
      if not shots.fadeIn and (ms.step or 99) <= 2 then
        shots.fadeIn = true
        U.shot(game, out .. "/03-fade-in.png")
      end
    end
    if fa and fa.phase == "to" then sawTo = true end
    if sawTo and not fa then break end
    U.wait(1)
  end

  ok(leafSeen > 0, ("the sweep spawned leaves (%d samples)"):format(leafSeen))
  ok(leafLeftOfWindow == 0 and leafRightOfWindow == 0,
    ("every leaf stayed on the GB screen (%d left, %d right, x %s..%s)")
      :format(leafLeftOfWindow, leafRightOfWindow, tostring(leafMinX),
        tostring(leafMaxX)))
  ok(leafNearPlayer > 0,
    ("and %d sample(s) swept past the player"):format(leafNearPlayer))
  ok(sawFadeOut and hidThroughFadeOut,
    "the whole map stayed hidden through the fade out")
  ok(sawFadeIn and hidThroughFadeIn,
    "and the player stayed hidden through the fade in")
  ok(sawTo, "FlyToAnim ran on the far side")

  U.wait(30)
  ok(world.flyAnim == nil, "the animation is over")
  ok(world.flyHidden == nil, ".ReturnFromFly respawned the player")
  local hideAll, hidePlayer = world:flyHides()
  ok(not hideAll and not hidePlayer, "and he is drawn again")
  ok(world.map.id ~= "NEW_BARK_TOWN",
    ("landed on %s at (%d,%d)"):format(world.map.id, p.cellX, p.cellY))
  U.shot(game, out .. "/04-fly-landed.png")

  U.log("flew out of New Bark Town for you (#1960). two things to judge:")
  U.log("01-fly-leaves.png -- the leaves must sweep across the middle of the")
  U.log("screen, in and around the flying icon, not bunched down the far left")
  U.log("edge of the window.")
  U.log("02-fade-out.png and 03-fade-in.png -- the player's own sprite must")
  U.log("NOT be standing there during either white fade; he only comes back")
  U.log("after the landing swoop, as in 04-fly-landed.png.")
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
