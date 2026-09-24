-- engine/battle/effect_commands.asm:1958-1961 (the 40 frame hold),
-- engine/battle/effect_commands.asm:3615 (.CheckAIRandomFail, the 25% roll)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")
local UI = require("src.ui.gen2.BattleState")

local TYPES = {
  NORMAL = { id = "NORMAL", index = 0, category = "physical" },
  ELECTRIC = { id = "ELECTRIC", index = 1, category = "special" },
}

local MOVES = {
  TACKLE = { id = "TACKLE", name = "TACKLE", power = 35, type = "NORMAL",
    accuracy = 100, pp = 35, effect = "EFFECT_NORMAL_HIT" },
  GROWL = { id = "GROWL", name = "GROWL", power = 0, type = "NORMAL",
    accuracy = 100, pp = 40, effect = "EFFECT_ATTACK_DOWN" },
  THUNDER_WAVE = { id = "THUNDER_WAVE", name = "THUNDER WAVE", power = 0,
    type = "ELECTRIC", accuracy = 100, pp = 20, effect = "EFFECT_PARALYZE" },
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

-- a controllable roll queue; falls back to a high roll (never fails an AI
-- check) once drained
local rolls
local function rng(n)
  if rolls and #rolls > 0 then return table.remove(rolls, 1) % math.max(1, n) end
  return (n or 1) - 1
end

local function newBattle(pmoves, emoves)
  local player = Mon.new(DATA, "MACHOP", 50, { dvs = perfect })
  player.moves = pmoves
  local wild = Mon.new(DATA, "MACHOP", 50, { dvs = perfect })
  wild.moves = emoves
  return Battle.new({ data = DATA, party = { player }, wild = wild,
    random = rng }), player, wild
end

local function findText(events, sub)
  for _, e in ipairs(events or {}) do
    if e.kind == "message" and e.text and e.text:find(sub, 1, true) then
      return true
    end
  end
  return false
end
local function moveEvent(events)
  for _, e in ipairs(events or {}) do
    if e.kind == "move" then return e end
  end
end

-- ---------------------------------------------------------------- gap 2:
-- the AI's 25% "miss" on a support move, and who is exempt from the roll.
do
  local battle, player, wild = newBattle(
    { { id = "TACKLE", pp = 35, maxPp = 35 } },
    { { id = "GROWL", pp = 40, maxPp = 40 } })
  battle.events = {}
  rolls = { 0, 10 } -- accuracy roll, then the AI roll (10 < 64: fails)
  battle:useMove(wild, player, "GROWL")
  T.check(findText(battle.events, "But it failed!"),
    "enemy GROWL fails 25% of the time with the specific line")
  T.eq(moveEvent(battle.events) and moveEvent(battle.events).missed, true,
    "an AI-failed move is marked missed (feeds the 40 frame hold)")
end

do
  local battle, player, wild = newBattle(
    { { id = "TACKLE", pp = 35, maxPp = 35 } },
    { { id = "GROWL", pp = 40, maxPp = 40 } })
  battle.events = {}
  rolls = { 0, 200 } -- AI roll passes (>=64): lands
  battle:useMove(wild, player, "GROWL")
  T.check(not findText(battle.events, "But it failed!"),
    "the same move lands when the AI roll passes")
end

do
  local battle, player, wild = newBattle(
    { { id = "GROWL", pp = 40, maxPp = 40 } },
    { { id = "TACKLE", pp = 35, maxPp = 35 } })
  battle.events = {}
  rolls = { 0, 10 } -- if the player rolled too, 10 would fail it
  battle:useMove(player, wild, "GROWL")
  T.check(not findText(battle.events, "But it failed!"),
    "the player's own GROWL is exempt from the AI roll")
end

-- --------------------------------------------------------------- gap 1:
-- the reported symptom -- the "used X!" line must hold before a failure.
do
  local input = { wasPressed = function() return false end }
  local ui = setmetatable({
    game = { input = input },
    phase = "resolving", slideFrame = 999, messageTimer = 0,
    picHidden = { player = false, enemy = false },
    queue = {
      { kind = "move", side = "enemy", move = "GROWL",
        text = "Enemy MACHOP used GROWL!", missed = true },
      { kind = "message", text = "But it failed!" },
    },
    updateAlarm = function() end,
    stepHpAnim = function() return false end,
    stepExpAnim = function() return false end,
  }, { __index = UI })

  ui:advanceQueue()
  T.eq(ui.message, "Enemy MACHOP used GROWL!", "the used-move line is shown first")
  T.eq(ui.messageDelay, 40,
    "a missed move arms the 40 frame delay (effect_commands.asm's MoveDelay)")
  T.eq(ui.messageTimer, 0, "no separate A/B hold on the move line itself")

  local frames, printed = 0, nil
  for _ = 1, 400 do
    if ui.message == "But it failed!" then break end
    if printed == nil and not ui:syncTyper() then printed = frames end
    ui:update(1 / 60)
    frames = frames + 1
  end
  T.eq(ui.message, "But it failed!", "the queue eventually reaches the failure line")
  T.check(printed ~= nil and printed > 0, "the used line typed itself out")
  T.eq(frames, printed + 41, "the used line held for exactly the 40 delay frames")
  T.check(ui.messageTimer > 0, "the failure line itself still holds for A/B")
end

do
  local input = { wasPressed = function() return false end }
  local ui2 = setmetatable({
    game = { input = input },
    phase = "resolving", slideFrame = 999, messageTimer = 0,
    picHidden = { player = false, enemy = false },
    queue = { { kind = "move", side = "player", move = "TACKLE",
      text = "MACHOP used TACKLE!" } },
    updateAlarm = function() end,
    stepHpAnim = function() return false end,
    stepExpAnim = function() return false end,
    animForMove = function() return false end,
  }, { __index = UI })
  ui2:advanceQueue()
  T.eq(ui2.messageDelay or 0, 0, "a move that lands arms no delay at all")
end

T.finish("gen2 enemy move fail text bug 1296")
