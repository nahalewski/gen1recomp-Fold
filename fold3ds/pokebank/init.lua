-- emuPoke Bank: a Pokemon Bank for every emulator's saves.  It reads the
-- Pokemon out of the games' saves (fold3ds/pokebank/sources.lua: Game Boy
-- to Game Boy Advance now, DS / 3DS / Switch as their readers arrive) and
-- keeps them in 100 boxes of 30 (store.lua), with the original bytes of
-- each so nothing about it is lost.
--
-- A HOME menu applet (3DS theme) that owns both screens while open, and a
-- window on the Switch skin (drawSingle):
--   top     the picked Pokemon: its HOME picture, name, level, trainer,
--           the game it came from; the logo when nothing is picked
--   bottom  tabs (Boxes, Party = the games' Pokemon, Dex, Favorites, Cloud),
--           the page, and the actions below it
-- Boxes: L / R or the arrows change box; tap a Pokemon to see it, Move then
-- tap where it goes, the star to favourite it, the bin to let it go.
-- Party: pick a game, tap the Pokemon to bring (or none for all), Deposit.
-- Depositing copies: the game keeps its Pokemon (taking them out of the
-- game's save comes with the save writers).
local PB = {}

local lg = love.graphics
local ST = require("fold3ds.pokebank.store")
local SRC = require("fold3ds.pokebank.sources")
local SP = require("fold3ds.pokebank.sprites")
local S = require("fold3ds.pokebank.species")

local UI = "fold3ds/pokebank/ui/"
local ctx = { font = function(s) return lg.newFont(math.max(6, math.floor(s))) end }
local st = {
  open = false, tab = "boxes", box = 1, sel = nil, moving = nil, confirm = nil,
  sources = nil, src = nil, data = nil, page = 1, picked = {}, msg = nil, msgAt = 0,
  dexPage = 1, favPage = 1, hits = {}, touches = {},
}
local imgs = {}

local function img(name)
  if imgs[name] == nil then
    local ok, i = pcall(lg.newImage, UI .. name .. ".png")
    imgs[name] = ok and i or false
    if ok then i:setFilter("linear", "linear") end
  end
  return imgs[name] or nil
end

-- draw a piece into x, y, w, h (fit, centred)
local function piece(name, x, y, w, h, a)
  local i = img(name)
  if not i then return end
  local k = math.min(w / i:getWidth(), h / i:getHeight())
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(i, x + (w - i:getWidth() * k) / 2, y + (h - i:getHeight() * k) / 2, 0, k, k)
end

-- stretch a piece over x, y, w, h
local function fill(name, x, y, w, h, a)
  local i = img(name)
  if not i then return end
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(i, x, y, 0, w / i:getWidth(), h / i:getHeight())
end

-- a bar stretched in the middle only: its end caps (as wide as it is
-- tall) keep their shape
local quads = {}
local function bar3(name, x, y, w, h, a)
  local i = img(name)
  if not i then return end
  local iw, ih = i:getDimensions()
  local cap = math.min(ih, iw / 3)
  local k = h / ih
  local cw = math.min(cap * k, w / 2)
  quads[name] = quads[name] or {
    lg.newQuad(0, 0, cap, ih, iw, ih), lg.newQuad(cap, 0, iw - cap * 2, ih, iw, ih), lg.newQuad(iw - cap, 0, cap, ih, iw, ih) }
  local q = quads[name]
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(i, q[1], x, y, 0, cw / cap, k)
  lg.draw(i, q[2], x + cw, y, 0, (w - cw * 2) / (iw - cap * 2), k)
  lg.draw(i, q[3], x + w - cw, y, 0, cw / cap, k)
end

local function hit(id, x, y, w, h) st.hits[#st.hits + 1] = { id = id, x = x, y = y, w = w, h = h } end
local function say(t) st.msg, st.msgAt = t, love.timer.getTime() end
local function sfx(n) if ctx.sfx then ctx.sfx(n) end end

local function monName(m)
  if not m then return "" end
  if m.egg then return "Egg" end
  local species = S.NAME[m.species] or ("#" .. tostring(m.species))
  if m.nick and m.nick ~= "" and m.nick:upper() ~= species:upper() then return m.nick .. " (" .. species .. ")" end
  return species
end

-- a Pokemon's box picture, or a silhouette until it arrives
local function drawMon(m, x, y, s, a)
  if not m then return end
  local pic = not m.egg and SP.get(m.species, "box", m.shiny)
  if pic then
    local k = s / math.max(pic:getWidth(), pic:getHeight()) * 1.25
    lg.setColor(1, 1, 1, a or 1)
    lg.draw(pic, x + s / 2, y + s / 2, 0, k, k, pic:getWidth() / 2, pic:getHeight() / 2)
  else
    piece("mon2_" .. ((m.species or 1) % 12 + 1), x + s * 0.1, y + s * 0.1, s * 0.8, s * 0.8, 0.55 * (a or 1))
  end
  if m.shiny then piece("ico_star", x + s * 0.68, y + s * 0.02, s * 0.3, s * 0.3) end
end

---------------------------------------------------------------- open / close
function PB.init(context) for k, v in pairs(context or {}) do ctx[k] = v end end
function PB.isOpen() return st.open end

function PB.open()
  ST.load()
  st.open, st.tab, st.sel, st.moving, st.confirm = true, "boxes", nil, nil, nil
  st.sources, st.src, st.data = nil, nil, nil
  sfx("open")
end

function PB.close() st.open = false end

---------------------------------------------------------------- the top screen
local function picked()
  if st.tab == "boxes" and st.sel then return ST.box(st.box).mons[st.sel] end
  if st.tab == "party" and st.data and st.sel then return st.data.mons[st.sel] end
  if st.tab == "favorites" and st.favSel then return st.favSel end
end

function PB.drawTop(r)
  lg.push("all")
  lg.setScissor(r.x, r.y, r.w, r.h)
  lg.setColor(0.03, 0.05, 0.14, 1)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  local pad = r.h * 0.04
  fill("panel_main", r.x + pad, r.y + pad, r.w - pad * 2, r.h - pad * 2)
  local ix, iy, iw, ih = r.x + pad * 3, r.y + r.h * 0.2, r.w - pad * 6, r.h * 0.68
  local m = picked()
  if not m then
    piece("logo", ix, iy - r.h * 0.04, iw, ih * 0.8)
    local f = ctx.font(r.h * 0.055)
    lg.setFont(f)
    lg.setColor(0.7, 0.85, 1, 1)
    local line = ("%d Pokemon in the Bank"):format(ST.count())
    if st.tab == "party" and st.data then
      line = ("%s  -  %s  -  %d Pokemon"):format(st.src.title, st.data.trainer or "", #st.data.mons)
    end
    lg.printf(line, ix, iy + ih * 0.82, iw, "center")
    lg.pop()
    return
  end
  -- the picture
  local ps = math.min(ih, iw * 0.45)
  local pic = not m.egg and SP.get(m.species, "home", m.shiny)
  if pic then
    local k = ps / math.max(pic:getWidth(), pic:getHeight())
    lg.setColor(1, 1, 1, 1)
    lg.draw(pic, ix + ps / 2, iy + ih / 2, 0, k, k, pic:getWidth() / 2, pic:getHeight() / 2)
  else
    drawMon(m, ix, iy + (ih - ps) / 2, ps)
  end
  -- the facts
  local tx, tw = ix + ps + pad * 2, iw - ps - pad * 2
  local nf, f = ctx.font(r.h * 0.075), ctx.font(r.h * 0.052)
  lg.setFont(nf)
  lg.setColor(1, 1, 1, 1)
  lg.printf(monName(m), tx, iy, tw, "left")
  local y = iy + nf:getHeight() * 1.3
  lg.setFont(f)
  local rows = {
    ("No. %04d   Lv. %d%s"):format(m.species or 0, m.level or 0, m.shiny and "   Shiny" or ""),
    ("Trainer %s   ID %05d"):format(m.ot or "?", m.tid or 0),
    ("From %s"):format(m.from or (st.src and st.src.title) or m.game or "?"),
    ("Generation %d  (%s)"):format(m.gen or 0, (m.format or ""):upper()),
  }
  for _, line in ipairs(rows) do
    lg.setColor(0.72, 0.84, 1, 1)
    lg.printf(line, tx, y, tw, "left")
    y = y + f:getHeight() * 1.35
  end
  if m.fav then piece("ico_star", tx, y, f:getHeight() * 1.4, f:getHeight() * 1.4) end
  lg.pop()
end

---------------------------------------------------------------- the bottom screen
local TABS = { { "boxes", "sq_boxes" }, { "party", "sq_party" }, { "dex", "sq_dex" },
  { "favorites", "sq_favorites" }, { "cloud", "sq_cloud" } }

-- a 6 x 5 grid of slots in x, y, w, h; each(i) -> the Pokemon, and its look
local function grid(x, y, w, h, each)
  local cols, rows = 6, 5
  local s = math.min(w / cols, h / rows)
  local gx, gy = x + (w - s * cols) / 2, y + (h - s * rows) / 2
  for i = 1, 30 do
    local cx = gx + ((i - 1) % cols) * s
    local cy = gy + math.floor((i - 1) / cols) * s
    local m, look = each(i)
    fill(look or "slot_empty", cx + 1, cy + 1, s - 2, s - 2)
    if m then drawMon(m, cx + s * 0.08, cy + s * 0.08, s * 0.84) end
    hit("slot:" .. i, cx, cy, s, s)
  end
end

-- the header: < title >
local function header(x, y, w, h, title, prevId, nextId)
  piece("arrow_left", x, y, h * 1.6, h)
  if prevId then hit(prevId, x, y, h * 1.6, h) end
  piece("arrow_right", x + w - h * 1.6, y, h * 1.6, h)
  if nextId then hit(nextId, x + w - h * 1.6, y, h * 1.6, h) end
  bar3("bar_cyan", x + h * 1.8, y, w - h * 3.6, h)
  -- as big as fits on one line
  local room = w - h * 4.8
  local size = h * 0.5
  local f = ctx.font(size)
  while f:getWidth(title) > room and size > 6 do size = size - 1; f = ctx.font(size) end
  lg.setFont(f)
  lg.setColor(1, 1, 1, 1)
  lg.printf(title, x + h * 2.4, y + (h - f:getHeight()) / 2, room, "center")
end

local function actions(x, y, w, h, list)
  local n = #list
  local s = math.min(h, w / n)
  local gap = (w - s * n) / math.max(1, n - 1)
  for i, a in ipairs(list) do
    local bx = x + (i - 1) * (s + gap)
    piece(a[2], bx, y, s, s, a.off and 0.35 or 1)
    if not a.off then hit(a[1], bx, y, s, s) end
  end
end

local function drawBoxes(x, y, w, h, bar)
  local box = ST.box(st.box)
  header(x, y, w, bar, box.name .. ("  (%d/%d)"):format(st.box, ST.BOXES), "boxprev", "boxnext")
  grid(x, y + bar * 1.15, w, h - bar * 1.15, function(i)
    local m = box.mons[i]
    local look = "slot_empty"
    if st.moving and st.moving[1] == st.box and st.moving[2] == i then look = "slot_purple"
    elseif st.sel == i then look = "slot_blue" end
    return m, look
  end)
end

local function drawSources(x, y, w, h, bar)
  if not st.data then
    st.sources = st.sources or SRC.list()
    local f = ctx.font(bar * 0.45)
    lg.setFont(f)
    lg.setColor(0.72, 0.84, 1, 1)
    lg.printf("Pick a game to bring its Pokemon", x, y + (bar - f:getHeight()) / 2, w, "center")
    if #st.sources == 0 then
      lg.printf("No saves found yet.  Play a Pokemon game (Game Boy, Color or Advance, or the "
        .. "gen1recomp games) and save in it, then come back.", x + w * 0.05, y + h * 0.35, w * 0.9, "center")
      return
    end
    local rh = bar * 1.05
    for i, s in ipairs(st.sources) do
      local ry = y + bar * 1.2 + (i - 1) * (rh + 4)
      if ry + rh > y + h then break end
      bar3(s.pokemon and "bar_cyan" or "bar_grey", x, ry, w, rh)
      lg.setColor(1, 1, 1, 1)
      lg.printf(s.title, x + rh * 1.3, ry + (rh - f:getHeight()) / 2, w - rh * 3, "left")
      lg.setColor(0.7, 0.85, 1, 1)
      lg.printf(s.sys:upper(), x, ry + (rh - f:getHeight()) / 2, w - rh * 0.4, "right")
      hit("src:" .. i, x, ry, w, rh)
    end
    return
  end
  local pages = math.max(1, math.ceil(#st.data.mons / 30))
  st.page = math.max(1, math.min(pages, st.page))
  header(x, y, w, bar, ("%s  %d/%d"):format(st.data.game, st.page, pages), "pageprev", "pagenext")
  grid(x, y + bar * 1.15, w, h - bar * 1.15, function(i)
    local k = (st.page - 1) * 30 + i
    local m = st.data.mons[k]
    local look = st.picked[k] and "slot_purple" or (st.sel == k and "slot_blue" or "slot_empty")
    if m and ST.has(m) then look = st.picked[k] and "slot_purple" or "slot_empty2" end
    return m, look
  end)
end

local function drawDex(x, y, w, h, bar)
  local caught = {}
  for _, b in ipairs(ST.load().boxes) do for _, m in pairs(b.mons) do caught[m.species] = true end end
  local n = 0
  for _ in pairs(caught) do n = n + 1 end
  local pages = math.ceil(S.COUNT / 30)
  st.dexPage = math.max(1, math.min(pages, st.dexPage))
  header(x, y, w, bar, ("Dex  %d / %d"):format(n, S.COUNT), "dexprev", "dexnext")
  local f = ctx.font(bar * 0.34)
  grid(x, y + bar * 1.15, w, h - bar * 1.15, function(i)
    local no = (st.dexPage - 1) * 30 + i
    if no > S.COUNT then return nil, "slot_locked" end
    if caught[no] then return { species = no }, "slot_empty" end
    return nil, "slot_empty2"
  end)
  -- the numbers under the empty ones
  lg.setFont(f)
  for _, hh in ipairs(st.hits) do
    local i = tonumber(hh.id:match("^slot:(%d+)$") or "")
    local no = i and (st.dexPage - 1) * 30 + i
    if no and no <= S.COUNT and not caught[no] then
      lg.setColor(0.6, 0.7, 0.9, 0.7)
      lg.printf(("%d"):format(no), hh.x, hh.y + (hh.h - f:getHeight()) / 2, hh.w, "center")
    end
  end
end

local function favorites()
  local out = {}
  for bi, b in ipairs(ST.load().boxes) do
    for si = 1, ST.PER do
      local m = b.mons[si]
      if m and m.fav then out[#out + 1] = { m = m, box = bi, slot = si } end
    end
  end
  return out
end

local function drawFavorites(x, y, w, h, bar)
  local list = favorites()
  local pages = math.max(1, math.ceil(#list / 30))
  st.favPage = math.max(1, math.min(pages, st.favPage))
  header(x, y, w, bar, ("Favorites  %d"):format(#list), "favprev", "favnext")
  st.favList = list
  grid(x, y + bar * 1.15, w, h - bar * 1.15, function(i)
    local e = list[(st.favPage - 1) * 30 + i]
    return e and e.m, (e and st.favSel == e.m) and "slot_blue" or "slot_empty"
  end)
end

local function drawCloud(x, y, w, h)
  piece("util_cloud", x + w * 0.4, y + h * 0.15, w * 0.2, h * 0.25)
  local f = ctx.font(h * 0.075)
  lg.setFont(f)
  lg.setColor(0.72, 0.84, 1, 1)
  lg.printf("The online Bank (moving Pokemon between phones and to friends) comes with "
    .. "online friend codes.  Everything here is kept on this phone for now.", x + w * 0.06, y + h * 0.48, w * 0.88, "center")
end

function PB.drawBottom(r)
  st.hits = {}
  lg.push("all")
  lg.setScissor(r.x, r.y, r.w, r.h)
  lg.setColor(0.02, 0.04, 0.12, 1)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  local pad = math.floor(r.w * 0.02)
  -- the tabs
  local th = r.h * 0.13
  local tw = (r.w - pad * 2) / #TABS
  for i, t in ipairs(TABS) do
    local tx = r.x + pad + (i - 1) * tw
    piece(t[2], tx, r.y + pad * 0.5, tw, th, st.tab == t[1] and 1 or 0.55)
    hit("tab:" .. t[1], tx, r.y, tw, th + pad)
  end
  local ay = r.y + r.h - th - pad * 0.5
  local cy = r.y + th + pad * 1.5
  local ch = ay - cy - pad
  local bar = r.h * 0.085
  local x, w = r.x + pad, r.w - pad * 2
  if st.tab == "boxes" then
    drawBoxes(x, cy, w, ch, bar)
    local m = st.sel and ST.box(st.box).mons[st.sel]
    actions(x, ay, w, th, {
      { "back", "sq_back" },
      { "move", "sq_move", off = not m },
      { "fav", "sq_favorites", off = not m },
      { "release", "ico_trash", off = not m },
    })
  elseif st.tab == "party" then
    drawSources(x, cy, w, ch, bar)
    actions(x, ay, w, th, {
      { "back", "sq_back" },
      { "all", "util_grid", off = not st.data },
      { "deposit", "sq_deposit", off = not st.data },
    })
  elseif st.tab == "dex" then
    drawDex(x, cy, w, ch, bar)
    actions(x, ay, w, th, { { "back", "sq_back" } })
  elseif st.tab == "favorites" then
    drawFavorites(x, cy, w, ch, bar)
    actions(x, ay, w, th, { { "back", "sq_back" } })
  else
    drawCloud(x, cy, w, ch)
    actions(x, ay, w, th, { { "back", "sq_back" } })
  end
  -- a question, or a message
  if st.confirm then
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", r.x, r.y, r.w, r.h)
    local f = ctx.font(r.h * 0.06)
    lg.setFont(f)
    lg.setColor(1, 1, 1, 1)
    lg.printf(st.confirm.text, r.x + pad * 3, r.y + r.h * 0.3, r.w - pad * 6, "center")
    local bw, bh = r.w * 0.34, r.h * 0.16
    st.hits = {}
    fill("big_back", r.x + r.w * 0.12, r.y + r.h * 0.58, bw, bh)
    hit("no", r.x + r.w * 0.12, r.y + r.h * 0.58, bw, bh)
    fill("big_confirm_green", r.x + r.w * 0.54, r.y + r.h * 0.58, bw, bh)
    hit("yes", r.x + r.w * 0.54, r.y + r.h * 0.58, bw, bh)
  elseif st.msg and love.timer.getTime() - st.msgAt < 3 then
    local f = ctx.font(r.h * 0.05)
    lg.setFont(f)
    local tw2 = math.min(r.w - pad * 4, f:getWidth(st.msg) + f:getHeight() * 1.5)
    local mx = r.x + (r.w - tw2) / 2
    local my = r.y + r.h * 0.45
    lg.setColor(0.05, 0.1, 0.25, 0.95)
    lg.rectangle("fill", mx, my, tw2, f:getHeight() * 2.2, 8, 8)
    lg.setColor(0.4, 0.85, 1, 1)
    lg.setLineWidth(2)
    lg.rectangle("line", mx, my, tw2, f:getHeight() * 2.2, 8, 8)
    lg.setColor(1, 1, 1, 1)
    lg.printf(st.msg, mx, my + f:getHeight() * 0.6, tw2, "center")
  end
  lg.pop()
end

-- one window (the Switch skin): the top screen's part on the left, the
-- bottom screen's on the right
function PB.drawSingle(r)
  local lw = math.floor(r.w * 0.5)
  PB.drawTop({ x = r.x, y = r.y, w = lw, h = r.h })
  PB.drawBottom({ x = r.x + lw, y = r.y, w = r.w - lw, h = r.h })
end

---------------------------------------------------------------- doing
local function back()
  if st.confirm then st.confirm = nil return end
  if st.moving then st.moving = nil return end
  if st.tab == "party" and st.data then st.data, st.src, st.sel, st.picked = nil, nil, nil, {} return end
  PB.close()
  sfx("back")
  return "exit"
end

local function deposit()
  if not st.data then return end
  local list = {}
  for k, m in ipairs(st.data.mons) do if st.picked[k] then list[#list + 1] = m end end
  if #list == 0 then list = st.data.mons end
  local added, dup = ST.deposit(list, { title = st.src.title, game = st.data.game })
  st.picked = {}
  sfx("select")
  if added == 0 and dup > 0 then say("They're all in the Bank already")
  else say(("%d copied into the Bank%s"):format(added, dup > 0 and (" (%d were there)"):format(dup) or "")) end
end

local function press(id)
  if id == "back" or id == "no" then return back() end
  if id == "yes" and st.confirm then
    local c = st.confirm
    st.confirm = nil
    ST.release(c.box, c.slot)
    st.sel = nil
    sfx("back")
    say("Released")
    return
  end
  local tab = id:match("^tab:(%w+)$")
  if tab then
    st.tab, st.sel, st.moving, st.favSel = tab, nil, nil, nil
    if tab == "party" then st.sources = nil end
    sfx("select")
    return
  end
  if id == "boxprev" then st.box = (st.box - 2) % ST.BOXES + 1; st.sel = nil; sfx("over") return end
  if id == "boxnext" then st.box = st.box % ST.BOXES + 1; st.sel = nil; sfx("over") return end
  if id == "pageprev" then st.page = st.page - 1 return end
  if id == "pagenext" then st.page = st.page + 1 return end
  if id == "dexprev" then st.dexPage = st.dexPage - 1 return end
  if id == "dexnext" then st.dexPage = st.dexPage + 1 return end
  if id == "favprev" then st.favPage = st.favPage - 1 return end
  if id == "favnext" then st.favPage = st.favPage + 1 return end
  if id == "move" and st.sel then st.moving = { st.box, st.sel }; say("Tap where it goes") return end
  if id == "fav" and st.sel then ST.favorite(st.box, st.sel); sfx("select") return end
  if id == "release" and st.sel and ST.box(st.box).mons[st.sel] then
    st.confirm = { box = st.box, slot = st.sel,
      text = ("Release %s?  It leaves the Bank for good."):format(monName(ST.box(st.box).mons[st.sel])) }
    return
  end
  if id == "deposit" then deposit() return end
  if id == "all" and st.data then
    local all = true
    for k = 1, #st.data.mons do if not st.picked[k] then all = false end end
    st.picked = {}
    if not all then for k = 1, #st.data.mons do st.picked[k] = true end end
    return
  end
  local src = tonumber(id:match("^src:(%d+)$") or "")
  if src then
    local s = st.sources[src]
    local data, why = SRC.read(s)
    if data then
      st.src, st.data, st.page, st.sel, st.picked = s, data, 1, nil, {}
      sfx("open")
      if #data.mons == 0 then say("No Pokemon in this save yet") end
    else
      say(why or "Not a Pokemon save")
    end
    return
  end
  local slot = tonumber(id:match("^slot:(%d+)$") or "")
  if slot then
    if st.tab == "boxes" then
      if st.moving then
        ST.move(st.moving[1], st.moving[2], st.box, slot)
        st.moving, st.sel = nil, slot
        sfx("select")
      else
        st.sel = ST.box(st.box).mons[slot] and slot or nil
        sfx("over")
      end
    elseif st.tab == "party" and st.data then
      local k = (st.page - 1) * 30 + slot
      if st.data.mons[k] then
        st.picked[k] = not st.picked[k] or nil
        st.sel = k
        sfx("over")
      end
    elseif st.tab == "favorites" then
      local e = st.favList and st.favList[(st.favPage - 1) * 30 + slot]
      st.favSel = e and e.m or nil
    end
  end
end

local function hitAt(x, y)
  for k = #st.hits, 1, -1 do
    local h = st.hits[k]
    if x >= h.x and y >= h.y and x <= h.x + h.w and y <= h.y + h.h then return h end
  end
end

function PB.pressed(id, x, y)
  local h = hitAt(x, y)
  st.touches[id] = h and h.id
end

function PB.moved() end

function PB.released(id, x, y)
  local want = st.touches[id]
  st.touches[id] = nil
  local h = hitAt(x, y)
  if want and h and h.id == want then return press(want) end
end

function PB.button(btn)
  if btn == "b" or btn == "home" then return back() end
  if btn == "l" then return press(st.tab == "boxes" and "boxprev" or "pageprev") end
  if btn == "r" then return press(st.tab == "boxes" and "boxnext" or "pagenext") end
  if st.tab == "boxes" or (st.tab == "party" and st.data) then
    local cur = st.sel or 0
    local d = ({ left = -1, right = 1, up = -6, down = 6 })[btn]
    if d then
      local base = st.tab == "party" and (st.page - 1) * 30 or 0
      local i = math.max(1, math.min(30, (cur > 0 and cur - base or 0) + d))
      st.sel = base + i
      sfx("over")
      return
    end
    if btn == "a" and st.sel then
      return press("slot:" .. (st.tab == "party" and (st.sel - (st.page - 1) * 30) or st.sel))
    end
  end
end

return PB
