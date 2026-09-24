-- POKEPORT_ARENA_SPEC payload for tests/drivers/arena_boot_gen2_loopback.lua.

local Net = require("src.link.Net")
local ArenaBoot = require("src.online.ArenaBoot")

local hostNet, guestNet = Net.loopbackPair()

-- Protocol.packMon2's shape: four rolled DVs (hp is derived), Gen 2's
-- `experience`, and a held item.
local function packedMon(species, item)
  return {
    species = species,
    level = 20,
    experience = 8000,
    hp = 60,
    moves = { { id = "TACKLE", pp = 35 } },
    dvs = { attack = 15, defense = 15, speed = 15, special = 15 },
    statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    item = item,
    happiness = 70,
  }
end

local hostParty = { packedMon("CYNDAQUIL", "LEFTOVERS") }
local guestParty = { packedMon("TOTODILE") }
local seed = 515151

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
    engine = 2,
    version = "gold",
    engineVersion = "test",
    apiVersion = 2,
    fingerprint = "loopback",
    rulesetId = "gen2",
    kind = "vanilla",
    rule = { partySize = 1 },
  },
  role = "host",
  slotId = "slot1",
  team = { 1 },
  seed = seed,
  peerName = "SILVER",
  myParty = hostParty,
  theirParty = guestParty,
  session = hostNet,
  onDone = function(result) ctx.result = result or "ended" end,
})

if not spec then error("gen 2 arena spec invalid: " .. tostring(err)) end
return spec
