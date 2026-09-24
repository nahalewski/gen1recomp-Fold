-- engine/battle_anims/bg_effects.asm:406-471 BattleBGEffect_BattlerObj_1Row

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local BgEffects = require("src.battle.gen2.BgEffects")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

do
  local bg = BgEffects.new(nil, { battleTurn = 0 })
  bg:queue("BATTLE_BG_EFFECT_BATTLEROBJ_1ROW", 0, 0, 0)
  bg:playFrame()
  local spawns = bg:takeSpawns()
  T.eq(spawns[1] and spawns[1].object, "BATTLE_ANIM_OBJ_ENEMYFEET_1ROW",
    "player attacking: the enemy's feet row becomes an OBJ")
  T.eq(spawns[1] and spawns[1].x, 16 * 8 + 4, "at the asm's fixed x")
  T.eq(bg.liftedRows.enemy, nil, "the tilemap row is intact on frame one")
  T.eq(BattleAnimView.needsCanvas({ bg = bg }), false,
    "an intact tilemap with no scroll skips the bake canvas")
  bg:playFrame()
  local lifted = bg.liftedRows.enemy
  T.check(lifted and lifted[1] == 6 and lifted[2] == 1,
    "frame two ClearBoxes row 6 of the enemy box (hlcoord 12, 6)")
  T.eq(bg.hidden.enemy, false, "the rest of the pic stays on the BG")
  T.eq(BattleAnimView.needsCanvas({ bg = bg }), true,
    "a lifted row keeps the panel on the bake canvas even with scx 0 and no"
    .. " lcdc pointer, so drawPic's 160x144 scissor stays in canvas space")
  for _ = 1, 4 do bg:playFrame() end
  T.eq(bg:activeCount(), 0, ".five ends the effect")
  lifted = bg.liftedRows.enemy
  T.check(lifted and lifted[1] == 6 and lifted[2] == 1,
    ".five never restores the row")
  T.eq(BattleAnimView.needsCanvas({ bg = bg }), true,
    "and the wait frames after .five stay baked as well")
  bg:queue("BATTLE_BG_EFFECT_SHOW_MON", 0, 0, 0)
  bg:playFrame()
  T.eq(bg.liftedRows.enemy, nil, "SHOW_MON's box redraw puts the row back")
  T.eq(BattleAnimView.needsCanvas({ bg = bg }), false,
    "after which the plain no-canvas path returns")
end

do
  local bg = BgEffects.new(nil, { battleTurn = 1 })
  bg:queue("BATTLE_BG_EFFECT_BATTLEROBJ_2ROW", 0, 0, 0)
  bg:playFrame()
  local spawns = bg:takeSpawns()
  T.eq(spawns[1] and spawns[1].object, "BATTLE_ANIM_OBJ_PLAYERHEAD_2ROW",
    "enemy attacking: the player's head rows become an OBJ")
  T.eq(spawns[1] and spawns[1].x, 6 * 8, "at the asm's fixed x")
  bg:playFrame()
  local lifted = bg.liftedRows.player
  T.check(lifted and lifted[1] == 0 and lifted[2] == 2,
    "rows 0-1 of the player box (hlcoord 2, 6, two rows)")
  T.eq(bg.liftedRows.enemy, nil, "the attacker keeps its own rows")
end

do
  local bg = BgEffects.new(nil, { battleTurn = 0, flying = { enemy = true } })
  bg:queue("BATTLE_BG_EFFECT_BATTLEROBJ_1ROW", 0, 0, 0)
  bg:playFrame()
  T.eq(#bg:takeSpawns(), 0, "a flying target spawns nothing")
  T.eq(bg:activeCount(), 0, "and the effect ends at once")
  T.eq(bg.liftedRows.enemy, nil, "with no row lifted")
end

T.finish("gen2 battler row lift bug 1231")
