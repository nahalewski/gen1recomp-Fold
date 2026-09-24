-- #1391: the Pewter museum guide's lockstep walk, exercised from all four
-- trigger cells around him, the way PewterGuys (engine/events/
-- pewter_guys.asm:1-49) builds the preamble and PewterCitySuperNerd1Shows
-- PlayerMuseumScript (scripts/PewterCity.asm:47-113) walks it out.
--
-- `museumEscort` had zero consumers and zero test coverage before this: a
-- future edit to the RLE tables or the preamble map could silently break
-- the walk and nothing would fail.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local M = assert(loadfile("data/scripts/flavor/pewter_city.lua"))()
local esc = M.PEWTER_CITY.museumEscort
T.check(type(esc) == "table", "museumEscort is exported")
T.check(type(esc.plan) == "function", "museumEscort.plan is exported")
T.check(type(esc.guySteps) == "table", "museumEscort.guySteps is exported")

-- RLEList_PewterMuseumGuy (engine/overworld/auto_movement.asm:199-204):
-- UP 6, LEFT 13, UP 3, LEFT 1 -- 23 steps by content, not just by count.
local wantGuySteps = {}
for _ = 1, 6 do wantGuySteps[#wantGuySteps + 1] = "up" end
for _ = 1, 13 do wantGuySteps[#wantGuySteps + 1] = "left" end
for _ = 1, 3 do wantGuySteps[#wantGuySteps + 1] = "up" end
wantGuySteps[#wantGuySteps + 1] = "left"
T.same(esc.guySteps, wantGuySteps,
  "guySteps is exactly UP x6, LEFT x13, UP x3, LEFT x1")

local function apply(x, y, dirs)
  for _, d in ipairs(dirs) do
    if d == "up" then y = y - 1
    elseif d == "down" then y = y + 1
    elseif d == "left" then x = x - 1
    elseif d == "right" then x = x + 1 end
  end
  return x, y
end

-- PewterMuseumGuyCoords (engine/events/pewter_guys.asm:58-75): the four
-- cells adjacent to the guy's spawn (27,17), each with its own preamble.
local triggers = { { 27, 18 }, { 27, 16 }, { 26, 17 }, { 28, 17 } }
for _, c in ipairs(triggers) do
  local plan = esc.plan(c[1], c[2])
  T.check(plan ~= nil,
    ("(%d,%d) is a real trigger cell and must produce a plan"):format(c[1], c[2]))
  T.eq(#plan.steps, 23,
    ("(%d,%d): 23-step walk, same length regardless of approach side")
      :format(c[1], c[2]))
  T.eq(plan.guyHeadStart, 0,
    ("(%d,%d): no NO_INPUT head padding in the museum preamble")
      :format(c[1], c[2]))

  local px, py = apply(c[1], c[2], plan.steps)
  T.check(px == 14 and py == 8,
    ("(%d,%d): player's walk ends at (14,8), by the museum door")
      :format(c[1], c[2]))

  local guySub = {}
  for i = plan.guyHeadStart + 1, plan.guyHeadStart + #plan.steps do
    guySub[#guySub + 1] = esc.guySteps[i]
  end
  local gx, gy = apply(27, 17, guySub)
  T.check(gx == 13 and gy == 8,
    ("(%d,%d): guy's walk ends at (13,8), beside the player")
      :format(c[1], c[2]))
end

-- Any cell that is not one of the four adjacent trigger cells must not
-- start the escort at all.
T.check(esc.plan(10, 10) == nil, "a non-adjacent cell returns no plan")
T.check(esc.plan(27, 17) == nil, "the guy's own cell is not a trigger either")

T.finish("pewter_museum_escort_bug1391")
