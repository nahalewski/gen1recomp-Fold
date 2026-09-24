-- #1831: spinner tiles whirled the sprite per DISPLAY frame and flickered
-- the arrows at twice the cart's rate (engine/overworld/spinners.asm:1-22,
-- home/overworld.asm:41-44,268-272).
--   POKEPORT_DRIVER=tests/drivers/spinner_rate_bug1831_test.lua \
--     POKEPORT_IDENTITY=bug1831 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local TileRenderer = require("src.render.TileRenderer")

  local results = {}
  local function check(label, ok)
    results[#results + 1] = (ok and "PASS " or "FAIL ") .. label
  end

  -- data/generated/field.lua ROCKET_HIDEOUT_B2F: the arrow at (12, 9)
  -- slides 10 cells left, the longest straight ride on the floor.
  U.teleport(game, "ROCKET_HIDEOUT_B2F", 13, 9, "left")
  U.wait(10)
  local ow = game.overworld
  check("overworld is up on ROCKET_HIDEOUT_B2F", ow ~= nil and ow.player ~= nil)

  -- one step left onto the arrow starts the forced slide
  U.hold(game, "left", 20)
  local spinning = false
  for _ = 1, 30 do
    if ow.player.spinning then spinning = true break end
    U.wait(1)
  end
  check("stepping on the arrow starts the spin", spinning)

  -- sample per fixed step while the slide runs
  local facings, timers, blurs = {}, {}, {}
  for _ = 1, 200 do
    if not ow.player.spinning then break end
    local _, _, _, facing = ow.player:pose()
    facings[#facings + 1] = facing
    timers[#timers + 1] = ow.player.spinTimer or 0
    blurs[#blurs + 1] = TileRenderer.spinBlurActive()
    U.wait(1)
  end
  check(("the slide gave %d samples (want >= 32)"):format(#facings),
    #facings >= 32)

  -- spinTimer ticks once per fixed step, not per rendered frame
  local ticks = true
  for i = 2, #timers do
    if timers[i] - timers[i - 1] ~= 1 then ticks = false end
  end
  check("spinTimer advances exactly once per fixed step", ticks)

  -- each facing holds for 2 fixed steps: one quarter-turn per OverworldLoop
  -- iteration, two frames each (home/overworld.asm:41-44)
  local runs, run = {}, 1
  for i = 2, #facings do
    if facings[i] == facings[i - 1] then
      run = run + 1
    else
      runs[#runs + 1] = run
      run = 1
    end
  end
  local twos, others = 0, 0
  for i = 2, #runs do -- the first run starts mid-phase, skip it
    if runs[i] == 2 then twos = twos + 1 else others = others + 1 end
  end
  check(("facing holds 2 steps (%d runs of 2, %d other)"):format(twos, others),
    twos >= 8 and others == 0)

  -- arrow blur half-period is 16 frames: one whole 16-frame walked tile
  -- per wSimulatedJoypadStatesIndex parity (spinners.asm:18-22).  The clock
  -- advances on the draw path, so allow one frame of sampling skew; the old
  -- bug read 8 here.
  local span, spans = 1, {}
  for i = 2, #blurs do
    if blurs[i] == blurs[i - 1] then
      span = span + 1
    else
      spans[#spans + 1] = span
      span = 1
    end
  end
  local good, bad = 0, 0
  for i = 2, #spans do -- first span starts mid-phase, skip it
    if spans[i] >= 15 and spans[i] <= 17 then good = good + 1
    else bad = bad + 1 end
  end
  check(("blur toggles every ~16 frames (%d good, %d off)"):format(good, bad),
    good >= 1 and bad == 0)

  for _, line in ipairs(results) do U.log(line) end

  U.log("Right looks like: while the player is swept along the arrow the")
  U.log("sprite makes roughly one full turn per 8 frames, a lazy whirl, and")
  U.log("the arrow tiles swap between blur and static about twice a second.")

  while true do
    coroutine.yield()
  end
end
