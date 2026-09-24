-- data/moves/animations.asm:401-403

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local UI = require("src.ui.gen2.BattleState")
local AnimRunner = require("src.battle.gen2.AnimRunner")

local runner = AnimRunner.new({ animId = "ANIM_THROW_POKE_BALL", battleTurn = 0 })
T.eq(runner.animId, "ANIM_THROW_POKE_BALL",
  "the runner exposes the anim id BattleState latches on")
T.eq(runner.env.animId, "ANIM_THROW_POKE_BALL",
  "the object/bg env still sees the same id")

-- A real runner skipped with B must still hide the caught mon.
do
  local s = setmetatable({
    anim = runner,
    ballThrow = { caught = true },
    picHidden = { player = false, enemy = false },
  }, { __index = UI })
  local input = { wasPressed = function(_, key) return key == "b" end }
  s:stepAnim(input)
  T.eq(s.picHidden.enemy, true, "a B-skipped catch latches with a real runner")
end

do
  local free = AnimRunner.new({ animId = "ANIM_THROW_POKE_BALL", battleTurn = 0 })
  local s = setmetatable({
    anim = free,
    ballThrow = { caught = false },
    picHidden = { player = false, enemy = false },
  }, { __index = UI })
  local input = { wasPressed = function(_, key) return key == "b" end }
  s:stepAnim(input)
  T.eq(s.picHidden.enemy, false, "a B-skipped break-free still does not latch")
end

T.finish("gen2 ball anim id bug 1804")
