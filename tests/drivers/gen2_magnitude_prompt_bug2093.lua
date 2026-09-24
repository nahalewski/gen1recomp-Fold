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

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-magnitude-prompt"
  U.wait(45)
  local world = game.world
  assert(world and world.map, "gen 2 world did not boot")
  local failures = {}
  local function check(ok, what)
    print((ok and "[ok] " or "[FAIL] ") .. what)
    if not ok then failures[#failures + 1] = what end
  end

  local player = Mon.new(game.data, "DUGTRIO", 30)
  giveMoves(player, game, { "MAGNITUDE" })
  game.save.party = { player }
  local foe = Mon.new(game.data, "RATTATA", 10)
  giveMoves(foe, game, { "TACKLE" })
  assert(world:startBattle({ wild = foe }), "startBattle failed")
  local screen = battleScreen(game)
  drain(game, screen, 200)

  screen:submit({ kind = "move", move = "MAGNITUDE" })
  local line
  for _ = 1, 900 do
    if screen.message and screen.message:match("^Magnitude %d+") then
      line = screen.message
      break
    end
    U.wait(1)
  end
  check(line ~= nil, "the Magnitude number line came up")

  local held = true
  for _ = 1, 150 do
    if screen.anim then
      held = false
      break
    end
    U.wait(1)
  end
  -- pokegold data/text/battle.asm:1017-1021
  check(held, "the number line holds with no quake frames while idle")
  check(screen.message == line, "the box still shows the number line")
  U.shot(game, out .. "/01-magnitude-held.png")

  -- pokegold engine/battle/move_effects/magnitude.asm:20-22
  U.tap(game, "a")
  local quaked = false
  for _ = 1, 120 do
    if screen.anim then
      quaked = true
      break
    end
    U.wait(1)
  end
  local options = game.options
  if options and options.battleScene == false then quaked = true end
  check(quaked, "the quake animation runs only after the press")
  U.shot(game, out .. "/02-magnitude-anim.png")

  drain(game, screen, 600)
  check((foe.hp or 0) < foe.maxHp, "the rolled power landed damage")

  if #failures > 0 then
    for _, what in ipairs(failures) do print("[FAIL] " .. what) end
    error(#failures .. " checks failed")
  end
  print("[driver] magnitude prompt checks passed")
  print("[driver] shots in " .. out)
end
