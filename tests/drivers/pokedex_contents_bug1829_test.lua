-- Eye/ear check for the Pokédex CONTENTS screen and entry page (#1829):
-- screen furniture, the seven rows, the side-menu cursor, the cry the entry
-- page waits on and the blinking page arrow.
-- engine/menus/pokedex.asm:161-199, :242-273, :500-506; home/joypad2.asm:55-83.
-- No POKEPORT_SPEED: the cry runs on the real-time audio clock.
--   POKEPORT_DRIVER=tests/drivers/pokedex_contents_bug1829_test.lua POKEPORT_IDENTITY=bug1829 POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local opts = game.save.options or {}
  if (opts.sfxVol or 1) == 0 then
    U.log("WARNING sfxVol is 0, so the entry page's cry will be silent and")
    U.log("WARNING the pause before the height/weight lines will look like a hang")
  end

  -- dex numbers -> species, so the driver never hardcodes an id
  local byDex = {}
  for _, def in pairs(game.data.pokemon) do
    if def.dex then byDex[def.dex] = def end
  end
  check("the cache carries a Kanto numbering", byDex[1] ~= nil and byDex[20] ~= nil)

  game.save.pokedex = { seen = {}, owned = {} }
  for n = 1, 20 do
    local def = byDex[n]
    if def and n ~= 5 then game.save.pokedex.seen[def.id] = true end
  end
  for _, n in ipairs({ 1, 2, 3, 7, 8 }) do
    local def = byDex[n]
    if def then
      game.save.pokedex.seen[def.id] = true
      game.save.pokedex.owned[def.id] = true
    end
  end
  game.save.player.name = "bryan"

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(20)

  local dex = Screens.push(game, "PokedexMenu")
  U.wait(20)
  check("the dex list is on the stack", game.stack:top() == dex)
  check("the list stops at the highest seen number (20)", #dex.items == 20)
  check("dex 005 was left unseen, so its row is a dashed line",
        dex.items[5] and dex.items[5].name == "----------")
  check("dex 001 is owned, so its row carries the ball marker",
        dex.items[1] and dex.items[1].ball == true)
  U.shot(game, SHOT_DIR .. "/bug1829_contents.png")

  -- Right pages the list without moving the cursor off its screen row
  local rowBefore = dex.index - dex.scroll
  U.tap(game, "right")
  U.wait(10)
  check("Right scrolled the list", dex.scroll == 7)
  check("the cursor kept its screen row", dex.index - dex.scroll == rowBefore)
  U.shot(game, SHOT_DIR .. "/bug1829_contents_paged.png")
  U.tap(game, "left")
  U.wait(10)
  check("Left paged back to the top", dex.scroll == 0)

  -- A on an owned row opens the side menu: the cursor moves onto the
  -- DATA/CRY/AREA/QUIT block that was already on screen
  U.tap(game, "a")
  U.wait(20)
  local side = game.stack:top()
  check("A opened the side menu", side ~= dex)
  check("the list row kept its hollow cursor", dex.hollowIndex == dex.index)
  U.shot(game, SHOT_DIR .. "/bug1829_side_menu.png")

  -- DATA is the first row, so A again opens the entry page
  U.tap(game, "a")
  U.wait(2)
  local page = game.stack:top()
  check("DATA opened the entry page", page ~= side and page.def ~= nil)
  U.shot(game, SHOT_DIR .. "/bug1829_entry_cry.png")

  local waited = 0
  while page.crying and page:crying() and waited < 300 do
    waited = waited + 1
    coroutine.yield()
  end
  U.log("the cry held the page for", waited, "frames")
  U.wait(10)
  U.shot(game, SHOT_DIR .. "/bug1829_entry_full.png")
  check("the entry has more than one page, so the arrow is drawn",
        (page.pageCount or 1) > 1)

  local function shotAtBlink(target, path)
    for _ = 1, 120 do
      if (page.blink or 0) == target then break end
      coroutine.yield()
    end
    U.shot(game, path)
  end
  shotAtBlink(8, SHOT_DIR .. "/bug1829_arrow_on.png")
  shotAtBlink(38, SHOT_DIR .. "/bug1829_arrow_off.png")

  U.log("Shots are in " .. SHOT_DIR .. ". The CONTENTS screen should read")
  U.log("CONTENTS top left, a vertical rule down column 14 with SEEN and OWN")
  U.log("counts beside it and DATA/CRY/AREA/QUIT under them, and seven rows")
  U.log("of number-above-name with the ball left of the owned names.")
  U.log("bug1829_entry_cry should show the frame, name, kind, No. and pic")
  U.log("with nothing below the divider while the cry sounds; the height,")
  U.log("weight and description arrive in bug1829_entry_full once it ends.")
  U.log("The near-miss to watch for: all of it painted at once with the cry")
  U.log("playing over the top, and a page arrow that never blinks off")
  U.log("(bug1829_arrow_on has it, bug1829_arrow_off should not).")

  while true do
    coroutine.yield()
  end
end
