-- Mods "Show for" chips collapse to a dropdown when they cannot all fit.
-- Landscape / desktop keep the individual game chips.  No pokered cite: the
-- launcher is port-only chrome.
--   luajit tests/engine/launcher_mod_scope_dropdown.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end

local Kit = require("src.ui.kit.Kit")
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")

local function window(w, h)
  love.graphics.getDimensions = function() return w, h end
  love.graphics.getPixelDimensions = function() return w, h end
end

local function navIds()
  local ids = {}
  for i = 1, (Kit._navPrevN or 0) do
    local slot = Kit._nav[i]
    if slot and slot.id then ids[slot.id] = true end
  end
  return ids
end

local function drawMods(W, H)
  window(W, H)
  local imp = RomImporter.new(function() end, { launcher = true })
  imp.tab = "mods"
  imp.ready = { red = true, blue = true, yellow = true, gold = true }
  local ok, err = pcall(LauncherView.draw, imp)
  check(ok, ("%dx%d mods draws: %s"):format(W, H, tostring(err)))
  return navIds()
end

local portrait = drawMods(360, 780)
check(portrait["mod-scope-menu"] == true,
  "portrait: Show-for collapses to a dropdown when the chips cannot all fit")
check(portrait["mod-scope-gold"] == nil
    and portrait["mod-scope-red"] == nil
    and portrait["mod-scope-blue"] == nil
    and portrait["mod-scope-yellow"] == nil,
  "portrait: individual version chips are not drawn beside the dropdown")

local desktop = drawMods(1280, 720)
check(desktop["mod-scope-menu"] == nil,
  "desktop: chips fit, so there is no dropdown")
check(desktop["mod-scope-all"] == true
    and desktop["mod-scope-red"] == true
    and desktop["mod-scope-blue"] == true
    and desktop["mod-scope-yellow"] == true
    and desktop["mod-scope-gold"] == true,
  "desktop: every Show-for chip stays reachable")

print("ok   launcher mod scope dropdown")
