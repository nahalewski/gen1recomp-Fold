-- POKEPORT_ARENA_SPEC payload for tests/drivers/arena_boot_loopback.lua.

local Net = require("src.link.Net")
local ArenaBoot = require("src.online.ArenaBoot")

local hostNet, guestNet = Net.loopbackPair()

local function packedMon(species)
  return {
    species = species,
    level = 5,
    hp = 4,
    moves = { { id = "TACKLE", pp = 35, ppUps = 0 } },
    dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
    statExp = {},
  }
end

local hostParty = { packedMon("CHARMANDER") }
local guestParty = { packedMon("SQUIRTLE") }
local seed = 424242

local ctx = {
  hostNet = hostNet,
  guestNet = guestNet,
  hostParty = hostParty,
  guestParty = guestParty,
  seed = seed,
  result = nil,
}
_G.POKEPORT_ARENA_TEST = ctx

local spec, err = ArenaBoot.spec({
  profile = {
    engine = 1,
    version = "red",
    engineVersion = "test",
    apiVersion = 2,
    fingerprint = "loopback",
    rulesetId = nil,
    kind = "vanilla",
    rule = { partySize = 1 },
  },
  role = "host",
  slotId = "slot1",
  team = { 1 },
  seed = seed,
  peerName = "BLUE",
  myParty = hostParty,
  theirParty = guestParty,
  session = hostNet,
  onDone = function(result) ctx.result = result or "ended" end,
})

if not spec then error("arena spec invalid: " .. tostring(err)) end
return spec
