-- pokegold engine/battle/effect_commands.asm:175-181
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-sleep-hud-2082"
  os.execute('mkdir -p "' .. out .. '" 2>/dev/null')
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[sleep-hud] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the crystal world did not boot")
  world:warpToMapId("NEW_BARK_TOWN", 4, 6, "down")
  U.wait(15)

  local lead = Mon.new(game.data, "SLOWPOKE", 30)
  assert(lead, "could not build a SLOWPOKE")
  lead.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }
  game.save.party = { lead }

  local wild = Mon.new(game.data, "RATTATA", 3)
  assert(wild, "could not build a wild RATTATA")
  wild.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }

  assert(world:startBattle({ wild = wild }), "startBattle failed")
  local screen
  for _ = 1, 600 do
    local top = game.stack:top()
    if top and top.battle then screen = top break end
    U.wait(1)
  end
  assert(screen and screen.battle, "battle screen never came up")

  for _ = 1, 900 do
    if screen.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(2)
  end
  ok(screen.phase == "menu", "reached the battle menu")

  local mon = screen.battle.player
  mon.status = "sleep"
  mon.statusTurns = 1
  screen:syncShownStatus()
  U.wait(6)
  ok(screen.shownStatus and screen.shownStatus.player == "sleep",
    "the HUD picked up the SLP tag before the turn")
  U.shot(game, out .. "/asleep_menu.png")

  U.tap(game, "a")
  U.wait(4)
  U.tap(game, "a")

  local stale, woke = 0, false
  for tick = 1, 300 do
    local queue = screen.queue or {}
    local queuedWake = false
    for _, ev in ipairs(queue) do
      if ev.text and ev.text:find("woke up!", 1, true) then
        queuedWake = true
      end
    end
    local shown = screen.shownStatus and screen.shownStatus.player
    if mon.status == nil then
      woke = true
      if not queuedWake and #queue > 0 and shown == "sleep" then
        stale = stale + 1
      end
    end
    if tick % 5 == 0 then
      U.shot(game, ("%s/t%03d.png"):format(out, tick))
    end
    if tick % 8 == 0 then U.tap(game, "a") end
    U.wait(1)
  end

  ok(woke, "the sleeper woke during the turn")
  ok(stale == 0,
    "the SLP tag never outlived the woke-up line (stale frames: " .. stale .. ")")
  ok(mon.status == nil, "the status byte stayed clear")

  print("[sleep-hud] " .. (fails == 0 and "PASS all claims" or
    (fails .. " claims failed")) .. " -- shots in " .. out)
  love.event.quit(fails == 0 and 0 or 1)
end
