-- DoBattleTransition, frame by frame.
--
--   POKEPORT_GAME=gold POKEPORT_DRIVER=tests/drivers/gold_transition_shots.lua love .
--
-- Shoots each of the four outros (spin / speckle / sine / zoom) plus the Poke
-- Ball overlay a trainer battle stamps over the map first.  POKEPORT_SHOT_INTERVAL
-- picks the sampling; the default walks the whole thing at 6 frames.
--
local U = require("tests.drivers.util")

local Transition = require("src.ui.gen2.BattleTransition")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-transition"
  local interval = tonumber(os.getenv("POKEPORT_SHOT_INTERVAL") or "") or 6

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")
  world:setMap("NEW_BARK_TOWN", 5, 8, "down")
  U.wait(20)

  local function run(style, trainer, every)
    local tag = style .. (trainer and "-trainer" or "-wild")
    local done = false
    game.stack:push(Transition.new(game, {
      world = world,
      style = style,
      trainer = trainer,
      onDone = function() done = true end,
    }))
    -- Shoot the flash sparsely and the outro (the part with the shape in it)
    -- at every interval, so a nine-shot run is not all palette pulses.
    local state = game.stack:top()
    local shots, outroShots = 0, 0
    for frame = 1, 600 do
      local outro = state.phase == "outro"
      local want = outro and (outroShots % interval == 0)
        or (not outro and (every or frame % 24 == 1))
      if want then
        shots = shots + 1
        if every and not outro then
          U.shot(game, ("%s/%s/%s-%03d.png")
            :format(out, tag, state.phase, state.frame))
        else
          U.shot(game, ("%s/%s/%s-%02d.png")
            :format(out, tag, outro and "outro" or "flash", shots))
        end
      end
      if outro then outroShots = outroShots + 1 end
      if done then break end
      U.wait(1)
    end
    print(("[driver] %-16s %d shots, finished=%s")
      :format(tag, shots, tostring(done)))
    -- The state pops itself; if it did not, take it off so the next run starts
    -- from a clean stack.
    if not done then game.stack:pop() end
    U.wait(5)
  end

  run("spin", true, true)
  run("spin", false)
  run("speckle", true)
  run("sine", true)
  run("zoom", true)

  print("[driver] shots in " .. out)
  love.event.quit()
end
