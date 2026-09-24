-- Manual check that Hideout B4F's Rocket3 engages on sight (#1814).
-- RocketHideout4TrainerHeader2 is `trainer EVENT_..., 1, ...`
-- (scripts/RocketHideoutB4F.asm:95-96), so CheckSpriteCanSeePlayer engages him
-- from the tile below.  The LIFT KEY half (his after-battle talk still reveals
-- the ball) is asserted in tests/parity_rocket3_sight_bug1814.lua.
--   POKEPORT_DRIVER=tests/drivers/rocket3_sight_bug1814_test.lua POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  -- pokered data/maps/objects/RocketHideoutB4F.asm: ROCKET3 stands at (11,2)
  -- facing DOWN, so the sight tile is the one below him
  local MAP = "ROCKET_HIDEOUT_B4F"
  local TEXT = "TEXT_ROCKETHIDEOUTB4F_ROCKET3"

  local function rocketIn(ow)
    for _, n in ipairs(ow.npcs or {}) do
      if n.def and n.def.text == TEXT then return n end
    end
  end

  -- a party that can take a hit, so the battle the sight starts is playable
  if #(game.save.party or {}) == 0 then
    local Pokemon = require("src.pokemon.Pokemon")
    game.save.party = { Pokemon.new(game.data, "NIDOKING", 45) }
  end

  U.teleport(game, MAP, 13, 3, "left")
  U.wait(10)
  local ow = game.overworld
  local rocket = rocketIn(ow)
  check("Rocket3 is on the map", rocket ~= nil)
  if rocket then
    U.log(("Rocket3 at (%d, %d) facing %s")
            :format(rocket.cellX, rocket.cellY, tostring(rocket.facing)))
  end

  local header = rocket
    and game.data:trainerHeader(ow.map.def.label, rocket.def.index)
  check("his extracted view range is 1 tile", header and header.range == 1)

  -- walk north into his line of sight; a map edit that moved him is a
  -- different failure than a sight check that never fires, so aim at the
  -- cell below wherever he actually stands
  local target = rocket and { rocket.cellX, rocket.cellY + 1 } or { 11, 3 }
  local steps = 0
  for _ = 1, 8 do
    local p = game.overworld.player
    if (p.cellX == target[1] and p.cellY == target[2])
       or game.overworld.engaging then break end
    if p.cellX > target[1] then U.hold(game, "left", 16)
    elseif p.cellX < target[1] then U.hold(game, "right", 16)
    elseif p.cellY > target[2] then U.hold(game, "up", 16)
    else U.hold(game, "down", 16) end
    steps = steps + 1
    U.wait(4)
  end
  U.log("walked", steps, "steps toward", target[1], target[2])

  local sighted = false
  for _ = 1, 90 do
    ow = game.overworld
    if ow.engaging or ow.emote then sighted = true break end
    U.wait(1)
  end
  check("stepping into his line of sight engages him", sighted)
  if game.overworld.emote then
    U.shot(game, SHOT_DIR .. "/bug1814_sighted.png")
    U.log("captured", SHOT_DIR .. "/bug1814_sighted.png")
  end

  local BattleState = require("src.battle.BattleState")
  -- his line prints first and holds on a button wait (home/text_script.asm:96)
  local fought = false
  for _ = 1, 60 do
    if getmetatable(game.stack:top()) == BattleState then fought = true break end
    U.tap(game, "a")
    U.wait(8)
  end
  check("the walk-up runs into the battle", fought)
  if fought then
    U.wait(60)
    U.shot(game, SHOT_DIR .. "/bug1814_battle.png")
    U.log("captured", SHOT_DIR .. "/bug1814_battle.png")
  end

  U.log("Right: the grunt notices the player one tile below him, the bubble")
  U.log("pops, he marches down and the fight starts on its own.  The near-miss")
  U.log("is nothing happening until the player presses A at him, which is the")
  U.log("bug.  After winning, talk to him again: he drops the LIFT KEY ball.")

  while true do
    coroutine.yield()
  end
end
