
local U = require("tests.drivers.util")

local Sound = require("src.core.Sound")
local UnownPuzzle = require("src.ui.gen2.UnownPuzzle")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/unown-jingle"
  local fails = 0
  local function say(line) print("[driver] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "OK   " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  assert(world and world.unownPuzzle, "gold world did not boot")

  -- engine/games/unown_puzzle.asm:286 UnownPuzzle_A
  local solved = nil
  world:unownPuzzle(0, function(done) solved = done end)
  U.wait(30)
  local screen = game.stack:top()
  assert(getmetatable(screen) == UnownPuzzle, "the puzzle screen is not on top")

  for cell = 1, UnownPuzzle.CELLS do
    screen.pieces[cell] = UnownPuzzle.SOLVED[cell]
  end
  local pc = UnownPuzzle.puzcoord
  local home, ring = pc(4, 4), pc(0, 0)
  screen.pieces[home + 1] = 0
  screen.pieces[ring + 1] = 16
  screen.cursor = ring

  local log = {}
  local realPlay = Sound.play
  Sound.play = function(data, name)
    local src = realPlay(data, name)
    log[#log + 1] = name .. (src and "" or " (DROPPED)")
    return src
  end

  U.tap(game, "a")
  U.wait(20)
  screen.cursor = home
  U.tap(game, "a")
  U.wait(45)
  Sound.play = realPlay

  say("sfx: " .. table.concat(log, ", "))
  ok(screen.solved == true, "the board is solved")
  local clicks = 0
  for _, entry in ipairs(log) do
    if entry:match("^Sfx_MegaKick") or entry:match("^Sfx_PlacePuzzlePieceDown")
    then
      clicks = clicks + 1
      ok(not entry:match("DROPPED"), entry .. " started")
    end
  end
  ok(clicks == 2, "both clicks were played")
  local fanfare = nil
  for _, entry in ipairs(log) do
    if entry:match("^Sfx_1stPlace") then fanfare = entry end
  end
  ok(fanfare ~= nil, "Sfx_1stPlace was requested")
  ok(fanfare ~= nil and not fanfare:match("DROPPED"),
    "and the priority gate started it")
  U.shot(game, out .. "/solved.png")

  U.tap(game, "a")
  U.wait(30)
  ok(solved == true, "A after the fanfare closes the screen as solved")

  say(fails == 0 and "PASS" or ("FAIL " .. fails))
  love.event.quit(fails == 0 and 0 or 1)
end
