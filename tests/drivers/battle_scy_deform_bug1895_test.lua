-- engine/battle_anims/bg_effects.asm:2638 (#1895)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/battle_scy_deform_bug1895_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/scy-deform love .
-- No POKEPORT_SPEED: the shots land on counted animation frames.
local U = require("tests.drivers.util")

local BattleAnimView = require("src.ui.gen2.BattleAnimView")
local Mon = require("src.battle.gen2.Mon")
local Permissions = require("src.world.gen2.Permissions")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/scy-deform"
  local failures = 0

  local function ok(label, condition, detail)
    if condition then
      print("[scy] ok   " .. label)
    else
      failures = failures + 1
      print("[scy] FAIL " .. label .. " " .. tostring(detail))
    end
  end

  local function shot(path)
    if not U.shot(game, path) then failures = failures + 1 end
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gold world did not boot")

  game.save.party = { Mon.new(game.data, "TOTODILE", 20) }
  game.save.inventory = { POTION = 3 }
  assert(world:setMap("ROUTE_29", 15, 11, "down"), "setMap ROUTE_29 failed")
  U.wait(8)
  if not Permissions.isWalkable(world:playerCollision()) then
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      if world:setMap("ROUTE_29", 15 + step[1], 11 + step[2], "down")
          and Permissions.isWalkable(world:playerCollision()) then
        break
      end
    end
    U.wait(8)
  end

  assert(world:startBattle({ wild = Mon.new(game.data, "GYARADOS", 20) }),
    "startBattle failed")
  local battle
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then battle = top break end
    U.wait(1)
  end
  ok("the battle screen came up", battle ~= nil, battle)
  if not battle then
    print(("[scy] FAIL no battle to shoot (%d)"):format(failures))
    while true do coroutine.yield() end
  end
  for _ = 1, 150 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(2)
  end
  ok("and it reached the FIGHT menu", battle.phase == "menu", battle.phase)
  U.wait(10)
  shot(out .. "/00-battle.png")

  local function sampleWhile(label, frames)
    local scanned, worst = 0, nil
    for _ = 1, frames do
      local anim = battle.anim
      local bg = anim and anim.bg
      if bg and (bg.lcdc or bg.scy ~= 0) then
        local lines = BattleAnimView.scanlines(bg)
        local seen, dup = {}, false
        for _, line in ipairs(lines) do
          if seen[line.dest] then dup = true end
          seen[line.dest] = true
          if line.src < 0 or line.src >= BattleAnimView.SCREEN_H then
            worst = "source row " .. line.src .. " is off the panel"
          end
        end
        if dup then worst = "two source rows landed on one scanline" end
        if bg.lcdc then
          local last = math.min(bg.lyEnd, BattleAnimView.SCREEN_H - 1)
          for row = bg.lyStart + 1, last do
            if not seen[row] and (bg.lyBackup[row - 1] or 0) ~= 0x90 then
              worst = "scanline " .. row .. " was left blank"
            end
          end
        end
        scanned = scanned + 1
      end
      U.wait(1)
    end
    ok(label .. ": " .. scanned .. " deformed frames, each scanline drawn once",
      scanned > 0 and worst == nil, worst or "no deformed frame seen")
  end

  local shots = {
    { "WATER_GUN", "01-water-gun", 10,
      "TOTODILE's WATER GUN: GYARADOS ripples in a gentle vertical wave, a",
      "couple of pixels deep, and the enemy HUD above it breathes with it.",
      "Wrong is the pic sliced into strips with blank rows between them." },
    { "CONFUSION", "02-confusion", 10,
      "CONFUSION: the same window, amplitude 2, so an even softer ripple.",
      "Nothing should tear, and no white gaps should open in the pic." },
    { "PSYCHIC_M", "03-psychic", 10,
      "PSYCHIC is the rSCX effect, the control: the whole screen shears",
      "SIDEWAYS. If this one stopped moving, the SCX path regressed." },
    { "WITHDRAW", "04-withdraw", 20,
      "WITHDRAW parks rows on $90: TOTODILE sinks out of sight row by row.",
      "Wrong is the pic staying put, or the whole panel jumping." },
    { "NIGHT_SHADE", "05-night-shade", 10,
      "NIGHT SHADE: the enemy window starts at scanline 0, so the wave",
      "reaches the very top of the screen.  Wrong is a white line flashing",
      "across the top row every few frames (#1921)." },
    { "SURF", "06-surf", 30,
      "SURF: the wave rolls up the screen and everything it has passed",
      "ripples with it -- pics and HUD boxes sheared, not ruler straight",
      "(#1920)." },
  }

  for _, entry in ipairs(shots) do
    local move, name, delay = entry[1], entry[2], entry[3]
    battle.anim = nil
    local started = battle:animForMove(move, move == "WITHDRAW"
      and "player" or "enemy", 0, 10)
    ok(move .. " has an extracted animation script", started, started)
    if started then
      U.wait(delay)
      for i = 4, #entry do U.log(entry[i]) end
      shot(out .. "/" .. name .. ".png")
      sampleWhile(move, 30)
    end
  end

  battle.anim = nil
  U.wait(6)

  print(failures == 0 and "[scy] PASS battle_scy_deform_bug1895"
    or ("[scy] FAIL battle_scy_deform_bug1895 (%d)"):format(failures))
  U.log("the battle menu is yours; pick a move to watch a full animation.")

  while true do coroutine.yield() end
end
