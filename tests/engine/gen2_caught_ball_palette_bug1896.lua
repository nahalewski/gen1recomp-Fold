-- engine/battle_anims/anim_commands.asm:213 (#1896)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local AnimRunner = require("src.battle.gen2.AnimRunner")

local function runnerWith(rows, palettes)
  local runner = AnimRunner.new({
    animId = "ANIM_THROW_POKE_BALL",
    battleTurn = 0,
    data = { scripts = { click = rows } },
  })
  runner:start("click")
  runner.objects.playFrame = function(objects)
    objects.oam = {}
    for _, name in ipairs(palettes) do
      objects.oam[#objects.oam + 1] = { x = 80, y = 80, tile = 0, attr = 0,
        palette = name }
    end
    return false
  end
  return runner
end

do
  local runner = runnerWith({ { "keepsprites" }, { "ret" } },
    { "PAL_BATTLE_OB_RED", "PAL_BATTLE_OB_BLUE" })
  T.eq(runner:step(), false, "keepsprites + ret ends the script the same frame")
  T.eq(runner.keepSprites, true, "and BATTLEANIM_KEEPSPRITES_F is set")
  T.eq(#runner:oam(), 2, "the ball's OBJs stay on screen")
  for _, obj in ipairs(runner:oam()) do
    T.eq(obj.palette, "PAL_BATTLE_OB_ENEMY",
      "every kept OBJ is remapped onto the wild mon's palette")
  end
end

do
  local runner = runnerWith({ { "ret" } },
    { "PAL_BATTLE_OB_RED", "PAL_BATTLE_OB_BLUE" })
  T.eq(runner:step(), false, "a break-free ret still ends the script")
  T.eq(runner.keepSprites, false, "with no keepsprites flag")
  T.eq(#runner:oam(), 0, "so BattleAnim_ClearOAM deletes the sprites instead")
end

T.finish("gen2 caught ball palette bug 1896")
