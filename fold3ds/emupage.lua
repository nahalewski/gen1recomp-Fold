-- An emulator's settings page, opened from an icon in its folder on the
-- HOME menu (3DS theme): the rows its provider gives (p.page()) drawn as
-- the 3DS's System Settings draws them.
--   choice rows  { key, label, value, choices = {{value, label}} }  tap, or
--                <- / ->, to step through them -> p.setSetting(key, value)
--   text rows    { key, label, value, text = max length }  the keyboard
--   action rows  { action, label, sub }  -> p.act(action)
--   info rows    { info = true, label }
-- B / HOME / Back close it (p.closePage()).  Any emulator with page() gets
-- this; Azahar opens its own settings screens instead.  Every page ends with
-- Credits (fold3ds/credits.lua), which takes both screens while it is open.
local EPG = {}

local lg = love.graphics
local Emus = require("fold3ds.emus")
local Sfx = require("fold3ds.sfx")
local Credits = require("fold3ds.credits")

local ctx
local st = { hits = {}, touches = {}, sel = 1, scroll = 0, pageId = nil, text = nil, maxScroll = 0 }

local function col(c, a) lg.setColor(c[1] / 255, c[2] / 255, c[3] / 255, a or 1) end

-- the emulator whose page is open, and the page
-- which emulator's folder the page was opened from (two can share pages)
function EPG.opened(id) st.owner = id end

function EPG.active()
  local list = {}
  for _, p in ipairs(Emus.providers()) do
    if p.id == st.owner then table.insert(list, 1, p) else list[#list + 1] = p end
  end
  for _, p in ipairs(list) do
    if p.page then
      local ok, pg = pcall(p.page)
      if ok and type(pg) == "table" then
        if pg.id ~= st.pageId then st.pageId, st.sel, st.scroll, st.text = pg.id, 1, 0, nil end
        pg.rows = pg.rows or {}
        local last = pg.rows[#pg.rows]
        if not (last and last.credits) then
          pg.rows[#pg.rows + 1] = { credits = true, action = "credits", label = "Credits",
            sub = "AI Slop Productions and every emulator in AeonDX" }
        end
        return p, pg
      end
    end
  end
  st.pageId = nil
end

local function choiceIndex(row)
  for i, c in ipairs(row.choices or {}) do
    if tostring(c[1] or c.value) == tostring(row.value) then return i end
  end
  return 1
end

local function choiceLabel(row)
  local c = (row.choices or {})[choiceIndex(row)]
  return c and tostring(c[2] or c.label or c[1]) or tostring(row.value or "")
end

local function hit(id, x, y, w, h) st.hits[#st.hits + 1] = { id = id, x = x, y = y, w = w, h = h } end

-- the top screen: the folder's banner is drawn by init.lua (appletBanner);
-- here the page's title and the picked row's explanation
function EPG.drawTop(r)
  if Credits.isOpen() then Credits.drawTop(r) return end
  local p, pg = EPG.active()
  if not p then return end
  lg.push("all")
  lg.setScissor(r.x, r.y, r.w, r.h)
  for y = 0, r.h, 2 do
    local k = y / r.h
    lg.setColor(0.95 - 0.04 * k, 0.96 - 0.03 * k, 0.99, 1)
    lg.rectangle("fill", r.x, r.y + y, r.w, 2)
  end
  local pad = r.h * 0.07
  local icon = ctx.icon and ctx.icon(p.id)
  local s = r.h * 0.34
  if icon then
    lg.setColor(1, 1, 1, 1)
    lg.draw(icon, r.x + pad, r.y + pad, 0, s / icon:getWidth(), s / icon:getHeight())
  end
  local tx = r.x + pad * 2 + s
  local tf = ctx.font(r.h * 0.1)
  lg.setFont(tf)
  lg.setColor(0.18, 0.2, 0.26, 1)
  lg.printf(pg.title or "", tx, r.y + pad, r.x + r.w - tx - pad, "left")
  local sf = ctx.font(r.h * 0.06)
  lg.setFont(sf)
  lg.setColor(0.42, 0.45, 0.52, 1)
  lg.printf(p.folder and p.folder.name or p.id, tx, r.y + pad + tf:getHeight() * 1.2, r.x + r.w - tx - pad, "left")
  local row = pg.rows[st.sel]
  if row then
    local f = ctx.font(r.h * 0.07)
    lg.setFont(f)
    lg.setColor(0.2, 0.22, 0.28, 1)
    local text = row.label or ""
    if row.sub and row.sub ~= "" then text = text .. "\n" .. row.sub end
    if row.choices then text = text .. "\n\nNow: " .. choiceLabel(row) end
    lg.printf(text, r.x + pad * 1.5, r.y + pad * 2 + s, r.w - pad * 3, "left")
  end
  lg.pop()
end

local function drawText(r)
  local t = st.text
  local f = ctx.font(r.h * 0.075)
  lg.setFont(f)
  lg.setColor(0.2, 0.22, 0.28, 1)
  lg.printf(t.label, r.x, r.y + r.h * 0.18, r.w, "center")
  local bx, by, bw, bh = r.x + r.w * 0.08, r.y + r.h * 0.34, r.w * 0.84, r.h * 0.14
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", bx, by, bw, bh, bh * 0.2, bh * 0.2)
  lg.setColor(0.2, 0.55, 0.95, 1)
  lg.setLineWidth(2)
  lg.rectangle("line", bx, by, bw, bh, bh * 0.2, bh * 0.2)
  local vf = ctx.font(bh * 0.5)
  lg.setFont(vf)
  lg.setColor(0.15, 0.15, 0.18, 1)
  local caret = (love.timer.getTime() % 1 < 0.5) and "|" or ""
  lg.printf(t.value .. caret, bx + bh * 0.2, by + (bh - vf:getHeight()) / 2, bw - bh * 0.4, "left")
  local hf = ctx.font(r.h * 0.05)
  lg.setFont(hf)
  lg.setColor(0.45, 0.46, 0.5, 1)
  lg.printf(("%d / %d"):format(#t.value, t.max), bx, by + bh + 4, bw, "right")
  local w, h = r.w * 0.3, r.h * 0.12
  for i, b in ipairs({ { "text:cancel", "Cancel" }, { "text:ok", "OK" } }) do
    local x = r.x + r.w * (i == 1 and 0.15 or 0.55)
    local y = r.y + r.h * 0.62
    if i == 2 then lg.setColor(0.2, 0.55, 0.95, 1) else lg.setColor(1, 1, 1, 1) end
    lg.rectangle("fill", x, y, w, h, h * 0.3, h * 0.3)
    local bf = ctx.font(h * 0.42)
    lg.setFont(bf)
    if i == 2 then lg.setColor(1, 1, 1, 1) else lg.setColor(0.25, 0.26, 0.3, 1) end
    lg.printf(b[2], x, y + (h - bf:getHeight()) / 2, w, "center")
    hit(b[1], x, y, w, h)
  end
end

function EPG.drawBottom(r)
  st.hits = {}
  if Credits.isOpen() then Credits.drawBottom(r) return end
  local p, pg = EPG.active()
  if not p then return end
  lg.push("all")
  lg.setScissor(r.x, r.y, r.w, r.h)
  lg.setColor(0.96, 0.97, 0.98, 1)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  if st.text then drawText(r) lg.pop() return end
  -- the bar: Back and the title
  local bh = math.floor(r.h * 0.13)
  lg.setColor(0.86, 0.88, 0.92, 1)
  lg.rectangle("fill", r.x, r.y, r.w, bh)
  local bw = r.w * 0.2
  lg.setColor(0.2, 0.55, 0.95, 1)
  lg.rectangle("fill", r.x + 6, r.y + bh * 0.15, bw, bh * 0.7, bh * 0.2, bh * 0.2)
  local bf = ctx.font(bh * 0.34)
  lg.setFont(bf)
  lg.setColor(1, 1, 1, 1)
  lg.printf("Back", r.x + 6, r.y + (bh - bf:getHeight()) / 2, bw, "center")
  hit("back", r.x, r.y, bw + 12, bh)
  lg.setColor(0.2, 0.22, 0.28, 1)
  lg.printf(pg.title or "", r.x + bw + 12, r.y + (bh - bf:getHeight()) / 2, r.w - bw * 2 - 24, "center")
  -- the rows
  local top = r.y + bh + 4
  local rh = math.floor(r.h * 0.15)
  st.rowH = rh
  local viewH = r.y + r.h - top
  st.maxScroll = math.max(0, #pg.rows * rh - viewH)
  st.scroll = math.max(0, math.min(st.maxScroll, st.scroll))
  lg.setScissor(r.x, top, r.w, viewH)
  local lf = ctx.font(rh * 0.3)
  local sf = ctx.font(rh * 0.22)
  for i, row in ipairs(pg.rows) do
    local y = top + (i - 1) * rh - st.scroll
    if y + rh > top and y < r.y + r.h then
      local on = i == st.sel
      if on then lg.setColor(0.86, 0.93, 1, 1) else lg.setColor(1, 1, 1, 1) end
      lg.rectangle("fill", r.x + 4, y + 2, r.w - 8, rh - 4, 6, 6)
      if on then
        lg.setColor(0.2, 0.55, 0.95, 1)
        lg.setLineWidth(2)
        lg.rectangle("line", r.x + 4, y + 2, r.w - 8, rh - 4, 6, 6)
      end
      local lx = r.x + 14
      lg.setFont(lf)
      if row.info then lg.setColor(0.45, 0.46, 0.5, 1) else lg.setColor(0.18, 0.2, 0.26, 1) end
      local valueW = (row.choices or row.text) and r.w * 0.36 or 0
      local ly = y + (rh - lf:getHeight()) / 2
      if row.sub and row.sub ~= "" and not row.info then ly = y + rh * 0.12 end
      lg.printf(row.label or "", lx, ly, r.w - valueW - 28, "left")
      if row.sub and row.sub ~= "" and not row.info then
        lg.setFont(sf)
        lg.setColor(0.45, 0.46, 0.5, 1)
        lg.printf(row.sub, lx, y + rh * 0.52, r.w - valueW - 28, "left")
      end
      if row.choices then
        -- < value >
        local vx = r.x + r.w - valueW - 10
        lg.setFont(lf)
        lg.setColor(0.2, 0.55, 0.95, 1)
        lg.printf("<", vx, y + (rh - lf:getHeight()) / 2, rh * 0.5, "center")
        lg.printf(">", vx + valueW - rh * 0.5, y + (rh - lf:getHeight()) / 2, rh * 0.5, "center")
        lg.setColor(0.18, 0.2, 0.26, 1)
        lg.printf(choiceLabel(row), vx + rh * 0.5, y + (rh - lf:getHeight()) / 2, valueW - rh, "center")
        hit("prev:" .. i, vx - 6, y, valueW * 0.35 + 6, rh)
        hit("next:" .. i, vx + valueW * 0.65, y, valueW * 0.35 + 10, rh)
      elseif row.text then
        local vx = r.x + r.w - valueW - 10
        lg.setFont(lf)
        lg.setColor(0.18, 0.2, 0.26, 1)
        lg.printf(tostring(row.value or ""), vx, y + (rh - lf:getHeight()) / 2, valueW, "right")
      elseif row.action then
        lg.setFont(lf)
        lg.setColor(0.2, 0.55, 0.95, 1)
        lg.printf(">", r.x + r.w - 30, y + (rh - lf:getHeight()) / 2, 16, "center")
      end
    end
    hit("row:" .. i, r.x, math.max(top, y), r.w, rh)
  end
  lg.pop()
end

---------------------------------------------------------------- input

local function setChoice(p, row, dir)
  local n = #(row.choices or {})
  if n == 0 or not p.setSetting then return end
  local i = (choiceIndex(row) - 1 + dir) % n + 1
  local c = row.choices[i]
  pcall(p.setSetting, row.key, tostring(c[1] or c.value))
  Sfx.play("select")
end

local function startText(row)
  st.text = { key = row.key, label = row.label or "", value = tostring(row.value or ""), max = row.text or 32 }
  if love.keyboard and love.keyboard.setTextInput then pcall(love.keyboard.setTextInput, true) end
  Sfx.play("open")
end

local function endText(p, keep)
  local t = st.text
  st.text = nil
  if love.keyboard and love.keyboard.setTextInput then pcall(love.keyboard.setTextInput, false) end
  if keep and t and p.setSetting then pcall(p.setSetting, t.key, t.value); Sfx.play("select")
  else Sfx.play("back") end
end

local function activateRow(p, pg, i)
  local row = pg.rows[i]
  if not row then return end
  st.sel = i
  if row.credits then Credits.open(); Sfx.play("open")
  elseif row.choices then setChoice(p, row, 1)
  elseif row.text then startText(row)
  elseif row.action and p.act then
    Sfx.play("open")
    pcall(p.act, row.action)
  end
end

local function close(p)
  if p.closePage then pcall(p.closePage) end
  st.text = nil
  Sfx.play("back")
end

local function activate(p, pg, id)
  if id == "back" then close(p) return end
  if id == "text:ok" then endText(p, true) return end
  if id == "text:cancel" then endText(p, false) return end
  local kind, n = id:match("^(%a+):(%d+)$")
  n = tonumber(n)
  if kind == "row" then
    if n == st.sel or not pg.rows[n].choices then activateRow(p, pg, n)
    else st.sel = n; Sfx.play("over") end
  elseif kind == "prev" or kind == "next" then
    st.sel = n
    setChoice(p, pg.rows[n], kind == "next" and 1 or -1)
  end
end

local function hitAt(x, y)
  -- the arrows first (they sit over their row)
  for k = #st.hits, 1, -1 do
    local h = st.hits[k]
    if not h.id:match("^row:") and x >= h.x and y >= h.y and x <= h.x + h.w and y <= h.y + h.h then return h end
  end
  for k = #st.hits, 1, -1 do
    local h = st.hits[k]
    if x >= h.x and y >= h.y and x <= h.x + h.w and y <= h.y + h.h then return h end
  end
end

function EPG.pressed(id, x, y)
  if Credits.isOpen() then Credits.pressed(id, x, y) return end
  local h = hitAt(x, y)
  st.touches[id] = { hit = h and h.id, y0 = y, y = y, scroll = st.scroll, moved = false }
end

function EPG.moved(id, x, y)
  if Credits.isOpen() then Credits.moved(id, x, y) return end
  local t = st.touches[id]
  if not t then return end
  if math.abs(y - t.y0) > 8 then t.moved = true end
  if t.moved then st.scroll = math.max(0, math.min(st.maxScroll, t.scroll - (y - t.y0))) end
end

function EPG.released(id, x, y)
  if Credits.isOpen() then
    if Credits.released(id, x, y) == "exit" then Sfx.play("back") end
    return
  end
  local t = st.touches[id]
  st.touches[id] = nil
  local p, pg = EPG.active()
  if not (t and p) or t.moved then return end
  local h = hitAt(x, y)
  if h and h.id == t.hit then activate(p, pg, h.id) end
end

function EPG.button(btn)
  if Credits.isOpen() then
    if Credits.button(btn) == "exit" then Sfx.play("back") end
    return true
  end
  local p, pg = EPG.active()
  if not p then return false end
  if st.text then
    if btn == "a" then endText(p, true) elseif btn == "b" then endText(p, false) end
    return true
  end
  local n = #pg.rows
  if btn == "b" or btn == "home" then close(p)
  elseif btn == "up" then st.sel = math.max(1, st.sel - 1); Sfx.play("over")
  elseif btn == "down" then st.sel = math.min(n, st.sel + 1); Sfx.play("over")
  elseif btn == "left" or btn == "right" then
    local row = pg.rows[st.sel]
    if row and row.choices then setChoice(p, row, btn == "right" and 1 or -1) end
  elseif btn == "a" then activateRow(p, pg, st.sel) end
  -- keep the picked row in view
  local rh = st.rowH or 0
  if rh > 0 then st.scroll = math.max(0, math.min(st.maxScroll, (st.sel - 3) * rh)) end
  return true
end

function EPG.textinput(t)
  if not st.text then return false end
  if #st.text.value < st.text.max then st.text.value = st.text.value .. t end
  return true
end

function EPG.keypressed(key)
  if not st.text then return false end
  local p = EPG.active()
  if key == "backspace" then
    local ok, utf8 = pcall(require, "utf8")
    local v = st.text.value
    local off = ok and utf8.offset(v, -1)
    st.text.value = off and v:sub(1, off - 1) or v:sub(1, -2)
  elseif key == "return" or key == "kpenter" then if p then endText(p, true) end
  elseif key == "escape" then if p then endText(p, false) end end
  return true
end

function EPG.init(context) ctx = context end

return EPG
