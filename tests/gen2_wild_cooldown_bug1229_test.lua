-- The post-battle grace period, which the port never re-armed after an
-- UNSCRIPTED wild battle (#1229): World:tryWildEncounter's own
-- self:startBattle({ wild = wild }) carries no onDone, so no VM resume ever
-- ran the script's own `reloadmapafterbattle` (which is where the cart's
-- SetUpFiveStepWildEncounterCooldown lives, engine/overworld/events.asm:1158-
-- 1162), and the counter sat at zero for the very next step.  What is
-- asserted here is the real World:startBattle -> onDone chain, same as
-- tests/gen2_canlose_test.lua exercises for the loss arm.
--
--   GOLD_CACHE=".../gold" luajit tests/gen2_wild_cooldown_bug1229_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("gen2 wild cooldown")
local check, eq = S.check, S.eq

local World = require("src.world.gen2.World")
local Mon = require("src.battle.gen2.Mon")
local Screens = require("src.ui.Screens")

local cache = os.getenv("GOLD_CACHE")
if not cache then
  local home = os.getenv("HOME") or ""
  cache = home .. "/Library/Application Support/LOVE/gold-dev/gold"
end
local probe = io.open(cache .. "/data/generated/pokemon.lua", "r")
if not probe then
  check(true, "gold cache absent (SKIP)")
  S.finish()
  return
end
probe:close()

local function loadLua(rel) return assert(loadfile(cache .. "/" .. rel))() end
local pokemon = loadLua("data/generated/pokemon.lua")
local moves = loadLua("data/generated/moves.lua")

-- The battle screen as a registry fake, same shape gen2_canlose_test uses:
-- the real World:startBattle pushes it and parks its onDone for the test.
-- Screens.get caches by id process-wide, so a suite dofile'd earlier in
-- tests/run_tests.lua can leave a stale "Gen2BattleState" behind.
Screens.invalidate()
local battleDone
local registry = {
  Gen2BattleState = { new = function(_g, opts)
    battleDone = opts.onDone
    return { screenId = "Gen2BattleState" }
  end },
}

local function makeStack()
  local stack = { items = {} }
  function stack:push(inst) self.items[#self.items + 1] = inst end
  function stack:pop()
    local top = self.items[#self.items]
    self.items[#self.items] = nil
    return top
  end
  return stack
end

local function makeWorld()
  battleDone = nil
  local game = {
    data = { audio = {}, screens = registry, pokemon = pokemon, moves = moves },
    -- No roamer state and no map at all: World:pushBattleTransition needs
    -- self.map to push a wipe and finds none, so pushBattle() runs straight
    -- away, exactly like a headless battle would.  World:restoreMapMusic and
    -- World:battleMusicContext both already guard a nil self.map.
    save = { player = { name = "GOLD", money = 3000 }, party = {} },
    stack = makeStack(),
  }
  local mon = Mon.new(game.data, "CYNDAQUIL", 5)
  check(mon ~= nil, "the cache can build the player's starter")
  game.save.party[1] = mon
  local w = World.new(game)
  return w, game
end

-- ---- the unscripted path itself: World:tryWildEncounter's own call -------
do
  local w, game = makeWorld()
  local wild = Mon.new(game.data, "MAGIKARP", 10)
  check(wild ~= nil, "the cache can build the wild mon")
  -- A grace period already partway spent, so a re-arm is the only way to
  -- land back on 5.
  w.wildCooldown = 2

  check(w:startBattle({ wild = wild }),
    "the unscripted wild path starts a battle")
  check(battleDone ~= nil, "the battle screen is up")

  battleDone("win")
  eq(w.wildCooldown, 5,
    "reloadmapafterbattle's SetUpFiveStepWildEncounterCooldown re-arms " ..
    "the counter (events.asm:1158-1162), even with no script waiting")
end

-- ---- the counter itself, once re-armed: four blocked steps then a roll --
do
  local w = makeWorld()
  w.wildCooldown = 5
  for step = 1, 4 do
    check(w:wildCooldownStep(),
      "step " .. step .. " of the grace period is still blocked")
  end
  check(not w:wildCooldownStep(), "the fifth step may roll")
end

-- ---- a battle NOTHING started re-arms nothing: only startBattle's onDone -
do
  local w = makeWorld()
  w.wildCooldown = 0
  check(w.wildCooldown == 0, "a fresh world never re-arms on its own")
end

S.finish()
