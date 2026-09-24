-- engine/battle/effect_commands.asm:121 (CheckTurn zeroes wBattleAnimParam)
-- engine/battle_anims/anim_commands.asm:550 (BattleAnimCmd_IfParamEqual)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")

local TYPES = {}
for i, id in ipairs({ "NORMAL", "GHOST", "GROUND", "FLYING", "FIGHTING",
    "GRASS", "DARK", "BUG", "WATER" }) do
  TYPES[id] = { id = id, index = i - 1,
    category = (id == "GRASS" or id == "WATER" or id == "DARK")
      and "special" or "physical" }
end

local function move(id, effect, power, type, accuracy)
  return { id = id, name = id, power = power, type = type,
    accuracy = accuracy or 100, pp = 20, effect = effect }
end

local MOVES = {
  TACKLE = move("TACKLE", "EFFECT_NORMAL_HIT", 35, "NORMAL"),
  CURSE = move("CURSE", "EFFECT_CURSE", 0, "GHOST"),
  DIG = move("DIG", "EFFECT_FLY", 60, "GROUND"),
  FLY = move("FLY", "EFFECT_FLY", 70, "FLYING"),
  RAZOR_WIND = move("RAZOR_WIND", "EFFECT_RAZOR_WIND", 80, "NORMAL"),
  SKULL_BASH = move("SKULL_BASH", "EFFECT_SKULL_BASH", 100, "NORMAL"),
  SKY_ATTACK = move("SKY_ATTACK", "EFFECT_SKY_ATTACK", 140, "FLYING"),
  SOLARBEAM = move("SOLARBEAM", "EFFECT_SOLARBEAM", 120, "GRASS"),
  SELFDESTRUCT = move("SELFDESTRUCT", "EFFECT_SELFDESTRUCT", 200, "NORMAL"),
  EXPLOSION = move("EXPLOSION", "EFFECT_SELFDESTRUCT", 250, "NORMAL"),
  BIDE = move("BIDE", "EFFECT_BIDE", 0, "NORMAL"),
  ROAR = move("ROAR", "EFFECT_FORCE_SWITCH", 0, "NORMAL"),
  WHIRLWIND = move("WHIRLWIND", "EFFECT_FORCE_SWITCH", 0, "NORMAL"),
  PRESENT = move("PRESENT", "EFFECT_PRESENT", 1, "NORMAL", 90),
  HI_JUMP_KICK = move("HI_JUMP_KICK", "EFFECT_JUMP_KICK", 85, "FIGHTING", 90),
  JUMP_KICK = move("JUMP_KICK", "EFFECT_JUMP_KICK", 70, "FIGHTING", 95),
  COMET_PUNCH = move("COMET_PUNCH", "EFFECT_MULTI_HIT", 18, "NORMAL", 85),
  DOUBLESLAP = move("DOUBLESLAP", "EFFECT_MULTI_HIT", 15, "NORMAL", 85),
  FURY_SWIPES = move("FURY_SWIPES", "EFFECT_MULTI_HIT", 18, "NORMAL", 80),
  DOUBLE_KICK = move("DOUBLE_KICK", "EFFECT_DOUBLE_HIT", 30, "FIGHTING"),
  TRIPLE_KICK = move("TRIPLE_KICK", "EFFECT_TRIPLE_KICK", 10, "FIGHTING", 90),
  DESTINY_BOND = move("DESTINY_BOND", "EFFECT_DESTINY_BOND", 0, "GHOST"),
  BEAT_UP = move("BEAT_UP", "EFFECT_BEAT_UP", 10, "DARK"),
  FURY_CUTTER = move("FURY_CUTTER", "EFFECT_FURY_CUTTER", 10, "BUG", 95),
  MOONLIGHT = move("MOONLIGHT", "EFFECT_MOONLIGHT", 0, "NORMAL"),
  MORNING_SUN = move("MORNING_SUN", "EFFECT_MORNING_SUN", 0, "NORMAL"),
  SYNTHESIS = move("SYNTHESIS", "EFFECT_SYNTHESIS", 0, "GRASS"),
  OCTAZOOKA = move("OCTAZOOKA", "EFFECT_ACCURACY_DOWN_HIT", 65, "WATER", 85),
  PURSUIT = move("PURSUIT", "EFFECT_PURSUIT", 40, "DARK"),
  SUBSTITUTE = move("SUBSTITUTE", "EFFECT_SUBSTITUTE", 0, "NORMAL"),
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
}

local DATA = { pokemon = POKEMON, moves = MOVES,
  type_chart = { types = TYPES, matchups = {} }, items = {} }

local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
perfect.hp = Mon.hpDV(perfect)

local function lowRoll() return 0 end

local function newBattle(moveId, random)
  local player = Mon.new(DATA, "SNORLAX", 50, { dvs = perfect })
  player.moves = { { id = moveId, pp = 20, maxPp = 20 } }
  local wild = Mon.new(DATA, "SNORLAX", 50, { dvs = perfect })
  wild.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }
  return Battle.new({ data = DATA, party = { player }, wild = wild,
    random = random or lowRoll }), player, wild
end

local function moveEvent(events)
  for _, e in ipairs(events or {}) do
    if e.kind == "move" then return e end
  end
end

local function turn(battle, player, wild, moveId)
  battle.events = {}
  battle:useMove(player, wild, moveId)
  return moveEvent(battle.events)
end

local function once(moveId, random)
  return function()
    local battle, player, wild = newBattle(moveId, random)
    return turn(battle, player, wild, moveId)
  end
end

local ENFORCED = {
  CURSE = { param = 1, cite = "move_effects/curse.asm:39", run = once("CURSE") },
  DIG = { param = 1, cite = "effect_commands.asm:5500", charge = true },
  FLY = { param = 1, cite = "effect_commands.asm:5500", charge = true },
  RAZOR_WIND = { param = 1, cite = "effect_commands.asm:5500", charge = true },
  SKULL_BASH = { param = 1, cite = "effect_commands.asm:5500", charge = true },
  SKY_ATTACK = { param = 1, cite = "effect_commands.asm:5500", charge = true },
  SOLARBEAM = { param = 1, cite = "effect_commands.asm:5500", charge = true },
}

local KNOWN_MISSING = {
  SELFDESTRUCT = { param = 1, cite = "move_effects/selfdestruct.asm:14",
    run = once("SELFDESTRUCT") },
  EXPLOSION = { param = 1, cite = "move_effects/selfdestruct.asm:14",
    run = once("EXPLOSION") },
  BIDE = { param = 1, cite = "move_effects/bide.asm:93", run = function()
    local battle, player, wild = newBattle("BIDE")
    local ev
    for _ = 1, 4 do
      ev = turn(battle, player, wild, "BIDE")
      if not battle:volatile(player).bideTurns then break end
    end
    return ev
  end },
  ROAR = { param = 1, cite = "effect_commands.asm:5160", run = once("ROAR") },
  WHIRLWIND = { param = 1, cite = "effect_commands.asm:5160",
    run = once("WHIRLWIND") },
  PRESENT = { param = 3, cite = "move_effects/present.asm:42",
    run = once("PRESENT") },
  HI_JUMP_KICK = { param = 1, cite = "effect_commands.asm:2246",
    run = once("HI_JUMP_KICK", function(n) return (n or 256) - 1 end) },
  JUMP_KICK = { param = 1, cite = "effect_commands.asm:2246",
    run = once("JUMP_KICK", function(n) return (n or 256) - 1 end) },
  COMET_PUNCH = { param = 1, cite = "effect_commands.asm:1994",
    run = once("COMET_PUNCH") },
  DOUBLESLAP = { param = 1, cite = "effect_commands.asm:1994",
    run = once("DOUBLESLAP") },
  FURY_SWIPES = { param = 1, cite = "effect_commands.asm:1994",
    run = once("FURY_SWIPES") },
  DOUBLE_KICK = { param = 1, cite = "effect_commands.asm:1994",
    run = once("DOUBLE_KICK") },
  TRIPLE_KICK = { param = 1, cite = "move_effects/triple_kick.asm:27",
    run = once("TRIPLE_KICK") },
  DESTINY_BOND = { param = 1, cite = "effect_commands.asm:2394",
    run = once("DESTINY_BOND") },
}

local DEAD_ARMS = {
  BEAT_UP = "effect_commands.asm:121",
  FURY_CUTTER = "effect_commands.asm:121",
  MOONLIGHT = "effect_commands.asm:121",
  MORNING_SUN = "effect_commands.asm:121",
  OCTAZOOKA = "effect_commands.asm:121",
  PURSUIT = "effect_commands.asm:121",
  SYNTHESIS = "effect_commands.asm:121",
  SUBSTITUTE = "move_effects/substitute.asm:63",
}

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

for _, id in ipairs(sortedKeys(ENFORCED)) do
  local spec = ENFORCED[id]
  if spec.charge then
    local battle, player, wild = newBattle(id)
    local ev = turn(battle, player, wild, id)
    check(ev ~= nil, id .. ": the charge turn queues a move event")
    eq(ev and ev.animParam, spec.param,
      ("%s: charge turn stamps animParam %d (%s)"):format(id, spec.param, spec.cite))
    local ev2 = turn(battle, player, wild, id)
    check(ev2 ~= nil, id .. ": the strike turn queues a move event")
    eq(ev2 and ev2.animParam, nil, id .. ": the strike turn leaves animParam nil")
  else
    local ev = spec.run()
    check(ev ~= nil, id .. ": queues a move event")
    eq(ev and ev.animParam, spec.param,
      ("%s: stamps animParam %d (%s)"):format(id, spec.param, spec.cite))
  end
end

for _, id in ipairs(sortedKeys(KNOWN_MISSING)) do
  local spec = KNOWN_MISSING[id]
  check(ENFORCED[id] == nil, id .. ": listed once, not in both sets")
  local ev = spec.run()
  check(ev ~= nil, id .. ": queues a move event")
  check(ev and ev.animParam ~= spec.param,
    ("%s: animParam %d (%s) is not stamped yet; move it to ENFORCED"):format(
      id, spec.param, spec.cite))
end

for id in pairs(DEAD_ARMS) do
  check(ENFORCED[id] == nil and KNOWN_MISSING[id] == nil,
    id .. ": a dead arm is listed nowhere else")
end

local cache = os.getenv("GOLD_CACHE")
  or ((os.getenv("HOME") or "") .. "/Library/Application Support/LOVE/gold-dev/gold")
local anims = loadfile(cache .. "/data/generated/battle_anims.lua")
local data = anims and anims()
if data and data.scripts and data.moves then
  local branching = {}
  for id, key in pairs(data.moves) do
    for _, row in ipairs(data.scripts[key] or {}) do
      if row[1] == "if_param_equal" or row[1] == "if_param_and" then
        branching[id] = true
        break
      end
    end
  end
  for _, id in ipairs(sortedKeys(branching)) do
    check(ENFORCED[id] or KNOWN_MISSING[id] or DEAD_ARMS[id],
      id .. ": the cart script branches on the param, so it is classified")
  end
  for _, set in ipairs({ ENFORCED, KNOWN_MISSING, DEAD_ARMS }) do
    for _, id in ipairs(sortedKeys(set)) do
      check(branching[id], id .. ": the cart script really branches on the param")
    end
  end
else
  check(true, "no Gold cache at " .. cache .. " (cart script cross-check SKIP)")
end

T.finish("gen2 anim param feed sweep")
