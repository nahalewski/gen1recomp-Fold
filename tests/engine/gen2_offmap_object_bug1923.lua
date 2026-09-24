-- InitializeVisibleSprites (engine/overworld/player_object.asm:223)
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local World = require("src.world.gen2.World")

local MAP_ID = "GOLDENROD_POKECENTER_1F"

local function pokecenter()
  local def = {
    id = MAP_ID, group = 24, map = 1, width = 5, height = 4,
    blocks = {}, warps = {}, connections = {},
    objects = {
      { index = 1, x = 3, y = 1, sprite = "SPRITE_NURSE" },
      { index = 2, x = 16, y = 8, sprite = "SPRITE_LINK_RECEPTIONIST" },
      { index = 3, x = 6, y = 1, sprite = "SPRITE_GAMEBOY_KID" },
    },
  }
  local world = World.new({ data = {}, save = { player = {} } })
  world.maps = { [MAP_ID] = def }
  world.map = { id = MAP_ID, def = def, widthCells = 10, heightCells = 8 }
  world.neighbors = {}
  world.player = { cellX = 4, cellY = 6 }
  world.pooledNpc = function(_, ownerMap, obj)
    return { def = obj, id = ownerMap .. ":" .. tostring(obj.index) }
  end
  return world, def
end

local function sprites(world)
  local names = {}
  for _, npc in ipairs(world.npcs) do names[#names + 1] = npc.def.sprite end
  return table.concat(names, ",")
end

do
  local world = pokecenter()
  world:rebuildPeople()
  eq(#world.npcs, 2, "the two in-bounds objects spawn")
  eq(sprites(world), "SPRITE_NURSE,SPRITE_GAMEBOY_KID",
    "and the off-grid receptionist is not among them")
end

do
  local world = pokecenter()
  local off = { x = 16, y = 8 }
  world.player = { cellX = 9, cellY = 7 }
  check(not world:objectSpawnable(off),
    "delta 7 is the first x the cart's window excludes")
  world.player = { cellX = 10, cellY = 7 }
  check(world:objectSpawnable(off), "delta 6 is inside it")
  world.player = { cellX = 10, cellY = 2 }
  check(not world:objectSpawnable(off), "and delta 6 in y is the first y out")
  world.player = { cellX = 10, cellY = 3 }
  check(world:objectSpawnable(off), "delta 5 in y is inside")
  check(world:objectSpawnable({ x = 3, y = 1 }),
    "an in-bounds object never consults the window at all")
end

-- maps/GoldenrodPokecenter1F.asm:26 `moveobject ..., 0, 7` then `appear`:
do
  local world, def = pokecenter()
  world:rebuildPeople()
  eq(#world.npcs, 2, "she starts off the map")
  world:moveObject(3, 0, 7)
  world:appearObject(3)
  eq(#world.npcs, 3, "moveobject + appear puts her in the room")
  check(sprites(world):find("SPRITE_LINK_RECEPTIONIST") ~= nil,
    "and it is the receptionist that arrived")

  local stash = world.objectSpawns and world.objectSpawns[MAP_ID]
    and world.objectSpawns[MAP_ID][2]
  eq(stash and stash[1], 16, "the header cell is stashed for the reload")
  eq(stash and stash[2], 8, "both halves of it")
  def.objects[2].x, def.objects[2].y = stash[1], stash[2]
  world:rebuildPeople()
  eq(#world.npcs, 2, "and a reload hides her again")
end

T.finish("gen2 off-map object bug1923")
