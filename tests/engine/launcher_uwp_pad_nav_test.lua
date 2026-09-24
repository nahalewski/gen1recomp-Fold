package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local setPositionCalls = 0
local mouseX, mouseY = 0, 0
love.mouse.getPosition = function() return mouseX, mouseY end
love.mouse.setPosition = function(x, y)
  setPositionCalls = setPositionCalls + 1
  mouseX, mouseY = x, y
end

local Platform = require("src.core.Platform")
local Kit = require("src.ui.kit.Kit")
local RomImporter = require("src.import.RomImporter")

local osName = "OS X"
love.system.getOS = function() return osName end

local function setHost(name)
  osName = name
  Platform._resetForTests()
end

local function freshImporter()
  Kit.focusId = nil
  Kit._navQueue = nil
  return setmetatable({
    isNX = false,
    _padCursor = { x = 100, y = 100 },
    _padCursorActive = false,
    _padAxis = { leftx = 0, lefty = 0, righty = 0 },
    _padDir = {},
    _rawHatDirs = {},
    _padInited = true,
    _flex = true,
    tab = "red",
  }, RomImporter)
end

local navLog = {}
local realNavigate = Kit.navigate
Kit.navigate = function(dir)
  navLog[#navLog + 1] = dir
  Kit._navQueue = nil
end

local function stick(imp, ax, ay, frames, dt)
  dt = dt or (1 / 60)
  imp._padAxis.leftx = ax
  imp._padAxis.lefty = ay
  for _ = 1, frames do imp:_updatePadCursor(dt) end
end

setHost("UWP")
do
  navLog = {}
  setPositionCalls = 0
  local imp = freshImporter()
  check(imp:_consolePointerHost(), "UWP counts as a console pointer host")
  stick(imp, 1, 0, 10)
  check(not imp._padCursorActive,
    "UWP: a stick push does not arm the virtual mouse")
  eq(#navLog, 1, "a held stick steps the ring once before the repeat delay")
  eq(navLog[1], "right", "right on the stick is right on the ring")
  eq(setPositionCalls, 0, "UWP never warps the system mouse")
  eq(imp._padCursor.x, 100, "the pad cursor stays parked in menu-nav mode")

  stick(imp, 1, 0, 30)
  check(#navLog > 1, "holding the stick repeats the step")
  stick(imp, 0.35, 0, 5)
  check(#navLog > 0, "0.35 is inside the release hysteresis, so the latch holds")
  stick(imp, 0, 0, 2)
  local released = #navLog
  stick(imp, 0.4, 0, 5)
  eq(#navLog, released, "0.4 is under the latch threshold, so nothing steps")
  stick(imp, 0, 0, 2)
  stick(imp, 0, -1, 1)
  eq(navLog[#navLog], "up", "up on the stick is up on the ring")
end

do
  navLog = {}
  local imp = freshImporter()
  imp._padCursorActive = true
  stick(imp, 1, 0, 10)
  check(imp._padCursor.x > 100,
    "UWP: cursor mode still moves the pad pointer")
  eq(#navLog, 0, "cursor mode does not also walk the ring")
  eq(setPositionCalls, 0, "UWP cursor mode never warps the system mouse")
  check(imp._nxPointerBridge, "UWP installs the getPosition bridge")
  imp:_restoreNxPointerBridge()

  mouseX, mouseY = 400, 400
  imp:_updatePadCursor(1 / 60)
  check(imp._padCursorActive,
    "UWP: system-mouse drift does not yield the pad cursor")
end

do
  navLog = {}
  local imp = freshImporter()
  imp._padCursorActive = true
  imp:gamepadpressed(nil, "y")
  check(not imp._padCursorActive, "Y drops back to Controller Menu Navigation")
  eq(imp._cursorModeToast, "Controller Menu Navigation [Y]",
    "the toast names the mode Y selected")
  stick(imp, 1, 0, 10)
  check(not imp._padCursorActive,
    "a stick still off-centre does not undo the Y toggle")
end

setHost("OS X")
do
  navLog = {}
  setPositionCalls = 0
  local imp = freshImporter()
  check(not imp:_consolePointerHost(), "desktop is not a console pointer host")
  stick(imp, 1, 0, 10)
  check(imp._padCursorActive, "desktop: the stick still arms the virtual mouse")
  check(setPositionCalls > 0, "desktop still warps the system mouse")
  eq(#navLog, 0, "desktop stick does not walk the ring by default")
end

do
  navLog = {}
  local imp = freshImporter()
  imp._padCursorActive = true
  imp:gamepadpressed(nil, "y")
  check(imp._padNavChosen, "Y records that menu nav was the deliberate choice")
  stick(imp, 1, 0, 10)
  check(not imp._padCursorActive,
    "desktop: after Y the stick keeps the ring instead of the mouse")
  eq(#navLog, 1, "desktop menu nav steps the ring")
end

Kit.navigate = realNavigate
setHost("OS X")

print("ok   launcher UWP pad menu navigation")
