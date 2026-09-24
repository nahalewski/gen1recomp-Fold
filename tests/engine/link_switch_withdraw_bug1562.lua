-- A link switch runs SwitchPlayerMon on the switcher and SwitchEnemyMon on
-- the peer (core.asm:2418-2422, trainer_ai.asm:596-599) (#1562).
--   luajit tests/run_engine.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
local Link = require("tests.modkit.link")
local Net = require("src.link.Net")
local Protocol = require("src.link.Protocol")
local LinkBattle = require("src.link.LinkBattle")

math.randomseed(4242)
local Input = Link.prepare(Data)

local gameA = Link.fakeGame(Data, { "FIXMON_A", "FIXMON_B" }, { name = "RED" })
local gameB = Link.fakeGame(Data, { "FIXMON_A", "FIXMON_B" }, { name = "BLUE" })

local netA, netB = Net.loopbackPair()
local packedA = Protocol.packParty(gameA.save.party)
local packedB = Protocol.packParty(gameB.save.party)
local battleA = LinkBattle.newHost(gameA, netA, {
  myParty = packedA, theirParty = packedB,
  theirName = "BLUE", seed = 987654321,
})
local battleB = LinkBattle.newGuest(gameB, netB, {
  myParty = packedB, theirParty = packedA,
  theirName = "RED", seed = 987654321,
})

local function watch(battle)
  local seen = {}
  local sayNext, sayNextAuto = battle.sayNext, battle.sayNextAuto
  battle.sayNext = function(s, text) seen[#seen + 1] = text; return sayNext(s, text) end
  battle.sayNextAuto = function(s, text, d)
    seen[#seen + 1] = text
    return sayNextAuto(s, text, d)
  end
  return seen
end
local seenA, seenB = watch(battleA), watch(battleB)

local function count(list, needle)
  local n = 0
  for _, text in ipairs(list) do
    if text and text:find(needle, 1, true) then n = n + 1 end
  end
  return n
end
local function firstIndex(list, needle)
  for i, text in ipairs(list) do
    if text and text:find(needle, 1, true) then return i end
  end
end

local resA, resB
battleA.onFinish = function(r) resA = r end
battleB.onFinish = function(r) resB = r end
gameA.stack:push(battleA)
gameB.stack:push(battleB)

local switched, retreatSeen = false, false
for _ = 1, 60000 do
  if resA and resB then break end
  Input.pressed = { a = true }
  if not switched and battleA.phase == "menu" and battleA.playerParty[2] then
    battleA:resolveSwitch(battleA.playerParty[2])
    switched = true
  end
  for _, g in ipairs({ gameA, gameB }) do
    local top = g.stack:top()
    if top and top.forceSwitch and top.party then
      for i, mon in ipairs(top.party) do
        if mon.hp > 0 then top.index = i break end
      end
    end
    g.stack:update(1 / 60)
  end
  if battleA.shrinkOut then retreatSeen = true end
end

T.check(switched, "the host got a menu phase to switch from")
T.eq(count(seenA, "Come back!"), 1,
  "RetreatMon prints once, for the voluntary switch only")
T.check(retreatSeen, "AnimateRetreatingPlayerMon runs on the switcher")
T.eq(count(seenB, "drew"), 1, "the peer prints AIBattleWithdrawText once")

local withdrawA = firstIndex(seenA, "Come back!")
local sendA = firstIndex(seenA, "Go! ") or firstIndex(seenA, "Do it! ")
           or firstIndex(seenA, "Get'm! ")
T.check(sendA ~= nil and withdrawA < sendA, "the recall line comes before the send-out")
local withdrawB = firstIndex(seenB, "drew")
local sendB = firstIndex(seenB, "sent\nout")
T.check(sendB ~= nil and withdrawB < sendB, "and so does the peer's withdraw line")

T.check(battleA.localHashes ~= nil and battleB.localHashes ~= nil,
  "both sides still record per-turn hashes")
local mismatch
for turn, hash in pairs(battleA.localHashes) do
  local other = battleB.localHashes[turn]
  if other and other ~= hash then mismatch = mismatch or turn end
end
T.check(mismatch == nil, "the added lines leave the lockstep state hash alone")

T.finish("link switch prints the recall lines (#1562)")
