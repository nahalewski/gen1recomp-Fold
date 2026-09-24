-- pokegold data/moves/effects.asm:1488
-- pokegold engine/battle/move_effects/curse.asm:58
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[curse-dig] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the crystal world did not boot")

  local function missedText(screen)
    for _, event in ipairs(screen.queue or {}) do
      if event.kind == "message" and event.text
          and event.text:find("attack missed", 1, true) then
        return event.text
      end
    end
    return nil
  end

  local function fight(leadSpecies, tag)
    local lead = Mon.new(game.data, leadSpecies, 42)
    assert(lead, "could not build a " .. leadSpecies)
    lead.moves = { { id = "CURSE", pp = 10, maxPp = 10 } }
    game.save.party = { lead }
    game.save.inventory = { POKE_BALL = 5 }

    local wild = Mon.new(game.data, "HITMONTOP", 30)
    assert(wild, "could not build a wild HITMONTOP")
    wild.moves = { { id = "DIG", pp = 10, maxPp = 10 } }
    wild.stats.speed = 1

    assert(world:startBattle({ wild = wild }), "startBattle failed")
    local screen
    for _ = 1, 600 do
      local top = game.stack:top()
      if top and top.battle then screen = top break end
      U.wait(1)
    end
    assert(screen and screen.battle, "battle screen never came up")

    for _ = 1, 900 do
      if screen.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(2)
    end
    ok(screen.phase == "menu", tag .. ": reached the battle menu")

    screen.battle:volatile(screen.battle.enemy).vanished = true
    screen.battle:volatile(screen.battle.enemy).chargeMove = "DIG"

    U.tap(game, "a")
    U.wait(4)
    U.tap(game, "a")
    for _ = 1, 60 do
      if screen.phase ~= "menu" then break end
      U.wait(1)
    end
    for _ = 1, 400 do
      if screen.phase == "menu" or game.stack:top() ~= screen then break end
      U.tap(game, "a")
      U.wait(2)
    end
    return screen
  end

  local function endBattle(screen)
    for _ = 1, 900 do
      if game.stack:top() ~= screen then break end
      screen.battle.enemy.hp = 0
      U.tap(game, "a")
      U.wait(2)
    end
  end

  local screen = fight("SNORLAX", "snorlax")
  local stages = screen.battle.stages.player
  ok(stages.speed == -1, "snorlax: Speed fell against a dug-in target")
  ok(stages.attack == 1, "snorlax: Attack rose")
  ok(stages.defense == 1, "snorlax: Defense rose")
  ok(missedText(screen) == nil,
    "snorlax: no 'attack missed!' line was printed")
  endBattle(screen)

  local screen2 = fight("GASTLY", "gastly")
  local enemyVol = screen2.battle:volatile(screen2.battle.enemy)
  ok(enemyVol.cursed == nil,
    "gastly: the Ghost arm fails against a dug-in target, no curse lands")
  ok(missedText(screen2) == nil,
    "gastly: the failure is not an 'attack missed!' line")
  endBattle(screen2)

  print("[curse-dig] " .. (fails == 0 and "PASS all claims" or
    (fails .. " claims failed")))
  love.event.quit(fails == 0 and 0 or 1)
end
