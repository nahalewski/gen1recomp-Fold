-- emuPoke Bank: the Pokemon in a DS save (melonDS: AeonDX/melonds/data/saves/
-- <game>.sav, the 512 KB flash image).
--   Gen 4: Diamond, Pearl, Platinum, HeartGold, SoulSilver.  Two copies of
--     the General and Storage blocks, the newer (by the footer's counters)
--     read; PK4s encrypted with the checksum as the LCG seed.
--   Gen 5: Black, White, Black 2, White 2.  One copy, told apart by the
--     footer's CRC; PK5s encrypted the same way, text in UTF-16.
-- Offsets from PKHeX (SAV4*.cs, SAV5*.cs, PK4.cs, PK5.cs).
--
-- read(bytes) -> nil, why | { gen, game, trainer, tid, sid, mons }
local P = require("fold3ds.pokebank.pkm")
local T4 = require("fold3ds.pokebank.text4")
local bit = require("bit")

local G = {}
local u8, u16, u32 = P.u8, P.u16, P.u32

local PARTITION = 0x40000

local function text4(b, o, chars)
  local out = {}
  for i = 0, chars - 1 do
    local c = u16(b, o + i * 2)
    if c == 0xFFFF or c == 0 then break end
    out[#out + 1] = T4[c] or "?"
  end
  return table.concat(out)
end

local PK4 = { gen = 4, format = "pk4", gen45 = true, moves = 0x28, iv = 0x38, nick = 0x48, ot = 0x68,
  nickChars = 11, otChars = 8, text = text4, shinyBelow = 8, levelAt = 0x8C }
local PK5 = { gen = 5, format = "pk5", gen45 = true, moves = 0x28, iv = 0x38, nick = 0x48, ot = 0x68,
  nickChars = 11, otChars = 8, text = P.utf16, shinyBelow = 8, levelAt = 0x8C }

-- Gen 4 games: General block size, Storage block start and size, and offsets
-- in the General block (trainer, party); boxes: 18 of 30, box stride
local GEN4 = {
  { game = "Diamond / Pearl", general = 0xC100, storage = 0xC100, storageSize = 0x121E0,
    trainer = 0x64, party = 0x98, boxAt = 4, boxStride = 0xFF0 },
  { game = "Platinum", general = 0xCF2C, storage = 0xCF2C, storageSize = 0x121E4,
    trainer = 0x68, party = 0xA0, boxAt = 4, boxStride = 0xFF0 },
  { game = "HeartGold / SoulSilver", general = 0xF628, storage = 0xF700, storageSize = 0x12310,
    trainer = 0x64, party = 0x98, boxAt = 0, boxStride = 0x1000 },
}

-- which copy is newer: its footer's major, then minor counter (PKHeX's
-- SAV4BlockDetection); 0xFFFFFFFF is an unwritten copy
local function compare(c1, c2)
  if c1 == 0xFFFFFFFF and c2 ~= 0xFFFFFFFE then return 2 end
  if c2 == 0xFFFFFFFF and c1 ~= 0xFFFFFFFE then return 1 end
  if c1 > c2 then return 1 elseif c1 < c2 then return 2 end
  return 0
end

local function active(b, begin, length)
  local o = begin + length - 0x14
  local r = compare(u32(b, o), u32(b, o + PARTITION))
  if r == 0 then r = compare(u32(b, o + 4), u32(b, o + PARTITION + 4)) == 2 and 2 or 1 end
  return r == 2 and PARTITION or 0
end

-- a copy's footer says its block size, then the SDK's date
local function footerOk(b, at, size)
  if at + size > #b then return false end
  if u32(b, at + size - 0xC) ~= size then return false end
  local sdk = u32(b, at + size - 0x8)
  return sdk == 0x20060623 or sdk == 0x20070903
end

local function readGen4(b, g)
  local gen = active(b, 0, g.general)
  local sto = active(b, g.storage, g.storageSize) + g.storage
  local out = {}
  local party = gen + g.party
  P.party(b, party, u8(b, party - 4), 236, 136, PK4, out)
  P.boxes(b, sto + g.boxAt, 18, 136, 136, PK4, out, g.boxStride)
  local t = gen + g.trainer
  return { gen = 4, game = g.game, trainer = text4(b, t, 8), tid = u16(b, t + 0x10), sid = u16(b, t + 0x12),
    mons = out }
end

-- CRC-16/CCITT (0x1021, from 0xFFFF), as the Gen 5 footers use
local function crc16(b, o, n)
  local crc = 0xFFFF
  for i = 0, n - 1 do
    crc = bit.bxor(crc, u8(b, o + i) * 256)
    for _ = 1, 8 do
      if bit.band(crc, 0x8000) ~= 0 then crc = bit.bxor(bit.lshift(crc, 1), 0x1021)
      else crc = bit.lshift(crc, 1) end
      crc = bit.band(crc, 0xFFFF)
    end
  end
  return crc
end

-- Gen 5: the save's size and its footer's checked length (PKHeX SaveUtil)
local GEN5 = { { game = "Black / White", size = 0x24000, info = 0x8C },
  { game = "Black 2 / White 2", size = 0x26000, info = 0x94 } }

local function isGen5(b, g)
  local f = g.size - 0x100
  if f + g.info + 0x10 > #b then return false end
  return u16(b, f + g.info + 0x10 - 2) == crc16(b, f, g.info)
end

local function readGen5(b, g)
  local out = {}
  P.party(b, 0x18E08, u8(b, 0x18E04), 220, 136, PK5, out)
  P.boxes(b, 0x400, 24, 136, 136, PK5, out, 0x1000)
  return { gen = 5, game = g.game, trainer = P.utf16(b, 0x19404, 8), tid = u16(b, 0x19414),
    sid = u16(b, 0x19416), mons = out }
end

function G.read(b)
  if #b < 0x80000 then return nil, "not a DS Pokemon save" end
  for _, g in ipairs(GEN5) do
    if isGen5(b, g) then return readGen5(b, g) end
  end
  for _, g in ipairs(GEN4) do
    if footerOk(b, 0, g.general) or footerOk(b, PARTITION, g.general) then return readGen4(b, g) end
  end
  return nil, "not a DS Pokemon save"
end

G.text4 = text4
return G
