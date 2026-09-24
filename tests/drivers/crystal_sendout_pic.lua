--   POKEPORT_IDENTITY=crystal-sep01b POKEPORT_VERSION=crystal \
--     POKEPORT_DRIVER=tests/drivers/crystal_sendout_pic.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-sendout-pic love .
-- ../pokecrystal/engine/battle/core.asm:82-93, :4027-4056
-- ../pokecrystal/engine/battle_anims/bg_effects.asm:647-671
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-sendout-pic"
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[sendout-pic] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the crystal world did not boot")

  local lead = Mon.new(game.data, "CYNDAQUIL", 12)
  assert(lead and #lead.moves > 0, "could not build a CYNDAQUIL")
  game.save.party = { lead }
  game.save.inventory = { POKE_BALL = 5 }

  local wild = Mon.new(game.data, "PIDGEY", 6)
  assert(world:startBattle({ wild = wild }), "startBattle failed")
  local screen
  for _ = 1, 600 do
    local top = game.stack:top()
    if top and top.battle then screen = top break end
    U.wait(1)
  end
  assert(screen and screen.battle, "battle screen never came up")

  for _ = 1, 600 do
    if screen.message == "Wild PIDGEY appeared!" and screen.typer
        and screen.typer:done() then
      break
    end
    U.wait(1)
  end
  ok(screen.message == "Wild PIDGEY appeared!", "the appeared line is up")
  U.shot(game, out .. "/000-appeared.png")

  U.tap(game, "a")

  local function state()
    local anim = screen.anim
    local size = anim and anim.bg and anim.bg.picSize.player
    return {
      slide = screen.backpicSlide,
      trainer = screen.showPlayerTrainer,
      cleared = screen:picBoxCleared("player"),
      message = screen.message,
      typed = screen.typer and screen.typer:done(),
      animFrames = anim and anim.frames or nil,
      size = size,
      pending = screen.afterSendOut ~= nil,
      hud = screen.showPlayerHud,
      phase = screen.phase,
    }
  end

  local log = {}
  local slideStart, slideEnd, goFirst, revealAt, hudAt, menuAt
  local clearedDuringGo, trainerDuringSlide = true, true
  local hudBeforeReveal, revealSize, revealTyped = false, nil, nil
  for frame = 1, 360 do
    local s = state()
    log[#log + 1] = ("%03d t=%d slide=%s trainer=%s cleared=%s msg=%s typed=%s "
      .. "anim=%s size=%s pending=%s hud=%s phase=%s"):format(frame, U.frame(),
      tostring(s.slide), tostring(s.trainer), tostring(s.cleared),
      tostring(s.message), tostring(s.typed), tostring(s.animFrames),
      tostring(s.size), tostring(s.pending), tostring(s.hud), s.phase)
    if s.slide then
      slideStart = slideStart or U.frame() - s.slide
      trainerDuringSlide = trainerDuringSlide and s.trainer
    elseif slideStart and not slideEnd then
      slideEnd = U.frame()
    end
    if s.message == "Go! CYNDAQUIL!" and not goFirst then goFirst = frame end
    if goFirst and not revealAt then
      if not s.cleared then
        revealAt = frame
        revealSize = s.size
        revealTyped = s.typed
        if not s.typed then clearedDuringGo = false end
      end
    end
    if s.hud and not hudAt then hudAt = frame end
    if s.hud and not revealAt then hudBeforeReveal = true end
    if s.phase == "menu" and not menuAt then menuAt = frame break end
    U.shot(game, out .. ("/%03d.png"):format(frame))
  end
  local f = io.open(out .. "/frames.log", "w")
  if f then f:write(table.concat(log, "\n"), "\n") f:close() end

  local slideFrames = (slideStart and slideEnd) and (slideEnd - slideStart) or -1
  ok(slideFrames >= 18 and slideFrames <= 20,
    "the back pic slides out over 18 frames: " .. slideFrames)
  ok(trainerDuringSlide, "and it is the trainer sliding, not the mon")
  ok(goFirst ~= nil, "Go! CYNDAQUIL! comes up at shot " .. tostring(goFirst))
  ok(goFirst ~= nil and slideEnd ~= nil, "after the slide")
  ok(clearedDuringGo, "the box stays empty while the line types")
  ok(revealAt ~= nil, "the mon appears at frame " .. tostring(revealAt))
  ok(revealTyped, "after the line finished typing")
  ok(revealSize == 2, "as EnterMon's 2x2 square: size " .. tostring(revealSize))
  ok(not hudBeforeReveal, "the HUD is not up before the mon")
  ok(hudAt ~= nil and revealAt ~= nil and hudAt > revealAt,
    "the HUD comes up at frame " .. tostring(hudAt) .. ", after the anim")
  ok(menuAt ~= nil, "the menu follows with no A press at frame "
    .. tostring(menuAt))

  print("[sendout-pic] " .. (fails == 0 and "PASS all claims" or
    (fails .. " claims failed")) .. " -- shots in " .. out)
  love.event.quit(fails == 0 and 0 or 1)
end
