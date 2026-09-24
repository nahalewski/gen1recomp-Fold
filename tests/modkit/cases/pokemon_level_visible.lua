-- A sandboxed mod can take a Pokémon's level off the screens that print it
-- (pokemon.level_visible): the readout goes, the layout does not, and a
-- build with no mod wrapping the hook prints exactly what it always did.
--
-- The predicate is tested rather than the pixels: every Gen 1 level readout
-- goes through LevelDisplay.visible, and the four call sites are the same
-- one-line guard. What matters here is the contract -- default true, false
-- suppresses, the surface is named, and no-mod costs nothing.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.modkit")
local LevelDisplay = require("src.ui.LevelDisplay")

local FIXTURE = {
  ["mods/level_probe/manifest.json"] = [[{
    "id": "level_probe",
    "name": "Level Probe",
    "version": "1.0.0",
    "entry": "main.lua",
    "api": 2
  }]],
  ["mods/level_probe/main.lua"] = [[
    local mod = ...
    mod.exports.answer = nil
    mod.exports.seen = nil
    mod.hooks:wrap("pokemon.level_visible", function(next, mon, ctx)
      mod.exports.seen = { mon = mon, where = ctx and ctx.where,
                           game = ctx and ctx.game }
      if mod.exports.answer == nil then return next(mon, ctx) end
      return mod.exports.answer
    end)
  ]],
}

local MON = { species = "RATTATA", level = 42, moves = {} }
local GAME = { save = {} }

-- ------- no mod: the level is always printed

local vanilla = T.sdk.loadNone({})
T.eq(LevelDisplay.visible(MON, "battle.enemy", GAME), true,
  "no mod: the enemy healthbox prints a level")
T.eq(LevelDisplay.visible(MON, "party", GAME), true,
  "no mod: the party rows print a level")
T.eq(LevelDisplay.visible(nil, "summary", nil), true,
  "no mod: even a nil mon answers true rather than throwing")
vanilla.release()

-- ------- a mod hides it

local run = T.sdk.loadMods({ "mods/level_probe" }, { fs = T.sdk.memfs(FIXTURE) })
T.eq(#run.errors, 0, "the level probe loads clean (" .. tostring(run.errors[1]) .. ")")
local probe = run.loader.exports.level_probe

probe.answer = false
T.eq(LevelDisplay.visible(MON, "battle.enemy", GAME), false,
  "hidden: the enemy healthbox prints no level")
T.eq(probe.seen and probe.seen.where, "battle.enemy",
  "the hook is told which surface asked")
T.check(probe.seen and probe.seen.mon == MON, "and which Pokémon")
T.check(probe.seen and probe.seen.game == GAME, "and the game")

-- the surface is what lets a mode hide an opponent's level and keep its own
probe.answer = nil
T.eq(LevelDisplay.visible(MON, "party", GAME), true,
  "falling through prints, as today")
T.eq(probe.seen and probe.seen.where, "party", "and still names the surface")

-- only an explicit false suppresses: a mod returning nothing must not blank
-- a screen by accident
probe.answer = true
T.eq(LevelDisplay.visible(MON, "summary", GAME), true,
  "an explicit true prints")

run.release()
T.finish("pokemon level visible")
