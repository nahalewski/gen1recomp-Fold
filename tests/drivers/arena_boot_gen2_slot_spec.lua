local Net = require("src.link.Net")
local ArenaBoot = require("src.online.ArenaBoot")
local Save = require("src.core.gen2.Save")
local SaveData = require("src.core.SaveData")

local VERSION = os.getenv("POKEPORT_VERSION") or "gold"

local hostNet, guestNet = Net.loopbackPair()

local function mon(species, item)
  return {
    species = species,
    level = 20,
    experience = 8000,
    hp = 60,
    maxHp = 60,
    stats = { hp = 60, attack = 30, defense = 30, speed = 30,
              spAttack = 30, spDefense = 30 },
    moves = { { id = "TACKLE", pp = 35, maxPp = 35 } },
    dvs = { attack = 15, defense = 15, speed = 15, special = 15 },
    statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    item = item,
    happiness = 70,
    ot = "GOLD",
    otId = 1234,
  }
end

local SLOT_LABEL = "arena-slot-spec"

local slotId
for _, row in ipairs(SaveData.listSlots(VERSION) or {}) do
  if row.label == SLOT_LABEL then slotId = row.id break end
end
if not slotId then
  slotId = SaveData.createSlot(VERSION)
  if slotId then SaveData.renameSlot(VERSION, slotId, SLOT_LABEL) end
end
if slotId then SaveData.setActiveSlot(VERSION, slotId) end
local save = Save.newGame({ playerName = "GOLD" })
save.version = VERSION
save.party = { mon("CYNDAQUIL", "LEFTOVERS") }
local wrote, writeErr = Save.save(save)
if not wrote then
  error("arena slot spec could not write a save: " .. tostring(writeErr))
end

local guestParty = { {
  species = "TOTODILE",
  level = 20,
  experience = 8000,
  hp = 60,
  moves = { { id = "TACKLE", pp = 35 } },
  dvs = { attack = 15, defense = 15, speed = 15, special = 15 },
  statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
  happiness = 70,
} }
local seed = 515151

local ctx = {
  hostNet = hostNet,
  guestNet = guestNet,
  hostParty = nil,
  guestParty = guestParty,
  seed = seed,
  result = nil,
}
_G.POKEPORT_ARENA_TEST = ctx

local spec, err = ArenaBoot.spec({
  profile = {
    engine = 2,
    version = VERSION,
    engineVersion = "test",
    apiVersion = 2,
    fingerprint = "loopback",
    rulesetId = "gen2",
    kind = "vanilla",
    rule = { partySize = 1 },
  },
  role = "host",
  slotId = slotId or "slot1",
  team = { 1 },
  seed = seed,
  peerName = "SILVER",
  theirParty = guestParty,
  session = hostNet,
  onDone = function(result) ctx.result = result or "ended" end,
})

if not spec then error("gen 2 arena spec invalid: " .. tostring(err)) end
return spec
