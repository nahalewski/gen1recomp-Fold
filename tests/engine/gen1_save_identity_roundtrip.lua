package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
love = love or require("tests.love_stub")

local GenSave = require("src.save_convert.GenSave")
local SaveConvert = require("src.save_convert.SaveConvert")
local SaveData = require("src.core.SaveData")
local SaveSerializer = require("src.core.SaveSerializer")
local GameVersion = require("src.core.GameVersion")
local SaveFileIO = require("src.import.SaveFileIO")
local SyncEngine = require("src.sync.SyncEngine")

if not loadfile("data/generated/pokemon.lua") then
  print("gen1_save_identity_roundtrip skipped (needs data/generated/ for the Gen1 save codec)")
  os.exit(0)
end

local data = assert(SaveConvert.loadData("red"))
local stampMapWindow = loadfile("tests/fixture_data/map_window.lua")()
for mapId in pairs(data.maps) do stampMapWindow(data, mapId) end

local realFS = love.filesystem

local function memfs(files)
  return {
    files = files,
    write = function(path, content) files[path] = content return true end,
    read = function(path) return files[path] end,
    remove = function(path) files[path] = nil return true end,
    getInfo = function(path)
      if files[path] then return { type = "file" } end
      local prefix = path .. "/"
      for key in pairs(files) do
        if key:sub(1, #prefix) == prefix then return { type = "directory" } end
      end
      return nil
    end,
    createDirectory = function() return true end,
    getSaveDirectory = function() return "/fake/save" end,
  }
end

local function fresh()
  local files = {}
  love.filesystem = memfs(files)
  SaveData.resetSlotState()
  GameVersion.set("red")
  return files
end

local bit = require("bit")
local O = GenSave.OFFSETS
local function rawChecksum(bytes, from, to)
  local sum = 0
  for i = from, to - 1 do sum = bit.band(sum + bytes:byte(i + 1), 0xFF) end
  return bit.band(bit.bnot(sum), 0xFF)
end
local function mainChecksumValid(bytes)
  return rawChecksum(bytes, O.checksumStart, O.checksumEnd)
    == bytes:byte(O.mainChecksum + 1)
end

local TAG = O.identityTag
local TAG_LEN = #GenSave.IDENTITY_MAGIC + GenSave.IDENTITY_ID_LENGTH
local ID = "0123456789abcdef0123456789abcdef"

do
  T.eq(TAG, 0x2000, "the tag sits at the start of SRAM bank 1")
  T.check(TAG + TAG_LEN <= O.checksumStart,
    "and ends before the checksummed sGameData window opens")

  local save = SaveData.newGame({ playerName = "ASH", rivalName = "GARY" })
  save.money = 4321
  save.meta = SaveData.buildMeta(nil, { mods = {} })
  local plain = GenSave.encode(save, data, nil)
  save.meta.playthroughId = ID
  local tagged = GenSave.encode(save, data, nil)
  T.eq(#tagged, GenSave.SAVE_SIZE, "a tagged export is still 32768 bytes")
  T.check(tagged:sub(1, TAG) == plain:sub(1, TAG),
    "bank 0 and the bytes before the tag match a tagless export")
  T.check(tagged:sub(TAG + TAG_LEN + 1) == plain:sub(TAG + TAG_LEN + 1),
    "and so does every byte after it")
  T.eq(tagged:sub(TAG + 1, TAG + TAG_LEN), GenSave.IDENTITY_MAGIC .. ID,
    "the tag is the magic followed by the 32 hex id")
  T.eq(plain:sub(TAG + 1, TAG + TAG_LEN), string.rep("\0", TAG_LEN),
    "a tagless export leaves the bank 1 padding zero")
  T.check(mainChecksumValid(tagged), "the main-data checksum still verifies")
  T.eq(tagged:byte(O.mainChecksum + 1), plain:byte(O.mainChecksum + 1),
    "and is the same byte as the tagless export's")
  T.check(GenSave.mainChecksumValid(tagged), "the codec's own check agrees")

  T.eq(GenSave.readIdentity(tagged), ID, "the tag reads back")
  T.eq(GenSave.readIdentity(plain), nil, "a tagless image has no identity")

  local decoded = GenSave.decode(tagged, data)
  T.eq(decoded.meta.playthroughId, ID, "decode carries the id into the meta")
  T.eq(decoded.player.name, "ASH", "beside the progress it always read")
  T.eq(GenSave.decode(plain, data).meta.playthroughId, nil,
    "and a tagless image decodes with none")

  T.check(GenSave.encode(decoded, data, nil) == tagged,
    "a template round trip is byte-identical, tag included")
  decoded.meta.playthroughId = nil
  T.check(GenSave.encode(decoded, data, nil) == tagged,
    "a save that lost its id leaves the template's bytes verbatim")

  save.meta.playthroughId = "abc"
  T.check(GenSave.encode(save, data, nil) == plain,
    "an id that is not 32 hex characters is never written")

  local junk = tagged:sub(1, TAG) .. GenSave.IDENTITY_MAGIC .. ("zz"):rep(16)
    .. tagged:sub(TAG + TAG_LEN + 1)
  T.eq(GenSave.readIdentity(junk), nil, "a non-hex id after the magic is ignored")
  local wrongMagic = tagged:sub(1, TAG) .. "G1RX" .. tagged:sub(TAG + 5)
  T.eq(GenSave.readIdentity(wrongMagic), nil, "and so is the wrong magic")
  T.eq(GenSave.decode(wrongMagic, data).meta.playthroughId, nil,
    "leaving the decoded meta identity-free")
end

do
  local files = fresh()
  local slot = SaveData.createSlot("red")
  SaveData.setActiveSlot("red", slot)
  local save = SaveData.newGame({ playerName = "ASH", rivalName = "GARY" })
  save.money = 4321
  save.meta = SaveData.buildMeta({}, save.meta, os.time() - 60)
  T.check(SaveData.save(save), "device one plays and saves")
  T.eq(SaveData.load("red").meta.playthroughId, nil,
    "with no identity minted yet")

  local ok, path = SaveFileIO.exportActiveSlot("red")
  T.eq(ok, true, "device one exports: " .. tostring(path))
  local out = files["exports/red/gen1recomp-red-" .. slot .. ".sav"]
  T.check(type(out) == "string" and #out == GenSave.SAVE_SIZE,
    "the export is a 32 KB image")
  local id = GenSave.readIdentity(out)
  T.check(type(id) == "string" and #id == 32 and id:match("^%x+$") ~= nil,
    "an export mints and tags the slot's identity")
  T.eq(SaveData.loadOptions().playthroughIds.red[slot], id,
    "the same identity device one syncs under")
  local mine = SyncEngine.defaultSaves().list()
  T.eq(mine[1] and mine[1].playthroughId, id, "as its sync listing confirms")
  T.check(mainChecksumValid(out), "and the image still verifies")
  local onDisk = SaveSerializer.decode(files["saves/red/" .. slot .. ".lua"])
  T.eq(onDisk.meta.playthroughId, nil, "exporting rewrote no progress bytes")

  local files2 = fresh()
  local imported, slot2 = SaveFileIO.importToSlot(out, "red")
  T.eq(imported, true, "device two imports the export: " .. tostring(slot2))
  local loaded = SaveData.load("red")
  T.eq(loaded and loaded.meta.playthroughId, id,
    "and the imported slot carries the same identity")
  T.eq(loaded and loaded.player.name, "ASH", "with the progress")
  local theirs = SyncEngine.defaultSaves().list()
  T.eq(#theirs, 1, "device two lists the import for sync")
  T.eq(theirs[1] and theirs[1].playthroughId, id,
    "under the same key, so both devices meet on the server")
  T.eq(SaveData.loadOptions().playthroughIds.red[slot2], id,
    "and the slot is mapped so a download replaces it in place")

  T.eq(SaveFileIO.exportActiveSlot("red"), true, "device two exports again")
  T.eq(GenSave.readIdentity(files2["exports/red/gen1recomp-red-" .. slot2 .. ".sav"]),
    id, "keeping the identity through the second hop")
end

love.filesystem = realFS
SaveData.resetSlotState()
GameVersion.set("red")

T.finish("gen1_save_identity_roundtrip")
