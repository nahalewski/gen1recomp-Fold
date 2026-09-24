-- Gen 2 had no per-trainer battle theme: trainers.encounterMusic is the
-- walk-up jingle (data/trainers/encounter_music.asm), and PlayBattleMusic's
-- ladder picked the song on its own.  A class' trainers.battleTheme, and a
-- wild species' pokemon.battleTheme, now replace that pick.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local BattleMusic = require("src.battle.gen2.BattleMusic")
local World = require("src.world.gen2.World")

-- ------------------------------------------------- the pure song lookup

T.eq(BattleMusic.battleSong({ class = "FALKNER", landmark = 1 }),
     "Music_JohtoGymBattle", "the vanilla ladder is unchanged without one")
T.eq(BattleMusic.battleSong({ class = "FALKNER", landmark = 1,
                              battleTheme = "Music_ModTheme" }),
     "Music_ModTheme", "a class theme replaces even a gym leader's song")
T.eq(BattleMusic.battleSong({ battleTheme = "Music_ModWild" }),
     "Music_ModWild", "a wild theme replaces the wild song")
T.eq(BattleMusic.battleSong({ battleTheme = "Music_ModTheme", crystal = true,
                              battleType = BattleMusic.BATTLETYPE_SUICUNE }),
     "Music_ModTheme", "and it wins over Crystal's Suicune arm")
T.eq(BattleMusic.victorySong({ class = "FALKNER" }), "Music_GymLeaderVictory",
     "the victory jingle is left alone")

-- ---------------------------------------------- where the theme comes from

local data = {
  trainers = { classes = {
    FALKNER = { id = "FALKNER", index = 3, name = "FALKNER",
                battleTheme = "Music_ModTheme",
                encounterMusic = "Music_HikerEncounter" },
    YOUNGSTER = { id = "YOUNGSTER", index = 4, name = "YOUNGSTER" },
  } },
  pokemon = {
    HOOTHOOT = { id = "HOOTHOOT", battleTheme = "Music_ModWild" },
    SENTRET = { id = "SENTRET" },
  },
}
local world = { game = { data = data } }

T.eq(World.modBattleTheme(world, { trainer = { classId = "FALKNER", class = 3 } }),
     "Music_ModTheme", "a trainer battle takes the class' theme")
T.eq(World.modBattleTheme(world, { trainer = { class = 3 } }),
     "Music_ModTheme", "the numeric class id resolves the same record")
T.eq(World.modBattleTheme(world, { trainer = { classId = "YOUNGSTER", class = 4 } }),
     nil, "a class without one keeps the vanilla ladder")
T.eq(World.modBattleTheme(world, { trainer = { classId = "FALKNER", class = 3 },
                                   wild = { species = "HOOTHOOT" } }),
     "Music_ModTheme", "a trainer battle never reads a species theme")
T.eq(World.modBattleTheme(world, { wild = { species = "HOOTHOOT" } }),
     "Music_ModWild", "a wild battle takes the species' theme")
T.eq(World.modBattleTheme(world, { wild = { species = "SENTRET" } }), nil,
     "a species without one keeps the vanilla ladder")
T.eq(World.modBattleTheme(world, {}), nil, "and so does a bare battle")
T.eq(World.modBattleTheme({}, {}), nil, "a world with no data answers nothing")

-- the walk-up jingle and the battle theme stay separate keys
T.eq(data.trainers.classes.FALKNER.encounterMusic, "Music_HikerEncounter",
     "encounterMusic is untouched by the battle theme")

T.finish("gen2 mod battle theme")
