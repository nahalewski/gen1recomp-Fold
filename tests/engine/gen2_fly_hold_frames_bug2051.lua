-- ../pokecrystal/engine/pokegear/pokegear.asm:2026-2046
-- ../pokecrystal/home/map.asm:1927-1940

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local World = require("src.world.gen2.World")
local BlankScreen = require("src.ui.gen2.BlankScreen")

do
  T.eq(World.FLY_MAP_BUILD_FRAMES, 28,
    "_FlyMap: ClearBGPalettes 4 + ClearTilemap 4 + LoadTownMapGFX 7 + border 1"
      .. " + TownMapBGUpdate 7 + TownMapMon 3 + TownMapPlayerIcon 2 = 28")
  T.eq(World.MENU_EXIT_RELOAD_FRAMES, 9,
    "ReloadTilesetAndPalettes with the LCD off, bracketed 8-10")
  T.eq(World.MENU_EXIT_WHITE_FRAMES, 23,
    "ExitAllMenus: ClearBGPalettes 4 + reload 9 + WaitBGMap2 (4 + 4 on CGB)"
      .. " + FadeInFromWhite entry 6 for 2 = 23")
  T.eq(World.FLY_EXIT_WHITE_FRAMES, 31,
    "_FlyMap.exit ClearBGPalettes 4 + CloseWindow's WaitBGMap 4 + 23 = 31")
  T.eq(World.flyCancelBlankFrames(0), 21,
    ".exit 4 + .illegal CloseWindow 4 + WaitBGMap 4 + .choosemenu 4"
      .. " + WaitBGMap 4 + DelayFrame 1 = 21 with an empty party")
  T.eq(World.flyCancelBlankFrames(6), 21 + 18,
    "plus GetIconGFX's 3 frames per party mon")
  T.eq(World.FLY_FROM_PREROLL, 6,
    "FadeInFromWhite entry 3 (2) + FlyFromAnim DelayFrame + InitGFX 1 + 2 = 6")
end

do
  local fired = 0
  local blank = BlankScreen.new(nil, { frames = 28,
    onDone = function() fired = fired + 1 end })
  T.eq(blank.left, 28, "frames = 28 arms 28")
  for _ = 1, 27 do blank:update() end
  T.eq(fired, 0, "27 updates: still blank (the push tick drew frame 1)")
  blank:update()
  T.eq(fired, 1, "the 28th update fires onDone: 28 drawn blank frames")
  blank:update()
  T.eq(fired, 1, "...once")
  local default = BlankScreen.new(nil, {})
  T.eq(default.left, BlankScreen.FRAMES, "no frames: WaitBGMap's 4")
end

do
  local world = setmetatable({}, World)
  world.player = { px = 0, py = 0 }
  world.flyIconFor = function() return { draw = function() end } end
  T.eq(world:startFlyAnim("from", {}), true, "the take-off anim starts")
  local fa = world.flyAnim
  T.eq(fa.preroll, 6, "FlyFromAnim waits 6 frames before its first sprite")
  T.eq(fa.left, 128, "on top of the 128-frame timer")
  world.spawnFlyLeaves = function() error("no leaves in the preroll") end
  world.playSfxNamed = function() error("no Sfx_Fly in the preroll") end
  for i = 1, 6 do
    world:stepFlyAnim()
    T.eq(fa.left, 128, ("preroll frame %d does not spend the timer"):format(i))
  end
  T.eq(fa.preroll, 0, "six frames burn the preroll")
  world.spawnFlyLeaves = function() end
  world.playSfxNamed = function() end
  world:stepFlyAnim()
  T.eq(fa.left, 127, "then the timer runs")

  local drawn = 0
  local landing = setmetatable({}, World)
  landing.player = { px = 0, py = 0 }
  landing.flyIconFor = function() return { draw = function() drawn = drawn + 1 end } end
  landing:startFlyAnim("to", {})
  T.eq(landing.flyAnim.preroll, 0, "the landing has no preroll")

  local w2 = setmetatable({}, World)
  w2.player = { px = 0, py = 0 }
  w2.flyIconFor = function() return { draw = function() drawn = drawn + 1 end } end
  w2:startFlyAnim("from", {})
  w2.drawFlyLeaves = function() end
  w2.gbScreenOrigin = function() return 0, 0 end
  w2:drawFlyAnim(1)
  T.eq(drawn, 0, "drawFlyAnim draws nothing during the preroll")
  w2.flyAnim.preroll = 0
  w2:drawFlyAnim(1)
  T.eq(drawn, 1, "...and the bird once it is over")
end

T.finish("gen2 fly hold frames bug 2051")
