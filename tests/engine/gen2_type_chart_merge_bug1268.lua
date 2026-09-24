-- data/types/type_matchups.asm:112-116, engine/battle/effect_commands.asm:1305-1313

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local Game2 = require("src.core.Game2")
local Damage = require("src.battle.gen2.Damage")

local TYPES = {
  "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BIRD", "BUG",
  "GHOST", "STEEL", "CURSE_TYPE", "FIRE", "WATER", "GRASS", "ELECTRIC",
  "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK",
}

local DEFAULT_ROWS = [[
NORMAL ROCK 5
NORMAL STEEL 5
FIRE FIRE 5
FIRE WATER 5
FIRE GRASS 20
FIRE ICE 20
FIRE BUG 20
FIRE ROCK 5
FIRE DRAGON 5
FIRE STEEL 20
WATER FIRE 20
WATER WATER 5
WATER GRASS 5
WATER GROUND 20
WATER ROCK 20
WATER DRAGON 5
ELECTRIC WATER 20
ELECTRIC ELECTRIC 5
ELECTRIC GRASS 5
ELECTRIC GROUND 0
ELECTRIC FLYING 20
ELECTRIC DRAGON 5
GRASS FIRE 5
GRASS WATER 20
GRASS GRASS 5
GRASS POISON 5
GRASS GROUND 20
GRASS FLYING 5
GRASS BUG 5
GRASS ROCK 20
GRASS DRAGON 5
GRASS STEEL 5
ICE WATER 5
ICE GRASS 20
ICE ICE 5
ICE GROUND 20
ICE FLYING 20
ICE DRAGON 20
ICE STEEL 5
ICE FIRE 5
FIGHTING NORMAL 20
FIGHTING ICE 20
FIGHTING POISON 5
FIGHTING FLYING 5
FIGHTING PSYCHIC_TYPE 5
FIGHTING BUG 5
FIGHTING ROCK 20
FIGHTING DARK 20
FIGHTING STEEL 20
POISON GRASS 20
POISON POISON 5
POISON GROUND 5
POISON ROCK 5
POISON GHOST 5
POISON STEEL 0
GROUND FIRE 20
GROUND ELECTRIC 20
GROUND GRASS 5
GROUND POISON 20
GROUND FLYING 0
GROUND BUG 5
GROUND ROCK 20
GROUND STEEL 20
FLYING ELECTRIC 5
FLYING GRASS 20
FLYING FIGHTING 20
FLYING BUG 20
FLYING ROCK 5
FLYING STEEL 5
PSYCHIC_TYPE FIGHTING 20
PSYCHIC_TYPE POISON 20
PSYCHIC_TYPE PSYCHIC_TYPE 5
PSYCHIC_TYPE DARK 0
PSYCHIC_TYPE STEEL 5
BUG FIRE 5
BUG GRASS 20
BUG FIGHTING 5
BUG POISON 5
BUG FLYING 5
BUG PSYCHIC_TYPE 20
BUG GHOST 5
BUG DARK 20
BUG STEEL 5
ROCK FIRE 20
ROCK ICE 20
ROCK FIGHTING 5
ROCK GROUND 5
ROCK FLYING 20
ROCK BUG 20
ROCK STEEL 5
GHOST NORMAL 0
GHOST PSYCHIC_TYPE 20
GHOST DARK 5
GHOST STEEL 5
GHOST GHOST 20
DRAGON DRAGON 20
DRAGON STEEL 5
DARK FIGHTING 5
DARK PSYCHIC_TYPE 20
DARK GHOST 20
DARK DARK 5
DARK STEEL 5
STEEL FIRE 5
STEEL WATER 5
STEEL ELECTRIC 5
STEEL ICE 20
STEEL ROCK 20
STEEL STEEL 5
]]

local FORESIGHT_ROWS = [[
NORMAL GHOST 0
FIGHTING GHOST 0
]]

local function parse(text)
  local rows = {}
  for attacker, defender, multiplier in
      text:gmatch("(%u[%u_]*)%s+(%u[%u_]*)%s+(%d+)") do
    rows[#rows + 1] = { attacker = attacker, defender = defender,
      multiplier = tonumber(multiplier) }
  end
  return rows
end

local function serialize(rows)
  local parts = {}
  for _, row in ipairs(rows) do
    parts[#parts + 1] = ("{attacker=%q,defender=%q,multiplier=%d}")
      :format(row.attacker, row.defender, row.multiplier)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local DEFAULT = parse(DEFAULT_ROWS)
local FORESIGHT = parse(FORESIGHT_ROWS)

T.eq(#DEFAULT, 108, "the fixture carries the cart's 108 default rows")
T.eq(#FORESIGHT, 2, "and the two rows the `db -2` marker precedes")

love.filesystem.write("data/generated/type_chart.lua",
  ("return { generation = 2, matchups = %s, foresightMatchups = %s }")
    :format(serialize(DEFAULT), serialize(FORESIGHT)))

local function bootChart()
  local game = setmetatable({ data = {} }, Game2)
  game.applyOptions = function() end
  pcall(Game2.load, game)
  return game.data.type_chart
end

local function resolve(matchups)
  local out = {}
  for _, attacker in ipairs(TYPES) do
    for _, defender in ipairs(TYPES) do
      out[attacker .. ">" .. defender] =
        Damage.typeMultiplier(attacker, { defender }, matchups)
    end
  end
  return out
end

local chart = bootChart()
T.check(chart and chart.matchups, "Gold's chart reaches self.data.type_chart")

local before = resolve(DEFAULT)
local after = resolve(chart.matchups)

T.eq(before["NORMAL>GHOST"], 10,
  "unmerged, a NORMAL move is neutral against a GHOST")
T.eq(before["FIGHTING>GHOST"], 10,
  "unmerged, a FIGHTING move is neutral against a GHOST")

T.eq(after["NORMAL>GHOST"], 0, "merged, NORMAL does nothing to GHOST")
T.eq(after["FIGHTING>GHOST"], 0, "merged, FIGHTING does nothing to GHOST")
T.eq(after["GHOST>NORMAL"], 0, "and GHOST still does nothing to NORMAL")

T.eq(#chart.matchups, #DEFAULT + #FORESIGHT,
  "the merge appends exactly the foresight rows")
T.eq(#(chart.foresightMatchups or {}), #FORESIGHT,
  "and leaves foresightMatchups in place for Fingerprint")

local moved = {}
for pair, value in pairs(after) do
  if before[pair] ~= value then moved[#moved + 1] = pair end
end
table.sort(moved)
T.eq(#moved, 2, "exactly two of the 19x19 pairs move")
T.eq(moved[1], "FIGHTING>GHOST", "the first is FIGHTING against GHOST")
T.eq(moved[2], "NORMAL>GHOST", "the second is NORMAL against GHOST")

local twice = bootChart()
T.eq(#twice.matchups, #DEFAULT + #FORESIGHT,
  "a second load appends the rows once, not twice")
T.eq(Damage.typeMultiplier("NORMAL", { "GHOST", "POISON" }, twice.matchups), 0,
  "a dual GHOST/POISON target is still immune to NORMAL")

T.finish("gen2 type chart foresight merge bug 1268")
