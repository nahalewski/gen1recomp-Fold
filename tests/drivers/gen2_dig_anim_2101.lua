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
    if screen.phase ~= "menu" then U.tap(game, "a") end
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
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-dig-anim-2101"
  U.wait(45)
  local world = game.world
  assert(world and world.map, "gen 2 world did not boot")
  local failures = {}
  local function check(ok, what)
    print((ok and "[ok] " or "[FAIL] ") .. what)
    if not ok then failures[#failures + 1] = what end
  end

  local player = Mon.new(game.data, "DUGTRIO", 30)
  giveMoves(player, game, { "DIG" })
  game.save.party = { player }
  local foe = Mon.new(game.data, "SNORLAX", 40)
  giveMoves(foe, game, { "TACKLE" })
  assert(world:startBattle({ wild = foe }), "startBattle failed")
  local screen = battleScreen(game)
  drain(game, screen, 200)

  screen:submit({ kind = "move", move = "DIG" })
  local sawAnim, animEnded = false, false
  for _ = 1, 600 do
    if screen.anim then sawAnim = true
    elseif sawAnim then animEnded = true break end
    U.tap(game, "a")
    U.wait(2)
  end
  check(sawAnim, "the charge animation ran")
  check(animEnded, "and finished")
  U.shot(game, out .. "/01-charge-end.png")
  check(not screen.afterAnimPlayed, "no hit shake rode the charge turn")
  local vol = screen.battle:volatile(screen.battle.player)
  check(vol.vanished == true, "the user is underground")
  local function boxEmpty()
    local vol = screen.battle:volatile(screen.battle.player)
    return screen:picBoxCleared("player") or (vol.vanished and true or false)
  end
  local revealed, revealedInAnim, shotTurn2 = false, false, false
  for _ = 1, 900 do
    if not boxEmpty() then
      revealed = true
      revealedInAnim = screen.anim ~= nil
      break
    end
    if screen.anim and not shotTurn2 then
      shotTurn2 = true
      U.shot(game, out .. "/02-between-turns.png")
    end
    U.tap(game, "a")
    U.wait(2)
  end
  U.shot(game, out .. "/03-turn2-latched.png")
  check(revealedInAnim, "the box stays empty into the attack turn")
  check(revealed, "ENTER_MON brings the user back")
  U.shot(game, out .. "/04-reappear.png")
  drain(game, screen, 600)
  check(screen.picHidden.player == false
      and next(screen.vanishReveal or {}) == nil,
    "no latch left behind")
  U.shot(game, out .. "/05-done.png")

  if #failures > 0 then
    for _, what in ipairs(failures) do print("[FAIL] " .. what) end
    error(#failures .. " checks failed")
  end
  print("[driver] dig anim checks passed")
  print("[driver] shots in " .. out)
end
