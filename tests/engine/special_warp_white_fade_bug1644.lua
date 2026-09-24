-- #1644: Fly/Teleport special warps fade white (GBFadeOutToWhite /
-- GBFadeInFromWhite), not black door-warp shape.
--
--   luajit tests/engine/special_warp_white_fade_bug1644.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("special warp white fade #1644")
local check, eq = S.check, S.eq

local Timing = require("src.core.Timing")
local Transition = require("src.render.Transition")

local white = { 1, 1, 1 }
local t = Transition.new(nil, function() end, nil, false, {
  color = white,
  frames = Timing.FADE_OUT_TO_WHITE,
  framesIn = Timing.FADE_IN_FROM_WHITE,
})
eq(t.color[1], 1, "special warp veil is white R")
eq(t.color[2], 1, "special warp veil is white G")
eq(t.color[3], 1, "special warp veil is white B")
eq(t.frames, Timing.FADE_OUT_TO_WHITE, "fade out uses FADE_OUT_TO_WHITE")
eq(t.framesIn, Timing.FADE_IN_FROM_WHITE, "fade in uses FADE_IN_FROM_WHITE")

local door = Transition.new(nil, function() end, nil, true)
eq(door.color[1], 0, "door warp stays black")
eq(door.framesIn, 0, "door warp has no fade in")
check(door.frames == Timing.WARP_FADE_OUT, "door warp uses WARP_FADE_OUT")

S.finish()
