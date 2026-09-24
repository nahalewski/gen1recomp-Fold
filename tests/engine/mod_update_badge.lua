package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local ModUpdate = require("src.mods.ModUpdate")
local LauncherMods = require("src.mods.LauncherMods")
local RomImporter = require("src.import.RomImporter")

local RELEASES = {
  { version = "1.1.10", zip = { url = "https://example.invalid/a.zip" } },
  { version = "1.0.0", zip = { url = "https://example.invalid/b.zip" } },
}

local oldPump = ModUpdate.pumpDownloadZip
local oldInstall = LauncherMods.installDownloadedZip
local oldDeps = LauncherMods.checkDependencies
local installedAs

ModUpdate.pumpDownloadZip = function() return true, "install.zip" end
LauncherMods.installDownloadedZip = function() return true, installedAs end
LauncherMods.checkDependencies = function() return { hasIssues = false } end

local function launcher(installed, wanted)
  installedAs = wanted
  local ri = setmetatable({
    mods = { { id = "gym", name = "Gym Challenge", version = installed,
               github = "someone/gym" } },
    modUpdateInfo = {
      gym = { status = "available", latest = "1.1.10", best = RELEASES[1],
              releases = RELEASES, checkedAt = 1 },
    },
    _modInstall = {
      h = {}, version = wanted,
      spec = { modId = "gym", name = "Gym Challenge", verb = "Updated",
               notice = "mod" },
    },
  }, RomImporter)
  ri._refreshMods = function(self) self.mods[1].version = wanted end
  return ri
end

do
  local ri = launcher("1.0.0", "1.1.10")
  ri:_pumpModInstall()
  eq(ri:_modUpdateInfo("gym").status, "current",
    "the mod that just installed the latest release is up to date")
  eq(ri:_modUpdateInfo("gym").latest, "1.1.10",
    "and the release list it was judged against is still on the row")
  check(ri.modNotice and ri.modNotice.ok, "the install still reports success")
  check(ri.modNotice.text:find("1.1.10", 1, true) ~= nil,
    "with the version it landed")
  eq(ri._modInstall, nil, "and the job is done")
end

do
  local ri = launcher("0.9.0", "1.0.0")
  ri:_pumpModInstall()
  eq(ri:_modUpdateInfo("gym").status, "available",
    "an older release is still behind the newest one")
  eq(ri:_modUpdateInfo("gym").latest, "1.1.10",
    "which is the release the badge names")
end

do
  local ri = launcher("1.0.0", "1.1.10")
  local pending = { mod = ri.mods[1], h = {} }
  ri._modInfoFetch = { pending }
  ri:_pumpModInstall()
  eq(pending.mod.version, "1.1.10",
    "the in-flight check judges against the version now on disk")

  local oldFetch = ModUpdate.pumpFetchReleases
  local oldCache = ModUpdate.readCache
  ModUpdate.pumpFetchReleases = function() return true, RELEASES end
  ModUpdate.readCache = function() return nil end
  ri:_pumpModInfoFetch()
  ModUpdate.pumpFetchReleases = oldFetch
  ModUpdate.readCache = oldCache
  eq(ri:_modUpdateInfo("gym").status, "current",
    "so it lands on the same answer instead of bringing the chip back")
end

do
  local ri = launcher("1.0.0", "1.1.10")
  ri.modUpdateInfo = {}
  ri:_pumpModInstall()
  eq(ri:_modUpdateInfo("gym"), nil,
    "no release list means no verdict to invent")
end

ModUpdate.pumpDownloadZip = oldPump
LauncherMods.installDownloadedZip = oldInstall
LauncherMods.checkDependencies = oldDeps

T.finish("mod update badge")
