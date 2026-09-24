-- Manual check of the FLY picker's bird marker and the departure fade (#1840).
-- LoadTownMap_Fly overwrites the cursor tiles with BirdSprite and marks the
-- destination with it, with no blink (engine/items/town_map.asm:146-149,
-- 177-179, 190-198); _LeaveMapAnim stops the music with fade control $4 before
-- the bird appears (engine/overworld/player_animations.asm:123, home/overworld.asm:772).
--   POKEPORT_DRIVER=tests/drivers/fly_bird_bug1840_test.lua POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Music = require("src.core.Music")
  local TownMap = require("src.ui.TownMap")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local vol = game.save.options and game.save.options.musicVol
  if vol == 0 then
    U.log("music volume is 0 in options; raise it or the fade is inaudible")
  end
  if (game.save.options and game.save.options.sfxVol) == 0 then
    U.log("sfx volume is 0 in options; the bird's SFX_FLY will be silent too")
  end

  -- BuildFlyLocationsList only offers visited towns
  game.save.visited = game.save.visited or {}
  for _, town in ipairs({ "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY",
                          "CERULEAN_CITY", "CELADON_CITY" }) do
    game.save.visited[town] = true
  end

  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  U.wait(30)

  local flown = nil
  Screens.push(game, "TownMap", { fly = true,
    onFly = function(mapId) flown = mapId end })
  U.wait(20)
  local map = game.stack:top()
  check("the FLY picker opened", getmetatable(map) == TownMap)
  check("it is in fly mode", map.fly == true)
  check("the destination marker is the bird sheet", map.birdSheet ~= nil)
  check("the blinking cursor art is still loaded for the plain viewer",
        map.bg == nil or map.bg.cursor ~= nil)
  U.log("fly destinations:", #(map.locs or {}))
  U.shot(game, SHOT_DIR .. "/bug1840_flypicker.png")

  -- the marker must not blink: sample the same screen a few frames apart
  map.blink = 0
  U.wait(2)
  U.shot(game, SHOT_DIR .. "/bug1840_flypicker_a.png")
  map.blink = 30
  U.wait(2)
  U.shot(game, SHOT_DIR .. "/bug1840_flypicker_b.png")
  U.log("compare", SHOT_DIR .. "/bug1840_flypicker_a.png",
        "with _b.png: they must be identical")

  U.tap(game, "up")
  U.wait(20)
  U.tap(game, "a")
  U.wait(20)
  check("A picks a destination", flown ~= nil)
  U.log("flying to", tostring(flown))

  local faded = false
  local realFade = Music.fadeOut
  Music.fadeOut = function(control, pending)
    faded = control
    return realFade(control, pending)
  end
  local ow = game.overworld
  if flown then ow:flyTo(flown) end
  U.wait(1)
  check("departure asks the music to fade", faded ~= false)
  check("with StopMusic's control byte $4", faded == 4)
  check("the world holds during the fade", ow.flyFade ~= nil)
  check("and the bird is not on screen yet", ow.flyAnim == nil)
  U.shot(game, SHOT_DIR .. "/bug1840_fading.png")

  local flapping = false
  for _ = 1, 120 do
    if ow.flyAnim then flapping = true break end
    U.wait(1)
  end
  check("the bird appears once the fade is done", flapping)
  Music.fadeOut = realFade
  U.wait(6)
  U.shot(game, SHOT_DIR .. "/bug1840_bird.png")
  U.log("captured", SHOT_DIR .. "/bug1840_{flypicker,fading,bird}.png")

  U.log("Right: the picker marks the town with a small bird that holds still,")
  U.log("and pressing A drops the map theme to silence before the bird flaps.")
  U.log("The near-miss is a square bracket cursor blinking on the town, or the")
  U.log("theme still playing under the flap and cutting off at the warp.")

  while true do
    coroutine.yield()
  end
end
