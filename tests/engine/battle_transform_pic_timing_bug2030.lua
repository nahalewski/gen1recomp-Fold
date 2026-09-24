-- engine/battle/move_effects/transform.asm:37-45 (#2030)
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
require("src.render.Font").load(Data)
local BattleState = require("src.battle.BattleState")
local Pokemon = require("src.pokemon.Pokemon")
local SaveData = require("src.core.SaveData")
local TypeChart = require("src.battle.TypeChart")
TypeChart.load(Data)

Data.moves.FIX_TRANSFORM = {
  id = "FIX_TRANSFORM", name = "FIX TRANSFORM", index = 144,
  power = 0, accuracy = 100, type = "NORMAL", pp = 10,
  effect = "TRANSFORM_EFFECT",
  anim = { seq = { { subanim = 33, delay = 6 },
                   { effect = "SE_TRANSFORM_MON" } } },
}

local function newBattle(animations)
  local save = SaveData.newGame()
  save.party = { Pokemon.new(Data, "FIXMON_A", 30) }
  save.options = save.options or {}
  save.options.animations = animations
  local game = { data = Data, save = save,
                 stack = { top = function() return nil end, push = function() end } }
  local battle = BattleState.newWild(game, "FIXMON_C", 30)
  battle.queue, battle.nextInsert = {}, 0
  return battle
end

local function indexOf(battle, pred)
  for i, item in ipairs(battle.queue) do
    if pred(item) then return i end
  end
  return nil
end

for _, animations in ipairs({ true, false }) do
  local label = animations and "animations on" or "animations off"
  local battle = newBattle(animations)
  local preSprite = battle.enemy.sprite
  battle:performMove(battle.enemy, battle.player, { id = "FIX_TRANSFORM", pp = 10 })

  T.eq(battle.enemy.sprite, preSprite,
    label .. ": the pic is untouched when performMove returns")

  local used = indexOf(battle, function(it)
    return it.text and it.text:find("used", 1, true) ~= nil
  end)
  local anim = indexOf(battle, function(it) return it.anim == "FIX_TRANSFORM" end)
  local fn = indexOf(battle, function(it) return it.fn ~= nil end)
  local said = indexOf(battle, function(it)
    return it.text and it.text:find("transformed", 1, true) ~= nil
  end)

  T.check(used ~= nil, label .. ": the announcement is queued")
  T.check(fn ~= nil, label .. ": the pic swap is queued as an act row")
  T.check(said ~= nil, label .. ": _TransformedText is queued")
  T.check(used < fn, label .. ": the announcement prints before the pic swap")
  T.check(fn < said, label .. ": the pic swaps before _TransformedText")
  if animations then
    T.check(anim ~= nil, label .. ": the move animation row is queued")
    T.check(used < anim, label .. ": the announcement prints before the animation")
    T.check(anim < fn, label .. ": the animation plays before the pic swap")
  else
    -- transform.asm:41-43
    T.eq(anim, nil, label .. ": no move animation row, so no 30-frame hold")
  end

  battle.queue[fn].fn()
  T.check(battle.enemy.sprite ~= preSprite,
    label .. ": running the act row swaps the pic")
  T.eq(battle.enemy.sprite,
    battle:speciesSprite(battle.player.mon.species, battle.enemy.isPlayer),
    label .. ": the copied pic is the target species' front sprite")

  -- special_effect_pointers.asm:30 already swapped it mid-animation
  local after = battle.enemy.sprite
  battle.queue[fn].fn()
  T.eq(battle.enemy.sprite, after, label .. ": the swap is idempotent")
end

do
  -- the copied stats/types/moves stay eager (transform.asm:57-132)
  local battle = newBattle(true)
  battle:performMove(battle.enemy, battle.player, { id = "FIX_TRANSFORM", pp = 10 })
  T.eq(battle.enemy.curStats.attack, battle.player.curStats.attack,
    "the stat copy still happens in the same call frame")
  T.eq(battle.enemy.curTypes[1], battle.player.curTypes[1],
    "the type copy still happens in the same call frame")
end

do
  -- special_effect_pointers.asm:30 stays the primary path
  local battle = newBattle(true)
  local preSprite = battle.enemy.sprite
  battle.animAttackerIsPlayer = false
  battle:applyAnimEffect({ effect = "SE_TRANSFORM_MON" })
  T.check(battle.enemy.sprite ~= preSprite,
    "SE_TRANSFORM_MON swaps the pic on its own")
end

T.finish("transform pic swaps with the animation (#2030)")
