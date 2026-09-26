-- The Nintendo Switch HOME menu, the other HOME menu the app can show
-- (the Switch HOME Menu applet on the 3DS HOME menu turns it on; its own
-- 3DS HOME Menu button and System Settings > HOME Menu turn it off).
--
-- It fills the whole inner screen, as the Switch's one screen, laid out
-- as the Switch lays out its 1280 x 720 HOME menu:
--
--   * across the top, the user's icon on the left (Play Activity) and the
--     clock, Wi-Fi and battery on the right;
--   * the software: one row of big square icons that slides sideways, the
--     selected one framed in the theme's blue with its name above it;
--   * the round buttons under it -- Nintendo eShop, Album, 3DS HOME Menu,
--     System Settings -- the selected one's name under it;
--   * a rule, then the handheld glyph on the left and the button guide on
--     the right.
--
-- Basic White and Basic Black, as System Settings > Themes offers.  The +
-- Pad / Circle Pad move (the row, the buttons), A starts or opens, X or +
-- shows a recomp game's manual.  Tap to select, tap again to start; drag the
-- software row to slide it.  System Settings is the Switch's own: the
-- categories down the left, their options on the right.
--
-- Kept in fold3ds_ui.cfg: which HOME menu is up and the theme.
local X = {}

local lg = love.graphics
local Pads = require("fold3ds.pads")

local CFG = "fold3ds_ui.cfg"
local REF_W, REF_H = 1280, 720

local THEMES = {
  white = { bg = { 235, 235, 235 }, text = { 45, 45, 45 }, dim = { 110, 110, 110 }, rule = { 205, 205, 205 },
            circle = { 255, 255, 255 }, accent = { 0, 170, 225 }, panel = { 244, 244, 244 },
            tile = { 220, 220, 222 }, shadow = { 0, 0, 0, 0.12 } },
  black = { bg = { 45, 45, 45 }, text = { 255, 255, 255 }, dim = { 170, 170, 170 }, rule = { 90, 90, 90 },
            circle = { 70, 70, 70 }, accent = { 0, 215, 225 }, panel = { 54, 54, 54 },
            tile = { 64, 64, 66 }, shadow = { 0, 0, 0, 0.3 } },
}

-- the round buttons under the software
local BUTTONS = {
  { id = "eshop", name = "Nintendo eShop", color = { 245, 120, 0 } },
  { id = "album", name = "Album", color = { 30, 140, 240 } },
  { id = "to3ds", name = "3DS HOME Menu", color = { 206, 32, 40 } },
  { id = "settings", name = "System Settings", color = { 120, 120, 128 } },
}

local SETTINGS = {
  { id = "themes", name = "Themes" },
  { id = "home", name = "HOME Menu" },
  { id = "controllers", name = "Controllers" },
  { id = "more", name = "Other Settings" },
  { id = "credits", name = "Credits" },
}

local ctx
local st = {
  on = false, theme = "white", loaded = false,
  row = "games",        -- "games" or "buttons" (the + Pad's row)
  sel = 1, bsel = 1,
  scroll = 0, target = 0, -- the software row's slide (reference px)
  settings = nil,       -- { cat, opt, focus = "cats" | "opts" } while open
  hits = {}, touches = {},
  frame = nil,          -- the reference frame on screen { x, y, s }
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function col(c, a) lg.setColor(c[1] / 255, c[2] / 255, c[3] / 255, a or c[4] or 1) end
local function theme() return THEMES[st.theme] or THEMES.white end

---------------------------------------------------------------- persistence

local function load()
  st.loaded = true
  local ok, text = pcall(love.filesystem.read, CFG)
  text = ok and type(text) == "string" and text or ""
  st.on = text:match("ui=switch") ~= nil
  local t = text:match("theme=(%a+)")
  if t and THEMES[t] then st.theme = t end
end

local function save()
  pcall(love.filesystem.write, CFG, ("ui=%s\ntheme=%s\n"):format(st.on and "switch" or "3ds", st.theme))
end

function X.init(context) ctx = context; load() end
function X.active() if not st.loaded then load() end return st.on end
function X.enable()
  st.on, st.row, st.settings = true, "games", nil
  st.touches = {}
  save()
end
function X.disable()
  st.on, st.settings = false, nil
  st.touches = {}
  save()
end

---------------------------------------------------------------- the software

-- The older systems' games go into one app each, the way Nintendo Switch
-- Online gathers them: Game Boy, Game Boy Color, Game Boy Advance -- and
-- the DS and the 3DS the same way.  Opening one shows its game picker.
local NSO = {
  { sys = "gb", name = "Game Boy", tag = "GAME BOY", color = { 150, 160, 40 }, dark = { 40, 52, 30 } },
  { sys = "gbc", name = "Game Boy Color", tag = "GAME BOY COLOR", color = { 120, 70, 200 }, dark = { 34, 22, 60 } },
  { sys = "gba", name = "Game Boy Advance", tag = "GAME BOY ADVANCE", color = { 72, 58, 170 }, dark = { 24, 20, 58 } },
  { sys = "nds", name = "Nintendo DS", tag = "NINTENDO DS", color = { 150, 152, 160 }, dark = { 36, 38, 44 } },
  { sys = "3ds", name = "Nintendo 3DS", tag = "NINTENDO 3DS", color = { 206, 32, 40 }, dark = { 52, 14, 18 } },
}
local NSO_BY = {}
for _, a in ipairs(NSO) do NSO_BY[a.sys] = a end
local Emus = require("fold3ds.emus")
local Sfx = require("fold3ds.sfx")
local Credits = require("fold3ds.credits")

local function sysOf(t)
  if t.system then return t.system end
  local p = Emus.owner(t)
  if p and p.id == "azahar" then return "3ds" end
  return nil
end

local function games(imp)
  local out, apps = {}, {}
  for _, t in ipairs(ctx.tiles(imp) or {}) do
    if t.game or t.emuGame then
      local sys = t.emuGame and sysOf(t)
      local a = sys and NSO_BY[sys]
      if a then
        if not apps[sys] then
          apps[sys] = { id = "nso_" .. sys, nso = a, name = a.name .. " - Nintendo Switch Online", list = {} }
          out[#out + 1] = apps[sys]
        end
        table.insert(apps[sys].list, t)
      else
        out[#out + 1] = t
      end
    end
  end
  return out
end

-- an NSO app's icon: the system's colour, its console, its name, the
-- red Nintendo Switch Online band
local function drawNsoIcon(a, x, y, sz)
  col(a.color)
  lg.rectangle("fill", x, y, sz, sz)
  lg.setColor(1, 1, 1, 0.14)
  lg.rectangle("fill", x, y, sz, sz * 0.45)
  -- the console
  local cw, ch = sz * 0.34, sz * 0.46
  local cx, cy = x + sz / 2, y + sz * 0.4
  lg.setColor(1, 1, 1, 0.95)
  if a.sys == "gba" then
    lg.rectangle("fill", cx - ch * 0.62, cy - cw * 0.34, ch * 1.24, cw * 0.68, sz * 0.05, sz * 0.05)
    col(a.dark)
    lg.rectangle("fill", cx - cw * 0.34, cy - cw * 0.22, cw * 0.68, cw * 0.44)
  elseif a.sys == "nds" or a.sys == "3ds" then
    lg.rectangle("fill", cx - cw * 0.62, cy - ch * 0.5, cw * 1.24, ch * 0.46, sz * 0.02, sz * 0.02)
    lg.rectangle("fill", cx - cw * 0.62, cy + ch * 0.02, cw * 1.24, ch * 0.46, sz * 0.02, sz * 0.02)
    col(a.dark)
    lg.rectangle("fill", cx - cw * 0.44, cy - ch * 0.44, cw * 0.88, ch * 0.34)
    lg.rectangle("fill", cx - cw * 0.3, cy + ch * 0.08, cw * 0.6, ch * 0.32)
  else
    lg.rectangle("fill", cx - cw / 2, cy - ch / 2, cw, ch, sz * 0.02, sz * 0.02)
    col(a.dark)
    lg.rectangle("fill", cx - cw * 0.36, cy - ch * 0.4, cw * 0.72, ch * 0.42)
  end
  local f = ctx.font(sz * 0.07)
  lg.setFont(f)
  lg.setColor(1, 1, 1, 1)
  lg.printf(a.tag, x, y + sz * 0.7, sz, "center")
  lg.setColor(0.9, 0.0, 0.07, 1)
  lg.rectangle("fill", x, y + sz * 0.84, sz, sz * 0.16)
  local f2 = ctx.font(sz * 0.055)
  lg.setFont(f2)
  lg.setColor(1, 1, 1, 1)
  lg.printf("Nintendo Switch Online", x, y + sz * 0.84 + (sz * 0.16 - f2:getHeight()) / 2, sz, "center")
end

-- reference geometry of the software row
local TILE, GAP, ROW_X = 256, 14, 118

local function follow(n)
  -- keep the selected tile inside the screen, as the Switch slides its row
  local x = ROW_X + (st.sel - 1) * (TILE + GAP) - st.target
  if x < ROW_X then st.target = st.target - (ROW_X - x) end
  if x + TILE > REF_W - ROW_X then st.target = st.target + (x + TILE - (REF_W - ROW_X)) end
  local max = math.max(0, n * (TILE + GAP) - GAP - (REF_W - ROW_X * 2))
  st.target = clamp(st.target, 0, max)
end

---------------------------------------------------------------- glyphs

local function battery(x, y, w, h, c)
  col(c)
  lg.setLineWidth(math.max(1, h * 0.12))
  lg.rectangle("line", x, y, w, h, h * 0.18, h * 0.18)
  lg.rectangle("fill", x + w, y + h * 0.3, h * 0.14, h * 0.4)
  local lvl = 1
  if love.system and love.system.getPowerInfo then
    local _, pct = love.system.getPowerInfo()
    if pct then lvl = clamp(pct / 100, 0.05, 1) end
  end
  lg.rectangle("fill", x + h * 0.18, y + h * 0.18, (w - h * 0.36) * lvl, h - h * 0.36)
end

local function wifi(cx, by, s, c)
  col(c)
  lg.setLineWidth(math.max(1.5, s * 0.12))
  for i = 1, 3 do
    lg.arc("line", "open", cx, by, s * 0.3 * i, -math.pi * 0.75, -math.pi * 0.25)
  end
  lg.circle("fill", cx, by - s * 0.05, s * 0.1)
end

-- the Switch's two Joy-Con, side by side (the applet's icon too)
function X.drawLogo(x, y, s)
  local w, h = s * 0.3, s * 0.78
  local top = y + (s - h) / 2
  local r = w * 0.5
  lg.setColor(0.9, 0.0, 0.07, 1)
  lg.rectangle("fill", x, y, s, s, s * 0.2, s * 0.2)
  local lx, rx = x + s * 0.17, x + s * 0.53
  lg.setColor(1, 1, 1, 1)
  lg.setLineWidth(math.max(1.5, s * 0.06))
  lg.rectangle("line", lx, top, w, h, r, r)
  lg.rectangle("fill", rx, top, w, h, r, r)
  lg.circle("fill", lx + w / 2, top + h * 0.3, w * 0.2)
  lg.setColor(0.9, 0.0, 0.07, 1)
  lg.circle("fill", rx + w / 2, top + h * 0.62, w * 0.2)
end

local function glyph(id, cx, cy, s, c, hole)
  col(c)
  lg.setLineWidth(math.max(1.5, s * 0.08))
  if id == "eshop" then
    -- a shopping bag
    lg.rectangle("fill", cx - s * 0.38, cy - s * 0.18, s * 0.76, s * 0.6, s * 0.08, s * 0.08)
    lg.arc("line", "open", cx, cy - s * 0.18, s * 0.2, math.pi, math.pi * 2)
  elseif id == "album" then
    -- a picture: frame, sun, hills
    lg.rectangle("line", cx - s * 0.42, cy - s * 0.32, s * 0.84, s * 0.64, s * 0.06, s * 0.06)
    lg.circle("fill", cx + s * 0.18, cy - s * 0.1, s * 0.09)
    lg.polygon("fill", cx - s * 0.36, cy + s * 0.26, cx - s * 0.1, cy - s * 0.04, cx + s * 0.14, cy + s * 0.26)
  elseif id == "to3ds" then
    -- a 3DS, open: the two screens
    lg.rectangle("line", cx - s * 0.34, cy - s * 0.44, s * 0.68, s * 0.4, s * 0.06, s * 0.06)
    lg.rectangle("line", cx - s * 0.34, cy + s * 0.04, s * 0.68, s * 0.4, s * 0.06, s * 0.06)
    lg.rectangle("fill", cx - s * 0.2, cy - s * 0.34, s * 0.4, s * 0.2)
    lg.rectangle("fill", cx - s * 0.16, cy + s * 0.13, s * 0.32, s * 0.22)
  elseif id == "settings" then
    -- a gear
    for i = 0, 7 do
      local a = i * math.pi / 4
      lg.push()
      lg.translate(cx, cy)
      lg.rotate(a)
      lg.rectangle("fill", -s * 0.08, -s * 0.44, s * 0.16, s * 0.2)
      lg.pop()
    end
    lg.circle("fill", cx, cy, s * 0.3)
    col(hole or theme().circle)
    lg.circle("fill", cx, cy, s * 0.12)
  end
end

-- a button guide entry: the round button with its letter, then the words
local function guide(xr, cy, letter, words, s, T)
  local f = ctx.font(20 * s)
  lg.setFont(f)
  local tw = f:getWidth(words)
  local x = xr - tw
  col(T.text)
  lg.print(words, x, cy - f:getHeight() / 2)
  local r = 13 * s
  local bx = x - r - 8 * s
  col(T.text)
  lg.circle("fill", bx, cy, r)
  col(T.bg)
  local lf = ctx.font(17 * s)
  lg.setFont(lf)
  lg.printf(letter, bx - r, cy - lf:getHeight() / 2, r * 2, "center")
  return bx - r - 28 * s
end

---------------------------------------------------------------- drawing

local function hit(id, x, y, w, h, data) st.hits[#st.hits + 1] = { id = id, x = x, y = y, w = w, h = h, data = data } end

local function drawTopBar(F, T, imp, now)
  local s = F.s
  -- the user: a round icon (Play Activity)
  local ux, uy, ur = F.x + 58 * s + 28 * s, F.top + 62 * s, 28 * s
  col(T.shadow)
  lg.circle("fill", ux, uy + 2 * s, ur + 2 * s)
  col({ 255, 190, 40 })
  lg.circle("fill", ux, uy, ur)
  lg.setColor(1, 1, 1, 1)
  lg.circle("fill", ux, uy - ur * 0.2, ur * 0.34)
  lg.arc("fill", ux, uy + ur * 0.75, ur * 0.6, math.pi, math.pi * 2)
  hit("user", ux - ur, uy - ur, ur * 2, ur * 2)
  -- the clock, Wi-Fi, battery
  local f = ctx.font(24 * s)
  lg.setFont(f)
  local clock = os.date("%H:%M")
  local bx = F.x + F.w - 58 * s - 44 * s
  battery(bx, uy - 10 * s, 38 * s, 20 * s, T.text)
  wifi(bx - 32 * s, uy + 10 * s, 26 * s, T.text)
  col(T.text)
  lg.print(clock, bx - 62 * s - f:getWidth(clock), uy - f:getHeight() / 2)
end

local function drawSoftware(F, T, imp, now, list)
  local s = F.s
  local ty = F.mid - 150 * s
  st.scroll = st.scroll + (st.target - st.scroll) * math.min(1, (st.dt or 0.016) * 14)
  if math.abs(st.target - st.scroll) < 0.3 then st.scroll = st.target end
  local pulse = 0.5 + 0.5 * math.sin(now * 4)
  for i, t in ipairs(list) do
    local x = F.x + (ROW_X + (i - 1) * (TILE + GAP) - st.scroll) * s
    local y = ty
    local sz = TILE * s
    if x + sz > F.x - sz and x < F.x + F.w + sz then
      local on = i == st.sel and st.row == "games"
      col(T.shadow)
      lg.rectangle("fill", x, y + 3 * s, sz, sz)
      col(T.tile)
      lg.rectangle("fill", x, y, sz, sz)
      -- the software's icon, square and edge to edge
      lg.push("all")
      local sx, sy, sw, sh = math.floor(x), math.floor(y), math.ceil(sz), math.ceil(sz)
      lg.intersectScissor(sx, sy, sw, sh)
      if t.nso then
        drawNsoIcon(t.nso, x, y, sz)
      elseif not (ctx.drawIcon and ctx.drawIcon(imp, t.id, x, y, sz)) then
        col(T.dim)
        local f = ctx.font(sz * 0.4)
        lg.setFont(f)
        lg.printf((t.name or "?"):sub(1, 1), x, y + (sz - f:getHeight()) / 2, sz, "center")
      end
      lg.pop()
      if on then
        -- the selection: the theme's blue frame, breathing, and the name above
        local c = T.accent
        lg.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 0.75 + 0.25 * pulse)
        lg.setLineWidth(5 * s)
        lg.rectangle("line", x - 6 * s, y - 6 * s, sz + 12 * s, sz + 12 * s, 4 * s, 4 * s)
        local nf = ctx.font(24 * s)
        lg.setFont(nf)
        col(c)
        lg.print(t.name or "", x, y - 14 * s - nf:getHeight())
      end
      hit("game", x, y, sz, sz, i)
    end
  end
  if #list == 0 then
    local f = ctx.font(24 * s)
    lg.setFont(f)
    col(T.dim)
    lg.printf("No software.  Open the 3DS HOME Menu to add games.", F.x, ty + TILE * s / 2, F.w, "center")
  end
  return ty + TILE * s
end

---------------------------------------------------------------- the NSO game picker
-- The app open: its colours behind, its name across the top, the games'
-- covers in a row (the picked one bigger, lit, its title and system under
-- it), A to play, B back to the HOME menu.

local CARD_W, CARD_H, CARD_GAP = 220, 300, 26

local function coverOf(t)
  local p = Emus.owner(t)
  local img
  if p and p.boxArt then local ok, i = pcall(p.boxArt, t); if ok then img = i end end
  if not img and p and p.cart then local ok, i = pcall(p.cart, t); if ok then img = i end end
  if not img then img = Emus.icon(t) end
  return type(img) == "userdata" and img or nil
end

local function drawPicker(F, T, now)
  local P = st.nso
  local a = P.app.nso
  local s = F.s
  -- the app's colours, top to bottom
  for i = 0, 23 do
    local k = i / 23
    lg.setColor((a.color[1] * (1 - k) + a.dark[1] * k) / 255, (a.color[2] * (1 - k) + a.dark[2] * k) / 255,
      (a.color[3] * (1 - k) + a.dark[3] * k) / 255, 1)
    lg.rectangle("fill", F.x - 2000, F.top + (F.bottom - F.top) * i / 24, F.w + 4000, (F.bottom - F.top) / 24 + 1)
  end
  -- the header: the system and Nintendo Switch Online
  local hf = ctx.font(40 * s)
  lg.setFont(hf)
  lg.setColor(1, 1, 1, 1)
  lg.print(a.name, F.x + 70 * s, F.top + 40 * s)
  local sf = ctx.font(20 * s)
  lg.setFont(sf)
  lg.setColor(1, 1, 1, 0.8)
  lg.print("Nintendo Switch Online", F.x + 72 * s, F.top + 40 * s + hf:getHeight())
  -- the covers
  local list = P.app.list
  P.sel = clamp(P.sel, 1, #list)
  local want = (P.sel - 1) * (CARD_W + CARD_GAP)
  P.scroll = P.scroll + (want - P.scroll) * math.min(1, (st.dt or 0.016) * 10)
  local cy = F.mid - 30 * s
  for i, t in ipairs(list) do
    local on = i == P.sel
    local pick = (P.pickAt and on) and clamp((love.timer.getTime() - P.pickAt) / 0.2, 0, 1) or 1
    local sc = (on and (1.18 + 0.04 * math.sin(pick * math.pi)) or 0.92) * s
    local cw, ch = CARD_W * sc, CARD_H * sc
    local x = F.x + F.w / 2 + ((i - 1) * (CARD_W + CARD_GAP) - P.scroll) * s - cw / 2
    local y = cy - ch / 2
    if x + cw > F.x - 200 * s and x < F.x + F.w + 200 * s then
      lg.setColor(0, 0, 0, on and 0.35 or 0.2)
      lg.rectangle("fill", x + 6 * s, y + 10 * s, cw, ch, 8 * s, 8 * s)
      lg.setColor(1, 1, 1, 1)
      lg.rectangle("fill", x, y, cw, ch, 8 * s, 8 * s)
      local img = coverOf(t)
      if img then
        lg.push("all")
        lg.intersectScissor(math.floor(x + 6 * s), math.floor(y + 6 * s), math.ceil(cw - 12 * s), math.ceil(ch - 12 * s))
        local iw, ih = img:getDimensions()
        local k = math.max((cw - 12 * s) / iw, (ch - 12 * s) / ih)
        lg.setColor(1, 1, 1, on and 1 or 0.8)
        lg.draw(img, x + cw / 2 - iw * k / 2, y + ch / 2 - ih * k / 2, 0, k, k)
        lg.pop()
      else
        col(a.color, on and 1 or 0.8)
        lg.rectangle("fill", x + 6 * s, y + 6 * s, cw - 12 * s, ch - 12 * s, 6 * s, 6 * s)
        local f = ctx.font(26 * sc)
        lg.setFont(f)
        lg.setColor(1, 1, 1, 1)
        lg.printf(t.name or "", x + 16 * s, y + ch * 0.4, cw - 32 * s, "center")
      end
      if on then
        local pulse = 0.6 + 0.4 * math.abs(math.sin(now * 3))
        lg.setColor(1, 1, 1, pulse)
        lg.setLineWidth(5 * s)
        lg.rectangle("line", x - 6 * s, y - 6 * s, cw + 12 * s, ch + 12 * s, 10 * s, 10 * s)
      end
      hit("nsogame", x, y, cw, ch, i)
    end
  end
  -- the picked game's title, and the guide
  local t = list[P.sel]
  if t then
    local tf = ctx.font(30 * s)
    lg.setFont(tf)
    lg.setColor(1, 1, 1, 1)
    lg.printf(t.name or "", F.x, cy + CARD_H * 0.62 * s + 20 * s, F.w, "center")
    lg.setFont(sf)
    lg.setColor(1, 1, 1, 0.75)
    lg.printf(t.sub or a.name, F.x, cy + CARD_H * 0.62 * s + 24 * s + tf:getHeight(), F.w, "center")
  end
  -- a launch: the picked cover swells and the screen goes white
  if P.launch then
    local k = clamp((love.timer.getTime() - P.launch) / 0.45, 0, 1)
    lg.setColor(1, 1, 1, k)
    lg.rectangle("fill", F.x - 2000, F.top, F.w + 4000, F.bottom - F.top)
  end
end

local function drawButtons(F, T, now, y0)
  local s = F.s
  local d = 72 * s
  local gap = 30 * s
  local total = #BUTTONS * d + (#BUTTONS - 1) * gap
  local x = F.x + (F.w - total) / 2
  local cy = y0 + 70 * s + d / 2
  local pulse = 0.5 + 0.5 * math.sin(now * 4)
  for i, b in ipairs(BUTTONS) do
    local cx = x + d / 2
    local on = st.row == "buttons" and st.bsel == i
    col(T.shadow)
    lg.circle("fill", cx, cy + 2 * s, d / 2 + 1 * s)
    col(T.circle)
    lg.circle("fill", cx, cy, d / 2)
    glyph(b.id, cx, cy, d * 0.52, b.color)
    if on then
      local c = T.accent
      lg.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 0.75 + 0.25 * pulse)
      lg.setLineWidth(5 * s)
      lg.circle("line", cx, cy, d / 2 + 7 * s)
      local f = ctx.font(20 * s)
      lg.setFont(f)
      col(c)
      lg.printf(b.name, cx - 120 * s, cy + d / 2 + 14 * s, 240 * s, "center")
    end
    hit("button", cx - d / 2, cy - d / 2, d, d, i)
    x = x + d + gap
  end
end

local function drawBottomBar(F, T, imp, list)
  local s = F.s
  local ry = F.bottom - 72 * s
  col(T.rule)
  lg.rectangle("fill", F.x + 30 * s, ry, F.w - 60 * s, math.max(1, 1.5 * s))
  local cy = ry + 36 * s
  -- handheld mode: the console with both Joy-Con attached
  col(T.text)
  lg.setLineWidth(2 * s)
  local gx = F.x + 58 * s
  lg.rectangle("line", gx, cy - 12 * s, 52 * s, 24 * s, 10 * s, 10 * s)
  lg.rectangle("fill", gx + 12 * s, cy - 8 * s, 28 * s, 16 * s)
  local xr = F.x + F.w - 58 * s
  local on = st.settings and "settings" or st.row
  if on == "games" and list[st.sel] then
    xr = guide(xr, cy, "A", "Start", s, T)
    if list[st.sel].game and ctx.hasManual and ctx.hasManual(list[st.sel].id) then
      guide(xr, cy, "X", "Manual", s, T)
    end
  elseif on == "settings" then
    xr = guide(xr, cy, "A", "OK", s, T)
    guide(xr, cy, "B", "Back", s, T)
  else
    guide(xr, cy, "A", "OK", s, T)
  end
end

local function drawSettings(F, T)
  local s = F.s
  local S = st.settings
  -- the title bar: the gear and "System Settings", a rule under it
  glyph("settings", F.x + 80 * s, F.top + 52 * s, 40 * s, T.text, T.bg)
  local tf = ctx.font(28 * s)
  lg.setFont(tf)
  col(T.text)
  lg.print("System Settings", F.x + 118 * s, F.top + 52 * s - tf:getHeight() / 2)
  col(T.rule)
  lg.rectangle("fill", F.x + 30 * s, F.top + 88 * s, F.w - 60 * s, math.max(1, 1.5 * s))
  local top, bottom = F.top + 88 * s, F.bottom - 72 * s
  -- the categories down the left
  local lw = 410 * s
  local f = ctx.font(23 * s)
  lg.setFont(f)
  local rh = 70 * s
  for i, c in ipairs(SETTINGS) do
    local y = top + 24 * s + (i - 1) * rh
    local on = S.cat == i
    if on then
      col(S.focus == "cats" and T.panel or T.panel, 1)
      lg.rectangle("fill", F.x + 60 * s, y, lw - 60 * s, rh)
      col(T.accent)
      lg.rectangle("fill", F.x + 66 * s, y + 12 * s, 5 * s, rh - 24 * s)
    end
    col(on and T.accent or T.text)
    lg.print(c.name, F.x + 90 * s, y + (rh - f:getHeight()) / 2)
    hit("cat", F.x + 60 * s, y, lw - 60 * s, rh, i)
  end
  col(T.rule)
  lg.rectangle("fill", F.x + lw, top, math.max(1, 1.5 * s), bottom - top)
  -- the options on the right
  local ox, ow = F.x + lw + 50 * s, F.w - lw - 110 * s
  local cat = SETTINGS[S.cat].id
  local opts = {}
  if cat == "credits" then
    -- the card and the list fill the pane (fold3ds/credits.lua)
    if S.creditsFor ~= S.cat then S.creditsFor = S.cat; Credits.restart() end
    S.opts = {}
    Credits.drawPanel(ox, top + 24 * s, ow, bottom - top - 36 * s)
    return
  end
  S.creditsFor = nil
  if cat == "themes" then
    opts = { { id = "white", name = "Basic White", on = st.theme == "white" },
             { id = "black", name = "Basic Black", on = st.theme == "black" } }
  elseif cat == "home" then
    opts = { { id = "switch", name = "Nintendo Switch HOME Menu", on = true },
             { id = "3ds", name = "Nintendo 3DS HOME Menu", on = false } }
  elseif cat == "controllers" then
    local l = Pads.layoutSetting()
    opts = { { id = "pad_auto", name = "Button Layout: Automatic", on = l == "auto" },
             { id = "pad_nintendo", name = "Button Layout: Nintendo (A on the right)", on = l == "nintendo" },
             { id = "pad_xbox", name = "Button Layout: Xbox (A at the bottom)", on = l == "xbox" } }
  else
    opts = { { id = "more", name = "Open the app's settings" } }
  end
  S.opts = opts
  local y = top + 24 * s
  local hf = ctx.font(20 * s)
  for i, o in ipairs(opts) do
    local focused = S.focus == "opts" and S.opt == i
    col(T.panel)
    lg.rectangle("fill", ox, y, ow, rh)
    if focused then
      col(T.accent)
      lg.setLineWidth(4 * s)
      lg.rectangle("line", ox - 3 * s, y - 3 * s, ow + 6 * s, rh + 6 * s, 3 * s, 3 * s)
    end
    lg.setFont(f)
    col(T.text)
    lg.print(o.name, ox + 24 * s, y + (rh - f:getHeight()) / 2)
    if o.on ~= nil then
      lg.setFont(hf)
      col(o.on and T.accent or T.dim)
      local w = o.on and "Selected" or ""
      lg.print(w, ox + ow - 24 * s - hf:getWidth(w), y + (rh - hf:getHeight()) / 2)
    end
    hit("opt", ox, y, ow, rh, i)
    y = y + rh + 10 * s
  end
  if cat == "controllers" then
    lg.setFont(hf)
    col(T.dim)
    local pads = Pads.list()
    local lines = {}
    for _, pd in ipairs(pads) do
      lines[#lines + 1] = pd.name .. "  -  " .. (pd.layout == "nintendo" and "Nintendo layout" or "Xbox layout")
    end
    local text = #lines > 0 and ("Connected:\n" .. table.concat(lines, "\n"))
      or "No controllers connected.  Switch Pro Controllers, Joy-Con, the Razer Kishi and other pads are set up as they connect."
    lg.printf(text, ox, y + 10 * s, ow, "left")
  end
  if cat == "home" then
    lg.setFont(hf)
    col(T.dim)
    lg.printf("The 3DS HOME Menu has the Switch HOME Menu applet on its bar to come back.",
      ox, y + 10 * s, ow, "left")
  end
end

-- the whole screen, r = the window
function X.draw(r, imp, now)
  if not st.loaded then load() end
  local T = theme()
  st.dt = st.lastNow and math.min(0.1, math.max(0, now - st.lastNow)) or 0.016
  st.lastNow = now
  st.hits = {}
  lg.push("all")
  lg.setScissor(r.x, r.y, r.w, r.h)
  lg.setBackgroundColor(T.bg[1] / 255, T.bg[2] / 255, T.bg[3] / 255, 1)
  col(T.bg)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  -- the 1280 x 720 layout across the screen's width; on a taller screen
  -- the bars keep to the edges and the middle keeps to the middle
  local s = math.min(r.w / REF_W, r.h / (REF_H * 0.8))
  local w = REF_W * s
  local F = { s = s, x = r.x + (r.w - w) / 2, w = w, top = r.y, bottom = r.y + r.h, mid = r.y + r.h / 2 }
  st.frame = F
  local list = games(imp)
  st.count = #list
  st.sel = clamp(st.sel, 1, math.max(1, #list))
  if st.nso then
    drawPicker(F, T, now)
    -- its launch finishing: the game starts
    if st.nso.launch and love.timer.getTime() - st.nso.launch >= 0.45 then
      local t = st.nso.app.list[st.nso.sel]
      st.nso.launch = nil
      if t and ctx.start then ctx.start(imp, t) end
    end
  elseif st.settings then
    drawSettings(F, T)
  else
    drawTopBar(F, T, imp, now)
    local y0 = drawSoftware(F, T, imp, now, list)
    drawButtons(F, T, now, y0)
  end
  drawBottomBar(F, T, imp, list)
  lg.pop()
end

---------------------------------------------------------------- actions

local function start(imp, t)
  if not t then return end
  if t.nso then
    st.nso = { app = t, sel = 1, scroll = 0, pickAt = love.timer.getTime() }
    Sfx.play("open")
    return
  end
  if ctx.start then ctx.start(imp, t) end
end

local function nsoMove(d)
  local P = st.nso
  local n = #P.app.list
  local s2 = clamp(P.sel + d, 1, n)
  if s2 ~= P.sel then P.sel = s2; P.pickAt = love.timer.getTime(); Sfx.play("over")
  else Sfx.play("edge") end
end

local function nsoPlay()
  local P = st.nso
  if P.launch then return end
  P.launch = love.timer.getTime()
  Sfx.play("launch")
end

local function pressButton(imp, i)
  local b = BUTTONS[i]
  if not b then return end
  if b.id == "eshop" then if ctx.openEshop then ctx.openEshop() end
  elseif b.id == "album" then if ctx.openAlbum then ctx.openAlbum() end
  elseif b.id == "to3ds" then X.disable(); if ctx.to3ds then ctx.to3ds() end
  elseif b.id == "settings" then st.settings = { cat = 1, opt = 1, focus = "cats" } end
end

local function pickOption(imp, i)
  local S = st.settings
  local o = S and S.opts and S.opts[i]
  if not o then return end
  S.opt, S.focus = i, "opts"
  local cat = SETTINGS[S.cat].id
  if cat == "themes" then
    st.theme = o.id
    save()
  elseif cat == "home" and o.id == "3ds" then
    X.disable()
    if ctx.to3ds then ctx.to3ds() end
  elseif cat == "controllers" then
    Pads.setLayout(o.id:sub(5))
  elseif cat == "more" then
    st.settings = nil
    if ctx.openSettings then ctx.openSettings(imp) end
  end
end

local function manual(imp, t)
  if t and t.game and ctx.openManual then ctx.openManual(imp, t) end
end

---------------------------------------------------------------- input

function X.button(imp, name)
  local n = st.count or #games(imp)
  if name == "start" then name = "x" end
  if st.nso then
    if name == "b" or name == "home" then st.nso = nil; Sfx.play("back")
    elseif name == "left" or name == "up" then nsoMove(-1)
    elseif name == "right" or name == "down" then nsoMove(1)
    elseif name == "a" then nsoPlay() end
    return true
  end
  local S = st.settings
  if S then
    if name == "b" or name == "home" then
      if S.focus == "opts" then S.focus = "cats" else st.settings = nil end
    elseif (name == "up" or name == "down") and S.focus == "opts" and SETTINGS[S.cat].id == "credits" then
      Credits.button(name)
    elseif name == "up" or name == "down" then
      local d = name == "down" and 1 or -1
      if S.focus == "cats" then S.cat = clamp(S.cat + d, 1, #SETTINGS); S.opt = 1
      else S.opt = clamp(S.opt + d, 1, #(S.opts or { 1 })) end
    elseif name == "right" and S.focus == "cats" then S.focus, S.opt = "opts", 1
    elseif name == "left" and S.focus == "opts" then S.focus = "cats"
    elseif name == "a" then
      if S.focus == "cats" then S.focus, S.opt = "opts", 1 else pickOption(imp, S.opt) end
    end
    return true
  end
  if name == "home" then st.row, st.sel = "games", 1; st.target = 0 return true end
  if st.row == "games" then
    if name == "left" or name == "right" then
      st.sel = clamp(st.sel + (name == "right" and 1 or -1), 1, math.max(1, n))
      follow(n)
    elseif name == "down" then st.row = "buttons"
    elseif name == "a" then start(imp, games(imp)[st.sel])
    elseif name == "x" then manual(imp, games(imp)[st.sel]) end
  else
    if name == "left" or name == "right" then
      st.bsel = clamp(st.bsel + (name == "right" and 1 or -1), 1, #BUTTONS)
    elseif name == "up" then st.row = "games"
    elseif name == "a" then pressButton(imp, st.bsel) end
  end
  return true
end

local function hitAt(x, y)
  for k = #st.hits, 1, -1 do
    local h = st.hits[k]
    if x >= h.x and y >= h.y and x <= h.x + h.w and y <= h.y + h.h then return h end
  end
end

function X.pressed(imp, id, x, y)
  local h = hitAt(x, y)
  st.touches[id] = { x0 = x, y0 = y, hit = h, target0 = st.target, drag = false }
  return true
end

function X.moved(imp, id, x, y)
  local t = st.touches[id]
  if not t then return false end
  local s = st.frame and st.frame.s or 1
  if not t.drag and math.abs(x - t.x0) > 12 and not st.settings then t.drag = true end
  if t.drag and st.nso then
    -- a swipe steps through the covers
    local step = (CARD_W + CARD_GAP) * s
    local d = math.floor((t.x0 - x) / step + 0.5)
    if d ~= 0 then nsoMove(d > 0 and 1 or -1); t.x0 = x end
    return true
  end
  if t.drag then
    local n = st.count or 0
    local max = math.max(0, n * (TILE + GAP) - GAP - (REF_W - ROW_X * 2))
    st.target = clamp(t.target0 - (x - t.x0) / s, 0, max)
    st.scroll = st.target
  end
  return true
end

function X.released(imp, id, x, y)
  local t = st.touches[id]
  st.touches[id] = nil
  if not t then return false end
  if t.drag then return true end
  local h = hitAt(x, y)
  if not h or not t.hit or h.id ~= t.hit.id or h.data ~= t.hit.data then return true end
  if h.id == "nsogame" and st.nso then
    if st.nso.sel == h.data then nsoPlay() else st.nso.sel = h.data; st.nso.pickAt = love.timer.getTime(); Sfx.play("over") end
    return true
  end
  if h.id == "game" then
    if st.row == "games" and st.sel == h.data then start(imp, games(imp)[h.data])
    else st.row, st.sel = "games", h.data end
  elseif h.id == "button" then
    if st.row == "buttons" and st.bsel == h.data then pressButton(imp, h.data)
    else st.row, st.bsel = "buttons", h.data end
  elseif h.id == "user" then
    if ctx.openActivity then ctx.openActivity() end
  elseif h.id == "cat" and st.settings then
    st.settings.cat, st.settings.focus, st.settings.opt = h.data, "cats", 1
  elseif h.id == "opt" and st.settings then
    pickOption(imp, h.data)
  end
  return true
end

-- does this touch belong to the Switch HOME menu (it began there)?
function X.owns(id) return st.touches[id] ~= nil end

return X
