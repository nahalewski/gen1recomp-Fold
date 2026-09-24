-- start_battle.asm:60-66
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local eq = T.eq

love = love or require("tests.love_stub")

local BattleMusic = require("src.battle.gen2.BattleMusic")
local World = require("src.world.gen2.World")

eq(BattleMusic.battleSong({ crystal = true, battleType = 5, landmark = 1,
  daytime = "NITE" }), "Music_SuicuneBattle",
  "a Crystal roaming battle wins over the night wild theme")
eq(BattleMusic.battleSong({ crystal = true, battleType = 12, landmark = 1 }),
  "Music_SuicuneBattle", "and so does the Tin Tower Suicune")
eq(BattleMusic.battleSong({ crystal = true, battleType = 5, class = "FALKNER",
  landmark = 1 }), "Music_SuicuneBattle",
  "the wBattleType test sits above the wOtherTrainerClass ladder")
eq(BattleMusic.battleSong({ battleType = 5, landmark = 1, daytime = "DAY" }),
  "Music_JohtoWildBattle", "Gold and Silver have no such block")
eq(BattleMusic.battleSong({ crystal = true, landmark = 1, daytime = "DAY" }),
  "Music_JohtoWildBattle", "an ordinary Crystal wild battle is untouched")

-- (../pokecrystal/engine/overworld/wildmons.asm:561
local function context(version, opts)
  local world = {
    tod = "DAY",
    map = { def = { landmark = 1 } },
    game = { save = { version = version } },
  }
  return World.battleMusicContext(world, opts)
end

eq(context("crystal", { roaming = 3 }).battleType, 5,
  "a roaming encounter reports BATTLETYPE_ROAMING")
eq(context("crystal", { roaming = 3 }).crystal, true, "...on Crystal")
eq(context("gold", { roaming = 3 }).crystal, false, "...but not on Gold")
eq(context("crystal", {}).battleType, nil,
  "an ordinary wild battle reports no battle type")
eq(context("crystal", { battleType = 12 }).battleType, 12,
  "the Tin Tower script's own loadvar rides through")

eq(BattleMusic.battleSong(context("crystal", { roaming = 3 })),
  "Music_SuicuneBattle", "a beast fights to Suicune's theme in Crystal")
eq(BattleMusic.battleSong(context("gold", { roaming = 3 })),
  "Music_JohtoWildBattle", "and to the ordinary wild theme in Gold")

T.finish("gen2_roamer_battle_music_bug1928")
