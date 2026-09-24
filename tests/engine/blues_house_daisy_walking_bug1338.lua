-- #1338: after the TOWN MAP, Daisy has to swap from the sitting object to
-- the walking one -- PalletTownDaisyScript, gated on both
-- EVENT_GOT_TOWN_MAP and EVENT_ENTERED_BLUES_HOUSE.
-- scripts/BluesHouse.asm:12-16; scripts/PalletTown.asm:133-144
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local Story = assert(loadfile("data/scripts/story.lua"))()
local Story2 = assert(loadfile("data/scripts/story2.lua"))()

T.check(type(Story.BLUES_HOUSE.onEnter) == "function",
  "M.BLUES_HOUSE.onEnter exists")
T.check(type(Story2.PALLET_TOWN.onEnter) == "function",
  "M.PALLET_TOWN.onEnter exists")

-- Entering Blue's House alone must set EVENT_ENTERED_BLUES_HOUSE and touch
-- nothing else: BluesHouseDefaultScript is a plain SetEvent, no swap here.
do
  local game = { save = { flags = {} } }
  Story.BLUES_HOUSE.onEnter(game, {})
  T.check(game.save.flags.EVENT_ENTERED_BLUES_HOUSE == true,
    "onEnter sets EVENT_ENTERED_BLUES_HOUSE")
  T.check(game.save.flags.EVENT_DAISY_WALKING == nil,
    "and does not itself start the swap")
end

-- PALLET_TOWN's onEnter is the swap: both events must be set, and it must
-- write the toggle even though BLUES_HOUSE is not the live map (the fix's
-- own precondition, verified against src/script/Commands.lua's toggleObject
-- writing save.objectToggles before its live-NPC early return).
do
  local game = {
    save = {
      flags = { EVENT_GOT_TOWN_MAP = true, EVENT_ENTERED_BLUES_HOUSE = true },
    },
  }
  local ow = { map = { id = "PALLET_TOWN" } }
  Story2.PALLET_TOWN.onEnter(game, ow)
  T.check(game.save.flags.EVENT_DAISY_WALKING == true,
    "both prerequisites set: EVENT_DAISY_WALKING fires")
  local toggles = game.save.objectToggles and game.save.objectToggles.BLUES_HOUSE
  T.check(toggles ~= nil, "the swap reaches BLUES_HOUSE's toggle table")
  T.eq(toggles and toggles.BLUESHOUSE_DAISY1, false,
    "the sitting Daisy (DAISY1) is hidden")
  T.eq(toggles and toggles.BLUESHOUSE_DAISY2, true,
    "the walking Daisy (DAISY2) is shown")
end

-- Only having the map, without ever entering the house, must not swap her:
-- EVENT_ENTERED_BLUES_HOUSE is a real gate, not a formality.
do
  local game = {
    save = { flags = { EVENT_GOT_TOWN_MAP = true } },
  }
  Story2.PALLET_TOWN.onEnter(game, { map = { id = "PALLET_TOWN" } })
  T.check(game.save.flags.EVENT_DAISY_WALKING == nil,
    "without EVENT_ENTERED_BLUES_HOUSE the swap does not fire")
end

-- Re-entering Pallet Town after she has already swapped must not re-run
-- the toggle writes (EVENT_DAISY_WALKING itself is the guard).
do
  local game = {
    save = {
      flags = {
        EVENT_GOT_TOWN_MAP = true,
        EVENT_ENTERED_BLUES_HOUSE = true,
        EVENT_DAISY_WALKING = true,
      },
      objectToggles = {},
    },
  }
  local ow = { map = { id = "PALLET_TOWN" } }
  Story2.PALLET_TOWN.onEnter(game, ow)
  T.check(next(game.save.objectToggles) == nil,
    "already-walking Daisy: onEnter writes no toggle a second time")
end

T.finish("blues_house_daisy_walking_bug1338")
