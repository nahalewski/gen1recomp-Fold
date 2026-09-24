-- engine/pokemon/evolve.asm:261-290
package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("gen2 evolution stat exp")
local check, eq = S.check, S.eq

love = require("tests.love_stub")

local Evolution = require("src.core.gen2.Evolution")
local Mon = require("src.battle.gen2.Mon")

local function base(hp, attack, defense, speed, spa, spd)
  return { hp = hp, attack = attack, defense = defense, speed = speed,
    specialAttack = spa, specialDefense = spd }
end

local DATA = {
  moves = {},
  pokemon = {
    growthRates = {
      MEDIUM_FAST = { numerator = 1, denominator = 1, squared = 0, linear = 0,
        constant = 0 },
    },
    CHIKORITA = {
      name = "CHIKORITA", index = 152, growthRate = "MEDIUM_FAST",
      genderRatio = 0x1f, types = { "GRASS" },
      baseStats = base(45, 49, 65, 45, 49, 65),
      evolutions = { { method = "EVOLVE_LEVEL", level = 16, into = "BAYLEEF" } },
      levelMoves = { { level = 1, move = "TACKLE" } },
    },
    BAYLEEF = {
      name = "BAYLEEF", index = 153, growthRate = "MEDIUM_FAST",
      genderRatio = 0x1f, types = { "GRASS" },
      baseStats = base(60, 62, 80, 60, 63, 80),
      evolutions = {},
      levelMoves = { { level = 1, move = "TACKLE" } },
    },
  },
}
local LEVEL = 16
local DVS = { attack = 12, defense = 9, speed = 7, special = 14 }
local ENTRY = DATA.pokemon.CHIKORITA.evolutions[1]

local function newChikorita(statExp)
  local mon = Mon.new(DATA, "CHIKORITA", LEVEL, { dvs = {
    attack = DVS.attack, defense = DVS.defense, speed = DVS.speed,
    special = DVS.special,
  } })
  mon.statExp = statExp
  Mon.refreshStats(mon, DATA)
  return mon
end

-- ---- non-zero stat exp ----------------------------------------------------

local trained = newChikorita({
  hp = 20000, attack = 15000, defense = 9000, speed = 6000, special = 12000,
})
local before = trained.stats
local expected = Mon.stats(DATA.pokemon.BAYLEEF.baseStats, trained.dvs, LEVEL,
  trained.statExp)
check(expected.hp > Mon.stats(DATA.pokemon.BAYLEEF.baseStats, trained.dvs,
  LEVEL, nil).hp, "fixture stat exp raises max HP")

trained.hp = trained.stats.hp - 7

local evolved = Evolution.apply(DATA, trained, ENTRY)
check(evolved ~= nil, "apply builds an evolved record")
eq(evolved.species, "BAYLEEF", "species is the evolution target")
for _, key in ipairs({ "hp", "attack", "defense", "speed", "specialAttack",
  "specialDefense" }) do
  eq(evolved.stats[key], expected[key],
    "evolved " .. key .. " comes from the carried stat exp")
end
eq(evolved.maxHp, expected.hp, "maxHp matches the recomputed stats")
for _, key in ipairs(Mon.STAT_EXP_ORDER) do
  eq(evolved.statExp[key], trained.statExp[key],
    "stat exp " .. key .. " carries across")
end
eq(evolved.level, LEVEL, "level is unchanged")
eq(evolved.experience, trained.experience, "experience is unchanged")

-- engine/pokemon/evolve.asm:274-290
eq(evolved.hp, (before.hp - 7) + (expected.hp - before.hp),
  "current HP gains the max HP delta")
eq(evolved.stats.hp - evolved.hp, 7, "the damage taken is preserved")

-- ---- zero stat exp --------------------------------------------------------

local fresh = newChikorita(Mon.newStatExp())
local freshExpected = Mon.stats(DATA.pokemon.BAYLEEF.baseStats, fresh.dvs,
  LEVEL, fresh.statExp)
local freshMax = fresh.stats.hp
local freshEvolved = Evolution.apply(DATA, fresh, ENTRY)
check(freshEvolved ~= nil, "apply builds a zero stat exp record")
for _, key in ipairs({ "hp", "attack", "defense", "speed", "specialAttack",
  "specialDefense" }) do
  eq(freshEvolved.stats[key], freshExpected[key],
    "zero stat exp " .. key .. " is unchanged")
end
eq(freshEvolved.hp, freshMax + (freshExpected.hp - freshMax),
  "a full HP mon stays full after evolving")
eq(freshEvolved.hp, freshEvolved.stats.hp, "and that is its new max")

S.finish()
