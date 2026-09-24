local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

local function giveMoves(mon, game, moves)
  mon.moves = {}
  for i, id in ipairs(moves) do
    local def = assert(game.data.moves[id], id .. " is not in moves.lua")
    mon.moves[i] = { id = id, pp = def.pp, maxPp = def.pp }
  end
  return mon
end

local function battleScreen(game)
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then return top end
    U.wait(1)
  end
  error("battle screen never came up")
end

local function runToMenu(game, screen, frames)
  for _ = 1, (frames or 400) do
    if screen.phase == "menu" and #screen.queue == 0 and not screen.anim then
      return true
    end
    U.tap(game, "a")
    U.wait(3)
  end
  return false
end

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-bodyslam-2102"
  U.wait(45)
  local world = game.world
  assert(world and world.map, "gen 2 world did not boot")
  local failures = {}
  local function check(ok, what)
    print((ok and "[ok] " or "[FAIL] ") .. what)
    if not ok then failures[#failures + 1] = what end
  end

  local player = Mon.new(game.data, "SNORLAX", 50)
  giveMoves(player, game, { "BODY_SLAM", "HEADBUTT", "SPLASH" })
  game.save.party = { player }
  local foe1 = Mon.new(game.data, "HITMONTOP", 42)
  giveMoves(foe1, game, { "SPLASH" })
  local foe2 = Mon.new(game.data, "PIDGEOTTO", 40)
  giveMoves(foe2, game, { "SPLASH" })
  assert(world:startBattle({ trainer = { class = "YOUNGSTER", name = "JOEY",
    party = { foe1, foe2 } } }), "trainer startBattle failed")
  local screen = battleScreen(game)
  assert(runToMenu(game, screen, 400), "never reached the menu")
  U.shot(game, out .. "/00-lead-out.png")

  local sawAnim, sawLift, mixed, shot = false, false, false, 0
  for _ = 1, 4 do
    if screen.battle.enemy ~= foe1 then break end
    if not runToMenu(game, screen, 400) then break end
    foe1.hp = 1
    screen:submit({ kind = "move", move = "BODY_SLAM" })
    for _ = 1, 900 do
      if screen.anim then
        sawAnim = true
        local pic = screen:animPicState("enemy")
        if pic and pic.lifted then
          sawLift = true
          local shown = screen:activeMon("enemy")
          if shown and shown.species ~= foe1.species then mixed = true end
          if shot % 4 == 0 then
            U.shot(game, ("%s/01-bodyslam-%03d.png"):format(out, shot))
          end
          shot = shot + 1
        end
      elseif sawAnim and screen.phase == "menu" and #screen.queue == 0 then
        break
      end
      U.tap(game, "a")
      U.wait(1)
    end
    if screen.battle.enemy ~= foe1 then break end
  end
  check(sawAnim, "Body Slam's animation ran")
  check(sawLift, "and it lifted the target's rows")
  check(screen.battle.enemy ~= foe1, "the 1-HP target fainted to the hit")
  check(not mixed, "the lifted band keeps the fainting mon until the send-out")
  U.wait(30)
  U.shot(game, out .. "/02-after.png")

  if #failures > 0 then
    print(("[driver] FAIL gen2 bodyslam faint 2102 (%d)"):format(#failures))
  else
    print("[driver] PASS gen2 bodyslam faint 2102 in " .. out)
  end
  love.event.quit()
end
