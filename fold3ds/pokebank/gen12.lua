-- emuPoke Bank: the Pokemon in a Game Boy save (Gen 1: Red, Blue, Yellow;
-- Gen 2: Gold, Silver, Crystal), the international 32 KB battery images.
-- Offsets from Bulbapedia's "Save data structure (Generation I / II)".
--
-- read(bytes) -> nil, why | { gen, game, trainer, tid, mons = { record... } }
-- A record (the bank's, shared by every generation's reader):
--   { gen, format = "pk1" | "pk2", raw = the original struct's bytes,
--     species (National Dex), nick, ot, tid, level, item, moves = {...},
--     shiny, egg, where = "Party" | "Box 3", slot }
local S = require("fold3ds.pokebank.species")

local G = {}

local function u8(b, o) return b:byte(o + 1) end
local function u16be(b, o) return b:byte(o + 1) * 256 + b:byte(o + 2) end
local function u24be(b, o) return (b:byte(o + 1) * 256 + b:byte(o + 2)) * 256 + b:byte(o + 3) end

-- the Game Boy games' letters (English)
local CHARS = {}
for i = 0, 25 do
  CHARS[0x80 + i] = string.char(65 + i)
  CHARS[0xA0 + i] = string.char(97 + i)
end
for i = 0, 9 do CHARS[0xF6 + i] = tostring(i) end
local MORE = { [0x7F] = " ", [0x9A] = "(", [0x9B] = ")", [0x9C] = ":", [0x9D] = ";", [0x9E] = "[",
  [0x9F] = "]", [0xE0] = "'", [0xE1] = "PK", [0xE2] = "MN", [0xE3] = "-", [0xE6] = "?", [0xE7] = "!",
  [0xE8] = ".", [0xEF] = "M", [0xF0] = "$", [0xF1] = "x", [0xF3] = "/", [0xF4] = ",", [0xF5] = "F",
  [0xBA] = "e", [0xBB] = "'d", [0xBC] = "'l", [0xBD] = "'s", [0xBE] = "'t", [0xBF] = "'v" }
for k, v in pairs(MORE) do CHARS[k] = v end

local function text(b, o, n)
  local out = {}
  for i = 0, n - 1 do
    local c = u8(b, o + i)
    if c == 0x50 or c == nil then break end
    out[#out + 1] = CHARS[c] or "?"
  end
  return table.concat(out)
end

---------------------------------------------------------------- checks
local function gen1Valid(b)
  if #b < 0x8000 then return false end
  local sum = 0
  for o = 0x2598, 0x3522 do sum = sum + u8(b, o) end
  return (255 - sum % 256) == u8(b, 0x3523)
end

local function gen2Sum(b, from, to, at)
  local sum = 0
  for o = from, to do sum = sum + u8(b, o) end
  return sum % 65536 == u8(b, at) + u8(b, at + 1) * 256
end

-- which Gen 2 layout: Gold / Silver or Crystal (by whose checksum holds)
local function gen2Layout(b)
  if #b < 0x8000 then return nil end
  if gen2Sum(b, 0x2009, 0x2B82, 0x2D0D) then
    return { name = "Crystal", curBoxNum = 0x2700, party = 0x2865, curBox = 0x2D10 }
  end
  if gen2Sum(b, 0x2009, 0x2D68, 0x2D69) then
    return { name = "Gold / Silver", curBoxNum = 0x2724, party = 0x288A, curBox = 0x2D6C }
  end
end

---------------------------------------------------------------- records
local function gen1Mon(b, o, size, nick, ot, where, slot, partyLevel)
  local idx = u8(b, o)
  local species = S.GEN1_INDEX[idx]
  if not species then return nil end
  local moves = {}
  for i = 0, 3 do local m = u8(b, o + 8 + i); if m > 0 then moves[#moves + 1] = m end end
  return {
    gen = 1, format = "pk1", raw = b:sub(o + 1, o + size), species = species,
    nick = nick, ot = ot, tid = u16be(b, o + 0x0C), level = partyLevel or u8(b, o + 3),
    exp = u24be(b, o + 0x0E), moves = moves, shiny = false, egg = false, where = where, slot = slot,
  }
end

local function gen2Shiny(b, o)
  local atk = math.floor(u8(b, o) / 16)
  local def, spe, spc = u8(b, o) % 16, math.floor(u8(b, o + 1) / 16), u8(b, o + 1) % 16
  return def == 10 and spe == 10 and spc == 10 and atk % 4 >= 2
end

local function gen2Mon(b, o, size, nick, ot, where, slot, listSpecies)
  local species = u8(b, o)
  if species < 1 or species > 251 then return nil end
  local moves = {}
  for i = 0, 3 do local m = u8(b, o + 2 + i); if m > 0 then moves[#moves + 1] = m end end
  return {
    gen = 2, format = "pk2", raw = b:sub(o + 1, o + size), species = species,
    nick = nick, ot = ot, tid = u16be(b, o + 6), level = u8(b, o + 0x1F), item = u8(b, o + 1),
    exp = u24be(b, o + 8), moves = moves, shiny = gen2Shiny(b, o + 0x15),
    egg = listSpecies == 0xFD, where = where, slot = slot,
  }
end

-- a list: count, species (cap + 1), cap structs, cap OT names, cap nicknames
local function list(b, base, cap, size, gen, where, out)
  local n = u8(b, base)
  if n > cap then return end
  local structs = base + 1 + cap + 1
  local ots = structs + cap * size
  local nicks = ots + cap * 11
  for i = 0, n - 1 do
    local o = structs + i * size
    local nick, ot = text(b, nicks + i * 11, 11), text(b, ots + i * 11, 11)
    local r
    if gen == 1 then
      r = gen1Mon(b, o, size, nick, ot, where, i + 1, size == 44 and u8(b, o + 0x21) or nil)
    else
      r = gen2Mon(b, o, size, nick, ot, where, i + 1, u8(b, base + 1 + i))
    end
    if r then out[#out + 1] = r end
  end
end

function G.read(b)
  if gen1Valid(b) then
    local out = {}
    local cur = u8(b, 0x284C) % 128
    list(b, 0x2F2C, 6, 44, 1, "Party", out)
    for box = 0, 11 do
      local base = box == cur and 0x30C0 or (box < 6 and 0x4000 + box * 0x462 or 0x6000 + (box - 6) * 0x462)
      list(b, base, 20, 33, 1, "Box " .. (box + 1), out)
    end
    return { gen = 1, game = "Red / Blue / Yellow", trainer = text(b, 0x2598, 11), tid = u16be(b, 0x2605), mons = out }
  end
  local L = gen2Layout(b)
  if L then
    local out = {}
    local cur = u8(b, L.curBoxNum) % 16
    list(b, L.party, 6, 48, 2, "Party", out)
    for box = 0, 13 do
      local base = box == cur and L.curBox or (box < 7 and 0x4000 + box * 0x450 or 0x6000 + (box - 7) * 0x450)
      list(b, base, 20, 32, 2, "Box " .. (box + 1), out)
    end
    return { gen = 2, game = L.name, trainer = text(b, 0x200B, 11), tid = u16be(b, 0x2009), mons = out }
  end
  return nil, "not a Gen 1 or Gen 2 save"
end

return G
