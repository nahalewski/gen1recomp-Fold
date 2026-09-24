-- ../pokecrystal/engine/battle/start_battle.asm:60-66
local U = require("tests.drivers.util")

local GameVersion = require("src.core.GameVersion")
local Mon = require("src.battle.gen2.Mon")
local Music = require("src.core.Music")
local Roamers = require("src.core.gen2.Roamers")

-- ../pokecrystal/constants/battle_constants.asm:103
local BATTLETYPE_SUICUNE = 12

return function(game)
  local fails = 0
  local function say(line) print("[1928] " .. line) end
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

  local save = game.save
  save.party = { Mon.new(game.data, "CYNDAQUIL", 30) }
  ok(save.party[1] ~= nil, "the cache built the player's mon")
  world:warpToMapId("ROUTE_29", 20, 8, "down")
  U.wait(30)

  -- ../pokecrystal/engine/overworld/wildmons.asm:493
  Roamers.init(save, { data = game.data, encounters = world.encounters })
  local beast = Roamers.beginBattle(save, 1, game.data)
  ok(beast ~= nil, "slot 1 handed over a beast ("
    .. tostring(beast and beast.species) .. ")")

  local function popBattle()
    for _ = 1, 240 do
      local top = game.stack:top()
      if top and top.battle then
        game.stack:pop()
        U.wait(2)
        return
      end
      U.wait(1)
    end
  end

  local crystal = GameVersion.engine(save.version or GameVersion.get())
    == "crystal"
  local function wildTheme(song)
    return song == "Music_JohtoWildBattle"
      or song == "Music_JohtoWildBattleNight"
  end
  local function beastTheme(song)
    if crystal then return song == "Music_SuicuneBattle" end
    return wildTheme(song)
  end
  local want = crystal and "Suicune's theme" or "the ordinary wild theme"

  local wild = Mon.new(game.data, "RATTATA", 4)
  world:startBattle({ wild = wild })
  U.wait(5)
  ok(wildTheme(Music.current()),
    "an ordinary Route 29 wild battle keeps the Johto theme (got "
      .. tostring(Music.current()) .. ")")
  popBattle()

  world:startBattle({ wild = beast, roaming = 1 })
  U.wait(5)
  ok(beastTheme(Music.current()),
    "a roaming beast fights to " .. want .. " (got "
      .. tostring(Music.current()) .. ")")
  popBattle()

  local scripted = Mon.new(game.data, "SUICUNE", 40)
  world:startBattle({ wild = scripted, battleType = BATTLETYPE_SUICUNE })
  U.wait(5)
  ok(beastTheme(Music.current()),
    "and a BATTLETYPE_SUICUNE battle plays " .. want .. " (got "
      .. tostring(Music.current()) .. ")")
  popBattle()

  say(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  love.event.quit(fails == 0 and 0 or 1)
end
