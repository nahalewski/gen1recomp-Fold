-- ../pokecrystal/audio/engine.asm:1987

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local bit = require("bit")
local ChipAsm = require("src.audio.ChipAsm")
local ChipSynth = require("src.core.ChipSynth")

local SAMPLES = 4096

local song = ChipAsm.song{
  channels = {
    { hw = 1, program = {
      { notetype = { speed = 8, volume = 12, fade = 2 } },
      { octave = 4 },
      { note = "C", len = 6 },
      { note = "E", len = 6 },
      { loop = { count = 0, to = 1 } },
    } },
    { hw = 2, program = {
      { notetype = { speed = 6, volume = 10, fade = 1 } },
      { octave = 3 },
      { note = "G", len = 4 },
      { note = "A", len = 8 },
      { loop = { count = 0, to = 1 } },
    } },
  },
}
song.generation = 2

local data = { audio = { generation = 2 } }

local function render(fastPath)
  ChipSynth._setMonoFastPathForTest(fastPath)
  local engine = ChipSynth.newEngine(data, song, { allowLoops = true })
  local frames = {}
  for index = 1, SAMPLES do
    local left, right = engine:sampleStereo()
    frames[index] = { left, right }
  end
  return frames, engine
end

ChipSynth.setStereo(false)

local general = render(false)
local fast, fastEngine = render(true)

check(fastEngine.monoMix,
      "a Gen 2 engine built with SOUND off takes the mono fast path")

local mismatches, sounding = 0, 0
for index = 1, SAMPLES do
  if fast[index][1] ~= general[index][1]
     or fast[index][2] ~= general[index][2] then
    mismatches = mismatches + 1
  end
  if general[index][1] ~= 0 then sounding = sounding + 1 end
end
eq(mismatches, 0, "the mono fast path is bit-identical to the general path")
check(sounding > SAMPLES / 2,
      "and the comparison ran against a song that is actually sounding")

local split = 0
for index = 1, SAMPLES do
  if fast[index][1] ~= fast[index][2] then split = split + 1 end
end
eq(split, 0, "every mono frame carries the same value in both speakers")

eq(fastEngine.hpfCapRight, fastEngine.hpfCapLeft,
   "the fast path keeps the right-hand HPF state in step")
eq(fastEngine.lpfRight, fastEngine.lpfLeft,
   "and the right-hand LPF state too")

ChipSynth._setMonoFastPathForTest(true)
local forced = ChipSynth.newEngine(data, song, { allowLoops = true })
check(forced.monoMix, "the engine starts on the fast path")
local channel = forced.channels[2]
local mask = bit.lshift(1, channel.hardware - 1)
channel.tracks = bit.lshift(mask, 4)
channel.forcePanning = true
forced:refreshMonoMix()
check(not forced.monoMix,
      "a force_stereo_panning channel drops the engine off the fast path")
local function spread(engine, count)
  local left, right = 0, 0
  for _ = 1, count do
    local l, r = engine:sampleStereo()
    left, right = left + math.abs(l), right + math.abs(r)
  end
  return left, right
end

local forcedLeft, forcedRight = spread(forced, SAMPLES)
check(forcedLeft ~= forcedRight,
      "and the general path pans that channel to one speaker")

ChipSynth.setStereo(true)
local stereo = ChipSynth.newEngine(data, song, { allowLoops = true })
check(not stereo.monoMix, "STEREO never takes the mono fast path")
stereo.channels[2].tracks = bit.lshift(1, stereo.channels[2].hardware - 1)
local stereoLeft, stereoRight = spread(stereo, SAMPLES)
check(stereoLeft ~= stereoRight,
      "a right-only track mixes differently into each speaker")

ChipSynth.setStereo(false)
ChipSynth._setMonoFastPathForTest(true)

T.finish("chip mono fast path")
