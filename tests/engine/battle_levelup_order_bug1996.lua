-- before GrewLevelText (engine/battle/experience.asm:149-256).  GrewLevelText
-- is sound_level_up + text_end with no prompt (data/text/text_2.asm:1228-1234),
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
require("src.render.Font").load(Data)

local BattleState = require("src.battle.BattleState")
local Experience = require("src.battle.Experience")
local Growth = require("src.pokemon.Growth")
local Pokemon = require("src.pokemon.Pokemon")
local SaveData = require("src.core.SaveData")
local Timing = require("src.core.Timing")
local TypeChart = require("src.battle.TypeChart")
TypeChart.load(Data)

local function newGame(mon)
  local save = SaveData.newGame()
  save.player.name = "RED"
  save.party = { mon }
  return {
    data = Data, save = save,
    stack = { top = function() return nil end, push = function() end },
    input = { wasPressed = function() return false end,
              isDown = function() return false end },
  }
end

local function monAtBrink(level)
  local mon = Pokemon.new(Data, "FIXMON_A", level, function(_, b) return b end)
  mon.exp = Growth.expForLevel(Data.pokemon.FIXMON_A.growthRate, level + 1,
                               Data.growth_rates) - 1
  return mon
end


do
  local eager, deferred = monAtBrink(10), monAtBrink(10)
  local baseLevel, baseMax = eager.level, eager.stats.hp
  eager.hp, deferred.hp = 4, 4

  local eagerLevels, eagerGained = Experience.apply(Data, eager,
    Data.pokemon.FIXMON_C, 10, false, 1, false)
  local levels, gained, steps = Experience.apply(Data, deferred,
    Data.pokemon.FIXMON_C, 10, false, 1, false, { defer = true })

  T.eq(#levels, #eagerLevels, "defer reports the same level count")
  T.eq(levels[1], eagerLevels[1], "defer reports the same first level")
  T.eq(gained, eagerGained, "defer reports the same exp award")
  T.eq(deferred.exp, eager.exp, "exp is credited either way (experience.asm:129)")
  T.eq(deferred.level, baseLevel, "defer leaves mon.level uncommitted")
  T.eq(deferred.stats.hp, baseMax, "defer leaves mon.stats uncommitted")
  T.eq(deferred.hp, 4, "defer leaves mon.hp uncommitted")
  T.eq(#steps, #levels, "one step per level gained")
  T.eq(steps[1].level, levels[1], "the step carries its level")
  T.check(steps[1].stats.hp > baseMax, "the step carries the grown stats")
  T.eq(steps[1].hp, 4 + (steps[1].stats.hp - baseMax),
    "the step carries the max-HP delta (experience.asm:194-200)")

  Experience.commit(Data, deferred, steps[1])
  T.eq(deferred.level, eager.level, "commit lands the same level")
  T.eq(deferred.stats.hp, eager.stats.hp, "commit lands the same max HP")
  T.eq(deferred.hp, eager.hp, "commit lands the same current HP")
end

do
  local mon = Pokemon.new(Data, "FIXMON_A", 5, function(_, b) return b end)
  mon.exp = Growth.expForLevel(Data.pokemon.FIXMON_A.growthRate, 9,
                               Data.growth_rates)
  local levels, _, steps = Experience.apply(Data, mon, Data.pokemon.FIXMON_C,
                                            5, false, 1, false, { defer = true })
  T.check(#levels >= 2, "a multi-level jump reports every level")
  for i = 2, #steps do
    T.check(steps[i].level == steps[i - 1].level + 1,
      "step " .. i .. " advances one level")
    T.check(steps[i].stats.hp >= steps[i - 1].stats.hp,
      "step " .. i .. " never loses max HP")
  end
  T.eq(mon.level, 5, "and none of them is committed")
end


local function awardOnce()
  local mon = monAtBrink(10)
  mon.hp = 4
  local game = newGame(mon)
  local battle = BattleState.newWild(game, "FIXMON_C", 10)
  battle.queue, battle.nextInsert = {}, 0
  battle.participants = { [mon] = true }
  battle:awardExp()
  return battle, mon
end

do
  local battle = awardOnce()
  local q = battle.queue
  T.check(q[1] ~= nil and q[1].text ~= nil,
    "row 1 is the gained-EXP page (experience.asm:149)")
  T.eq(q[1].auto, nil, "the gained-EXP page keeps its prompt (_ExpPointsText)")
  T.check(q[2] ~= nil and type(q[2].fn) == "function",
    "row 2 writes the level (experience.asm:158-239)")
  T.check(q[3] ~= nil and q[3].text ~= nil, "row 3 is the grew-level page")
  T.eq(q[3].auto, true, "GrewLevelText ends in text_end, not prompt")
  T.eq(type(q[3].waitForLearningSfx), "function",
    "GrewLevelText still waits out sound_level_up")
  T.check(q[4] ~= nil and type(q[4].ui) == "function",
    "row 4 is PrintStatsBox (experience.asm:249)")
  for i, row in ipairs(q) do
    T.eq(row.drain, nil, "row " .. i .. " does not animate the HP bar")
  end
end

do
  local battle, mon = awardOnce()
  local oldLevel, oldMax = 10, mon.stats.hp
  T.eq(mon.level, oldLevel, "the level has not moved while the pages queue")
  T.eq(mon.stats.hp, oldMax, "nor has the HUD's max-HP denominator")
  T.eq(battle.player.shownHP, 4, "nor the bar")

  battle.queue[2].fn()
  T.eq(mon.level, oldLevel + 1, "the queued row writes the level")
  T.check(mon.stats.hp > oldMax, "and the new max HP")
  T.eq(mon.hp, 4 + (mon.stats.hp - oldMax), "and the max-HP delta")
  T.eq(battle.player.shownHP, mon.hp,
    "DrawPlayerHUDAndHPBar snaps the bar (experience.asm:239)")
  T.eq(battle.player.shownPx,
    Timing.hpBarPixels(mon.hp, math.max(1, mon.stats.hp)),
    "including its pixel length")
  T.eq(battle.player.badgeExtraBoosts, nil,
    "ApplyBadgeStatBoosts is re-run (experience.asm:238)")
end


do
  local mon = monAtBrink(10)
  local game = newGame(mon)
  local battle = BattleState.newWild(game, "FIXMON_C", 10)
  battle.queue, battle.nextInsert = {}, 0

  local Sound = require("src.core.Sound")
  local origWait = Sound.waitFrames
  Sound.waitFrames = function() return 3 end
  local playing, sfxCalls = true, 0
  battle:sayNextAutoWaitSfx("FIXMON A GREW\nTO LEVEL 11!", function()
    sfxCalls = sfxCalls + 1
    return { isPlaying = function() return playing end,
             stop = function() end }
  end)

  local frames = 0
  while battle.queue[1] or battle.current or battle.waitingSound do
    battle:updateQueue()
    frames = frames + 1
    if frames > 2000 then break end
    if battle.waitingSound and frames > 400 then playing = false end
  end
  Sound.waitFrames = origWait

  T.eq(sfxCalls, 1, "the auto page still plays sound_level_up")
  T.eq(battle.current, nil, "and clears with no A/B press")
  T.eq(battle.msgPrompt, nil, "no prompt arrow was ever raised")
  T.check(frames <= 2000, "the queue did not wedge")
end


-- engine/battle/core.asm:829-858
local function awardWithExpAll(startLevel)
  local mon = monAtBrink(startLevel)
  mon.hp = 4
  local game = newGame(mon)
  game.save.inventory.EXP_ALL = 1
  local battle = BattleState.newWild(game, "FIXMON_C", 10)
  battle.queue, battle.nextInsert = {}, 0
  battle.participants = { [mon] = true }
  battle:awardExp()
  local gainedPages, grewLevels, fnRows, uiRows = {}, {}, {}, {}
  for _, row in ipairs(battle.queue) do
    if type(row.text) == "string" then
      local lv = row.text:match("to level (%d+)!")
      if lv then
        table.insert(grewLevels, tonumber(lv))
      elseif row.text:match("EXP%. Points!") then
        table.insert(gainedPages, row.text)
      end
    elseif type(row.fn) == "function" then
      table.insert(fnRows, row.fn)
    elseif type(row.ui) == "function" then
      table.insert(uiRows, row.ui)
    end
  end
  return battle, mon, gainedPages, grewLevels, fnRows, uiRows
end

do
  local _, mon, gained, grew, fnRows, uiRows = awardWithExpAll(10)
  T.eq(#gained, 2, "both shares print their own gained-EXP page")
  T.check(gained[2]:match("with EXP%.ALL,") ~= nil,
    "the party pass carries _WithExpAllText")
  T.eq(#grew, 1, "one grew-level page for the one level crossed")
  T.eq(grew[1], 11, "and it names level 11")
  T.eq(#fnRows, 1, "one commit row")
  T.eq(#uiRows, 1, "one PrintStatsBox (experience.asm:249)")
  T.eq(mon.level, 10, "the level is still uncommitted while the pages queue")
  fnRows[1]()
  T.eq(mon.level, 11, "the commit row lands the level once")
end

do
  local _, mon, _, grew, fnRows, uiRows = awardWithExpAll(5)
  local final = Growth.levelForExp(Data.pokemon.FIXMON_A.growthRate, mon.exp,
                                   100, Data.growth_rates)
  T.check(final > 6, "both shares together cross more than one level")
  T.eq(#grew, final - 5, "one grew-level page per level crossed")
  for i = 2, #grew do
    T.eq(grew[i], grew[i - 1] + 1,
      "grew page " .. i .. " names the next level, never a repeat")
  end
  T.eq(#fnRows, #grew, "one commit row per grew page")
  T.eq(#uiRows, #grew, "one stat box per grew page")
  for _, fn in ipairs(fnRows) do fn() end
  T.eq(mon.level, final, "the commit rows walk to the final level")
end

T.finish()
