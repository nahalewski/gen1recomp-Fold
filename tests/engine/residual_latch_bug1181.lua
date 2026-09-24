-- HandlePoisonBurnLeechSeed runs once per side per round; a mod that
-- reads battle.ruleset.residualAfterMove twice (executeAction:3487 and
-- endOfTurn:2657) could otherwise fire both arms.  #1181's b.residualDone
-- latch (residualFor ~2612, endOfTurn ~2670, cleared ~2685) closes that.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
local Font = require("src.render.Font")
Font.load(Data)
local BattleState = require("src.battle.BattleState")
local Pokemon = require("src.pokemon.Pokemon")
local SaveData = require("src.core.SaveData")
local TypeChart = require("src.battle.TypeChart")
TypeChart.load(Data)

local function newBattle(opts)
  opts = opts or {}
  local save = SaveData.newGame()
  save.party = { Pokemon.new(Data, "FIXMON_A", 30), Pokemon.new(Data, "FIXMON_A", 28) }
  local game = { data = Data, save = save,
               stack = { top = function() return nil end, push = function() end } }
  local battle = BattleState.newWild(game, "FIXMON_C", 30)
  battle.rng = function() return 0 end
  battle.enemyAction = function() return { id = "FIX_SCRATCH", pp = 35 } end
  if opts.playerFaster then
    battle.player.curStats.speed = 200
    battle.enemy.curStats.speed = 1
  else
    battle.enemy.curStats.speed = 200
    battle.player.curStats.speed = 1
  end
  return battle
end

local function drain(battle)
  local rows = {}
  for _ = 1, 800 do
    local item = table.remove(battle.queue, 1)
    if not item then return rows end
    if item.text then rows[#rows + 1] = { text = item.text } end
    if item.fn then
      battle.nextInsert = 0
      item.fn()
    end
  end
  error("the turn queue never drained")
end

local function countTicks(rows)
  local player, enemy = 0, 0
  for _, r in ipairs(rows) do
    if r.text and r.text:find("hurt by poison", 1, true) then
      if r.text:find("Enemy", 1, true) then enemy = enemy + 1
      else player = player + 1 end
    end
  end
  return player, enemy
end

local function assertCleared(b, label)
  T.check(b.player.residualDone == nil, label .. ": player residualDone cleared")
  T.check(b.enemy.residualDone == nil, label .. ": enemy residualDone cleared")
end

do
  local b = newBattle({ playerFaster = true })
  b.player.mon.status = "PSN"
  b:resolveTurn({ id = "FIX_TACKLE", pp = 35 })
  local pt, et = countTicks(drain(b))
  T.eq(pt, 1, "faster attacker: poison ticks exactly once")
  T.eq(et, 0, "faster attacker: no enemy tick")
  assertCleared(b, "faster attacker")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b:resolveTurn({ id = "FIX_TACKLE", pp = 35 })
  local pt, et = countTicks(drain(b))
  T.eq(pt, 1, "slower attacker: poison ticks exactly once")
  T.eq(et, 0, "slower attacker: no enemy tick")
  assertCleared(b, "slower attacker")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b:itemUsed({})
  local pt, et = countTicks(drain(b))
  T.eq(pt, 1, "item round: poison ticks exactly once")
  T.eq(et, 0, "item round: no enemy tick")
  assertCleared(b, "item round")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b.catchAttempt = function() return false, 0 end
  local ballId
  for id in pairs(Data.items or {}) do
    if id:find("BALL") then ballId = id break end
  end
  if not ballId then
    Data.items = Data.items or {}
    Data.items.POKE_BALL = { name = "POKE BALL" }
    ballId = "POKE_BALL"
  end
  b:throwBall(ballId)
  local pt, et = countTicks(drain(b))
  T.eq(pt, 1, "ball round: poison ticks exactly once")
  T.eq(et, 0, "ball round: no enemy tick")
  assertCleared(b, "ball round")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b.runRoll = function() return false end
  b:tryRun()
  local pt, et = countTicks(drain(b))
  T.eq(pt, 1, "failed run: poison ticks exactly once")
  T.eq(et, 0, "failed run: no enemy tick")
  assertCleared(b, "failed run")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b:resolveSwitch(b.game.save.party[2])
  local pt, et = countTicks(drain(b))
  T.eq(pt, 0, "switch round: a fresh battler ticks zero")
  T.eq(et, 0, "switch round: still no enemy tick")
  assertCleared(b, "switch round")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b.enemy.mon.status = "PSN"
  local php0, ehp0 = b.player.mon.hp, b.enemy.mon.hp
  b:resolveTurn({ id = "FIX_TACKLE", pp = 35 })
  local rows = drain(b)
  local pt, et = countTicks(rows)
  T.eq(pt, 1, "both sides poisoned: player side ticks once")
  T.eq(et, 1, "both sides poisoned: enemy side ticks once too")
  T.check(b.player.mon.hp < php0, "both sides poisoned: player actually lost HP")
  T.check(b.enemy.mon.hp < ehp0, "both sides poisoned: enemy actually lost HP")
  assertCleared(b, "both sides poisoned")
end

do
  local b = newBattle({ playerFaster = false })
  b.player.mon.status = "PSN"
  b.player.mon.hp = 999
  b.player.mon.stats.hp = 999
  local lastLoss
  for round = 1, 5 do
    local hp0 = b.player.mon.hp
    b:resolveTurn({ id = "FIX_TACKLE", pp = 35 })
    local pt, et = countTicks(drain(b))
    T.eq(pt, 1, ("round %d of 5: poison ticks exactly once"):format(round))
    T.eq(et, 0, ("round %d of 5: no enemy tick"):format(round))
    assertCleared(b, ("round %d of 5"):format(round))
    local loss = hp0 - b.player.mon.hp
    T.check(loss > 0, ("round %d of 5: HP actually dropped"):format(round))
    if lastLoss then
      T.eq(loss, lastLoss, ("round %d of 5: same tick size as the round before"):format(round))
    end
    lastLoss = loss
  end
end

T.finish("residual latch (#1181)")
