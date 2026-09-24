-- scripts/MtMoonPokecenter.asm:30-34
--   SHOT_DIR=/tmp/karp_shots POKEPORT_DRIVER=tests/drivers/magikarp_money_bug1983_test.lua love .

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/karp_shots"
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")

  local function topIs(cls)
    return getmetatable(game.stack:top()) == cls
  end

  local function findBox()
    for i = #game.stack.states, 1, -1 do
      if getmetatable(game.stack.states[i]) == TextBox then
        return game.stack.states[i]
      end
    end
  end

  game.save.money = 5326
  game.save.flags.EVENT_BOUGHT_MAGIKARP = nil
  U.teleport(game, "MT_MOON_POKECENTER", 10, 7, "up")
  U.wait(10)
  U.shot(game, DIR .. "/karp_00_center.png")

  local box
  for _ = 1, 40 do
    U.tap(game, "a")
    U.wait(4)
    box = findBox()
    if box then break end
    U.hold(game, "up", 2)
  end
  if not box then
    U.log("FAIL: salesman never opened a text box")
    return
  end

  U.log("page1 moneyVisible:", box:moneyVisible())
  U.shot(game, DIR .. "/karp_01_page1.png")

  for _ = 1, 400 do
    if topIs(ChoiceBox) then break end
    if box.done and not box.choicePushed then U.wait(1) end
    U.tap(game, "a")
    U.wait(2)
  end
  U.log("choice up:", topIs(ChoiceBox), "moneyVisible:", box:moneyVisible())
  U.shot(game, DIR .. "/karp_02_choice.png")

  U.tap(game, "b")
  U.wait(30)
  U.shot(game, DIR .. "/karp_03_declined.png")
  U.log("done")
end
