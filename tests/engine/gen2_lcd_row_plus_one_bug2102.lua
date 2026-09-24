-- home/lcd.asm:12 (#2102)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local check, eq = T.check, T.eq
local BgEffects = require("src.battle.gen2.BgEffects")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")
local GbcPalette = require("src.render.GbcPalette")

local function byRow(lines)
  local rows = {}
  for _, line in ipairs(lines) do rows[line.dest] = line end
  return rows
end

local function displacement(bg)
  local total = 0
  for row = bg.lyStart, bg.lyEnd do
    local byte = bg.lyBackup[row] or 0
    if byte ~= 0 then total = total + 1 end
  end
  return total
end

local function runToPeak(bg, frames)
  local peak, peakRows = -1, nil
  for _ = 1, frames do
    bg:playFrame()
    local d = displacement(bg)
    if d > peak then peak, peakRows = d, byRow(BattleAnimView.scanlines(bg)) end
  end
  return peakRows, peak
end

local function assertBand(label, rows, lyStart, lyEnd, register)
  local top = rows[lyStart]
  check(top ~= nil and top.src == lyStart and top.dx == 0,
    label .. (": drawn row 0x%02x (LY = lyStart) is untouched"):format(lyStart))
  local identity = 0
  for row = lyStart + 1, lyEnd do
    local line = rows[row]
    if line and line.src == row and line.dx == 0 then identity = identity + 1 end
  end
  eq(identity, 0, label .. ": no identity row inside the pic band")
  local bottom = rows[lyEnd]
  if register == "SCX" then
    check(bottom ~= nil and bottom.dx ~= 0,
      label .. (": drawn row 0x%02x (LY = lyEnd) is shoved sideways"):format(lyEnd))
  else
    check(bottom == nil or bottom.src ~= lyEnd,
      label .. (": drawn row 0x%02x (LY = lyEnd) is moved or blanked"):format(lyEnd))
  end
  local below = rows[lyEnd + 1]
  check(below ~= nil and below.src == lyEnd + 1 and below.dx == 0,
    label .. (": drawn row 0x%02x below the band is untouched"):format(lyEnd + 1))
end

-- engine/battle_anims/bg_effects.asm:1765 BattleBGEffect_BounceDown
do
  local bg = BgEffects.new({}, { battleTurn = 0 })
  bg:queue("BATTLE_BG_EFFECT_BOUNCE_DOWN", 0, 1, 0)
  bg:playFrame()
  eq(bg.lyStart, 0x2d, "player BounceDown opens the band at $2d")
  eq(bg.lyEnd, 0x5f, "one past $5e")
  local rows, peak = runToPeak(bg, 20)
  check(peak >= 0x30, ("the peak displaces %d rows"):format(peak))
  assertBand("player BounceDown", rows, 0x2d, 0x5f, "SCY")
end

do
  local bg = BgEffects.new({}, { battleTurn = 0 })
  bg:queue("BATTLE_BG_EFFECT_BOUNCE_DOWN", 0, 0, 0)
  bg:playFrame()
  eq(bg.lyStart, 0x00, "enemy BounceDown opens the band at $00")
  eq(bg.lyEnd, 0x37, "one past $36")
  local rows, peak = runToPeak(bg, 20)
  check(peak >= 0x30, ("the peak displaces %d rows"):format(peak))
  local identity = 0
  for row = 1, 0x37 do
    local line = rows[row]
    if line and line.src == row and line.dx == 0 then identity = identity + 1 end
  end
  eq(identity, 0, "enemy BounceDown: no identity row inside the pic band")
  check(rows[0x37] == nil or rows[0x37].src ~= 0x37,
    "enemy BounceDown: drawn row 0x37 (LY = lyEnd) is moved or blanked")
  check(rows[0x38] ~= nil and rows[0x38].src == 0x38,
    "enemy BounceDown: drawn row 0x38 below the band is untouched")
end

-- engine/battle_anims/bg_effects.asm:1444 BattleBGEffect_BodySlam
do
  local bg = BgEffects.new({}, { battleTurn = 0 })
  bg:queue("BATTLE_BG_EFFECT_BODY_SLAM", 0, 1, 0)
  bg:playFrame()
  eq(bg.lcdc, "SCX", "player BodySlam shoves sideways")
  local rows = runToPeak(bg, 6)
  assertBand("player BodySlam", rows, 0x2d, 0x5f, "SCX")
end

do
  local bg = BgEffects.new({}, { battleTurn = 0 })
  bg:queue("BATTLE_BG_EFFECT_BODY_SLAM", 0, 0, 0)
  bg:playFrame()
  eq(bg.lyEnd, 0x37, "enemy BodySlam ends one past $36")
  local rows = runToPeak(bg, 6)
  check(rows[0] ~= nil and rows[0].dx == 0, "enemy BodySlam: drawn row 0 is untouched")
  local identity = 0
  for row = 1, 0x37 do
    local line = rows[row]
    if line and line.dx == 0 then identity = identity + 1 end
  end
  eq(identity, 0, "enemy BodySlam: no identity row inside the pic band")
  check(rows[0x37] ~= nil and rows[0x37].dx ~= 0,
    "enemy BodySlam: drawn row 0x37 (LY = lyEnd) is shoved")
  check(rows[0x38] ~= nil and rows[0x38].dx == 0,
    "enemy BodySlam: drawn row 0x38 is untouched")
end

-- engine/battle_anims/bg_effects.asm:2585 (rBGP band)
do
  local base = GbcPalette.BGP_IDENTITY
  local bg = { bgp = base, lcdc = "BGP", lyStart = 0x2d, lyEnd = 0x5f, lyBackup = {} }
  for row = 0x2d, 0x5e do bg.lyBackup[row] = 0xff end
  local rowByte = {}
  for _, band in ipairs(BattleAnimView.bgpBands(bg)) do
    for _, row in ipairs(band.rows) do rowByte[row] = band.byte end
  end
  eq(rowByte[0x2d], base, "BGP: drawn row 0x2d (LY = lyStart) keeps wBGP")
  eq(rowByte[0x2e], 0xff, "BGP: drawn row 0x2e takes the byte written at LY 0x2d")
  eq(rowByte[0x5f], 0xff, "BGP: drawn row 0x5f takes the byte written at LY 0x5e")
  eq(rowByte[0x60], base, "BGP: drawn row 0x60 is back on wBGP")
  local off = 0
  for row = 0x2e, 0x5f do
    if rowByte[row] == base then off = off + 1 end
  end
  eq(off, 0, "BGP: no drawn row inside the band keeps the base palette")
end

T.finish("gen2 lcd row plus one bug 2102")
