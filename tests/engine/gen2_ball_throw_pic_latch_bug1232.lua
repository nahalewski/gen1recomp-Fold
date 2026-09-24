-- data/moves/animations.asm:379

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local UI = require("src.ui.gen2.BattleState")

local function newSelf(opts)
  opts = opts or {}
  return setmetatable({
    anim = opts.anim,
    ballThrow = opts.ballThrow,
    picHidden = { player = false, enemy = false },
    pendingAfterAnim = nil,
    afterSendOut = nil,
  }, { __index = UI })
end

-- pushCaught itself must never touch picHidden: only the animation's own
-- steps (stepAnim) are allowed to latch the enemy pic box.
do
  local self1 = setmetatable({
    battle = {}, tutorial = true, save = nil,
    queue = {}, picHidden = { player = false, enemy = false },
  }, { __index = UI })
  self1:pushCaught({ species = "RATTATA" }, "POKE_BALL")
  T.eq(self1.picHidden.enemy, false,
    "pushCaught alone does not hide the enemy pic")
  T.eq(self1.battle.outcome, "caught", "pushCaught still marks the battle caught")
end

-- stepAnim, natural end (anim:step() returns false): a caught ball throw
-- latches, everything else does not.
do
  local caughtAnim = { animId = "ANIM_THROW_POKE_BALL",
    step = function() return false end, keepSprites = false }
  local s = newSelf({ anim = caughtAnim, ballThrow = { caught = true } })
  s:stepAnim(nil)
  T.eq(s.picHidden.enemy, true, "caught ball throw latches at the natural end")
  T.eq(s.anim, nil, "the finished runner is cleared")
end

do
  local breakFreeAnim = { animId = "ANIM_THROW_POKE_BALL",
    step = function() return false end, keepSprites = false }
  local s = newSelf({ anim = breakFreeAnim, ballThrow = { caught = false } })
  s:stepAnim(nil)
  T.eq(s.picHidden.enemy, false, "a break-free throw does not latch")
end

do
  local otherAnim = { animId = "ANIM_HYDRO_PUMP",
    step = function() return false end, keepSprites = false }
  local s = newSelf({ anim = otherAnim, ballThrow = { caught = true } })
  s:stepAnim(nil)
  T.eq(s.picHidden.enemy, false, "an unrelated animation never latches")
end

-- stepAnim, cut short with B: the property the latch exists for -- a caught
-- mon must not reappear even if the player skips past "Gotcha!".
do
  local caughtAnim = { animId = "ANIM_THROW_POKE_BALL",
    step = function() return true end, keepSprites = false }
  local s = newSelf({ anim = caughtAnim, ballThrow = { caught = true } })
  local input = { wasPressed = function(_, key) return key == "b" end }
  s:stepAnim(input)
  T.eq(s.picHidden.enemy, true, "a B-skipped catch still latches")
  T.eq(s.anim, nil, "B cuts the runner short")
end

do
  local breakFreeAnim = { animId = "ANIM_THROW_POKE_BALL",
    step = function() return true end, keepSprites = false }
  local s = newSelf({ anim = breakFreeAnim, ballThrow = { caught = false } })
  local input = { wasPressed = function(_, key) return key == "b" end }
  s:stepAnim(input)
  T.eq(s.picHidden.enemy, false, "a B-skipped break-free does not latch")
end

T.finish("gen2 ball throw pic latch bug 1232")
