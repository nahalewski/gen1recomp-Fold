--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal \
--     POKEPORT_DRIVER=tests/drivers/crystal_battle_text.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-battle-text love .
--           time (PrintLetterDelay, ../pokecrystal/home/print_text.asm:1).  A
--           (../pokecrystal/engine/battle/core.asm:9104-9130).
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-battle-text"
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[battle-text] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the crystal world did not boot")

  local lead = Mon.new(game.data, "CYNDAQUIL", 12)
  assert(lead and #lead.moves > 0, "could not build a CYNDAQUIL")
  game.save.party = { lead }
  game.save.inventory = { POKE_BALL = 5 }

  local function fight(opts)
    local wild = Mon.new(game.data, opts.species, opts.level or 6)
    assert(wild, "could not build a wild " .. tostring(opts.species))
    if opts.status then
      wild.status = opts.status
      wild.statusTurns = 7
    end
    assert(world:startBattle({ wild = wild, battleType = opts.battleType }),
      "startBattle failed")
    local screen
    for _ = 1, 600 do
      local top = game.stack:top()
      if top and top.battle then screen = top break end
      U.wait(1)
    end
    assert(screen and screen.battle, "battle screen never came up")
    return screen, wild
  end

  local function introEvent(screen)
    for _, event in ipairs(screen.queue) do
      if event.intro then return event end
    end
    return nil
  end

  local function endBattle(screen)
    for _ = 1, 900 do
      if screen.phase == "done" or game.stack:top() ~= screen then break end
      screen.battle.enemy.hp = 0
      U.tap(game, "a")
      U.wait(2)
    end
    for _ = 1, 300 do
      if game.stack:top() ~= screen then break end
      U.tap(game, "a")
      U.wait(2)
    end
  end

  local screen = fight({ species = "PIDGEY" })
  local intro = introEvent(screen)
  ok(intro ~= nil and intro.text == "Wild PIDGEY appeared!",
    "the wild arm is WildPokemanAppearedText: "
      .. tostring(intro and intro.text))

  for _ = 1, 400 do
    if screen.message then break end
    U.wait(1)
  end
  local grew, shots = {}, 0
  for i = 1, 3 do
    shots = shots + 1
    grew[i] = screen.typer and screen.typer.shown or -1
    U.shot(game, out .. ("/%02d-typing.png"):format(i))
  end
  print(("[battle-text] glyphs up at the three shots: %d, %d, %d")
    :format(grew[1], grew[2], grew[3]))
  ok(grew[1] >= 0, "the intro line went through the typewriter")
  ok(grew[1] < (screen.typer and screen.typer.total or 0),
    "and was not whole on the first shot")
  ok(grew[3] > grew[1], "the box filled in as the frames went by")

  local before = screen.typer.shown
  U.tap(game, "a")
  U.wait(1)
  ok(screen.typer.shown <= before + 2,
    "a tap mid-print does not dump the rest of the line")
  ok(screen.messageTimer > 0, "and does not page the box away either")

  for _ = 1, 400 do
    if screen.typer:done() then break end
    U.wait(1)
  end
  ok(screen.typer:done(), "the line finishes on its own")
  U.shot(game, out .. "/04-printed.png")
  endBattle(screen)

  local treeScreen, treeMon = fight({ species = "EXEGGCUTE", level = 10,
    battleType = "tree", status = "sleep" })
  local treeIntro = introEvent(treeScreen)
  ok(treeIntro ~= nil
      and treeIntro.text == "EXEGGCUTE fell out of the tree!",
    "PokemonFellFromTreeText: " .. tostring(treeIntro and treeIntro.text))
  ok(treeIntro ~= nil and treeIntro.cry == nil,
    "CheckSleepingTreeMon takes the cry with it")
  ok(treeMon.status == "sleep", "and the mon is still asleep in the battle")
  for _ = 1, 400 do
    if treeScreen.typer and treeScreen.typer:done() then break end
    U.wait(1)
  end
  U.shot(game, out .. "/05-tree.png")
  endBattle(treeScreen)

  local fishScreen = fight({ species = "MAGIKARP", level = 10,
    battleType = "fish" })
  local fishIntro = introEvent(fishScreen)
  ok(fishIntro ~= nil
      and fishIntro.text == "The hooked MAGIKARP attacked!",
    "HookedPokemonAttackedText: " .. tostring(fishIntro and fishIntro.text))
  ok(fishIntro ~= nil and fishIntro.cry ~= nil,
    "and an awake hooked mon still cries")
  for _ = 1, 400 do
    if fishScreen.typer and fishScreen.typer:done() then break end
    U.wait(1)
  end
  U.shot(game, out .. "/06-fish.png")

  print("[battle-text] " .. (fails == 0 and "PASS all claims" or
    (fails .. " claims failed")) .. " -- shots in " .. out)
  love.event.quit(fails == 0 and 0 or 1)
end
