-- engine/battle_anims/functions.asm:1148 (#1920)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local AnimObjects = require("src.battle.gen2.AnimObjects")
local BgEffects = require("src.battle.gen2.BgEffects")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

-- data/battle_anims/objects.asm: BATTLE_ANIM_OBJ_SURF, and
-- data/moves/animations.asm:1126 BattleAnim_Surf's anim_obj row.
local DATA = { objects = { SURF = { func = "BATTLE_ANIM_FUNC_SURF" } } }

local function pools()
  local bg = BgEffects.new({}, { battleTurn = 0 })
  local objects = AnimObjects.new(DATA, {}, { battleTurn = 0 })
  objects.hram = bg
  bg:queue("BATTLE_BG_EFFECT_SURF", 0, 0, 0)
  local st = objects:queue("SURF", 88, 104, 0x8)
  return bg, objects, st
end

-- anim_commands.asm:100: the BG effects run first, then the object functions.
local function step(bg, objects)
  bg:playFrame()
  objects:playFrame()
end

local function painted(bg, first, last)
  for row = first, last do
    if (bg.lyBackup[row] or 0) ~= 0 then return true end
  end
  return false
end

do
  local bg, objects = pools()
  step(bg, objects)
  T.eq(bg.lcdc, "SCY", "the Surf object opens the LCD-STAT window")
  T.eq(bg.lyStart, 0x58, "at hLYOverrideStart $58")
  T.eq(bg.lyEnd, 0x5e, "and hLYOverrideEnd $5e")
  T.check(not painted(bg, 0, 0x5e),
    "and the BG effect has painted nothing on the frame that opens it")

  step(bg, objects)
  T.check(painted(bg, 0x59, 0x5e),
    "the next frame rotates the ring into the window")
  T.check(bg.lyStart < 0x58, "and the wave front climbs the screen")

  local before = bg.lyStart
  for _ = 1, 20 do step(bg, objects) end
  T.check(bg.lyStart < before - 0x10,
    "it keeps climbing past its own sine wobble")
  T.check(painted(bg, bg.lyStart + 1, 0x5e),
    "with the water still on screen behind it")

  local lines = BattleAnimView.scanlines(bg)
  local sheared = false
  for _, line in ipairs(lines) do
    if line.src ~= line.dest then sheared = true end
  end
  T.check(sheared, "so the view distorts at least one scanline")
end

do
  local bg, objects, st = pools()
  step(bg, objects)
  st.y, st.jt = 0x70, 3
  step(bg, objects)
  T.eq(bg.lcdc, nil, "passing y $70 closes the window again")
  T.eq(bg.lyStart, 0, "clearing hLYOverrideStart")
  T.eq(bg.lyEnd, 0, "and hLYOverrideEnd")
  T.eq(st.index, 0, "and deinitialising the object")
end

do
  local bg, objects, st = pools()
  step(bg, objects)
  st.y = 0x00
  step(bg, objects)
  T.eq(bg.lyStart, 0, "reaching the top of the screen zeroes the window start")
  T.eq(bg.lcdc, "SCY", "but leaves the pointer open")
end

T.finish("gen2 surf ly override bug 1920")
