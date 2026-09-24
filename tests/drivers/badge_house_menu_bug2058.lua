-- pokered scripts/CeruleanBadgeHouse.asm:12-53, home/list_menu.asm:29-31,
-- data/text_boxes.asm:13, text/CeruleanBadgeHouse.asm:19
--   POKEPORT_DRIVER=tests/drivers/badge_house_menu_bug2058.lua POKEPORT_IDENTITY=bug2058 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local MapScripts = require("data.scripts.init")

  local MAP = "CERULEAN_BADGE_HOUSE"
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local hooks = MapScripts.get(MAP)
  check(MAP .. " registers the middle-aged man talk script",
        hooks ~= nil and hooks.talk ~= nil
        and hooks.talk.TEXT_CERULEANBADGEHOUSE_MIDDLE_AGED_MAN ~= nil)

  -- object_event 5, 3 (data/maps/objects/CeruleanBadgeHouse.asm:15)
  U.teleport(game, MAP, 5, 2, "down")
  U.wait(20)

  local function findList()
    for _ = 1, 200 do
      local top = game.stack:top()
      if type(top) == "table" and top.items and top.itemBox then return top end
      U.tap(game, "a")
      U.wait(6)
    end
    return nil
  end

  local list = findList()
  if not check("talking opens the badge list menu", list ~= nil) then return end
  check("LIST_MENU_BOX, not the generic full-screen list", list.itemBox == true)
  check("four printed rows", list.rows == 4)
  check("cursor reaches three rows", list.cursorRows == 3)
  check("the map stays visible around the box", list.isOpaque == false)
  U.shot(game, SHOT_DIR .. "/2058_list.png")

  for _ = 1, 5 do
    U.tap(game, "down")
    U.wait(4)
  end
  U.wait(20)
  check("the list scrolled", list.scroll > 0)
  U.shot(game, SHOT_DIR .. "/2058_list_scrolled.png")

  local index, scroll = list.index, list.scroll
  U.tap(game, "a")
  U.wait(40)
  check("the description prints over the still-open list",
        game.stack:top() ~= list)
  U.shot(game, SHOT_DIR .. "/2058_description.png")

  for _ = 1, 60 do
    if game.stack:top() == list then break end
    U.tap(game, "a")
    U.wait(6)
  end
  check("the list is armed again after the description",
        game.stack:top() == list)
  check("wCurrentMenuItem survives .loop", list.index == index)
  check("wListScrollOffset survives .loop", list.scroll == scroll)
  U.shot(game, SHOT_DIR .. "/2058_list_again.png")

  U.tap(game, "b")
  U.wait(30)
  for _ = 1, 60 do
    if game.stack:top() == game.overworld then break end
    U.tap(game, "a")
    U.wait(6)
  end
  check("B backs out to the overworld", game.stack:top() == game.overworld)
end
