-- pokegold engine/battle_anims/anim_commands.asm:213 (#1896)
--
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/caught_ball_palette_bug1896_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/caught-ball love .
--
-- No POKEPORT_SPEED: the shot has to land on the click frame.
local U = require("tests.drivers.util")
local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/caught-ball"
  local failures = 0

  local function ok(label, condition, detail)
    if condition then
      print("[ball] PASS " .. label)
    else
      failures = failures + 1
      print("[ball] FAIL " .. label .. " " .. tostring(detail))
    end
  end

  local function finish()
    print(failures == 0 and "[ball] PASS caught_ball_palette_bug1896"
      or ("[ball] FAIL caught_ball_palette_bug1896 (%d)"):format(failures))
    while true do coroutine.yield() end
  end

  local function battleScreen()
    local top = game.stack:top()
    return (top and top.battle) and top or nil
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 600 do
      if predicate() then return true end
      U.wait(1)
    end
    return predicate() and true or false
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  local save = game.save
  save.party = { Mon.new(game.data, "CYNDAQUIL", 12) }
  save.inventory = { POTION = 2, POKE_BALL = 10 }

  local wild = Mon.new(game.data, "WOOPER", 5)
  assert(wild, "the cache carries no WOOPER")
  assert(world:startBattle({ wild = wild }), "the wild battle refused to start")

  local screen
  assert(waitFor(function()
    screen = battleScreen()
    return screen ~= nil
  end, 900), "the battle screen never came up")

  for _ = 1, 400 do
    if screen.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(2)
  end
  ok("the battle reached the BattleMenu", screen.phase == "menu", screen.phase)
  if screen.phase ~= "menu" then finish() end

  screen.battle.random = function() return 0 end

  if screen.menuIndex % 2 == 0 then
    U.tap(game, "left")
    U.wait(3)
  end
  if screen.menuIndex <= 2 then
    U.tap(game, "down")
    U.wait(3)
  end
  ok("the cursor sat on the PACK row", screen.menuIndex == 3, screen.menuIndex)
  U.tap(game, "a")
  U.wait(6)

  local pack = game.stack:top()
  ok("the battle PACK opened", pack ~= nil and pack.rows ~= nil, pack)
  if not (pack and pack.rows) then finish() end

  for _ = 1, 4 do
    if pack:pocket().id == "BALL" then break end
    U.tap(game, "right")
    U.wait(4)
  end
  ok("and it crossed to the POKe BALLS pocket", pack:pocket().id == "BALL",
    pack:pocket().id)

  local ballRow
  for index, row in ipairs(pack.rows) do
    if row.id == "POKE_BALL" then ballRow = index end
  end
  ok("the POKE BALL is on the list", ballRow ~= nil, #pack.rows)
  if not ballRow then finish() end

  for _ = 1, 20 do
    if pack.index == ballRow then break end
    U.tap(game, pack.index < ballRow and "down" or "up")
    U.wait(3)
  end
  ok("the cursor reached it", pack.index == ballRow, pack.index)
  -- ItemSubmenu (engine/items/pack.asm:783
  U.tap(game, "a")
  U.wait(4)
  ok("the ball opened ItemSubmenu", pack.submenu ~= nil, pack.submenu)
  U.tap(game, "a")
  U.wait(6)

  ok("the throw was rolled as a catch",
    screen.ballThrow ~= nil and screen.ballThrow.caught == true,
    screen.ballThrow and screen.ballThrow.caught)
  ok("ANIM_THROW_POKE_BALL is running", screen.anim ~= nil, screen.anim)
  if not screen.anim then finish() end

  local clicked = waitFor(function()
    local anim = screen.anim
    return anim ~= nil and anim:done() and anim.keepSprites
  end, 1200)
  ok("the wobble loop ended on .Click and kept its sprites", clicked,
    screen.anim and screen.anim.keepSprites)
  if not clicked then finish() end

  local kept, wrong = 0, nil
  for _, obj in ipairs(screen.anim:oam()) do
    kept = kept + 1
    if obj.palette ~= "PAL_BATTLE_OB_ENEMY" then wrong = obj.palette end
  end
  ok("the ball's OBJs outlived the script", kept > 0, kept)
  ok(("all %d kept OBJs are on the enemy palette slot"):format(kept),
    kept > 0 and wrong == nil, wrong)

  local gotcha = waitFor(function()
    local text = screen.message
    return type(text) == "string" and text:find("Gotcha") ~= nil
  end, 600)
  ok("the Gotcha line is on screen", gotcha, screen.message)

  local stillThere = screen.anim ~= nil and #screen.anim:oam() > 0
  ok("and the ball is still parked under it", stillThere, screen.anim)

  U.log("shot 01: the ball sits on the ground where WOOPER was, with the")
  U.log("Gotcha line under it. Right looks like a ball wearing WOOPER's own")
  U.log("blues, darker and muted; wrong is the bright red and white ball that")
  U.log("was thrown, unchanged from the frame before the click.")
  if not U.shot(game, out .. "/01-gotcha-ball.png") then failures = failures + 1 end

  print(failures == 0 and "[ball] PASS caught_ball_palette_bug1896"
    or ("[ball] FAIL caught_ball_palette_bug1896 (%d)"):format(failures))
  U.log("the battle is left standing on the Gotcha line; press A in the")
  U.log("window to carry on through the catch.")

  while true do coroutine.yield() end
end
