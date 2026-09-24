-- #1860: jingles cut or dropped by the text blip.  GiveItemScript
-- (pokegold engine/overworld/scripting.asm:441-449), Oak's rating
-- (engine/events/prof_oaks_pc.asm:14-21), bug contest judging
-- (engine/events/bug_contest/judging.asm:29-32).
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gold_jingle_bug1860_test.lua love .
local U = require("tests.drivers.util")
local Sound = require("src.core.Sound")

return function(game)
  U.wait(45)
  local world = game.world
  assert(world and world.map and world.vm, "gold world did not boot")

  local opts = game.save.options or {}
  if (opts.sfxVol or 7) == 0 then
    U.log("WARNING: options.sfxVol is 0 -- every jingle below will be")
    U.log("WARNING: silent; raise SFX volume before judging this by ear")
  end

  local results = {}
  local function check(label, ok)
    results[#results + 1] = (ok and "PASS " or "FAIL ") .. label
  end

  local function specialId(name)
    for index, entry in ipairs(world.vm.specialOrder or {}) do
      if entry == name then return index - 1 end
    end
    return nil
  end

  -- World:specialSound resolves the numeric index (itemIdByIndex), and only
  -- a TM_HM-pocket item rings Sfx_GetTm.
  local tm
  for _, def in pairs(game.data.items or {}) do
    if type(def) == "table" and def.pocket == "TM_HM" and def.index then
      tm = def.index
      break
    end
  end
  check("cache names a TM_HM-pocket item", tm ~= nil)

  -- Runs one scripted moment while mashing A every 4th frame the whole way.
  -- everBusy: a gated sfx started at all (the drop half of the bug).
  -- maxRun: longest unbroken stretch it kept sounding (the cut half).
  -- popEarly: a box with the sfx hold popped while the jingle still rang.
  local function runMoment(label, script, minRun)
    U.wait(30)
    world.vm:start(script)
    U.wait(2)
    local everBusy, maxRun, run = false, 0, 0
    local sawHeld, popEarly = false, false
    local sawArrowWhileBusy = false
    local pressIn = 4
    for _ = 1, 1500 do
      local busy = Sound.sfxBusy()
      if busy then
        everBusy = true
        run = run + 1
        if run > maxRun then maxRun = run end
      else
        run = 0
      end
      local top = game.stack:top()
      if top and top.sfxWait and busy then sawHeld = true end
      -- LoadBlinkingCursor (home/text.asm:749) (#1926)
      if busy and top and top.arrowVisible and top:arrowVisible() then
        sawArrowWhileBusy = true
      end
      pressIn = pressIn - 1
      if pressIn <= 0 then
        pressIn = 4
        game.input.pressQueue[#game.input.pressQueue + 1] = "a"
        game.input.state.a = true
        U.wait(1)
        game.input.state.a = false
        if top and top.sfxWait and busy and game.stack:top() ~= top then
          popEarly = true
        end
      else
        U.wait(1)
      end
      if not world:busy() and not game.stack:top() then break end
    end
    check(label .. ": a jingle started (not dropped by the blip)", everBusy)
    check(("%s: it survived mashed A for %d frames (want >= %d)")
      :format(label, maxRun, minRun), maxRun >= minRun)
    check(label .. ": the held box refused A while it rang",
      sawHeld and not popEarly)
    check(label .. ": no arrow while the jingle rang", not sawArrowWhileBusy)
  end

  if tm then
    runMoment("verbosegiveitem TM", {
      { op = "opentext" },
      { op = "verbosegiveitem", args = { tm, 1 } },
      { op = "closetext" },
      { op = "end" },
    }, 60)
  end

  local oak = specialId("ProfOaksPCBoot")
  check("specialOrder names ProfOaksPCBoot", oak ~= nil)
  if oak then
    game.save.pokedex = game.save.pokedex or { seen = {}, caught = {} }
    game.save.pokedex.caught = {}
    for i = 1, 150 do game.save.pokedex.caught["DEX_SEED_" .. i] = true end
    runMoment("Oak's dex rating fanfare", {
      { op = "opentext" },
      { op = "special", id = oak },
      { op = "closetext" },
      { op = "end" },
    }, 40)
  end

  local judging = specialId("BugContestJudging")
  check("specialOrder names BugContestJudging", judging ~= nil)
  if judging then
    runMoment("bug contest place fanfares", {
      { op = "opentext" },
      { op = "special", id = judging },
      { op = "closetext" },
      { op = "end" },
    }, 30)
  end

  for _, line in ipairs(results) do U.log(line) end

  U.log("Right sounds like: the TM jingle, the dex-rating fanfare and each")
  U.log("place fanfare play out in full even while A is mashed; the box under")
  U.log("each one only closes once its jingle has finished ringing.")

  while true do
    coroutine.yield()
  end
end
