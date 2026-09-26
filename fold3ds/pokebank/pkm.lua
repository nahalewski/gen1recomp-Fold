-- emuPoke Bank: what the Gen 4 to 9 Pokemon structures share (PK4, PK5, PK6,
-- PK7, PK8, PB8, PA8, PK9).  Each stored Pokemon is an 8-byte header (the
-- encryption constant / PID and a checksum) and four shuffled blocks,
-- encrypted with the games' LCG (0x41C64E6D, 0x6073) seeded from the
-- checksum (Gen 4 and 5) or the encryption constant (Gen 6 on), and put back
-- in order by (constant >> 13) & 31.  After PKHeX's PokeCrypto.
local S = require("fold3ds.pokebank.species")
local bit = require("bit")

local P = {}

local function u8(b, o) return b:byte(o + 1) end
local function u16(b, o) return b:byte(o + 1) + b:byte(o + 2) * 256 end
local function u32(b, o) return u16(b, o) + u16(b, o + 2) * 65536 end
P.u8, P.u16, P.u32 = u8, u16, u32

-- where each decrypted block comes from, by (constant >> 13) & 31
local ORDER = {
  0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1,
  1, 0, 2, 3, 1, 0, 3, 2, 2, 0, 1, 3, 3, 0, 1, 2, 2, 0, 3, 1, 3, 0, 2, 1,
  1, 2, 0, 3, 1, 3, 0, 2, 2, 1, 0, 3, 3, 1, 0, 2, 2, 3, 0, 1, 3, 2, 0, 1,
  1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 0,
  0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1,
  1, 0, 2, 3, 1, 0, 3, 2,
}

-- seed * 0x41C64E6D + 0x6073, mod 2^32, without losing bits to doubles
local function lcg(seed)
  local lo, hi = seed % 65536, math.floor(seed / 65536)
  local low = lo * 0x4E6D
  local mid = (lo * 0x41C6 + hi * 0x4E6D) % 65536
  return (low + mid * 65536 + 0x6073) % 4294967296
end

-- decrypt the stored part (size bytes) of the structure at b[o]: its bytes,
-- in order, as a string -- or nil when the checksum is wrong
function P.decrypt(b, o, size, gen45)
  local ec, chk = u32(b, o), u16(b, o + 6)
  local seed = gen45 and chk or ec
  local out, sum = {}, 0
  local words = {}
  for i = 0, (size - 8) / 2 - 1 do
    seed = lcg(seed)
    local w = bit.bxor(u16(b, o + 8 + i * 2), math.floor(seed / 65536)) % 65536
    words[i] = w
    sum = sum + w
  end
  if sum % 65536 ~= chk then return nil end
  local blockWords = (size - 8) / 8
  local sv = math.floor(ec / 8192) % 32
  out[1] = b:sub(o + 1, o + 8)
  for k = 0, 3 do
    local from = ORDER[sv * 4 + k + 1] * blockWords
    for i = 0, blockWords - 1 do
      local w = words[from + i]
      out[#out + 1] = string.char(w % 256, math.floor(w / 256))
    end
  end
  return table.concat(out)
end

-- UTF-16 (little endian) to UTF-8, up to a 0x0000 / 0xFFFF terminator
function P.utf16(b, o, chars)
  local out = {}
  for i = 0, chars - 1 do
    local c = u16(b, o + i * 2)
    if c == 0 or c == 0xFFFF then break end
    if c == 0xE08E then c = 0x2642 elseif c == 0xE08F then c = 0x2640 end -- the games' own gender signs
    if c < 0x80 then out[#out + 1] = string.char(c)
    elseif c < 0x800 then out[#out + 1] = string.char(0xC0 + math.floor(c / 64), 0x80 + c % 64)
    else out[#out + 1] = string.char(0xE0 + math.floor(c / 4096), 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64) end
  end
  return table.concat(out)
end

-- the experience a level needs, by growth rate
local function expFor(rate, n)
  if n <= 1 then return 0 end
  local c = n * n * n
  if rate == 1 then return math.floor(5 * c / 4)
  elseif rate == 3 then return math.floor(4 * c / 5)
  elseif rate == 4 then return math.floor(6 * c / 5 - 15 * n * n + 100 * n - 140)
  elseif rate == 5 then
    if n <= 50 then return math.floor(c * (100 - n) / 50)
    elseif n <= 68 then return math.floor(c * (150 - n) / 100)
    elseif n <= 98 then return math.floor(c * math.floor((1911 - 10 * n) / 3) / 500)
    else return math.floor(c * (160 - n) / 100) end
  elseif rate == 6 then
    if n <= 15 then return math.floor(c * (math.floor((n + 1) / 3) + 24) / 50)
    elseif n <= 36 then return math.floor(c * (n + 14) / 50)
    else return math.floor(c * (math.floor(n / 2) + 32) / 50) end
  end
  return c
end

function P.levelFor(species, exp)
  local rate = S.GROWTH[species] or 2
  local lv = 1
  while lv < 100 and expFor(rate, lv + 1) <= exp do lv = lv + 1 end
  return lv
end

-- the record, from a decrypted structure d.  f: the format's offsets
-- { format, gen, moves, iv, nick, ot, nickChars, otChars, text = function(d, o, n),
--   species = function(raw) -> national }, shinyBelow 8 (Gen 3-5) / 16
function P.record(d, raw, f, where, slot, partyLevel)
  local ec, pid = u32(d, 0), u32(d, f.pid or 0)
  local rawSpecies = u16(d, 0x08)
  local species = f.species and f.species(rawSpecies) or rawSpecies
  if species < 1 or species > S.COUNT then return nil end
  local moves = {}
  for i = 0, 3 do
    local m = u16(d, f.moves + i * 2)
    if m > 0 then moves[#moves + 1] = m end
  end
  local ivs = u32(d, f.iv)
  local tid, sid = u16(d, 0x0C), u16(d, 0x0E)
  local exp = u32(d, 0x10)
  local xor = bit.bxor(bit.bxor(tid, sid), bit.bxor(pid % 65536, math.floor(pid / 65536)))
  if xor < 0 then xor = xor + 65536 end
  return {
    gen = f.gen, format = f.format, raw = raw, species = species, pid = pid, ec = ec,
    nick = f.text(d, f.nick, f.nickChars), ot = f.text(d, f.ot, f.otChars),
    tid = tid, sid = sid, exp = exp,
    level = (partyLevel and partyLevel >= 1 and partyLevel <= 100) and partyLevel or P.levelFor(species, exp),
    item = u16(d, 0x0A), moves = moves, shiny = xor < (f.shinyBelow or 16),
    egg = math.floor(ivs / 2 ^ 30) % 2 == 1, where = where, slot = slot,
  }
end

-- every structure in a run of boxes: count boxes of 30 slots, stride bytes
-- apart (slot), box by box (boxStride, default 30 * stride)
function P.boxes(b, base, count, stride, size, f, out, boxStride)
  boxStride = boxStride or 30 * stride
  for box = 0, count - 1 do
    for s = 0, 29 do
      local o = base + box * boxStride + s * stride
      if o + size > #b then return out end
      if u32(b, o) ~= 0 or u16(b, o + 6) ~= 0 then
        local d = P.decrypt(b, o, size, f.gen45)
        local r = d and P.record(d, b:sub(o + 1, o + stride), f, "Box " .. (box + 1), s + 1)
        if r then out[#out + 1] = r end
      end
    end
  end
  return out
end

-- the party: n structures, stride apart; level from its battle stats
function P.party(b, base, n, stride, size, f, out)
  for i = 0, math.min(n, 6) - 1 do
    local o = base + i * stride
    if o + stride <= #b then
      local d = P.decrypt(b, o, size, f.gen45)
      if d then
        -- the battle stats are encrypted with the constant (the PID), on their own
        local seed, lv = u32(b, o), nil
        local at = f.levelAt - size
        for k = 0, math.floor(at / 2) do
          seed = lcg(seed)
          if k == math.floor(at / 2) then
            local w = bit.bxor(u16(b, o + size + k * 2), math.floor(seed / 65536)) % 65536
            lv = at % 2 == 0 and w % 256 or math.floor(w / 256)
          end
        end
        local r = P.record(d, b:sub(o + 1, o + stride), f, "Party", i + 1, lv)
        if r then out[#out + 1] = r end
      end
    end
  end
  return out
end

return P
