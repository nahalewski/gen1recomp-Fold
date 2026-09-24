-- ../pokecrystal/audio/engine.asm:105
local U = require("tests.drivers.util")

local ChipSynth = require("src.core.ChipSynth")
local Sound = require("src.core.Sound")

-- ../pokecrystal/data/pokemon/cries.asm:163
local EXPECT = {
  { species = "CYNDAQUIL", length = 128, channel = 1, frames = 20 },
  { species = "CYNDAQUIL", length = 128, channel = 2, frames = 20 },
  { species = "MARILL", length = 288, channel = 1, frames = 37 },
}

return function(game)
  local fails = 0
  local function say(line) print("[1945] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end
  world:warpToMapId("NEW_BARK_TOWN", 5, 6, "down")
  U.wait(30)

  local data = game.data
  local cries = data.audio and data.audio.cries
  if not cries then
    say("FAIL no cry table in this cache")
    love.event.quit(1)
    return
  end

  for _, want in ipairs(EXPECT) do
    local cry = cries[want.species]
    if not cry then
      ok(false, want.species .. " missing from the cry table")
    else
      ok(cry.length == want.length, ("%s length word is %s (want %d)")
        :format(want.species, tostring(cry.length), want.length))
      local engine = ChipSynth.newEngine(data, cry.header, {
        sfx = true, allowLoops = false,
        frequencyOffset = cry.pitch, cryLength = cry.length,
      })
      local channel = engine and engine.channels[want.channel]
      if not channel then
        ok(false, want.species .. " has no channel " .. want.channel)
      else
        local frames, events, dropped = 0, 0, 0
        for _ = 1, 128 do
          local event = channel:nextEvent()
          if not event then break end
          events = events + 1
          if event.duration * 60 < 0.5 then dropped = dropped + 1 end
          frames = frames + event.duration * 60
        end
        ok(dropped == 0, ("%s ch%d drops %d notes")
          :format(want.species, want.channel + 4, dropped))
        ok(math.floor(frames + 0.5) == want.frames,
          ("%s ch%d runs %.0f frames over %d events (want %d)")
            :format(want.species, want.channel + 4, frames, events,
              want.frames))
      end
    end
  end

  for _, species in ipairs({ "CYNDAQUIL", "MARILL", "CYNDAQUIL" }) do
    say("playing " .. species)
    local src = Sound.playCry(data, species)
    ok(src ~= nil, species .. " cry source built")
    U.wait(90)
  end

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
