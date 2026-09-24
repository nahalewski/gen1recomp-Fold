--   POKEPORT_GAME=gold POKEPORT_IDENTITY=gold-aug30 \
--     POKEPORT_DRIVER=tests/drivers/gen2_belly_drum_attract_bug2018_2010.lua \
--     POKEPORT_SHOT_DIR=/tmp/gen2-drum-attract love .
-- Block 1 is engine/battle/move_effects/belly_drum.asm: half the max HP for a
-- Block 2 is engine/battle/move_effects/attract.asm plus the SUBSTATUS_IN_LOVE
-- arm of CheckPlayerTurn (engine/battle/effect_commands.asm:279-300) and
-- BreakAttraction (engine/battle/core.asm:4110).
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

local function battleScreen(game)
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then return top end
    U.wait(1)
  end
  error("battle screen never came up")
end

local function drain(game, screen, frames)
  for _ = 1, (frames or 400) do
    if screen.phase == "menu" and #screen.queue == 0 and not screen.anim then
      return true
    end
    U.tap(game, "a")
    U.wait(3)
  end
  return false
end

local function giveMoves(mon, game, moves)
  mon.moves = {}
  for i, id in ipairs(moves) do
    local def = assert(game.data.moves[id], id .. " is not in moves.lua")
    mon.moves[i] = { id = id, pp = def.pp, maxPp = def.pp }
  end
  return mon
end

local function dvsWithAttack(attack)
  local dvs = { attack = attack, defense = 15, speed = 15, special = 15 }
  dvs.hp = Mon.hpDV(dvs)
  return dvs
end

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-drum-attract"
  U.wait(45)
  local world = game.world
  assert(world and world.map, "gen 2 world did not boot")
  local failures = {}
  local function check(ok, what)
    print((ok and "[ok] " or "[FAIL] ") .. what)
    if not ok then failures[#failures + 1] = what end
  end
  local function leaveBattle(game_)
    for _ = 1, 400 do
      if not game_.stack:top() or not game_.stack:top().battle then break end
      U.tap(game_, "a")
      U.wait(3)
    end
    U.wait(60)
  end

  local player = Mon.new(game.data, "SNORLAX", 40, { dvs = dvsWithAttack(15) })
  giveMoves(player, game, { "BELLY_DRUM", "TACKLE" })
  game.save.party = { player }
  local foe = Mon.new(game.data, "RATTATA", 5, { dvs = dvsWithAttack(15) })
  giveMoves(foe, game, { "TACKLE" })
  assert(world:startBattle({ wild = foe }), "startBattle failed")
  local screen = battleScreen(game)
  drain(game, screen, 200)

  local maxHp = player.maxHp
  local cost = math.max(1, math.floor(maxHp / 2))
  screen:submit({ kind = "move", move = "BELLY_DRUM" })
  U.wait(40)
  U.shot(game, out .. "/01-belly-drum.png")
  drain(game, screen, 400)
  print(("[driver] BELLY DRUM: %d/%d HP, attack stage %d")
    :format(player.hp, maxHp, screen.battle.stages.player.attack))
  check(player.hp <= maxHp - cost, "the user paid half its max HP")
  check(screen.battle.stages.player.attack == 6, "and ATTACK is maxed")

  screen:submit({ kind = "move", move = "BELLY_DRUM" })
  U.wait(40)
  U.shot(game, out .. "/02-belly-drum-failed.png")
  local hpBefore = player.hp
  drain(game, screen, 400)
  check(player.hp >= hpBefore, "a second BELLY DRUM under half costs no HP")
  leaveBattle(game)

  local lover = Mon.new(game.data, "SNORLAX", 40, { dvs = dvsWithAttack(15) })
  giveMoves(lover, game, { "ATTRACT", "TACKLE" })
  local bench = Mon.new(game.data, "PIDGEY", 20, { dvs = dvsWithAttack(15) })
  giveMoves(bench, game, { "TACKLE" })
  game.save.party = { lover, bench }
  local miltank = Mon.new(game.data, "MILTANK", 20, { dvs = dvsWithAttack(0) })
  giveMoves(miltank, game, { "TACKLE" })
  assert(world:startBattle({ wild = miltank }), "startBattle failed")
  screen = battleScreen(game)
  drain(game, screen, 200)
  print(("[driver] genders: user %s, foe %s")
    :format(tostring(screen.battle.player.gender),
      tostring(screen.battle.enemy.gender)))
  check(screen.battle.player.gender == "male"
    and screen.battle.enemy.gender == "female",
    "the pair is opposite-sex, so CheckOppositeGender lets ATTRACT through")

  screen:submit({ kind = "move", move = "ATTRACT" })
  U.wait(40)
  U.shot(game, out .. "/03-fell-in-love.png")
  drain(game, screen, 400)
  check(screen.battle:volatile(screen.battle.enemy).attract == true,
    "the foe is infatuated")

  local lines = 0
  for _ = 1, 6 do
    if (screen.battle.enemy.hp or 0) <= 0 then break end
    screen:submit({ kind = "move", move = "TACKLE" })
    U.wait(40)
    if screen.message and screen.message:find("in love", 1, true) then
      lines = lines + 1
      U.shot(game, out .. "/04-in-love-turn.png")
    end
    drain(game, screen, 400)
  end
  print(("[driver] the in-love line came up on %d of the turns watched")
    :format(lines))

  if (screen.battle.enemy.hp or 0) > 0 then
    screen:submit({ kind = "switch", index = 2 })
    drain(game, screen, 400)
    check(screen.battle:volatile(screen.battle.enemy).attract == nil,
      "and the switch broke the attraction on the mon that stayed")
  end
  leaveBattle(game)

  if #failures > 0 then
    for _, what in ipairs(failures) do print("[FAIL] " .. what) end
    error(#failures .. " checks failed")
  end
  print("[driver] all belly drum / attract checks passed")
  print("[driver] shots in " .. out)
end
