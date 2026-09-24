-- "This POKéMON is really energetic!" prints before the received-mon box
-- (#1334).  starterBall's numeric jump targets moved down one row for the
-- new line, so this asserts the targets by ROW CONTENT, not by index, and
-- would catch a stale target the next time a row is inserted above them.
-- scripts/OaksLab.asm:919
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local M = assert(loadfile("data/scripts/oaks_lab.lua"))()
local rows = M.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL
T.check(type(rows) == "table", "starterBall rows loaded")

-- the energetic line lands between the ask and the sound/received pair
local askRow
for i, row in ipairs(rows) do
  if row[1] == "ask" then askRow = i end
end
T.check(askRow ~= nil, "found the ask row")
T.eq(rows[askRow + 1][1], "jump_if_false", "the ask is followed by its jump")
T.same(rows[askRow + 2], { "show_text", "_OaksLabMonEnergeticText" },
  "the energetic line is the row right after the NO jump")
T.eq(rows[askRow + 3][1], "text_sound",
  "the sound cue stays on the RECEIVED line, not the energetic one")
T.eq(rows[askRow + 4][1], "show_text",
  "and the received-mon text follows the sound cue")
T.eq(rows[askRow + 4][2], "_OaksLabReceivedMonText",
  "specifically the received-mon text")

-- jump_if_true (row 2): the EVENT_GOT_STARTER short-circuit must land on
-- the leftover-ball beat, "face_object 5 down" -- asserted by content
local gotStarterJump
for i, row in ipairs(rows) do
  if row[1] == "check_flag" and row[2] == "EVENT_GOT_STARTER" then
    gotStarterJump = rows[i + 1]
    break
  end
end
T.check(gotStarterJump ~= nil and gotStarterJump[1] == "jump_if_true",
  "found the EVENT_GOT_STARTER jump_if_true")
local target1 = gotStarterJump[2]
T.check(type(target1) == "number", "the target is a numeric row index")
T.same(rows[target1], { "face_object", 5, "down" },
  "jump_if_true lands on the leftover-ball face_object row")

-- jump_if_false (row 4): the EVENT_FOLLOWED_OAK_INTO_LAB gate must land on
-- the pre-pick line, "show_text _OaksLabThoseArePokeBallsText"
local followedOakJump
for i, row in ipairs(rows) do
  if row[1] == "check_flag" and row[2] == "EVENT_FOLLOWED_OAK_INTO_LAB" then
    followedOakJump = rows[i + 1]
    break
  end
end
T.check(followedOakJump ~= nil and followedOakJump[1] == "jump_if_false",
  "found the EVENT_FOLLOWED_OAK_INTO_LAB jump_if_false")
local target2 = followedOakJump[2]
T.check(type(target2) == "number", "the target is a numeric row index")
T.same(rows[target2], { "show_text", "_OaksLabThoseArePokeBallsText" },
  "jump_if_false lands on the pre-pick ThoseArePokeBalls row")

-- the leftover-ball beat this jump lands on must never fall through into
-- the pre-pick line beneath it (#601 remnant); confirm a terminating jump
-- sits between them
T.eq(rows[target1 + 2][1], "jump",
  "the leftover-ball beat ends on its own jump before the pre-pick row")

T.finish("oaks_lab_starter_energetic_bug1334")
