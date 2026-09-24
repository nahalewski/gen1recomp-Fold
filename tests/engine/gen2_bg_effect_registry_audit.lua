-- engine/battle_anims/bg_effects.asm:1 (BattleBGEffects jumptable)
-- constants/battle_anim_constants.asm (BATTLE_BG_EFFECT_*)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
local BgEffects = require("src.battle.gen2.BgEffects")

local MANIFESTS = {
  crystal = "tools/rom_manifest_crystal.json",
  gold = "tools/rom_manifest_gold.json",
  silver = "tools/rom_manifest_silver.json",
}

local function readAll(path)
  local f = assert(io.open(path, "r"), path)
  local src = f:read("*a")
  f:close()
  return src
end

local function manifestIds(path)
  local src = readAll(path)
  local block = src:match('"battleBgEffectOrder"%s*:%s*%[(.-)%]')
  check(block ~= nil, path .. " carries battleBgEffectOrder")
  local ids, seen = {}, {}
  for id in (block or ""):gmatch('"(BATTLE_BG_EFFECT_[A-Z0-9_]+)"') do
    if not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  return ids
end

local E = BgEffects.EFFECTS
local unmodelled = {}
for _, name in ipairs(BgEffects.UNMODELLED) do unmodelled[name] = true end

local union = {}
for game, path in pairs(MANIFESTS) do
  local ids = manifestIds(path)
  check(#ids >= 50, ("%s lists %d BG effect ids"):format(game, #ids))
  for _, id in ipairs(ids) do
    union[id] = true
    check(E[id] ~= nil or unmodelled[id],
      ("%s: %s has an E entry or an UNMODELLED cite"):format(game, id))
  end
end

check(union.BATTLE_BG_EFFECT_BODY_SLAM, "the cart lists BODY_SLAM")
check(type(E.BATTLE_BG_EFFECT_BODY_SLAM) == "function",
  "BODY_SLAM is modelled (bg_effects.asm:1444)")

local source = readAll("src/battle/gen2/BgEffects.lua")
for _, name in ipairs(BgEffects.UNMODELLED) do
  check(E[name] == nil, name .. ": UNMODELLED entries carry no E entry")
  check(union[name], name .. ": UNMODELLED names a cart id")
  local cited = false
  for line in source:gmatch("[^\n]+") do
    if line:find(name, 1, true) and line:find("%.asm:%d+") then cited = true end
  end
  check(cited, name .. ": UNMODELLED entry cites its bg_effects.asm routine")
end

for id in pairs(E) do
  check(union[id], id .. ": every E entry names a cart id")
end

eq(#BgEffects.DROPPED, 0, "nothing dropped before any pool ran")
local wasStrict = BgEffects.strict
BgEffects.strict = false
local pool = BgEffects.new({ battleBgEffectOrder = { "BATTLE_BG_EFFECT_NOT_A_THING" } },
  { battleTurn = 0 })
local st = pool:queue(0, 0, 0, 0)
check(st ~= nil and st.func == "BATTLE_BG_EFFECT_NOT_A_THING", "an unknown id still queues")
pool:playFrame()
check(st and st.func == nil, "and is ended on the first frame")
eq(#BgEffects.DROPPED, 1, "but the drop is recorded")
eq(BgEffects.DROPPED[1], "BATTLE_BG_EFFECT_NOT_A_THING", "by name")
pool:queue(0, 0, 0, 0)
pool:playFrame()
eq(#BgEffects.DROPPED, 1, "and only once per id")

BgEffects.strict = true
pool:queue("BATTLE_BG_EFFECT_ALSO_NOT_A_THING", 0, 0, 0)
local ok, err = pcall(pool.playFrame, pool)
check(not ok and tostring(err):find("ALSO_NOT_A_THING", 1, true) ~= nil,
  "strict mode raises on the unknown id")
BgEffects.strict = wasStrict

local known = BgEffects.new({ battleBgEffectOrder = { "BATTLE_BG_EFFECT_BODY_SLAM" } },
  { battleTurn = 0 })
known:queue(0, 0, 0, 0)
local before = #BgEffects.DROPPED
known:playFrame()
eq(#BgEffects.DROPPED, before, "a modelled id is never recorded")

T.finish("gen2 bg effect registry audit")
