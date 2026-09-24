local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local Save = require("src.core.gen2.Save")
local Specials = require("src.script.gen2.Specials")

-- constants/pokemon_constants.asm
-- (../pokecrystal/maps/PokeSeersHouse.asm:29
local TOTODILE = 158
local SEER_MAP, SEER_X, SEER_Y = "POKE_SEERS_HOUSE", 2, 4

return function(game)
  local fails = 0
  local function say(line) print("[1929] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
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
  if starter then
    local b0, b1 = Mon.packCaughtData(starter)
    ok(starter.caughtLocation == landmark,
      "the starter carries the lab's landmark (got "
        .. tostring(starter.caughtLocation) .. ")")
    say("starter bytes " .. b0 .. " " .. b1)
  end

  Specials.HANDLERS.GiveShuckle(world.vm)
  U.wait(5)
  local shuckie = save.party[2]
  ok(shuckie ~= nil, "SHUCKIE joined")
  if shuckie then
    local b0, b1 = Mon.packCaughtData(shuckie)
    ok(shuckie.caughtLocation == Mon.LANDMARK_GIFT,
      "SHUCKIE is LANDMARK_GIFT (got " .. tostring(shuckie.caughtLocation) .. ")")
    ok(b0 == 0 and b1 == Mon.LANDMARK_GIFT,
      "and its byte pair is 0/" .. Mon.LANDMARK_GIFT
        .. " (got " .. b0 .. "/" .. b1 .. ")")
  end

  save.party[3] = Mon.new(game.data, "GEODUDE", 30)
  if save.party[3] then
    save.party[3].caughtLevel = 30
    save.party[3].caughtLocation = nil
    Save.MIGRATIONS[7](save)
    local b0, b1 = Mon.packCaughtData(save.party[3])
    ok(b0 == 0 and b1 == 0,
      "the legacy slot migrates to an empty pair (got " .. b0 .. "/" .. b1 .. ")")
    local s0, s1 = Mon.packCaughtData(starter or {})
    ok(s0 ~= 0 or s1 ~= 0, "and the stamped starter survives the migration")
    say("starter after migrate " .. s0 .. " " .. s1)
  end

  world:warpToMapId(SEER_MAP, SEER_X, SEER_Y, "up")
  U.wait(60)
  ok(world.map and world.map.def and world.map.def.id == SEER_MAP,
    "standing in front of the Seer")
  U.shot(game, "/tmp/pokeport-shots/crystal_seer_bug1929.png")
  say("press A: slot 1 must read NEW BARK TOWN, slot 2 and 3 "
    .. "\"Whaaaat? I can't tell a thing!\"")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
