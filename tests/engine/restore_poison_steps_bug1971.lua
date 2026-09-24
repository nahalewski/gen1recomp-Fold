-- poisonSteps is a plain step counter -- (poisonSteps + 1) % 4 on EVERY step,
-- not only while a mon is poisoned (OverworldController:applyFieldPoison) --
-- so it is non-zero three steps out of four in ordinary play.
--
-- Restoring a checkpoint re-enters the map, and the map-enter path zeroes it
-- (setMap, mirroring ClearVariablesOnEnterMap). Checkpoint.restore then
-- re-captures the applied state and compares it with the checkpoint, so the
-- field it just discarded fails the comparison and the whole restore rolls
-- back: "restored state differed at $.save.poisonSteps" (#1971).
--
-- A restore is not a map entry from the player's point of view; the counter
-- belongs to the state being restored.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
Data.tilesets.FIX_OUT.tilesPerRow = 16
Data.field.flyWarps = Data.field.flyWarps or {}
Data.field.playerSprites = { walk = "SPRITE_FIX_PLAYER" }
Data.field.waterTilesets = {}
Data.field.forcedMovement = { tiles = {} }
Data.audio = Data.audio or {}
Data.audio.songs = Data.audio.songs or {}
Data.audio.mapSongs = Data.audio.mapSongs or {}

local SaveData = require("src.core.SaveData")
local Game = require("src.core.Game")
local StateStack = require("src.core.StateStack")
local OverworldState = require("src.world.OverworldController")

Game.data = Data
Game.save = SaveData.newGame()
Game.save.player.name = "RED"
Game.save.player.map = "FIX_TOWN"
StateStack:init()
Game.stack = StateStack
Game.overworld = OverworldState
Game.input = {
  isDown = function() return false end,
  wasPressed = function() return false end,
  step = function() end, state = {}, pressQueue = {},
}
Game.renderer = {
  beginWorldPass = function() end, endWorldPass = function() end,
  beginUIPass = function() end, endUIPass = function() end,
  worldViewSize = function() return 160, 144 end,
  setSGBZones = function() end,
}

local function checkpointSave(steps)
  local save = SaveData.newGame()
  save.player.map = "FIX_TOWN"
  save.player.x, save.player.y = 4, 4
  save.poisonSteps = steps
  return save
end

-- === the bug: the counter survives a checkpoint restore
for _, steps in ipairs({ 1, 2, 3 }) do
  Game:restoreCheckpointSave(checkpointSave(steps))
  T.eq(Game.save.poisonSteps, steps,
    ("a checkpoint restore keeps poisonSteps = %d"):format(steps))
end

-- === zero stays zero (the case that accidentally worked before)
Game:restoreCheckpointSave(checkpointSave(0))
T.eq(Game.save.poisonSteps, 0, "a checkpoint restore keeps poisonSteps = 0")

-- === an ordinary map entry still clears it, which is the cart behaviour
Game.save.poisonSteps = 3
OverworldState:setMap("FIX_TOWN", 4, 4, "up", {})
T.eq(Game.save.poisonSteps, 0, "a plain map entry still zeroes the counter")

-- === and a seamless connection crossing still does not
Game.save.poisonSteps = 3
OverworldState:setMap("FIX_TOWN", 4, 4, "up", { seamless = true })
T.eq(Game.save.poisonSteps, 3, "a seamless crossing still carries it across")

T.finish("poisonSteps survives a checkpoint restore (#1971)")
