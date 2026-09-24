-- engine/battle/core.asm:339, :416, :454 (#2076)
-- engine/battle/trainer_ai.asm:290-320, :357-362, :453-456
-- Self-contained; run via `luajit tests/parity_brock_full_heal.lua`.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.RATTATA) then Data:load() end
local TypeChart = require("src.battle.TypeChart")
TypeChart.load(Data)

local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")
local S = require("tests.harness").suite("parity brock full heal")
local check, eq = S.check, S.eq

local function newGame()
  return {
    data = Data,
    save = { party = { Pokemon.new(Data, "BULBASAUR", 50) },
             player = { name = "RED" }, inventory = {},
             options = { battleStyle = "set" },
             pokedex = { seen = {}, owned = {} }, flags = {}, money = 0 },
    stack = { push = function() end, pop = function() end, top = function() end },
  }
end

local function newBrock()
  local b = BattleState.newTrainer(newGame(), "OPP_BROCK", 1)
  b.rng = function(lo) return lo end
  b.player.curStats.speed = 200
  b.enemy.curStats.speed = 1
  return b
end

local function playerInflicts(b, status)
  local real = b.performMove
  b.performMove = function(self, user, target, action, ...)
    if user == self.player then
      target.mon.status = status
      return
    end
    return real(self, user, target, action, ...)
  end
  return b.player.curMoves[1]
end

local function drain(b)
  local rows = {}
  for _ = 1, 800 do
    local item = table.remove(b.queue, 1)
    if not item then return rows end
    if item.text then rows[#rows + 1] = item.text end
    if item.fn then
      b.nextInsert = 0
      item.fn()
    end
  end
  error("the turn queue never drained")
end

local function healed(rows)
  for _, text in ipairs(rows) do
    if text:find("FULL HEAL", 1, true) then return true end
  end
  return false
end

do
  local b = newBrock()
  eq(b.aiUses, 5, "wAICount seeded to BrockAI's 5 uses (ai_pointers.asm:40)")
  eq(b.enemy.mon.species, "GEODUDE", "Brock leads with GEODUDE")
end

do
  local b = newBrock()
  b.enemy.mon.status = "SLP"
  local act = b:enemyAction()
  check(act and act.id and act.special == nil,
        "enemyAction answers with a move, not the class item")
  local slot = b:trainerAIAction()
  check(slot and slot.special == "aiItem" and slot.item == "FULL_HEAL",
        "the slot roll is where BrockAI reaches for the FULL HEAL")
end

do
  local b = newBrock()
  local move = playerInflicts(b, "SLP")
  b:resolveTurn(move)
  local rows = drain(b)
  check(healed(rows), "BROCK uses the FULL HEAL the turn the status lands")
  eq(b.enemy.mon.status, nil, "AICureStatus cleared wEnemyMonStatus")
  eq(b.aiUses, 4, "DecrementAICount spent one of the five uses")
end

do
  local b = newBrock()
  b.enemy.mon.status = "PSN"
  b.enemy.bideTurns = 2
  b.enemy.bideDamage = 0
  check(b:enemyAction().special == "bide", "the foe is locked into Bide")
  local move = playerInflicts(b, "PSN")
  b:resolveTurn(move)
  local rows = drain(b)
  check(healed(rows), "the FULL HEAL preempts the locked Bide turn")
  eq(b.enemy.mon.status, nil, "the status is cured mid-Bide")
  eq(b.enemy.bideTurns, 2, "the Bide counter does not advance on the item turn")
  eq(b.aiUses, 4, "the item still costs a use")
end

-- wAICount at 0 rets before the class routine (trainer_ai.asm:306-308).
do
  local b = newBrock()
  b.aiUses = 0
  b.enemy.mon.status = "PSN"
  check(b:trainerAIAction() == nil, "no uses left, no roll")
  local move = playerInflicts(b, "PSN")
  b:resolveTurn(move)
  check(not healed(drain(b)), "an exhausted wAICount never prints an item use")
  eq(b.enemy.mon.status, "PSN", "the status stays on the foe")
end

S.finish()
