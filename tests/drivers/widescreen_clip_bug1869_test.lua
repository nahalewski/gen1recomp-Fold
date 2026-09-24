-- engine/events/halloffame.asm:270 (#1869)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/widescreen_clip_bug1869_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/widescreen-clip love .
local U = require("tests.drivers.util")

local Chrome = require("src.ui.gen2.Chrome")
local Mon = require("src.battle.gen2.Mon")
local Permissions = require("src.world.gen2.Permissions")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/widescreen-clip"
  local failures = 0

  local function ok(label, condition, detail)
    if condition then
      print("[wide] ok   " .. label)
    else
      failures = failures + 1
      print("[wide] FAIL " .. label .. " " .. tostring(detail))
    end
  end

  local function shot(path)
    if not U.shot(game, path) then failures = failures + 1 end
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  if love.window and love.window.setMode then
    love.window.setMode(1280, 840, { resizable = true })
    U.wait(6)
  end
  local winW, winH = love.graphics.getDimensions()
  local scale = Chrome.fitScale(winW, winH)
  local ox, oy = Chrome.fitOrigin(winW, winH, scale)
  ok(("the window leaves bars to look at (%dx%d, panel at %d,%d x%d)")
    :format(winW, winH, ox, oy, scale), ox > 8 and oy > 8, ox .. "," .. oy)

  local G = love.graphics
  local function panelClip(label, drawIt)
    local rects = {}
    local realSet, realIntersect = G.setScissor, G.intersectScissor
    G.setScissor = function(...) rects[#rects + 1] = { ... } return realSet(...) end
    if realIntersect then
      G.intersectScissor = function(...)
        rects[#rects + 1] = { ... }
        return realIntersect(...)
      end
    end
    local fine, err = pcall(drawIt)
    G.setScissor, G.intersectScissor = realSet, realIntersect
    if not fine then
      ok(label .. " draws", false, err)
      return
    end
    local matched = false
    for _, r in ipairs(rects) do
      if r[1] == ox and r[2] == oy and r[3] == Chrome.SCREEN_W * 8 * scale
          and r[4] == Chrome.SCREEN_H * 8 * scale then
        matched = true
      end
    end
    ok(label .. " clips to the 160x144 panel before it draws", matched,
      #rects .. " scissors, none matching " .. ox .. "," .. oy)
  end

  game.save.party = { Mon.new(game.data, "CYNDAQUIL", 12) }
  assert(world:setMap("ROUTE_29", 15, 11, "down"), "setMap ROUTE_29 failed")
  U.wait(8)
  if not Permissions.isWalkable(world:playerCollision()) then
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      if world:setMap("ROUTE_29", 15 + step[1], 11 + step[2], "down")
          and Permissions.isWalkable(world:playerCollision()) then
        break
      end
    end
    U.wait(8)
  end
  assert(world:startBattle({ wild = Mon.new(game.data, "PIDGEY", 4) }),
    "startBattle failed")
  local battle
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then battle = top break end
    U.wait(1)
  end
  ok("the battle screen came up", battle ~= nil, battle)
  if battle then
    U.log("01: the first frames of the battle intro. The player's backpic")
    U.log("slides in from the right EDGE OF THE PANEL. The white surround")
    U.log("around it must be empty -- a trainer sprite parked out in the white")
    U.log("void to the right of the screen is the bug.")
    shot(out .. "/01-battle-intro.png")
    U.wait(20)
    shot(out .. "/02-battle-intro-mid.png")
    for _ = 1, 150 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(2)
    end
    U.log("03: the FIGHT menu. Nothing at all outside the panel.")
    shot(out .. "/03-battle-menu.png")
    panelClip("BattleState:drawWidescreen",
      function() battle:drawWidescreen(winW, winH) end)
    game.stack:pop()
    U.wait(10)
  end

  world:hallOfFame(function() end)
  local hof
  for _ = 1, 600 do
    local top = game.stack:top()
    if top and top.phase then hof = top break end
    U.wait(1)
  end
  ok("the Hall of Fame is up", hof ~= nil, hof)
  if hof then
    hof.phase = "backpic"
    hof.scx = 0x50
    U.wait(2)
    U.log("04: the Hall of Fame mid-slide. The bars left and right of the")
    U.log("panel must be solid black. A whole backpic sitting in the left bar,")
    U.log("or a scrap of one in the right bar, is the wrap copy leaking.")
    shot(out .. "/04-hof-backpic.png")
    panelClip("HallOfFame:drawWidescreen",
      function() hof:drawWidescreen(winW, winH) end)
    for _ = 1, 60 do
      U.tap(game, "a")
      U.wait(4)
      if game.stack:top() ~= hof then break end
    end
  end

  local credits = game.stack:top()
  if not (credits and credits.drawBorderStrips) then
    game.stack:pop()
    world:credits(function() end)
    for _ = 1, 600 do
      local top = game.stack:top()
      if top and top.drawBorderStrips then credits = top break end
      U.wait(1)
    end
  end
  ok("the credits are rolling", credits ~= nil, credits)
  if credits then
    U.wait(120)
    U.log("05: the credits. The two border strips run edge to edge INSIDE the")
    U.log("panel only. Wavy white bands continuing through the black bars to")
    U.log("the window edge is the strip loop drawing past x=0 and x=160.")
    shot(out .. "/05-credits.png")
    panelClip("Credits:drawWidescreen",
      function() credits:drawWidescreen(winW, winH) end)
    U.wait(240)
    shot(out .. "/06-credits-later.png")
  end

  print(failures == 0 and "[wide] PASS widescreen_clip_bug1869"
    or ("[wide] FAIL widescreen_clip_bug1869 (%d)"):format(failures))
  U.log("the window is left at 1280x840; resize it and the bars must stay")
  U.log("empty at every size.")

  while true do coroutine.yield() end
end
