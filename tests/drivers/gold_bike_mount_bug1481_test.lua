-- pokegold engine/events/overworld.asm:1616-1630, :1686 (#1481)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gold_bike_mount_bug1481_test.lua love .
-- No POKEPORT_SPEED: the song starts on the audio clock.
local U = require("tests.drivers.util")

local Bag = require("src.inventory.Bag")
local PackMenu = require("src.ui.gen2.PackMenu")

local HOME = { map = "NEW_BARK_TOWN", x = 13, y = 6 }
local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

return function(game)
  local failed = 0
  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")
  local world, save = game.world, game.save

  world:setMap(HOME.map, HOME.x, HOME.y, "down")
  U.wait(12)

  local sprites = game.data and game.data.gen2Sprites or {}
  pass(sprites.SPRITE_CHRIS_BIKE ~= nil,
    "this cache carries SPRITE_CHRIS_BIKE, the sheet the mount swaps to")
  local songs = game.data and game.data.audio and game.data.audio.songs or {}
  pass(songs.Music_Bicycle ~= nil,
    "and Music_Bicycle, the song .GetOnBike starts")

  save.inventory = { BICYCLE = 1 }
  save.bagOrder = { "BICYCLE" }
  Bag.order(save, { items = game.data.items })

  game.packCursor = nil
  -- data/items/attributes.asm
  local pack = PackMenu.new(game, { save = save, world = world,
    pocket = "KEY_ITEM", onClose = function() game.stack:pop() end })
  game.stack:push(pack)
  U.wait(20)

  -- pokegold engine/items/pack.asm:243
  U.tap(game, "a")
  U.wait(20)
  U.tap(game, "a")

  for _ = 1, 150 do
    if world.playerState == "bike" then break end
    coroutine.yield()
  end
  pass(world.playerState == "bike",
    "the queued Script_GetOnBike reached loadvar VAR_MOVEMENT, PLAYER_BIKE")
  local def = world.player and world.player.spriteDef
  pass(def ~= nil and def.id == "SPRITE_CHRIS_BIKE",
    "and the player is on the rider sheet")
  U.shot(game, SHOT_DIR .. "/bike_mount.png")

  U.tap(game, "a")
  U.wait(40)
  U.shot(game, SHOT_DIR .. "/bike_after_box.png")
  U.log("the box above should read \"got on the BICYCLE!\" and the bike theme"
    .. " should be playing; both are for a human to judge")
  U.log(failed == 0 and "bike mount ran clean"
    or (failed .. " machine-checkable parts failed"))
  while true do coroutine.yield() end
end
