-- ../pokered/data/text/text_2.asm:1144
--   POKEPORT_DRIVER=tests/drivers/multihit_crit_text_bug1949_test.lua POKEPORT_IDENTITY=red-aug28 POKEPORT_TOUCH=0 SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Runtime = require("src.mods.Runtime")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1 else fail = fail + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  game.save.party = { Pokemon.new(game.data, "SNORLAX", 30) }
  game.save.player.name = "RED"
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(10)
  local ow = game.overworld
  check("the overworld is up on ROUTE_1", ow ~= nil)

  local battle = BattleState.newWild(game, "RATTATA", 5)
  battle.onFinish = function() end
  ow:pushBattle(battle)
  for _ = 1, 400 do
    if game.stack:top() == battle and (battle.introSlide or 0) == 0 then break end
    U.wait(1)
  end
  check("the battle reached the screen", game.stack:top() == battle)
  for i = 1, 900 do
    if battle.phase == "menu" and #battle.queue == 0 then break end
    if i % 6 == 0 and battle.phase == "messages" then
      table.insert(game.input.pressQueue, "a")
    end
    U.wait(1)
    game.input.state.a = false
  end
  check("the battle reached its FIGHT menu", battle.phase == "menu")

  local unsub
  if Runtime.hooks and Runtime.hooks.wrap then
    unsub = Runtime.hooks:wrap("battle.crit", function() return true end)
  end
  check("the crit hook is installed", unsub ~= nil)

  battle.rng = (function()
    local seq, i = { 7, 0, 255, 255 }, 0
    return function(_, b)
      i = i + 1
      return seq[i] ~= nil and seq[i] or b
    end
  end)()
  battle:performMove(battle.enemy, battle.player, { id = "DOUBLESLAP", pp = 10 })
  battle.phase = "messages"
  battle.afterQueue = "menu"

  -- ../pokered/data/text/text_2.asm:1205
  local pages, presses = {}, 0
  local sawCrit, sawCount, critDismissed = false, false, false
  local critHeldFrames, gaps = 0, 0
  local prevPrompt, last = false, nil
  local shotArrow, shotHold = false, false
  for _ = 1, 1800 do
    if battle.current and battle.current.text then last = battle.current.text end
    if last and last:find("times!", 1, true) then sawCount = true end
    if last == "Critical hit!" then sawCrit = true end

    if battle.msgPrompt and not prevPrompt then
      pages[#pages + 1] = last
      if last == "Critical hit!" and not shotArrow then
        shotArrow = true
        U.shot(game, DIR .. "/bug1949_crit_prompt.png")
      end
    end
    if prevPrompt and not battle.msgPrompt then presses = presses + 1 end
    prevPrompt = battle.msgPrompt and true or false

    if battle.msgPrompt then
      table.insert(game.input.pressQueue, "a")
    end

    if critDismissed and not sawCount then
      if (battle.current or battle.animPlaying or battle.msgHold) then
        critHeldFrames = critHeldFrames + 1
        if not shotHold and battle.animPlaying then
          shotHold = true
          U.shot(game, DIR .. "/bug1949_crit_through_anim.png")
        end
      else
        gaps = gaps + 1
      end
    end
    if sawCrit and not critDismissed and battle.current == nil
       and not battle.msgPrompt then
      critDismissed = true
    end

    if sawCount and #battle.queue == 0 and battle.current == nil
       and not battle.msgPrompt and presses >= 2 then
      break
    end
    U.wait(1)
    game.input.state.a = false
  end

  local names = table.concat(pages, " | ")
  check("the crit line printed", sawCrit)
  check("the strikes ran through to the hit-count line", sawCount)
  check("the crit page raised the '\226\150\188' arrow (" .. names .. ")",
        pages[1] == "Critical hit!")
  check("one prompt per prompted page, one press each (" .. #pages
          .. " pages, " .. presses .. " dismissed)",
        #pages >= 2 and presses == #pages)
  check("the count line prompts too",
        pages[#pages] ~= nil and pages[#pages]:find("times!", 1, true) ~= nil)
  check("the crit page stayed drawn after the press (" .. critHeldFrames
          .. " frames, " .. gaps .. " blank)",
        critDismissed and gaps == 0 and critHeldFrames > 0)
  check("the turn finished", #battle.queue == 0)
  if unsub then unsub() end

  U.log(("machine checks: %d passed, %d failed"):format(pass, fail))
  U.log("prompted pages: " .. names)
  U.log("Eyes: " .. DIR .. "/bug1949_crit_prompt.png -- 'Critical hit!' with")
  U.log("the blinking arrow, as the cart shows it.  After A,")
  U.log("bug1949_crit_through_anim.png is the same line still up while the")
  U.log("next slap animates; it stays until 'Hit 5 times!' replaces it.")

  while true do
    coroutine.yield()
  end
end
