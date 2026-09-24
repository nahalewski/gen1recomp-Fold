-- GetMapMusic (pokegold home/map.asm:2550), #1385
--   luajit tests/engine/gen2_rocket_map_music_bug1385.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local Source = {}
Source.__index = Source
function Source:play() self.playing = true end
function Source:stop() self.playing = false end
function Source:pause() self.playing = false end
function Source:isPlaying() return self.playing end
function Source:setLooping() end
function Source:setVolume(v) self.volume = v end
function Source:setPitch() end
function Source:setFilter() end
function Source:getDuration() return 1 end

local made = {}
love.audio = {
  newSource = function(file, mode)
    made[file] = setmetatable({ file = file, mode = mode }, Source)
    return made[file]
  end,
}

local World = require("src.world.gen2.World")
local Music = require("src.core.Music")

-- constants/music_constants.asm:100,:109
local MUSIC_MAHOGANY_MART = 100
local RADIO_TOWER_SENTINEL = 0x80 + 61

local order = {}
order[61 + 1] = "Music_GoldenrodCity"
local audio = {
  musicOrder = order,
  songs = {
    Music_RocketHideout = { file = "rocket_hideout.wav" },
    Music_CherrygroveCity = { file = "cherrygrove.wav" },
    Music_RocketTheme = { file = "rocket_theme.wav" },
    Music_GoldenrodCity = { file = "goldenrod.wav" },
  },
}

eq(World.mapMusicLabel(audio, MUSIC_MAHOGANY_MART, true, false),
  "Music_RocketHideout",
  "MAHOGANY_MART_1F with rockets in the mart plays the hideout theme")
eq(World.mapMusicLabel(audio, MUSIC_MAHOGANY_MART, false, false),
  "Music_CherrygroveCity",
  "MAHOGANY_MART_1F after the hideout is cleared plays Cherrygrove")
eq(World.mapMusicLabel(audio, RADIO_TOWER_SENTINEL, false, true),
  "Music_RocketTheme",
  "RADIO_TOWER floors during the takeover play the rocket theme")
eq(World.mapMusicLabel(audio, RADIO_TOWER_SENTINEL, false, false),
  "Music_GoldenrodCity",
  "RADIO_TOWER floors otherwise fall back to the low bits of the byte")
eq(World.mapMusicLabel(audio, 72, true, true), nil,
  "a plain song id stays with the mapSongs table")
eq(World.mapMusicLabel(audio, nil, true, true), nil,
  "a missing music byte resolves to nothing")

local data = { audio = {
  songs = {
    Music_RocketHideout = { file = "rocket_hideout.wav" },
    Music_Victory = { file = "victory.wav" },
  },
  mapSongs = {},
} }

local function playing()
  for file, src in pairs(made) do
    if src.playing then return file end
  end
  return "(silence)"
end

Music.stop()
Music.playMap(data, "MAHOGANY_MART_1F", false, false, nil,
  "Music_RocketHideout")
eq(playing(), "rocket_hideout.wav",
  "the resolved song overrides the empty mapSongs table")

Music.play(data, "Music_Victory", nil, { reason = "battle" })
eq(playing(), "victory.wav", "the battle result theme takes over")
Music.restoreMap(data)
eq(playing(), "rocket_hideout.wav",
  "restoreMap replays the resolved song, ending the victory loop")

T.finish("gen2_rocket_map_music_bug1385")
