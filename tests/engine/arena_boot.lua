package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local ArenaBoot = require("src.online.ArenaBoot")

local function fakeSession()
  return {
    sent = {},
    send = function(self, msg) self.sent[#self.sent + 1] = msg end,
    poll = function() return {} end,
    take = function() return nil end,
    close = function(self) self.closed = true end,
    update = function() end,
    paired = true,
    closed = false,
  }
end

local function mon(species, level)
  return {
    species = species,
    level = level or 50,
    hp = 100,
    moves = { { id = "TACKLE", pp = 35, ppUps = 0 } },
    dvs = { attack = 15, defense = 15, speed = 15, special = 15, hp = 15 },
    statExp = {},
  }
end

local function packed(species)
  return { { species = species, level = 50, moves = {}, dvs = {}, statExp = {} } }
end

local NONE = setmetatable({}, { __tostring = function() return "NONE" end })

local function merge(base, over)
  for k, v in pairs(over or {}) do
    base[k] = (v ~= NONE) and v or nil
  end
  return base
end

local function profile(over)
  local p = {
    engine = 1,
    version = "red",
    engineVersion = "1.9.0",
    apiVersion = 2,
    fingerprint = "abc123",
    rulesetId = "gen1_faithful",
    kind = "vanilla",
    rule = { partySize = 3, forceLevel = 50 },
  }
  return merge(p, over)
end

local function fields(over)
  local f = {
    profile = profile(),
    role = "host",
    slotId = "slot1",
    team = { 3, 1 },
    seed = 12345,
    peerName = "BLUE",
    theirParty = packed("BLASTOISE"),
    session = fakeSession(),
    onDone = function() end,
  }
  return merge(f, over)
end

-- ---------------------------------------------------------------- spec
local spec, err = ArenaBoot.spec(fields())
T.check(spec ~= nil, "a well formed host spec validates: " .. tostring(err))
T.eq(spec.role, "host", "role survives")
T.eq(spec.slotId, "slot1", "slotId survives")
T.eq(spec.seed, 12345, "seed survives")
T.eq(spec.peerName, "BLUE", "peerName survives")
T.same(spec.team, { 3, 1 }, "team order survives")
T.eq(spec.profile.rule.partySize, 3, "rule.partySize survives")
T.eq(spec.profile.rule.forceLevel, 50, "rule.forceLevel survives")
T.eq(spec.hostName, "HOST", "hostName defaults")
T.eq(spec.guestName, "GUEST", "guestName defaults")
T.eq(type(spec.onDone), "function", "onDone is always callable")

local defaulted = ArenaBoot.spec(fields({ profile = profile({ rule = NONE }),
                                          team = NONE, peerName = NONE }))
T.check(defaulted ~= nil, "a spec with no rule and no team validates")
T.eq(defaulted and defaulted.profile.rule.partySize, 6, "partySize defaults to 6")
T.eq(defaulted and defaulted.peerName, "FOE", "peerName defaults to FOE")

local function rejects(over, what)
  local got, why = ArenaBoot.spec(fields(over))
  T.check(got == nil, what .. " is refused (got " .. tostring(why) .. ")")
end

rejects({ profile = NONE }, "a spec with no profile")
rejects({ profile = profile({ engine = 3 }) }, "an unknown engine")
rejects({ profile = profile({ version = "ruby" }) }, "an unknown version")
rejects({ profile = profile({ kind = "cart" }) }, "a cart profile with no cart")
rejects({ profile = profile({ rule = { partySize = 9 } }) }, "partySize above 6")
rejects({ profile = profile({ rule = { forceLevel = 500 } }) }, "an out of range forceLevel")
rejects({ role = "referee" }, "an unknown role")
rejects({ slotId = NONE }, "a player spec with no slotId")
rejects({ team = { 1, 1 } }, "a team that repeats an index")
rejects({ team = { 1, 7 } }, "a team index outside 1..6")
rejects({ team = { 1, 2, 3, 4 } }, "a team longer than partySize")
rejects({ seed = "abc" }, "a non-numeric seed")
rejects({ session = {} }, "a session with no send/poll/close")
rejects({ theirParty = NONE }, "a player spec with no theirParty")
rejects({ onDone = 7 }, "a non-callable onDone")

local cartSpec = ArenaBoot.spec(fields({
  profile = profile({ kind = "cart",
                      cart = { id = "kanto_plus", version = "1.2.0", hash = "deadbeef" } }),
}))
T.check(cartSpec ~= nil, "a cart profile with id and hash validates")
T.eq(cartSpec and cartSpec.profile.cart.id, "kanto_plus", "cart id survives")

local specSession = fakeSession()
local watched = ArenaBoot.spec(fields({ session = specSession }))
T.check(watched.session == specSession, "the session object is passed through, not copied")

local seen
local reported = ArenaBoot.spec(fields({ onDone = function(r) seen = r end }))
reported.onDone("win")
T.eq(seen, "win", "onDone forwards the result")

local spectator, specErr = ArenaBoot.spec({
  profile = profile(),
  role = "spectator",
  seed = 7,
  hostParty = packed("CHARIZARD"),
  guestParty = packed("BLASTOISE"),
  hostName = "RED",
  guestName = "BLUE",
  session = fakeSession(),
})
T.check(spectator ~= nil, "a spectator spec needs no slotId: " .. tostring(specErr))
T.check(ArenaBoot.spec({ profile = profile(), role = "spectator", seed = 7,
                         session = fakeSession() }) == nil,
        "a spectator spec with no parties is refused")

-- ---------------------------------------------------------------- battleOpts
local opts = ArenaBoot.battleOpts(spec)
T.eq(opts.role, "host", "host opts carry the role")
T.eq(opts.theirName, "BLUE", "host opts name the peer")
T.eq(opts.seed, 12345, "host opts carry the seed")
T.eq(opts.ruleset, "gen1_faithful", "ruleset comes from profile.rulesetId")
T.eq(opts.verdict, "full", "arena battles always run at verdict full")
T.eq(opts.strict, true, "arena battles are always strict")
T.eq(opts.forceLevel, 50, "forceLevel comes from the rule")
T.eq(opts.keepNetOpen, true, "the arena never closes the session")
T.check(opts.theirParty ~= nil, "host opts carry theirParty")

local guestOpts = ArenaBoot.battleOpts(ArenaBoot.spec(fields({ role = "guest" })))
T.eq(guestOpts.role, "guest", "guest opts carry the role")

local specOpts = ArenaBoot.battleOpts(spectator)
T.eq(specOpts.hostName, "RED", "spectator opts carry hostName")
T.eq(specOpts.guestName, "BLUE", "spectator opts carry guestName")
T.eq(specOpts.keepNetOpen, true, "spectator opts keep the session open")
T.check(specOpts.hostParty ~= nil and specOpts.guestParty ~= nil,
        "spectator opts carry both parties")
T.check(specOpts.myParty == nil, "spectator opts have no myParty")

-- ---------------------------------------------------------------- packOwnParty
local game = { save = { party = { mon("CHARIZARD"), mon("PIKACHU"), mon("SNORLAX") } } }
local fresh = ArenaBoot.spec(fields())
local mine, packErr = ArenaBoot.packOwnParty(game, fresh)
T.check(mine ~= nil, "packOwnParty packs a party: " .. tostring(packErr))
T.eq(#mine, 2, "packOwnParty packs exactly the chosen team")
T.eq(mine[1].species, "SNORLAX", "the team's first index leads")
T.eq(mine[2].species, "CHARIZARD", "the team's second index follows")
T.check(fresh.myParty == mine, "packOwnParty fills spec.myParty")

local again = ArenaBoot.packOwnParty(game, fresh)
T.check(again == mine, "packOwnParty is idempotent once myParty is filled")

local noTeam = ArenaBoot.spec(fields({ team = NONE }))
local wholeParty = ArenaBoot.packOwnParty(game, noTeam)
T.eq(#wholeParty, 3, "with no team the whole party goes, capped by partySize")

local capped = ArenaBoot.spec(fields({ team = NONE,
                                       profile = profile({ rule = { partySize = 2 } }) }))
T.eq(#ArenaBoot.packOwnParty(game, capped), 2, "partySize caps the untargeted party")

local empty = ArenaBoot.spec(fields())
local none, noneErr = ArenaBoot.packOwnParty({ save = { party = {} } }, empty)
T.check(none == nil and noneErr ~= nil, "an empty party is refused: " .. tostring(noneErr))

T.check(ArenaBoot.packOwnParty(game, spectator) == nil,
        "packOwnParty does nothing for a spectator")

-- A Gen 2 profile packs through Protocol.packParty2, whose record carries the
-- held item and Gen 2's `experience` rather than Gen 1's `exp`.
local gen2Game = { save = { party = { mon("TYPHLOSION"), mon("PIKACHU"),
                                      mon("SNORLAX") } } }
gen2Game.save.party[3].item = "LEFTOVERS"
gen2Game.save.party[3].experience = 125000
local gen2 = ArenaBoot.spec(fields({ profile = profile({ engine = 2, version = "gold" }) }))
local g2, g2err = ArenaBoot.packOwnParty(gen2Game, gen2)
T.check(g2 ~= nil, "gen 2 party packing goes through packParty2: " .. tostring(g2err))
T.eq(g2 and #g2, 2, "the Gen 2 pack honours the chosen team")
T.eq(g2 and g2[1].species, "SNORLAX", "the Gen 2 team's first index leads")
T.eq(g2 and g2[1].item, "LEFTOVERS", "the held item rides the Gen 2 record")
T.eq(g2 and g2[1].experience, 125000, "the Gen 2 record carries `experience`")
T.check(g2 and g2[1].exp == nil, "...and not Gen 1's `exp`")

T.finish("arena_boot")
