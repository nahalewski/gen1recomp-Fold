-- engine/events/vending_machine.asm (#1876)
--   POKEPORT_DRIVER=tests/drivers/vending_machine_bug1876_test.lua POKEPORT_IDENTITY=bug1876 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  os.execute("mkdir -p " .. SHOT_DIR)

  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local Menu = require("src.ui.Menu")

  local ok = true
  local function check(label, pass)
    if not pass then ok = false end
    U.log(pass and "PASS" or "FAIL", label)
    return pass
  end

  local function waitForArrow(box)
    for _ = 1, 240 do
      if box.waiting or box.done then return true end
      U.wait(1)
    end
    return false
  end

  game.save.party = { Pokemon.new(game.data, "BULBASAUR", 5) }
  game.save.money = 3000

  U.teleport(game, "CELADON_MART_ROOF", 10, 2, "up")
  U.wait(20)

  local ow = game.overworld
  local sign
  for _, s in ipairs((ow.map.def and ow.map.def.signs) or {}) do
    if tostring(s.text or s.id or ""):find("VENDING_MACHINE") then
      sign = s
      break
    end
  end
  if not check("the roof has a vending machine sign", sign ~= nil) then
    while true do coroutine.yield() end
  end
  U.teleport(game, "CELADON_MART_ROOF", sign.x, sign.y + 1, "up")
  U.wait(20)

  U.tap(game, "a")
  U.wait(40)
  local intro = game.stack:top()
  check("A on the machine opens a text box", getmetatable(intro) == TextBox)
  local said = {}
  for _, page in ipairs(intro.pages or {}) do
    for _, line in ipairs(page) do said[#said + 1] = line end
  end
  U.log("it reads:", table.concat(said, " / "))
  check("it is VendingMachineText1",
        table.concat(said, " "):find("vending machine", 1, true) ~= nil)
  check("the money box rides along", intro.money ~= nil)
  waitForArrow(intro)
  U.shot(game, SHOT_DIR .. "/bug1876_1_intro.png")

  U.tap(game, "a")
  U.wait(30)
  local menu = game.stack:top()
  check("the drink list opens over it", getmetatable(menu) == Menu)
  if getmetatable(menu) ~= Menu then
    while true do coroutine.yield() end
  end
  check("the greeting is still in the box underneath",
        game.stack.states[#game.stack.states - 1] == intro)
  check("the list is not a screen of its own", menu.isOpaque ~= true)
  check("TextBoxBorder at hlcoord 0,3, 14x10",
        menu.tx == 0 and menu.ty == 3 and menu.tw == 14 and menu.th == 10)
  local labels = {}
  for i, item in ipairs(menu.items) do labels[i] = item.label end
  U.log("rows:", table.concat(labels, ", "))
  check("three drinks and CANCEL", #menu.items == 4
        and labels[4] == "CANCEL")
  U.shot(game, SHOT_DIR .. "/bug1876_2_menu.png")

  U.tap(game, "up")
  U.wait(10)
  check("Up on FRESH WATER does not wrap onto CANCEL", menu.index == 1)

  local moneyBefore = game.save.money
  local heldBefore = game.save.inventory.FRESH_WATER or 0
  U.tap(game, "a")
  U.wait(150) -- 120 frames of rumble, then the popped-out line
  local result = game.stack:top()
  check("the delivery ends in a text box", getmetatable(result) == TextBox)
  local out = {}
  for _, page in ipairs((result.pages) or {}) do
    for _, line in ipairs(page) do out[#out + 1] = line end
  end
  U.log("it reads:", table.concat(out, " / "))
  check("it is VendingMachineText5",
        table.concat(out, " "):find("popped out", 1, true) ~= nil)
  check("the drink is in the bag",
        (game.save.inventory.FRESH_WATER or 0) == heldBefore + 1)
  check("and it cost 200", game.save.money == moneyBefore - 200)
  check("the drink list is gone by then",
        game.stack.states[#game.stack.states - 1] == ow)
  waitForArrow(result)
  U.shot(game, SHOT_DIR .. "/bug1876_3_popped.png")

  U.tap(game, "a")
  U.wait(30)
  check("one A closes the whole conversation", game.stack:top() == ow)

  U.log(ok and "checks are green, the screen is worth looking at."
           or "something above says FAIL, do not trust what is on screen.")
  U.log("shots are in " .. SHOT_DIR .. ".")
  U.log("")
  U.log("the half a machine cannot judge: bug1876_2_menu.png should show the")
  U.log("roof tiles to the right of column 14 and the greeting still in the")
  U.log("bottom box, with MONEY top-right and the prices one row under each")
  U.log("drink. talk to the machine again and press A on a drink: the rumble")
  U.log("is SFX_PUSH_BOULDER restarted 60 times over two seconds, and the")
  U.log("popped-out line lands while the last one is still decaying.")

  while true do
    coroutine.yield()
  end
end
