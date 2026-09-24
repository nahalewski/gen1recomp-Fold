-- Eye check on NIGHT_SHADE's wavy screen (#1848).  AnimationWavyScreen's
-- `ld c, $ff` counts outer passes and the inner loop exits twice a frame
-- (pokered engine/battle/animations.asm:1884-1903, 1916-1927), so the
-- wobble runs ~128 frames with a 16-line wave, not 255 with a 32-line one.
--   POKEPORT_DRIVER=tests/drivers/nightshade_anim_bug1848_test.lua POKEPORT_IDENTITY=bug1848 POKEPORT_TOUCH=0 love .
-- No POKEPORT_SPEED: fast-forward scales the logic clock only.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local AnimPlayer = require("src.battle.AnimPlayer")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  -- data/generated/maps.lua ROUTE_1: open path south of the first grass
  -- patch; pokered data/maps/objects/Route1.asm parks its youngsters at
  -- (5, 24) and (15, 13), so nobody is standing here or watching.
  local MAP = "ROUTE_1"
  local STAND = { x = 5, y = 5, facing = "down" }

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local opts = game.save.options or {}
  local sfxVol = opts.sfxVol or 7
  if sfxVol == 0 then
    U.log("FAIL sfx volume is 0, so the flash that opens the animation is")
    U.log("     silent. Set SFX to 7 in OPTION first.")
  end
  check(("sfx volume %d"):format(sfxVol), sfxVol > 0)
  if opts.animations == false then
    U.log("FAIL OPTION has animations off, which skips every queued anim row.")
  end
  check("battle animations are on", opts.animations ~= false)

  local anims = (game.data.battle_anims or {}).moveAnims or {}
  check("NIGHT_SHADE has an animation", anims.NIGHT_SHADE ~= nil)

  -- what the animation player budgets for the effect, ahead of the battle
  local probe = AnimPlayer.new(game.data.battle_anims)
  probe:start("NIGHT_SHADE", true)
  local budget
  for _, e in ipairs(probe.events) do
    if e.effect == "SE_WAVY_SCREEN" then budget = e.dur end
  end
  check(("SE_WAVY_SCREEN is budgeted %s frames (want 128)"):format(tostring(budget)),
        budget == 128)

  local lead = Pokemon.new(game.data, "GASTLY", 25)
  lead.moves = { { id = "NIGHT_SHADE", pp = 15 } }
  game.save.party = { lead }

  U.teleport(game, MAP, STAND.x, STAND.y, STAND.facing)
  U.wait(15)
  local ow = game.overworld
  if not ow.map:isWalkableCell(STAND.x, STAND.y) then
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
      local cx, cy = STAND.x + d[1], STAND.y + d[2]
      if ow.map:isWalkableCell(cx, cy) and not ow:npcAtCell(cx, cy) then
        U.log(("(%d, %d) is blocked, standing on"):format(STAND.x, STAND.y), cx, cy)
        U.teleport(game, MAP, cx, cy, STAND.facing)
        U.wait(15)
        ow = game.overworld
        break
      end
    end
  end
  check("standing on " .. MAP, ow.map.id == MAP)

  local battle = BattleState.newWild(game, "PIDGEY", 6)
  battle.onFinish = function() end
  ow:pushBattle(battle)

  local function waitPhase(phase, tries)
    for _ = 1, tries do
      if battle.phase == phase then return true end
      U.tap(game, "a")
      U.wait(6)
    end
    return battle.phase == phase
  end
  check("the battle reached the menu", waitPhase("menu", 60))
  U.tap(game, "a")
  check("NIGHT_SHADE is the move on the list", waitPhase("moveSelect", 20))
  U.tap(game, "a")

  -- ride the animation and time the wave from the fx layer itself
  local started, frames, phases = false, 0, {}
  local shots = { [4] = "start", [64] = "middle", [124] = "end" }
  for _ = 1, 400 do
    local wavy = battle.fx and battle.fx.wavy
    if wavy then
      started = true
      frames = frames + 1
      phases[#phases + 1] = wavy.phase
      local tag = shots[frames]
      if tag then
        U.shot(game, ("%s/bug1848_wavy_%s.png"):format(DIR, tag))
      end
    elseif started then
      break
    end
    U.wait(1)
  end

  check("the wave actually ran", started)
  check(("the wave lasted %d frames (want 128)"):format(frames),
        frames >= 120 and frames <= 136)
  local step = (#phases >= 2) and (phases[2] - phases[1]) or 0
  check(("the offset pointer advances %d entries a frame (want 2)"):format(step),
        step == 2)

  U.log("Three shots are in " .. DIR .. ": bug1848_wavy_start/middle/end.png.")
  U.log("The screen should ripple with about nine full waves top to bottom,")
  U.log("scrolling upward, and settle after roughly two seconds. The near-miss")
  U.log("to watch for is half that many waves crawling for twice as long.")

  while true do
    coroutine.yield()
  end
end
