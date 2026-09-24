-- engine/battle_anims/bg_effects.asm:1444 (#2102)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local BgEffects = require("src.battle.gen2.BgEffects")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

T.check(BgEffects.EFFECTS.BATTLE_BG_EFFECT_BODY_SLAM ~= nil,
  "BODY_SLAM has a BG-effect body, not the silent unknown-id fallback")

-- data/moves/animations.asm:2096 BattleAnim_BodySlam
local slam = BgEffects.new({}, { battleTurn = 0 })
slam:queue("BATTLE_BG_EFFECT_BODY_SLAM", 0, 1, 0)
slam:playFrame()
T.eq(slam.lcdc, "SCX", "the lunge shoves the user sideways")
T.eq(slam.lyStart, 0x2d, "SetLCDStatCustoms2 opens the player band at $2d")
T.eq(slam.lyEnd, 0x5f, "and one past $5e")
slam:playFrame()
slam:playFrame()
T.eq(slam.lyBackup[0x30], 0xfe, "the player's rows step two pixels right")
T.check(slam:activeCount() >= 1, "and the struct stays alive for the return")

-- engine/battle_anims/bg_effects.asm:1765 BattleBGEffect_BounceDown
local bounce = BgEffects.new({}, { battleTurn = 0 })
bounce:queue("BATTLE_BG_EFFECT_BOUNCE_DOWN", 0, 1, 0)
bounce:playFrame()
T.eq(bounce.lcdc, "SCY", "BounceDown displaces the user vertically")
T.eq(bounce.lyStart, 0x2d, "through SetLCDStatCustoms2's $2d player band")
T.eq(bounce.lyEnd, 0x5f, "ending one past $5e")

-- home/lcd.asm:12
local strays = 0
for _ = 1, 16 do
  bounce:playFrame()
  for _, line in ipairs(BattleAnimView.scanlines(bounce)) do
    if line.dest == 0x5f and line.src == 0x5f then strays = strays + 1 end
  end
end
T.eq(strays, 0, "no frame leaves the pic's bottom scanline behind")

T.finish("gen2 body slam bounce bug 2102")
