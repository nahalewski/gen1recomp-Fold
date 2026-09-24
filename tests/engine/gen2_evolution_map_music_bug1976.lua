-- ../pokecrystal/engine/pokemon/evolve.asm:331
-- ../pokecrystal/engine/pokemon/evolve.asm:194
-- ../pokecrystal/engine/items/item_effects.asm:1141

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")
require("src.core.Logger").warn = function() end

local Game2 = require("src.core.Game2")
local Screens = require("src.ui.Screens")

local DATA_POKEMON = {
  SUNKERN = {
    id = "SUNKERN", name = "SUNKERN",
    evolutions = {
      { method = "EVOLVE_ITEM", item = "SUN_STONE", into = "SUNFLORA" },
    },
  },
  SUNFLORA = { id = "SUNFLORA", name = "SUNFLORA", evolutions = {} },
  POLIWAG = {
    id = "POLIWAG", name = "POLIWAG",
    evolutions = { { method = "EVOLVE_LEVEL", level = 5, into = "POLIWHIRL" } },
  },
  POLIWHIRL = { id = "POLIWHIRL", name = "POLIWHIRL", evolutions = {} },
}

local function newGame(species, inventory)
  local seen = { restored = 0 }
  local mon = { species = species, level = 10, moves = {} }
  local game = setmetatable({
    data = {
      pokemon = DATA_POKEMON,
      screens = {
        Gen2PartyMenu = function(_, options)
          seen.party = options
          return {}
        end,
        Gen2EvolutionAnim = function(_, options)
          seen.evolution = options
          return {}
        end,
      },
    },
    save = { party = { mon }, inventory = inventory or {} },
    stack = { pop = function() end, push = function() end },
    world = {
      restoreMapMusic = function() seen.restored = seen.restored + 1 end,
    },
  }, Game2)
  Screens.invalidate()
  return game, mon, seen
end


do
  local game, mon, seen = newGame("SUNKERN", { SUN_STONE = 1 })
  game:usePartyItem("SUN_STONE")
  T.check(seen.party ~= nil, "the SUN STONE opened the party list")
  seen.party.onChoose(1, mon)
  T.check(seen.evolution ~= nil, "the pick pushed the evolution screen")
  T.eq(seen.restored, 0, "with the map theme still down under the screen")
  seen.evolution.onDone({ evolved = true })
  T.eq(seen.restored, 1, "and RestartMapMusic once the screen is gone")
end

do
  local game, mon, seen = newGame("SUNKERN", { SUN_STONE = 1 })
  game:usePartyItem("SUN_STONE")
  seen.party.onChoose(1, mon)
  seen.evolution.onDone({ canceled = true })
  T.eq(seen.restored, 1, "a cancelled stone evolution restarts it as well")
end


do
  local game, mon, seen = newGame("POLIWAG")
  game:afterRareCandy(mon, { learned = {} })
  T.check(seen.evolution ~= nil, "the candy's level-up pushed the screen")
  T.eq(seen.restored, 0, "nothing restarted while it is up")
  seen.evolution.onDone({ evolved = true })
  T.eq(seen.restored, 1, "and the map theme comes back after it")
end

do
  local game, mon, seen = newGame("SUNFLORA")
  local ran = false
  game:afterRareCandy(mon, { learned = {} }, function() ran = true end)
  T.check(ran, "the caller's continuation still runs")
  T.eq(seen.evolution, nil, "with no evolution screen")
  T.eq(seen.restored, 0, "and no restart")
end

T.finish("gen2 evolution map music bug 1976")
