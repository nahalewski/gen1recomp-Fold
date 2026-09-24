-- The walking-NPC animation cadence, which the port ran at half the cart's
-- rate (#1303).  UpdateSpriteInWalkingAnimation advances one animation frame
-- every 4 fixed steps regardless of how long the whole cell takes
-- (engine/overworld/movement.asm:301), so a 32-frame NPC cell must show the
-- same two-pulse cadence Player:pose already shows across its own 16.
--   luajit tests/engine/npc_walk_cadence_bug1303.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local NPC = require("src.world.NPC")

local DATA = {
  sprites = {
    SPRITE_TEST_NPC = { image = "fixture_npc.png", frames = 6, walker = true },
  },
}

local function newNpc()
  return NPC.new(DATA, "TEST_MAP", {
    index = 1, x = 5, y = 5, sprite = "SPRITE_TEST_NPC", range = "ANY_DIR",
    movement = "STAY",
  })
end

-- ---- the pure cadence: two walk pulses across one 32-frame NPC step ------
do
  local npc = newNpc()
  npc.moving = true
  local phases = {}
  for clock = 0, 31 do
    npc.animClock = clock
    phases[clock] = npc:walkPhase()
  end
  local risingEdges = 0
  for clock = 1, 31 do
    if phases[clock] == 1 and phases[clock - 1] == 0 then
      risingEdges = risingEdges + 1
    end
  end
  eq(risingEdges, 2, "a 32-frame NPC cell shows two walk pulses, not one")
  eq(phases[0], 0, "frame 0 stands")
  eq(phases[4], 1, "frame 4 opens the first walk pulse")
  eq(phases[11], 1, "frame 11 is still the first pulse")
  eq(phases[12], 0, "frame 12 closes it back to standing")
  eq(phases[20], 1, "frame 20 opens the second walk pulse")
  eq(phases[27], 1, "frame 27 is still the second pulse")
  eq(phases[28], 0, "frame 28 closes the cycle back to standing")
end

-- ---- the flip half-cycle: one flip per 16-frame half, not per whole cell -
do
  local npc = newNpc()
  npc.moving = true
  npc.animClock = 0
  local _, _, _, _, _, flip0 = npc:pose()
  npc.animClock = 15
  local _, _, _, _, _, flip15 = npc:pose()
  npc.animClock = 16
  local _, _, _, _, _, flip16 = npc:pose()
  npc.animClock = 31
  local _, _, _, _, _, flip31 = npc:pose()
  check(not flip0, "the first half of the cell is unflipped")
  check(not flip15, "still unflipped just before frame 16")
  check(flip16, "frame 16 flips, matching Player:pose's own half-cycle")
  check(flip31, "and stays flipped through the second half")
end

-- ---- standing keeps the externally-written flip (Pikachu idle contract) --
do
  local npc = newNpc()
  npc.moving = false
  npc.stepFlip = true
  local _, _, _, _, phase, flip = npc:pose()
  eq(phase, 0, "a standing NPC has no walk phase")
  check(flip, "and pose() reads stepFlip back exactly, not the moving formula")
end

-- ---- the wiring: NPC:update advances animClock alongside progress -------
do
  local npc = newNpc()
  npc.facing = "down"
  npc.moving = true
  npc.targetX, npc.targetY = npc.cellX, npc.cellY + 1
  local map = {}
  for i = 1, 16 do
    npc:update(map, {})
    eq(npc.animClock, i, "animClock ticks once per update, step " .. i)
  end
  check(npc.moving, "still mid-cell at 16 of the 32 ticks")
end

T.finish("npc walk cadence bug1303")
