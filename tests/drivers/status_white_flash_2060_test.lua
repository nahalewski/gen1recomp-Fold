-- engine/menus/start_sub_menus.asm:97-104
-- engine/pokemon/status_screen.asm:82, home/pokemon.asm:186
--   POKEPORT_VERSION=red POKEPORT_TOUCH=0 SHOT_DIR=/tmp/bug2060 \
--     POKEPORT_DRIVER=tests/drivers/status_white_flash_2060_test.lua love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/bug2060"
  local SummaryMenu = require("src.ui.SummaryMenu")

  local function top() return game.stack:top() end
  local function bail(msg)
    U.log("[2060] FAIL " .. msg .. "; top = "
            .. tostring(top() and (top().screenId or "?")))
    while true do coroutine.yield() end
  end

  local function cursorTo(menu, field, wanted)
    for _ = 1, 40 do
      if not menu or menu[field] == wanted then
        return menu and menu[field] == wanted
      end
      U.tap(game, menu[field] < wanted and "down" or "up")
      U.wait(3)
    end
    return menu and menu[field] == wanted
  end

  U.newGame(game)
  U.wait(20)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  U.tap(game, "start")
  U.wait(10)
  local menu = top()
  if not (menu and menu.screenId == "StartMenu") then bail("no start menu") end
  local row
  for i, it in ipairs(menu.items or {}) do
    if it.label == "POKéMON" then row = i break end
  end
  if not (row and cursorTo(menu, "index", row)) then bail("no POKéMON row") end
  U.tap(game, "a")
  U.wait(10)

  local party = top()
  if not (party and party.screenId == "PartyMenu") then bail("no party menu") end
  U.tap(game, "a")
  U.wait(8)
  local subRow
  for i, it in ipairs(party.subItems or {}) do
    if it.action == "stats" then subRow = i break end
  end
  if not (subRow and cursorTo(party, "subIndex", subRow)) then
    bail("no STATS row")
  end
  U.shot(game, DIR .. "/00-stats-selected.png")

  -- ---- opening: status_screen.asm:82 --------------------------------------
  U.tap(game, "a")
  for i = 1, 8 do U.shot(game, ("%s/10-open-%02d.png"):format(DIR, i)) end
  local screen = top()
  if not (getmetatable(screen) == SummaryMenu
          or (screen and screen.screenId == "SummaryMenu")) then
    bail("status screen never opened")
  end
  U.log("[2060] opened; whiteHold left = " .. tostring(screen.whiteHold))
  U.wait(30)
  U.shot(game, DIR .. "/11-open-settled.png")

  -- ---- closing: status_screen.asm:431 + home/pokemon.asm:186 --------------
  U.tap(game, "a")
  U.wait(10)
  U.log("[2060] page = " .. tostring(screen.page))
  U.tap(game, "a")
  local blink = top()
  U.log("[2060] closing state frames = " .. tostring(blink and blink.frames)
          .. ", isOpaque = " .. tostring(blink and blink.isOpaque))
  for i = 1, 8 do U.shot(game, ("%s/20-close-%02d.png"):format(DIR, i)) end
  U.wait(20)
  U.shot(game, DIR .. "/21-close-settled.png")
  U.log("[2060] back on " .. tostring(top() and (top().screenId or "?")))
  U.log("[2060] shots in " .. DIR)
  while true do coroutine.yield() end
end
