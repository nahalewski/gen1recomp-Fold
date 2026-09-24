-- engine/battle_anims/bg_effects.asm:343 (#2101)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local BgEffects = require("src.battle.gen2.BgEffects")

do
  local bg = BgEffects.new({}, { battleTurn = 0 })
  local st = bg:queue("BATTLE_BG_EFFECT_HIDE_MON", 0, 0, 0)
  local side = bg:sideKey(st)
  bg:playFrame()
  T.eq(bg.hidden[side], true, "HideMon clears the battler's box")
  for _ = 1, 6 do bg:playFrame() end
  T.eq(bg:activeCount(), 0, "the effect ends after its five steps")
  T.eq(bg.hidden[side], true, "and the box stays cleared when it does")
end

do
  local bg = BgEffects.new({}, { battleTurn = 0 })
  local st = bg:queue("BATTLE_BG_EFFECT_HIDE_MON", 0, 0, 0)
  local side = bg:sideKey(st)
  for _ = 1, 6 do bg:playFrame() end
  T.eq(bg.hidden[side], true, "hidden going into the redraw")
  bg:queue("BATTLE_BG_EFFECT_SHOW_MON", 0, 0, 0)
  bg:playFrame()
  T.eq(bg.hidden[side], false, "ShowMon is what redraws the box")
end

T.finish("gen2 dig hide mon bug 2101")
