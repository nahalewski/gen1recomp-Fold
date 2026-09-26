-- emuPoke Bank: the Pokemon in a Game Boy Advance save (Gen 3: Ruby,
-- Sapphire, Emerald, FireRed, LeafGreen), the 128 KB flash image: two save
-- slots of fourteen 4 KB sections, the newer one read.  Each Pokemon is an
-- 80-byte PK3 whose 48-byte data block is XOR-encrypted with PID ^ OT ID
-- and shuffled by PID % 24.  Offsets from Bulbapedia's "Save data structure
-- (Generation III)" and "Pokemon data structure (Generation III)".
--
-- read(bytes) -> nil, why | { gen = 3, game, trainer, tid, sid, mons }
-- (records as in gen12.lua, format "pk3", raw = the 80 bytes as saved)
local S = require("fold3ds.pokebank.species")
local bit = require("bit")

local G = {}

local function u8(b, o) return b:byte(o + 1) end
local function u16(b, o) return b:byte(o + 1) + b:byte(o + 2) * 256 end
local function u32(b, o) return u16(b, o) + u16(b, o + 2) * 65536 end

-- the experience a level needs, by growth rate (1 slow, 2 medium fast,
-- 3 fast, 4 medium slow, 5 erratic, 6 fluctuating)
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

local function levelFor(species, exp)
  local rate = S.GROWTH[species] or 2
  local lv = 1
  while lv < 100 and expFor(rate, lv + 1) <= exp do lv = lv + 1 end
  return lv
end
G.levelFor = levelFor

local SIG = 0x08012025
local SIZES = { [0] = 3884, 3968, 3968, 3968, 3848, 3968, 3968, 3968, 3968, 3968, 3968, 3968, 3968, 2000 }

-- the Game Boy Advance games' letters (English)
local CHARS = { [0x00] = " ", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB0] = "...",
  [0xB1] = "\"", [0xB2] = "\"", [0xB3] = "'", [0xB4] = "'", [0xB5] = "M", [0xB6] = "F", [0xB8] = ",",
  [0xBA] = "/" }
for i = 0, 9 do CHARS[0xA1 + i] = tostring(i) end
for i = 0, 25 do
  CHARS[0xBB + i] = string.char(65 + i)
  CHARS[0xD5 + i] = string.char(97 + i)
end

local function text(b, o, n)
  local out = {}
  for i = 0, n - 1 do
    local c = u8(b, o + i)
    if c == 0xFF or c == nil then break end
    out[#out + 1] = CHARS[c] or "?"
  end
  return table.concat(out)
end

-- the save slot to read: its sections by id (the one with the higher counter)
local function sections(b)
  local best
  for slot = 0, 1 do
    local base = slot * 0xE000
    local secs, index, ok = {}, nil, true
    for i = 0, 13 do
      local o = base + i * 0x1000
      if o + 0x1000 > #b or u32(b, o + 0xFF8) ~= SIG then ok = false break end
      local id = u16(b, o + 0xFF4)
      if id > 13 then ok = false break end
      secs[id] = o
      index = u32(b, o + 0xFFC)
    end
    if ok and (not best or index > best.index) then best = { secs = secs, index = index } end
  end
  return best and best.secs
end

-- the orders the four 12-byte blocks come in: Growth, Attacks, EVs, Misc
local ORDERS = { "GAEM", "GAME", "GEAM", "GEMA", "GMAE", "GMEA", "AGEM", "AGME", "AEGM", "AEMG", "AMGE", "AMEG",
  "EGAM", "EGMA", "EAGM", "EAMG", "EMGA", "EMAG", "MGAE", "MGEA", "MAGE", "MAEG", "MEGA", "MEAG" }

-- one PK3 (80 bytes at o) -> the record, or nil when the slot is empty / bad
local function pk3(b, o, where, slot, partyLevel, tidSid)
  local pid, otid = u32(b, o), u32(b, o + 4)
  if pid == 0 and otid == 0 then return nil end
  local key = bit.bxor(pid, otid)
  local words, sum = {}, 0
  for i = 0, 11 do
    local w = bit.bxor(u32(b, o + 0x20 + i * 4), key)
    if w < 0 then w = w + 4294967296 end
    words[i] = w
    sum = sum + w % 65536 + math.floor(w / 65536)
  end
  if sum % 65536 ~= u16(b, o + 0x1C) then return nil end
  local order = ORDERS[pid % 24 + 1]
  local block = {}
  for i = 1, 4 do block[order:sub(i, i)] = (i - 1) * 3 end
  local function w(letter, k) return words[block[letter] + k] end
  local g0, g1 = w("G", 0), w("G", 1)
  local species = S.GEN3_INDEX[g0 % 65536]
  if not species then return nil end
  local moves = {}
  local a0, a1 = w("A", 0), w("A", 1)
  for _, m in ipairs({ a0 % 65536, math.floor(a0 / 65536), a1 % 65536, math.floor(a1 / 65536) }) do
    if m > 0 then moves[#moves + 1] = m end
  end
  local ivs = w("M", 1)
  local egg = math.floor(ivs / 2 ^ 30) % 2 == 1
  local exp = g1
  local level = partyLevel or levelFor(species, exp)
  local tid, sid = otid % 65536, math.floor(otid / 65536)
  local shiny = bit.bxor(bit.bxor(tid, sid), bit.bxor(pid % 65536, math.floor(pid / 65536))) < 8
  return {
    gen = 3, format = "pk3", raw = b:sub(o + 1, o + 80), species = species, pid = pid,
    nick = text(b, o + 8, 10), ot = text(b, o + 0x14, 7), tid = tid, sid = sid, level = level,
    item = math.floor(g0 / 65536), exp = exp, moves = moves, shiny = shiny, egg = egg,
    where = where, slot = slot,
  }
end

function G.read(b)
  if #b < 0x1C000 then return nil, "not a Gen 3 save" end
  local secs = sections(b)
  if not secs then return nil, "not a Gen 3 save" end
  local t = secs[0]
  local code = u32(b, t + 0xAC)
  local game = code == 0 and "Ruby / Sapphire" or code == 1 and "FireRed / LeafGreen" or "Emerald"
  local out = {}
  -- the party
  local team = secs[1]
  local countAt, partyAt = 0x234, 0x238
  if code == 1 then countAt, partyAt = 0x34, 0x38 end
  local n = u8(b, team + countAt)
  for i = 0, math.min(n, 6) - 1 do
    local o = team + partyAt + i * 100
    local r = pk3(b, o, "Party", i + 1, u8(b, o + 0x54))
    if r then out[#out + 1] = r end
  end
  -- the PC: sections 5 to 13, end to end
  local pc = {}
  for id = 5, 13 do pc[#pc + 1] = b:sub(secs[id] + 1, secs[id] + SIZES[id]) end
  pc = table.concat(pc)
  for box = 0, 13 do
    for s = 0, 29 do
      local r = pk3(pc, 4 + (box * 30 + s) * 80, "Box " .. (box + 1), s + 1)
      if r then out[#out + 1] = r end
    end
  end
  local id = u32(b, t + 0x0A)
  return { gen = 3, game = game, trainer = text(b, t, 7), tid = id % 65536, sid = math.floor(id / 65536), mons = out }
end

return G
