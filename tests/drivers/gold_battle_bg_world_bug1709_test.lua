-- maps/Route29.asm:432 (#1709)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gold_battle_bg_world_bug1709_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/gold-battle-bg-world love .
local U = require("tests.drivers.util")

local Chrome = require("src.ui.gen2.Chrome")
local Mon = require("src.battle.gen2.Mon")
local OptionsMenu = require("src.ui.gen2.OptionsMenu")
local Permissions = require("src.world.gen2.Permissions")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-battle-bg-world"
  local failures = 0

  local function ok(label, condition, detail)
    if condition then
      print("[bgworld] ok   " .. label)
    else
      failures = failures + 1
      print("[bgworld] FAIL " .. label .. " " .. tostring(detail))
    end
  end

  local function tap(button, frames)
    game.input.pressQueue[#game.input.pressQueue + 1] = button
    game.input.state[button] = true
    U.wait(2)
    game.input.state[button] = false
    U.wait(frames or 6)
  end

  local function shot(path)
    if not U.shot(game, path) then failures = failures + 1 end
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  local bgRow
  for _, row in ipairs(OptionsMenu.ROWS) do
    if row.label == "BATTLE BG" then bgRow = row end
  end
  ok("OPTION carries a BATTLE BG row", bgRow ~= nil, bgRow)
  if bgRow then
    ok("and WORLD is on its ladder", bgRow.display.world == "WORLD",
      bgRow.display.world)
  end

  local battleModule = require("src.ui.gen2.BattleState")
  ok("the battle screen publishes the veil's dim",
    battleModule.BG_WORLD_DIM ~= nil, battleModule.BG_WORLD_DIM)
  ok("and stays opaque: Game2 draws the map, not StateStack",
    battleModule.isOpaque == true, battleModule.isOpaque)

  if love.window and love.window.setMode then
    love.window.setMode(1280, 840, { resizable = true })
    U.wait(6)
  end
  local winW, winH = love.graphics.getDimensions()
  local scale = Chrome.fitScale(winW, winH)
  local ox, oy = Chrome.fitOrigin(winW, winH, scale)
  ok(("the window leaves a void to look at (%dx%d, panel at %d,%d x%d)")
    :format(winW, winH, ox, oy, scale), ox > 8 and oy > 8, ox .. "," .. oy)

  local player = Mon.new(game.data, "CYNDAQUIL", 12)
  local wild = Mon.new(game.data, "PIDGEY", 4)
  ok("CYNDAQUIL builds from the extracted tables",
    player ~= nil and #player.moves > 0, player and #player.moves)
  game.save.party = { player }
  game.save.inventory = { POKE_BALL = 5, POTION = 3 }

  assert(world:setMap("ROUTE_29", 15, 11, "down"), "setMap ROUTE_29 failed")
  U.wait(8)
  if not Permissions.isWalkable(world:playerCollision()) then
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
        { 2, 0 }, { -2, 0 } }) do
      if world:setMap("ROUTE_29", 15 + step[1], 11 + step[2], "down")
          and Permissions.isWalkable(world:playerCollision()) then
        break
      end
    end
    U.wait(8)
  end
  ok("the player is standing on floor, not in a wall",
    Permissions.isWalkable(world:playerCollision()),
    tostring(world:playerCollision()))

  print(failures == 0
    and "[bgworld] preflight PASS -- the shots below are worth looking at"
    or ("[bgworld] preflight FAIL (%d) -- fix these before judging a pixel")
      :format(failures))

  game.options.battleBg = "world"
  U.wait(6)
  U.log("00: Route 29 with BATTLE BG on WORLD. the overworld is not a battle,")
  U.log("so nothing here may be dimmed -- the map and its surround look")
  U.log("exactly as they do on WHITE.")
  shot(out .. "/00-route29.png")

  assert(world:startBattle({ wild = wild }), "startBattle failed")
  local battle
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then battle = top break end
    U.wait(1)
  end
  ok("the battle screen came up after the transition", battle ~= nil, battle)
  if not battle then
    print(("[bgworld] FAIL no battle to shoot (%d)"):format(failures))
    while true do coroutine.yield() end
  end
  for _ = 1, 150 do
    if battle.phase == "menu" then break end
    tap("a", 2)
  end
  ok("the battle reached the FIGHT menu", battle.phase == "menu", battle.phase)
  ok("and it reports the world surround", battle:bgMode() == "world",
    battle:bgMode())
  U.wait(10)

  U.log("01: the battle on WORLD. Route 29 fills the window on all four sides")
  U.log("of the GB screen, darkened about halfway; the battle's own field, HUD")
  U.log("and message box stay paper white with a clean edge. map pixels")
  U.log("creeping over the panel edge, or a dimmed row of the HUD, is the band")
  U.log("maths being wrong.")
  shot(out .. "/01-battle-world.png")

  local function pointAt(index)
    tap("left", 3)
    tap("up", 3)
    if index == 2 or index == 4 then tap("right", 3) end
    if index == 3 or index == 4 then tap("down", 3) end
    return battle.menuIndex == index
  end

  ok("the cursor is on PKMN", pointAt(2), battle.menuIndex)
  tap("a", 12)
  ok("the party list opened over the battle", battle.phase == "submenu",
    battle.phase)
  U.log("02: the party list over the same battle. the map must still be there")
  U.log("behind it, at the same dim. white flooding back the instant the list")
  U.log("goes up means the paper fill is not being suppressed.")
  shot(out .. "/02-party-over-world.png")
  tap("b", 12)

  ok("the cursor is on PACK", pointAt(3), battle.menuIndex)
  tap("a", 14)
  U.log("03: the PACK over the battle, same rule -- still the dimmed map.")
  shot(out .. "/03-pack-over-world.png")
  tap("b", 12)
  for _ = 1, 20 do
    if battle.phase == "menu" then break end
    tap("b", 4)
  end

  game.options.battleFit = "fill"
  U.wait(8)
  U.log("04: WORLD with BATTLE SIZE on FILL. the panel is taller, so the map")
  U.log("shows only down the left and right sides -- and still stops dead at")
  U.log("the panel edge.")
  shot(out .. "/04-battle-world-fill.png")
  game.options.battleFit = "fixed"
  U.wait(8)

  game.options.battleBg = "black"
  U.wait(6)
  ok("BLACK still reads black", battle:bgMode() == "black", battle:bgMode())
  U.log("05: the same battle on BLACK -- solid bars, no map anywhere.")
  shot(out .. "/05-battle-black.png")

  game.options.battleBg = "white"
  U.wait(6)
  ok("and WHITE still reads white", battle:bgMode() == "white", battle:bgMode())
  U.log("06: the same battle on WHITE -- paper white to the window edge, no")
  U.log("seam where the panel ends.")
  shot(out .. "/06-battle-white.png")

  game.options.battleBg = "world"
  U.wait(6)

  print(failures == 0 and "[bgworld] PASS gold_battle_bg_world_bug1709"
    or ("[bgworld] FAIL gold_battle_bg_world_bug1709 (%d)"):format(failures))
  U.log("the battle is still up on WORLD and the controls are yours.")

  while true do coroutine.yield() end
end
