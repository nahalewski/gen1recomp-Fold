-- fold3ds: the Android foldable layer for gen1recomp.
--
-- On a foldable held open the app becomes a 3DS: the game (or the
-- launcher) draws inside the top shell's screen, the bottom shell carries
-- drawn A / B / X / Y, D-pad, stick, START, SELECT and HOME buttons that
-- press real input, and the bottom screen shows the launcher (menus) or,
-- in game, the game's Pokemon animated.  On the cover screen (the phone
-- closed) the closed lid fills the screen.
--
-- It plugs into the engine's own seams and touches no engine file:
--   * HostDisplay backend: beginFrame / endFrame around the launcher's and
--     the game's draw, so each renders into a canvas placed in a screen
--     cutout while believing that canvas is the window (love.graphics
--     size, window mode, safe area, mouse and touch queries are answered
--     in that "virtual window" while it is active);
--   * Input:overlayPressed / overlayReleased for the game buttons;
--   * the launcher's gamepadpressed / gamepadreleased for menu buttons;
--   * Orientation.apply("landscape") so the hinge runs across the middle.
--
-- POKEPORT_FOLD=ds|lid|off forces a mode on the desktop for testing.
local M = {}

local lg, lw, lm, lt = love.graphics, love.window, love.mouse, love.touch
local real = {
  getDimensions = lg.getDimensions, getWidth = lg.getWidth, getHeight = lg.getHeight,
  getPixelDimensions = lg.getPixelDimensions, getPixelWidth = lg.getPixelWidth, getPixelHeight = lg.getPixelHeight,
  setCanvas = lg.setCanvas,
  getMode = lw.getMode, getSafeArea = lw.getSafeArea,
  mouseGetPosition = lm.getPosition, mouseGetX = lm.getX, mouseGetY = lm.getY,
  touchGetTouches = lt.getTouches, touchGetPosition = lt.getPosition,
}
local orig = {}   -- the engine's event handlers, wrapped by install()

local DIR = "fold3ds/"
-- shell art (full size); cut = the screen opening in the art's pixels
local TOP = { file = "skin/top_gbc.png", cut = { 318, 196, 838, 464 } }
local BOTTOM = { file = "skin/bottom_empty.png", cut = { 318, 158, 756, 504 } }
local SHEET = "skin/buttons.png"
local LID = "skin/lid.png"
-- sockets in half-size units of the bottom shell (x, y centre, r radius);
-- sprite = rect in the half-size button sheet.  Both scale by 2 for the art.
local BUTTONS = {
  { name = "stick", x = 68, y = 134, r = 50, sprite = { 270, 228, 181, 182 }, kind = "dpad" },
  { name = "pad", x = 68, y = 249, r = 48, sprite = { 37, 228, 184, 186 }, kind = "dpad" },
  { name = "x", x = 620, y = 126, r = 21, sprite = { 381, 57, 133, 134 } },
  { name = "y", x = 583, y = 164, r = 21, sprite = { 560, 58, 133, 133 } },
  { name = "a", x = 656, y = 164, r = 21, sprite = { 35, 58, 132, 133 } },
  { name = "b", x = 620, y = 201, r = 21, sprite = { 209, 58, 132, 133 } },
  { name = "start", x = 586, y = 271, r = 14, sprite = { 515, 256, 62, 62 } },
  { name = "select", x = 586, y = 316, r = 14, sprite = { 515, 340, 62, 63 } },
  { name = "home", x = 342, y = 365, r = 25, sprite = { 288, 427, 144, 86 }, wide = true },
}
-- game buttons (Input names) and launcher buttons (SDL gamepad names)
local GAME_BTN = { a = "a", b = "b", x = "r", y = "l", start = "start", select = "select",
                   up = "up", down = "down", left = "left", right = "right" }
local PAD_BTN = { a = "a", b = "b", x = "x", y = "y", start = "start", select = "back",
                  up = "dpup", down = "dpdown", left = "dpleft", right = "dpright" }

local state = {
  mode = "off",          -- off | lid | ds
  kind = nil,            -- last HostDisplay kind: launcher | game | editor ...
  subject = nil,
  W = 0, H = 0,          -- real window
  L = nil,               -- layout
  vwin = nil,            -- the virtual window rect (x, y, w, h) in real pixels
  frameCanvas = nil,     -- while a subject draws: its canvas
  canvases = {},
  held = {},             -- touch id -> { name=, dirs= }
  vtouch = {},           -- touch id -> { x, y } inside the virtual window
  images = {},
  idle = { manifest = nil, sheets = {} },
  oriented = false,
  time = 0,
}

---------------------------------------------------------------- helpers

local function image(file)
  if state.images[file] == nil then
    local ok, img = pcall(lg.newImage, DIR .. file)
    state.images[file] = ok and img or false
    if ok then img:setFilter("linear", "linear") end
  end
  return state.images[file] or nil
end

local function detectMode()
  local force = os.getenv and os.getenv("POKEPORT_FOLD")
  if force == "off" or force == "ds" or force == "lid" then return force end
  local os_ = love.system and love.system.getOS and love.system.getOS()
  if os_ ~= "Android" then return "off" end
  local W, H = real.getDimensions()
  if W <= 0 or H <= 0 then return "off" end
  -- the cover screen is phone-shaped, the inner screen nearly square
  local r = math.min(W, H) / math.max(W, H)
  if r < 0.62 then return "lid" end
  return "ds"
end

local function layout(W, H)
  local top, bottom = image(TOP.file), image(BOTTOM.file)
  if not top or not bottom then return nil end
  local topH = math.floor(H / 2)
  local botH = H - topH
  local L = {}
  local tw, th = top:getDimensions()
  local sc = math.min(W / tw, topH / th)
  L.top = { x = math.floor((W - tw * sc) / 2), y = topH - th * sc, sc = sc, img = top }
  L.topCut = { x = math.floor(L.top.x + TOP.cut[1] * sc), y = math.floor(L.top.y + TOP.cut[2] * sc),
               w = math.floor(TOP.cut[3] * sc), h = math.floor(TOP.cut[4] * sc) }
  local bw, bh = bottom:getDimensions()
  local sb = math.min(W / bw, botH / bh)
  L.bottom = { x = math.floor((W - bw * sb) / 2), y = topH, sc = sb, img = bottom }
  L.botCut = { x = math.floor(L.bottom.x + BOTTOM.cut[1] * sb), y = math.floor(L.bottom.y + BOTTOM.cut[2] * sb),
               w = math.floor(BOTTOM.cut[3] * sb), h = math.floor(BOTTOM.cut[4] * sb) }
  L.s2 = sb * 2          -- half-size units -> pixels
  L.topH = topH
  L.W, L.H = W, H
  return L
end

local function virtualRect()
  local L = state.L
  if not L then return nil end
  if state.kind == "game" then return L.topCut end
  return L.botCut
end

local function vactive()
  return state.mode == "ds" and state.vwin ~= nil
end

local function inside(r, x, y)
  return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end

---------------------------------------------------------------- buttons

-- the shell button under a point (bottom half, outside the screen)
local function buttonAt(x, y)
  local L = state.L
  if M.debug then print("fold3ds buttonAt L=" .. tostring(L) .. " topH=" .. tostring(L and L.topH)) end
  if not L or y < L.topH then return nil end
  for _, b in ipairs(BUTTONS) do
    if M.debug then print("fold3ds  check " .. b.name) end
    local cx, cy, r = L.bottom.x + b.x * L.s2, L.bottom.y + b.y * L.s2, b.r * L.s2
    local dx, dy = x - cx, y - cy
    if b.kind == "dpad" then
      if math.abs(dx) <= r * 1.3 and math.abs(dy) <= r * 1.3 then return b end
    elseif b.wide then
      if math.abs(dx) <= r * 2 and math.abs(dy) <= r * 1.2 then return b end
    elseif dx * dx + dy * dy <= (r * 1.25) * (r * 1.25) then
      return b
    end
  end
  return nil
end

-- directions a d-pad / stick touch holds
local function dirsAt(b, x, y)
  local L = state.L
  local cx, cy, r = L.bottom.x + b.x * L.s2, L.bottom.y + b.y * L.s2, b.r * L.s2
  local dx, dy = x - cx, y - cy
  local ax, ay = math.abs(dx), math.abs(dy)
  local d = {}
  if ax > r * 0.2 or ay > r * 0.2 then
    if ax >= ay * 0.45 then d[dx < 0 and "left" or "right"] = true end
    if ay >= ax * 0.45 then d[dy < 0 and "up" or "down"] = true end
  end
  return d
end

local function gameInput()
  local ok, Input = pcall(require, "src.core.Input")
  return ok and Input or nil
end

local function press(btn)
  if state.kind == "game" then
    if btn == "home" then
      -- HOME: back to the launcher (the engine turns quit into a return)
      love.event.quit()
      return
    end
    local Input = gameInput()
    if Input and Input.overlayPressed and GAME_BTN[btn] then Input:overlayPressed(GAME_BTN[btn]) end
  else
    local s = state.subject
    if btn == "home" then return end
    if s and s.gamepadpressed and PAD_BTN[btn] then pcall(s.gamepadpressed, s, nil, PAD_BTN[btn]) end
  end
end

local function release(btn)
  if state.kind == "game" then
    local Input = gameInput()
    if Input and Input.overlayReleased and GAME_BTN[btn] then Input:overlayReleased(GAME_BTN[btn]) end
  else
    local s = state.subject
    if s and s.gamepadreleased and PAD_BTN[btn] then pcall(s.gamepadreleased, s, nil, PAD_BTN[btn]) end
  end
end

local function holdStart(id, b, x, y)
  local h = { name = b.name, kind = b.kind, dirs = {} }
  state.held[id] = h
  if b.kind == "dpad" then
    h.dirs = dirsAt(b, x, y)
    for d in pairs(h.dirs) do press(d) end
  else
    press(b.name)
  end
end

local function holdMove(id, x, y)
  local h = state.held[id]
  if not h or h.kind ~= "dpad" then return end
  local b
  for _, bb in ipairs(BUTTONS) do if bb.name == h.name then b = bb end end
  local nd = dirsAt(b, x, y)
  for d in pairs(h.dirs) do if not nd[d] then release(d) end end
  for d in pairs(nd) do if not h.dirs[d] then press(d) end end
  h.dirs = nd
end

local function holdEnd(id)
  local h = state.held[id]
  if not h then return end
  state.held[id] = nil
  if h.kind == "dpad" then
    for d in pairs(h.dirs) do release(d) end
  else
    release(h.name)
  end
end

local function releaseAll()
  for id in pairs(state.held) do holdEnd(id) end
  state.vtouch = {}
end

local function buttonLit(b)
  for _, h in pairs(state.held) do
    if h.name == b.name then return true, h.dirs end
  end
  return false, nil
end

---------------------------------------------------------------- events

local topScreenTap   -- defined with the drawing (the launcher's top screen)
local function toVirtual(x, y)
  local r = state.vwin
  if not r then return x, y, false end
  return x - r.x, y - r.y, inside(r, x, y)
end

local function onTouchPressed(id, x, y, dx, dy, pr)
  if M.debug then print("fold3ds touchpressed enter mode=" .. tostring(state.mode)) end
  if state.mode ~= "ds" then
    if state.mode == "lid" then return end
    return orig.touchpressed and orig.touchpressed(id, x, y, dx, dy, pr)
  end
  local b = buttonAt(x, y)
  if M.debug then print("fold3ds buttonAt -> " .. tostring(b and b.name)) end
  if b then holdStart(id, b, x, y) return end
  if topScreenTap(x, y) then return end
  local lx, ly, ok = toVirtual(x, y)
  if M.debug then print(("fold3ds touch %d,%d -> %s %.0f,%.0f kind=%s"):format(x, y, tostring(ok), lx, ly, tostring(state.kind))) end
  if ok then
    state.vtouch[id] = { lx, ly }
    if orig.touchpressed then
      local okc, err = pcall(orig.touchpressed, id, lx, ly, dx, dy, pr)
      if M.debug then print("fold3ds forwarded ok=" .. tostring(okc)) end
      if not okc then print("fold3ds: touchpressed error: " .. tostring(err)) end
    end
  end
end

local function onTouchMoved(id, x, y, dx, dy, pr)
  if state.mode ~= "ds" then
    if state.mode == "lid" then return end
    return orig.touchmoved and orig.touchmoved(id, x, y, dx, dy, pr)
  end
  if state.held[id] then holdMove(id, x, y) return end
  if state.vtouch[id] then
    local lx, ly = toVirtual(x, y)
    state.vtouch[id] = { lx, ly }
    if orig.touchmoved then return orig.touchmoved(id, lx, ly, dx, dy, pr) end
  end
end

local function onTouchReleased(id, x, y, dx, dy, pr)
  if state.mode ~= "ds" then
    if state.mode == "lid" then return end
    return orig.touchreleased and orig.touchreleased(id, x, y, dx, dy, pr)
  end
  if state.held[id] then holdEnd(id) return end
  if state.vtouch[id] then
    state.vtouch[id] = nil
    local lx, ly = toVirtual(x, y)
    if orig.touchreleased then return orig.touchreleased(id, lx, ly, dx, dy, pr) end
  end
end

-- a real mouse (desktop testing) is a finger too; Android's synthesized
-- mouse twin of a touch just gets the same coordinate change
local function onMousePressed(x, y, button, istouch, presses)
  if state.mode ~= "ds" then
    if state.mode == "lid" then return end
    return orig.mousepressed and orig.mousepressed(x, y, button, istouch, presses)
  end
  if not istouch and button == 1 then
    local b = buttonAt(x, y)
    if b then holdStart("mouse", b, x, y) return end
    if topScreenTap(x, y) then return end
  end
  local lx, ly, ok = toVirtual(x, y)
  if ok and orig.mousepressed then return orig.mousepressed(lx, ly, button, istouch, presses) end
end

local function onMouseMoved(x, y, dx, dy, istouch)
  if state.mode ~= "ds" then
    if state.mode == "lid" then return end
    return orig.mousemoved and orig.mousemoved(x, y, dx, dy, istouch)
  end
  if state.held.mouse then holdMove("mouse", x, y) return end
  local lx, ly = toVirtual(x, y)
  if orig.mousemoved then return orig.mousemoved(lx, ly, dx, dy, istouch) end
end

local function onMouseReleased(x, y, button, istouch, presses)
  if state.mode ~= "ds" then
    if state.mode == "lid" then return end
    return orig.mousereleased and orig.mousereleased(x, y, button, istouch, presses)
  end
  if state.held.mouse and not istouch then holdEnd("mouse") return end
  local lx, ly = toVirtual(x, y)
  if orig.mousereleased then return orig.mousereleased(lx, ly, button, istouch, presses) end
end

---------------------------------------------------------------- drawing

local function idleAnim(version)
  local idle = state.idle
  if idle.manifest == nil then
    local ok, m = pcall(function() return love.filesystem.load(DIR .. "idle/manifest.lua")() end)
    idle.manifest = ok and type(m) == "table" and m or false
  end
  local entry = idle.manifest and idle.manifest[version]
  if not entry then return nil end
  if idle.sheets[version] == nil then
    local ok, img = pcall(lg.newImage, DIR .. "idle/" .. entry.file)
    if ok then
      img:setFilter("nearest", "nearest")
      local w, h = img:getDimensions()
      local fw = math.floor(w / entry.frames)
      local quads = {}
      for i = 0, entry.frames - 1 do quads[i + 1] = lg.newQuad(i * fw, 0, fw, h, w, h) end
      idle.sheets[version] = { img = img, quads = quads, fw = fw, fh = h, fps = entry.fps or 5, frames = entry.frames }
    else
      idle.sheets[version] = false
    end
  end
  return idle.sheets[version] or nil
end

local function currentVersion()
  local ok, GV = pcall(require, "src.core.GameVersion")
  return ok and GV.get and GV.get() or "red"
end

-- the bottom screen while playing: the game's Pokemon; Yellow's Pikachu surfs
local function drawIdle(r)
  local t = state.time
  local version = currentVersion()
  lg.setColor(0.04, 0.06, 0.16, 1)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  local anim = idleAnim(version)
  local surf = version == "yellow"
  if surf then
    for band = 0, 2 do
      local by = r.y + r.h * (0.62 + band * 0.12)
      lg.setColor(0.16 + band * 0.06, 0.40 + band * 0.08, 0.85 - band * 0.10, 1)
      lg.rectangle("fill", r.x, by, r.w, r.h - (by - r.y))
      lg.setColor(0.85, 0.93, 1, 0.9)
      local step = r.w / 18
      for wx = r.x - step, r.x + r.w, step do
        local px = wx + (t * (30 + band * 12) * (r.w / 480)) % step
        local py = by + math.sin((px + t * 40) / 9) * 2
        if px >= r.x and px + step / 2 <= r.x + r.w then lg.rectangle("fill", px, py - 1, step / 2, r.h / 90) end
      end
    end
  end
  if not anim then return end
  local scale = math.max(1, math.floor((r.h * 0.55) / anim.fh))
  local frame = math.floor(t * anim.fps) % anim.frames + 1
  local dx = r.x + (r.w - anim.fw * scale) / 2
  local dy = r.y + (r.h - anim.fh * scale) / 2
  if surf then dy = r.y + r.h * 0.62 - anim.fh * scale + r.h * 0.08 + math.sin(t * 2.5) * r.h * 0.015 end
  lg.setColor(1, 1, 1, 1)
  lg.draw(anim.img, anim.quads[frame], math.floor(dx), math.floor(dy), 0, scale, scale)
end

-- the launcher's selected game (the GAMES tab's version, else the last panel)
local function launcherVersion()
  local imp = state.subject
  local ok, GV = pcall(require, "src.core.GameVersion")
  local v = imp and (imp.panelVersion or imp.tab)
  if ok and GV.VERSIONS and v and GV.VERSIONS[v] then return v end
  return "red"
end

local function cartImage(version)
  local key = "cart:" .. version
  if state.images[key] == nil then
    local ok, img = pcall(lg.newImage, DIR .. "carts/" .. version .. ".png")
    state.images[key] = ok and img or false
    if ok then img:setFilter("linear", "linear") end
  end
  return state.images[key] or nil
end

local fonts = {}
local function font(px)
  px = math.max(8, math.floor(px))
  if not fonts[px] then fonts[px] = lg.newFont(px) end
  return fonts[px]
end

-- the top screen behind the launcher: the selected game's cartridge, the
-- arrows that change it, the project credit
local function drawTopIdle(r)
  lg.setColor(0.02, 0.02, 0.03, 1)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  local version = launcherVersion()
  local img = cartImage(version)
  if img then
    local iw, ih = img:getDimensions()
    local s = math.max(r.w / iw, r.h / ih)
    lg.setColor(1, 1, 1, 1)
    lg.setScissor(r.x, r.y, r.w, r.h)
    lg.draw(img, r.x + (r.w - iw * s) / 2, r.y + (r.h - ih * s) / 2, 0, s, s)
    lg.setScissor()
  end
  local f = font(r.h * 0.12)
  lg.setFont(f)
  lg.setColor(1, 1, 1, 0.85)
  lg.print("<", r.x + r.w * 0.03, r.y + r.h / 2 - f:getHeight() / 2)
  lg.print(">", r.x + r.w * 0.97 - f:getWidth(">"), r.y + r.h / 2 - f:getHeight() / 2)
  local ok, GV = pcall(require, "src.core.GameVersion")
  local info = ok and GV.info and GV.info(version)
  local imp = state.subject
  local ready = imp and imp.ready and imp.ready[version]
  local cf = font(r.h * 0.05)
  lg.setFont(cf)
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", r.x, r.y + r.h - cf:getHeight() * 3.4, r.w, cf:getHeight() * 3.4)
  lg.setColor(0.85, 0.85, 0.9, 1)
  lg.printf((info and info.displayName or version) .. (ready and "  -  tap the cart to play" or "  -  import the ROM below"),
    r.x, r.y + r.h - cf:getHeight() * 3.2, r.w, "center")
  lg.printf("Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC\ngithub.com/bryanthaboi/gen1recomp",
    r.x, r.y + r.h - cf:getHeight() * 2.1, r.w, "center")
end

-- a tap on the top screen while the launcher shows: arrows change the
-- game, the cart plays it
topScreenTap = function(x, y)
  local L = state.L
  if not L or state.kind == "game" or not inside(L.topCut, x, y) then return false end
  local imp = state.subject
  if not imp then return true end
  local rel = (x - L.topCut.x) / L.topCut.w
  local ok, GV = pcall(require, "src.core.GameVersion")
  local order = ok and GV.ORDER or { "red" }
  local version = launcherVersion()
  if rel < 0.2 or rel > 0.8 then
    local idx = 1
    for i, v in ipairs(order) do if v == version then idx = i end end
    idx = (idx - 1 + (rel < 0.2 and -1 or 1)) % #order + 1
    imp.tab = order[idx]
    imp.panelVersion = order[idx]
  elseif imp.ready and imp.ready[version] and imp.play then
    pcall(imp.play, imp, version, true)
  end
  return true
end

local function drawButtons(L)
  local sheet = image(SHEET)
  if not sheet then return end
  local sw, sh = sheet:getDimensions()
  for _, b in ipairs(BUTTONS) do
    b.quad = b.quad or lg.newQuad(b.sprite[1] * 2, b.sprite[2] * 2, b.sprite[3] * 2, b.sprite[4] * 2, sw, sh)
    local lit, dirs = buttonLit(b)
    local target = b.r * 2 * L.s2               -- socket width in pixels
    local qw, qh = b.sprite[3] * 2, b.sprite[4] * 2
    local scale = (b.wide and (target * 2 / qw)) or (target / math.max(qw, qh))
    local cx, cy = L.bottom.x + b.x * L.s2, L.bottom.y + b.y * L.s2
    local dx, dy = 0, 0
    if b.kind == "dpad" and lit and dirs then
      local lean = b.r * L.s2 * 0.12
      if dirs.left then dx = dx - lean end
      if dirs.right then dx = dx + lean end
      if dirs.up then dy = dy - lean end
      if dirs.down then dy = dy + lean end
    end
    local ps = scale * (lit and 0.93 or 1)
    if lit then lg.setColor(0.68, 0.68, 0.72, 1) else lg.setColor(1, 1, 1, 1) end
    lg.draw(sheet, b.quad, cx - qw * ps / 2 + dx, cy - qh * ps / 2 + dy + (lit and L.s2 * 1.5 or 0), 0, ps, ps)
  end
end

local function drawLid(W, H)
  local lid = image(LID)
  lg.setColor(0.16, 0.16, 0.17, 1)
  lg.rectangle("fill", 0, 0, W, H)
  if not lid then return end
  local iw, ih = lid:getDimensions()
  local portrait = H > W * 1.1
  local aw, ah = W, H
  if portrait then aw, ah = H, W end
  local s = math.min(aw / iw, ah / ih)
  lg.push()
  if portrait then
    lg.translate(W, 0)
    lg.rotate(math.pi / 2)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(lid, math.floor((aw - iw * s) / 2), math.floor((ah - ih * s) / 2), 0, s, s)
  lg.pop()
end

local function drawFrame()
  local L = state.L
  local W, H = state.W, state.H
  real.setCanvas()
  lg.push("all")
  lg.origin()
  lg.setShader()
  lg.setScissor()
  lg.setBlendMode("alpha")
  lg.setColor(1, 1, 1, 1)
  if state.mode == "lid" then
    drawLid(W, H)
    lg.pop()
    return
  end
  lg.clear(0.05, 0.05, 0.06, 1)
  -- screens first (the openings in the shell art are transparent)
  local canvas = state.canvases[state.kind == "game" and "game" or "launcher"]
  if state.kind == "game" then
    if canvas then lg.draw(canvas, L.topCut.x, L.topCut.y) end
    drawIdle(L.botCut)
  else
    drawTopIdle(L.topCut)
    if canvas then lg.draw(canvas, L.botCut.x, L.botCut.y) end
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(L.top.img, L.top.x, L.top.y, 0, L.top.sc, L.top.sc)
  lg.draw(L.bottom.img, L.bottom.x, L.bottom.y, 0, L.bottom.sc, L.bottom.sc)
  drawButtons(L)
  lg.pop()
end

---------------------------------------------------------------- backend

local backend = {}

local dbgFrames = 0
function backend:update(dt)
  state.time = state.time + (dt or 0)
  if M.debug and dbgFrames < 3 then dbgFrames = dbgFrames + 1 io.stdout:setvbuf("no") print("fold3ds update mode=" .. tostring(state.mode) .. " kind=" .. tostring(state.kind)) end
  if M.driverTick then M.driverTick() end
  local mode = detectMode()
  local W, H = real.getDimensions()
  if mode ~= state.mode then
    releaseAll()
    state.mode = mode
  end
  if mode == "ds" and (W ~= state.W or H ~= state.H or not state.L) then
    state.W, state.H = W, H
    state.L = layout(W, H)
    if not state.L then state.mode = "off" end
  end
  state.W, state.H = W, H
  state.vwin = state.mode == "ds" and virtualRect() or nil
  if not state.oriented and love.system.getOS() == "Android" then
    state.oriented = true
    pcall(function() require("src.core.Orientation").apply("landscape") end)
  end
end

function backend:beginFrame(kind, subject)
  local changed = kind ~= state.kind
  state.kind, state.subject = kind, subject
  if changed then releaseAll() end
  if state.mode ~= "ds" or not state.L then return end
  state.vwin = virtualRect()
  local r = state.vwin
  local key = kind == "game" and "game" or "launcher"
  local c = state.canvases[key]
  if not c or c:getWidth() ~= r.w or c:getHeight() ~= r.h then
    if c and c.release then c:release() end
    c = lg.newCanvas(r.w, r.h)
    state.canvases[key] = c
  end
  if kind == "game" then
    -- the shell's buttons replace the engine's touch overlay
    local ok, TC = pcall(require, "src.core.TouchControls")
    if ok and TC then TC.enabled = false end
  end
  state.frameCanvas = c
  real.setCanvas(c)
  lg.clear(0, 0, 0, 1)
end

function backend:endFrame(kind, subject)
  state.frameCanvas = nil
  if state.mode == "off" then return end
  drawFrame()
end

---------------------------------------------------------------- install

function M.install()
  if M.installed then return end
  M.installed = true
  -- the virtual window: size, mode, safe area, pointer queries
  lg.getDimensions = function() if vactive() then return state.vwin.w, state.vwin.h end return real.getDimensions() end
  lg.getWidth = function() if vactive() then return state.vwin.w end return real.getWidth() end
  lg.getHeight = function() if vactive() then return state.vwin.h end return real.getHeight() end
  if real.getPixelDimensions then
    lg.getPixelDimensions = function() if vactive() then return state.vwin.w, state.vwin.h end return real.getPixelDimensions() end
    lg.getPixelWidth = function() if vactive() then return state.vwin.w end return real.getPixelWidth() end
    lg.getPixelHeight = function() if vactive() then return state.vwin.h end return real.getPixelHeight() end
  end
  -- "the screen" (no target, or a nil target) is the subject's canvas while
  -- it draws; the engine's GameViewport passes nil when it has no viewport
  lg.setCanvas = function(...)
    if state.frameCanvas and (select("#", ...) == 0 or select(1, ...) == nil) then
      return real.setCanvas(state.frameCanvas)
    end
    return real.setCanvas(...)
  end
  lw.getMode = function()
    local w, h, flags = real.getMode()
    if vactive() then return state.vwin.w, state.vwin.h, flags end
    return w, h, flags
  end
  if real.getSafeArea then
    lw.getSafeArea = function()
      if vactive() then return 0, 0, state.vwin.w, state.vwin.h end
      return real.getSafeArea()
    end
  end
  lm.getPosition = function()
    local x, y = real.mouseGetPosition()
    if vactive() then return x - state.vwin.x, y - state.vwin.y end
    return x, y
  end
  lm.getX = function() local x = lm.getPosition() return x end
  lm.getY = function() local _, y = lm.getPosition() return y end
  lt.getTouches = function()
    if not vactive() then return real.touchGetTouches() end
    local ids = {}
    for id in pairs(state.vtouch) do ids[#ids + 1] = id end
    return ids
  end
  lt.getPosition = function(id)
    if vactive() and state.vtouch[id] then return state.vtouch[id][1], state.vtouch[id][2] end
    return real.touchGetPosition(id)
  end
  -- events
  orig.touchpressed, orig.touchmoved, orig.touchreleased = love.touchpressed, love.touchmoved, love.touchreleased
  orig.mousepressed, orig.mousemoved, orig.mousereleased = love.mousepressed, love.mousemoved, love.mousereleased
  love.touchpressed, love.touchmoved, love.touchreleased = onTouchPressed, onTouchMoved, onTouchReleased
  love.mousepressed, love.mousemoved, love.mousereleased = onMousePressed, onMouseMoved, onMouseReleased
  -- the frame
  local ok, HostDisplay = pcall(require, "src.core.HostDisplay")
  if ok and HostDisplay and HostDisplay.setBackend then HostDisplay.setBackend(backend) end
  -- desktop testing: a window the size of a foldable's screen, and a script
  local size = os.getenv and os.getenv("POKEPORT_FOLD_SIZE")
  if size then
    local w, h = size:match("^(%d+)x(%d+)$")
    if w then
      pcall(lw.setMode, tonumber(w), tonumber(h), { resizable = true })
      -- the launcher's desktop window manager would resize it back
      lw.setMode = function() return true end
    end
  end
  local script = os.getenv and os.getenv("POKEPORT_FOLD_TEST")
  if script then
    M.debug = true
    local okd, driver = pcall(function() return love.filesystem.load(DIR .. "dev/driver.lua")() end)
    if okd and driver then driver.start(script, M) end
  end
  backend:update(0)
end
M.backend = backend

M.state = state
return M
