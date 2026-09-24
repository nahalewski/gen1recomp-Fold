-- Parity test: an AI trainer switch clears the exp participant flags.
--
-- pokered's AI switch path calls EnemySendOut, which zeroes
-- wPartyGainExpFlags and re-flags only wPlayerMonNumber before falling
-- into EnemySendOutFirstMon (engine/battle/core.asm:1276-1292).  The port
-- kept the old participants, so a mon that had fought the withdrawn foe
-- still halved the exp for the newly sent-out one (#1826).
--
-- Self-contained; run via `luajit tests/parity_ai_switch_exp.lua`.
-- Also picked up by tests/run_tests.lua's parity_* glob.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.RATTATA) then Data:load() end
local TypeChart = require("src.battle.TypeChart")
TypeChart.load(Data)

local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")
local S = require("tests.harness").suite("parity ai switch exp")
local check, eq = S.check, S.eq

local function freshGame()
  return {
    data = Data,
    save = {
      party = { Pokemon.new(Data, "BULBASAUR", 50), Pokemon.new(Data, "CHARMANDER", 50) },
      player = { name = "RED", id = 1234 },
      inventory = {},
      options = { battleStyle = "set" },
      pokedex = { seen = {}, owned = {} },
      flags = {},
      money = 0,
    },
    stack = { push = function() end, pop = function() end, top = function() end },
  }
end

-- Both party mons fought the first foe; the AI then withdraws it.
local function battleAfterAiSwitch()
  local Game = freshGame()
  local b = BattleState.newTrainer(Game, "OPP_AGATHA", 1)
  check(#b.enemyParty >= 2, "the trainer has a reserve to switch to")
  b.participants = { [Game.save.party[1]] = true, [Game.save.party[2]] = true }
  b:executeAction(b.enemy, b.player, { special = "aiSwitch", index = 2 })
  return Game, b
end

do
  local Game, b = battleAfterAiSwitch()
  eq(b.participants[Game.save.party[1]], true,
    "the mon on the field is the one participant after the switch")
  eq(b.participants[Game.save.party[2]], nil,
    "the benched mon lost its gain-exp flag (core.asm:1276-1289)")
end

-- The divisor follows: the on-field mon takes the whole share, and the
-- benched one earns nothing off the new foe's KO.
do
  local Game, b = battleAfterAiSwitch()
  b.enemy.mon.hp = 0
  local before1 = Game.save.party[1].exp
  local before2 = Game.save.party[2].exp
  b:awardExp()
  local gainedSwitched = Game.save.party[1].exp - before1
  check(gainedSwitched > 0, "the mon on the field is paid for the KO")
  eq(Game.save.party[2].exp - before2, 0, "the benched mon is paid nothing")

  -- Reference: the same KO with a single flagged participant from the start.
  local Game2 = freshGame()
  local b2 = BattleState.newTrainer(Game2, "OPP_AGATHA", 1)
  b2:executeAction(b2.enemy, b2.player, { special = "aiSwitch", index = 2 })
  b2.participants = { [Game2.save.party[1]] = true }
  b2.enemy.mon.hp = 0
  local ref = Game2.save.party[1].exp
  b2:awardExp()
  eq(gainedSwitched, Game2.save.party[1].exp - ref,
    "the share is undivided, not halved by the stale participant")
end

S.finish()
