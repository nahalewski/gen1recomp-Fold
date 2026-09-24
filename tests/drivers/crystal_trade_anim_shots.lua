--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal \
--   POKEPORT_DRIVER=tests/drivers/crystal_trade_anim_shots.lua \
--   POKEPORT_SHOT_DIR=/tmp/crystal-trade love .
-- ../pokecrystal/engine/movie/trade_animation.asm:64-65, :772-800
-- ../pokecrystal/engine/gfx/pic_animation.asm:72
local U = require("tests.drivers.util")

local Anim = require("src.core.gen2.TradeAnim")
local Mon = require("src.battle.gen2.Mon")
local Screens = require("src.ui.Screens")

local FRAME_LIMIT = 900

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-trade"
  local give = os.getenv("POKEPORT_TRADE_GIVE") or "ABRA"
  local get = os.getenv("POKEPORT_TRADE_GET") or "MACHOP"
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[tradeanim] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  assert(game.world and game.world.map, "crystal world did not boot")

  local given = Mon.new(game.data, give, 12)
  local received = Mon.new(game.data, get, 12)
  ok(game.data.pokemon[get] and game.data.pokemon[get].anim ~= nil,
    get .. " has an anim row in this cache")

  local done = false
  Screens.push(game, "Gen2TradeAnim", {
    row = { otName = "MIKE", otId = 1234, get = get },
    given = given, received = received, save = game.save,
    eventTables = game.data.events,
    onDone = function() done = true end,
  })
  local screen = game.stack:top()
  assert(screen and screen.beat, "the trade screen did not open")

  -- ../pokecrystal/engine/movie/trade_animation.asm:61-63
  screen.frame = Anim.startOf("getmon_poof") - 1

  local shots, animSteps, beatWhileAnim = 0, 0, {}
  local sawAnim = false
  for _ = 1, FRAME_LIMIT do
    if done then break end
    if screen.picAnim then
      sawAnim = true
      animSteps = animSteps + 1
      beatWhileAnim[screen.beat and screen.beat.id or "?"] = true
      if animSteps % 3 == 1 then
        shots = shots + 1
        U.shot(game, ("%s/anim-%03d.png"):format(out, shots))
      else
        U.wait(1)
      end
    else
      local id = screen.beat and screen.beat.id or "?"
      U.shot(game, ("%s/beat-%s-%04d.png"):format(out, id, screen.frame))
      U.wait(3)
    end
  end

  ok(sawAnim, "AnimateFrontpic ran at getmon_hold")
  ok(animSteps > 1, "and for more than one iteration (" .. animSteps .. ")")
  local ids = {}
  for id in pairs(beatWhileAnim) do ids[#ids + 1] = id end
  ok(#ids == 1 and ids[1] == "getmon_hold",
    "the script is held while the scene runs (" .. table.concat(ids, ",")
      .. ")")
  ok(done, "and the animation still reaches its end")

  print("[tradeanim] shots in " .. out)
  print("[tradeanim] " .. (fails == 0 and "all claims passed"
    or (fails .. " claims failed")))
  love.event.quit(fails == 0 and 0 or 1)
end
