-- CanObjectMoveInDirection (engine/overworld/npc_movement.asm:1

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local Permissions = require("src.world.gen2.Permissions")
local Map = require("src.world.gen2.Map")
local World = require("src.world.gen2.World")
local Runtime = require("src.mods.Runtime")

local FLOOR = 0x00
local UP_WALL = 0xb2
local RIGHT_WALL = 0xb0
local UP_BUOY = 0xc2
local WALL = 0x07

local function permitted(from, to, dir)
  return Permissions.objectStepPermitted(from, to, dir) == true
end

do
  check(not permitted(FLOOR, UP_WALL, "down"), "DOWN onto an UP_WALL is refused")
  check(permitted(FLOOR, UP_WALL, "up"), "UP onto one is not")
  check(permitted(FLOOR, UP_WALL, "left"), "nor LEFT")
  check(permitted(UP_WALL, FLOOR, "down"), "DOWN off an UP_WALL is fine")
  check(not permitted(UP_WALL, FLOOR, "up"), "UP off one is CanObjectLeaveTile")

  check(not permitted(FLOOR, RIGHT_WALL, "left"), "LEFT onto a RIGHT_WALL is refused")
  check(permitted(FLOOR, RIGHT_WALL, "right"), "RIGHT onto one is not")
  check(not permitted(RIGHT_WALL, FLOOR, "right"), "RIGHT off one is refused")

  check(not permitted(FLOOR, UP_BUOY, "down"), "DOWN onto an UP_BUOY is refused")
  check(not permitted(FLOOR, UP_BUOY, "up"), "and so is UP")
  check(not permitted(UP_BUOY, FLOOR, "up"), "leaving one upward is the mask")
  check(permitted(UP_BUOY, FLOOR, "down"), "leaving one downward is not")

  for _, dir in ipairs({ "up", "down", "left", "right" }) do
    check(not permitted(FLOOR, WALL, dir), "no direction enters a WALL tile")
  end
  check(permitted(FLOOR, FLOOR, "down"), "plain floor to plain floor moves")
end

-- entryBlocks is the leave row's mirror, npc_movement.asm:116 against :142
do
  local MIRROR = { up = "down", down = "up", left = "right", right = "left" }
  for _, base in ipairs({ 0xb0, 0xc0 }) do
    for coll = base, base + 7 do
      local leave = Permissions.sideBlocks(coll)
      local enter = Permissions.entryBlocks(coll)
      local ok = true
      for d in pairs(leave) do if not enter[MIRROR[d]] then ok = false end end
      for d in pairs(enter) do if not leave[MIRROR[d]] then ok = false end end
      check(ok, ("$%02x's entry row mirrors its exit row"):format(coll))
    end
  end
  check(Permissions.entryBlocks(FLOOR) == nil, "a plain floor has no entry row")
end

local MAP_ID = "MOUNT_MORTAR_B1F"

local function lipMap()
  local def = {
    id = MAP_ID, width = 1, height = 2,
    blocks = { 1, 2 }, warps = {}, connections = {},
  }
  local tileset = {
    collision = {
      { 0xff, 0xff, 0xff, 0xff },
      { FLOOR, FLOOR, FLOOR, FLOOR },
      { UP_WALL, UP_WALL, FLOOR, FLOOR },
    },
  }
  return Map.new(def, tileset)
end

local function boulderWorld()
  local map = lipMap()
  local world = World.new({ data = {}, save = { player = {} } })
  world.map = map
  world.entities = {}
  world.strengthActive = true
  local boulder = {
    def = { index = 0, movement = 0x19 }, cellX = 0, cellY = 0, steps = 0,
  }
  boulder.scriptStep = function(self, dir)
    local d = Map.DELTA[dir]
    self.cellX, self.cellY = self.cellX + d[1], self.cellY + d[2]
    self.steps = self.steps + 1
  end
  world.npcs = { boulder }
  world.entities = { boulder }
  return world, boulder, map
end

do
  local map = lipMap()
  eq(map:cellCollision(0, 0), FLOOR, "the column decodes floor at the top")
  eq(map:cellCollision(0, 2), UP_WALL, "the lip sits at y=2")
  eq(map:cellCollision(0, 3), FLOOR, "and the lower floor under it")
  check(not map:objectStepPermitted(0, 1, "down"), "the lip refuses a step down")
  check(map:objectStepPermitted(0, 0, "down"), "the step above it does not")
  check(not map:objectStepPermitted(0, 3, "down"), "off-map is GetCoordTileCollision $ff")
end

do
  local world, boulder = boulderWorld()
  check(world:tryPushBoulder("down", 0, 0), "the first push moves the boulder")
  eq(boulder.cellY, 1, "onto the cell above the lip")
  check(not world:tryPushBoulder("down", 0, 1), "the second push is refused")
  eq(boulder.cellY, 1, "and the boulder has not moved")
  eq(boulder.steps, 1, "one scriptStep in all")
end

do
  local world, boulder = boulderWorld()
  boulder.cellX, boulder.cellY = 0, 2
  check(world:tryPushBoulder("down", 0, 2), "DOWN off the lip is still allowed")
  eq(boulder.cellY, 3, "onto the lower floor")
end

do
  local seen = {}
  local saved = Runtime.events
  Runtime.events = {
    listeners = { ["world.boulder_moved"] = true },
    emit = function(_, name, payload) seen[name] = payload end,
  }
  local world, boulder = boulderWorld()
  check(world:tryPushBoulder("down", 0, 0), "a floor-to-floor push still moves")
  eq(boulder.cellY, 1, "the boulder stepped")
  local p = seen["world.boulder_moved"]
  check(p ~= nil, "and world.boulder_moved still fires")
  eq(p and p.mapId, MAP_ID, "with the map it moved on")
  eq(p and p.npcId, 1, "the one-based object id")
  eq(p and p.x, 0, "the destination x")
  eq(p and p.y, 1, "and the destination y")

  seen = {}
  check(not world:tryPushBoulder("down", 0, 1), "the refused push does not move")
  check(seen["world.boulder_moved"] == nil, "and emits nothing")
  Runtime.events = saved
end

T.finish("gen2 boulder side wall bug1936")
