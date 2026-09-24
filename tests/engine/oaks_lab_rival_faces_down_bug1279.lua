-- #1279: the rival must face DOWN at his own table cell before the taunt,
-- same as SetSpriteFacingDirectionAndDelay does before DisplayTextID -- not
-- just the player turning to face him.
-- scripts/OaksLab.asm:347-351 (Red/Blue); pokeyellow scripts/OaksLab.asm:311-315
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local function fakeOw(rival)
  return {
    npcByIndex = function(_, i) return i == 1 and rival or nil end,
    map = {
      inBounds = function() return true end,
      isWalkableCell = function() return true end,
    },
    runner = { run = function(_, rows, opts) return rows, opts end },
  }
end

-- capture the rows the runner was handed, since `run` is only a stub
local function captureRun(ow)
  local captured
  ow.runner.run = function(_, rows, opts) captured = rows return true end
  return function() return captured end
end

local function baseGame()
  return {
    save = {
      flags = {
        EVENT_GOT_STARTER = true,
        EVENT_BATTLED_RIVAL_IN_OAKS_LAB = false,
        EVENT_CHOSE_BULBASAUR = true,
      },
    },
  }
end

-- Red/Blue
do
  local M = assert(loadfile("data/scripts/oaks_lab.lua"))()
  local rival = { id = "rival" }
  local ow = fakeOw(rival)
  local getRows = captureRun(ow)
  local ok = M.onStep(baseGame(), ow, 4, 6)
  T.check(ok == true, "onStep claims the rival-challenge step")
  local rows = getRows()
  T.check(rows ~= nil, "the challenge rows reached the runner")
  T.same(rows[1], { "face_object", 1, "down" },
    "the FIRST row faces the rival down at his table (#1279)")
  T.eq(rows[2][1], "face_player_dir", "the player-facing row still follows it")
  T.eq(rows[2][2], "up", "and still turns the player up, unchanged")
end

-- Yellow
do
  local M = assert(loadfile("data/scripts/oaks_lab_yellow.lua"))()
  local rival = { id = "rival" }
  local ow = fakeOw(rival)
  local getRows = captureRun(ow)
  local ok = M.onStep(baseGame(), ow, 4, 6)
  T.check(ok == true, "yellow onStep claims the rival-challenge step")
  local rows = getRows()
  T.check(rows ~= nil, "the yellow challenge rows reached the runner")
  T.same(rows[1], { "face_object", 1, "down" },
    "yellow's first row faces the rival (object 1) down too (#1279)")
end

T.finish("oaks_lab_rival_faces_down_bug1279")
