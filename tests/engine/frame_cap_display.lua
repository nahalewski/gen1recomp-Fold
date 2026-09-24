package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
_G.POKEPORT_LOOP_PANEL_SYNC = true
local FrameCap = require("src.core.FrameCap")
local RefreshRate = require("src.core.RefreshRate")

RefreshRate.reset()

T.eq(FrameCap.DISPLAY, 0, "DISPLAY is the zero cap")
T.eq(FrameCap.CYCLE[#FrameCap.CYCLE], FrameCap.DISPLAY,
  "and it is the last stop on the cycle ring")
T.eq(#FrameCap.CYCLE, #FrameCap.STEPS + 1,
  "the ring is the steps plus that one stop")

T.eq(FrameCap.normalize(0), FrameCap.DISPLAY, "a stored 0 is DISPLAY")
T.eq(FrameCap.normalize(-5), FrameCap.DISPLAY, "and so is a negative cap")
T.eq(FrameCap.normalize(1), 30, "a positive cap below the floor still clamps")
T.eq(FrameCap.normalize(9999), 160, "and one above the ceiling still clamps")
T.eq(FrameCap.normalize(nil), 60, "nil is still the 60 default")
T.eq(FrameCap.normalize("junk"), 60, "and so is garbage")

T.eq(FrameCap.label(0), "DISPLAY", "the row prints DISPLAY for the zero cap")
T.eq(FrameCap.label(60), "60", "and plain numbers for the rest")

T.eq(FrameCap.cycle(160, 1), FrameCap.DISPLAY, "the ceiling cycles to DISPLAY")
T.eq(FrameCap.cycle(FrameCap.DISPLAY, 1), 30, "which then wraps to the floor")
T.eq(FrameCap.cycle(30, -1), FrameCap.DISPLAY, "and back down again")
T.eq(FrameCap.cycle(FrameCap.DISPLAY, -1), 160, "DISPLAY steps down to 160")

local before = FrameCap.current
FrameCap.apply(FrameCap.DISPLAY)
T.eq(FrameCap.current, 0, "apply stores the uncapped value as-is")
FrameCap.apply(before)

local function measure(hz)
  RefreshRate.reset()
  for _ = 1, 31 do RefreshRate.sample(1 / hz) end
end

-- Handheld: default 60 follows the panel through PresentSync, not the software pacer.
local savedGetenv = os.getenv
os.getenv = function(name)
  if name == "POKEPORT_HANDHELD" then return "1" end
  return savedGetenv(name)
end
FrameCap.current = FrameCap.DEFAULT
FrameCap.applyOptions({ fpsCap = 60 })
T.eq(FrameCap.current, FrameCap.DISPLAY, "handheld default 60 maps to DISPLAY")
FrameCap.applyOptions({ fpsCap = 144 })
T.eq(FrameCap.current, 144, "handheld explicit caps are kept")
FrameCap.current = FrameCap.DEFAULT
FrameCap.bootHandheld()
T.eq(FrameCap.current, FrameCap.DISPLAY, "bootHandheld picks DISPLAY before a save loads")
os.getenv = savedGetenv
FrameCap.apply(before)

-- Android/iOS/UWP also prefer DISPLAY so composed GLES can lock during probe.
local savedGetOS = love and love.system and love.system.getOS
love = love or {}
love.system = love.system or {}
for _, osName in ipairs({ "Android", "UWP" }) do
  love.system.getOS = function() return osName end
  FrameCap.current = FrameCap.DEFAULT
  FrameCap.applyOptions({ fpsCap = 60 })
  T.eq(FrameCap.current, FrameCap.DISPLAY,
    osName .. " default 60 maps to DISPLAY")
  FrameCap.current = FrameCap.DEFAULT
  FrameCap.bootPanelSync()
  T.eq(FrameCap.current, FrameCap.DISPLAY,
    "bootPanelSync picks DISPLAY on " .. osName)
end
love.system.getOS = savedGetOS or function() return "Linux" end
FrameCap.apply(before)

-- Performance LOW must not force DISPLAY → 60 on a 60 Hz panel.
measure(60)
FrameCap.apply(FrameCap.DISPLAY)
FrameCap.clampToPerformance(60)
T.eq(FrameCap.current, FrameCap.DISPLAY, "LOW tier leaves DISPLAY on a 60 Hz panel")
FrameCap.apply(144)
FrameCap.clampToPerformance(60)
T.eq(FrameCap.current, 60, "LOW tier clamps 144 down to 60")
FrameCap.apply(before)


local opts = { fpsCap = 60 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 60, "an unknown refresh leaves the 60 default alone")
T.eq(FrameCap.current, 60, "and paces to it")

measure(90)
T.eq(RefreshRate.mismatch(), 90, "90Hz is not a multiple of 60")
T.eq(FrameCap.label(0), "DISPLAY (90HZ)", "so the row names the panel rate")
T.eq(FrameCap.label(60), "60 (90HZ)", "beside whatever the cap reads")

FrameCap.migrated = false
opts = { fpsCap = 60 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 60, "a mismatch panel no longer auto-migrates to DISPLAY")
T.eq(FrameCap.current, 60, "and keeps pacing at the stored cap")
T.eq(opts.fpsCapMigrated, nil, "without stamping a migration marker")

opts = { fpsCap = 144 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 144, "a cap that is not the default is never rewritten")

measure(144)
T.eq(RefreshRate.mismatch(), 144, "144Hz is no multiple of 60 either")
FrameCap.migrated = false
opts = { fpsCap = 60 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 60, "nor does a high-Hz panel rewrite a default 60 cap")

measure(75)
FrameCap.migrated = false
opts = { fpsCap = 60 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 60, "75Hz mismatch also leaves the default alone")

measure(120)
T.eq(RefreshRate.mismatch(), nil, "120Hz shows 60Hz logic 1:1")
T.eq(FrameCap.label(60), "60", "so the row says nothing about it")
FrameCap.migrated = false
opts = { fpsCap = 60 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 60, "and the 60 default stays put")

measure(59.94)
T.eq(RefreshRate.mismatch(), nil, "a 59.94Hz panel is within a hertz of 60")

measure(59)
T.eq(RefreshRate.hz(), 60, "the integer 59 a driver reports for it reads as 60")
T.eq(RefreshRate.period(), 1 / 60, "so the step period snapped to is the 60Hz one")
T.eq(RefreshRate.mismatch(), nil, "and it is no mismatch")
FrameCap.migrated = false
opts = { fpsCap = 60 }
FrameCap.applyOptions(opts)
T.eq(opts.fpsCap, 60, "nor does it move the cap")

measure(60.3)
T.eq(RefreshRate.hz(), 60, "a measured 60.3 quantizes to the panel's 60")
measure(59.7)
T.eq(RefreshRate.hz(), 60, "and so does a measured 59.7")
measure(89.8)
T.eq(RefreshRate.hz(), 90, "while a measured 89.8 is a 90Hz panel")
T.eq(RefreshRate.period(), 1 / 90, "with the 90Hz period, not the measurement's")

RefreshRate.reset()
FrameCap.migrated = false
FrameCap.apply(before)

T.finish("frame cap display")
