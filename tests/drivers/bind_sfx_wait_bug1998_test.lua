-- PlayAnimation (engine/battle/animations.asm:437), and every type that
-- (home/delay.asm:15), which blocks while CHAN5/CHAN6/CHAN8 still sound.
--   POKEPORT_DRIVER=tests/drivers/bind_sfx_wait_bug1998_test.lua POKEPORT_VERSION=red POKEPORT_TOUCH=0 POKEPORT_IDENTITY=bug1998 SHOT_DIR=/tmp/bind1998 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local AnimPlayer = require("src.battle.AnimPlayer")
  local Sound = require("src.core.Sound")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1 else fail = fail + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  U.log("#1998 applying-attack shake waits out the move sfx: machine checks")

  check("Sound exposes the CHAN5/6/8 busy predicate",
        type(Sound.moveSfxBusy) == "function")
  check("Sound exposes the WaitForSoundToFinish frame budget",
        type(Sound.moveSfxWaitFrames) == "function")
  check("nothing is sounding before a battle starts", Sound.moveSfxBusy() == false)

  -- data/moves/animations.asm:326 BindAnim is SUBANIM_0_BIND twice at delay 4,
  -- (delay + 1) per frame block (:346, home/copy2.asm:62).
  local ba = game.data.battle_anims
  check("battle_anims is in the cache", ba ~= nil)

  local function compile(move)
    if not (ba and (ba.moveAnims or {})[move]) then return nil end
    local p = AnimPlayer.new(ba)
    local ok = pcall(p.start, p, move, false)
    if not ok then return nil end
    return p
  end

  local function shapeOf(p)
    local out = {}
    for _, s in ipairs(p.steps) do out[#out + 1] = tostring(s.dur) end
    return table.concat(out, " ")
  end

  local function total(p)
    local n = 0
    for _, s in ipairs(p.steps) do n = n + s.dur end
    return n
  end

  local FENCE = {
    { move = "BIND", frames = 40, shape = "10 5 5 10 5 5" },
    { move = "WRAP", frames = 60, shape = "10 5 5 10 5 5 10 5 5" },
    { move = "CONSTRICT", frames = 72, shape = "10 7 7 10 7 7 10 7 7" },
  }
  for _, f in ipairs(FENCE) do
    local p = compile(f.move)
    check(f.move .. " compiles into a timeline", p ~= nil)
    if p then
      U.log(("  %s steps: %s"):format(f.move, shapeOf(p)))
      check(("%s is %d frames (want %d): the subanimation is unchanged")
              :format(f.move, total(p), f.frames), total(p) == f.frames)
      check(("%s keeps its %s shape"):format(f.move, f.shape),
            shapeOf(p) == f.shape)
    end
  end

  U.log(("machine checks: %d passed, %d failed"):format(pass, fail))

  if not (game.data.moves.BIND and ba) then
    U.log("no BIND animation in this cache, so there is nothing to watch")
    while true do coroutine.yield() end
  end

  local MAP, SX, SY = "ROUTE_1", 5, 5
  local ekans = Pokemon.new(game.data, "EKANS", 30)
  ekans.moves = { { id = "BIND", pp = game.data.moves.BIND.pp } }
  game.save.party = { ekans }
  game.save.player.name = "RED"

  U.teleport(game, MAP, SX, SY, "down")
  U.wait(12)
  local ow = game.overworld
  if ow and not ow.map:isWalkableCell(SX, SY) then
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
      local cx, cy = SX + d[1], SY + d[2]
      if ow.map:isWalkableCell(cx, cy) and not ow:npcAtCell(cx, cy) then
        U.teleport(game, MAP, cx, cy, "down")
        U.wait(12)
        ow = game.overworld
        break
      end
    end
  end
  check("the overworld is up on " .. MAP, ow ~= nil and ow.map.id == MAP)

  local battle = BattleState.newWild(game, "PIDGEY", 20)
  battle.onFinish = function() end
  ow:pushBattle(battle)
  for _ = 1, 400 do
    if game.stack:top() == battle and (battle.introSlide or 0) == 0 then break end
    U.wait(1)
  end
  check("the battle reached the screen", game.stack:top() == battle)

  battle.enemy.mon.stats.hp = 500
  battle.enemy.mon.hp = 500
  battle.enemy.shownHP = 500
  for i = #battle.enemy.mon.moves, 1, -1 do
    local id = battle.enemy.mon.moves[i].id
    if id == "WHIRLWIND" or id == "ROAR" or id == "TELEPORT" then
      table.remove(battle.enemy.mon.moves, i)
    end
  end

  local held, sawBusy, shakeAt, animEnd = 0, false, nil, nil
  local budgetSeen, tailSeen = 0, 0
  local frame = 0
  local curMove
  if battle.animPlayer then
    local realStart = battle.animPlayer.start
    battle.animPlayer.start = function(self, moveId, isPlayer, o)
      local r = realStart(self, moveId, isPlayer, o)
      curMove = moveId
      return r
    end
  end
  local function sample()
    frame = frame + 1
    if curMove ~= "BIND" then return end
    if battle.animPlaying then
      local n = Sound.moveSfxWaitFrames()
      if n > tailSeen then tailSeen = n end
    end
    if battle.hitSfxWait then
      held = held + 1
      sawBusy = true
      animEnd = animEnd or frame
      if battle.hitSfxWait + 1 > budgetSeen then budgetSeen = battle.hitSfxWait + 1 end
    end
    if not shakeAt and battle.fx and (battle.fx.shakeProg or battle.fx.blink) then
      shakeAt = frame
    end
  end

  local function pump(n, mash, stop)
    for i = 1, n do
      if mash and i % mash == 0 and battle.phase == "messages" then
        table.insert(game.input.pressQueue, "a")
      end
      U.wait(1)
      game.input.state.a = false
      sample()
      if stop and stop() then return end
    end
  end

  local function toMenu()
    pump(1200, 6, function() return battle.phase == "menu" and #battle.queue == 0 end)
    return battle.phase == "menu"
  end

  local function useBind()
    for _ = 1, 80 do
      if battle.phase == "moveSelect" then break end
      if battle.phase == "menu" then
        if battle.menuIndex ~= 1 then
          U.tap(game, battle.menuIndex > 2 and "up" or "left")
        else
          U.tap(game, "a")
        end
      else
        U.tap(game, "a")
      end
      for _ = 1, 3 do U.wait(1) sample() end
    end
    if battle.phase ~= "moveSelect" then return false end
    for _ = 1, 20 do
      if battle.phase ~= "moveSelect" then return true end
      U.tap(game, "a")
      for _ = 1, 3 do U.wait(1) sample() end
    end
    return false
  end

  check("the battle reached its FIGHT menu", toMenu())

  local sent = false
  for _ = 1, 6 do
    battle.player.stages.accuracy = 0
    shakeAt, animEnd, held, curMove = nil, nil, 0, nil
    budgetSeen, tailSeen = 0, 0
    sent = useBind()
    if not sent then break end
    pump(900, 8, function() return shakeAt ~= nil and not battle.animPlaying end)
    if shakeAt then break end
    U.log("  BIND did not connect that turn; using it again")
    toMenu()
  end
  check("chose BIND from the move menu", sent)
  check("BIND's applying-attack fx eventually ran", shakeAt ~= nil)

  U.log(("  the shake was held for %d frames after the animation finished"):format(held))
  U.log(("  budget taken at the gate: %d frames; longest BIND sfx tail seen "
           .. "during the animation: %d frames"):format(budgetSeen, tailSeen))
  if sawBusy then
    check("the shake waited on the BIND sfx instead of starting the same frame",
          held > 0)
  else
    U.log("  the BIND sfx had already finished when the animation ended, so")
    U.log("  there was nothing to wait for on this turn (short sfx, or SFX is")
    U.log("  muted in OPTION). raise SFX and try the pad below before judging.")
  end
  U.shot(game, DIR .. "/bug1998_bind_after.png")

  local opts = game.save.options or {}
  if opts.animations == false then
    U.log("  ANIMATION is off in OPTION, which skips the whole row: turn it on")
  end
  if opts.sfxVol == 0 then
    U.log("  sfxVol is 0, so there is no sfx tail to wait on: raise SFX")
  end

  U.log("the pad is yours in a battle where the EKANS knows only BIND (#1998).")
  U.log("pick FIGHT then BIND and watch the END of the animation: the two coil")
  U.log("frames should finish, the screen should sit completely still for about")
  U.log("half a second while the squeeze sfx rings out, and only then should the")
  U.log("screen shake and the HP bar drain.")
  U.log("the bug was the shake starting on the very next frame, which wiped the")
  U.log("second coil off the screen mid-sound and read as a cut-off animation.")
  U.log("BIND traps the foe, so the next few turns replay it as \"attack")
  U.log("continues!\" and you can watch the beat more than once.")
  U.log("screenshots: " .. DIR .. "/bug1998_*.png")
  while true do coroutine.yield() end
end
