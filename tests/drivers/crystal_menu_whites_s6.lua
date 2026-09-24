-- ../pokecrystal/home/map.asm:1910-1940
-- ../pokecrystal/engine/menus/start_menu.asm:444-518
--   POKEPORT_IDENTITY=crystal-sep01b POKEPORT_VERSION=crystal POKEPORT_TOUCH=0 \
--     POKEPORT_SPEED=1 POKEPORT_DRIVER=tests/drivers/crystal_menu_whites_s6.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-menu-whites
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local MenuFade = require("src.ui.gen2.MenuFade")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-menu-whites"
  os.execute('mkdir -p "' .. out .. '" 2>/dev/null')
  local fails = 0

  local function ok(cond, msg)
    if cond then
      print("[menuwhite] ok   " .. msg)
    else
      fails = fails + 1
      print("[menuwhite] FAIL " .. msg)
    end
    return cond
  end

  local function top() return game.stack:top() end
  local function topId()
    local state = top()
    return state and state.screenId or nil
  end

  local counts, shooting, shotIndex = nil, nil, 0
  local realDraw = love.draw
  love.draw = function(...)
    realDraw(...)
    if not counts then return end
    local state = top()
    counts.frames = counts.frames + 1
    if state and state.screenId == "Gen2MenuFade" then
      counts.fade = counts.fade + 1
      if state:level() >= 1 then
        counts.white = counts.white + 1
      else
        counts.ramp = counts.ramp + 1
      end
    end
    if shooting then
      shotIndex = shotIndex + 1
      local path = ("%s/%s-%02d.png"):format(out, shooting, shotIndex)
      love.graphics.captureScreenshot(function(imagedata)
        local f = io.open(path, "wb")
        if f then
          f:write(imagedata:encode("png"):getString())
          f:close()
        end
      end)
    end
  end

  local function startCount(label)
    counts = { frames = 0, fade = 0, white = 0, ramp = 0 }
    shooting, shotIndex = label, 0
  end
  local function stopCount()
    local c = counts
    counts, shooting = nil, nil
    return c
  end

  local function settle()
    for _ = 1, 400 do
      if topId() == nil and not game.world:busy() then return true end
      U.wait(1)
    end
    return false
  end

  local function openStart()
    for _ = 1, 10 do
      U.tap(game, "start")
      for _ = 1, 10 do
        if topId() == "Gen2StartMenu" then return top() end
        U.wait(1)
      end
    end
    return nil
  end

  local function cursorTo(menu, id)
    for _ = 1, 12 do
      if menu.list:current().value == id then return true end
      U.tap(game, "down")
      U.wait(2)
    end
    return false
  end

  local function waitTop(id, limit)
    for _ = 1, limit or 120 do
      if topId() == id then return true end
      U.wait(1)
    end
    return false
  end

  U.wait(45)
  local world = game.world
  local save, data = game.save, game.data
  if not ok(world and world.map, "booted into the overworld") then
    error("menuwhite: no world")
  end
  save.party = { Mon.new(data, "CYNDAQUIL", 12), Mon.new(data, "PIDGEY", 8) }
  save.engineFlags = save.engineFlags or {}
  save.engineFlags[4] = true
  save.engineFlags[11] = true
  world.mapScenes = world.mapScenes or {}
  world.mapScenes.NEW_BARK_TOWN = 1
  world:warpToMapId("NEW_BARK_TOWN", 9, 8, "down")
  U.wait(15)
  settle()

  local function openPage(id, pageId, label, shots)
    local menu = openStart()
    if not ok(menu ~= nil, label .. ": START opened the menu") then return end
    if not ok(cursorTo(menu, id), label .. ": cursor on the row") then return end
    startCount(shots and (label .. "-open") or nil)
    if not shots then shooting = nil end
    U.tap(game, "a")
    local landed = waitTop(pageId, 160)
    local c = stopCount()
    local wantWhite = MenuFade.openWhite(id, #save.party)
    ok(landed, label .. ": the page came up")
    ok(c.fade == MenuFade.framesOut(wantWhite),
      ("%s: the fade ran %d drawn frames (want %d = 8 + %d)")
        :format(label, c.fade, MenuFade.framesOut(wantWhite), wantWhite))
    ok(c.white == MenuFade.OUT_WHITE_FRAMES + wantWhite,
      ("%s: %d of them white (want %d = 2 + %d)")
        :format(label, c.white, MenuFade.OUT_WHITE_FRAMES + wantWhite, wantWhite))
    ok(c.ramp == MenuFade.OUT_FRAMES - MenuFade.OUT_WHITE_FRAMES,
      ("%s: %d ramp frames (want 6)"):format(label, c.ramp))
    U.wait(12)
    U.shot(game, ("%s/%s-page.png"):format(out, label))
    startCount(shots and (label .. "-close") or nil)
    if not shots then shooting = nil end
    U.tap(game, "b")
    local back = waitTop("Gen2StartMenu", 160)
    local d = stopCount()
    local wantClose = MenuFade.closeWhite(id)
    ok(back, label .. ": B came back to the START menu")
    ok(d.fade == MenuFade.framesIn(wantClose),
      ("%s: the close fade ran %d drawn frames (want %d = %d + 6)")
        :format(label, d.fade, MenuFade.framesIn(wantClose), wantClose))
    ok(d.white == wantClose,
      ("%s: %d of them white (want %d)"):format(label, d.white, wantClose))
    ok(d.ramp == MenuFade.IN_RAMP_FRAMES,
      ("%s: %d ramp frames (want 6)"):format(label, d.ramp))
    U.wait(6)
    U.tap(game, "start")
    ok(settle(), label .. ": START closed the menu")
  end

  openPage("pack", "Gen2PackMenu", "pack", true)
  openPage("pokemon", "Gen2PartyMenu", "pokemon", true)
  openPage("pokegear", "Gen2Pokegear", "pokegear", false)
  openPage("status", "Gen2TrainerCard", "card", false)

  love.draw = realDraw
  U.log("START page whites (S6): shots are in " .. out .. ".")
  if fails > 0 then
    U.log(("%d assertion(s) failed above."):format(fails))
    love.event.quit(1)
    return
  end
  love.event.quit()
end
