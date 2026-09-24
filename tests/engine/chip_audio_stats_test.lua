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
function Source:setLooping(v) self.looping = v end
function Source:setVolume(v) self.volume = v end
function Source:setPitch(v) self.pitch = v end
function Source:setFilter() end
function Source:getDuration() return 1 end
function Source:getFreeBufferCount() return self.free end
function Source:queue() self.free = math.max(0, self.free - 1) end

local ChipSynth = require("src.core.ChipSynth")
local BUFFERS = ChipSynth.MUSIC_BUFFER_COUNT

function Source:drain(n) self.free = math.min(BUFFERS, self.free + n) end

local sources = {}
love.audio = {
  newSource = function(what, mode)
    return setmetatable({ file = what, mode = mode, free = 0 }, Source)
  end,
  newQueueableSource = function()
    local src = setmetatable({ queueable = true, free = BUFFERS }, Source)
    sources[#sources + 1] = src
    return src
  end,
}

local channels = {}
local lastGen = 0
local Channel = {}
Channel.__index = Channel
function Channel:push(msg)
  if type(msg) == "table" and msg.cmd == "play" then lastGen = msg.gen end
  self.queue[#self.queue + 1] = msg
end
function Channel:pop() return table.remove(self.queue, 1) end
function Channel:clear() self.queue = {} end
function Channel:getCount() return #self.queue end

local function channel(name)
  channels[name] = channels[name] or setmetatable({ queue = {} }, Channel)
  return channels[name]
end

love.thread = {
  newThread = function()
    return { start = function() end, getError = function() return nil end,
             wait = function() end }
  end,
  getChannel = channel,
}

local ChipAudio = require("src.core.ChipAudio")
local PREROLL = ChipAudio.MUSIC_PREROLL

local ChipAsm = require("src.audio.ChipAsm")
local song = ChipAsm.song{
  channels = { { hw = 1, program = {
    { notetype = { speed = 12, volume = 12, fade = 0 } },
    { octave = 4 },
    { note = "C", len = 8 },
    { loop = { count = 0, to = 1 } },
  } } },
}
local data = { audio = { songs = { Music_PalletTown = song } } }

local idle = ChipAudio.stats()
check(type(idle) == "table" and type(idle.line) == "string",
      "stats() returns a table with a one-line summary")
eq(idle.rate, ChipSynth.SAMPLE_RATE, "the line leads with the live synth rate")
check(idle.line:find("rate=" .. ChipSynth.SAMPLE_RATE, 1, true) ~= nil,
      "and the rate is in the line: " .. idle.line)
check(idle.line:find("worker=", 1, true) ~= nil,
      "the line names which runtime the worker got")

ChipAudio._setAudioStatsForTest(false)
check(ChipAudio.playMusic(data, song, true) ~= nil, "a song is streaming")
local src = sources[#sources]

local function deliver(n, extra)
  for _ = 1, (n or 1) do
    local buf = { gen = lastGen, sd = true }
    if extra then for key, value in pairs(extra) do buf[key] = value end end
    channel("chipaudio_out"):push(buf)
  end
end

deliver(PREROLL, { jit = true, xrt = 0.125 })
ChipAudio.update()

local playing = ChipAudio.stats()
eq(playing.worker, "jit",
   "a buffer that reports jit.status() true shows worker=jit")
eq(playing.xrt, 0.125, "and carries the worker's own cost per buffer")
eq(playing.depth, PREROLL, "the live queue depth is reported")
eq(playing.depthMin, PREROLL, "so is the low-water mark")
check(playing.line:find("xrt=0.125", 1, true) ~= nil,
      "the line formats xrt: " .. playing.line)

src:drain(PREROLL)
src.playing = false
for _ = 1, 30 do ChipAudio.update() end
local dry = ChipAudio.stats()
eq(dry.underruns, 30,
   "an ungated session counts every frame the queue ran dry")
eq(dry.depthMin, 0, "and remembers the queue hit zero")
eq(dry.restarts, 0, "nothing restarted while there was nothing to play")

deliver(PREROLL, { jit = false, xrt = 0.9 })
ChipAudio.update()
ChipAudio.ensureMusicPlaying()
local recovered = ChipAudio.stats()
eq(recovered.restarts, 1, "the restart the reporter hears as a gap is counted")
eq(recovered.worker, "interp",
   "a worker that could not turn the JIT on reads as interp")
check(recovered.line:find("underruns=30", 1, true) ~= nil
      and recovered.line:find("restarts=1", 1, true) ~= nil,
      "both counters reach the line: " .. recovered.line)

local IssueReport = require("src.core.IssueReport")
local SaveData = require("src.core.SaveData")
local _, fields = IssueReport.build(SaveData.defaultOptions(), {})
check(type(fields.extra) == "string"
      and fields.extra:find("\n- Audio: ", 1, true) ~= nil,
      "the copyable diagnostics block carries an Audio row")
check(fields.extra:find("worker=", 1, true) ~= nil,
      "and that row is the stats line")

ChipAudio.stopMusic()

T.finish("chip audio stats")
