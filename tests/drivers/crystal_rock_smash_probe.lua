local U = require("tests.drivers.util")

local GameVersion = require("src.core.GameVersion")
local Mon = require("src.battle.gen2.Mon")

-- data/wild/treemon_maps.asm RockMonMaps
local ROCK_MAP = "DARK_CAVE_VIOLET_ENTRANCE"
local STAND_X, STAND_Y = 15, 14

-- constants/pokemon_constants.asm; TreeMonSet_Rock is 90 KRABBY / 10 SHUCKLE.
local ROCK_SPECIES = { [98] = "KRABBY", [213] = "SHUCKLE" }

return function(game)
  local fails = 0

  local function say(line) print("[rocksmash] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end
  local function tap(button, frames)
    game.input.pressQueue[#game.input.pressQueue + 1] = button
    game.input.state[button] = true
    U.wait(2)
    game.input.state[button] = false
    U.wait(frames or 4)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end
  ok(GameVersion.engine() == "crystal",
    "engine lineage is crystal (got " .. tostring(GameVersion.engine()) .. ")")
  ok(world:tempWildMonSpeciesAddress() == 0xd22e,
    "the readmem seam claims 01:d22e")

  world:setMap(ROCK_MAP, STAND_X, STAND_Y, "right")
  U.wait(60)
  ok(world.map and world.map.def and world.map.def.id == ROCK_MAP,
    "arrived at " .. ROCK_MAP)

  local save = game.save
  save.party = save.party or {}
  if not save.party[1] then
    save.party[1] = Mon.new(game.data, "GEODUDE", 20)
  end
  local lead = save.party[1]
  lead.moves = lead.moves or {}
  lead.moves[#lead.moves + 1] = { id = "ROCK_SMASH", pp = 15, maxPp = 15 }
  ok(lead ~= nil, "the lead can be taught ROCK SMASH")

  world.rockmonRandom = function() return 0 end
  world.noWildEncounters = true

  local fought
  local realScripted = world.startScriptedBattle
  world.startScriptedBattle = function(self, record, wild, onDone)
    if wild and wild.species then fought = wild.species end
    return realScripted(self, record, wild, onDone)
  end

  for _ = 1, 60 do
    if fought then break end
    tap("a", 8)
  end

  ok(fought ~= nil, "the smash reached startbattle at all")
  ok(fought ~= nil and ROCK_SPECIES[fought] ~= nil,
    "and the wild mon came out of TREEMON_SET_ROCK (got "
      .. tostring(fought and (ROCK_SPECIES[fought] or fought)) .. ")")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
