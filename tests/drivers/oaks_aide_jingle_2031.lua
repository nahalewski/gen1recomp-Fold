-- ../pokered/engine/events/oaks_aide.asm:64-67
-- ../pokered/scripts/Route2Gate.asm:28-30
--   POKEPORT_DRIVER=tests/drivers/oaks_aide_jingle_2031.lua POKEPORT_IDENTITY=red-aug28 POKEPORT_VERSION=red POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
    or "/tmp/shots"
  local MAP = "ROUTE_2_GATE"
  local AIDE = { x = 1, y = 4 }

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local opts = game.save.options or {}
  if (opts.sfxVol or 7) == 0 then
    U.log("note: sfxVol is 0, so the fanfare under test will be silent")
  end

  U.newGame(game)
  local save = game.save

  -- ../pokered/scripts/Route2Gate.asm:12-13
  local ids = {}
  for id in pairs(game.data.pokemon) do
    if type(game.data.pokemon[id]) == "table" then ids[#ids + 1] = id end
  end
  table.sort(ids)
  local owned = {}
  for i = 1, 12 do owned[ids[i]] = true end
  save.pokedex = save.pokedex or {}
  save.pokedex.seen = save.pokedex.seen or {}
  save.pokedex.owned = owned
  save.flags.EVENT_GOT_HM05 = nil
  save.flags.EVENT_GOT_HM_FLASH = nil
  check("12 kinds owned, aide flag clear", not save.flags.EVENT_GOT_HM05)

  U.teleport(game, MAP, AIDE.x + 1, AIDE.y, "right")
  U.wait(10)
  U.tap(game, "left")
  U.wait(10)
  local fx, fy = game.overworld.player:facingCell()
  check("facing the aide at (1, 4)", fx == AIDE.x and fy == AIDE.y)
  U.shot(game, SHOT_DIR .. "/bug2031_before_talk.png")

  U.log("Press A, answer YES.")
  U.log("Expect, in order:")
  U.log("  1. 'Great! You have caught 12 kinds...Here you go!'")
  U.log("  2. 'RED got the HM FLASH!' WITH the item fanfare, box held")
  U.log("     until the jingle finishes")
  U.log("  3. 'The HM FLASH lights even the darkest dungeons.'")
  U.log("Walking away and talking again must show only line 3.")

  while true do
    coroutine.yield()
  end
end
