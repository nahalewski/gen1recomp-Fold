-- engine/items/item_effects.asm:779-793 (#2072)
-- pokeyellow engine/items/item_effects.asm:810-830
--   luajit tests/engine/evo_stone_sfx_bug2072.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local heard = {}
package.loaded["src.core.Sound"] = {
  play = function(_, name) heard[#heard + 1] = name end,
  playCry = function(_, species) heard[#heard + 1] = "cry:" .. tostring(species) end,
}

local Fixtures = require("tests.modkit.fixtures")
local GameVersion = require("src.core.GameVersion")
local ItemEffects = require("src.inventory.ItemEffects")
local Pokemon = require("src.pokemon.Pokemon")

local Data = Fixtures.fresh()
Data.items.THUNDER_STONE = {
  id = "THUNDER_STONE", index = 33, name = "THUNDERSTONE", price = 2100,
  tossable = true,
}
Data.items.FIRE_STONE = {
  id = "FIRE_STONE", index = 32, name = "FIRESTONE", price = 2100,
  tossable = true,
}
Data.pokemon.FIXMON_A.evolutions = {
  { method = "ITEM", item = "THUNDER_STONE", species = "FIXMON_B" },
}

local function freshSave(species)
  local mon = Pokemon.new(Data, species or "FIXMON_A", 20)
  mon.ot = "RED"
  mon.otId = 1
  return {
    party = { mon },
    player = { name = "RED", id = 1 },
    inventory = { THUNDER_STONE = 1, FIRE_STONE = 1 },
    options = {}, flags = {}, money = 0,
  }, mon
end

local function use(itemId, save, target)
  heard = {}
  return ItemEffects.use(Data, save, itemId, target)
end

local original = GameVersion.current

GameVersion.set("red")

do
  local save, mon = freshSave()
  local result, _, extra = use("THUNDER_STONE", save, mon)
  eq(result, "consumed", "the matching stone is used up")
  eq(extra and extra.evolveTo, "FIXMON_B", "and evolves the mon")
  eq(heard[1], "Heal_Ailment",
     "SFX_HEAL_AILMENT plays before TryEvolvingMon "
     .. "(engine/items/item_effects.asm:779) (#2072)")
end

do
  local save, mon = freshSave()
  local result = use("FIRE_STONE", save, mon)
  eq(result, "failed", "a stone with no matching evolution reaches .noEffect")
  eq(heard[1], "Heal_Ailment",
     "and Red/Blue still played the jingle first, because item_effects.asm "
     .. "sounds it at :779 before the :785 branch to .noEffect (#2072)")
end

do
  local save = freshSave()
  local result = use("THUNDER_STONE", save, nil)
  eq(result, "failed", "cancelling the party menu does not use the stone")
  eq(#heard, 0,
     "and .canceledItemUse is reached before the jingle "
     .. "(engine/items/item_effects.asm:774)")
end

GameVersion.set("yellow")

do
  local save, mon = freshSave()
  local result, _, extra = use("THUNDER_STONE", save, mon)
  eq(result, "consumed", "Yellow evolves on the matching stone too")
  eq(extra and extra.evolveTo, "FIXMON_B", "into the same species")
  eq(heard[1], "Heal_Ailment",
     "and .notPlayerPikachu plays SFX_HEAL_AILMENT "
     .. "(pokeyellow engine/items/item_effects.asm:828)")
end

do
  local save, mon = freshSave()
  local result = use("FIRE_STONE", save, mon)
  eq(result, "failed", "Yellow bails on a stone with no matching evolution")
  eq(#heard, 0,
     "silently: Func_d85d runs before the jingle, so `jr nc, .noEffect` "
     .. "skips it (pokeyellow engine/items/item_effects.asm:810-811)")
end

do
  Data.pokemon.PIKACHU = Data.pokemon.PIKACHU or Data.pokemon.FIXMON_A
  local save, mon = freshSave("PIKACHU")
  mon.species = "PIKACHU"
  local result = use("THUNDER_STONE", save, mon)
  eq(result, "failed", "the Yellow starter Pikachu refuses the stone")
  eq(heard[1], "cry:PIKACHU",
     "with PikachuCry28 and no jingle "
     .. "(pokeyellow engine/items/item_effects.asm:814-820)")
  check(heard[2] == nil, "and nothing after it")
end

GameVersion.set(original)

T.finish("evo stone sfx (#2072)")
