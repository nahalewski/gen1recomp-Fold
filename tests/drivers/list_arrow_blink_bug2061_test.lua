-- pokered home/window.asm:5-13, 26-35, 217-263; home/list_menu.asm:518-524
--   POKEPORT_DRIVER=tests/drivers/list_arrow_blink_bug2061_test.lua POKEPORT_IDENTITY=bug2061 POKEPORT_TOUCH=0 POKEPORT_VERSION=red SHOT_DIR=/tmp/shots/bug2061 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local ListMenu = require("src.ui.ListMenu")
  local Menu = require("src.ui.Menu")
  local Screens = require("src.ui.Screens")
  local Strings = require("src.core.Strings")

  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local ok = true
  local function check(label, pass)
    U.log(pass and "PASS" or "FAIL", label)
    if not pass then ok = false end
    return pass
  end

  -- pokered data/maps/objects/PalletTown.asm: the house doors sit at (5,5)
  local TOWN, TOWN_X, TOWN_Y = "PALLET_TOWN", 10, 8
  -- home/list_menu.asm:518-522
  local STOCK = { "POTION", "ANTIDOTE", "BURN_HEAL", "ICE_HEAL",
                  "AWAKENING", "PARLYZ_HEAL" }

  for _, id in ipairs(STOCK) do
    check(id .. " exists as an item", game.data.items[id] ~= nil)
  end
  check("renderer is up", game.renderer ~= nil)

  game.save.player.name = "SEBAS"
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 50) }
  game.save.inventory = {}
  game.save.bagOrder = nil
  local Bag = require("src.inventory.Bag")
  for i, id in ipairs(STOCK) do Bag.add(game.save, id, i) end

  local function stationary()
    for _ = 1, 60 do
      if not (game.overworld and game.overworld.player.moving) then break end
      coroutine.yield()
    end
  end

  local function openBag()
    stationary()
    U.tap(game, "start")
    U.wait(20)
    local menu = game.stack:top()
    if getmetatable(menu) == Menu then
      local ITEM = Strings("ITEM")
      for _ = 1, 20 do
        if menu.items[menu.index].label == ITEM then break end
        U.tap(game, "down")
        U.wait(6)
      end
      U.tap(game, "a")
      U.wait(20)
    end
    local bag = game.stack:top()
    if getmetatable(bag) ~= ListMenu then
      U.log("START -> ITEM did not reach the bag, pushing BagMenu directly")
      bag = Screens.push(game, "BagMenu")
      U.wait(20)
    end
    return getmetatable(bag) == ListMenu and bag or nil
  end

  -- home/window.asm:217-263
  local function atPhase(bag, target)
    for _ = 1, 180 do
      if bag.arrowBlink == target then return true end
      coroutine.yield()
    end
    return false
  end

  U.teleport(game, TOWN, TOWN_X, TOWN_Y, "down")
  U.wait(20)

  local bag = openBag()
  if check("the bag opened", bag ~= nil) then
    check("a full page of names, so the arrow is on screen",
          #bag.items > bag.rows)
    check("the list carries a blink phase", bag.arrowBlink ~= nil)

    check("reached the on phase", atPhase(bag, 5))
    check("arrow-on shot reached disk",
          U.shot(game, SHOT_DIR .. "/bug2061_on.png"))

    check("reached the off phase", atPhase(bag, 35))
    check("arrow-off shot reached disk",
          U.shot(game, SHOT_DIR .. "/bug2061_off.png"))

    check("the phase came back around", atPhase(bag, 5))
    check("arrow-on-again shot reached disk",
          U.shot(game, SHOT_DIR .. "/bug2061_on_again.png"))

    -- home/window.asm:29-35
    check("back to the off phase", atPhase(bag, 35))
    U.tap(game, "down")
    U.wait(2)
    check("the press rearmed the arrow to solid", (bag.arrowBlink or 99) < 30)
    check("scrolling shot reached disk",
          U.shot(game, SHOT_DIR .. "/bug2061_scrolling.png"))
  end

  U.log("")
  if ok then
    U.log("the bag is open with six items in it. compare the lower right")
    U.log("corner of the list box, at 144,88, across the shots:")
    U.log("bug2061_on.png has the down arrow, bug2061_off.png has bare box")
    U.log("there, and bug2061_on_again.png has it back -- that is the ~2 Hz")
    U.log("blink the cart runs while the menu idles.")
    U.log("bug2061_scrolling.png is taken one frame after a down press from")
    U.log("the OFF phase: the arrow must be solid there, because the cart")
    U.log("skips the blink on any frame a key was read.")
    U.log("watch the live window too: idle on the list and the arrow should")
    U.log("pulse about twice a second, and hold down and it should stay lit.")
    U.log("yellow shares this list code: rerun with POKEPORT_VERSION=yellow")
    U.log("and a yellow identity for the same three shots.")
  else
    U.log("a check above failed, so nothing on screen is worth reading yet.")
  end

  while true do
    coroutine.yield()
  end
end
