-- engine/events/field_moves.asm:300, engine/sprite_anims/functions.asm:642

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local World = require("src.world.gen2.World")

local function flyWorld()
  local world = World.new({ data = {}, save = { player = {} } })
  world.player = { px = 64, py = 64, facing = "down" }
  world.flyIconFor = function() return { draw = function() end } end
  world.playSfxNamed = function() end
  return world
end

-- engine/events/field_moves.asm:304 (depixel 10, 10, 4, 0)
do
  local world = flyWorld()
  check(world:startFlyAnim("from", { species = "PIDGEY" }), "FlyFromAnim runs")
  local fa = world.flyAnim
  local bx, by = World.birdScreenPos(fa)
  eq(bx, 64, "the bird starts on the OAM column the cart uses")
  eq(by, 60, "and four pixels above the player, not on his own row")
  check(not World.offGbScreen(bx, by, 16, 16), "so it is on the LCD")
end

-- engine/sprite_anims/functions.asm:642 (SpriteAnimFunc_FlyFrom)
do
  local world = flyWorld()
  check(world:startFlyAnim("from", { species = "PIDGEY" }), "FlyFromAnim runs")
  local fa = world.flyAnim
  -- engine/events/field_moves.asm:305-311
  eq(fa.preroll, World.FLY_FROM_PREROLL, "InitGFX's frames come first")
  for _ = 1, fa.preroll do world:stepFlyAnim() end
  eq(fa.left, 128, "and spend none of the 128-frame counter")
  local steps, culled = 0, nil
  while world.flyAnim and steps < 400 do
    world:stepFlyAnim()
    steps = steps + 1
    local x, y = World.birdScreenPos(fa)
    if steps == 64 then
      eq(fa.hover, 0, "the hover burns 64 frames")
      eq(fa.y, 0, "and moves nothing")
    end
    if World.offGbScreen(x, y, 16, 16) and not culled then culled = steps end
  end
  eq(steps, 129, "the 128-frame counter runs out")
  eq(fa.y, -84, "YCOORD walked 84 pixels up")
  eq(select(2, World.birdScreenPos(fa)), -24,
    "which puts the whole icon above the LCD")
  check(culled and culled <= 106,
    "and it is gone by the end of the rise, not parked for the tail")
  check(steps - culled >= 22, "for the last 22 frames of the counter")
end

-- engine/sprite_anims/core.asm:229 (the OAM byte wraps; there is no margin)
do
  local world = flyWorld()
  check(world:startFlyAnim("from", { species = "PIDGEY" }), "FlyFromAnim runs")
  local fa = world.flyAnim
  fa.y = -84
  local bx, by = World.birdScreenPos(fa)
  for _, viewH in ipairs({ 144, 156, 180, 216 }) do
    world.viewW, world.viewH = 160, viewH
    local _, soy = world:gbScreenOrigin()
    check(World.offGbScreen(bx, by, 16, 16),
      "the cull drops the parked bird at viewH " .. viewH)
    if viewH >= 180 then
      check(soy + by + 16 > 0,
        "which is the only thing keeping it out of the letterbox margin")
    end
  end
end

-- engine/events/field_moves.asm:338 (depixel 31, 10, 4, 0)
do
  local world = flyWorld()
  check(world:startFlyAnim("to", { species = "PIDGEY" }), "FlyToAnim runs")
  local fa = world.flyAnim
  eq(fa.y, -88, "the landing starts 88 pixels up, at YCOORD -4")
  local sx, sy = World.birdScreenPos(fa)
  eq(sy, -28, "fully off the top of the LCD")
  check(World.offGbScreen(sx, sy, 16, 16), "so nothing is drawn on frame one")
  local steps, moved = 0, 0
  while world.flyAnim and steps < 400 do
    local before = fa.y
    world:stepFlyAnim()
    steps = steps + 1
    if fa.y ~= before then moved = moved + 1 end
  end
  eq(steps, 65, "the 64-frame counter runs out")
  eq(moved, 44, "after 44 frames of descent")
  eq(fa.y, 0, "landing on the player's row")
  eq(fa.amp, 0, "with the wobble fully decayed")
end

-- engine/sprite_anims/functions.asm:1389 (SpriteAnimFunc_FlyLeaf)
do
  local dying = { x = 182, y = 0x40, xoff = 0 }
  local lx, ly = World.leafScreenPos(dying)
  check(World.offGbScreen(lx, ly, 8, 8),
    "a leaf past the right edge is not drawn in the margin")
  local mid = { x = 90, y = 0x40, xoff = 0 }
  local mx, my = World.leafScreenPos(mid)
  check(not World.offGbScreen(mx, my, 8, 8), "a mid-sweep leaf still draws")
end

T.finish("gen2 fly bird leaves the LCD bug2015")
