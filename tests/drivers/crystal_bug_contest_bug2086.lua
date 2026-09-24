local U = require("tests.drivers.util")

local BugContest = require("src.core.gen2.BugContest")

local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

local function statMon(species, level, hp)
  return {
    species = species, name = species, level = level,
    hp = hp, maxHp = hp,
    stats = { hp = hp, attack = 30, defense = 30, speed = 30,
              specialAttack = 30, specialDefense = 30 },
    dvs = { attack = 2, defense = 2, speed = 2, special = 2 },
  }
end

return function(game)
  local fails = 0
  local function say(line) print("[2086] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world, save = game.world, game.save
  if not (world and world.map and world.vm and save) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  save.party = { statMon("CYNDAQUIL", 10, 30) }
  BugContest.start(save)
  BugContest.catch(save, statMon("CATERPIE", 9, 20))
  world:warpToMapId("NATIONAL_PARK", 10, 20, "down")
  U.wait(45)
  ok(world.map and world.map.def and world.map.def.id == "NATIONAL_PARK",
    "standing in the park mid-contest")

  U.tap(game, "start")
  U.wait(20)
  local menu = game.stack and game.stack:top()
  ok(menu and menu.items ~= nil, "the START menu opened")
  local hasSave, quitIndex = false, nil
  for index, item in ipairs((menu and menu.items) or {}) do
    if item.value == "quitContest" then quitIndex = index end
    if item.value == "save" then hasSave = true end
  end
  ok(quitIndex ~= nil, "the QUIT row is on the menu")
  ok(not hasSave, "and SAVE is not")
  ok(menu and menu.list and menu.list.y == 4, "the list sits two rows down")
  U.shot(game, SHOT_DIR .. "/crystal_bug2086_startmenu.png")
  say("the shot must show CAUGHT CATERPIE / LEVEL 9 / BALLS: 19 top-left")

  local Screens = require("src.ui.Screens")
  Screens.push(game, "Gen2ContestMenu", {
    save = save, stock = BugContest.caughtMon(save),
    caught = statMon("PINSIR", 13, 40),
    onClose = function() game.stack:pop() end,
  })
  U.wait(10)
  U.shot(game, SHOT_DIR .. "/crystal_bug2086_switch.png")
  say("the shot must show the bold :L levels and ten-tile STOCK/THIS headers")
  U.tap(game, "b")
  U.wait(10)

  ok(game.stack and game.stack:top() == menu,
    "the START menu is on top again")
  if quitIndex and menu and menu.list then menu.list.index = quitIndex end
  U.tap(game, "a")
  U.wait(5)
  ok(menu and menu.phase == "confirmContest", "QUIT asks to end the Contest")
  U.shot(game, SHOT_DIR .. "/crystal_bug2086_confirm.png")
  U.tap(game, "a")
  U.wait(30)
  ok(world.vm:running(), "YES starts BugContestResultsWarpScript")
  for _ = 1, 600 do
    if not world.vm:running() then break end
    U.tap(game, "a")
    U.wait(4)
  end
  ok(not world.vm:running(), "the judging script ran to completion")
  ok(not BugContest.isActive(save), "and the contest is over")
  U.shot(game, SHOT_DIR .. "/crystal_bug2086_judged.png")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
