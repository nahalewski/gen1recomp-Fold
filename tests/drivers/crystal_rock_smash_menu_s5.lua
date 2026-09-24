-- ../pokecrystal/engine/events/overworld.asm:1317 TryRockSmashFromMenu
--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal \
--     POKEPORT_DRIVER=tests/drivers/crystal_rock_smash_menu_s5.lua \
--     POKEPORT_SHOT_DIR=/tmp/shots love .

local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local PartyMenu = require("src.ui.gen2.PartyMenu")

-- data/wild/treemon_maps.asm RockMonMaps
local ROCK_MAP = "DARK_CAVE_VIOLET_ENTRANCE"
local ROCK_X, ROCK_Y = 16, 14
local STAND_X, STAND_Y = 15, 14
local ROCK_SPECIES = { [98] = "KRABBY", [213] = "SHUCKLE" }

return function(game)
  local DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
    or "/tmp/shots"
  local fails = 0
  local function say(line) print("[rocksmashmenu] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world = game.world
  if not (world and world.map) then
    say("FAIL the world did not boot")
    love.event.quit(1)
    return
  end

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

  world.rockmonRandom = function() return 0 end
  world.noWildEncounters = true

  local fought
  local realScripted = world.startScriptedBattle
  world.startScriptedBattle = function(self, record, wild, onDone)
    if wild and wild.species then fought = wild.species end
    return realScripted(self, record, wild, onDone)
  end

  local rock
  for _, e in ipairs(world.entities or {}) do
    if e.cellX == ROCK_X and e.cellY == ROCK_Y then rock = e end
  end
  ok(rock ~= nil and rock.def ~= nil and rock.def.movement == 0x18,
    "the object faced is SPRITEMOVEDATA_SMASHABLE_ROCK")
  U.shot(game, DIR .. "/rocksmash_menu_before.png")

  local menu = PartyMenu.new(game, { save = save, submenu = true })
  menu:useFieldMove("ROCK_SMASH", lead)
  ok(world.queuedScript ~= nil, "the menu queued RockSmashFromMenuScript")
  ok(world.vm and world.vm.lastTalked == (rock and rock.def.index or -1) + 1,
    "with hLastTalked pointing at the rock")

  U.wait(90)
  U.shot(game, DIR .. "/rocksmash_menu_used.png")
  for _ = 1, 60 do
    if fought then break end
    U.tap(game, "a")
    U.wait(15)
  end
  U.shot(game, DIR .. "/rocksmash_menu_after.png")
  ok(fought ~= nil, "the queued script reached startbattle with no yes/no")
  ok(fought ~= nil and ROCK_SPECIES[fought] ~= nil,
    "and the wild mon came out of TREEMON_SET_ROCK (got "
      .. tostring(fought and (ROCK_SPECIES[fought] or fought)) .. ")")

  local gone = true
  for _, e in ipairs(world.entities or {}) do
    if e == rock and not e.hidden then gone = false end
  end
  ok(gone, "disappear LAST_TALKED took the rock away")

  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
