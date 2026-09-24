-- engine/items/town_map.asm:74 (#1868)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local TownMap = require("src.ui.TownMap")

local LOCATIONS = {
  PALLET_TOWN = { x = 4, y = 12, name = "PALLET TOWN" },
  ROUTE_1 = { x = 4, y = 9, name = "ROUTE 1" },
  VIRIDIAN_CITY = { x = 4, y = 11, name = "VIRIDIAN CITY" },
  SEA_COTTAGE = { x = 12, y = 0, name = "SEA COTTAGE" },
}
local ORDER = { "PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY" }

local function newGame()
  local pressed = {}
  local game = {
    data = {
      field = {
        townMap = { locations = LOCATIONS, cursorOrder = ORDER },
        playerSprites = { walk = "SPRITE_RED" },
      },
      sprites = {},
      maps = {},
    },
    save = {},
    overworld = { map = { id = "PALLET_TOWN" } },
    input = { wasPressed = function(_, name)
      local p = pressed[name]
      pressed[name] = nil
      return p
    end },
    stack = { pop = function() end },
  }
  return game, function(name) pressed[name] = true end
end

local game, tap = newGame()
local tm = TownMap.new(game, {})

eq(tm.mode, "grid", "located entries put the screen in grid mode")
eq(tm.locs[tm.sel].name, "PALLET TOWN",
   "the viewer opens on the player's town")

local reachable = {}
for _, loc in ipairs(tm.locs) do reachable[loc.name] = true end
check(not reachable["SEA COTTAGE"],
      "a location outside cursorOrder is not a cursor stop")

tap("left") tm:update(0)
eq(tm.locs[tm.sel].name, "PALLET TOWN", "LEFT does not move the cursor")
tap("right") tm:update(0)
eq(tm.locs[tm.sel].name, "PALLET TOWN", "RIGHT does not move the cursor")

tap("up") tm:update(0)
eq(tm.locs[tm.sel].name, "ROUTE 1",
   "UP steps forward through TownMapOrder, not to the nearest square")
tap("up") tm:update(0)
eq(tm.locs[tm.sel].name, "VIRIDIAN CITY", "UP again reaches VIRIDIAN CITY")
tap("down") tm:update(0)
eq(tm.locs[tm.sel].name, "ROUTE 1", "DOWN steps back")
tap("down") tm:update(0)
eq(tm.locs[tm.sel].name, "PALLET TOWN", "DOWN again returns to PALLET TOWN")
tap("down") tm:update(0)
eq(tm.locs[tm.sel].name, "VIRIDIAN CITY",
   "DOWN off the top wraps to the last TownMapOrder entry")

local game2, tap2 = newGame()
game2.data.field.townMap.cursorOrder = nil
local tm2 = TownMap.new(game2, {})
eq(tm2.mode, "grid", "the screen still works without cursorOrder")
local before = tm2.locs[tm2.sel]
tap2("left") tm2:update(0)
tap2("right") tm2:update(0)
check(tm2.locs[tm2.sel] == before,
      "LEFT/RIGHT stay inert on the cursorOrder-less fallback")
tap2("up") tm2:update(0)
check(tm2.locs[tm2.sel] ~= before, "UP still moves on the fallback")

local game3 = newGame()
game3.overworld.map.id = "SEA_COTTAGE"
local tm3 = TownMap.new(game3, {})
eq(tm3.locs[tm3.sel].name, "SEA COTTAGE",
   "the viewer still opens on a map that is not a TownMapOrder stop")

T.finish("town map cursor bug 1868")
