-- PKMN LEAGUE (the post-E4 Hall of Fame viewer) never had a screen backing
-- it, so a PC row wired up to open it would have had nowhere to go (#1282).
-- src/ui/LeaguePC.lua is the missing viewer; it resolves through the
-- registry's builtin fallback with no id table edit needed, because every
-- unregistered id falls through to `require("src.ui." .. id)`.
-- engine/menus/league_pc.asm:1, constants/pokemon_data_constants.asm:65 (cap 50)
--   luajit tests/engine/league_pc_bug1282.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Screens = require("src.ui.Screens")
local LeaguePC = require("src.ui.LeaguePC")

local function team(species, level)
  return { { species = species, level = level, nickname = nil } }
end

local function newGame(teamCount)
  local teams = {}
  for i = 1, teamCount do teams[i] = team("RATTATA", i) end
  local popped = false
  local game = {
    data = { pokemon = {}, text = {} },
    save = { hallOfFame = teams },
    stack = { pop = function() popped = true end },
  }
  return game, function() return popped end
end

-- the registry needs no LeaguePC id entry: an unregistered id falls
-- through resolve()'s builtin path straight to src/ui/LeaguePC.lua
local factory = Screens.get({ data = {} }, "LeaguePC")
check(factory == LeaguePC, "Screens.get(\"LeaguePC\") resolves to this module")
check(type(factory.new) == "function", "the resolved factory is constructible")

-- 60 recorded teams: HOF_TEAM_CAPACITY (50) means the oldest 10 are gone,
-- so the viewer opens on the OLDEST STILL-RECORDED team, index 11
do
  local game = newGame(60)
  local pc = LeaguePC.new(game)
  eq(pc.teamIndex, 11, "60 teams over a cap of 50 starts at team 11 (60-50+1)")
  eq(pc.monIndex, 1, "starts on the first mon of that team")
  check(pc:currentMon() ~= nil, "a current mon is resolved")
end

-- A steps through every remaining team (49 more presses, 11 -> 60), then
-- one more A on the last team's only mon closes the whole viewer
do
  local game, wasPopped = newGame(60)
  local pc = LeaguePC.new(game)
  local doneCalled = false
  pc.onDone = function() doneCalled = true end
  for _ = 1, 49 do
    game.input = { wasPressed = function(_, b) return b == "a" end }
    pc:update(0)
  end
  eq(pc.teamIndex, 60, "49 A-presses walk from team 11 to team 60")
  check(not wasPopped(), "the viewer is still open on the last team")
  game.input = { wasPressed = function(_, b) return b == "a" end }
  pc:update(0)
  check(wasPopped(), "one more A on the last team's last mon closes the viewer")
  check(doneCalled, "onDone fires on close")
end

-- B always closes immediately, from any position
do
  local game, wasPopped = newGame(3)
  local pc = LeaguePC.new(game)
  game.input = { wasPressed = function(_, b) return b == "b" end }
  pc:update(0)
  check(wasPopped(), "B closes the viewer")
end

-- an empty Hall of Fame (no wins recorded yet, or the extreme edge case of
-- a save with the row reachable but no completed run) must not crash: A on
-- a nil current mon closes cleanly instead of indexing into nothing
do
  local game, wasPopped = newGame(0)
  local pc = LeaguePC.new(game)
  eq(pc.teamIndex, 1, "an empty roster clamps teamIndex to 1, not 0 or negative")
  check(pc:currentMon() == nil, "there is no current mon")
  local ok = pcall(function()
    game.input = { wasPressed = function(_, b) return b == "a" end }
    pc:update(0)
  end)
  check(ok, "A on an empty Hall of Fame does not raise")
  check(wasPopped(), "...and closes the viewer instead")
end

T.finish("league pc bug 1282")
