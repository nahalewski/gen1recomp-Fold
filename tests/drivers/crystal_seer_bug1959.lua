local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local Protocol = require("src.link.Protocol")
local Specials = require("src.script.gen2.Specials")
local Wire = require("src.link.Wire")

-- ../pokecrystal/maps/PokeSeersHouse.asm:29
local TOTODILE = 158
local SEER_MAP, SEER_X, SEER_Y = "POKE_SEERS_HOUSE", 2, 4

local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots"

return function(game)
  local fails = 0
  local function say(line) print("[1959] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  -- ../pokecrystal/constants/pokemon_data_constants.asm:93-99
  local function trade(mon)
    local msg = Wire.sanitize({ type = "party",
      mons = { Protocol.packMon2(mon) } })
    if not (msg and msg.mons and msg.mons[1]) then return nil end
    return Protocol.unpackMon2(game.data, msg.mons[1])
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map and world.vm) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  local save = game.save
  save.party = {}

  world:warpToMapId("ELMS_LAB", 5, 5, "down")
  U.wait(30)
  local landmark = world:caughtDataOpts().landmark
  say("ELMS_LAB landmark=" .. tostring(landmark))

  world.vm.givePokeFn(TOTODILE, 5, 0, nil)
  U.wait(5)
  local starter = save.party[1]
  ok(starter ~= nil, "the givepoke landed")

  Specials.HANDLERS.GiveShuckle(world.vm)
  U.wait(5)
  local shuckie = save.party[2]
  ok(shuckie ~= nil, "SHUCKIE joined")

  save.party = {}

  local received = starter and trade(starter)
  ok(received ~= nil, "the starter came back over the wire")
  if received then
    local b0, b1 = Mon.packCaughtData(received)
    ok(received.caughtLocation == landmark,
      "a traded mon keeps the lab's landmark (got "
        .. tostring(received.caughtLocation) .. ")")
    ok(received.caughtLevel == 5, "and its caught level")
    say("traded starter bytes " .. b0 .. " " .. b1)
    save.party[1] = received
  end

  local tradedGift = shuckie and trade(shuckie)
  if tradedGift then
    local b0, b1 = Mon.packCaughtData(tradedGift)
    ok(b0 == 0 and b1 == Mon.LANDMARK_GIFT,
      "a traded gift mon is still 0/" .. Mon.LANDMARK_GIFT
        .. " (got " .. b0 .. "/" .. b1 .. ")")
    save.party[2] = tradedGift
  end

  local legacy = Mon.new(game.data, "GEODUDE", 30)
  if legacy then
    legacy.caughtTime, legacy.caughtLevel = 0, 0
    legacy.caughtLocation, legacy.caughtByGender = 0, "boy"
    local tradedLegacy = trade(legacy)
    if tradedLegacy then
      local b0, b1 = Mon.packCaughtData(tradedLegacy)
      ok(b0 == 0 and b1 == 0,
        "a traded legacy mon stays 0/0 (got " .. b0 .. "/" .. b1 .. ")")
      save.party[3] = tradedLegacy
    end
  end

  world:warpToMapId(SEER_MAP, SEER_X, SEER_Y, "up")
  U.wait(60)
  ok(world.map and world.map.def and world.map.def.id == SEER_MAP,
    "standing in front of the Seer")
  U.shot(game, SHOT_DIR .. "/crystal_seer_bug1959.png")
  say("press A: slot 1 must read NEW BARK TOWN, slot 2 and 3 "
    .. "\"Whaaaat? I can't tell a thing!\"")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
