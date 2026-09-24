-- Launcher footer Patch notes control.  The GitHub release body is already
-- fetched by the updater; this is the in-app viewer for it.
--   luajit tests/engine/launcher_patch_notes.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end

local Kit = require("src.ui.kit.Kit")
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")
local PatchNotes = require("src.update.PatchNotes")

local function window(w, h)
  love.graphics.getDimensions = function() return w, h end
  love.graphics.getPixelDimensions = function() return w, h end
end

local function freshLauncher()
  return RomImporter.new(function() end, { launcher = true })
end

local realPrint = love.graphics.print
local function drawAndCapture(imp)
  local seen = {}
  love.graphics.print = function(str, ...)
    seen[#seen + 1] = tostring(str)
    return realPrint(str, ...)
  end
  local ok, err = pcall(LauncherView.draw, imp)
  love.graphics.print = realPrint
  check(ok, "the frame draws: " .. tostring(err))
  return table.concat(seen, "\n")
end

window(1280, 720)
local imp = freshLauncher()
local text = drawAndCapture(imp)
check(text:find("Patch notes", 1, true) ~= nil,
  "desktop footer prints Patch notes")

window(360, 780)
local phone = freshLauncher()
check(drawAndCapture(phone):find("Patch notes", 1, true) ~= nil,
  "portrait footer still prints Patch notes")

do
  local body, ver = PatchNotes.body({
    state = function()
      return { notes = "## Issues closed\n\n- #12 cart padding", latest = "1.4.2" }
    end,
  })
  eq(body, "## Issues closed\n\n- #12 cart padding",
    "PatchNotes prefers the updater's GitHub body")
  eq(ver, "1.4.2", "PatchNotes carries the release version")
end

do
  local body, ver = PatchNotes.body(nil)
  check(type(body) == "string" and (body:find("Download", 1, true) or body:find("Issues", 1, true)),
    "without a check result PatchNotes uses the stashed iOS app-repo notes")
  check(type(ver) == "string" and ver:find("^%d+%.%d+%.%d+$") ~= nil,
    "stashed notes name a release version")
end

do
  local notes, ver = PatchNotes.fromRepo("999.999.999")
  eq(notes, nil, "fromRepo returns nil when a specific engine version is missing")
  eq(ver, nil, "fromRepo version is nil when missing")
end

do
  local f = assert(io.open("mobile/ios/app-repo.json", "rb"))
  local list = PatchNotes.parseRepo(f:read("*a"))
  f:close()
  check(#list >= 2, "app-repo.json stashes more than one release")
  local notes, ver = PatchNotes.fromRepo(list[2].version)
  eq(ver, list[2].version, "fromRepo can pick a specific stashed version")
  eq(notes, list[2].notes, "fromRepo returns that version's notes")
end

do
  local oldVersion = package.loaded["src.core.Version"]
  package.loaded["src.core.Version"] = { engine = "999.999.999" }
  local body, ver = PatchNotes.body(nil)
  eq(body, "Unable to fetch patch notes.", "returns Unable to fetch patch notes when version is uncached and unlisted")
  eq(ver, "999.999.999", "returns the requested engine version")
  package.loaded["src.core.Version"] = oldVersion
end

imp._appPatchNotes = true
local modal = drawAndCapture(imp)
check(modal:find("Patch notes", 1, true) ~= nil, "the modal titles itself")
check(modal:find("Close", 1, true) ~= nil, "the modal can be closed")

imp:keypressed("escape")
eq(imp._appPatchNotes, nil, "Escape dismisses patch notes")

T.finish("launcher patch notes")
