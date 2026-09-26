-- emuPoke Bank: the game saves it can read, and what is in them.
--   * Virtual Console games (SkyEmu: Game Boy, Color, Advance): their
--     battery saves in AeonDX/vc/data/saves (fold3ds/aeondx.lua)
--   * the gen1recomp games (Red, Blue, Yellow, Gold, Silver, Crystal): their
--     save slots, turned back into a cartridge save (SaveConvert.exportSav)
-- Every one is read by the reader for its generation (gen12.lua, gen3.lua).
-- DS, 3DS and Switch saves plug in the same way (READERS, list()).
local Gen12 = require("fold3ds.pokebank.gen12")
local Gen3 = require("fold3ds.pokebank.gen3")

local SRC = {}

-- generation readers, by the system a save comes from
local READERS = { gb = Gen12, gbc = Gen12, gba = Gen3 }
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
