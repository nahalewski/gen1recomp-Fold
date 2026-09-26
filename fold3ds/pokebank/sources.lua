-- emuPoke Bank: the game saves it can read, and what is in them.
--   * Virtual Console games (SkyEmu: Game Boy, Color, Advance): their
--     battery saves in AeonDX/vc/data/saves (fold3ds/aeondx.lua)
--   * DS games (melonDS): their saves in AeonDX/melonds/data/saves
--   * 3DS games (Azahar): the "main" file in each Pokemon game's save data
--     (sdmc/Nintendo 3DS/<id0>/<id1>/title/<high>/<low>/data/00000001)
--   * Switch games (Eden): each Pokemon game's save in nand/user/save/
--     0000000000000000/<user>/<title id> ("main", or BDSP's SaveData.bin)
--   * the gen1recomp games (Red, Blue, Yellow, Gold, Silver, Crystal): their
--     save slots, turned back into a cartridge save (SaveConvert.exportSav)
-- Every one is read by the reader for its generation (gen12.lua, gen3.lua,
-- gen45.lua, gen67.lua, gen89.lua).
local Gen12 = require("fold3ds.pokebank.gen12")
local Gen3 = require("fold3ds.pokebank.gen3")
local Gen45 = require("fold3ds.pokebank.gen45")
local Gen67 = require("fold3ds.pokebank.gen67")
local Gen89 = require("fold3ds.pokebank.gen89")

local SRC = {}

-- generation readers, by the system a save comes from
local READERS = { gb = Gen12, gbc = Gen12, gba = Gen3, ds = Gen45, ["3ds"] = Gen67, switch = Gen89 }
SRC.READERS = READERS

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function isPokemon(name)
  local n = (name or ""):lower()
  return n:find("pok") ~= nil
end

local function exists(p)
  local f = io.open(p, "rb")
  if f then f:close() end
  return f ~= nil
end

-- the names in a folder outside the app's own (the Switch users' save
-- folders): through the shell's ls, as LOVE's filesystem can't list them
local function listDir(p)
  local ok, pipe = pcall(io.popen, 'ls -1 "' .. p:gsub('"', '\\"') .. '" 2>/dev/null')
  if not ok or not pipe then return {} end
  local out = {}
  for name in pipe:lines() do out[#out + 1] = name end
  pipe:close()
  return out
end

-- a 3DS game's save: Azahar's SD card, the system ids Azahar uses (zeros)
local SDMC = "/sdmc/Nintendo 3DS/00000000000000000000000000000000/00000000000000000000000000000000/title/"
local function save3ds(A, t)
  local id = t.titleId and t.titleId:lower()
  if not id or #id ~= 16 then return nil end
  local p = A.userDir() .. SDMC .. id:sub(1, 8) .. "/" .. id:sub(9, 16) .. "/data/00000001/main"
  return exists(p) and p or nil
end

-- a Switch game's saves, one per user who played it
local function savesSwitch(E, t)
  local id = t.titleId or t.programId
  if not id then return {} end
  local root = E.dataDir() .. "/nand/user/save/0000000000000000/"
  local out = {}
  for _, user in ipairs(listDir(root)) do
    local found
    for _, tid in ipairs({ id:upper(), id:lower() }) do
      for _, file in ipairs({ "main", "SaveData.bin" }) do
        local p = root .. user .. "/" .. tid .. "/" .. file
        if not found and exists(p) then found = p end
      end
    end
    if found then out[#out + 1] = found end
  end
  return out
end

-- -> { { title, sys, path | bytes, game = t } ... }
function SRC.list()
  local out = {}
  -- the Virtual Console games with a save
  local okE, E = pcall(require, "fold3ds.emucore")
  local okA, A = pcall(require, "fold3ds.aeondx")
  if okE and okA then
    local ok, games = pcall(E.games)
    for _, t in ipairs(ok and games or {}) do
      if READERS[t.sys] and not t.fake then
        local p = A.getSavePath(t.sys, t.base)
        local f = io.open(p, "rb")
        if f then
          f:close()
          out[#out + 1] = { title = t.name, sys = t.sys, path = p, pokemon = isPokemon(t.name) }
        end
      end
    end
  end
  -- the 3DS games (Azahar) that are Pokemon games
  local okZ, Az = pcall(require, "fold3ds.azahar")
  if okZ then
    local ok, games = pcall(Az.games)
    for _, t in ipairs(ok and games or {}) do
      if isPokemon(t.name) then
        local okP, p = pcall(save3ds, Az, t)
        if okP and p then out[#out + 1] = { title = t.name, sys = "3ds", path = p, pokemon = true } end
      end
    end
  end
  -- the Switch games (Eden) that are Pokemon games
  local okN, Ed = pcall(require, "fold3ds.eden")
  if okN then
    local ok, games = pcall(Ed.games)
    for _, t in ipairs(ok and games or {}) do
      if isPokemon(t.name) then
        local okP, paths = pcall(savesSwitch, Ed, t)
        for i, p in ipairs(okP and paths or {}) do
          out[#out + 1] = { title = t.name .. (#paths > 1 and (" (" .. i .. ")") or ""), sys = "switch",
            path = p, pokemon = true }
        end
      end
    end
  end
  -- the gen1recomp games' own saves
  local okD, SaveData = pcall(require, "src.core.SaveData")
  local okC, SaveConvert = pcall(require, "src.save_convert.SaveConvert")
  if okD and okC then
    for _, v in ipairs({ "red", "blue", "yellow", "gold", "silver", "crystal" }) do
      local okL, save = pcall(SaveData.load, v)
      if okL and type(save) == "table" then
        out[#out + 1] = { title = "Pokemon " .. v:sub(1, 1):upper() .. v:sub(2) .. " (gen1recomp)",
          sys = (v == "gold" or v == "silver" or v == "crystal") and "gbc" or "gb", pokemon = true,
          export = function() return SaveConvert.exportSav(save, v) end }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.pokemon ~= b.pokemon then return a.pokemon end
    return a.title < b.title
  end)
  return out
end

-- the Pokemon in one source -> the reader's result, or nil and why
function SRC.read(s)
  local reader = READERS[s.sys]
  if not reader then return nil, "no reader for this system yet" end
  local bytes
  if s.export then
    local ok, b = pcall(s.export)
    bytes = ok and b or nil
  else
    bytes = readFile(s.path)
  end
  if not bytes then return nil, "the save could not be read" end
  local ok, res, why = pcall(reader.read, bytes)
  if not ok then return nil, "the save could not be read" end
  return res, why
end

return SRC
