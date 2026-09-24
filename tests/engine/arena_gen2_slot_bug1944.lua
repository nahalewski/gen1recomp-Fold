package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.harness")
local Game2 = require("src.core.Game2")
local Save = require("src.core.gen2.Save")
local ArenaBoot = require("src.online.ArenaBoot")

package.loaded["src.ui.gen2.ArenaState"] = {
  new = function(game, spec) return { game = game, spec = spec } end,
}

local function mon(species)
  return {
    species = species, level = 50, hp = 100,
    moves = { { id = "TACKLE", pp = 35, ppUps = 0 } },
    dvs = { attack = 15, defense = 15, speed = 15, special = 15, hp = 15 },
    statExp = {}, experience = 125000,
  }
end

local function fakeStack()
  return {
    pushed = {},
    clear = function(self) self.pushed = {} end,
    push = function(self, state) self.pushed[#self.pushed + 1] = state end,
  }
end

local function host(loaded)
  local savedLoad = Save.load
  Save.load = function() return loaded end
  local game = setmetatable({
    stack = fakeStack(),
    options = { text = 3 },
    data = { pokemon = {} },
    save = Save.newGame({ playerName = "GOLD" }),
  }, { __index = Game2 })
  game:enterArena({ slotId = "slot1", role = "host", team = {},
    profile = { engine = 2, version = "gold",
      rule = { partySize = 3, forceLevel = 50 } } })
  Save.load = savedLoad
  return game
end

local slot = Save.newGame({ playerName = "GOLD" })
slot.party = { mon("CHIKORITA"), mon("TOTODILE") }

local game = host(slot)
T.eq(game.save, slot, "entering a Gen 2 arena adopts the slot it was given")
T.eq(#(game.save.party or {}), 2, "so the party is the save's, not the skeleton's")
T.eq(game.save.options, game.options, "with the launcher's option block kept")
T.eq(#game.stack.pushed, 1, "and the arena state is on a cleared stack")

local spec = { role = "host", team = {},
  profile = { engine = 2, version = "gold",
    rule = { partySize = 3, forceLevel = 50 } } }
local packed, err = ArenaBoot.packOwnParty(game, spec)
T.check(packed ~= nil, "packOwnParty finds a party to send: " .. tostring(err))
T.eq(packed and #packed, 2, "both party members go out")
T.eq(packed and packed[1].species, "CHIKORITA", "led by the first slot")

local empty = host(nil)
T.check(empty.save ~= nil, "an unreadable slot leaves the boot skeleton alone")
local none, why = ArenaBoot.packOwnParty(empty,
  { role = "host", team = {},
    profile = { engine = 2, version = "gold", rule = { partySize = 3 } } })
T.eq(none, nil, "an empty party still refuses to send")
T.eq(why, "no party to send", "with the message the arena screen draws")

T.finish("arena gen2 slot bug1944")
