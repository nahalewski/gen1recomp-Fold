-- ../pokecrystal/constants/pokemon_data_constants.asm:93-99
-- ../pokecrystal/engine/pokemon/caught_data.asm:169-233
-- ../pokecrystal/engine/events/poke_seer.asm:97-136
package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local Mon = require("src.battle.gen2.Mon")
local Protocol = require("src.link.Protocol")
local Wire = require("src.link.Wire")

local ROUTE_29 = 3

local DATA = {
  items = {},
  moves = { TACKLE = { id = "TACKLE", name = "TACKLE", pp = 35 } },
  pokemon = {
    growthRates = {
      GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1, squared = 0,
        linear = 0, constant = 0 },
    },
    HAUNTER = { id = "HAUNTER", name = "HAUNTER", index = 93,
      growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 127,
      types = { "GHOST", "POISON" },
      baseStats = { hp = 45, attack = 50, defense = 45, speed = 95,
        specialAttack = 115, specialDefense = 55 },
      levelMoves = { { level = 1, move = "TACKLE" } } },
  },
}

local function newMon()
  return {
    species = "HAUNTER", name = "HAUNTER", level = 30, experience = 27000,
    hp = 60, maxHp = 60,
    dvs = { attack = 10, defense = 11, speed = 12, special = 13 },
    statExp = {},
    moves = { { id = "TACKLE", pp = 35, maxPp = 35 } },
    happiness = 70, pokerus = 0, ot = "GOLD", otId = 1234,
  }
end

local function overTheWire(mon)
  local msg = Wire.sanitize({ type = "party",
    mons = { Protocol.packMon2(mon) } })
  T.check(msg and msg.mons and msg.mons[1],
    "the offer survives the wire sanitizer")
  return Protocol.unpackMon2(DATA, msg.mons[1])
end

do
  local sent = Mon.setCaughtData(newMon(),
    { timeOfDay = "DAY", level = 12, landmark = ROUTE_29,
      playerGender = "female" })
  local got = overTheWire(sent)
  T.eq(got.caughtTime, 2, "wTimeOfDay DAY crosses the wire")
  T.eq(got.caughtLevel, 12, "so does the caught level")
  T.eq(got.caughtLocation, ROUTE_29, "and the landmark the Seer names")
  T.eq(got.caughtByGender, "girl", "and the gender bit riding byte 1")

  local a0, a1 = Mon.packCaughtData(sent)
  local b0, b1 = Mon.packCaughtData(got)
  T.eq(b0, a0, "byte 0 of MON_CAUGHTDATA is unchanged by the trade")
  T.eq(b1, a1, "and so is byte 1")
end

do
  local gift = Mon.setGiftCaughtData(newMon(), "girl")
  local got = overTheWire(gift)
  T.eq(got.caughtLocation, Mon.LANDMARK_GIFT, "a gift mon keeps LANDMARK_GIFT")
  T.eq(got.caughtLevel, 0, "and the zero caught level SetGiftMonCaughtData wrote")
  T.eq(got.caughtByGender, "girl", "CAUGHT_BY_GIRL still rides bit 7")
end

do
  local legacy = newMon()
  legacy.caughtTime, legacy.caughtLevel = 0, 0
  legacy.caughtLocation, legacy.caughtByGender = 0, "boy"
  local got = overTheWire(legacy)
  local byte0, byte1 = Mon.packCaughtData(got)
  T.eq(byte0, 0, "a zeroed caught word stays zero across a trade")
  T.eq(byte1, 0, "so ReadCaughtData still takes .error, as #1929 fixed it")
end

do
  local old = Protocol.packMon2(newMon())
  old.caughtTime, old.caughtLocation, old.caughtByGender = nil, nil, nil
  old.caughtLevel = nil
  local msg = Wire.sanitize({ type = "party", mons = { old } })
  local got = Protocol.unpackMon2(DATA, msg.mons[1])
  T.eq(got.caughtTime, nil, "a peer that sends no caught data grows no keys")
  T.eq(got.caughtLocation, nil, "none of them")
  T.eq(got.caughtByGender, nil, "at all")
end

do
  local hostile = Protocol.packMon2(newMon())
  hostile.caughtLocation = 999
  hostile.caughtTime = 99
  hostile.caughtLevel = 9999
  hostile.caughtByGender = "SOMETHING ELSE"
  local msg = Wire.sanitize({ type = "party", mons = { hostile } })
  local got = Protocol.unpackMon2(DATA, msg.mons[1])
  T.eq(got.caughtLocation, Mon.CAUGHT_LOCATION_MASK,
    "an out-of-range landmark clamps instead of wrapping into another one")
  T.eq(got.caughtTime, 3, "and the time clamps to NITE")
  T.eq(got.caughtLevel, Mon.MAX_LEVEL, "and the level to MAX_LEVEL")
  T.eq(got.caughtByGender, "boy", "an unknown gender reads as PLAYERGENDER_MALE")
end

T.finish("gen2 link caught data bug 1959")
