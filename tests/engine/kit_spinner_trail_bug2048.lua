package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check = T.check
local Kit = require("src.ui.kit.Kit")

local G = love.graphics
local rec, alpha = {}, 1
local oldSet, oldLine = G.setColor, G.line

G.setColor = function(r, g, b, a) alpha = a or 1 end
G.line = function(_, _, x2, y2)
  rec[#rec + 1] = { a = alpha, ang = math.atan2(y2 - 100, x2 - 100) }
end

local function sample(t)
  rec = {}
  Kit.scale = 1
  Kit.spinner(100, 100, 20, t)
  local head, best = 1, -1
  for i, v in ipairs(rec) do
    if v.a > best then best, head = v.a, i end
  end
  return rec, head
end

local r0, h0 = sample(0.0)
check(#r0 == 12, "the ring is twelve ticks")
local _, h1 = sample(0.1)
check(h1 == (h0 % #r0) + 1, "the bright head advances clockwise one tick")

local ahead = r0[(h0 % #r0) + 1]
local behind = r0[((h0 - 2) % #r0) + 1]
check(behind.a > ahead.a, "the fade trails the head instead of leading it")
check(ahead.a < 0.1, "the tick the head is about to reach is the dimmest")

local prev, monotonic = r0[h0].a, true
for n = 1, #r0 - 1 do
  local v = r0[((h0 - 1 - n) % #r0) + 1]
  if v.a >= prev then monotonic = false end
  prev = v.a
end
check(monotonic, "and keeps falling off all the way round the trail")

G.setColor, G.line = oldSet, oldLine

T.finish("kit spinner trail")
