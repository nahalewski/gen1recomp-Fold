package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end

local Kit = require("src.ui.kit.Kit")
local Theme = require("src.ui.kit.Theme")
local PAL = Theme.PAL
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")

local realFill = Theme.fillRounded
local fills = nil

local function sameColor(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function spyOn()
  fills = {}
  Theme.fillRounded = function(x, y, w, h, color, alpha, radius)
    fills[#fills + 1] = { x = x, y = y, w = w, h = h,
      color = color, alpha = alpha }
    return realFill(x, y, w, h, color, alpha, radius)
  end
end

local function spyOff()
  Theme.fillRounded = realFill
end

local function filledWith(rect, color)
  for _, f in ipairs(fills) do
    if math.abs(f.x - rect.x) < 1 and math.abs(f.y - rect.y) < 1
        and math.abs(f.w - rect.w) < 1 and (f.alpha or 1) > 0.5
        and sameColor(f.color, color) then
      return true
    end
  end
  return false
end

local function drawGamePopup(tab)
  love.graphics.getDimensions = function() return 1280, 720 end
  love.graphics.getPixelDimensions = function() return 1280, 720 end
  local imp = RomImporter.new(function() end, { launcher = true })
  imp.tab = tab
  imp.ready = { red = true, blue = true, yellow = true, gold = true }
  imp._gamePopup = true
  Kit.focusId = nil
  local ok, err = pcall(LauncherView.draw, imp)
  check(ok, "first Choose-game frame draws: " .. tostring(err))
  spyOn()
  ok, err = pcall(LauncherView.draw, imp)
  spyOff()
  check(ok, "second Choose-game frame draws: " .. tostring(err))
  local rects = {}
  for i = 1, (Kit._navPrevN or 0) do
    local slot = Kit._nav[i]
    if slot and slot.id then
      rects[slot.id] = { x = slot.x, y = slot.y, w = slot.w, h = slot.h }
    end
  end
  return rects
end

local rects = drawGamePopup("blue")
check(rects["gamepop-blue"] and rects["gamepop-red"],
  "the Choose-game list is in the nav graph")
check(filledWith(rects["gamepop-blue"], PAL.railBlue),
  "Blue cartridge: only the Blue row carries a solid rail fill")
check(not filledWith(rects["gamepop-red"], PAL.railRed),
  "Blue cartridge: Red is not filled even when the ring parks on it")

Kit.setFocus("gamepop-blue")
rects = drawGamePopup("red")
check(filledWith(rects["gamepop-red"], PAL.railRed),
  "Red cartridge: Red stays filled while the ring sits elsewhere")
check(not filledWith(rects["gamepop-blue"], PAL.railBlue),
  "Red cartridge: the focused Blue row is ring-only")

local function tabFace(opts)
  Kit.blockClicks = false
  Kit.beginFrame()
  spyOn()
  Kit.button(10, 10, 100, 20, "Red", opts)
  spyOff()
  Kit.endFrame()
  return { x = 10, y = 10, w = 100, h = 20 }
end

Kit.setFocus("tab-face")
local r = tabFace({ face = "tab", id = "tab-face", color = PAL.railRed,
  active = false })
check(not filledWith(r, PAL.railRed),
  "tab face: the focused-but-inactive row is not filled with its cart colour")

Kit.setFocus("tab-face")
r = tabFace({ face = "tab", id = "tab-face", color = PAL.railRed,
  active = true })
check(filledWith(r, PAL.railRed),
  "tab face: the active row is filled with its cart colour")

print("ok   launcher choose-game fill vs focus")
