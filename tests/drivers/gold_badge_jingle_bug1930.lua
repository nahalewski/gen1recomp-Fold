-- #1930 home/audio.asm:225
local U = require("tests.drivers.util")

local Sound = require("src.core.Sound")

return function(game)
  local fails, lines = 0, {}

  local function claim(ok, text)
    if not ok then fails = fails + 1 end
    lines[#lines + 1] = (ok and "PASS " or "FAIL ") .. text
    return ok
  end

  local function stop()
    for _, line in ipairs(lines) do U.log(line) end
    U.log(("%d checks, %d failed"):format(#lines, fails))
    while true do coroutine.yield() end
  end

  U.wait(45)
  local world = game.world
  if not (world and world.map and world.vm) then
    U.log("FAIL the gold world never booted, nothing to listen to")
    while true do coroutine.yield() end
  end

  local audio = game.data.audio or {}
  local ids = {}
  for i, name in ipairs(audio.sfxOrder or {}) do ids[name] = i - 1 end
  claim(ids.Sfx_GetBadge ~= nil and audio.sfx and audio.sfx.Sfx_GetBadge ~= nil,
    ("the cache can play Sfx_GetBadge (id %s)"):format(
      tostring(ids.Sfx_GetBadge)))
  claim((ids.Sfx_ReadText2 or 0) < (ids.Sfx_GetBadge or 0),
    "and the box beep outranks it, so the gate is live")
  local vol = game.save.options and game.save.options.sfxVol
  claim(vol ~= 0, ("SFX VOL is %s"):format(tostring(vol)))
  if not ids.Sfx_GetBadge then stop() end

  local probe = Sound.play(game.data, "Sfx_GetBadge")
  local length = 0
  if probe then
    local ok, dur = pcall(probe.getDuration, probe)
    if ok and dur then length = math.ceil(dur * 60) end
  end
  Sound.waitSfxDone()
  U.wait(15)
  U.log(("Sfx_GetBadge is %d frames"):format(length))
  claim(length > 180, "which is past the cap the park used to carry")

  world.vm:start({ { op = "playsound", id = ids.Sfx_GetBadge },
                   { op = "waitsfx" } })
  local parked = 0
  while world.vm:running() and parked < 900 do
    parked = parked + 1
    coroutine.yield()
  end
  local busy = Sound.sfxBusy()
  U.log(("vm released after %d frames; sfx still busy = %s"):format(
    parked, tostring(busy)))
  claim(parked >= length - 5,
    ("the vm stayed parked for the fanfare (%d of %d frames)"):format(
      parked, length))
  claim(parked > 180, "which the old flat cap cut short")
  claim(not busy, "and the channels were free when it moved on")
  Sound.waitSfxDone()
  U.wait(30)

  local started = nil
  local realPlay = Sound.play
  Sound.play = function(d, name)
    local src = realPlay(d, name)
    if Sound.resolve(d, name) == "Sfx_GetBadge" then started = src ~= nil end
    return src
  end
  local blip = Sound.playPress(game.data)
  claim(blip ~= nil, "the box beep sounds, as it does on every dismissed box")
  world.vm:start({ { op = "playsound", id = ids.Sfx_GetBadge },
                   { op = "waitsfx" } })
  local n = 0
  while world.vm:running() and n < 900 do
    n = n + 1
    coroutine.yield()
  end
  Sound.play = realPlay
  claim(started == true, "the script's playsound rang over the retired beep")
  Sound.waitSfxDone()

  for _, line in ipairs(lines) do U.log(line) end
  U.log(("%d checks, %d failed"):format(#lines, fails))
  U.log("ears-on: beat Falkner and mash A through the badge line; the")
  U.log("fanfare must ring in full, and his next box must not cut it short.")
  U.log("the controls are yours.")
  while true do coroutine.yield() end
end
