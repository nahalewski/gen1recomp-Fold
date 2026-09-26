-- skin: the XML-driven UI skin. Loads SKINS/<id>/skin.xml and draws from it.
--
-- NOTHING ABOUT THE SWITCH LOOK IS WRITTEN HERE. Every colour, size, position,
-- texture and label comes out of skin.xml, because Ben's requirement is that people
-- can customise the theme later. If a value is missing the fallback is a neutral
-- one, never a Switch-specific one - a skin that half-loads should look plainly
-- wrong rather than quietly like the Switch skin with one thing off.
--
-- THE LOGIC IS SEPARATED FROM THE DRAWING ON PURPOSE. `layout()` and `page()` are
-- pure functions of numbers, so they run under a plain Lua with no love at all, and
-- "does the carousel house all the games" is answered by a test on this machine
-- rather than by squinting at a screenshot from a handset.
--
-- Seam with init.lua (XMB UI Dev owns that file):
--   Skin.load(id)             -> model, or nil + message
--   Skin.mode()               -> "full_screen" | "clamshell"
--   Skin.games(list)          -> the library, handed in; this file never enumerates
--   Skin.draw(w, h, region)   -> region "all" | "top" | "bottom"
--   Skin.input(action)        -> true when consumed

local X = require("fold3ds.skinxml")

local M = {}

local model = nil
local games = {}
local sel = 1          -- index into `games`
local filter = 1       -- index into model.filters
local images = {}      -- cache: path -> image or false when it failed
-- Declared HERE, with images, not beside the drawing code that uses it: `load()`
-- clears this cache, and a `local` further down the file is not in scope there, so
-- load() would have silently created a global instead. The fonts would then never
-- be dropped on a skin change and the old sizes would persist - invisible in a
-- screenshot, because they are the right sizes until someone switches skin.
local fonts = {}       -- cache: pixel size -> font or false

local DIR = "fold3ds/"

----------------------------------------------------------------- loading ----

local function colorOf(node, tag, fallback)
  local r, g, b, a = X.color(X.text(node, tag))
  if r then return { r, g, b, a } end
  return fallback
end

local function attrColor(node, name, fallback)
  local r, g, b, a = X.color(X.attr(node, name))
  if r then return { r, g, b, a } end
  return fallback
end

--- Read SKINS/<id>/skin.xml into a model. Returns nil, message on failure.
function M.load(id)
  local path = DIR .. "SKINS/" .. id .. "/skin.xml"
  local text
  if love and love.filesystem and love.filesystem.getInfo(path) then
    text = love.filesystem.read(path)
  else
    local fh = io.open(path, "r")
    if fh then text = fh:read("*a"); fh:close() end
  end
  if not text then return nil, "no skin.xml at " .. path end

  local root, err = X.parse(text)
  if not root then return nil, "skin.xml: " .. err end
  if root.tag ~= "Skin" then return nil, "root is <" .. root.tag .. ">, expected <Skin>" end

  local display = X.child(root, "Display")
  local res = X.find(root, "Display", "TargetResolution")
  local theme = X.child(root, "Theme")
  local safe = X.find(root, "Display", "SafeArea")

  local m = {
    id = X.attr(root, "id", id),
    name = X.attr(root, "name", id),
    dir = DIR .. "SKINS/" .. id .. "/",
    mode = X.text(display, "Mode") or "clamshell",
    baseW = X.num(res, "width", 1280),
    baseH = X.num(res, "height", 720),
    safe = {
      left = X.num(safe, "left", 0), top = X.num(safe, "top", 0),
      right = X.num(safe, "right", 0), bottom = X.num(safe, "bottom", 0),
    },
    variants = {},
    variantOrder = {},
    filters = {},
    system = {},
    prompts = {},
  }

  -- THEME VARIANTS. The skin carries a light and a dark palette and names one
  -- active; each variant owns its own background, divider and colours. Read them
  -- all, so switching is a lookup rather than a reload, and take the active one
  -- from the file rather than assuming either.
  for _, v in ipairs(X.children(theme, "Variant")) do
    local vid = X.attr(v, "id", "?")
    local colors = X.child(v, "Colors")
    local bg = X.child(v, "Background")
    local div = X.child(v, "DividerLine")
    local entry = {
      id = vid,
      name = X.attr(v, "name", vid),
      bg = { src = X.attr(bg, "src"), fallback = attrColor(bg, "fallbackColor", { .92, .92, .92, 1 }) },
      cardFrame = X.text(colors, "CardDefaultFrame"),
      -- Neutral greys, not Switch colours: a variant missing its palette must look
      -- unfinished rather than nearly right.
      color = {
        primary = colorOf(colors, "Primary", { .5, .5, .5, 1 }),
        accent = colorOf(colors, "Accent", { .6, .6, .6, 1 }),
        text = colorOf(colors, "TextPrimary", { .1, .1, .1, 1 }),
        text2 = colorOf(colors, "TextSecondary", { .45, .45, .45, 1 }),
        inverse = colorOf(colors, "TextInverse", { 1, 1, 1, 1 }),
        surface = colorOf(colors, "Surface", { .95, .95, .95, 1 }),
        badge = colorOf(colors, "NintendoRed", { .9, 0, .07, 1 }),
      },
    }
    if X.bool(div, "enabled", false) then
      entry.divider = { y = X.num(div, "y", 0), h = X.num(div, "height", 1),
                        color = attrColor(div, "color", entry.color.text2), alpha = X.num(div, "alpha", 1) }
    end
    m.variants[vid] = entry
    table.insert(m.variantOrder, vid)
  end

  -- An ActiveVariant naming a variant that is not there is a typo in a file people
  -- edit by hand, so fall back to the first declared one rather than to nothing.
  local want = X.text(theme, "ActiveVariant")
  m.variant = (want and m.variants[want] and want) or m.variantOrder[1]

  local function applyVariant(mm, vid)
    local v = mm.variants[vid]
    if not v then return false end
    mm.variant, mm.color, mm.bg, mm.divider, mm.cardFrame = vid, v.color, v.bg, v.divider, v.cardFrame
    return true
  end
  m.applyVariant = applyVariant
  applyVariant(m, m.variant)

  local sb = X.child(root, "StatusBar")
  if X.bool(sb, "enabled", false) then
    m.statusBar = { y = X.num(sb, "y", 0), h = X.num(sb, "height", 48),
                    pad = X.num(sb, "paddingHorizontal", 0) }
  end

  local fb = X.child(root, "FilterBar")
  if X.bool(fb, "enabled", false) then
    m.filterBar = { y = X.num(fb, "y", 0), h = X.num(fb, "height", 34),
                    pad = X.num(fb, "paddingHorizontal", 0), spacing = X.num(fb, "spacing", 12) }
    for _, f in ipairs(X.children(fb, "Filter")) do
      table.insert(m.filters, {
        id = X.attr(f, "id", "?"), label = X.attr(f, "label", ""),
        src = X.attr(f, "src"), w = X.num(f, "width", 80), h = X.num(f, "height", 30),
        active = X.bool(f, "active", false),
      })
    end
  end
  for i, f in ipairs(m.filters) do if f.active then filter = i end end

  local car = X.child(root, "Carousel")
  local tile = X.find(root, "Carousel", "Tile")
  m.carousel = {
    y = X.num(car, "y", 145), h = X.num(car, "height", 340),
    tileW = tonumber(X.text(tile, "Width")) or 230,
    tileH = tonumber(X.text(tile, "Height")) or 230,
    radius = tonumber(X.text(tile, "CornerRadius")) or 0,
    spacing = tonumber(X.text(tile, "Spacing")) or 24,
    selScale = tonumber(X.text(tile, "SelectedScale")) or 1,
    unselScale = tonumber(X.text(tile, "UnselectedScale")) or 1,
    placeholder = X.attr(X.child(tile, "PlaceholderLight"), "src"),
    glow = X.attr(X.child(tile, "FocusGlow"), "src"),
  }
  local td = X.child(car, "TitleDisplay")
  m.title = { y = X.num(td, "y", 410), size = X.num(td, "fontSize", 24),
              color = attrColor(td, "color", m.color.text) }
  local pi = X.child(car, "PageIndicator")
  if X.bool(pi, "enabled", false) then m.pageDots = { y = X.num(pi, "y", 442) } end

  local sr = X.child(root, "SystemRow")
  if X.bool(sr, "enabled", false) then
    m.systemRow = { y = X.num(sr, "y", 540), size = X.num(sr, "iconSize", 64),
                    spacing = X.num(sr, "spacing", 28) }
    for _, b in ipairs(X.children(sr, "Button")) do
      local badge = X.child(b, "Badge")
      table.insert(m.system, {
        id = X.attr(b, "id", "?"), name = X.attr(b, "name", ""), src = X.attr(b, "src"),
        color = attrColor(b, "color", m.color.surface), action = X.attr(b, "action"),
        badge = (badge and X.bool(badge, "show", false)) and X.num(badge, "count", 0) or nil,
      })
    end
  end

  local nb = X.child(root, "NavigationBar")
  if X.bool(nb, "enabled", false) then
    m.navBar = { y = X.num(nb, "y", 665), h = X.num(nb, "height", 38),
                 pad = X.num(nb, "paddingHorizontal", 48) }
    for _, group in ipairs(X.children(nb, "Prompt")) do
      for _, it in ipairs(X.children(group, "Item")) do
        table.insert(m.prompts, {
          group = X.attr(group, "group", "right"), button = X.attr(it, "button", ""),
          label = X.attr(it, "label", ""), src = X.attr(it, "src"), action = X.attr(it, "action"),
        })
      end
    end
  end

  -- FONT SIZES COME FROM THE XML TOO. Without this every label draws in love's
  -- default ~12px face on a design authored at 1280x720, so a 24px game title
  -- renders half size and the screen reads as "nearly right" rather than wrong -
  -- the hardest kind of defect to spot in a screenshot.
  m.font = {}
  local fonts = X.child(theme, "Fonts")
  if fonts then
    for _, f in ipairs(fonts.kids) do
      m.font[f.tag] = X.num(f, "size", 14)
    end
  end

  model, sel, images, fonts = m, 1, {}, {}
  return m
end

--- Basename: the XML says "textures/icon_news.png"; homeswitch asks its own
--- texture loader for "icon_news.png", so the folder is stripped here rather than
--- each caller having to know the layout.
local function basename(p)
  -- Forward slash only: skin.xml writes paths that way throughout, and a character
  -- class carrying a backslash is one more thing to escape wrong.
  return p and p:match("([^/]+)$") or nil
end

--- 0..1 -> 0..255, which is what the existing draw path uses.
local function rgb255(c)
  if not c then return nil end
  return { math.floor(c[1] * 255 + .5), math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5) }
end

--- The system row, in the shape the wired draw path already expects.
---
--- This is the adapter that lets `SYSTEM_BUTTONS` stop being a Lua literal. The
--- ids, names, icons, colours and badges all come out of skin.xml, so a user
--- editing the file changes the row - which is the whole point of the theme being
--- XML. `action="modal:controllers"` is split into `modal`, `action="app:news"`
--- into `action`, because that is how the draw path branches.
function M.systemButtons()
  if not model then return {} end
  local out = {}
  for _, b in ipairs(model.system) do
    local kind, rest = (b.action or ""):match("^(%a+):(.+)$")
    table.insert(out, {
      id = b.id, name = b.name, icon = basename(b.src), color = rgb255(b.color),
      badge = b.badge,
      modal = kind == "modal" and rest or nil,
      action = kind ~= "modal" and (rest or b.action) or nil,
    })
  end
  return out
end

--- The filter pills, same idea.
function M.filterPills()
  if not model then return {} end
  local out = {}
  for _, f in ipairs(model.filters) do
    table.insert(out, { id = f.id, label = f.label, tex = basename(f.src) })
  end
  return out
end

function M.model() return model end

--- Switch theme variant ("light"/"dark"). Returns the active id.
--- The set comes from the XML, so a skin that adds a third variant needs no code.
function M.variant(id)
  if model and id and model.applyVariant then model.applyVariant(model, id) end
  return model and model.variant
end

--- Every variant id the skin declares, in document order.
function M.variants()
  return model and model.variantOrder or {}
end
function M.mode() return model and model.mode or "clamshell" end

--- The library, handed in by init.lua. This file never enumerates games itself.
function M.games(list)
  games = list or {}
  if sel > #games then sel = math.max(1, #games) end
  return #games
end

------------------------------------------------------------------ layout ----

--- Scale and offsets that map the skin's design resolution onto a real screen.
--- Uniform scale with letterboxing, so a skin authored at 1280x720 keeps its
--- proportions on any panel instead of being stretched to fit.
function M.layout(w, h, m)
  m = m or model
  if not m then return nil end
  local s = math.min(w / m.baseW, h / m.baseH)
  return {
    scale = s,
    offX = (w - m.baseW * s) / 2,
    offY = (h - m.baseH * s) / 2,
    -- design coords -> screen coords
    x = function(v) return (w - m.baseW * s) / 2 + v * s end,
    y = function(v) return (h - m.baseH * s) / 2 + v * s end,
    n = function(v) return v * s end,
  }
end

--- Which tiles are on screen, and where, for a carousel of `count` games.
---
--- The whole library is reachable: the window slides with the selection rather
--- than the list being cut to a page, so the last game is always one press from
--- the second to last. `first`/`last` are what a test asserts on to answer "does
--- it house all the games" without drawing anything.
function M.page(count, selected, m, w)
  m = m or model
  if not m or count <= 0 then return { first = 0, last = -1, perPage = 0, pages = 0, page = 0 } end
  local c = m.carousel
  local usable = (w or m.baseW) - m.safe.left - m.safe.right
  local step = c.tileW + c.spacing
  local perPage = math.max(1, math.floor((usable + c.spacing) / step))

  selected = math.max(1, math.min(selected, count))
  -- Centre the selection when there is room on both sides; clamp at the ends so
  -- the row never shows empty space beside a full library.
  local half = math.floor(perPage / 2)
  local first = math.max(1, math.min(selected - half, math.max(1, count - perPage + 1)))
  local last = math.min(count, first + perPage - 1)
  return {
    first = first, last = last, perPage = perPage,
    pages = math.max(1, math.ceil(count / perPage)),
    page = math.max(1, math.ceil(selected / perPage)),
  }
end

function M.selected() return sel end
function M.count() return #games end
function M.selectedGame() return games[sel] end
function M.game(i) return games[i or sel] end

------------------------------------------------------------------- input ----

function M.input(action)
  if not model or model.mode ~= "full_screen" then return false end
  if action == "left" then
    sel = sel > 1 and sel - 1 or #games          -- wrap, like the real shelf
    return true
  elseif action == "right" then
    sel = sel < #games and sel + 1 or 1
    return true
  elseif action == "filter_next" then
    if #model.filters > 0 then filter = filter % #model.filters + 1 end
    return true
  end
  return false
end

function M.filter() return model and model.filters[filter] or nil end

----------------------------------------------------------------- drawing ----

local function image(src)
  if not src or not model then return nil end
  if images[src] ~= nil then return images[src] or nil end
  local ok, img = pcall(love.graphics.newImage, model.dir .. src)
  -- A missing texture is cached as `false` so a broken path costs one failed load
  -- rather than one per frame.
  images[src] = ok and img or false
  return ok and img or nil
end

--- An image from a path that is NOT inside the skin folder - game artwork lives
--- wherever its emulator keeps it. Cached the same way, on the full path.
local function loadImage(path)
  if type(path) ~= "string" then return nil end
  if images[path] ~= nil then return images[path] or nil end
  local ok, img = pcall(love.graphics.newImage, path)
  images[path] = ok and img or false
  return ok and img or nil
end

local artFn = nil

--- Where a game's cover comes from. Injected so this file needs no opinion about
--- how the library stores art.
function M.art(fn) artFn = fn end

--- A tile's artwork, however this build happens to provide it.
---
--- I originally read `g.art`, which no tile has: `Emus.games()` stamps ids and
--- systems, and artwork comes from the provider through `Emus.icon(t)`. Reading a
--- field that is always nil does not fail, it just draws the placeholder behind
--- every game - which looks like missing art rather than like a bug, and would
--- have survived the first screenshot.
---
--- Providers return either a loaded image or a path, so both are accepted.
local function artFor(g)
  if not g then return nil end
  local a = g.art or g.cover
  if artFn then a = artFn(g) or a end
  if a == nil then
    local ok, Emus = pcall(require, "fold3ds.emus")
    if ok and type(Emus) == "table" then
      if Emus.icon then a = Emus.icon(g) end
      if a == nil and Emus.iconPath then a = Emus.iconPath(g) end
    end
  end
  if type(a) == "string" then return loadImage(a) end
  -- Anything else is assumed to be a drawable the provider already loaded; if it
  -- is not, the pcall in the caller keeps one bad tile from killing the frame.
  return a
end

--- A font at the size the XML asked for, scaled to this screen.
---
--- Cached on the pixel size: love creates a new rasterisation per size, and making
--- one per frame would allocate a font sixty times a second.
local function font(role, L)
  local px = math.max(8, math.floor(L.n(model.font[role] or 14) + 0.5))
  if not fonts[px] then
    local ok, f = pcall(love.graphics.newFont, px)
    fonts[px] = ok and f or false
  end
  return fonts[px] or nil
end

local function useFont(role, L)
  local f = font(role, L)
  if f then love.graphics.setFont(f) end
end

local function setColor(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alpha or 1))
end

local function drawTile(L, g, dx, dy, dw, dh, isSel)
  local c = model.carousel
  local ph = image(isSel and c.placeholder or c.placeholder)
  setColor(model.color.surface)
  love.graphics.rectangle("fill", L.x(dx), L.y(dy), L.n(dw), L.n(dh), L.n(c.radius))
  local okArt, art = pcall(artFor, g)
  if okArt and art and art.getWidth then
    setColor({ 1, 1, 1, 1 })
    love.graphics.draw(art, L.x(dx), L.y(dy), 0, L.n(dw) / art:getWidth(), L.n(dh) / art:getHeight())
  elseif ph then
    setColor({ 1, 1, 1, 1 })
    love.graphics.draw(ph, L.x(dx), L.y(dy), 0, L.n(dw) / ph:getWidth(), L.n(dh) / ph:getHeight())
  end
  if isSel then
    setColor(model.color.accent)
    love.graphics.setLineWidth(math.max(2, L.n(3)))
    love.graphics.rectangle("line", L.x(dx), L.y(dy), L.n(dw), L.n(dh), L.n(c.radius))
    love.graphics.setLineWidth(1)
  end
end

--- Draw the skin. `region` is "all" (library), "top" or "bottom" - XMB UI Dev
--- calls it twice while a game runs, because Ben wants the game on the bottom
--- screen and the settings panel on the top even though the skin is full_screen.
function M.draw(w, h, region)
  if not model then return false end
  region = region or "all"
  local L = M.layout(w, h)
  if not L then return false end

  if region == "bottom" then return false end   -- the emulator owns those pixels

  local bg = image(model.bg.src)
  if bg then
    setColor({ 1, 1, 1, 1 })
    love.graphics.draw(bg, L.offX, L.offY, 0, L.n(model.baseW) / bg:getWidth(), L.n(model.baseH) / bg:getHeight())
  else
    setColor(model.bg.fallback)
    love.graphics.rectangle("fill", L.offX, L.offY, L.n(model.baseW), L.n(model.baseH))
  end

  if region == "top" then
    M.drawSettingsPanel(L)
    return true
  end

  if model.statusBar then M.drawStatusBar(L) end
  if model.filterBar then M.drawFilterBar(L) end
  M.drawCarousel(L, w)
  if model.divider then
    setColor(model.divider.color, model.divider.alpha)
    love.graphics.rectangle("fill", L.x(0), L.y(model.divider.y), L.n(model.baseW), math.max(1, L.n(model.divider.h)))
  end
  if model.systemRow then M.drawSystemRow(L) end
  if model.navBar then M.drawNavBar(L) end
  return true
end

function M.drawStatusBar(L)
  local sb = model.statusBar
  useFont("Clock", L)
  setColor(model.color.text)
  love.graphics.print(os.date("%H:%M"), L.x(model.baseW - sb.pad - 60), L.y(sb.y + 10))
end

function M.drawFilterBar(L)
  local fb = model.filterBar
  local x = fb.pad
  for i, f in ipairs(model.filters) do
    local img = image(f.src)
    if img then
      setColor({ 1, 1, 1, i == filter and 1 or .55 })
      love.graphics.draw(img, L.x(x), L.y(fb.y), 0, L.n(f.w) / img:getWidth(), L.n(f.h) / img:getHeight())
    else
      setColor(i == filter and model.color.primary or model.color.surface)
      love.graphics.rectangle("fill", L.x(x), L.y(fb.y), L.n(f.w), L.n(f.h), L.n(8))
    end
    x = x + f.w + fb.spacing
  end
end

function M.drawCarousel(L, w)
  local c = model.carousel
  local p = M.page(#games, sel, model, model.baseW)
  if p.last < p.first then return end

  local shown = p.last - p.first + 1
  local span = shown * c.tileW + (shown - 1) * c.spacing
  local x = (model.baseW - span) / 2

  for i = p.first, p.last do
    local isSel = (i == sel)
    local scale = isSel and c.selScale or c.unselScale
    local dw, dh = c.tileW * scale, c.tileH * scale
    local dy = c.y + (c.h - dh) / 2
    drawTile(L, games[i], x + (c.tileW - dw) / 2, dy, dw, dh, isSel)
    x = x + c.tileW + c.spacing
  end

  local g = games[sel]
  if g and model.title then
    useFont("GameTitle", L)
    setColor(model.title.color)
    love.graphics.printf(g.name or g.title or "", L.x(0), L.y(model.title.y), L.n(model.baseW), "center")
  end
  if model.pageDots and p.pages > 1 then
    local r = L.n(4)
    local gap = L.n(16)
    local startX = L.x(model.baseW / 2) - (p.pages - 1) * gap / 2
    for i = 1, p.pages do
      setColor(i == p.page and model.color.primary or model.color.text2, i == p.page and 1 or .4)
      love.graphics.circle("fill", startX + (i - 1) * gap, L.y(model.pageDots.y), r)
    end
  end
end

--- The system row's buttons shown: M.hide(id) (set by the fold layer) keeps
--- an eShop app's button off until the app is downloaded.
local function shownSystem()
  local out = {}
  for _, b in ipairs(model.system) do
    if not (M.hide and M.hide(b.id)) then out[#out + 1] = b end
  end
  return out
end

function M.drawSystemRow(L)
  local sr = model.systemRow
  local list = shownSystem()
  local n = #list
  if n == 0 then return end
  local span = n * sr.size + (n - 1) * sr.spacing
  local x = (model.baseW - span) / 2
  for _, b in ipairs(list) do
    local img = image(b.src)
    if img then
      setColor({ 1, 1, 1, 1 })
      love.graphics.draw(img, L.x(x), L.y(sr.y), 0, L.n(sr.size) / img:getWidth(), L.n(sr.size) / img:getHeight())
    else
      setColor(b.color)
      love.graphics.circle("fill", L.x(x + sr.size / 2), L.y(sr.y + sr.size / 2), L.n(sr.size / 2))
    end
    x = x + sr.size + sr.spacing
  end
end

--- The system row's button under a screen point (the same places
--- drawSystemRow draws them), with its action split as systemButtons() does.
function M.systemButtonAt(x, y, L)
  if not (model and model.systemRow and L) then return nil end
  local sr = model.systemRow
  local list = shownSystem()
  local n = #list
  local span = n * sr.size + (n - 1) * sr.spacing
  local bx = (model.baseW - span) / 2
  for _, b in ipairs(list) do
    local rx, ry, rs = L.x(bx), L.y(sr.y), L.n(sr.size)
    if x >= rx and x <= rx + rs and y >= ry and y <= ry + rs then
      for _, sb in ipairs(M.systemButtons()) do if sb.id == b.id then return sb end end
    end
    bx = bx + sr.size + sr.spacing
  end
end

function M.drawNavBar(L)
  local nb = model.navBar
  useFont("ButtonPrompt", L)
  local rightX = model.baseW - nb.pad
  for i = #model.prompts, 1, -1 do
    local p = model.prompts[i]
    if p.group ~= "left" then
      setColor(model.color.text2)
      love.graphics.print(p.button .. "  " .. p.label, L.x(rightX - 90), L.y(nb.y))
      rightX = rightX - 110
    end
  end
  for _, p in ipairs(model.prompts) do
    if p.group == "left" then
      setColor(model.color.text2)
      love.graphics.print(p.button .. "  " .. p.label, L.x(nb.pad), L.y(nb.y))
    end
  end
end

--- Top screen while a Switch game runs. Ben's spec: settings up here, game below.
function M.drawSettingsPanel(L)
  useFont("DialogTitle", L)
  setColor(model.color.text)
  love.graphics.printf(model.name, L.x(0), L.y(model.safe.top + 8), L.n(model.baseW), "center")
  local y = model.safe.top + 56
  for _, b in ipairs(model.system) do
    setColor(b.color)
    love.graphics.rectangle("fill", L.x(model.safe.left), L.y(y), L.n(28), L.n(28), L.n(6))
    useFont("SystemIconLabel", L)
    setColor(model.color.text)
    love.graphics.print(b.name, L.x(model.safe.left + 40), L.y(y + 6))
    y = y + 40
  end
end

return M
