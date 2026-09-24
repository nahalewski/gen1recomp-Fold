package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local VSync = require("src.core.VSync")

VSync.reset()

T.same(VSync.MODES, { "on", "off" }, "two modes, in row order")

T.eq(VSync.default(), "on", "with nothing to ask, vsync reads ON")
T.eq(VSync.normalize(nil), "on", "so a save with no key is ON")
T.eq(VSync.normalize("junk"), "on", "and so is garbage")
T.eq(VSync.normalize("adaptive"), "on", "a parked adaptive key folds to ON")

T.eq(VSync.label("on"), "ON", "ON prints as ON")
T.eq(VSync.label("off"), "OFF", "OFF as OFF")
T.eq(VSync.label("adaptive"), "ON", "and a parked adaptive key prints as ON")

T.eq(VSync.cycle("on", 1), "off", "ON cycles to OFF")
T.eq(VSync.cycle("off", 1), "on", "OFF wraps to ON")
T.eq(VSync.cycle("on", -1), "off", "stepping back is also OFF")
T.eq(VSync.cycle(nil, 1), "off", "a missing key normalizes before it steps")

T.eq(VSync.apply("off"), "off", "apply answers with what it stored")
T.eq(VSync.isOn(), false, "and OFF is not on")
T.eq(VSync.apply("adaptive"), "on", "apply(adaptive) becomes ON")
T.eq(VSync.isOn(), true, "and counts as on")
VSync.applyOptions({})
T.eq(VSync.isOn(), true, "an options table with no key falls back to the boot mode")


local calls = {}
local interval = 0
love.window.getVSync = function() return interval end
love.window.setVSync = function(v) calls[#calls + 1] = v; interval = v end
VSync.reset()

T.eq(VSync.default(), "off", "a handheld booted with vsync 0 defaults to OFF")
T.eq(VSync.normalize(nil), "off", "so its saves with no key stay OFF")
T.eq(VSync.isOn(), false, "and the run loop sees vsync off")

VSync.apply("on")
T.eq(calls[#calls], 1, "ON sets the swap interval to 1")
T.eq(VSync.isOn(), true, "and the loop sees vsync on")
calls = {}
T.eq(VSync.apply("adaptive"), "on", "parked adaptive applies as ON")
T.eq(calls[#calls], 1, "and asks for interval 1, never -1")
VSync.applyOptions({ vsync = "off" })
T.eq(calls[#calls], 0, "and OFF turns it off")

local opts = { vsync = "adaptive" }
T.eq(VSync.applyOptions(opts), "on", "applyOptions folds a saved adaptive key")
T.eq(opts.vsync, "on", "and rewrites it so later writes stay on the on/off ring")

-- Driver reports 0 after we asked for ON (vblank_mode=0 / Gamescope quirk):
-- isOn stays true so PresentProbe still tries a real wait on native X11.
VSync.reset()
calls = {}
interval = 0
love.window.getVSync = function() return 0 end
love.window.setVSync = function(v) calls[#calls + 1] = v end
VSync.apply("on")
T.eq(calls[#calls], 1, "ON still asks the driver for interval 1")
T.eq(VSync.isOn(), true, "requested ON stays wanted even if getVSync is 0")
T.eq(VSync.effective(), "off", "while effective tracks the driver bit")

-- BufferQueue fail-closed: silence live swapinterval without flipping wanted.
VSync.reset()
calls = {}
interval = 1
love.window.getVSync = function() return interval end
love.window.setVSync = function(v) calls[#calls + 1] = v; interval = v end
VSync.apply("on")
calls = {}
VSync.silenceDriver()
T.eq(calls[#calls], 0, "silenceDriver asks for interval 0")
T.eq(VSync.isOn(), true, "wanted stays ON after silenceDriver")
T.eq(VSync.effective(), "off", "effective follows the silenced driver")

love.window.getVSync, love.window.setVSync = nil, nil
VSync.reset()

T.finish("vsync option")
