-- Oak's lab poster/e-mail hidden events (#1331, #1333): the extractor's
-- hidden_event whitelist drops both, so the posters and PC e-mail were
-- dead A presses until the flavor script's onInteract hook.
-- engine/events/hidden_events/oaks_lab_posters.asm:1
-- engine/events/hidden_events/oaks_lab_email.asm:1
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

package.loaded["src.render.TextBox"] = {
  new = function(_, text, onDone, opts)
    return { text = text, onDone = onDone, opts = opts }
  end,
}

local M = assert(loadfile("data/scripts/flavor/oaks_lab.lua"))()
local hook = M.OAKS_LAB.onInteract
T.check(type(hook) == "function", "OAKS_LAB.onInteract exists")

local pushed
local function mkGame(owned)
  pushed = {}
  return {
    data = { text = {
      _PushStartText = "PUSH",
      _SaveOptionText = "SAVE",
      _StrengthsAndWeaknessesText = "TYPES",
      _OakLabEmailText = "EMAIL",
    } },
    save = { pokedex = { owned = owned } },
    stack = { push = function(_, box) pushed[#pushed + 1] = box end },
  }
end
local owUp = { player = { facing = "up" } }
local owDown = { player = { facing = "down" } }

-- left poster: unconditional, any facing (#1331)
local g = mkGame({})
T.eq(hook(g, owDown, 4, 0), true, "left poster consumes the press")
T.eq(#pushed, 1, "left poster pushes one box")
T.eq(pushed[1].text, "PUSH", "left poster prints PushStartText")

-- right poster, fewer than 2 species owned: SaveOptionText (#1331)
g = mkGame({ [1] = true })
T.eq(hook(g, owDown, 5, 0), true, "right poster consumes the press (<2 owned)")
T.eq(pushed[1].text, "SAVE", "right poster prints SaveOptionText below 2 owned")

-- right poster, 2+ species owned: StrengthsAndWeaknessesText (#1331)
g = mkGame({ [1] = true, [4] = true })
T.eq(hook(g, owDown, 5, 0), true, "right poster consumes the press (2+ owned)")
T.eq(pushed[1].text, "TYPES",
  "right poster prints StrengthsAndWeaknessesText at 2+ owned")

-- right poster, exactly at the boundary (still <2, one species owned twice
-- under different keys does not double-count)
g = mkGame({ [1] = true })
T.eq(hook(g, owDown, 5, 0), true, "right poster boundary case consumes")
T.eq(pushed[1].text, "SAVE", "one owned species stays on the SAVE line")

-- e-mail tiles, facing up: OakLabEmailText (#1333)
g = mkGame({})
T.eq(hook(g, owUp, 0, 1), true, "e-mail tile x=0 consumes facing up")
T.eq(pushed[1].text, "EMAIL", "e-mail tile x=0 prints OakLabEmailText")
g = mkGame({})
T.eq(hook(g, owUp, 1, 1), true, "e-mail tile x=1 consumes facing up")
T.eq(pushed[1].text, "EMAIL", "e-mail tile x=1 prints OakLabEmailText")

-- e-mail tiles, any other facing: explicit FALSE so the press falls
-- through to tryBookshelf, and nothing is pushed (#1333)
g = mkGame({})
T.eq(hook(g, owDown, 0, 1), false, "e-mail tile x=0 returns false facing down")
T.eq(#pushed, 0, "wrong facing prints nothing")
g = mkGame({})
T.eq(hook(g, { player = { facing = "left" } }, 1, 1), false,
  "e-mail tile x=1 returns false facing left")
T.eq(#pushed, 0, "wrong facing prints nothing")

-- unrelated cell: falls through, nothing printed
g = mkGame({})
T.eq(hook(g, owUp, 3, 3), false, "an unrelated cell returns false")
T.eq(#pushed, 0, "an unrelated cell prints nothing")

T.finish("oaks_lab_posters_email_bug1331_1333")
