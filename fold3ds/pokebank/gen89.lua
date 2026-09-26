-- emuPoke Bank: the Pokemon in a Switch save (Eden: AeonDX/eden/data/nand/
-- user/save/0000000000000000/<user>/<title id>/).
--   Sword, Shield (PK8), Legends: Arceus (PA8), Scarlet, Violet (PK9): the
--     "main" file, SwishCrypto -- a static 0x7F-byte xorpad over the whole
--     file (the last 0x20 bytes are a SHA-256 hash), then a list of SCBlocks,
--     each a key and a payload encrypted with an xorshift32 stream seeded by
--     the key.  The boxes, party and trainer are three of those blocks.
--   Brilliant Diamond, Shining Pearl (PB8): "SaveData.bin", plain.
-- Pokemon are encrypted like Gen 6 and 7 (the encryption constant seeds the
-- LCG); in these games the boxes hold the party-sized structure.  Offsets,
-- block keys and the xorpad from PKHeX (SwishCrypto.cs, SCBlock.cs,
-- SCXorShift32.cs, SAV8SWSH/8LA/8BS/9SV.cs, SaveBlockAccessor*.cs, G8PKM.cs,
-- PA8.cs, PK9.cs, MyStatus8/8a/8b/9.cs).
--
-- read(bytes) -> nil, why | { gen, game, trainer, tid, sid, mons }
local P = require("fold3ds.pokebank.pkm")
local S = require("fold3ds.pokebank.species")
local bit = require("bit")

local G = {}
local u8, u16, u32 = P.u8, P.u16, P.u32

local function fmt(gen, format, over)
  local f = { gen = gen, format = format, pid = 0x1C, moves = 0x72, iv = 0x8C, nick = 0x58, ot = 0xF8,
    nickChars = 13, otChars = 13, text = P.utf16, shinyBelow = 16, levelAt = 0x148 }
  for k, v in pairs(over or {}) do f[k] = v end
  return f
end
local PK8 = fmt(8, "pk8")
local PB8 = fmt(8, "pb8")
local PA8 = fmt(8, "pa8", { moves = 0x54, iv = 0x94, nick = 0x60, ot = 0x110, levelAt = 0x168 })
local PK9 = fmt(9, "pk9", { species = function(raw) return S.GEN9_INTERNAL[raw] or raw end })

---------------------------------------------------------------- SwishCrypto
local XORPAD = {
  0xA0, 0x92, 0xD1, 0x06, 0x07, 0xDB, 0x32, 0xA1, 0xAE, 0x01, 0xF5, 0xC5, 0x1E, 0x84, 0x4F, 0xE3,
  0x53, 0xCA, 0x37, 0xF4, 0xA7, 0xB0, 0x4D, 0xA0, 0x18, 0xB7, 0xC2, 0x97, 0xDA, 0x5F, 0x53, 0x2B,
  0x75, 0xFA, 0x48, 0x16, 0xF8, 0xD4, 0x8A, 0x6F, 0x61, 0x05, 0xF4, 0xE2, 0xFD, 0x04, 0xB5, 0xA3,
  0x0F, 0xFC, 0x44, 0x92, 0xCB, 0x32, 0xE6, 0x1B, 0xB9, 0xB1, 0x2E, 0x01, 0xB0, 0x56, 0x53, 0x36,
  0xD2, 0xD1, 0x50, 0x3D, 0xDE, 0x5B, 0x2E, 0x0E, 0x52, 0xFD, 0xDF, 0x2F, 0x7B, 0xCA, 0x63, 0x50,
  0xA4, 0x67, 0x5D, 0x23, 0x17, 0xC0, 0x52, 0xE1, 0xA6, 0x30, 0x7C, 0x2B, 0xB6, 0x70, 0x36, 0x5B,
  0x2A, 0x27, 0x69, 0x33, 0xF5, 0x63, 0x7B, 0x36, 0x3F, 0x26, 0x9B, 0xA3, 0xED, 0x7A, 0x53, 0x00,
  0xA4, 0x48, 0xB3, 0x50, 0x9E, 0x14, 0xA0, 0x52, 0xDE, 0x7E, 0x10, 0x2B, 0x1B, 0x77, 0x6E, 0x80,
}
-- PKHeX xors 0x80-byte chunks 0x7F apart, so every 0x7Fth byte (after the
-- first) gets the pad's last byte as well as its first
local function pad(j)
  local m = j % 127
  local v = XORPAD[m + 1]
  if m == 0 and j > 0 then v = bit.bxor(v, XORPAD[128]) end
  return v
end

-- the xorshift32 byte stream a block is encrypted with
local function stream(key)
  local state = bit.tobit(key)
  local n, k = 0, key
  while k > 0 do n = n + k % 2; k = math.floor(k / 2) end
  local function advance(s)
    s = bit.bxor(s, bit.lshift(s, 2))
    s = bit.bxor(s, bit.rshift(s, 15))
    return bit.bxor(s, bit.lshift(s, 13))
  end
  for _ = 1, n do state = advance(state) end
  local counter = 0
  local function nextByte()
    local r = bit.band(bit.rshift(state, counter * 8), 0xFF)
    if counter == 3 then state, counter = advance(state), 0 else counter = counter + 1 end
    return r
  end
  local function next32()
    return nextByte() + nextByte() * 256 + nextByte() * 65536 + nextByte() * 16777216
  end
  return nextByte, next32
end

local TYPE_SIZE = { [3] = 1, [8] = 1, [9] = 2, [10] = 4, [11] = 8, [12] = 1, [13] = 2, [14] = 4, [15] = 8,
  [16] = 4, [17] = 8 }

-- the blocks' keys -> { at = payload offset of the encrypted bytes, len };
-- nil when the file isn't SwishCrypto
local function blocks(b)
  local len = #b - 32
  if len < 16 then return nil end
  local function pb(j) return bit.bxor(b:byte(j + 1), pad(j)) end
  local function p32(j) return pb(j) + pb(j + 1) * 256 + pb(j + 2) * 65536 + pb(j + 3) * 16777216 end
  local out, o = {}, 0
  while o < len do
    if o + 5 > len then return nil end
    local key = p32(o)
    o = o + 4
    local nextByte, next32 = stream(key)
    local t = bit.bxor(pb(o), nextByte())
    o = o + 1
    if t >= 1 and t <= 3 then
      -- a boolean: no payload
    elseif t == 4 then
      local n = bit.bxor(p32(o), next32()) % 4294967296
      o = o + 4
      if n > len - o then return nil end
      out[key] = { key = key, at = o, len = n }
      o = o + n
    elseif t == 5 then
      local count = bit.bxor(p32(o), next32()) % 4294967296
      local sub = bit.bxor(pb(o + 4), nextByte())
      o = o + 5
      local n = count * (TYPE_SIZE[sub] or math.huge)
      if n > len - o then return nil end
      o = o + n
    elseif TYPE_SIZE[t] then
      o = o + TYPE_SIZE[t]
    else
      return nil
    end
  end
  return out, pb
end

-- an Object block's payload, decrypted
local function object(blk, pb)
  local nextByte = stream(blk.key)
  for _ = 1, 5 do nextByte() end -- the type and the length
  local out = {}
  for i = 0, blk.len - 1 do out[#out + 1] = string.char(bit.bxor(pb(blk.at + i), nextByte())) end
  return table.concat(out)
end

-- block keys by game (SaveBlockAccessor8SWSH / 8LA / 9SV)
local SWISH = {
  { game = "Scarlet / Violet", f = PK9, box = 0x0D66012C, party = 0x3AA1A9AD, status = 0xE3E89BD1,
    stride = 0x158, size = 0x148, partyStride = 0x158, tid = 0x00, name = 0x10, gen = 9 },
  { game = "Legends: Arceus", f = PA8, box = 0x47E1CEAB, party = 0x2985FE5D, status = 0xF25C070E,
    stride = 0x168, size = 0x168, partyStride = 0x178, tid = 0x10, name = 0x20, gen = 8 },
  { game = "Sword / Shield", f = PK8, box = 0x0D66012C, party = 0x2985FE5D, status = 0xF25C070E,
    stride = 0x158, size = 0x148, partyStride = 0x158, tid = 0xA0, name = 0xB0, gen = 8 },
}

local function readSwish(b)
  local blk, pb = blocks(b)
  if not blk then return nil end
  for _, g in ipairs(SWISH) do
    if blk[g.box] and blk[g.party] and blk[g.status] then
      local out = {}
      local party = object(blk[g.party], pb)
      P.party(party, 0, u8(party, 6 * g.partyStride) or 0, g.partyStride, g.size, g.f, out)
      local box = object(blk[g.box], pb)
      P.boxes(box, 0, math.floor(#box / (30 * g.stride)), g.stride, g.size, g.f, out)
      local st = object(blk[g.status], pb)
      return { gen = g.gen, game = g.game, trainer = P.utf16(st, g.name, 13), tid = u16(st, g.tid),
        sid = u16(st, g.tid + 2), mons = out }
    end
  end
  return nil
end

---------------------------------------------------------------- BDSP
-- SAV8BS.cs: the file sizes of its versions, and the version number first
local BDSP = { [0xE9828] = 0x25, [0xEDC20] = 0x2C, [0xEED8C] = 0x32, [0xEF0A4] = 0x34 }

local function readBDSP(b)
  if not BDSP[#b] or BDSP[#b] ~= u32(b, 0) then return nil end
  local out = {}
  P.party(b, 0x14098, u8(b, 0x14098 + 6 * 0x158), 0x158, 0x148, PB8, out)
  P.boxes(b, 0x14EF4, 40, 0x158, 0x148, PB8, out)
  return { gen = 8, game = "Brilliant Diamond / Shining Pearl", trainer = P.utf16(b, 0x79BB4, 13),
    tid = u16(b, 0x79BB4 + 0x1C), sid = u16(b, 0x79BB4 + 0x1E), mons = out }
end

function G.read(b)
  local r = readBDSP(b) or readSwish(b)
  if not r then return nil, "not a Switch Pokemon save" end
  return r
end

G.pad = pad
return G
