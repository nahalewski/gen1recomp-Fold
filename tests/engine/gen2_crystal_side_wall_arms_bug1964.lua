-- ../pokegold/home/map.asm:1960

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

local GameVersion = require("src.core.GameVersion")
local Permissions = require("src.world.gen2.Permissions")

local FLOOR = 0x00
local WALL = 0x07
local STAIRCASE = 0x7a
local RIGHT_WALL = 0xb0
local LEFT_WALL = 0xb1
local UP_WALL = 0xb2

local function collOf(cells)
  return function(x, y) return cells[x .. "," .. y] or FLOOR end
end

-- ../pokecrystal/data/tilesets/mansion_collision.asm:36
local roof = collOf({
  ["0,0"] = WALL, ["1,0"] = WALL, ["2,0"] = WALL, ["3,0"] = WALL,
  ["0,1"] = WALL, ["1,1"] = STAIRCASE, ["2,1"] = LEFT_WALL,
  ["4,2"] = RIGHT_WALL, ["5,2"] = LEFT_WALL,
})

local lip = collOf({ ["0,1"] = UP_WALL })

local saved = GameVersion.current

GameVersion.set("gold")
do
  check(not Permissions.stepPermitted(roof, 1, 1, "down"),
    "gold: the LEFT_WALL right of the stairs forbids the DOWN step")
  check(Permissions.stepPermitted(roof, 1, 1, "right"),
    "gold: and never forbids the RIGHT step")
  check(not Permissions.stepPermitted(lip, 0, 0, "down"),
    "gold: an UP_WALL below still forbids DOWN")
  check(Permissions.neighborBlocksDown("right", LEFT_WALL),
    "gold: every matched arm answers down")
end

GameVersion.set("crystal")
do
  check(Permissions.stepPermitted(roof, 1, 1, "down"),
    "crystal: the stairs step off onto the roof")
  check(not Permissions.stepPermitted(roof, 1, 1, "right"),
    "crystal: the railing right of the stairs forbids RIGHT")
  check(Permissions.stepPermitted(roof, 1, 1, "left"),
    "crystal: and leaves the other arms alone")
  check(not Permissions.stepPermitted(lip, 0, 0, "down"),
    "crystal: an UP_WALL below still forbids DOWN")
  check(not Permissions.neighborBlocksDown("right", LEFT_WALL),
    "crystal: the right arm answers right, not down")
  check(Permissions.neighborBlocksDown("down", UP_WALL),
    "crystal: the down arm still answers down")
  eq(Permissions.neighborBlocks("left", RIGHT_WALL), "left",
    "crystal: a RIGHT_WALL to the left forbids LEFT")
  eq(Permissions.neighborBlocks("up", FLOOR), nil,
    "a plain floor neighbour forbids nothing")
end

do
  GameVersion.set("gold")
  check(not Permissions.stepPermitted(roof, 4, 2, "down"),
    "gold: the LEFT_WALL beside the railing column forbids DOWN")
  check(not Permissions.stepPermitted(roof, 4, 2, "right"),
    "gold: standing on a RIGHT_WALL forbids RIGHT")
  GameVersion.set("crystal")
  check(Permissions.stepPermitted(roof, 4, 2, "down"),
    "crystal: the railing column walks down")
  check(not Permissions.stepPermitted(roof, 4, 2, "right"),
    "crystal: standing on a RIGHT_WALL still forbids RIGHT")
end

GameVersion.set(saved)

T.finish("gen2 crystal side wall arms bug1964")
