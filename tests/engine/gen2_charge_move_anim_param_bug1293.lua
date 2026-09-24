-- engine/battle/effect_commands.asm:5458 BattleCommand_Charge

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")

local TYPES = {
  NORMAL = { id = "NORMAL", index = 0, category = "physical" },
  GROUND = { id = "GROUND", index = 1, category = "physical" },
  FLYING = { id = "FLYING", index = 2, category = "physical" },
}

local MOVES = {
  TACKLE = { id = "TACKLE", name = "TACKLE", power = 35, type = "NORMAL",
    accuracy = 100, pp = 35, effect = "EFFECT_NORMAL_HIT" },
  DIG = { id = "DIG", name = "DIG", power = 60, type = "GROUND",
    accuracy = 100, pp = 10, effect = "EFFECT_FLY" },
  FLY = { id = "FLY", name = "FLY", power = 70, type = "FLYING",
    accuracy = 95, pp = 15, effect = "EFFECT_FLY" },
}

local POKEMON = {
  growthRates = {
    GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1, squared = 0,
      linear = 0, constant = 0 },
  },
  MACHOP = { id = "MACHOP", index = 66, name = "MACHOP",
    baseStats = { hp = 70, attack = 80, defense = 50, speed = 35,
      specialAttack = 35, specialDefense = 35 },
    types = { "NORMAL", "NORMAL" }, catchRate = 180, baseExp = 75,
    growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 63,
    levelMoves = {}, evolutions = {} },
}

local DATA = { pokemon = POKEMON, moves = MOVES,
  type_chart = { types = TYPES, matchups = {} }, items = {} }

local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
perfect.hp = Mon.hpDV(perfect)

local function highRoll(n) return (n or 1) - 1 end

local function newBattle(moveId)
  local player = Mon.new(DATA, "MACHOP", 50, { dvs = perfect })
  player.moves = { { id = moveId, pp = 20, maxPp = 20 } }
  local wild = Mon.new(DATA, "MACHOP", 50, { dvs = perfect })
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
  local battle, player, wild = newBattle("DIG")
  battle.events = {}
  battle:useMove(player, wild, "DIG")
  local ev = moveEvent(battle.events)
  T.check(ev ~= nil, "the charge turn queues a move event")
  T.eq(ev and ev.animParam, 1,
    "DIG's charge (burrow) turn carries animParam 1, the take-cover script arm")
  battle.events = {}
  battle:useMove(player, wild, "DIG")
  local ev2 = moveEvent(battle.events)
  T.check(ev2 ~= nil, "the strike turn also queues a move event")
  T.eq(ev2 and ev2.animParam, nil,
    "DIG's strike turn leaves animParam nil, the hit script arm")
end

do
  local battle, player, wild = newBattle("FLY")
  battle.events = {}
  battle:useMove(player, wild, "FLY")
  local ev = moveEvent(battle.events)
  T.eq(ev and ev.animParam, 1, "FLY's take-off turn also carries animParam 1")
end

-- a plain hit-and-run move never sets a parameter at all
do
  local battle, player, wild = newBattle("DIG")
  player.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }
  battle.events = {}
  battle:useMove(player, wild, "TACKLE")
  local ev = moveEvent(battle.events)
  T.eq(ev and ev.animParam, nil, "a non-charge move never carries animParam")
end

T.finish("gen2 charge move anim param bug 1293")
