-- ../pokered/scripts/CinnabarLabFossilRoom.asm:74-83
-- ../pokered/engine/events/give_pokemon.asm:52-71
--   POKEPORT_DRIVER=tests/drivers/fossil_gift_bug2034_test.lua \
--     POKEPORT_IDENTITY=red-aug28 POKEPORT_VERSION=red POKEPORT_TOUCH=0 \
--     SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local function boxText()
    local t = game.stack:top()
    if not (t and t.pages) then return nil end
    local out = {}
    for _, page in ipairs(t.pages) do
      for _, line in ipairs(page) do out[#out + 1] = line end
    end
    return table.concat(out, " ")
  end

  local function mashUntil(cond, tries)
    for _ = 1, tries or 200 do
      if cond() then return true end
      U.tap(game, "a")
      U.wait(4)
    end
    return false
  end

  U.teleport(game, "CINNABAR_LAB_FOSSIL_ROOM", 5, 3, "up")
  local ow = game.overworld
  for _, npc in ipairs(ow.npcs) do
    if npc.def and npc.def.text == "TEXT_CINNABARLABFOSSILROOM_SCIENTIST1" then
      npc.wanders, npc.moving = false, false
      npc.cellX, npc.cellY = 5, 2
      npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
      npc.facing = "down"
    end
  end

  game.save.party = {}
  game.save.labFossilMon = "AERODACTYL"
  game.save.flags.EVENT_GAVE_FOSSIL_TO_LAB = true
  game.save.flags.EVENT_LAB_STILL_REVIVING_FOSSIL = nil
  game.save.flags.EVENT_LAB_HANDING_OVER_FOSSIL_MON = nil
  U.wait(5)

  U.tap(game, "a")
  U.wait(20)
  U.shot(game, DIR .. "/fossil2034_1_backtolife.png")

  local sawGot = mashUntil(function()
    local t = boxText()
    return t and t:find("AERODACTYL", 1, true) and t:find("got", 1, true)
  end)
  check("_GotMonText prints for the revived fossil", sawGot)
  U.wait(40)
  U.shot(game, DIR .. "/fossil2034_2_gotmon.png")

  local sawNick = mashUntil(function()
    local t = boxText()
    return t and t:find("nickname", 1, true) ~= nil
  end)
  check("and AddPartyMon asks for a nickname", sawNick)
  U.wait(60)
  U.shot(game, DIR .. "/fossil2034_3_nickname.png")

  U.tap(game, "b")
  mashUntil(function() return game.stack:top() == ow end)
  U.shot(game, DIR .. "/fossil2034_4_after.png")

  check("AERODACTYL is in the party",
        game.save.party[1] and game.save.party[1].species == "AERODACTYL")
  check("at level 30 (`ld c, 30`)",
        game.save.party[1] and game.save.party[1].level == 30)
  check("the quest reset", not game.save.flags.EVENT_GAVE_FOSSIL_TO_LAB
        and game.save.labFossilMon == nil)
  check("and nothing is left over the overworld", game.stack:top() == ow)

  U.log("Shots: " .. DIR .. "/fossil2034_*.png")
  U.log("Shot 2 must read 'RED got / AERODACTYL!' and shot 3 the nickname")
  U.log("prompt. Broken showed neither: the mon appeared in the party with")
  U.log("no line at all, straight from the back-to-life text.")
  U.log("DONE")
  love.event.quit()
end
