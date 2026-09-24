local U = require("tests.drivers.util")

-- ../pokecrystal/maps/GoldenrodCity.asm:34
local NAMES = {
  "ENGINE_DAILY_MOVE_TUTOR",
  "ENGINE_BUENAS_PASSWORD",
  "ENGINE_INDIGO_PLATEAU_RIVAL_FIGHT",
  "ENGINE_KURT_MAKING_BALLS",
  "ENGINE_ALL_FRUIT_TREES",
}

return function(game)
  local fails = 0
  local function say(line) print("[1963] " .. line) end
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    say((cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(60)
  local world, save = game.world, game.save
  if not (world and world.map and save) then
    say("FAIL the crystal world did not boot")
    love.event.quit(1)
    return
  end

  world:warpToMapId("GOLDENROD_CITY", 17, 10, "down")
  U.wait(30)
  ok(world.map and world.map.def and world.map.def.id == "GOLDENROD_CITY",
    "standing outside the Game Corner")

  save.engineFlags = save.engineFlags or {}
  local ids = {}
  for _, name in ipairs(NAMES) do
    local id = world:engineFlagId(name, nil)
    ids[name] = id
    say(name .. " = " .. tostring(id))
    if id then save.engineFlags[id] = true end
  end
  ok(ids.ENGINE_DAILY_MOVE_TUTOR == 94,
    "ENGINE_DAILY_MOVE_TUTOR resolves to Crystal's 94 (got "
      .. tostring(ids.ENGINE_DAILY_MOVE_TUTOR) .. ")")

  save.dailyReset = { remaining = 0, day = save.dailyReset
    and save.dailyReset.day or 0 }
  world:checkTimeEvents()
  U.wait(5)

  for _, name in ipairs(NAMES) do
    local id = ids[name]
    ok(id == nil or save.engineFlags[id] == nil,
      name .. " is clear after the rollover")
  end

  U.shot(game, (os.getenv("POKEPORT_SHOT_DIR") or "/tmp/pokeport-shots")
    .. "/crystal_move_tutor_bug1963.png")
  say("on a Wednesday or Saturday after the Elite Four the tutor "
    .. "must be standing here again")
  say(fails == 0 and "all claims passed" or (fails .. " claims failed"))
  love.event.quit(fails == 0 and 0 or 1)
end
