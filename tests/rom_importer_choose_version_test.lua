-- #1274: with several cartridge dumps sitting in the save directory, Choose
-- ROM imported whichever version was not yet ready rather than the one the
-- player picked.  Select Red, get Blue.
--
-- The fallback exists for devices with no file picker (handheld Linux with
-- no zenity or kdialog, and the Android USB-drop path), where chooseRom
-- returns nil and the importer scans the save directory instead.  That scan,
-- findPendingRom, answered with the first dump whose SHA-1 mapped to any
-- not-yet-ready version, so the selection was dropped on the floor.
--
--
-- Self-contained: `luajit tests/rom_importer_choose_version_test.lua`
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("rom importer honours the chosen version")
local eq = S.eq
local check = S.check

local RomImporter = require("src.import.RomImporter")
local GameVersion = require("src.core.GameVersion")

local ROM_BYTES = 1024 * 1024

-- One dump per version, each a blob of the right size whose first byte says
-- which cart it is.  love.data.hash is stubbed to answer with the real SHA-1
-- from GameVersion, so GameVersion.forSha1 does its own lookup unchanged.
local MARK = { R = "red", B = "blue", Y = "yellow" }
local FILES = {
  ["blue.gb"] = string.rep("B", ROM_BYTES),
  ["red.gb"] = string.rep("R", ROM_BYTES),
  ["yellow.gbc"] = string.rep("Y", ROM_BYTES),
}
-- Deliberately not alphabetical and not selection order: the bug returned
-- whatever getDirectoryItems listed first.
local LISTING = { "blue.gb", "red.gb", "yellow.gbc" }

love.system = love.system or {}
love.data = love.data or {}

local saved = {
  getOS = love.system.getOS,
  hash = love.data.hash,
  encode = love.data.encode,
  getDirectoryItems = love.filesystem.getDirectoryItems,
  getInfo = love.filesystem.getInfo,
  read = love.filesystem.read,
  getSaveDirectory = love.filesystem.getSaveDirectory,
}

-- Not OS X, Windows or Linux, so chooseRom returns nil without shelling out
-- to a dialog that may or may not exist on the machine running the suite.
-- The fallback under test is the same one every pickerless device takes.
love.system.getOS = function() return "Unknown" end
local savedKit = package.loaded["src.ui.kit.Kit"]
local opened = nil
package.loaded["src.ui.kit.Kit"] = {
  FileBrowser = { open = function(opts) opened = opts end },
}
love.filesystem.getSaveDirectory = function() return "/tmp/pokemon-love2d" end
love.filesystem.getDirectoryItems = function() return LISTING end
love.filesystem.getInfo = function(name, filter)
  if FILES[name] then return { type = "file", size = #FILES[name] } end
  return nil
end
love.filesystem.read = function(name) return FILES[name] end
-- RomImporter's sha1 helper is hash then encode-to-hex, so the pair is
-- stubbed together: hash answers with the digest already in the form
-- GameVersion stores, and encode hands it back untouched.
love.data.hash = function(_, data)
  local version = MARK[data:sub(1, 1)]
  return version and GameVersion.info(version).sha1 or "0"
end
love.data.encode = function(_, _, digest) return digest end

local function freshImporter()
  opened = nil
  return setmetatable({
    android = false,
    nativePicker = false,
    workState = nil,
    ready = { red = false, blue = false, yellow = false },
    notice = nil,
    modNotice = nil,
    saveNotice = {},
    baseRoms = {},
    chooseVersion = nil,
    startData = function(self, data, displayName)
      self._started = { data = data, name = displayName }
    end,
    startPath = function(self, path) self._startedPath = path end,
  }, RomImporter)
end

-- ------- the report: pick Red, get Red

local ri = freshImporter()
ri:choose("red")
check(ri._started ~= nil, "a pickerless Choose still imports from the save dir")
eq(ri._started and ri._started.name, "red.gb",
  "and it imports the cart that was chosen, not the first pending one")
eq(opened, nil,
  "the file browser never opens over a dump already sitting in the save dir")

-- ------- the same for a version listed after another pending dump

ri = freshImporter()
ri:choose("yellow")
eq(ri._started and ri._started.name, "yellow.gbc",
  "Yellow is imported for Yellow, with Blue and Red still pending")
eq(opened, nil, "and that one is unattended too")

-- ------- a chosen version with no dump present imports nothing

ri = freshImporter()
ri.ready = { red = false, blue = false, yellow = false, gold = false }
ri:choose("gold")
check(ri._started == nil,
  "choosing a version whose dump is absent imports no other cart")
check(opened ~= nil, "it opens the browser instead, which is what it is for")
eq(opened and opened.title, "Select "
  .. (GameVersion.info("gold").displayName or "ROM"),
  "titled for the version that was chosen")

-- ------- an already-imported cart is still never re-extracted (#167)

ri = freshImporter()
ri.ready = { red = true, blue = false, yellow = false }
ri:choose("red")
check(ri._started == nil,
  "and a version already imported is not extracted a second time")
check(opened ~= nil, "the browser is still there to pick another file with")


local realGetenv = os.getenv
os.getenv = function(name)
  if name == "POKEPORT_HANDHELD" then return "1" end
  return realGetenv(name)
end

ri = freshImporter()
ri:choose("red")
eq(ri._started and ri._started.name, "red.gb",
  "a handheld build imports the parked dump unattended")
eq(opened, nil, "without the in-launcher browser ever appearing")

ri = freshImporter()
ri.ready = { red = true, blue = false, yellow = false }
ri:choose("red")
check(ri._started == nil and opened ~= nil,
  "and it still reaches the browser when nothing is parked for that version")

os.getenv = realGetenv


package.loaded["src.ui.kit.Kit"] = { FileBrowser = nil }
ri = freshImporter()
ri:choose("blue")
eq(ri._started and ri._started.name, "blue.gb",
  "a Kit-less build scans the save dir exactly the same way")

ri = freshImporter()
ri.ready = { red = false, blue = false, yellow = false, gold = false }
ri:choose("gold")
check(ri._started == nil and opened == nil,
  "and with nothing parked it falls through to the pickerless notice")

package.loaded["src.ui.kit.Kit"] = savedKit

for name, fn in pairs(saved) do
  if name == "getOS" then love.system.getOS = fn
  elseif name == "hash" then love.data.hash = fn
  elseif name == "encode" then love.data.encode = fn
  else love.filesystem[name] = fn end
end

S.finish()
