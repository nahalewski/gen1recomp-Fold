-- scripts/CeladonMartRoof.asm:44
--   POKEPORT_DRIVER=tests/drivers/celadon_girl_drink_bug1955_test.lua POKEPORT_IDENTITY=bug1955 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
    or "/tmp/shots"

  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local Menu = require("src.ui.Menu")
  local Bag = require("src.inventory.Bag")

  local MAP = "CELADON_MART_ROOF"
  local GIRL_TEXT = "TEXT_CELADONMARTROOF_LITTLE_GIRL"

  local ok = true
  local function check(label, pass)
    if not pass then ok = false end
    U.log(pass and "PASS" or "FAIL", label)
    return pass
  end

  local function boxText(box)
    local out = {}
    for _, page in ipairs(box.pages or {}) do
      for _, line in ipairs(page) do out[#out + 1] = line end
    end
    return table.concat(out, " / ")
  end

  local function freezeGirl()
    for _, n in ipairs(game.overworld.npcs or {}) do
      if n.def and n.def.text == GIRL_TEXT then
        n.wanders = false
        return n
      end
    end
    return nil
  end

  game.save.party = { Pokemon.new(game.data, "BULBASAUR", 5) }
  for _, id in ipairs({ "FRESH_WATER", "SODA_POP", "LEMONADE" }) do
    if (game.save.inventory[id] or 0) == 0 then
      Bag.add(game.save, id, 1, game.data)
    end
  end
  game.save.flags.EVENT_GOT_TM13 = nil

  U.teleport(game, MAP, 15, 2, "down")
  local girl = freezeGirl()
  if not check("the roof has the thirsty girl", girl ~= nil) then
    while true do coroutine.yield() end
  end
  local spawnX, spawnY = girl.def.x, girl.def.y

  local SIDES = {
    { 0, 1, "up" }, { 0, -1, "down" }, { 1, 0, "left" }, { -1, 0, "right" },
  }
  local stand
  for _, s in ipairs(SIDES) do
    local cx, cy = spawnX + s[1], spawnY + s[2]
    if game.overworld.map:isWalkableCell(cx, cy)
       and not game.overworld:npcAtCell(cx, cy) then
      stand = { cx, cy, s[3] }
      break
    end
  end
  if not check("there is a cell to talk to her from", stand ~= nil) then
    while true do coroutine.yield() end
  end

  U.teleport(game, MAP, stand[1], stand[2], stand[3])
  girl = freezeGirl()
  U.wait(10)
  local ow = game.overworld
  check("she is standing on her spawn cell",
        girl ~= nil and girl.cellX == spawnX and girl.cellY == spawnY)

  for _ = 1, 30 do
    if getmetatable(game.stack:top()) == ChoiceBox then break end
    U.tap(game, "a")
    U.wait(12)
  end
  local ask = game.stack.states[#game.stack.states - 1]
  check("A on the girl asks whether to give her a drink",
        getmetatable(game.stack:top()) == ChoiceBox)
  if getmetatable(ask) == TextBox then U.log("she says:", boxText(ask)) end
  U.shot(game, SHOT_DIR .. "/bug1955_1_ask.png")

  U.tap(game, "a")
  U.wait(40)

  local menu = game.stack:top()
  check("YES opens the drink list", getmetatable(menu) == Menu)
  if getmetatable(menu) ~= Menu then
    U.log("top of stack is", tostring(menu))
    while true do coroutine.yield() end
  end
  local under = game.stack.states[#game.stack.states - 1]
  check("the which-drink box is still up underneath",
        getmetatable(under) == TextBox)
  if getmetatable(under) == TextBox then
    U.log("the box reads:", boxText(under))
    check("it is GiveHerWhichDrinkText",
          boxText(under):lower():find("drink", 1, true) ~= nil)
    check("it waits for nothing (text_end, not prompt)",
          under.stay ~= nil and under.stay.prompt ~= true)
  end
  check("the list is not a screen of its own", menu.isOpaque ~= true)
  check("no invented title bar", menu.title == nil)
  check("TextBoxBorder at hlcoord 0,0, 14x8",
        menu.tx == 0 and menu.ty == 0 and menu.tw == 14 and menu.th == 8)
  check("names at hlcoord 2,2 (wTopMenuItemY 2)", menu.itemY == 2)
  local labels = {}
  for i, item in ipairs(menu.items) do labels[i] = item.label end
  U.log("rows:", table.concat(labels, ", "))
  check("three drinks and no CANCEL row", #menu.items == 3
        and labels[1] == game.data.items.FRESH_WATER.name)
  U.shot(game, SHOT_DIR .. "/bug1955_2_menu.png")

  U.tap(game, "up")
  U.wait(10)
  check("Up on FRESH WATER does not wrap onto LEMONADE", menu.index == 1)

  U.tap(game, "a")
  U.wait(40)
  local yay = game.stack:top()
  check("A on FRESH WATER prints her reply", getmetatable(yay) == TextBox)
  check("the drink box is still on screen under it",
        game.stack.states[#game.stack.states - 1] == menu)
  if getmetatable(yay) == TextBox then U.log("she says:", boxText(yay)) end
  U.shot(game, SHOT_DIR .. "/bug1955_3_yay.png")

  for _ = 1, 80 do
    if game.stack:top() == ow then break end
    U.tap(game, "a")
    U.wait(12)
  end
  check("the conversation ends back on the overworld", game.stack:top() == ow)
  check("nothing is left on the stack", #game.stack.states == 1)
  check("the FRESH WATER is gone", (game.save.inventory.FRESH_WATER or 0) == 0)
  check("TM13 is in the bag", (game.save.inventory.TM_ICE_BEAM or 0) > 0)
  check("EVENT_GOT_TM13 is set", game.save.flags.EVENT_GOT_TM13 == true)
  U.shot(game, SHOT_DIR .. "/bug1955_4_after.png")

  U.log(ok and "checks are green, the screen is worth looking at."
           or "something above says FAIL, do not trust what is on screen.")
  U.log("shots are in " .. SHOT_DIR .. ".")
  U.log("")
  U.log("what only a human can judge: bug1955_2_menu.png should show a small")
  U.log("bordered box in the TOP-LEFT corner, no title, roof tiles visible to")
  U.log("its right, and 'Give her which drink?' still in the bottom box with")
  U.log("no blinking arrow.  bug1955_3_yay.png should still show that corner")
  U.log("box while she says Yay! underneath.  Talk to her again with SODA POP")
  U.log("and LEMONADE for TM48 and TM49; a second FRESH WATER gets the")
  U.log("'not thirsty after all' line with the box still up.")

  while true do
    coroutine.yield()
  end
end
