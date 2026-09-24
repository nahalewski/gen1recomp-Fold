-- engine/pokegear/pokegear.asm:2285 (#1891)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gold_dex_area_bug1891_test.lua \
--     POKEPORT_SHOT_DIR=/tmp/gold-dex-area love .
-- No POKEPORT_SPEED: the markers blink on a frame counter.
local U = require("tests.drivers.util")

local HallOfFame = require("src.core.gen2.HallOfFame")
local Nests = require("src.core.gen2.Nests")
local PokedexMenu = require("src.ui.gen2.PokedexMenu")

local SPECIES = "MILTANK"

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-dex-area"
  local failed = 0

  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  local function shot(name)
    U.wait(4)
    U.shot(game, ("%s/%s.png"):format(out, name))
  end

  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")
  local save = game.save

  save.pokedex = save.pokedex or {}
  save.pokedex.seen = save.pokedex.seen or {}
  save.pokedex.caught = save.pokedex.caught or {}
  save.pokedex.seen[SPECIES] = true
  save.pokedex.caught[SPECIES] = true

  local johto = Nests.find(game.data, SPECIES, "johto", save)
  local kanto = Nests.find(game.data, SPECIES, "kanto", save)
  pass(#johto == 2, ("%s has %d Johto nests; the cart's FindNest answers 2 " ..
    "(Routes 38 and 39)"):format(SPECIES, #johto))
  pass(#kanto == 0, ("and %d in Kanto, where it answers none"):format(#kanto))

  local gear = game.data and game.data.gen2MenuGfx and game.data.gen2MenuGfx.pokegear
  pass(gear ~= nil and gear.maps ~= nil, "this cache carries the town maps")
  pass(gear ~= nil and gear.nestIcon ~= nil,
    "and PokedexNestIconGFX; without it the markers fall back to a plain " ..
    "square and the cache wants a re-import")

  local dex = PokedexMenu.new(game, {})
  for i, row in ipairs(dex.rows) do
    if row.species == SPECIES then dex.index = i break end
  end
  dex:ensureVisible()
  dex.view = "area"
  dex.areaRegion = nil
  game.stack:push(dex)
  U.wait(10)

  pass(dex:areaRegionName() == "johto",
    "the page opens on Johto, whatever region the player is standing in")

  dex.areaBlink = 0
  U.log("00-johto-on: the Johto map, edge to edge, with no red or orange")
  U.log("anywhere. row 0 is a black strip reading \"MILTANK'S NEST\" in pale")
  U.log("letters from the third column, row 1 the map's own rule. two markers")
  U.log("blink over Routes 38 and 39, west of the middle. the word JOHTO is")
  U.log("only the one baked into the map at the bottom right; no landmark")
  U.log("name, no \"+1\", no second JOHTO up top.")
  shot("00-johto-on")

  dex.areaBlink = 16
  U.log("01-johto-off: the same screen with both markers gone. sixteen frames")
  U.log("on, sixteen off.")
  shot("01-johto-off")

  dex.areaBlink = 0
  dex:updateArea({ wasPressed = function(_, b) return b == "right" end })
  pass(dex:areaRegionName() == "johto" or HallOfFame.hasEntered(save),
    "right is refused until the Hall of Fame bit is set")

  HallOfFame.record(save).count = math.max(1, HallOfFame.count(save))
  dex:updateArea({ wasPressed = function(_, b) return b == "right" end })
  dex.areaBlink = 0
  pass(dex:areaRegionName() == "kanto", "and taken once it is")
  U.log("02-kanto: the Kanto map with nothing blinking on it and the same")
  U.log("pale-on-black caption on top. no \"AREA UNKNOWN\" printed over the")
  U.log("baked-in KANTO at the bottom left.")
  shot("02-kanto")

  U.log(("%d check(s) failed"):format(failed))

  while true do coroutine.yield() end
end
