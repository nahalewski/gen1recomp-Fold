-- engine/tilesets/tileset_palettes.asm:1 (#1924)
local U = require("tests.drivers.util")

local Palettes = require("src.world.gen2.Palettes")

local GLASS = {
  { 247, 230, 214 }, { 255, 156, 197 }, { 132, 107, 25 }, { 58, 58, 58 },
}

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-house"
  local failed = 0

  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  assert(game.world and game.world.map, "crystal world did not boot")

  -- data/maps/blocks.asm:199 -- House1.blk, whose bottom row is blocks 6 and 7
  game.world:warpToMapId("CHERRYGROVE_GYM_SPEECH_HOUSE", 3, 6, "up")
  U.wait(20)

  local world = game.world
  local def = world.map and world.map.def
  pass(def ~= nil and def.tileset == "TILESET_HOUSE",
    "the map loaded on TILESET_HOUSE")

  local special = Palettes.specialSet(world.palettes, def)
  pass(special ~= nil,
    "LoadSpecialMapPalette answers for it; nil means the cache predates " ..
    "specialTilesets and wants a re-import")

  local set = Palettes.bgSet(world.palettes, def, world.daytime or "DAY")
  local roof = set and set[world.palettes and world.palettes.roofSlot or 7]
  for i, want in ipairs(GLASS) do
    local got = roof and roof[i]
    pass(got ~= nil and got[1] == want[1] and got[2] == want[2]
      and got[3] == want[3],
      ("PAL_BG_ROOF colour %d is %d,%d,%d (got %s)"):format(
        i - 1, want[1], want[2], want[3],
        got and ("%d,%d,%d"):format(got[1], got[2], got[3]) or "nothing"))
  end

  U.log("00-house: a Cherrygrove house interior. the potted plants in the")
  U.log("bottom-left and bottom-right corners sit in BROWN pots, not blue")
  U.log("ones, and the floor around them is the same pink as the room.")
  U.wait(4)
  U.shot(game, out .. "/00-house.png")

  U.log(("%d check(s) failed"):format(failed))

  while true do coroutine.yield() end
end
