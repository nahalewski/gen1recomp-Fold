-- ../pokecrystal/audio/engine.asm:84
local U = require("tests.drivers.util")

local ChipAudio = require("src.core.ChipAudio")
local Mon = require("src.battle.gen2.Mon")
local Music = require("src.core.Music")

local SETTLE = 300

return function(game)
  local fails = 0
  local logPath = os.getenv("POKEPORT_DRIVER_LOG")
  local function say(line)
    print("[2002] " .. line)
    if logPath then
      local file = io.open(logPath, "a")
      if file then file:write(line, "\n") file:close() end
    end
  end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  say("jit.status=" .. tostring(jit and jit.status()))

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  local save = game.save
  save.party = { Mon.new(game.data, "CYNDAQUIL", 15) }

  local function scene(label)
    U.wait(SETTLE)
    local stats = ChipAudio.stats()
    say(label .. ": song=" .. tostring(Music.current()) .. " " .. stats.line)
    return stats
  end

  world:warpToMapId("NEW_BARK_TOWN", 4, 6, "down")
  local outdoor = scene("overworld")
  ok(outdoor.worker ~= "none", "the chip worker is running")

  world:warpToMapId("PLAYERS_HOUSE_1F", 7, 5, "down")
  scene("interior")

  local wild = Mon.new(game.data, "RATTATA", 4)
  world:startBattle({ wild = wild })
  U.wait(10)
  scene("battle")
  for _ = 1, 240 do
    local top = game.stack:top()
    if top and top.battle then
      game.stack:pop()
      U.wait(2)
      break
    end
    U.wait(1)
  end

  local back = scene("overworld after battle")

  ok(back.underruns == 0,
    "no queue underrun across every scene (" .. back.underruns .. ")")
  ok(back.restarts == 0,
    "and no restart (" .. back.restarts .. ")")
  ok(back.depthMin and back.depthMin >= ChipAudio.MUSIC_PREROLL,
    "the queue never fell below the pre-roll (min "
      .. tostring(back.depthMin) .. ")")
  ok(type(back.xrtAvg) == "number" and back.xrtAvg < 0.5,
    "the worker's mean cost per buffer stays under half realtime ("
      .. tostring(back.xrtAvg) .. ", worst " .. tostring(back.xrtMax) .. ")")

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
