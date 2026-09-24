package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end
love.keyboard.setTextInput = love.keyboard.setTextInput or function() end

local Kit = require("src.ui.kit.Kit")
local VK = require("src.ui.kit.VirtualKeyboard")
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")

local realGetenv = os.getenv
local handheld = false
os.getenv = function(name)
  if handheld and name == "HANDHELD" then return "1" end
  return realGetenv(name)
end

love.graphics.getDimensions = function() return 1280, 720 end
love.graphics.getPixelDimensions = function() return 1280, 720 end

local imp = RomImporter.new(function() end, { launcher = true })
imp.tab = "find"
imp.ready = { red = true, blue = true }

handheld = false
eq(VK.open({ title = "Search mods" }), false,
   "off a Linux handheld the OSK refuses to open")
check(VK.active == false, "no OSK overlay on a touch-only host")

handheld = true
check(VK.open({ text = "", title = "Search mods",
  onDone = function(newText, confirmed)
    if confirmed then imp.findQuery = newText end
  end }) == true, "the OSK opens on a handheld")

local pressRects = {}
local realPress = Kit.press
local recording = false
Kit.press = function(x, y, w, h)
  if recording and not Kit.blockClicks then
    pressRects[#pressRects + 1] = { x = x, y = y, w = w, h = h }
  end
  return realPress(x, y, w, h)
end

local function frame(click)
  imp._clickPt = click
  pressRects = {}
  recording = true
  local ok, err = pcall(LauncherView.draw, imp)
  recording = false
  check(ok, "OSK frame draws: " .. tostring(err))
  return pressRects
end

local rects = frame(nil)
check(#rects > 0,
  "the OSK keys register with Kit.press instead of drawing behind a shield")

local first = rects[1]
if first then
  frame({ x = first.x + first.w / 2, y = first.y + first.h / 2 })
  eq(VK.text, "1", "tapping the top-left key types it")
end

VK.text = "pikachu"
VK.close(true)
check(VK.active == false, "Done closes the OSK")
eq(imp.findQuery, "pikachu", "Done writes findQuery, not a dead _findQuery")
eq(imp._findQuery, nil, "nothing writes the dead _findQuery field")

Kit.press = realPress
os.getenv = realGetenv

print("ok   launcher on-screen keyboard taps")
