--   POKEPORT_VERSION=crystal POKEPORT_IDENTITY=crystal-aug29b POKEPORT_TOUCH=0 \
--     POKEPORT_SHOT_DIR=/tmp/gen2-intro \
--     POKEPORT_DRIVER=tests/drivers/gen2_battle_intro_shots.lua love .
-- ../pokecrystal/engine/battle/core.asm:8063
-- engine/battle/core.asm:8733
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local Trainers = require("src.world.gen2.Trainers")

local OUT = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-intro"

local function rowState(screen)
  local rows = screen.ballRows or {}
  return ("slideFrame=%s gray=%s player=%s enemy=%s"):format(
    tostring(screen.slideFrame), tostring(screen:introGrayscale()),
    tostring(rows.player), tostring(rows.enemy))
end

local function seedParty(game)
  local party = {}
  for i = 1, 4 do party[i] = Mon.new(game.data, "CYNDAQUIL", 18 + i) end
  party[3].status = "poison"
  party[4].hp = 0
  return party
end

local function openBattle(game, opts)
  assert(game.world:startBattle(opts), "startBattle failed")
  for _ = 1, 900 do
    local top = game.stack:top()
    if top and top.battle then return top end
    U.wait(1)
  end
  error("battle screen never came up")
end

local function shootIntro(game, screen, tag)
  for i = 0, 6 do
    U.shot(game, ("%s/%s-slide-%d.png"):format(OUT, tag, i))
    U.log(("[driver] %s slide %d: %s"):format(tag, i, rowState(screen)))
    U.wait(10)
  end
  for _ = 1, 300 do
    if screen.message then break end
    U.wait(1)
  end
  U.wait(4)
  U.shot(game, ("%s/%s-startline.png"):format(OUT, tag))
  U.log(("[driver] %s start line %q: %s"):format(tag,
    tostring(screen.message), rowState(screen)))
end

local function drainBattle(game)
  for _ = 1, 900 do
    if not (game.stack:top() or {}).battle then return end
    U.tap(game, "a")
  end
end

return function(game)
  U.wait(45)
  assert(game.world and game.world.map, "gen2 world did not boot")
  game.save.inventory = {}

  game.save.party = seedParty(game)
  local screen = openBattle(game, { wild = Mon.new(game.data, "PIDGEY", 5) })
  shootIntro(game, screen, "wild")
  drainBattle(game)

  local entry = game.world:trainerParty(36, 1)
  if entry then
    entry.party = Trainers.party(game.data, entry)
    game.save.party = seedParty(game)
    screen = openBattle(game, { trainer = entry })
    shootIntro(game, screen, "trainer")
  else
    U.log("[driver] no trainer 36/1 in this cache; wild shots only")
  end

  U.log("[driver] shots in " .. OUT .. " -- the battle is yours")
end
