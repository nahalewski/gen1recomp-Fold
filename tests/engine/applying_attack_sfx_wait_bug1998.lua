-- engine/battle/animations.asm:2639, home/delay.asm:15
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
require("src.render.Font").load(Data)
local BattleState = require("src.battle.BattleState")
local Pokemon = require("src.pokemon.Pokemon")
local SaveData = require("src.core.SaveData")
local TypeChart = require("src.battle.TypeChart")
local Sound = require("src.core.Sound")
TypeChart.load(Data)

local busy, budget = false, 0
Sound.moveSfxBusy = function() return busy end
Sound.moveSfxWaitFrames = function() return budget end

local function newBattle(hit, alarm)
  local save = SaveData.newGame()
  save.party = { Pokemon.new(Data, "FIXMON_A", 40) }
  local game = { data = Data, save = save,
                 stack = { top = function() return nil end, push = function() end } }
  local battle = BattleState.newWild(game, "FIXMON_C", 40)
  battle.queue, battle.nextInsert = {}, 0
  battle.fx = {}
  battle.animPlayer = { update = function() end,
                        isDone = function() return true end,
                        pollEffects = function() return {} end }
  battle.animPlaying = true
  battle.pendingHit = hit
  battle.lowHealthAlarmActive = function() return alarm == true end
  return battle
end

local function fxArmed(battle)
  return (battle.fx.shakeProg ~= nil) or (battle.fx.blink ~= nil)
end

for _, t in ipairs({ 1, 2, 5 }) do
  busy, budget = true, 5
  local battle = newBattle({ animType = t, sfx = "Damage" })
  for i = 1, 5 do
    T.eq(battle:updateQueue(), true,
      ("type %d holds the queue on frame %d"):format(t, i))
    T.check(not fxArmed(battle),
      ("type %d arms no applying-attack fx while the sfx sounds"):format(t))
    T.check(battle.pendingHit ~= nil,
      ("type %d keeps its hit row pending"):format(t))
    T.eq(battle.animPlaying, true,
      ("type %d stays in the animation branch"):format(t))
  end
  battle:updateQueue()
  T.check(fxArmed(battle),
    ("type %d arms its fx once the budget expires"):format(t))
  T.eq(battle.pendingHit, nil, ("type %d consumes its hit row"):format(t))
  T.eq(battle.hitSfxWait, nil, ("type %d clears the hold counter"):format(t))
end

do
  busy, budget = true, 3
  local battle = newBattle(nil)
  battle.pendingHit = { animType = 4, sfx = "Damage", blink = battle.enemy }
  battle:updateQueue()
  T.eq(battle.fx.blink, nil, "type 4 does not blink while the sfx sounds")
  for _ = 1, 3 do battle:updateQueue() end
  T.check(battle.fx.blink ~= nil, "type 4 blinks once the sfx has finished")
end

do
  busy, budget = true, 60
  local battle = newBattle({ animType = 1, sfx = "Damage" })
  battle:updateQueue()
  battle:updateQueue()
  T.check(not fxArmed(battle), "still held while CHAN5/6/8 are busy")
  busy = false
  battle:updateQueue()
  T.check(fxArmed(battle), "released the frame the sfx channels go idle")
  T.eq(battle.hitSfxWait, nil, "and the hold counter is cleared")
end

-- animations.asm:495 / :498 ShakeScreenHorizontallySlow, ...Slow2
for _, t in ipairs({ 3, 6 }) do
  busy, budget = true, 60
  local battle = newBattle({ animType = t })
  battle:updateQueue()
  T.check(battle.fx.shakeProg ~= nil,
    ("type %d shakes without waiting for the sfx"):format(t))
  T.eq(battle.hitSfxWait, nil, ("type %d sets no hold counter"):format(t))
end

do
  busy, budget = true, 60
  local battle = newBattle({ animType = 1, sfx = "Damage" }, true)
  battle:updateQueue()
  T.check(fxArmed(battle), "the low-health alarm bypasses the wait")
  T.eq(battle.hitSfxWait, nil, "and leaves no hold counter behind")
end

do
  busy, budget = true, 60
  local battle = newBattle(nil)
  battle:updateQueue()
  T.eq(battle.animPlaying, false, "a hitless animation row ends on its own")
  T.eq(battle.hitSfxWait, nil, "and sets no hold counter")
end

do
  busy, budget = true, 0
  local battle = newBattle({ animType = 1, sfx = "Damage" })
  battle:updateQueue()
  T.check(fxArmed(battle), "a zero budget releases immediately")
end

do
  busy, budget = true, 100000
  local battle = newBattle({ animType = 1, sfx = "Damage" })
  battle:updateQueue()
  T.eq(battle.hitSfxWait, 179, "the budget is capped at 180 logic frames")
  for _ = 1, 200 do
    if fxArmed(battle) then break end
    battle:updateQueue()
  end
  T.check(fxArmed(battle), "and a stuck source cannot wedge the battle")
end

do
  Sound.moveSfxBusy, Sound.moveSfxWaitFrames = nil, nil
  package.loaded["src.core.Sound"] = nil
  local Fresh = require("src.core.Sound")
  T.eq(type(Fresh.moveSfxBusy), "function", "Sound exposes moveSfxBusy")
  T.eq(type(Fresh.moveSfxWaitFrames), "function",
    "Sound exposes moveSfxWaitFrames")
  T.eq(Fresh.moveSfxBusy(), false, "no move sfx sounding, no wait")
  T.eq(Fresh.moveSfxWaitFrames(), 0, "and a zero frame budget")
end

T.finish()
