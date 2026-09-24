package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end
love.graphics.polygon = love.graphics.polygon or function() end

local SaveData = require("src.core.SaveData")
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")

local stored = { enabled = nil, skin = nil }
local reads = 0
local realLoad, realSave = SaveData.loadOptions, SaveData.saveOptions
SaveData.loadOptions = function()
  reads = reads + 1
  return { touchControls = { enabled = stored.enabled, skin = stored.skin } }
end
SaveData.saveOptions = function(opts)
  local tc = type(opts) == "table" and type(opts.touchControls) == "table"
    and opts.touchControls or {}
  stored.enabled, stored.skin = tc.enabled, tc.skin
  return true
end

local function window(w, h)
  love.graphics.getDimensions = function() return w, h end
  love.graphics.getPixelDimensions = function() return w, h end
end

local imp = RomImporter.new(function() end, { launcher = true })

eq(imp:_activeSkin(), nil, "no skin chosen yet")
local at = reads
for _ = 1, 20 do imp:_activeSkin() end
eq(reads, at, "twenty more asks decode the options file zero more times")

imp:_useSkin("neon")
eq(imp:_activeSkin(), "neon", "choosing a skin is visible on the next ask")
at = reads
for _ = 1, 20 do imp:_activeSkin() end
eq(reads, at, "and the new answer caches just as hard")

imp:_disableSkins()
eq(imp:_activeSkin(), nil, "turning skins off is visible too")
at = reads
for _ = 1, 20 do imp:_activeSkin() end
eq(reads, at, "and 'no skin' caches instead of re-reading forever")

imp:_useSkin("neon")
imp:_activeSkin()
at = reads
imp:_closeSettings()
imp:_activeSkin()
check(reads > at, "closing the gear re-reads: it can toggle the pad itself")

imp:_activeSkin()
at = reads
imp:prepareOverlayHandoff()
imp:_activeSkin()
check(reads > at,
  "and handing the screen to the studio re-reads on the way back")

window(420, 900)
imp.tab = "skins"
LauncherView.draw(imp)
LauncherView.draw(imp)
at = reads
for _ = 1, 5 do LauncherView.draw(imp) end
eq(reads, at, "five frames of the skins tab decode the options file zero times")

window(1400, 900)
LauncherView.draw(imp)
at = reads
for _ = 1, 5 do LauncherView.draw(imp) end
eq(reads, at, "and a desktop-width skins tab is just as quiet")

local okStudio, Studio = pcall(require, "src.ui.SkinStudio")
if okStudio then
  Studio.forgetActiveSkin()
  eq(Studio.activeSkinId(), "neon", "the studio reads the same answer")
  at = reads
  for _ = 1, 20 do Studio.activeSkinId() end
  eq(reads, at, "and its library grid asks the cache, not the disk")
  Studio.forgetActiveSkin()
  Studio.activeSkinId()
  check(reads > at, "until something that writes options clears it")
else
  check(false, "the skin studio loads: " .. tostring(Studio))
end

SaveData.loadOptions, SaveData.saveOptions = realLoad, realSave

T.finish("launcher skins options reads")
