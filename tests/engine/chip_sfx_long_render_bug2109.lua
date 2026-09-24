-- ../pokered/audio/sfx/pokeflute.asm:1
--   luajit tests/engine/chip_sfx_long_render_bug2109.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check

love = require("tests.love_stub")

local ChipAsm = require("src.audio.ChipAsm")
local ChipSynth = require("src.core.ChipSynth")

local flute = ChipAsm.song{
  tempo = 0x100,
  channels = { { hw = 3, program = {
    { notetype = { speed = 12, waveLevel = 1, waveInstrument = 0 } },
    { octave = 5 },
    { note = "E", len = 2 },
    { note = "F", len = 2 },
    { note = "G", len = 4 },
    { note = "A", len = 2 },
    { note = "G", len = 2 },
    { octave = 6 },
    { note = "C", len = 4 },
    { note = "C", len = 2 },
    { note = "D", len = 2 },
    { note = "C", len = 2 },
    { octave = 5 },
    { note = "G", len = 2 },
    { note = "A", len = 2 },
    { note = "F", len = 2 },
    { note = "G", len = 8 },
    { rest = 12 },
  } } },
}
local blobData = { audio = { sfx = {}, cries = {} } }

local RATE = ChipSynth.SAMPLE_RATE
local EXPECTED = 48 * 12 / 60

local engine = ChipSynth.newEngine(blobData, flute,
  { sfx = true, allowLoops = false })
local ran = 0
while ran < RATE * 12 and not engine:finished() do
  ran = ran + 1
  engine:sample()
end
check(engine:finished(), "the flute program reaches sound_ret on its own")
check(math.abs(ran / RATE - EXPECTED) < 0.05,
  ("the program runs %.3f s (expected %.1f)"):format(ran / RATE, EXPECTED))

local sd = ChipSynth.renderEffectData(blobData, flute, {})
check(sd ~= nil, "the flute renders")
local seconds = sd and sd:getSampleCount() / RATE or 0
check(seconds >= 9.5,
  ("the rendered effect keeps the whole program: %.3f s"):format(seconds))
check(math.abs(seconds - EXPECTED) < 0.05,
  ("the rendered length matches the program: %.3f s"):format(seconds))

local capped = ChipSynth.renderEffectData(blobData, flute, { maxSeconds = 5 })
check(capped and capped:getSampleCount() == RATE * 5,
  "maxSeconds is the only thing that cuts a program short")

T.finish("long SFX render (#2109)")
