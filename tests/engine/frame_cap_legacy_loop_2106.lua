package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
_G.POKEPORT_LOOP_PANEL_SYNC = nil
package.loaded["src.core.FrameCap"] = nil
local FrameCap = require("src.core.FrameCap")

T.eq(FrameCap.loopSupportsPanelSync(), false,
  "no marker means a run loop that predates DISPLAY pacing")
T.eq(FrameCap.normalize(0), FrameCap.DEFAULT,
  "a stored DISPLAY cap paces at the default instead of 1/0")
T.eq(FrameCap.normalize(-5), FrameCap.DEFAULT, "and so does a negative cap")

love = love or {}
love.system = love.system or {}
local savedGetOS = love.system.getOS
local savedGetenv = os.getenv
os.getenv = function(name)
  if name == "POKEPORT_HANDHELD" then return "1" end
  return savedGetenv(name)
end
for _, osName in ipairs({ "Android", "iOS", "UWP" }) do
  love.system.getOS = function() return osName end
  T.eq(FrameCap.prefersPanelSync(), false,
    osName .. " does not prefer panel sync under a legacy loop")
  FrameCap.current = FrameCap.DEFAULT
  FrameCap.applyOptions({})
  T.check(FrameCap.current > 0, osName .. " boots with a positive cap")
  FrameCap.applyOptions({ fpsCap = 0 })
  T.check(FrameCap.current > 0, osName .. " keeps a positive cap for a stored 0")
  FrameCap.current = FrameCap.DEFAULT
  FrameCap.bootPanelSync()
  T.check(FrameCap.current > 0, "bootPanelSync stays positive on " .. osName)
end
os.getenv = savedGetenv
love.system.getOS = savedGetOS

_G.POKEPORT_LOOP_PANEL_SYNC = true
T.eq(FrameCap.normalize(0), FrameCap.DISPLAY,
  "the marker from a current love.run restores DISPLAY")
_G.POKEPORT_LOOP_PANEL_SYNC = nil
package.loaded["src.core.FrameCap"] = nil

T.finish("frame cap legacy loop #2106")
