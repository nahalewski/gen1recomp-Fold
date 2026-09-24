-- pokecrystal engine/battle/move_effects/curse.asm:36
-- pokecrystal data/moves/animations.asm:3232
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-curse-anim-2099"
  os.execute('mkdir -p "' .. out .. '" 2>/dev/null')
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[curse-anim] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the crystal world did not boot")

  local function fight(leadSpecies, tag)
    local lead = Mon.new(game.data, leadSpecies, 42)
    assert(lead, "could not build a " .. leadSpecies)
    lead.moves = { { id = "CURSE", pp = 10, maxPp = 10 } }
    game.save.party = { lead }
    game.save.inventory = { POKE_BALL = 5 }

    local wild = Mon.new(game.data, "HITMONTOP", 30)
    assert(wild, "could not build a wild HITMONTOP")
    wild.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }

    assert(world:startBattle({ wild = wild }), "startBattle failed")
    local screen
    for _ = 1, 600 do
      local top = game.stack:top()
      if top and top.battle then screen = top break end
      U.wait(1)
    end
    assert(screen and screen.battle, "battle screen never came up")
    local seen
    local battle = screen.battle
    local emit = battle.emit
    battle.emit = function(self, event)
      local outEvent = emit(self, event)
      if not seen and event and event.kind == "move"
          and event.move == "CURSE" then
        seen = outEvent
      end
      return outEvent
    end

    for _ = 1, 900 do
      if screen.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(2)
    end
    ok(screen.phase == "menu", tag .. ": reached the battle menu")
    U.tap(game, "a")
    U.wait(4)
    U.tap(game, "a")

    for tick = 1, 150 do
      if tick % 10 == 0 then
        U.shot(game, ("%s/%s-t%03d.png"):format(out, tag, tick))
      end
      U.wait(1)
    end
    battle.emit = emit
    return screen, seen
  end

  local function endBattle(screen)
    for _ = 1, 900 do
      if game.stack:top() ~= screen then break end
      screen.battle.enemy.hp = 0
      U.tap(game, "a")
      U.wait(2)
    end
  end

  local screen, ev = fight("SNORLAX", "snorlax")
  ok(ev ~= nil and ev.move == "CURSE", "SNORLAX queued a CURSE move event")
  ok(ev ~= nil and ev.animParam == 1,
    "non-ghost CURSE carries animParam 1 (speed-line streaks, not the doll)")
  endBattle(screen)

  local screen2, ev2 = fight("GASTLY", "gastly")
  ok(ev2 ~= nil and ev2.move == "CURSE", "GASTLY queued a CURSE move event")
  ok(ev2 ~= nil and ev2.animParam == nil,
    "ghost CURSE keeps animParam nil (the nail-and-doll arm)")
  endBattle(screen2)

  print("[curse-anim] " .. (fails == 0 and "PASS all claims" or
    (fails .. " claims failed")) .. " -- shots in " .. out)
  love.event.quit(fails == 0 and 0 or 1)
end
