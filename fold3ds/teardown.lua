-- The teardown Easter egg on the cover screen.  Shake the closed phone hard
-- enough, often enough, and the top cover pops off: the parts inside spill
-- out across the screen (seen from above, like a console opened on a
-- table), and the player puts them back into the shell and the cover back
-- on.  Settings > Shell & Controls turns it off.
--
--   * tap a part to turn it over; it only goes back in the side that faces
--     the cover up (the side in teardown_parts_back.png)
--   * drag it near its place in the shell and let go: it snaps in; a part
--     already in can be pulled back out
--   * the ribbon cables bend as they are dragged and flung
--   * each speaker has a sound of its own (a random one of the app's), played
--     when it is tapped or knocked into the screen's edge
--   * the LCD's face shows the AeonDX boot on a glitchy loop
--   * the cover waits at the fold's opening edge; once everything is back in
--     it slides back on and the lid is whole again
--   * the screen's rotation is locked while it is apart
--
-- Art: fold3ds/teardown/ (tools/make_teardown_sprites.py).  Scene units are
-- the pixels of inside.png, the shell with its parts in, drawn the way the
-- closed lid is (turned on its side on a portrait screen).
local T = {}

local lg = love.graphics
local DIR = "fold3ds/teardown/"

-- where the shell is in inside.png (the opaque box: the rim and the hinge)
local SHELL = { x = 35, y = 140, w = 1380, h = 775 }
-- loose parts: the part sheets' pixels are this much smaller than inside.png's
local PS = 1.2

-- every part: its kind (which places it fits), and its place in inside.png
local PARTS = {
  { id = "lcd", kind = "lcd", slot = { 266, 226, 1188, 732 } },
  { id = "speaker_l", kind = "speaker", slot = { 98, 212, 252, 598 }, speaker = true },
  { id = "speaker_r", kind = "speaker", slot = { 1208, 212, 1362, 598 }, speaker = true },
  { id = "camera_l", kind = "camera", slot = { 480, 158, 600, 240 } },
  { id = "camera_r", kind = "camera", slot = { 850, 158, 970, 240 } },
  { id = "ircam", kind = "ircam", slot = { 632, 160, 806, 226 } },
  { id = "ribbon_l", kind = "ribbon_l", slot = { 66, 495, 300, 805 }, ribbon = "v" },
  { id = "ribbon_r", kind = "ribbon_r", slot = { 1160, 598, 1292, 805 }, ribbon = "v" },
  { id = "ribbon_long", kind = "ribbon_long", slot = { 652, 726, 1240, 808 }, ribbon = "h" },
  { id = "foam_1", kind = "foam", slot = { 406, 728, 484, 804 } },
  { id = "foam_2", kind = "foam", slot = { 482, 728, 662, 804 } },
  { id = "bracket_1", kind = "bracket", slot = { 88, 678, 162, 768 } },
  { id = "bracket_2", kind = "bracket", slot = { 176, 636, 252, 712 } },
  { id = "bracket_3", kind = "bracket", slot = { 1250, 690, 1332, 782 } },
  { id = "bracket_4", kind = "bracket", slot = { 190, 705, 240, 752 } },
  { id = "bracket_5", kind = "bracket", slot = { 1255, 640, 1300, 700 } },
  { id = "bracket_6", kind = "bracket", slot = { 664, 718, 784, 798 } },
  { id = "screw_1", kind = "screw", slot = { 165, 170, 205, 210 } },
  { id = "screw_2", kind = "screw", slot = { 1242, 170, 1282, 210 } },
  { id = "screw_3", kind = "screw", slot = { 90, 435, 130, 475 } },
  { id = "screw_4", kind = "screw", slot = { 208, 435, 248, 475 } },
  { id = "screw_5", kind = "screw", slot = { 1202, 435, 1242, 475 } },
  { id = "screw_6", kind = "screw", slot = { 1316, 435, 1356, 475 } },
}
-- the LCD's glass on its face (lcd_b.png pixels): where the boot loops
local GLASS = { 54, 29, 706, 333 }

-- shaking: this many hard shakes inside WINDOW seconds pops the cover
local SHAKES, WINDOW, HARD = 8, 5, 26

local ctx = {}
local st = {
  on = false, phase = nil, t0 = 0, parts = nil, slots = nil, cover = nil,
  shakes = {}, wobbleAt = -10, drag = {}, msg = nil, msgAt = -10,
}
local img, data, quads = {}, {}, {}
local trySnap, solve   -- (the touch section's; update() reaches them too)

local function now() return love.timer.getTime() end
local function clamp(x, a, b) return x < a and a or (x > b and b or x) end
local function ease(x) x = clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end

local function load(name)
  if img[name] == nil then
    local ok, i = pcall(lg.newImage, DIR .. name .. ".png")
    img[name] = ok and i or false
    if ok then i:setFilter("linear", "linear") end
  end
  return img[name] or nil
end

local function alphaData(name)
  if data[name] == nil then
    local ok, d = pcall(love.image.newImageData, DIR .. name .. ".png")
    data[name] = ok and d or false
  end
  return data[name] or nil
end

---------------------------------------------------------------- the sounds
-- every sound the app has, for the speakers to pick from
local soundList
local function sounds()
  if soundList then return soundList end
  soundList = {}
  local fs = love.filesystem
  local function walk(dir, depth)
    if depth > 5 or #soundList > 400 then return end
    local ok, items = pcall(fs.getDirectoryItems, dir)
    if not ok then return end
    for _, it in ipairs(items) do
      local p = dir .. "/" .. it
      local info = fs.getInfo(p)
      if info and info.type == "directory" then walk(p, depth + 1)
      elseif it:lower():match("%.ogg$") or it:lower():match("%.wav$") or it:lower():match("%.mp3$") then
        soundList[#soundList + 1] = p
      end
    end
  end
  walk("fold3ds/sounds", 0)
  walk("sounds", 0)
  return soundList
end

local function playSpeaker(p)
  if not p.sound then return end
  if p.src then pcall(function() p.src:stop() end) end
  local ok, src = pcall(love.audio.newSource, p.sound, "static")
  if not ok then return end
  p.src = src
  src:setVolume(ctx.volume and ctx.volume() or 1)
  pcall(src.play, src)
end

---------------------------------------------------------------- the rotation lock
-- Activity.setRequestedOrientation(SCREEN_ORIENTATION_LOCKED) through JNI,
-- as src/core/Orientation.lua does for its modes; unlocking hands back to
-- ctx.unlock (the app's own orientation)
local lockFfi
local function setRequested(value)
  if love.system.getOS() ~= "Android" then return end
  pcall(function()
    local ffi = require("ffi")
    if not lockFfi then
      pcall(ffi.cdef, "typedef union { int32_t i; int64_t pad; } aeondx_jvalue;")
      pcall(ffi.cdef, "void *SDL_AndroidGetJNIEnv(void);")
      pcall(ffi.cdef, "void *SDL_AndroidGetActivity(void);")
      lockFfi = ffi
    end
    local env = ffi.C.SDL_AndroidGetJNIEnv()
    local activity = ffi.C.SDL_AndroidGetActivity()
    if env == nil or activity == nil then return end
    local fns = ffi.cast("void***", env)[0]
    local getObjectClass = ffi.cast("void *(*)(void *, void *)", fns[31])
    local getMethodID = ffi.cast("void *(*)(void *, void *, const char *, const char *)", fns[33])
    local callVoidMethodA = ffi.cast("void (*)(void *, void *, void *, aeondx_jvalue *)", fns[63])
    local deleteLocalRef = ffi.cast("void (*)(void *, void *)", fns[23])
    local exceptionClear = ffi.cast("void (*)(void *)", fns[17])
    local cls = getObjectClass(env, activity)
    if cls ~= nil then
      local mid = getMethodID(env, cls, "setRequestedOrientation", "(I)V")
      if mid ~= nil then
        local args = ffi.new("aeondx_jvalue[1]")
        args[0].pad = 0
        args[0].i = value
        callVoidMethodA(env, activity, mid, args)
      end
      exceptionClear(env)
      deleteLocalRef(env, cls)
    end
    deleteLocalRef(env, activity)
  end)
end

---------------------------------------------------------------- the view
-- where the scene sits on a W x H screen (the lid's own fit and turn)
local function view(W, H)
  local portrait = H > W * 1.1
  local aw, ah = W, H
  if portrait then aw, ah = H, W end
  -- the closed lid's own size (drawLidIn), so the cover lands where the lid is
  local lb = ctx.lidBox or { 0, 0, SHELL.w, SHELL.h }
  local s = math.min(aw / lb[3], ah / lb[4]) * 0.98 * lb[3] / SHELL.w
  local ox, oy = (aw - SHELL.w * s) / 2, (ah - SHELL.h * s) / 2
  local v = { W = W, H = H, portrait = portrait, s = s, ox = ox, oy = oy, aw = aw, ah = ah }
  -- the scene's visible bounds
  v.u0, v.u1 = SHELL.x - ox / s, SHELL.x + (aw - ox) / s
  v.v0, v.v1 = SHELL.y - oy / s, SHELL.y + (ah - oy) / s
  st.view = v
  return v
end

local function toScene(x, y)
  local v = st.view
  if not v then return x, y end
  local X, Y = x, y
  if v.portrait then X, Y = y, v.W - x end
  return (X - v.ox) / v.s + SHELL.x, (Y - v.oy) / v.s + SHELL.y
end

local function slotCentre(sl) return (sl[1] + sl[3]) / 2, (sl[2] + sl[4]) / 2 end

---------------------------------------------------------------- the parts
local function newParts()
  local list, snd = {}, sounds()
  for i, P in ipairs(PARTS) do
    local a = load(P.id .. "_a")
    local w, h = a and a:getWidth() or 40, a and a:getHeight() or 40
    local cx, cy = slotCentre(P.slot)
    local p = {
      def = P, id = P.id, kind = P.kind, w = w * PS, h = h * PS, iw = w, ih = h,
      x = cx, y = cy, vx = 0, vy = 0, rot = 0, spin = 0, z = 1,
      side = "a", flip = nil, placed = nil, tween = nil, order = i,
      bend = {}, bendV = {},
    }
    if P.speaker and #snd > 0 then p.sound = snd[love.math.random(#snd)] end
    list[#list + 1] = p
  end
  return list
end

local function slotsFree()
  local used = {}
  for _, p in ipairs(st.parts) do if p.placed then used[p.def] = true end end
  return used
end

local function allIn()
  for _, p in ipairs(st.parts) do
    if not p.placed or p.tween then return false end
  end
  return true
end

local function say(text) st.msg, st.msgAt = text, now() end

-- ribbons: a bend along their length, a spring chain the part's own
-- sideways acceleration (and the finger holding one end) swings
local SEG = 12
local function bendStep(p, dt, ax, ay)
  if not p.def.ribbon then return end
  -- the acceleration across the ribbon, in its own frame
  local c, s = math.cos(-p.rot), math.sin(-p.rot)
  local lx, ly = ax * c - ay * s, ax * s + ay * c
  local across = p.def.ribbon == "v" and lx or ly
  local len = p.def.ribbon == "v" and p.h or p.w
  local grab = p.grabT or 0.5
  for i = 0, SEG do
    local t = i / SEG
    local o, ov = p.bend[i] or 0, p.bendV[i] or 0
    local w = math.abs(t - grab) * 2
    local acc = -140 * o - 7 * ov - across * w * 0.035
    ov = ov + acc * dt
    o = clamp(o + ov * dt, -len * 0.22, len * 0.22)
    p.bend[i], p.bendV[i] = o, ov
  end
end

local function ribbonMesh(p, tex)
  local key = p.id .. p.side
  p.meshes = p.meshes or {}
  local m = p.meshes[key]
  if not m then
    local ok, mm = pcall(lg.newMesh, (SEG + 1) * 2, "strip", "stream")
    if not ok then return nil end
    m = mm
    m:setTexture(tex)
    p.meshes[key] = m
  end
  local w, h = p.iw, p.ih
  for i = 0, SEG do
    local t = i / SEG
    local o = (p.bend[i] or 0) / PS
    if p.def.ribbon == "v" then
      local y = -h / 2 + t * h
      m:setVertex(i * 2 + 1, -w / 2 + o, y, 0, t, 1, 1, 1, 1)
      m:setVertex(i * 2 + 2, w / 2 + o, y, 1, t, 1, 1, 1, 1)
    else
      local x = -w / 2 + t * w
      m:setVertex(i * 2 + 1, x, -h / 2 + o, t, 0, 1, 1, 1, 1)
      m:setVertex(i * 2 + 2, x, h / 2 + o, t, 1, 1, 1, 1, 1)
    end
  end
  return m
end

---------------------------------------------------------------- start / end
function T.init(context) for k, v in pairs(context or {}) do ctx[k] = v end end
function T.active() return st.on end

function T.start()
  if st.on then return end
  st.on, st.phase, st.t0 = true, "lift", now()
  st.parts = newParts()
  st.cover = { x = SHELL.x + SHELL.w / 2, y = SHELL.y + SHELL.h / 2, rot = 0, z = 0, resting = false }
  st.drag, st.msg = {}, nil
  setRequested(14)   -- SCREEN_ORIENTATION_LOCKED
  if ctx.sfx then ctx.sfx("launch") end
end

local function finish()
  st.on, st.phase = false, nil
  for _, p in ipairs(st.parts or {}) do
    if p.src then pcall(function() p.src:stop() end) end
  end
  st.parts, st.cover = nil, nil
  st.shakes = {}
  if ctx.unlock then pcall(ctx.unlock) end
  if ctx.sfx then ctx.sfx("click") end
end

---------------------------------------------------------------- shaking
-- fed the accelerometer (m/s^2) every frame while the lid is shut
function T.feed(ax, ay, az)
  if st.on or not ax then return end
  local m = math.sqrt(ax * ax + ay * ay + (az or 0) ^ 2)
  local t = now()
  if m < HARD or t - (st.lastShake or -1) < 0.16 then return end
  st.lastShake = t
  local keep = {}
  for _, s in ipairs(st.shakes) do if t - s < WINDOW then keep[#keep + 1] = s end end
  keep[#keep + 1] = t
  st.shakes = keep
  st.wobbleAt = t
  if ctx.sfx then ctx.sfx("over") end
  if #keep >= SHAKES then T.start() end
end

-- the shut lid shaking loose: an offset and a turn for its drawing
function T.wobble()
  local age = now() - st.wobbleAt
  if age > 0.35 then return 0, 0, 0 end
  local k = (1 - age / 0.35) * math.min(1, #st.shakes / SHAKES) * 10
  local t = now() * 60
  return math.sin(t) * k, math.cos(t * 1.3) * k * 0.6, math.sin(t * 0.7) * k * 0.004
end

---------------------------------------------------------------- update
local function coverRest(v)
  -- at the fold's opening edge (the scene's top), most of it off screen
  return SHELL.x + SHELL.w / 2, v.v0 - SHELL.h * 0.5 + SHELL.h * 0.2
end

local function update(dt)
  local v = st.view
  if not v then return end
  local t = now() - st.t0
  local c = st.cover
  if st.phase == "lift" then
    c.z = ease(t / 0.35) * 0.08
    if t > 0.35 then st.phase = "fly" end
  end
  if st.phase == "fly" or st.phase == "lift" then
    local ft = (t - 0.35) / 0.55
    if ft > 0 then
      local rx, ry = coverRest(v)
      local e = ease(ft)
      c.x = SHELL.x + SHELL.w / 2 + (rx - SHELL.x - SHELL.w / 2) * e
      c.y = SHELL.y + SHELL.h / 2 + (ry - SHELL.y - SHELL.h / 2) * e
      c.rot = math.sin(ft * math.pi) * 0.35
      c.z = 0.08 * (1 - e)
    end
    -- the parts spill as the cover comes away
    if t > 0.45 and not st.spilled then
      st.spilled = true
      local cx, cy = SHELL.x + SHELL.w / 2, SHELL.y + SHELL.h / 2
      for _, p in ipairs(st.parts) do
        local dx, dy = p.x - cx, p.y - cy
        local d = math.max(1, math.sqrt(dx * dx + dy * dy))
        local sp = 500 + love.math.random() * 900
        p.vx = dx / d * sp + (love.math.random() - 0.5) * 700
        p.vy = dy / d * sp + (love.math.random() - 0.5) * 700
        p.spin = (love.math.random() - 0.5) * 7
        p.z = 1
      end
    end
    if ft >= 1 then st.phase, c.resting = "play", true end
  end
  if st.phase == "close" then
    local k = ease((now() - st.closeAt) / 0.35)
    c.x = c.fx + (SHELL.x + SHELL.w / 2 - c.fx) * k
    c.y = c.fy + (SHELL.y + SHELL.h / 2 - c.fy) * k
    c.rot = c.frot * (1 - k)
    c.z = 0.05 * (1 - k)
    if k >= 1 then finish() return end
  end
  -- the cover, let go of: back to its rest
  if st.phase == "play" and not c.held then
    local rx, ry = coverRest(v)
    c.x = c.x + (rx - c.x) * math.min(1, dt * 8)
    c.y = c.y + (ry - c.y) * math.min(1, dt * 8)
    c.rot = c.rot * (1 - math.min(1, dt * 8))
  end
  if not st.spilled then return end
  if st.solveAt and now() > st.solveAt then solve() end
  -- the parts: sliding, spinning, slowing on the "table", off the edges
  for _, p in ipairs(st.parts) do
    local ovx, ovy = p.vx, p.vy
    if p.tween then
      local k = ease((now() - p.tween.at) / 0.22)
      local tw = p.tween
      p.x = tw.x + (tw.tx - tw.x) * k
      p.y = tw.y + (tw.ty - tw.y) * k
      p.rot = tw.rot * (1 - k)
      p.z = 0
      if k >= 1 then p.tween = nil; if ctx.sfx then ctx.sfx("select") end end
    elseif not p.held and not p.placed then
      p.z = math.max(0, p.z - dt / 0.4)
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.rot = p.rot + p.spin * dt
      local f = math.exp(-(p.z > 0 and 0.6 or 3.2) * dt)
      p.vx, p.vy = p.vx * f, p.vy * f
      p.spin = p.spin * math.exp(-2.4 * dt)
      local r = math.min(p.w, p.h) * 0.4
      local bumped
      if p.x < v.u0 + r then p.x, p.vx, bumped = v.u0 + r, math.abs(p.vx) * 0.45, math.abs(p.vx) end
      if p.x > v.u1 - r then p.x, p.vx, bumped = v.u1 - r, -math.abs(p.vx) * 0.45, math.abs(p.vx) end
      if p.y < v.v0 + r then p.y, p.vy, bumped = v.v0 + r, math.abs(p.vy) * 0.45, math.abs(p.vy) end
      if p.y > v.v1 - r then p.y, p.vy, bumped = v.v1 - r, -math.abs(p.vy) * 0.45, math.abs(p.vy) end
      if bumped then
        p.spin = p.spin + (love.math.random() - 0.5) * 3
        if p.def.speaker and bumped > 380 and now() - (p.knockAt or 0) > 0.6 then
          p.knockAt = now()
          playSpeaker(p)
        end
      end
    end
    local ax, ay = 0, 0
    if dt > 0 then ax, ay = (p.vx - ovx) / dt, (p.vy - ovy) / dt end
    if p.held then ax, ay = p.hax or 0, p.hay or 0 end
    bendStep(p, dt, ax, ay)
    if p.flip then
      p.flip.k = (now() - p.flip.at) / 0.3
      if p.flip.k >= 0.5 and not p.flip.swapped then
        p.flip.swapped = true
        p.side = p.side == "a" and "b" or "a"
      end
      if p.flip.k >= 1 then p.flip = nil end
    end
  end
end

---------------------------------------------------------------- drawing
-- the LCD's face: the top screen's boot on a loop, glitching
local function glassCanvas()
  if not ctx.bootTop then return nil end
  local c = st.glass
  if not c then
    local ok, cc = pcall(lg.newCanvas, 400, 240)
    if not ok then return nil end
    c = cc
    st.glass = c
  end
  local t = (now() - st.t0) % 4.2
  local prev = lg.getCanvas()
  lg.push("all")
  lg.origin()
  lg.setScissor()
  ;(ctx.setCanvas or lg.setCanvas)(c)
  lg.clear(0, 0, 0, 1)
  pcall(ctx.bootTop, { x = 0, y = 0, w = 400, h = 240 }, 0.9 + t)
  ;(ctx.setCanvas or lg.setCanvas)(prev)
  lg.pop()
  return c
end

local function drawGlass(p)
  local c = glassCanvas()
  if not c then return end
  local gx, gy = GLASS[1] - p.iw / 2, GLASS[2] - p.ih / 2
  local gw, gh = GLASS[3] - GLASS[1], GLASS[4] - GLASS[2]
  local sx, sy = gw / 400, gh / 240
  local t = now()
  -- a burst every so often: bands thrown sideways, the colours apart
  local rng = love.math.newRandomGenerator(math.floor(t * 12))
  local function rnd() return rng:random() end
  local burst = rnd() < 0.28
  local split = burst and (2 + rnd() * 6) or 0.8
  local bands = 10
  for i = 0, bands - 1 do
    local off = 0
    if burst and rnd() < 0.4 then off = (rnd() - 0.5) * gw * 0.12 end
    quads["band" .. i] = quads["band" .. i] or lg.newQuad(0, i * 240 / bands, 400, 240 / bands, 400, 240)
    local q = quads["band" .. i]
    local y = gy + i * gh / bands
    lg.setColor(1, 1, 1, 1)
    lg.draw(c, q, gx + off, y, 0, sx, sy)
    lg.setBlendMode("add")
    lg.setColor(0.6, 0, 0.1, 0.5)
    lg.draw(c, q, gx + off + split, y, 0, sx, sy)
    lg.setColor(0, 0.25, 0.6, 0.5)
    lg.draw(c, q, gx + off - split, y, 0, sx, sy)
    lg.setBlendMode("alpha")
  end
  -- scanlines, and a rolling bar
  lg.setColor(0, 0, 0, 0.22)
  for y = gy, gy + gh, 4 do lg.rectangle("fill", gx, y, gw, 1.5) end
  local roll = (t * 0.35) % 1
  lg.setColor(1, 1, 1, 0.05)
  lg.rectangle("fill", gx, gy + roll * gh, gw, gh * 0.08)
  if burst and rnd() < 0.5 then
    lg.setColor(1, 1, 1, 0.25)
    lg.rectangle("fill", gx + rnd() * gw * 0.8, gy + rnd() * gh, gw * (0.05 + rnd() * 0.2), 2 + rnd() * 6)
  end
end

local function drawPart(p)
  local tex = load(p.id .. "_" .. p.side)
  if not tex then return end
  local fx = 1
  if p.flip then fx = math.max(0.04, math.abs(math.cos(math.pi * p.flip.k))) end
  local lift = 1 + 0.25 * p.z + (p.held and 0.06 or 0)
  -- the shadow on the table
  local sh = 6 + 30 * p.z + (p.held and 14 or 0)
  lg.push()
  lg.translate(p.x + sh, p.y + sh)
  lg.rotate(p.rot)
  lg.scale(PS * lift * fx, PS * lift)
  lg.setColor(0, 0, 0, 0.35)
  if p.def.ribbon then
    local m = ribbonMesh(p, tex)
    if m then lg.draw(m) end
  else
    lg.draw(tex, -p.iw / 2, -p.ih / 2)
  end
  lg.pop()
  lg.push()
  lg.translate(p.x, p.y)
  lg.rotate(p.rot)
  lg.scale(PS * lift * fx, PS * lift)
  lg.setColor(1, 1, 1, 1)
  if p.def.ribbon then
    local m = ribbonMesh(p, tex)
    if m then lg.draw(m) end
  else
    lg.draw(tex, -p.iw / 2, -p.ih / 2)
  end
  if p.id == "lcd" and p.side == "b" then drawGlass(p) end
  lg.pop()
end

-- a part's place in the shell: the photo's own pixels once it is in, a
-- dark bay while it is out
local function drawSlot(p, inside)
  local sl = p.def.slot
  local x, y, w, h = sl[1], sl[2], sl[3] - sl[1], sl[4] - sl[2]
  if p.placed and not p.tween then
    local key = "slot:" .. p.def.id
    quads[key] = quads[key] or lg.newQuad(x, y, w, h, inside:getDimensions())
    lg.setColor(1, 1, 1, 1)
    lg.draw(inside, quads[key], x, y)
  else
    lg.setColor(0.05, 0.05, 0.06, 0.94)
    lg.rectangle("fill", x, y, w, h, 8, 8)
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("fill", x + 3, y + h - 6, w - 6, 3, 2, 2)
    local glow = allIn() and 0 or 0.25 + 0.15 * math.sin(now() * 3 + p.order)
    lg.setColor(0.55, 0.8, 1, glow)
    lg.setLineWidth(2)
    lg.rectangle("line", x + 2, y + 2, w - 4, h - 4, 7, 7)
  end
end

local function drawCover(c)
  local lid = ctx.lidImage and ctx.lidImage()
  local box = ctx.lidBox
  if not (lid and box) then return end
  quads.lid = quads.lid or lg.newQuad(box[1], box[2], box[3], box[4], lid:getDimensions())
  local k = SHELL.w / box[3]
  local lift = 1 + c.z
  local sh = 10 + 200 * c.z
  lg.push()
  lg.translate(c.x + sh * 0.5, c.y + sh)
  lg.rotate(c.rot)
  lg.scale(k * lift, k * lift)
  lg.setColor(0, 0, 0, 0.4)
  lg.draw(lid, quads.lid, -box[3] / 2, -box[4] / 2)
  lg.pop()
  lg.push()
  lg.translate(c.x, c.y)
  lg.rotate(c.rot)
  lg.scale(k * lift, k * lift)
  lg.setColor(1, 1, 1, 1)
  lg.draw(lid, quads.lid, -box[3] / 2, -box[4] / 2)
  -- once everything is in: its edge glows to be slid back on
  if st.phase == "play" and allIn() then
    lg.setColor(0.4, 0.85, 1, 0.35 + 0.3 * math.sin(now() * 4))
    lg.setLineWidth(8 / k)
    lg.rectangle("line", -box[3] / 2, -box[4] / 2, box[3], box[4], 60, 60)
  end
  lg.pop()
end

function T.draw(W, H, dt)
  local v = view(W, H)
  update(dt or love.timer.getDelta())
  if not st.on then return false end
  local inside = load("inside")
  lg.push("all")
  lg.setColor(0.07, 0.07, 0.08, 1)
  lg.rectangle("fill", 0, 0, W, H)
  if ctx.drawWall then pcall(ctx.drawWall, W, H) end
  -- the screen's own shake as the cover pops
  local t = now() - st.t0
  local jx, jy = 0, 0
  if t < 0.6 then
    local k = (1 - t / 0.6) * 10
    jx, jy = math.sin(t * 90) * k, math.cos(t * 70) * k
  end
  lg.push()
  lg.translate(jx, jy)
  if v.portrait then
    lg.translate(W, 0)
    lg.rotate(math.pi / 2)
  end
  lg.translate(v.ox, v.oy)
  lg.scale(v.s, v.s)
  lg.translate(-SHELL.x, -SHELL.y)
  -- the shell
  if inside then
    lg.setColor(1, 1, 1, 1)
    lg.draw(inside, 0, 0)
    -- its bays, the big ones under the small ones
    local order = {}
    for _, p in ipairs(st.parts) do order[#order + 1] = p end
    table.sort(order, function(a, b)
      local sa, sb = a.def.slot, b.def.slot
      return (sa[3] - sa[1]) * (sa[4] - sa[2]) > (sb[3] - sb[1]) * (sb[4] - sb[2])
    end)
    if st.spilled then for _, p in ipairs(order) do drawSlot(p, inside) end end
  end
  -- the loose parts (and the ones still snapping in), the held one on top
  local loose = {}
  for _, p in ipairs(st.parts) do
    if not p.placed or p.tween then loose[#loose + 1] = p end
  end
  table.sort(loose, function(a, b) return (a.top or a.order) < (b.top or b.order) end)
  for _, p in ipairs(loose) do drawPart(p) end
  drawCover(st.cover)
  lg.pop()
  -- what to do, now and then
  local msg = st.msg
  if not msg and st.phase == "play" then
    if allIn() then msg = "Slide the cover back on" end
  end
  if msg and ctx.font then
    local age = st.msg and now() - st.msgAt or 0
    if st.msg and age > 2 then st.msg = nil
    else
      local f = ctx.font(math.min(W, H) * 0.045)
      lg.setFont(f)
      local a = st.msg and math.min(1, (2 - age) / 0.4) or (0.6 + 0.4 * math.sin(now() * 3))
      local tw = f:getWidth(msg) + f:getHeight() * 1.2
      local x, y = (W - tw) / 2, H * 0.9
      lg.setColor(0, 0, 0, 0.6 * a)
      lg.rectangle("fill", x, y - f:getHeight() * 0.3, tw, f:getHeight() * 1.6, 8, 8)
      lg.setColor(1, 1, 1, a)
      lg.printf(msg, x, y, tw, "center")
    end
  end
  lg.pop()
  return true
end

---------------------------------------------------------------- touch
local function hitPart(p, u, v)
  local dx, dy = u - p.x, v - p.y
  local c, s = math.cos(-p.rot), math.sin(-p.rot)
  local lx, ly = dx * c - dy * s, dx * s + dy * c
  local px, py = lx / PS + p.iw / 2, ly / PS + p.ih / 2
  local pad = math.max(0, 28 - math.min(p.iw, p.ih) / 2)   -- screws are small
  if px < -pad or py < -pad or px > p.iw + pad or py > p.ih + pad then return false end
  if pad > 0 then return true end
  local d = alphaData(p.id .. "_a")
  if not d then return true end
  local ok, _, _, _, a = pcall(d.getPixel, d, clamp(math.floor(px), 0, p.iw - 1), clamp(math.floor(py), 0, p.ih - 1))
  return not ok or a > 0.25
end

local function inSlot(p, u, v)
  local sl = p.def.slot
  return u >= sl[1] and v >= sl[2] and u <= sl[3] and v <= sl[4]
end

local topN = 1000
local function pick(u, v)
  -- the loose parts, the top one first
  local loose = {}
  for _, p in ipairs(st.parts) do if not p.placed then loose[#loose + 1] = p end end
  table.sort(loose, function(a, b) return (a.top or a.order) > (b.top or b.order) end)
  for _, p in ipairs(loose) do if hitPart(p, u, v) then return p end end
  -- then the ones in the shell, the small ones first (to pull back out)
  local placed = {}
  for _, p in ipairs(st.parts) do if p.placed and not p.tween then placed[#placed + 1] = p end end
  table.sort(placed, function(a, b)
    local sa, sb = a.def.slot, b.def.slot
    return (sa[3] - sa[1]) * (sa[4] - sa[2]) < (sb[3] - sb[1]) * (sb[4] - sb[2])
  end)
  for _, p in ipairs(placed) do if inSlot(p, u, v) then return p end end
end

local function hitCover(u, v)
  local c = st.cover
  local dx, dy = u - c.x, v - c.y
  return math.abs(dx) < SHELL.w / 2 and math.abs(dy) < SHELL.h / 2
end

function T.pressed(id, x, y)
  if not st.on or st.phase ~= "play" then return end
  local u, v = toScene(x, y)
  local p = pick(u, v)
  if p then
    if p.placed then
      p.placed = nil
      p.x, p.y = slotCentre(p.def.slot)
      p.rot, p.z = 0, 0
    end
    topN = topN + 1
    p.top = topN
    p.held = true
    p.vx, p.vy, p.spin = 0, 0, 0
    -- which end of a ribbon is held
    local c, s = math.cos(-p.rot), math.sin(-p.rot)
    local lx, ly = (u - p.x) * c - (v - p.y) * s, (u - p.x) * s + (v - p.y) * c
    if p.def.ribbon == "v" then p.grabT = clamp(ly / p.h + 0.5, 0, 1)
    elseif p.def.ribbon == "h" then p.grabT = clamp(lx / p.w + 0.5, 0, 1) end
    st.drag[id] = { p = p, ox = p.x - u, oy = p.y - v, u0 = u, v0 = v, at = now(), moved = false,
      lu = u, lv = v, lt = now(), vx = 0, vy = 0 }
    return
  end
  if hitCover(u, v) then
    st.cover.held = true
    st.drag[id] = { cover = true, ox = st.cover.x - u, oy = st.cover.y - v, u0 = u, v0 = v }
  end
end

function T.moved(id, x, y)
  local d = st.drag[id]
  if not d then return end
  local u, v = toScene(x, y)
  if math.abs(u - d.u0) + math.abs(v - d.v0) > 14 then d.moved = true end
  if d.cover then
    st.cover.x, st.cover.y = u + d.ox, v + d.oy
    return
  end
  local p = d.p
  local t = now()
  local dt = math.max(1 / 240, t - d.lt)
  local nvx, nvy = (u - d.lu) / dt, (v - d.lv) / dt
  p.hax, p.hay = (nvx - d.vx) / dt * 0.2, (nvy - d.vy) / dt * 0.2
  d.vx, d.vy = d.vx * 0.5 + nvx * 0.5, d.vy * 0.5 + nvy * 0.5
  d.lu, d.lv, d.lt = u, v, t
  p.x, p.y = u + d.ox, v + d.oy
end

trySnap = function(p)
  local free = slotsFree()
  local best, bd
  for _, q in ipairs(st.parts) do
    local sl = q.def.slot
    if q.def.kind == p.kind and not free[q.def] then
      local cx, cy = slotCentre(sl)
      local d = math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
      local reach = math.max(110, 0.45 * math.sqrt((sl[3] - sl[1]) ^ 2 + (sl[4] - sl[2]) ^ 2))
      if d < reach and (not bd or d < bd) then best, bd = q, d end
    end
  end
  if not best then return false end
  if p.side ~= "a" then
    say("Turn it over first")
    p.vx, p.vy = (love.math.random() - 0.5) * 300, (love.math.random() - 0.5) * 300
    return true
  end
  -- a matching place (a screw fits any screw hole): the part takes that
  -- place's photo, so swap which part owns which place
  if best ~= p then best.def, p.def = p.def, best.def end
  local cx, cy = slotCentre(p.def.slot)
  p.placed = true
  p.tween = { at = now(), x = p.x, y = p.y, tx = cx, ty = cy, rot = p.rot }
  return true
end

-- desktop testing (POKEPORT_FOLD_TEARDOWN=solve): every part back in its
-- place after `delay` seconds, through the same snap a drag ends in
function T.autoSolve(delay) st.solveAt = now() + (delay or 2) end
function T.debugFace(id)
  for _, p in ipairs(st.parts or {}) do if p.id == id then p.side = "b" end end
end
solve = function()
  st.solveAt = nil
  for _, p in ipairs(st.parts) do
    if not p.placed then
      p.side, p.flip = "a", nil
      p.x, p.y = slotCentre(p.def.slot)
      trySnap(p)
    end
  end
end

function T.released(id, x, y)
  local d = st.drag[id]
  st.drag[id] = nil
  if not d then return end
  if d.cover then
    local c = st.cover
    c.held = false
    local cx, cy = SHELL.x + SHELL.w / 2, SHELL.y + SHELL.h / 2
    local near = math.abs(c.x - cx) < SHELL.w * 0.35 and math.abs(c.y - cy) < SHELL.h * 0.5
    if near and allIn() then
      st.phase, st.closeAt = "close", now()
      c.fx, c.fy, c.frot, c.held = c.x, c.y, c.rot, true
    elseif near then
      say("Put everything back in first")
    end
    return
  end
  local p = d.p
  p.held, p.hax, p.hay, p.grabT = false, 0, 0, nil
  if not d.moved and now() - d.at < 0.35 then
    -- a tap: turn it over (a speaker plays its sound)
    p.flip = { at = now() }
    if p.def.speaker then playSpeaker(p) end
    if ctx.sfx then ctx.sfx("over") end
    return
  end
  if trySnap(p) then return end
  p.vx, p.vy = clamp(d.vx, -2600, 2600), clamp(d.vy, -2600, 2600)
  p.spin = (love.math.random() - 0.5) * 2
end

return T
