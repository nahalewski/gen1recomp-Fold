-- engine/battle_anims/bg_effects.asm:2638 (#1895)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

local SCREEN_H = BattleAnimView.SCREEN_H

local function bg(fields)
  local out = { scx = 0, scy = 0, lyStart = 0, lyEnd = 0, lyBackup = {} }
  for k, v in pairs(fields) do out[k] = v end
  return out
end

local function byRow(lines)
  local map = {}
  for _, line in ipairs(lines) do map[line.dest] = line end
  return map
end

do
  local lines = byRow(BattleAnimView.scanlines(
    bg({ lcdc = "SCY", lyStart = 0, lyEnd = 0x36, lyBackup = { [10] = 2 } })))
  T.eq(lines[11] and lines[11].src, 13, "rSCY 2 stored on LY 10 lands on 11")
  T.eq(lines[11] and lines[11].dest, 11, "and draws on scanline 11")
  T.eq(lines[11] and lines[11].dx, 0, "rSCY never moves the row sideways")
end

do
  local lines = byRow(BattleAnimView.scanlines(
    bg({ lcdc = "SCX", lyStart = 0, lyEnd = 0x36, lyBackup = { [10] = 2 } })))
  T.eq(lines[11] and lines[11].src, 11, "rSCX leaves the sampled row alone")
  T.eq(lines[11] and lines[11].dx, -2, "and shifts the destination x instead")
end

do
  local backup = {}
  for row = 0, 0x35 do
    backup[row] = ({ 0, 1, 2, 3, 2, 1, 0, 0xff, 0xfe, 0xfd, 0xfe, 0xff })
      [(row % 12) + 1]
  end
  local lines = BattleAnimView.scanlines(
    bg({ lcdc = "SCY", lyStart = 0, lyEnd = 0x36, lyBackup = backup }))
  local seen = {}
  for _, line in ipairs(lines) do
    T.check(not seen[line.dest], "scanline " .. line.dest .. " is drawn once")
    seen[line.dest] = true
    T.check(line.src >= 0 and line.src < SCREEN_H,
      "scanline " .. line.dest .. " samples inside the panel")
  end
  local gaps = 0
  for row = 1, 0x36 do
    if not seen[row] then gaps = gaps + 1 end
  end
  T.eq(gaps, 0, "a per-scanline rSCY sine leaves no blank rows in the window")
end

do
  local lines = byRow(BattleAnimView.scanlines(
    bg({ lcdc = "SCY", lyStart = 0, lyEnd = 0x36,
      lyBackup = { [10] = 0x90, [120] = 0x90 } })))
  T.eq(lines[11], nil, "a $90 stored on LY 10 skips scanline 11")
  T.check(lines[120] ~= nil, "a $90 row outside the window still draws")
end

-- home/lcd.asm:3 (#1921)
do
  local lines = byRow(BattleAnimView.scanlines(
    bg({ lcdc = "SCY", lyStart = 0, lyEnd = 0x36,
      lyBackup = { [0] = 0xfe, [1] = 0xfd } })))
  T.eq(lines[1] and lines[1].src, 0,
    "a window row that wobbles above the panel clamps to row 0")
  T.eq(lines[2] and lines[2].src, 0, "two rows above the panel clamp as well")
  T.eq(lines[2] and lines[2].dest, 2, "and still land on their own scanline")
end

do
  local lines = byRow(BattleAnimView.scanlines(
    bg({ lcdc = "SCY", lyStart = 0x80, lyEnd = SCREEN_H,
      lyBackup = { [SCREEN_H - 2] = 2 } })))
  T.eq(lines[SCREEN_H - 1] and lines[SCREEN_H - 1].src, SCREEN_H - 1,
    "and a window row that wobbles below it clamps to the last row")
end

do
  local lines = byRow(BattleAnimView.scanlines(
    bg({ lcdc = "SCY", scy = 0xfc, lyStart = 0, lyEnd = 0x36,
      lyBackup = { [0] = 0xff } })))
  T.eq(lines[1], nil, "an hSCY shake keeps its blank rows, window or not")
end

do
  local lines = byRow(BattleAnimView.scanlines(bg({ scy = 4 })))
  T.eq(lines[0] and lines[0].src, 4, "hSCY 4 puts BG row 4 on scanline 0")
  T.eq(lines[0] and lines[0].dest, 0, "with the destination untouched")
  T.eq(lines[SCREEN_H - 1], nil,
    "and the rows that would sample past the panel are left blank")
end

T.finish("gen2 scy deform blit bug 1895")
