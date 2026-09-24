-- engine/events/black_out.asm:39-43, engine/overworld/special_warps.asm:71-129
--   POKEPORT_DRIVER=tests/drivers/blackout_landing_bug2077_test.lua POKEPORT_IDENTITY=bug2077 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local TOWN, CENTER = "VIRIDIAN_CITY", "VIRIDIAN_POKECENTER"
  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1 else fail = fail + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local function waitFor(fn, limit)
    for _ = 1, limit do
      if fn() then return true end
      U.wait(1)
    end
    return false
  end

  local function box()
    local top = game.stack:top()
    return getmetatable(top) == TextBox and top or nil
  end

  local fw = game.data.field.flyWarps[TOWN]
  U.log(("%s fly warp cell: (%d, %d)"):format(TOWN, fw.x, fw.y))

  U.teleport(game, TOWN, fw.x, fw.y, "up")
  U.tap(game, "up")
  local entered = waitFor(function()
    return game.overworld and game.overworld.map
       and game.overworld.map.id == CENTER
       and not game.overworld.transitioning
  end, 240)
  check("walked in through the " .. CENTER .. " door", entered)
  local ow = game.overworld
  U.log("wLastMap after the door:", game.save.lastOutdoor
        and game.save.lastOutdoor.id or "nil")

  local nurse
  for _, obj in ipairs(ow.map.def.objects or {}) do
    local entry = obj.text and game.data:textEntry(ow.map.def.label, obj.text)
    if entry and entry.nurse then nurse = obj break end
  end
  if not check("found Nurse Joy in " .. CENTER, nurse ~= nil) then
    U.log("Map objects changed; talk to her by hand, then black out.")
    while true do coroutine.yield() end
  end
  U.log(("Nurse Joy stands at (%d, %d)"):format(nurse.x, nurse.y))

  game.save.party = { Pokemon.new(game.data, "SQUIRTLE", 15) }
  local mon = game.save.party[1]
  local full = mon.stats.hp
  mon.hp = 1
  game.save.money = 3000

  local talked = false
  for _, dy in ipairs({ 2, 1, 3 }) do
    U.teleport(game, CENTER, nurse.x, nurse.y + dy, "up")
    ow = game.overworld
    U.tap(game, "a")
    if waitFor(function() return box() ~= nil end, 60) then
      U.log(("talked to her from (%d, %d)"):format(nurse.x, nurse.y + dy))
      talked = true
      break
    end
  end
  check("Nurse Joy answered", talked)

  for _ = 1, 80 do
    if game.stack:top() == ow and not ow.healAnim then break end
    U.tap(game, "a")
    U.wait(20)
  end
  check("the party came back healed", mon.hp == full)
  local heal = game.save.lastHeal or {}
  U.log("lastHeal:", heal.map, heal.x, heal.y,
        heal.outdoor and heal.outdoor.id or "no outdoor")
  check("SetLastBlackoutMap recorded the town door",
        heal.outdoor ~= nil and heal.outdoor.id == TOWN)
  U.wait(30)
  U.shot(game, SHOT_DIR .. "/bug2077_1_healed.png")

  U.teleport(game, "ROUTE_1", 10, 6, "down")
  ow = game.overworld
  mon.hp = 0
  game.save.money = 3000
  local encDef = game.data.encounters.ROUTE_1
  local slots = encDef and encDef.grass and encDef.grass.slots
  if not check("ROUTE_1 has a grass encounter table", slots and #slots > 0) then
    U.log("Nothing to fight here; rerun after a ROM re-import.")
    while true do coroutine.yield() end
  end
  local got
  local battle = BattleState.newWild(game, slots[1].species, slots[1].level)
  battle.onFinish = function(result)
    got = result
    ow:afterBattle(result, battle)
  end
  ow:pushBattle(battle)
  check("the encounter starts out lost (no healthy party)", battle.dead == true)

  check("the blackout text came up", waitFor(function() return box() ~= nil end, 600))
  for _ = 1, 12 do
    if not box() then break end
    U.tap(game, "a")
    U.wait(20)
  end
  local landed = waitFor(function()
    return game.overworld and game.overworld.map
       and not game.overworld.transitioning
       and game.overworld.map.id ~= "ROUTE_1"
  end, 900)
  check("the blackout warp finished", landed)
  local now = game.overworld
  U.log(("landed on %s at (%d, %d)"):format(now.map.id,
        now.player.cellX, now.player.cellY))
  check("onFinish reported a loss", got == "lose")
  check("half the money is gone (3000 -> 1500)", game.save.money == 1500)
  check("the blackout landed OUTSIDE, in " .. TOWN .. " (#2077)",
        now.map.id == TOWN)
  check("it landed on the FlyWarpDataPtr cell",
        now.player.cellX == fw.x and now.player.cellY == fw.y)
  check("wLastMap follows the landing town",
        game.save.lastOutdoor ~= nil and game.save.lastOutdoor.id == TOWN)
  U.wait(30)
  U.shot(game, SHOT_DIR .. "/bug2077_2_landed.png")
  U.log("captured", SHOT_DIR .. "/bug2077_2_landed.png")
  U.log(("%d passed, %d failed"):format(pass, fail))

  U.log("You are standing on the doorstep of the VIRIDIAN POKeMON CENTER,")
  U.log("outdoors, facing down, with no arrival spin. Standing inside in")
  U.log("front of Nurse Joy is the bug. Step up to walk back in.")

  while true do
    coroutine.yield()
  end
end
