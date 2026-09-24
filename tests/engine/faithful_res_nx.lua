package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FaithfulRes = require("src.core.FaithfulRes")
local VideoMode = require("src.core.VideoMode")
local Platform = require("src.core.Platform")
local Renderer = require("src.render.Renderer")
local Zoom = require("src.render.Zoom")

local g = love.graphics
local realDims, realPixelDims = g.getDimensions, g.getPixelDimensions
local savedWindow, savedSystem = love.window, love.system
local savedOffset = Zoom.offset

local setModeCalls, fullscreenCalls = {}, {}
local winW, winH = 0, 0

local function window(w, h) winW, winH = w, h end

local function pose(w, h, osName)
  winW, winH = w, h
  love.system = { getOS = function() return osName or "NX" end }
  g.getDimensions = function() return w, h end
  g.getPixelDimensions = function() return w, h end
  love.window = {
    getMode = function()
      return winW, winH, { fullscreen = false, resizable = true,
                           minwidth = 480, minheight = 360 }
    end,
    setMode = function(sw, sh, flags)
      winW, winH = sw, sh
      setModeCalls[#setModeCalls + 1] = { w = sw, h = sh, flags = flags }
    end,
    setFullscreen = function(on, kind)
      fullscreenCalls[#fullscreenCalls + 1] = { on = on, kind = kind }
    end,
  }
  Platform._resetForTests()
end

Renderer.uiWidth, Renderer.uiHeight = Renderer.WIDTH, Renderer.HEIGHT
Zoom.offset = 0

pose(1280, 720, "NX")

T.eq(FaithfulRes.fixedDisplay(), true, "the Switch reads as a fixed display")
T.eq(FaithfulRes.isMobile(), true, "and the old predicate name still answers")
T.eq(FaithfulRes.maxLevel(), 1, "so the row is ON/OFF, not a 1X-4X ladder")
T.eq(#FaithfulRes.levels(), 2, "exactly two selectable values")
T.eq(FaithfulRes.label(1), "ON", "and ON is spelled ON, not 1X")
T.eq(FaithfulRes.normalize(4), 1, "a persisted 4X normalizes to ON")

T.eq(FaithfulRes.apply(1), true, "FAITHFUL RATIO locks on the Switch")
T.eq(#setModeCalls, 0, "without ever resizing the console framebuffer")
T.eq(FaithfulRes.scaleCap(), 5, "1280x720 holds 5 whole GB screens")
T.eq(Renderer:fitScale(), 5, "and that is the scale the renderer locks to")

pose(1920, 1080, "NX")
T.eq(FaithfulRes.deviceScale(), 7, "docked re-derives to 7x with nothing to apply")
T.eq(Renderer:fitScale(), 7, "and the renderer follows it")

T.eq(FaithfulRes.apply(0), false, "OFF releases the lock")
T.eq(FaithfulRes.scaleCap(), nil, "with no cap on the renderer")
T.eq(#setModeCalls, 0, "and still no setMode on the console")

VideoMode.apply("borderless")
VideoMode.apply("windowed")
T.eq(#fullscreenCalls, 0, "VIDEO MODE never toggles fullscreen on the Switch")

pose(1920, 1080, "OS X")
VideoMode.apply("borderless")
T.eq(#fullscreenCalls, 1, "desktop still gets its fullscreen toggle")
T.eq(fullscreenCalls[1].on, true, "borderless turns it on")
VideoMode.apply("windowed")
T.eq(fullscreenCalls[2].on, false, "and windowed turns it back off")

window(1600, 900)
setModeCalls = {}
T.eq(FaithfulRes.apply(2), true, "desktop 2X locks the window")
T.eq(setModeCalls[1].w, 320, "at 320 wide")
T.eq(FaithfulRes.apply(4), true, "and 4X re-locks it")
T.eq(setModeCalls[2].w, 640, "at 640 wide")

T.eq(FaithfulRes.apply(0), false, "OFF releases the window")
local off = setModeCalls[3]
T.eq(off.w, 1600, "restoring the pre-lock width, not the locked one")
T.eq(off.h, 900, "and the pre-lock height")
T.eq(off.flags.resizable, true, "handing resizing back to the player")
T.eq(off.flags.minwidth, 480, "with the pre-lock minimum restored")
T.eq(off.flags.minheight, 360, "on both axes")
T.eq(FaithfulRes.prevSize, nil, "and the stashed size is dropped")

setModeCalls = {}
T.eq(FaithfulRes.apply(0), false, "a second OFF is a no-op")
T.eq(#setModeCalls, 0, "and touches nothing")

g.getDimensions, g.getPixelDimensions = realDims, realPixelDims
love.window, love.system = savedWindow, savedSystem
Zoom.offset = savedOffset
FaithfulRes.locked, FaithfulRes.prevSize = false, nil
FaithfulRes.mobileScale = 0
Platform._resetForTests()

T.finish("faithful ratio on the Switch")
