-- Parity: the Tower 2F rival scene arms its in-battle line, prints
-- HowsYourDex on the win, and restores the map music (#1842).
--
-- PokemonTower2FRivalText arms SaveEndBattleTextPointers with .DefeatedText
-- before the fight (scripts/PokemonTower2F.asm:145-150), the win re-runs
-- DisplayTextID so the beaten branch prints .HowsYourDexText (asm:72-75,
-- :137-140), and PokemonTower2FRivalExitsScript hides him and calls
-- PlayDefaultMusic (asm:115-124).
--
-- Self-contained; run via `luajit tests/parity_pokemon_tower_rival_bug1842.lua`.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end
local S = require("tests.harness").suite("parity pokemon tower rival")
local check, eq = S.check, S.eq

local story = dofile("data/scripts/story.lua")
local tower = story.POKEMON_TOWER_2F
check(tower ~= nil and tower.rivalScript ~= nil, "POKEMON_TOWER_2F rivalScript exists")

local rows = tower.rivalScript(15)

local function find(verb, arg)
  for i, row in ipairs(rows) do
    if row[1] == verb and (arg == nil or row[2] == arg) then return i, row end
  end
end

local iBattle = find("rival_battle")
local iArm = find("save_end_battle_text", "_PokemonTower2FRivalDefeatedText")
check(iArm ~= nil, "_PokemonTower2FRivalDefeatedText is armed for the battle")
check(iBattle and iArm == iBattle - 1,
      "SaveEndBattleTextPointers runs just before the battle")
check(find("show_text", "_PokemonTower2FRivalDefeatedText") == nil,
      "and it is not also printed on the map afterwards")

local iSet = find("set_flag", "EVENT_BEAT_POKEMON_TOWER_RIVAL")
local iDex = find("show_text", "_PokemonTower2FRivalHowsYourDexText")
check(iSet and iDex and iDex > iSet,
      "the win prints HowsYourDex after setting the event")

local iHide = find("hide_object")
local iDefault = find("play_default_music")
check(iDefault ~= nil, "the exit calls play_default_music")
check(iHide and iDefault and iDefault > iHide,
      "PlayDefaultMusic follows HideObject")
local iWalk = find("walk_npc")
check(iWalk and iHide and iHide > iWalk, "the walk-out runs before the hide")

-- the beaten branch: every jump target resolves, and talking again after the
-- win reaches HowsYourDex instead of falling off the end
local ScriptRunner = require("src.script.ScriptRunner")
local problems = ScriptRunner.validate(rows)
eq(#problems, 0, "rival script validates: " .. table.concat(problems, "; "))

local iJumpIfTrue, jumpRow = find("jump_if_true")
check(iJumpIfTrue ~= nil, "the beaten check jumps")
local labelRow
for i, row in ipairs(rows) do
  if row[1] == "label" and row[2] == (jumpRow and jumpRow[2]) then labelRow = i end
end
check(labelRow ~= nil, "it jumps to a real label, not a stale row number")
local tail
for i = labelRow or 0, #rows do
  if rows[i] and rows[i][1] == "show_text" then tail = rows[i][2] break end
end
eq(tail, "_PokemonTower2FRivalHowsYourDexText",
   "the beaten branch prints HowsYourDex")

-- both exit paths are still distinct (ON_LEFT vs not, asm:76-82)
local left = tower.rivalScript(15)
local right = tower.rivalScript(14)
local _, lWalk = find("walk_npc")
local rWalk
for _, row in ipairs(right) do if row[1] == "walk_npc" then rWalk = row end end
check(lWalk and rWalk and lWalk[3][1] ~= rWalk[3][1],
      "the two exit movements still differ")
eq(#left, #right, "both variants are the same script shape")

S.finish()
