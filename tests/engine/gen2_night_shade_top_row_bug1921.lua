-- engine/battle_anims/bg_effects.asm:1108 (#1921)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local BgEffects = require("src.battle.gen2.BgEffects")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

local SCREEN_H = BattleAnimView.SCREEN_H

-- data/moves/animations.asm:2618 BattleAnim_NightShade:
local bg = BgEffects.new({}, { battleTurn = 0 })
bg:queue("BATTLE_BG_EFFECT_NIGHT_SHADE", 0, 0, 0x8)
bg:playFrame()
T.eq(bg.lcdc, "SCY", "Night Shade wobbles the target vertically")
T.eq(bg.lyStart, 0x00, "and the enemy window starts at scanline 0")
T.eq(bg.lyEnd, 0x36, "running to $36")

local negatives, gaps, duplicates = 0, 0, 0
for _ = 1, 16 do
  bg:playFrame()
  for row = bg.lyStart, bg.lyEnd - 1 do
    local byte = bg.lyBackup[row] or 0
    if byte >= 0x80 and row + (byte - 0x100) < 0 then
      negatives = negatives + 1
    end
  end
  local seen = {}
  for _, line in ipairs(BattleAnimView.scanlines(bg)) do
    if seen[line.dest] then duplicates = duplicates + 1 end
    seen[line.dest] = true
  end
  for row = bg.lyStart + 1, bg.lyEnd do
    if not seen[row] then gaps = gaps + 1 end
  end
end
T.check(negatives > 0, "the wave really does push the top rows off the panel")
T.eq(gaps, 0, "but no window scanline is ever left blank")
T.eq(duplicates, 0, "and none is drawn twice")

local function panel(fields)
  local out = { scx = 0, scy = 0, lyStart = 0, lyEnd = 0x36, lyBackup = {},
    lcdc = "SCY" }
  for k, v in pairs(fields) do out[k] = v end
  return out
end

local function byRow(lines)
  local map = {}
  for _, line in ipairs(lines) do map[line.dest] = line end
  return map
end

do
  local lines = byRow(BattleAnimView.scanlines(panel({
    lyBackup = { [0] = 0xfe, [1] = 0xfd } })))
  T.eq(lines[1] and lines[1].src, 0, "an rSCY of -2 stored on LY 0 holds row 0")
  T.eq(lines[2] and lines[2].src, 0, "and -3 stored on LY 1 holds it too")
end

do
  local lines = byRow(BattleAnimView.scanlines(panel({
    lyEnd = SCREEN_H, lyBackup = { [SCREEN_H - 2] = 4 } })))
  T.eq(lines[SCREEN_H - 1] and lines[SCREEN_H - 1].src, SCREEN_H - 1,
    "a wobble past the bottom of the panel holds the last row")
end

do
  local lines = byRow(BattleAnimView.scanlines(panel({
    lyBackup = { [0] = 0x90 } })))
  T.eq(lines[1], nil, "the $90 displacement still sinks its row into blank")
end

do
  local lines = byRow(BattleAnimView.scanlines(panel({
    scy = 4, lcdc = nil, lyEnd = 0 })))
  T.eq(lines[SCREEN_H - 1], nil,
    "and a whole-screen hSCY shake still leaves the bottom rows blank")
end

T.finish("gen2 night shade top row bug 1921")
