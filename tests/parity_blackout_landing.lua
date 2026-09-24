-- engine/events/black_out.asm:39-43, engine/overworld/special_warps.asm:71-129
-- data/maps/special_warps.asm:64-91, home/overworld.asm:23-30 (#96)
-- Self-contained; run via `luajit tests/parity_blackout_landing.lua`.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end
local Data = require("src.core.Data")
if not (Data.maps and Data.maps.PALLET_TOWN) then Data:load() end
local S = require("tests.harness").suite("parity blackout landing #2077")
local check, eq = S.check, S.eq

require("src.render.Font").load(Data)
local Game          = require("src.core.Game")
local Input         = require("src.core.Input")
local StateStack    = require("src.core.StateStack")
local Renderer      = require("src.render.Renderer")
local SaveData      = require("src.core.SaveData")
local Pokemon       = require("src.pokemon.Pokemon")
local Map           = require("src.world.Map")
local FieldDefaults = require("src.world.FieldDefaults")
local OW            = require("src.world.OverworldController")

Game.data = Data
Game.input = Input; Input:init()
Game.renderer = Renderer; Renderer:init()
Game.stack = StateStack; StateStack:init()
Game.save = SaveData.newGame()
Game.save.party = { Pokemon.new(Data, "SQUIRTLE", 20) }

Game.stack:push(OW, "ROUTE_1", 10, 6, "down")
local ow = Game.stack:top()
Game.overworld = ow

local dest, arrive
local realStart = ow.startWarpTo
ow.startWarpTo = function(self, mapId, x, y, facing, onDone, opts)
  dest = { map = mapId, x = x, y = y }
  arrive = self.arriveWarp
  self.arriveWarp = nil
  self.transitioning = false
end

local outsideTilesets = FieldDefaults.field(Data, "outsideTilesets")
local function isOutside(mapId)
  local def = Data.maps[mapId]
  return def ~= nil and Map.isOutside(def, outsideTilesets)
end

local flyWarps = Data.field.flyWarps or {}
local bootHeal = SaveData.defaultHeal(Data.field.boot)

Game.save.lastHeal = { map = "VIRIDIAN_POKECENTER", x = 3, y = 3,
                       outdoor = { id = "VIRIDIAN_CITY", x = 23, y = 27 } }
ow:rememberOutdoor("ROUTE_2", 9, 60)
dest, arrive = nil, nil
ow:warpToHealPoint()

check(flyWarps.VIRIDIAN_CITY ~= nil, "Viridian City has a fly warp cell")
check(not isOutside("VIRIDIAN_POKECENTER"), "the Pokecenter is not outside")
eq(dest.map, "VIRIDIAN_CITY", "a blackout lands in the town, not the Center")
eq(dest.x, flyWarps.VIRIDIAN_CITY.x, "blackout lands on the FlyWarpDataPtr x")
eq(dest.y, flyWarps.VIRIDIAN_CITY.y, "blackout lands on the FlyWarpDataPtr y")
eq(arrive, nil, "a blackout still arrives without EnterMapAnim (#96)")
eq(Game.save.lastOutdoor.id, "VIRIDIAN_CITY",
   "PrepareForSpecialWarp re-points wLastMap at the landing town")
eq(Game.save.lastOutdoor.x, dest.x, "wLastMap x follows the landing cell")
eq(Game.save.lastOutdoor.y, dest.y, "wLastMap y follows the landing cell")

local bm, bx, by = ow:escapeWarpTarget()
dest, arrive = nil, nil
ow:warpToHealPoint(nil, { arrive = "teleport" })
eq(dest.map, bm, "ESCAPE ROPE and blackout share the destination map")
eq(dest.x, bx, "ESCAPE ROPE and blackout share the landing x")
eq(dest.y, by, "ESCAPE ROPE and blackout share the landing y")
eq(arrive, "teleport", "only the rope keeps the arrival spin")

Game.save.lastHeal = nil
ow:rememberOutdoor("ROUTE_2", 9, 60)
dest = nil
ow:warpToHealPoint()

eq(dest.map, bootHeal.map, "a never-healed save blacks out to the boot town")
eq(dest.x, bootHeal.x, "boot town keeps its landing x")
eq(dest.y, bootHeal.y, "boot town keeps its landing y")
check(isOutside(dest.map), "the boot blackout town is an outside map")

Game.save.lastHeal = { map = "SEAFOAM_ISLANDS_B2F", x = 5, y = 5 }
ow:rememberOutdoor("ROUTE_20", 5, 10)
dest = nil
ow:warpToHealPoint()

check(not isOutside("SEAFOAM_ISLANDS_B2F"), "Seafoam B2F is not outside")
check(flyWarps.SEAFOAM_ISLANDS_B2F ~= nil,
      "Seafoam B2F does have a warp cell (DungeonWarpData), so the outdoor "
      .. "check is what rejects it")
eq(dest.map, bootHeal.map, "an unusable heal record falls back to the boot town")
check(isOutside(dest.map), "a blackout destination is always an outside map")
eq(Game.save.lastOutdoor.id, bootHeal.map,
   "the fallback landing is remembered as wLastMap too")

Game.stack:push(OW, "SEAFOAM_ISLANDS_B2F", 5, 5, "down")
local cave = Game.stack:top()
Game.overworld = cave
cave.startWarpTo = ow.startWarpTo
Game.save.lastHeal = { map = "VIRIDIAN_POKECENTER", x = 3, y = 3,
                       outdoor = { id = "VIRIDIAN_CITY", x = 23, y = 27 } }
cave:rememberOutdoor("ROUTE_20", 5, 10)
dest = nil
cave:warpToHealPoint(nil, { arrive = "teleport" })

eq(dest.map, "VIRIDIAN_CITY", "the rope still leaves the cave for the town")
eq(dest.x, flyWarps.VIRIDIAN_CITY.x, "the rope lands on the fly-warp cell")
eq(Game.save.lastOutdoor.id, "VIRIDIAN_CITY",
   "the rope re-points wLastMap away from the cave mouth (#805)")

dest = nil
cave:warpToHealPoint()
eq(dest.map, "VIRIDIAN_CITY", "blacking out in a cave lands in the town too")

Game.save.lastHeal = { map = "INDIGO_PLATEAU_LOBBY", x = 8, y = 6,
                       outdoor = { id = "INDIGO_PLATEAU", x = 9, y = 7 } }
cave:rememberOutdoor("ROUTE_23", 8, 60)
dest = nil
cave:warpToHealPoint()

eq(dest.map, "INDIGO_PLATEAU", "the Elite Four blackout lands on the Plateau")
eq(dest.x, flyWarps.INDIGO_PLATEAU.x, "Plateau landing x is the fly-warp cell")
eq(dest.y, flyWarps.INDIGO_PLATEAU.y, "Plateau landing y is the fly-warp cell")
check(isOutside(dest.map), "the Plateau counts as an outside map")

cave.startWarpTo = realStart
ow.startWarpTo = realStart
S.finish()
