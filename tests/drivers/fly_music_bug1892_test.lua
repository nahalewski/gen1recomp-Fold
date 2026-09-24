-- home/overworld.asm (#1892)
--   POKEPORT_DRIVER=tests/drivers/fly_music_bug1892_test.lua \
--     POKEPORT_TOUCH=0 SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Music = require("src.core.Music")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function waitFor(pred, limit)
    local guard = 0
    while not pred() and guard < (limit or 900) do
      guard = guard + 1
      coroutine.yield()
    end
    return pred()
  end

  U.teleport(game, "ROUTE_17", 4, 10, "down")
  local ow = game.stack:top()
  local destSong = game.data.audio.mapSongs.PALLET_TOWN
  U.log("Pallet Town theme is " .. tostring(destSong))

  local Screens = require("src.ui.Screens")
  Screens.push(game, "TownMap", { fly = true, onFly = function() end })
  for _ = 1, 20 do coroutine.yield() end
  U.shot(game, DIR .. "/fly_music_1_picker.png")
  U.log("Picker: two small black triangles sit in the top-right of the"
        .. " name strip, one pointing up, one pointing down")
  game.stack:pop()
  for _ = 1, 4 do coroutine.yield() end

  ow:flyTo("PALLET_TOWN")

  if not waitFor(function() return ow.map.id == "PALLET_TOWN" end) then
    U.log("FAIL never reached PALLET_TOWN")
    while true do coroutine.yield() end
  end

  local earlyStart = nil
  local frames = 0
  while ow.flyArrive and frames < 300 do
    if Music.current() == destSong then
      earlyStart = earlyStart or frames
    end
    frames = frames + 1
    coroutine.yield()
  end
  U.shot(game, DIR .. "/fly_music_2_swoop.png")

  if earlyStart then
    U.log(("FAIL the Pallet theme started %d frames into the landing swoop")
          :format(earlyStart))
  else
    U.log("PASS the destination theme stayed silent through the swoop")
  end

  for _ = 1, 8 do coroutine.yield() end
  if Music.current() == destSong then
    U.log("PASS the Pallet theme started once the bird landed")
  else
    U.log("FAIL after landing the current song is "
          .. tostring(Music.current()))
  end
  U.shot(game, DIR .. "/fly_music_3_landed.png")

  U.log("Screenshots are under " .. DIR)
  while true do coroutine.yield() end
end
