-- data/maps/setup_scripts.asm:89
local U = require("tests.drivers.util")

local FieldMoves = require("src.world.gen2.FieldMoves")
local Music = require("src.core.Music")
local Permissions = require("src.world.gen2.Permissions")

return function(game)
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/bike-connection-1975"
  local fails = 0
  local function say(line) print("[1975] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the gen2 world did not boot")
    love.event.quit(1)
    return
  end

  world:warpToMapId("ROUTE_29", 20, 8, "left")
  U.wait(45)
  ok(world.map.id == "ROUTE_29", "landed on Route 29 (got "
    .. tostring(world.map.id) .. ")")

  local startX, startY = 7, nil
  local rows = (world.map.height or 9) * 2
  for y = 0, rows - 1 do
    local clear = true
    for x = 0, startX do
      if not Permissions.isWalkable(world.map:cellCollision(x, y)) then
        clear = false
        break
      end
    end
    if clear and not startY then startY = y end
  end
  if not startY then
    say("FAIL no walkable row runs to Route 29's west edge")
    love.event.quit(1)
    return
  end
  world:warpToMapId("ROUTE_29", startX, startY, "left")
  U.wait(45)
  say("standing at " .. startX .. "," .. startY .. " on " .. tostring(world.map.id))

  world:applyPlayerState(FieldMoves.PLAYER_BIKE)
  world:playBikeMusic()
  U.wait(10)
  ok(Music.current() == "Music_Bicycle", "riding to the bike theme (got "
    .. tostring(Music.current()) .. ")")
  U.shot(game, DIR .. "/1975-before.png")

  local from = world.map.id
  local crossed = false
  for _ = 1, 60 do
    U.hold(game, "left", 16)
    if world.map.id ~= from then crossed = true break end
  end
  ok(crossed, "crossed the west connection (now on "
    .. tostring(world.map.id) .. ")")

  U.wait(8 * Music.MAP_FADE)
  local mapSongs = game.data.audio and game.data.audio.mapSongs
  local want = world:mapMusicSong(world.map.id)
    or (mapSongs and mapSongs[world.map.id])
  say("destination song is " .. tostring(want)
    .. ", playing " .. tostring(Music.current()))
  ok(Music.current() ~= "Music_Bicycle",
    "the bike theme did not survive the crossing")
  ok(Music.current() == want,
    "the destination map's own theme is playing")
  ok(Music.mapSong() == Music.current(),
    "FadeToMapMusic left wMapMusic on the new song")
  U.shot(game, DIR .. "/1975-after.png")

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
