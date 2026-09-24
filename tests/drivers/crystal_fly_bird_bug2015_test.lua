-- ../pokecrystal/engine/events/field_moves.asm:300
-- ../pokecrystal/engine/sprite_anims/functions.asm:642
-- ../pokecrystal/engine/sprite_anims/core.asm:229
--   POKEPORT_IDENTITY=crystal-aug31 POKEPORT_GAME=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/crystal_fly_bird_bug2015_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-fly2015
local U = require("tests.drivers.util")

local FieldMoves = require("src.world.gen2.FieldMoves")
local Mon = require("src.battle.gen2.Mon")
local World = require("src.world.gen2.World")
local Zoom = require("src.render.Zoom")

local FLY_SPECIES = "PIDGEOTTO"

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-fly2015"
  local fails = 0

  local function ok(cond, msg)
    if cond then
      print("[fly2015] ok   " .. msg)
    else
      fails = fails + 1
      print("[fly2015] FAIL " .. msg)
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
    error("fly2015: no world")
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

  Zoom.step(-2, world:fitScale())
  U.wait(6)
  ok(world.viewH and world.viewH > 152,
    ("zoomed out to a %dx%d world view (the margin the bird used to park in)")
      :format(world.viewW or 0, world.viewH or 0))

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
    error("fly2015: no start menu")
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
    error("fly2015: no party list")
  end
  tap("a")
  local sub = party.submenu
  if not ok(sub ~= nil, "A opened the action submenu") then
    error("fly2015: no submenu")
  end
  local flyRow
  for index, item in ipairs(sub.items) do
    if item.id == "FLY" then flyRow = index end
  end
  if not ok(flyRow ~= nil, "which lists FLY") then
    error("fly2015: the submenu has no FLY row")
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
    error("fly2015: no picker")
  end
  tap("up")
  U.wait(6)

  U.tap(game, "a")
  for _ = 1, 180 do
    U.wait(1)
    if world.flyAnim and world.flyAnim.phase == "from" then break end
  end
  if not ok(world.flyAnim ~= nil and world.flyAnim.phase == "from",
      "A started FlyFromAnim") then
    error("fly2015: the flight collapsed into a warp")
  end

  local shots = { hover = false, rising = false, gone = false, land = false }
  local tail, tailDrawn, tailInWindow = 0, 0, 0
  local landStart, sawTo = nil, false
  local risenY = nil

  for _ = 1, 1800 do
    local fa = world.flyAnim
    if fa then
      local bx, by = World.birdScreenPos(fa)
      local _, soy = world:gbScreenOrigin()
      local gone = World.offGbScreen(bx, by, 16, 16)
      if fa.phase == "from" then
        if not shots.hover and fa.hover and fa.hover > 0 and fa.t >= 20 then
          shots.hover = true
          U.shot(game, out .. "/01-bird-hover.png")
        end
        if not shots.rising and fa.y <= -40 and fa.y > -70 then
          shots.rising = true
          U.shot(game, out .. "/02-bird-rising.png")
        end
        if fa.y <= -84 then
          risenY = by
          tail = tail + 1
          if not gone then tailDrawn = tailDrawn + 1 end
          if soy + by + 16 > 0 then tailInWindow = tailInWindow + 1 end
          if not shots.gone and fa.left <= 20 then
            shots.gone = true
            U.shot(game, out .. "/03-bird-gone.png")
          end
        end
      else
        sawTo = true
        landStart = landStart or by
        if not shots.land and fa.y >= -20 then
          shots.land = true
          U.shot(game, out .. "/04-landing.png")
        end
      end
    end
    if sawTo and not world.flyAnim then break end
    U.wait(1)
  end

  ok(tail > 0, ("the rise finished (%d tail frames)"):format(tail))
  ok(risenY == -24,
    ("and left the icon at GB y %s, above the LCD"):format(tostring(risenY)))
  ok(tailDrawn == 0,
    ("nothing was drawn for the whole tail (%d/%d frames drawn)")
      :format(tailDrawn, tail))
  ok(tailInWindow > 0,
    ("and the world view was tall enough to have shown it (%d frames)")
      :format(tailInWindow))
  ok(sawTo, "FlyToAnim ran on the far side")
  ok(landStart == -28,
    ("which starts off the top of the LCD at GB y %s")
      :format(tostring(landStart)))

  U.wait(30)
  ok(world.flyAnim == nil, "the animation is over")
  ok(world.flyHidden == nil, ".ReturnFromFly respawned the player")
  U.shot(game, out .. "/05-fly-landed.png")

  U.log("flew out of New Bark Town zoomed out (#2015). judge these shots:")
  U.log("03-bird-gone.png -- the window must be EMPTY of the flying icon:")
  U.log("no bird, no sliver of one, parked at the top of the frame. this is")
  U.log("the shot the bug was about.")
  U.log("01/02 -- the bird hovers over the player and rises straight up out")
  U.log("of the GB screen; 04/05 -- it swoops back down onto the new map.")
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
