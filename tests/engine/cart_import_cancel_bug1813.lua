package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end
love.graphics.polygon = love.graphics.polygon or function() end

local Kit = require("src.ui.kit.Kit")
local Platform = require("src.core.Platform")
local HostShell = require("src.core.HostShell")
local FilePicker = require("src.core.FilePicker")
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")

love.graphics.getDimensions = function() return 1280, 720 end
love.graphics.getPixelDimensions = function() return 1280, 720 end

local pumped = 0
local realPump = HostShell.pumpHostEvents
HostShell.pumpHostEvents = function() pumped = pumped + 1 end

local realPopen, realPclose = HostShell.popen, HostShell.pclose
HostShell.popen = function()
  return { read = function() return "" end, close = function() end }
end
HostShell.pclose = function() end

local realCanSpawn = Platform.canSpawnProcess
Platform.canSpawnProcess = function() return true end
local realGetOS = love.system.getOS
love.system.getOS = function() return "OS X" end

local cancelled = FilePicker.open("Choose a cart", { label = "Cart",
  exts = { "g1rcart" } })
eq(cancelled, nil, "empty chooser output reads as a cancel")
eq(pumped, 1, "the chooser's button-up is pumped once the read unblocks")

HostShell.popen, HostShell.pclose = realPopen, realPclose
HostShell.pumpHostEvents = realPump
love.system.getOS = realGetOS

local realOpen = FilePicker.open
FilePicker.open = function() return nil end

local imp = RomImporter.new(function() end, { launcher = true })
imp.tab = "red"
imp.ready = { red = true, blue = true }
imp._cartPopup = "red"

love.mouse.isDown = function() return false end
imp._prevMouseDown = true
imp._mouseAt = { x = 10, y = 10 }
imp._clickPt = { x = 10, y = 10 }

eq(imp:importCartFile("red"), false, "a cancelled cart import commits nothing")
eq(imp._cartPopup, "red", "Custom Carts stays open after a cancel")
eq(imp._cartNotice, nil, "a cancel is not an error worth a notice")
eq(imp._mouseAt, nil, "the armed drag is dropped when the dialog returns")
eq(imp._clickPt, nil, "no stale click survives the dialog")
eq(imp._prevMouseDown, false,
   "the polled click machine resyncs to the real button state")

local ok, err = pcall(LauncherView.draw, imp)
check(ok, "Custom Carts draws after the cancel: " .. tostring(err))

local close = nil
for i = 1, (Kit._navPrevN or 0) do
  local slot = Kit._nav[i]
  if slot and slot.id == "cartpop-close" then close = slot end
end
check(close ~= nil, "the Close control is in the modal's nav graph")

if close then
  LauncherView.clickAt(imp, close.x + close.w / 2, close.y + close.h / 2)
  ok, err = pcall(LauncherView.draw, imp)
  check(ok, "the click frame draws: " .. tostring(err))
  LauncherView.update(imp, 1 / 60)
  eq(imp._cartPopup, nil, "Close still closes Custom Carts after a cancel")
end

FilePicker.open = realOpen
Platform.canSpawnProcess = realCanSpawn

local src = io.open("src/core/FilePicker.lua", "r"):read("*a")
check(not src:match("io%.popen%("),
  "FilePicker never reaches io.popen directly")
check(src:match("HostShell%.pumpHostEvents"),
  "FilePicker's blocking read pumps host events afterwards")

print("ok   cart import cancel keeps the modal live")
