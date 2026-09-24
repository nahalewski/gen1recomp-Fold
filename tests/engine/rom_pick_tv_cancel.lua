package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local RomImporter = require("src.import.RomImporter")

love.filesystem.getSaveDirectory = function() return "/sdcard/pokeport/save" end
love.system = {
  getOS = function() return "Android" end,
  pickFile = function() return true end,
}

local function detail(ri) return tostring(ri.detail or "") end

local function clearSaveDir()
  for _, name in ipairs(love.filesystem.getDirectoryItems("")) do
    love.filesystem.remove(name)
  end
end

local function freshImporter()
  return setmetatable({
    android = true,
    launcher = true,
    workState = nil,
    tab = "red",
    ready = { red = false, blue = false, yellow = false },
    saveNotice = {},
    modNotice = nil,
    notice = nil,
    slotScroll = {},
    activeSlot = {},
  }, RomImporter)
end

do
  clearSaveDir()
  love.filesystem.write("pick_error.flag", "cancelled:picked_rom.gb")
  local ri = freshImporter()
  ri:focus(true)
  eq(ri.workState, "error", "an empty TV pick reports instead of staying silent")
  check(detail(ri):find("did not return a file", 1, true),
    "the notice blames the file manager, not an unreadable file")
  check(not detail(ri):find("Files (Documents) app", 1, true),
    "and does not send a TV player to an app the device does not have")
  check(detail(ri):find("/sdcard/pokeport/save", 1, true),
    "the save dir stays offered as the copy-it-yourself fallback")
  eq(love.filesystem.getInfo("pick_error.flag"), nil, "the flag is consumed")
end

do
  clearSaveDir()
  love.filesystem.write("pick_error.flag", "cancelled:picked_mod.zip")
  local ri = freshImporter()
  ri:focus(true)
  check(ri.modNotice ~= nil and ri.modNotice.ok == false,
    "the prefix still routes a mod pick to the mods panel")
  eq(ri.workState, nil, "and leaves the ROM panel alone")
end

do
  clearSaveDir()
  love.filesystem.write("pick_error.flag", "cancelled:picked_save.sav")
  local ri = freshImporter()
  ri.androidPendingVersion = "blue"
  ri:focus(true)
  check(ri.saveNotice.blue ~= nil and ri.saveNotice.blue.ok == false,
    "and a save pick to the game it was picked for")
end

do
  clearSaveDir()
  love.filesystem.write("pick_error.flag", "picked_rom.gb")
  local ri = freshImporter()
  ri:focus(true)
  check(detail(ri):find("Could not read the picked file", 1, true),
    "an unprefixed flag still reads as the #442 unreadable pick")
end

clearSaveDir()
T.finish()
