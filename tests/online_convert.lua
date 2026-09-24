--   luajit tests/online_convert.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.harness")
local Convert = require("src.online.Convert")

--------------------------------------------------------------------------
-- Synthetic datasets
--------------------------------------------------------------------------

local gen1Data = {
  pokemon = {
    TESTMON = {
      id = "TESTMON", name = "TESTMON", index = 1, dex = 1,
      types = { "GRASS", "POISON" },
      baseStats = { hp = 45, attack = 49, defense = 49, speed = 45,
                    special = 65 },
      catchRate = 45, growthRate = "MEDIUM_SLOW",
    },
    MAGNETIC = {
      id = "MAGNETIC", name = "MAGNETIC", index = 2, dex = 2,
      types = { "ELECTRIC" },
      baseStats = { hp = 25, attack = 35, defense = 70, speed = 45,
                    special = 95 },
      catchRate = 190, growthRate = "MEDIUM_FAST",
    },
  },
  moves = {
    TACKLE = { id = "TACKLE", name = "TACKLE", pp = 35 },
    VINE_WHIP = { id = "VINE_WHIP", name = "VINE WHIP", pp = 10 },
  },
}

local gen2Data = {
  pokemon = {
    TESTMON = {
      id = "TESTMON", name = "TESTMON",
      types = { "GRASS", "POISON" },
      baseStats = { hp = 45, attack = 49, defense = 49, speed = 45,
                    specialAttack = 65, specialDefense = 65 },
      growthRate = "GROWTH_MEDIUM_SLOW", genderRatio = 0x1f,
    },
    SPLITMON = {
      id = "SPLITMON", name = "SPLITMON",
      types = { "WATER" },
      baseStats = { hp = 60, attack = 60, defense = 60, speed = 60,
                    specialAttack = 90, specialDefense = 40 },
      growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 0x7f,
    },
    MAGNETIC = {
      id = "MAGNETIC", name = "MAGNETIC",
      types = { "ELECTRIC", "STEEL" },
      baseStats = { hp = 25, attack = 35, defense = 70, speed = 45,
                    specialAttack = 95, specialDefense = 55 },
      growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 0xff,
    },
    JOHTOMON = {
      id = "JOHTOMON", name = "JOHTOMON",
      types = { "FIRE" },
      baseStats = { hp = 50, attack = 65, defense = 64, speed = 45,
                    specialAttack = 60, specialDefense = 50 },
      growthRate = "GROWTH_MEDIUM_SLOW", genderRatio = 0x1f,
    },
    growthRates = {
      GROWTH_MEDIUM_SLOW = { numerator = 6, denominator = 5, squared = -15,
                             linear = 100, constant = 140 },
      GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1 },
    },
  },
  moves = {
    TACKLE = { id = "TACKLE", name = "TACKLE", pp = 35 },
    VINE_WHIP = { id = "VINE_WHIP", name = "VINE WHIP", pp = 10 },
    SHADOW_BALL = { id = "SHADOW_BALL", name = "SHADOW BALL", pp = 15 },
  },
  items = {
    LEFTOVERS = { id = "LEFTOVERS", name = "LEFTOVERS" },
    METAL_COAT = { id = "METAL_COAT", name = "METAL COAT" },
    FLOWER_MAIL = { id = "FLOWER_MAIL", name = "FLOWER MAIL" },
  },
}

local DVS = { attack = 15, defense = 14, speed = 13, special = 12 }
local ZERO_EXP = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }

local Stats = require("src.pokemon.Stats")
local Growth = require("src.pokemon.Growth")
local Mon = require("src.battle.gen2.Mon")

local function gen1Mon(species, level, over)
  species = species or "TESTMON"
  level = level or 30
  local def = gen1Data.pokemon[species]
  local dvs = {}
  for k, v in pairs(DVS) do dvs[k] = v end
  dvs.hp = Mon.hpDV(dvs)
  local stats = Stats.calc(def, level, dvs, ZERO_EXP)
  local mon = {
    species = species, level = level,
    exp = Growth.expForLevel(def.growthRate, level),
    dvs = dvs, statExp = { hp = 0, attack = 0, defense = 0, speed = 0,
                           special = 0 },
    stats = stats, hp = stats.hp, catchRate = def.catchRate, status = nil,
    moves = { { id = "TACKLE", pp = 35, ppUps = 0 },
              { id = "VINE_WHIP", pp = 10, ppUps = 0 } },
    nickname = "SPROUT", ot = "RED", otId = 1234, traded = false,
  }
  for k, v in pairs(over or {}) do mon[k] = v end
  return mon
end

local function gen2Mon(species, level, over)
  species = species or "TESTMON"
  level = level or 30
  local def = gen2Data.pokemon[species]
  local dvs = {}
  for k, v in pairs(DVS) do dvs[k] = v end
  dvs.hp = Mon.hpDV(dvs)
  local statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
  local stats = Mon.stats(def.baseStats, dvs, level, statExp)
  local mon = {
    species = species, level = level,
    experience = Mon.experienceForLevel(
      Mon.growthFor(gen2Data, def.growthRate), level),
    dvs = dvs, statExp = statExp, stats = stats,
    hp = stats.hp, maxHp = stats.hp,
    item = nil, status = nil, happiness = 128, pokerus = 0,
    caughtLevel = 5,
    moves = { { id = "TACKLE", pp = 35, maxPp = 35 },
              { id = "VINE_WHIP", pp = 10, maxPp = 10 } },
    nickname = "SPROUT", ot = "GOLD", otName = "GOLD", otId = 4321,
    traded = false, isEgg = false,
  }
  for k, v in pairs(over or {}) do mon[k] = v end
  return mon
end

local function has(lines, needle)
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) then return true end
  end
  return false
end

local function kinds(list)
  local out = {}
  for _, row in ipairs(list) do out[row.kind] = row end
  return out
end

--------------------------------------------------------------------------
-- Gen 1 -> Gen 2
--------------------------------------------------------------------------

do
  local src = gen1Mon("TESTMON", 30)
  local out, report = Convert.toGen2(src, gen1Data, gen2Data)
  T.check(out ~= nil, "1->2 converts a Kanto mon")
  T.eq(out.species, "TESTMON", "1->2 keeps the species")
  T.eq(out.level, 30, "1->2 keeps the level")
  T.eq(out.experience,
    Mon.experienceForLevel(Mon.growthFor(gen2Data, "GROWTH_MEDIUM_SLOW"), 30),
    "1->2 recomputes experience on the Gen 2 curve")
  T.eq(out.dvs.hp, Mon.hpDV(src.dvs), "1->2 derives the HP DV")
  T.eq(out.happiness, 70, "1->2 stamps happiness 70")
  T.eq(out.pokerus, 0, "1->2 zeroes pokerus")
  T.eq(out.item, nil, "1->2 carries no held item")
  T.eq(out.caughtLevel, 30, "1->2 meets at the current level")
  T.eq(out.isEgg, false, "1->2 is never an egg")
  T.eq(out.nickname, "SPROUT", "1->2 keeps the nickname")
  T.eq(out.ot, "RED", "1->2 keeps the OT")
  T.eq(out.otName, "RED", "1->2 mirrors otName")
  T.eq(out.otId, 1234, "1->2 keeps the OT id")
  T.eq(out.maxHp, out.stats.hp, "1->2 sets maxHp from the new stats")
  T.eq(out.hp, out.stats.hp, "1->2 keeps a full-HP mon full")
  T.eq(out.stats.specialAttack,
    Mon.stats(gen2Data.pokemon.TESTMON.baseStats, out.dvs, 30,
      out.statExp).specialAttack,
    "1->2 recomputes stats through Mon.stats")
  T.eq(out.stats.specialAttack, out.stats.specialDefense,
    "1->2 splits one Special into two equal stats when the bases agree")
  T.eq(out.moves[1].maxPp, 35, "1->2 gives moves a maxPp from move data")
  T.eq(#report.lost, 0, "1->2 loses nothing")
  T.check(kinds(report.changed).happiness ~= nil, "1->2 reports the friendship")
end

do
  local src = gen1Mon("TESTMON", 50)
  src.species = "SPLITMON"
  src.stats = Stats.calc(
    { baseStats = { hp = 60, attack = 60, defense = 60, speed = 60,
                    special = 65 } }, 50, src.dvs, ZERO_EXP)
  src.hp = src.stats.hp
  local out, report = Convert.toGen2(src, gen1Data, gen2Data)
  T.check(out.stats.specialAttack ~= out.stats.specialDefense,
    "1->2 splits Special apart when the Gen 2 bases differ")
  local row = kinds(report.changed).special_split
  T.check(row ~= nil, "1->2 reports the Special split")
  T.eq(row.text, ("SPECIAL SPLIT %d -> %d/%d"):format(src.stats.special,
    out.stats.specialAttack, out.stats.specialDefense),
    "1->2 spells the Special split in the game's voice")
end

do
  local src = gen1Mon("TESTMON", 30, { hp = 1 })
  src.status = "PSN"
  local out = Convert.toGen2(src, gen1Data, gen2Data)
  T.eq(out.status, "poison", "1->2 maps PSN to poison")
  T.check(out.hp >= 1 and out.hp <= out.maxHp,
    "1->2 keeps a hurt mon alive after scaling")
end

do
  for from, to in pairs({ SLP = "sleep", PSN = "poison", BRN = "burn",
                          PAR = "paralyze", FRZ = "freeze" }) do
    local out = Convert.toGen2(gen1Mon("TESTMON", 20, { status = from }),
      gen1Data, gen2Data)
    T.eq(out.status, to, "1->2 status " .. from)
  end
end

do
  local src = gen1Mon("TESTMON", 60)
  src.hp = math.floor(src.stats.hp / 2)
  local out = Convert.toGen2(src, gen1Data, gen2Data)
  local want = math.floor(src.hp * out.maxHp / src.stats.hp + 0.5)
  T.eq(out.hp, want, "1->2 scales HP proportionally to the new maximum")
  local fainted = Convert.toGen2(gen1Mon("TESTMON", 60, { hp = 0 }),
    gen1Data, gen2Data)
  T.eq(fainted.hp, 0, "1->2 keeps a fainted mon fainted")
end

do
  local src = gen1Mon("TESTMON", 30)
  src.moves = { { id = "TACKLE", pp = 42, ppUps = 1 } }
  local out = Convert.toGen2(src, gen1Data, gen2Data)
  T.eq(out.moves[1].maxPp, 35 + 7, "1->2 honours PP Ups in maxPp")
  T.eq(out.moves[1].pp, 42, "1->2 keeps current PP under the new cap")
end

do
  local shinyDvs = { attack = 15, defense = 10, speed = 10, special = 10 }
  local src = gen1Mon("TESTMON", 30, { dvs = shinyDvs })
  local out = Convert.toGen2(src, gen1Data, gen2Data)
  T.check(out.shiny == true, "1->2 derives shininess from the DVs")
  T.eq(out.gender, "male", "1->2 derives gender from the Attack DV")
  local plain = Convert.toGen2(gen1Mon("TESTMON", 30,
    { dvs = { attack = 0, defense = 3, speed = 5, special = 7 } }),
    gen1Data, gen2Data)
  T.check(plain.shiny == false, "1->2 leaves an ordinary mon unshiny")
  T.eq(plain.gender, "female", "1->2 reads a low Attack DV as female")
end

--------------------------------------------------------------------------
-- Gen 2 -> Gen 1
--------------------------------------------------------------------------

do
  local src = gen2Mon("TESTMON", 30)
  local out, report = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out ~= nil, "2->1 converts a Kanto mon")
  T.eq(out.level, 30, "2->1 keeps the level")
  T.eq(out.exp, Growth.expForLevel("MEDIUM_SLOW", 30),
    "2->1 recomputes exp on the Gen 1 curve")
  T.eq(out.catchRate, 45,
    "2->1 stamps the Gen 1 species' own catch rate")
  T.eq(out.stats.special,
    Stats.calc(gen1Data.pokemon.TESTMON, 30, out.dvs, out.statExp).special,
    "2->1 folds Special back through the Gen 1 base Special")
  T.eq(out.stats.specialAttack, nil, "2->1 has no specialAttack")
  T.eq(out.nickname, "SPROUT", "2->1 keeps the nickname")
  T.eq(out.ot, "GOLD", "2->1 keeps the OT")
  T.eq(out.otId, 4321, "2->1 keeps the OT id")
  T.eq(out.moves[1].ppUps, 0, "2->1 derives PP Ups from maxPp")
  local lost = kinds(report.lost)
  T.check(lost.happiness ~= nil, "2->1 reports friendship lost")
  T.check(lost.caught_level ~= nil, "2->1 reports the met data lost")
  T.check(lost.item == nil, "2->1 reports no item when none is held")
end

do
  local src = gen2Mon("TESTMON", 40, { item = "LEFTOVERS", pokerus = 0xf1 })
  local out, report = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out ~= nil, "2->1 accepts a mon holding an ordinary item")
  T.eq(out.item, nil, "2->1 drops the held item")
  T.eq(out.catchRate, 45,
    "2->1 does not put the item byte in the catch rate slot")
  local lost = kinds(report.lost)
  T.eq(lost.item.text, "HELD ITEM LOST: LEFTOVERS",
    "2->1 names the item it dropped")
  T.check(lost.pokerus ~= nil, "2->1 reports pokerus lost")
end

do
  for from, to in pairs({ sleep = "SLP", poison = "PSN", toxic = "PSN",
                          burn = "BRN", paralyze = "PAR", freeze = "FRZ" }) do
    local out = Convert.toGen1(gen2Mon("TESTMON", 20, { status = from }),
      gen2Data, gen1Data)
    T.eq(out.status, to, "2->1 status " .. from)
  end
end

do
  local src = gen2Mon("SPLITMON", 50)
  local out, report = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out == nil, "2->1 refuses a species the Gen 1 dataset does not know")
  T.eq(report, "species_too_new", "2->1 gives the species refusal reason")
end

do
  local src = gen2Mon("JOHTOMON", 20)
  local out, reason, info = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out == nil, "2->1 refuses a Johto species")
  T.eq(reason, "species_too_new", "2->1 names the Johto refusal")
  T.eq(info.species, "JOHTOMON", "2->1 says which species was refused")
end

do
  local src = gen2Mon("TESTMON", 30)
  src.moves = { { id = "TACKLE", pp = 35, maxPp = 35 },
                { id = "SHADOW_BALL", pp = 15, maxPp = 15 } }
  local out, reason, info = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out == nil, "2->1 refuses a move past STRUGGLE")
  T.eq(reason, "move_too_new", "2->1 names the move refusal")
  T.eq(info.move, "SHADOW_BALL", "2->1 says which move was refused")
end

do
  local src = gen2Mon("TESTMON", 30, { item = "FLOWER_MAIL" })
  local out, reason = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out == nil, "2->1 refuses a mon holding mail")
  T.eq(reason, "has_mail", "2->1 names the mail refusal")
  local carried = gen2Mon("TESTMON", 30,
    { mail = { message = "HI", author = "GOLD" } })
  local out2, reason2 = Convert.toGen1(carried, gen2Data, gen1Data)
  T.check(out2 == nil, "2->1 refuses a mon carrying a mail record")
  T.eq(reason2, "has_mail", "2->1 names the mail-record refusal")
end

do
  local src = gen2Mon("TESTMON", 30, { isEgg = true })
  local out, reason = Convert.toGen1(src, gen2Data, gen1Data)
  T.check(out == nil, "2->1 refuses an egg")
  T.eq(reason, "is_egg", "2->1 names the egg refusal")
end

do
  local src = gen2Mon("TESTMON", 60)
  src.hp = math.floor(src.maxHp / 2)
  local out = Convert.toGen1(src, gen2Data, gen1Data)
  T.eq(out.hp, math.floor(src.hp * out.stats.hp / src.maxHp + 0.5),
    "2->1 scales HP proportionally")
end

do
  local src = gen2Mon("TESTMON", 30)
  src.moves = { { id = "TACKLE", pp = 40, maxPp = 42 } }
  local out = Convert.toGen1(src, gen2Data, gen1Data)
  T.eq(out.moves[1].ppUps, 1, "2->1 reads one PP Up out of maxPp")
  T.eq(out.moves[1].pp, 40, "2->1 keeps current PP under the Gen 1 cap")
end

--------------------------------------------------------------------------
-- Round trip
--------------------------------------------------------------------------

do
  local src = gen1Mon("TESTMON", 44)
  local mid = Convert.toGen2(src, gen1Data, gen2Data)
  local back = Convert.toGen1(mid, gen2Data, gen1Data)
  T.check(back ~= nil, "round trip comes back")
  T.eq(back.level, src.level, "round trip keeps the level")
  T.eq(back.exp, src.exp, "round trip keeps the exp")
  T.eq(back.catchRate, src.catchRate, "round trip keeps the catch rate")
  for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
    T.eq(back.stats[key], src.stats[key], "round trip keeps stat " .. key)
    T.eq(back.dvs[key], src.dvs[key], "round trip keeps DV " .. key)
  end
  T.eq(back.hp, src.hp, "round trip keeps current HP")
  T.eq(#back.moves, #src.moves, "round trip keeps the move count")
  for i, mv in ipairs(src.moves) do
    T.eq(back.moves[i].id, mv.id, "round trip keeps move " .. i)
    T.eq(back.moves[i].pp, mv.pp, "round trip keeps PP " .. i)
    T.eq(back.moves[i].ppUps, mv.ppUps, "round trip keeps PP Ups " .. i)
  end
  T.eq(back.nickname, src.nickname, "round trip keeps the nickname")
  T.eq(back.ot, src.ot, "round trip keeps the OT")
  T.eq(back.otId, src.otId, "round trip keeps the OT id")
end

--------------------------------------------------------------------------
-- ValidateOTTrademon
--------------------------------------------------------------------------

do
  local ok = Convert.validateArrival(
    { species = "TESTMON", level = 30, types = { "GRASS", "POISON" } },
    gen1Data)
  T.check(ok, "arrival accepts matching types")

  local bad, why = Convert.validateArrival(
    { species = "TESTMON", level = 30, types = { "FIRE" } }, gen1Data)
  T.check(not bad, "arrival refuses a type disagreement")
  T.eq(why, "types", "arrival names the type disagreement")

  local mag = Convert.validateArrival(
    { species = "MAGNEMITE", level = 30, types = { "ELECTRIC" } },
    { pokemon = { MAGNEMITE = { types = { "ELECTRIC", "STEEL" } } } })
  T.check(mag, "arrival carves out MAGNEMITE")
  local magneton = Convert.validateArrival(
    { species = "MAGNETON", level = 30, types = { "ELECTRIC" } },
    { pokemon = { MAGNETON = { types = { "ELECTRIC", "STEEL" } } } })
  T.check(magneton, "arrival carves out MAGNETON")
  local other = Convert.validateArrival(
    { species = "MAGNETIC", level = 30, types = { "ELECTRIC" } }, gen2Data)
  T.check(not other, "arrival refuses another mon claiming the wrong types")

  T.check(not Convert.validateArrival(
    { species = "TESTMON", level = 255 }, gen1Data),
    "arrival refuses a level past 100")
  T.check(not Convert.validateArrival(
    { species = "NOSUCHMON", level = 5 }, gen1Data),
    "arrival refuses an unknown species")
  T.check(Convert.validateArrival({ species = "TESTMON", level = 30 },
    gen1Data), "arrival accepts a record that claims no types")
end

--------------------------------------------------------------------------
-- Previews
--------------------------------------------------------------------------

do
  local lines, ok = Convert.preview(gen2Mon("TESTMON", 30,
    { item = "LEFTOVERS" }), 2, 1, gen2Data, gen1Data)
  T.check(ok, "preview of a legal 2->1 mon is ok")
  T.check(has(lines, "HELD ITEM LOST: LEFTOVERS"),
    "preview names the lost held item")

  local bad, badOk = Convert.preview(gen2Mon("JOHTOMON", 30), 2, 1,
    gen2Data, gen1Data)
  T.check(not badOk, "preview of a Johto mon is not ok")
  T.eq(bad[1], "SPECIES NOT IN GEN 1: JOHTOMON",
    "preview spells the species refusal")

  local moveMon = gen2Mon("TESTMON", 30)
  moveMon.moves = { { id = "SHADOW_BALL", pp = 15, maxPp = 15 } }
  local mv, mvOk = Convert.preview(moveMon, 2, 1, gen2Data, gen1Data)
  T.check(not mvOk, "preview of an illegal move is not ok")
  T.eq(mv[1], "MOVE ILLEGAL IN GEN 1: SHADOW BALL",
    "preview spells the move refusal")

  local mailMon = gen2Mon("TESTMON", 30, { item = "FLOWER_MAIL" })
  local ml, mlOk = Convert.preview(mailMon, 2, 1, gen2Data, gen1Data)
  T.check(not mlOk, "preview of a mail holder is not ok")
  T.eq(ml[1], "MON IS HOLDING MAIL", "preview spells the mail refusal")

  local eggLines = Convert.preview(gen2Mon("TESTMON", 5, { isEgg = true }),
    2, 1, gen2Data, gen1Data)
  T.eq(eggLines[1], "EGGS CANNOT TRAVEL", "preview spells the egg refusal")

  local splitSrc = gen1Mon("TESTMON", 50)
  splitSrc.species = "SPLITMON"
  splitSrc.stats = Stats.calc(
    { baseStats = { hp = 60, attack = 60, defense = 60, speed = 60,
                    special = 65 } }, 50, splitSrc.dvs, ZERO_EXP)
  splitSrc.hp = splitSrc.stats.hp
  local up, upOk = Convert.preview(splitSrc, 1, 2, gen1Data, gen2Data)
  T.check(upOk, "preview of a 1->2 mon is ok")
  T.check(has(up, "SPECIAL SPLIT "), "preview shows the Special split")
end

--------------------------------------------------------------------------
-- Party mapping with mixed legality
--------------------------------------------------------------------------

do
  local illegalMove = gen2Mon("TESTMON", 30)
  illegalMove.moves = { { id = "SHADOW_BALL", pp = 15, maxPp = 15 } }
  local party = {
    gen2Mon("TESTMON", 30),
    gen2Mon("JOHTOMON", 30),
    illegalMove,
    gen2Mon("MAGNETIC", 30, { item = "METAL_COAT" }),
  }
  local converted, results = Convert.partyToGen1(party, gen2Data, gen1Data)
  T.eq(#converted, 2, "party mapping converts only the legal mons")
  T.eq(converted[1].species, "TESTMON", "party mapping keeps order")
  T.eq(converted[2].species, "MAGNETIC", "party mapping keeps the second")
  T.eq(#results, 4, "party mapping reports every slot")
  T.check(results[1].ok, "slot 1 is legal")
  T.check(not results[2].ok, "slot 2 is refused")
  T.eq(results[2].reason, "species_too_new", "slot 2 refusal reason")
  T.eq(results[2].index, 2, "slot 2 carries its index")
  T.eq(results[3].reason, "move_too_new", "slot 3 refusal reason")
  T.eq(results[3].info.move, "SHADOW_BALL", "slot 3 names the move")
  T.check(results[4].ok, "slot 4 is legal with the item dropped")
  T.check(has(results[4].preview, "HELD ITEM LOST: METAL COAT"),
    "slot 4 preview names the dropped METAL COAT")
  T.eq(#Convert.refusals(results), 2, "two refusals collected")

  local up, upResults = Convert.partyToGen2(
    { gen1Mon("TESTMON", 10), gen1Mon("MAGNETIC", 12) }, gen1Data, gen2Data)
  T.eq(#up, 2, "every Kanto mon is legal going up")
  T.check(upResults[1].ok and upResults[2].ok, "no refusals going up")
  T.eq(#Convert.refusals(upResults), 0, "no refusals collected going up")
end

--------------------------------------------------------------------------
-- Real data
--------------------------------------------------------------------------

local function realDataset(version)
  local roots = { ("%s/data/generated/"):format(version), }
  if version == "red" then roots[#roots + 1] = "data/generated/" end
  for _, root in ipairs(roots) do
    local probe = io.open(root .. "pokemon.lua", "r")
    if probe then
      probe:close()
      local function load(name)
        local chunk = loadfile(root .. name .. ".lua")
        if not chunk then return nil end
        local ok, value = pcall(chunk)
        return ok and value or nil
      end
      local data = { pokemon = load("pokemon"), moves = load("moves"),
                     items = load("items") }
      if data.pokemon and data.moves then return data end
    end
  end
  return nil
end

local red = realDataset("red")
local gold = realDataset("gold")

if red and gold then
  local function goldMon(species, level, over)
    local mon = Mon.new(gold, species, level, { dvs = { attack = 15,
      defense = 14, speed = 13, special = 12 } })
    for k, v in pairs(over or {}) do mon[k] = v end
    return mon
  end

  local bulb = goldMon("BULBASAUR", 30)
  local down = Convert.toGen1(bulb, gold, red)
  T.check(down ~= nil, "real BULBASAUR converts down")
  T.eq(down.catchRate, red.pokemon.BULBASAUR.catchRate,
    "real BULBASAUR takes Red's catch rate")

  local magnemite = goldMon("MAGNEMITE", 30)
  local mDown = Convert.toGen1(magnemite, gold, red)
  T.check(mDown ~= nil, "real MAGNEMITE converts down")
  T.check(Convert.validateArrival(
    { species = "MAGNEMITE", level = 30,
      types = red.pokemon.MAGNEMITE.types }, gold),
    "real MAGNEMITE survives arrival validation despite the STEEL type")

  local scyther = goldMon("SCYTHER", 40, { item = "METAL_COAT" })
  local sDown, sReport = Convert.toGen1(scyther, gold, red)
  T.check(sDown ~= nil, "real SCYTHER with METAL COAT converts down")
  T.check(kinds(sReport.lost).item ~= nil, "real METAL COAT is reported lost")

  local totodile = goldMon("TOTODILE", 15)
  local tDown, tReason = Convert.toGen1(totodile, gold, red)
  T.check(tDown == nil and tReason == "species_too_new",
    "real TOTODILE is refused as a Johto species")

  local shadow = goldMon("GASTLY", 40)
  shadow.moves = { { id = "SHADOW_BALL", pp = 15, maxPp = 15 } }
  local shDown, shReason = Convert.toGen1(shadow, gold, red)
  T.check(shDown == nil and shReason == "move_too_new",
    "real SHADOW BALL is refused")

  local mailed = goldMon("BULBASAUR", 30, { item = "FLOWER_MAIL" })
  local mlDown, mlReason = Convert.toGen1(mailed, gold, red)
  T.check(mlDown == nil and mlReason == "has_mail",
    "real FLOWER MAIL is refused")

  local upBulb = Convert.toGen2(down, red, gold)
  T.check(upBulb ~= nil, "real BULBASAUR converts back up")
  T.eq(upBulb.level, bulb.level, "real round trip keeps the level")
else
  T.check(true, "real-data cases skipped (no red and gold caches)")
end

T.finish("online_convert")
