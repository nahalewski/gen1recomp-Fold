
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local Kit = require("src.ui.kit.Kit")
local RomImporter = require("src.import.RomImporter")
local View = require("src.import.LauncherView")

local function freshImporter()
  Kit.focusId = nil
  Kit._navQueue = nil
  return setmetatable({
    isNX = false,
    _padCursor = { x = 100, y = 100 },
    _padCursorActive = false,
    _padAxis = { leftx = 0, lefty = 0, righty = 0 },
    _padDir = {},
    _rawHatDirs = {},
    _padInited = true,
    _flex = false,
    tab = "red",
  }, RomImporter)
end


do
  local imp = freshImporter()
  Kit._ringShown = true
  Kit.focusId = "play-red"
  imp:touchpressed(1, 10, 10, 0, 0, 1)
  check(Kit._ringShown == false, "a touch clears the focus ring")
  eq(Kit.focusId, "play-red", "but the ring keeps its parked id for the pad")

  Kit.navigate("down")
  Kit._navQueue = nil
  check(Kit._ringShown == true, "a d-pad step brings the ring back")

  imp:mousepressed(10, 10, 1)
  check(Kit._ringShown == false, "a left click clears the focus ring")

  Kit.navigate("up")
  Kit._navQueue = nil
  imp:mousepressed(10, 10, 2)
  check(Kit._ringShown == false,
    "a non-primary click is still a pointer, so it clears the ring too")

  Kit.setFocus("play-red")
  check(Kit._ringShown == true, "an explicit setFocus re-arms the ring")
end

do
  Kit.scale = 1
  Kit.blockClicks = false
  Kit.focusId = nil
  Kit.beginFrame(0, 0, false, 0)
  Kit.focusable("tab-red", 10, 60, 40, 24)
  Kit.focusable("play-red", 20, 200, 120, 200)
  Kit.focusable("manage-red", 150, 200, 34, 34)
  Kit.endFrame()
  eq(Kit.focusId, "play-red",
    "with no rom- button on the panel the ring parks on the cart")
end


local function hullContains(flat, px, py)
  local n = #flat / 2
  local pos, neg = false, false
  for i = 1, n do
    local ax, ay = flat[i * 2 - 1], flat[i * 2]
    local j = i % n + 1
    local bx, by = flat[j * 2 - 1], flat[j * 2]
    local cross = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
    if cross > 1e-9 then pos = true elseif cross < -1e-9 then neg = true end
  end
  return not (pos and neg)
end

do
  local front = { { 0, 0 }, { 100, 0 }, { 100, 200 }, { 0, 200 } }
  local back = { { 14, -9 }, { 114, -9 }, { 114, 191 }, { 14, 191 } }
  local flat = View.cartHull({ front, back })
  check(type(flat) == "table" and #flat >= 8,
    "the silhouette of an extruded box is a polygon")
  local worst = nil
  for _, q in ipairs({ front, back }) do
    for _, p in ipairs(q) do
      if not hullContains(flat, p[1], p[2]) then worst = p end
    end
  end
  eq(worst, nil, "every projected corner sits inside the silhouette")
  check(not hullContains(flat, 130, 100),
    "and the silhouette does not swallow the whole panel")
end


do
  local realTime = Kit.time
  local TAU = 6.2831853
  Kit.time = 987654.321
  local tw, band, wave = View.cartFinishPhases(4096 * math.pi)
  check(tw >= 0 and tw < TAU + 1e-9,
    "a day of uptime still reaches the shader as one turn of twinkle phase")
  check(band >= 0 and band < 1 + 1e-9,
    "and as one cycle of hue band phase")
  check(wave >= 0 and wave < TAU + 1e-9,
    "and as one turn of interference phase")

  Kit.time = 9876.54321
  local spin = 48 * math.pi
  tw, band, wave = View.cartFinishPhases(spin)
  local rawTw = Kit.time * 2.6 + spin * 3.0
  check(math.abs(math.sin(tw) - math.sin(rawTw)) < 1e-6,
    "the twinkle wrap is a whole period, so the flecks never jump")
  local rawBand = Kit.time * 0.06 + spin * 0.55
  check(math.abs(math.cos(TAU * band) - math.cos(TAU * rawBand)) < 1e-3,
    "the hue wrap is a whole cycle, so the sweep never jumps")
  local rawWave = Kit.time * 0.9
  check(math.abs(math.sin(wave) - math.sin(rawWave)) < 1e-6,
    "the interference wrap is a whole period")
  Kit.time = realTime
end


do
  local src = View.CART_HOVER_SHADER
  check(not src:find("sin(dot(", 1, true),
    "no screen-space dot product is fed to sin(): GLSL ES leaves that undefined")
  check(src:find("mod(floor(cell), 512.0)", 1, true) ~= nil,
    "the fleck cell id is bounded before it reaches the hash")
  check(not src:find("precision%s+%a+%s+float%s*;"),
    "no default precision statement: LOVE parses effect()'s prototype under mediump before user code")
  check(not src:find("precision%s+%a+%s+int%s*;"),
    "and no default int precision statement either")
  check(src:find("varying CART_HP vec2 cart_screen_pos", 1, true) ~= nil,
    "the sparkle input is a varying the vertex stage writes in highp")
  check(src:find("sparkle(cart_screen_pos)", 1, true) ~= nil,
    "and the sparkle reads that varying, not the mediump screen_coords")
  check(src:find("!defined(GL_FRAGMENT_PRECISION_HIGH)", 1, true) ~= nil,
    "highp is only named where the fragment stage offers it")
  check(src:find("vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)", 1, true) ~= nil,
    "effect() keeps the unqualified parameter list LOVE's prototype was parsed with")
  local vertexBlock = src:match("#ifdef VERTEX(.-)#endif")
  check(vertexBlock and vertexBlock:find("extern vec2 mouse_screen_pos;", 1, true) ~= nil,
    "the hover uniforms live in the vertex stage only")
  check(not src:find("smoothstep(0.13, 0.0,", 1, true),
    "smoothstep is never called with edge0 > edge1")
  check(src:find("pow(max(tw, 0.0), 16.0)", 1, true) ~= nil,
    "pow() never sees a negative base")
  check(not src:find("finish_time", 1, true),
    "the raw wall clock never reaches the shader")
  check(src:find("h = fract(h * (h + 47.13));", 1, true) ~= nil
    and src:find("h = fract(h * (h + 19.77));", 1, true) ~= nil,
    "the fleck hash is the one mirrored below")
end


local function fract(x) return x - math.floor(x) end

local function mediump(x)
  if x == 0 then return 0 end
  local m, e = math.frexp(x)
  return math.ldexp(math.floor(m * 1024 + 0.5) / 1024, e)
end

local function sparkHash(x, y, q)
  local h = q(fract(q(q(x * 0.1031) + q(y * 0.3711)) + 0.137))
  h = q(fract(q(h * q(h + 47.13))))
  h = q(fract(q(h * q(h + 19.77))))
  return h
end

local function oldHash(x, y, q)
  return q(fract(q(math.sin(q(x * 41.7321 + y * 289.113)) * 43758.5453)))
end

local function spread(fn, q)
  local seen = {}
  for iy = 0, 129 do
    for ix = 0, 57 do
      seen[math.floor(fn(ix, iy, q) * 64)] = true
    end
  end
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  return n
end

local function exact(x) return x end

do
  check(spread(sparkHash, exact) >= 60,
    "the fleck hash fills its range at full precision")
  check(spread(sparkHash, mediump) > 32,
    "and still fills it at mediump, so the flecks stay scattered")
  check(spread(oldHash, mediump) < 10,
    "the sin() hash it replaced collapses at mediump into the reported grid")
end

T.finish("launcher_cart_ring_bug2003")
