-- engine/battle/move_effects/curse.asm:36

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")
local Effects = require("src.battle.gen2.Effects")

local TYPES = {
  NORMAL = { id = "NORMAL", index = 0, category = "physical" },
  GHOST = { id = "GHOST", index = 1, category = "physical" },
}

local MOVES = {
  TACKLE = { id = "TACKLE", name = "TACKLE", power = 35, type = "NORMAL",
    accuracy = 100, pp = 35, effect = "EFFECT_NORMAL_HIT" },
  CURSE = { id = "CURSE", name = "CURSE", power = 0, type = "GHOST",
    accuracy = 100, pp = 10, effect = "EFFECT_CURSE" },
}

local POKEMON = {
  growthRates = {
    GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1, squared = 0,
      linear = 0, constant = 0 },
  },
  SNORLAX = { id = "SNORLAX", index = 143, name = "SNORLAX",
    baseStats = { hp = 160, attack = 110, defense = 65, speed = 30,
      specialAttack = 65, specialDefense = 110 },
    types = { "NORMAL", "NORMAL" }, catchRate = 25, baseExp = 154,
    growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 31,
    levelMoves = {}, evolutions = {} },
  GASTLY = { id = "GASTLY", index = 92, name = "GASTLY",
    baseStats = { hp = 30, attack = 35, defense = 30, speed = 80,
      specialAttack = 100, specialDefense = 35 },
    types = { "GHOST", "GHOST" }, catchRate = 190, baseExp = 95,
    growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 127,
    levelMoves = {}, evolutions = {} },
}

local DATA = { pokemon = POKEMON, moves = MOVES,
  type_chart = { types = TYPES, matchups = {} }, items = {} }

local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
perfect.hp = Mon.hpDV(perfect)

local function highRoll(n) return (n or 1) - 1 end

local function newBattle(species)
  local player = Mon.new(DATA, species, 50, { dvs = perfect })
  player.moves = { { id = "CURSE", pp = 10, maxPp = 10 } }
  local wild = Mon.new(DATA, "SNORLAX", 50, { dvs = perfect })
  wild.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }
  return Battle.new({ data = DATA, party = { player }, wild = wild,
    random = highRoll }), player, wild
end

local function moveEvent(events)
  for _, e in ipairs(events or {}) do
    if e.kind == "move" then return e end
  end
end

do
  local battle, player, wild = newBattle("SNORLAX")
  battle.events = {}
  battle:useMove(player, wild, "CURSE")
  local ev = moveEvent(battle.events)
  T.check(ev ~= nil, "the non-ghost CURSE turn queues a move event")
  T.eq(ev and ev.animParam, 1,
    "non-ghost CURSE carries animParam 1, the stat-streak script arm")
  local stages = battle.stages[battle:sideOf(player)]
  T.eq(stages.attack, 1, "and ATTACK still rises")
  T.eq(stages.defense, 1, "and DEFENSE still rises")
  T.eq(stages.speed, -1, "and SPEED still drops")
end

do
  local battle, player, wild = newBattle("SNORLAX")
  local stages = battle.stages[battle:sideOf(player)]
  stages.attack = Effects.MAX_STAGE
  stages.defense = Effects.MAX_STAGE
  battle.events = {}
  battle:useMove(player, wild, "CURSE")
  local ev = moveEvent(battle.events)
  T.check(ev ~= nil, "the capped turn still queues a move event")
  T.eq(ev and ev.animParam, nil,
    "the cantraise arm leaves animParam nil")
end

do
  local battle, player, wild = newBattle("GASTLY")
  battle.events = {}
  battle:useMove(player, wild, "CURSE")
  local ev = moveEvent(battle.events)
  T.check(ev ~= nil, "the ghost CURSE turn queues a move event")
  T.eq(ev and ev.animParam, nil,
    "ghost CURSE leaves animParam nil, the nail-and-doll script arm")
  T.check(battle:volatile(wild).cursed == true, "and the target is cursed")
end

T.finish("gen2 curse anim param bug 2099")
