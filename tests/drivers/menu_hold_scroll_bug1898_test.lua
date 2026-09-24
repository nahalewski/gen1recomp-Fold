-- home/list_menu.asm:8 (#1898)
--   POKEPORT_DRIVER=tests/drivers/menu_hold_scroll_bug1898_test.lua POKEPORT_IDENTITY=bug1898 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local STOCK = {
    "POTION", "SUPER_POTION", "ANTIDOTE", "PARLYZ_HEAL", "AWAKENING",
    "BURN_HEAL", "ICE_HEAL", "REPEL", "ESCAPE_ROPE", "POKE_BALL",
    "GREAT_BALL", "ULTRA_BALL",
  }
  game.save.inventory = {}
  game.save.bagOrder = {}
  for i, id in ipairs(STOCK) do
    game.save.inventory[id] = 1
    game.save.bagOrder[i] = id
  end

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  Screens.push(game, "BagMenu", {})
  U.wait(10)

  local list = game.stack:top()
  check("the bag list is on top of the stack", list ~= nil and list.items ~= nil)
  if not (list and list.items) then
    while true do coroutine.yield() end
  end
  check("hold-to-scroll is on with no mod loaded", list.keyRepeat == true)
  check("at the cart's 30-frame delay", list.repeatDelay == 30)
  check("and its 5-frame repeat", list.repeatRate == 5)

  table.insert(game.input.pressQueue, "down")
  game.input.state.down = true
  local marks = {}
  for frame = 1, 90 do
    coroutine.yield()
    marks[frame] = list.index
  end
  game.input.state.down = false

  U.log("cursor row after the press:", marks[1])
  U.log("after 29 held frames:", marks[30])
  U.log("after 30:", marks[31], "after 35:", marks[36], "after 59:", marks[60])
  check("the press alone moves one row", marks[1] == 2)
  check("a short hold moves nothing more", marks[30] == 2)
  check("the 30th held frame repeats", marks[31] == 3)
  check("and every fifth frame after it", marks[36] == 4)
  check("a long hold reaches the CANCEL row", marks[90] == #list.items)

  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  if U.shot(game, SHOT_DIR .. "/bug1898_bag_bottom.png") then
    U.log("captured", SHOT_DIR .. "/bug1898_bag_bottom.png")
  end

  -- home/list_menu.asm:47, 61-64, 338-342
  list.index, list.scroll = 4, 1
  U.wait(2)
  table.insert(game.input.pressQueue, "down")
  game.input.state.down = true
  coroutine.yield()
  game.input.state.down = false
  local blanked = list.cursorBlank
  U.log("cursorBlank right after a scrolling step:", tostring(blanked))
  check("a scroll step blanks the arrow", (blanked or 0) > 0)
  if U.shot(game, SHOT_DIR .. "/bug1898_cursor_off.png") then
    U.log("captured", SHOT_DIR .. "/bug1898_cursor_off.png")
  end
  U.wait(5)
  U.log("cursorBlank five frames later:", tostring(list.cursorBlank))
  check("and puts it back after Delay3", (list.cursorBlank or 0) == 0)
  if U.shot(game, SHOT_DIR .. "/bug1898_cursor_on.png") then
    U.log("captured", SHOT_DIR .. "/bug1898_cursor_on.png")
  end
  U.log("Compare the two: the arrow left of the item name is missing in")
  U.log("bug1898_cursor_off.png and present in bug1898_cursor_on.png.")

  list.index, list.scroll = 1, 0
  U.wait(5)
  U.log("The bag is open at the top of a twelve-item list, input handed back.")
  U.log("Hold Down: the cursor steps once, pauses about half a second, then")
  U.log("runs to CANCEL at roughly twelve rows a second.  Hold Up to come")
  U.log("back. Before this fix the cursor moved one row and stopped there.")
  U.log("While it is running, the arrow flickers: three frames of every five.")

  while true do
    coroutine.yield()
  end
end
