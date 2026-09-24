-- maps/Route29.asm:432 (#1709)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gold_battle_size_bug1709_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/gold-battle-size love .
-- No POKEPORT_SPEED: the shots land on counted frames.
local U = require("tests.drivers.util")

local Chrome = require("src.ui.gen2.Chrome")
local Mon = require("src.battle.gen2.Mon")
local OptionsMenu = require("src.ui.gen2.OptionsMenu")
local Permissions = require("src.world.gen2.Permissions")
local Save = require("src.core.gen2.Save")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-battle-size"
  local failures = 0

  local function ok(label, condition, detail)
    if condition then
      print("[battlesize] ok   " .. label)
    else
      failures = failures + 1
      print("[battlesize] FAIL " .. label .. " " .. tostring(detail))
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

  local BattleState = require("src.ui.gen2.BattleState")

  ok("battleFit has a default in the Gold options table",
    Save.DEFAULT_OPTIONS.battleFit == "fixed", Save.DEFAULT_OPTIONS.battleFit)

  local sizeRow
  for i, row in ipairs(OptionsMenu.ROWS) do
    if row.label == "BATTLE SIZE" then sizeRow = i end
  end
  ok("OPTION carries a BATTLE SIZE row", sizeRow ~= nil, sizeRow)
  if sizeRow then
    ok("and BATTLE BG follows it",
      OptionsMenu.ROWS[sizeRow + 1]
        and OptionsMenu.ROWS[sizeRow + 1].key == "battleBg", sizeRow)
  end
  ok("the battle screen reads the option rather than answering true",
    BattleState.wantsFillScale({ game = { options = { battleFit = "fixed" } } })
      == false, "stub")

  if love.window and love.window.setMode then
    love.window.setMode(1280, 840, { resizable = true })
    U.wait(6)
  end
  local winW, winH = love.graphics.getDimensions()
  local fixed = Chrome.fitScale(winW, winH)
  local fill = BattleState.fillScale(winW, winH)
  ok(("the window makes FILL fractional (%dx%d, fixed x%d, fill x%.3f)")
    :format(winW, winH, fixed, fill), fill > fixed and fill % 1 > 0.01,
    fixed .. " / " .. fill)

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
    and "[battlesize] preflight PASS -- the shots below are worth looking at"
    or ("[battlesize] preflight FAIL (%d) -- fix these before judging a pixel")
      :format(failures))

  game.options.battleFit = "fixed"
  game.options.battleBg = "white"

  assert(world:startBattle({ wild = wild }), "startBattle failed")
  local battle
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then battle = top break end
    U.wait(1)
  end
  ok("the battle screen came up after the transition", battle ~= nil, battle)
  if not battle then
    print(("[battlesize] FAIL no battle to shoot (%d)"):format(failures))
    while true do coroutine.yield() end
  end
  for _ = 1, 150 do
    if battle.phase == "menu" then break end
    tap("a", 2)
  end
  ok("the battle reached the FIGHT menu", battle.phase == "menu", battle.phase)
  ok("and it reports FIXED", battle:wantsFillScale() == false,
    battle:wantsFillScale())
  U.wait(10)

  U.log("01: the battle on FIXED. this is the reference shot: every box border")
  U.log("is one even line, the HUD rules are even, and the glyphs are whole.")
  shot(out .. "/01-battle-fixed.png")

  game.options.battleFit = "fill"
  U.wait(8)
  ok("the battle now reports FILL", battle:wantsFillScale() == true,
    battle:wantsFillScale())
  U.log("02: the same battle on FILL. the panel is bigger and reaches the top")
  U.log("and bottom edges. what to judge: the message box border, the HUD")
  U.log("rules under both names, and the level and HP digits. some stepping is")
  U.log("inherent at a fractional scale; a border that breaks into visible")
  U.log("stairs, or a glyph missing a pixel row, is too much to ship.")
  shot(out .. "/02-battle-fill.png")

  local function pointAt(index)
    tap("left", 3)
    tap("up", 3)
    if index == 2 or index == 4 then tap("right", 3) end
    if index == 3 or index == 4 then tap("down", 3) end
    return battle.menuIndex == index
  end

  ok("the cursor is on FIGHT", pointAt(1), battle.menuIndex)
  tap("a", 12)
  U.log("03: the move list on FILL. the move names, TYPE/ and the PP figures")
  U.log("are the smallest text in the game -- this is where a lost pixel row")
  U.log("shows first.")
  shot(out .. "/03-moves-fill.png")
  tap("b", 12)

  ok("the cursor is on PKMN", pointAt(2), battle.menuIndex)
  tap("a", 12)
  U.log("04: the party list opened over the FILL battle. PARTY paints its own")
  U.log("surround at the whole-pixel fit, so the panel steps back down to the")
  U.log("FIXED size here and the void around it must be clean -- no paper ring")
  U.log("left where the bigger battle panel was. carrying FILL into PARTY and")
  U.log("PACK is still open work.")
  shot(out .. "/04-party-over-fill.png")
  tap("b", 12)
  for _ = 1, 20 do
    if battle.phase == "menu" then break end
    tap("b", 4)
  end

  game.options.battleBg = "black"
  U.wait(8)
  U.log("05: FILL with BATTLE BG on BLACK. the black hugs the bigger panel:")
  U.log("no white strip left on an edge, and no black creeping over the HUD.")
  shot(out .. "/05-fill-black-bg.png")
  game.options.battleBg = "white"

  for _, mode in ipairs({ "upper", "top" }) do
    game.options.screenPos = mode
    game:applyOptions()
    U.wait(8)
    U.log(("06-%s: SCREEN POS %s at FILL. the panel moves as a whole; it must")
      :format(mode, mode))
    U.log("not shear or leave a sliver at the edge it was lifted from.")
    shot(out .. ("/06-screenpos-%s-fill.png"):format(mode))
  end
  game.options.screenPos = "center"
  game:applyOptions()
  U.wait(8)

  game.options.battleFit = "fixed"
  U.wait(8)
  ok("and back to FIXED", battle:wantsFillScale() == false,
    battle:wantsFillScale())
  U.log("07: back on FIXED, for the same comparison as 01. nothing about the")
  U.log("panel should have changed while FILL was on and off again.")
  shot(out .. "/07-battle-fixed-again.png")

  print(failures == 0 and "[battlesize] PASS gold_battle_size_bug1709"
    or ("[battlesize] FAIL gold_battle_size_bug1709 (%d)"):format(failures))
  U.log("the battle is still up on FIXED and the controls are yours. OPTION ->")
  U.log("BATTLE SIZE is the row to flip by hand if you want another look.")

  while true do coroutine.yield() end
end
