-- ../pokegold/engine/battle/battle_transition.asm:164
-- ../pokecrystal/engine/battle/start_battle.asm:15-35
-- ../pokegold/engine/battle/core.asm:7782-7783
package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("gen2 transition stale levels")
local eq = S.eq

local World = require("src.world.gen2.World")
local Transition = require("src.ui.gen2.BattleTransition")

local function world(version, party)
  local game = {
    data = { audio = { sfxOrder = {} } },
    save = { version = version, party = party or {}, player = {} },
  }
  return World.new(game)
end

local w = world("crystal")
eq(w.staleEnemyMonLevel, 0, "a fresh session has no leftover enemy level")
eq(w.staleBattleMonLevel, 0, "nor a leftover player level")
eq(w:transitionBattleMonLevel(), 0, "an empty crystal party reads 0")
eq(Transition.pick({ environment = "ROUTE",
    playerLevel = w:transitionBattleMonLevel(),
    enemyLevel = w.staleEnemyMonLevel }),
  "spin", "the session's first battle spins outdoors")
eq(Transition.pick({ environment = "CAVE",
    playerLevel = w:transitionBattleMonLevel(),
    enemyLevel = w.staleEnemyMonLevel }),
  "sine", "and sine-waves in a cave")

eq(World.transitionStatusByte(nil), 0, "a healthy mon's status byte is 0")
eq(World.transitionStatusByte("sleep", 3), 3, "sleep reads its turn counter")
eq(World.transitionStatusByte("sleep", nil), 1, "sleep with no counter is 1")
eq(World.transitionStatusByte("poison"), 8, "poison is bit 3")
eq(World.transitionStatusByte("toxic"), 8, "toxic wears the poison bit")
eq(World.transitionStatusByte("burn"), 16, "burn is bit 4")
eq(World.transitionStatusByte("freeze"), 32, "freeze is bit 5")
eq(World.transitionStatusByte("paralyze"), 64, "paralysis is bit 6")

local wc = world("crystal", {
  { hp = 0, status = "paralyze" },
  { hp = 20, status = "poison" },
})
eq(wc:transitionBattleMonLevel(), 8,
  "crystal reads the first ALIVE mon's status byte")
wc.game.save.party[2].status = nil
eq(wc:transitionBattleMonLevel(), 0, "a healthy survivor reads 0")

wc:recordStaleBattleLevels({ enemy = { level = 10 }, player = { level = 40 } })
eq(wc.staleEnemyMonLevel, 10, "the battle banks the enemy's level")
eq(wc.staleBattleMonLevel, 40, "and the player's")
eq(Transition.pick({ environment = "ROUTE",
    playerLevel = wc:transitionBattleMonLevel(),
    enemyLevel = wc.staleEnemyMonLevel }),
  "speckle", "crystal's second battle speckles outdoors")
eq(Transition.pick({ environment = "CAVE",
    playerLevel = wc:transitionBattleMonLevel(),
    enemyLevel = wc.staleEnemyMonLevel }),
  "zoom", "and zooms in a cave")

local wg = world("gold", { { hp = 20, status = "poison" } })
wg:recordStaleBattleLevels({ enemy = { level = 10 }, player = { level = 12 } })
eq(wg:transitionBattleMonLevel(), 12,
  "gold reads the stale player level, not the status byte")
eq(Transition.pick({ environment = "ROUTE",
    playerLevel = wg:transitionBattleMonLevel(),
    enemyLevel = wg.staleEnemyMonLevel }),
  "spin", "so gold's next battle still spins")
eq(Transition.pick({ environment = "ROUTE",
    playerLevel = wg:transitionBattleMonLevel(),
    enemyLevel = 16 }),
  "speckle", "unless the leftovers really were four levels up")

wg:recordStaleBattleLevels({ enemy = { level = 5 } })
eq(wg.staleBattleMonLevel, 12, "a battle with no player mon keeps the old level")
eq(wg.staleEnemyMonLevel, 5, "while the enemy side still updates")

S.finish()
