-- engine/battle_anims/anim_commands.asm:603 BattleAnimCmd_BGP

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local AnimRunner = require("src.battle.gen2.AnimRunner")
local BgEffects = require("src.battle.gen2.BgEffects")
local GbcPalette = require("src.render.GbcPalette")

-- data/moves/animations.asm:4509 BattleAnim_ShadowBall
local SHADOW_BALL = {
  { "2gfx", "BATTLE_ANIM_GFX_EGG", "BATTLE_ANIM_GFX_SMOKE" },
  { "bgp", 0x1b },
  { "sound", 6 * 4 + 2, 0 },
  { "obj", "BATTLE_ANIM_OBJ_SHADOW_BALL", 64, 92, 0x2 },
  { "wait", 32 },
}

do
  local runner = AnimRunner.new({
    data = { scripts = { SHADOW_BALL = SHADOW_BALL } },
  })
  runner:start("SHADOW_BALL")
  T.eq(runner.bg.bgp, BgEffects.NORMAL_PAL, "identity ramp before the script")
  T.check(runner:step(), "the script is still running after frame one")
  T.eq(runner.bg.bgp, 0x1b,
    "anim_bgp $1b lands in wBGP: the inverted ramp the view must apply")
  runner.bg:reset()
  T.eq(runner.bg.bgp, BgEffects.NORMAL_PAL,
    "BattleAnim_RevertPals puts the identity back")
end

do
  T.eq(GbcPalette.BGP_IDENTITY, 0xe4, "dc 3, 2, 1, 0")
  local colors = { "c0", "c1", "c2", "c3" }
  local out = GbcPalette.remap(colors, 0x1b)
  T.eq(out[1], "c3", "$1b is dc 0, 1, 2, 3: colour 0 shows shade 3")
  T.eq(out[2], "c2", "colour 1 shows shade 2")
  T.eq(out[3], "c1", "colour 2 shows shade 1")
  T.eq(out[4], "c0", "colour 3 shows shade 0")
  T.check(GbcPalette.remap(colors, 0xe4) == colors,
    "the identity byte returns the palette untouched")
end

-- engine/battle_anims/anim_commands.asm:1293 BattleAnim_SetBGPals
do
  local list = {
    { { 255, 255, 255 }, { 168, 168, 168 }, { 84, 84, 84 }, { 0, 0, 0 } },
    { { 255, 255, 255 }, { 200, 100, 50 }, { 80, 40, 20 }, { 0, 0, 0 } },
    { { 255, 255, 255 }, { 230, 200, 40 }, { 150, 90, 20 }, { 0, 0, 0 } },
    { { 255, 255, 255 }, { 100, 220, 100 }, { 30, 160, 30 }, { 0, 0, 0 } },
    { { 255, 255, 255 }, { 230, 220, 90 }, { 180, 150, 20 }, { 0, 0, 0 } },
    { { 255, 255, 255 }, { 230, 100, 90 }, { 180, 30, 20 }, { 0, 0, 0 } },
    { { 255, 255, 255 }, { 120, 140, 230 }, { 40, 60, 160 }, { 0, 0, 0 } },
  }
  local src, dst, count, ambiguous = GbcPalette.remapTable(list, 0x1b)
  T.check(count > 0 and count <= GbcPalette.REMAP_MAX,
    "the table fits the shader array")
  T.eq(ambiguous, 0, "no colour maps two ways")
  local function mapped(from)
    for i = 1, count do
      if src[i][1] == from[1] and src[i][2] == from[2]
          and src[i][3] == from[3] then
        return dst[i]
      end
    end
  end
  local black = mapped({ 255, 255, 255 })
  T.check(black and black[1] == 0 and black[2] == 0 and black[3] == 0,
    "white inverts to black")
  local white = mapped({ 0, 0, 0 })
  T.check(white and white[1] == 255 and white[2] == 255 and white[3] == 255,
    "black inverts to white")
  local mid = mapped({ 200, 100, 50 })
  T.check(mid and mid[1] == 80 and mid[2] == 40 and mid[3] == 20,
    "the mon's colour 1 shows its colour 2")
end

T.finish("gen2 shadow ball bgp bug 1269")
