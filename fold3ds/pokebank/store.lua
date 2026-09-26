-- emuPoke Bank's storage: 100 boxes of 30, kept in the save folder
-- (pokebank/bank.lua), a copy of the last good file beside it
-- (bank.bak.lua).  Each Pokemon keeps its original bytes from the game it
-- came from (raw, as hex), so it can go back into a game of its generation,
-- or on to a later one, without losing anything.
local ST = {}

ST.BOXES, ST.PER = 100, 30
local DIR, FILE, BAK = "pokebank", "pokebank/bank.lua", "pokebank/bank.bak.lua"

local data

local function hex(s) return (s:gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
local function unhex(h) return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end)) end
ST.hex, ST.unhex = hex, unhex

-- a Pokemon's identity: the same one copied in twice stays one
function ST.fingerprint(r)
  local raw = r.rawHex or (r.raw and hex(r.raw)) or ""
  return table.concat({ r.format or "", raw, r.nick or "", r.ot or "" }, "|")
end

local function empty()
  local d = { version = 1, boxes = {} }
  for i = 1, ST.BOXES do d.boxes[i] = { name = "Box " .. i, mons = {} } end
  return d
end

local function ser(v, ind)
  local t = type(v)
  if t == "string" then return ("%q"):format(v)
  elseif t == "number" or t == "boolean" then return tostring(v)
  elseif t ~= "table" then return "nil" end
  ind = ind or ""
  local out, keys = { "{" }, {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  for _, k in ipairs(keys) do
    local key = type(k) == "number" and ("[" .. k .. "]") or (("[%q]"):format(k))
    out[#out + 1] = ind .. " " .. key .. " = " .. ser(v[k], ind .. " ") .. ","
  end
  out[#out + 1] = ind .. "}"
  return table.concat(out, "\n")
end

local function read(file)
  local ok, text = pcall(love.filesystem.read, file)
  if not ok or not text then return nil end
  local fn = loadstring and loadstring(text) or load(text)
  if not fn then return nil end
  if setfenv then setfenv(fn, {}) end
  local ok2, d = pcall(fn)
  if ok2 and type(d) == "table" and type(d.boxes) == "table" then return d end
end

function ST.load()
  if data then return data end
  data = read(FILE) or read(BAK) or empty()
  for i = 1, ST.BOXES do
    data.boxes[i] = data.boxes[i] or { name = "Box " .. i, mons = {} }
    data.boxes[i].mons = data.boxes[i].mons or {}
  end
  return data
end

function ST.save()
  if not data then return end
  love.filesystem.createDirectory(DIR)
  if love.filesystem.getInfo(FILE) then
    local old = love.filesystem.read(FILE)
    if old then love.filesystem.write(BAK, old) end
  end
  love.filesystem.write(FILE, "return " .. ser(data) .. "\n")
end

function ST.box(i) return ST.load().boxes[i] end

function ST.count()
  local n = 0
  for _, b in ipairs(ST.load().boxes) do for _ in pairs(b.mons) do n = n + 1 end end
  return n
end

-- every fingerprint in the bank
local function known()
  local k = {}
  for _, b in ipairs(ST.load().boxes) do
    for _, m in pairs(b.mons) do k[ST.fingerprint(m)] = true end
  end
  return k
end

function ST.has(r) return known()[ST.fingerprint(r)] == true end

-- copy records from a game into the first free slots, from box `from` on;
-- the ones already in are skipped.  -> how many went in, how many were there
function ST.deposit(records, source, from)
  local d = ST.load()
  local have = known()
  local added, dup = 0, 0
  local bi, si = from or 1, 1
  for _, r in ipairs(records) do
    local fp = ST.fingerprint(r)
    if have[fp] then dup = dup + 1
    else
      while bi <= ST.BOXES and d.boxes[bi].mons[si] do
        si = si + 1
        if si > ST.PER then bi, si = bi + 1, 1 end
      end
      if bi > ST.BOXES then break end
      d.boxes[bi].mons[si] = {
        gen = r.gen, format = r.format, rawHex = r.raw and hex(r.raw) or r.rawHex,
        species = r.species, nick = r.nick, ot = r.ot, tid = r.tid, sid = r.sid, pid = r.pid,
        level = r.level, item = r.item, shiny = r.shiny or false, egg = r.egg or false,
        moves = r.moves, from = source and source.title, game = source and source.game,
        at = os.time(),
      }
      have[fp] = true
      added = added + 1
    end
  end
  ST.save()
  return added, dup
end

function ST.move(fromBox, fromSlot, toBox, toSlot)
  local d = ST.load()
  local a, b = d.boxes[fromBox].mons, d.boxes[toBox].mons
  a[fromSlot], b[toSlot] = b[toSlot], a[fromSlot]
  ST.save()
end

function ST.release(box, slot)
  ST.load().boxes[box].mons[slot] = nil
  ST.save()
end

function ST.favorite(box, slot)
  local m = ST.load().boxes[box].mons[slot]
  if m then m.fav = not m.fav or nil; ST.save() end
end

return ST
