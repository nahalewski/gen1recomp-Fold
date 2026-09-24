
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = require("tests.love_stub")

local sources = {}

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

function Source:drain(n)
  self.free = math.min(BUFFERS, self.free + n)
end

local function track(src)
  sources[#sources + 1] = src
  return src
end

love.audio = {
  newSource = function(what, mode)
    return track(setmetatable({ file = what, mode = mode, free = 0 }, Source))
  end,
  newQueueableSource = function()
    return track(setmetatable({ queueable = true, free = BUFFERS }, Source))
  end,
}

local channels = {}
local lastGen, lastEpoch = 0, 0

local Channel = {}
Channel.__index = Channel
function Channel:push(msg)
  if type(msg) == "table" and msg.cmd == "play" then
    lastGen, lastEpoch = msg.gen, msg.stereoEpoch or 0
  end
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
    return {
      start = function() end,
      getError = function() return nil end,
      wait = function() end,
    }
  end,
  getChannel = channel,
}

local ChipAudio = require("src.core.ChipAudio")
local Logger = require("src.core.Logger")
local PREROLL = ChipAudio.MUSIC_PREROLL

check(type(PREROLL) == "number" and PREROLL > 1,
      "ChipAudio publishes a pre-roll floor deeper than one buffer")

local function deliver(n)
  for _ = 1, (n or 1) do
    channel("chipaudio_out"):push({
      gen = lastGen, sd = true, stereoEpoch = lastEpoch })
  end
end

local function deliverDone()
  channel("chipaudio_out"):push({ gen = lastGen, done = true })
end

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

local function lastSource() return sources[#sources] end

local function newSong(allowLoops)
  for i = #sources, 1, -1 do sources[i] = nil end
  channel("chipaudio_out"):clear()
  check(ChipAudio.playMusic(data, song, allowLoops) ~= nil,
        "threaded playMusic built a queueable source")
  return lastSource()
end


local src = newSong(true)
check(not src.playing, "a fresh song is silent before any buffer lands")

for queued = 1, PREROLL - 1 do
  deliver(1)
  ChipAudio.update()
  eq(BUFFERS - src.free, queued,
     ("update queued buffer %d"):format(queued))
  check(not src.playing,
        ("a looping song is still silent on %d queued buffer(s)"):format(queued))
  check(ChipAudio.awaitingFirstBuffer(),
        "the song still reads as awaiting its first buffer")
end

deliver(1)
ChipAudio.update()
eq(BUFFERS - src.free, PREROLL, "the pre-roll is fully queued")
check(src.playing, "the looping song starts once the pre-roll is queued")
check(not ChipAudio.awaitingFirstBuffer(), "and it is no longer awaiting")


local jingle = newSong(false)
check(ChipAudio.awaitingFirstBuffer(),
      "the jingle awaits its first buffer like it always did")
deliver(1)
ChipAudio.update()
check(jingle.playing, "a playOnce jingle still starts on its first buffer")
check(not ChipAudio.awaitingFirstBuffer(),
      "and awaitingFirstBuffer clears on that same buffer")


local short = newSong(true)
deliver(1)
deliverDone()
ChipAudio.update()
check(short.playing,
      "a song the worker finished short of the pre-roll starts on what it has")


local recover = newSong(true)
deliver(PREROLL)
ChipAudio.update()
check(recover.playing, "the song is sounding before the stall")

recover:drain(PREROLL)
recover.playing = false
eq(BUFFERS - recover.free, 0, "the stall drained the queue dry")
ChipAudio.ensureMusicPlaying()
check(not recover.playing, "an empty queue is not restarted")

deliver(1)
ChipAudio.update()
ChipAudio.ensureMusicPlaying()
check(not recover.playing,
      "recovery does not restart on one buffer straight back into an underrun")

deliver(PREROLL - 1)
ChipAudio.update()
ChipAudio.ensureMusicPlaying()
check(recover.playing, "recovery restarts once the queue is pre-rolled again")


check(type(ChipAudio._setAudioStatsForTest) == "function",
      "ChipAudio exposes the audio stats counters")
ChipAudio._setAudioStatsForTest(true)

local stats = newSong(true)
local logBase = #Logger.history
deliver(PREROLL)
for _ = 1, 59 do ChipAudio.update() end
eq(#Logger.history, logBase, "the stats line does not fire before a full second")
ChipAudio.update()
local line = Logger.history[#Logger.history]
check(line ~= nil and line:find("chipaudio: depth=", 1, true) ~= nil,
      "one stats line per 60 updates: " .. tostring(line))
check(line:find(("depth=%d/%d"):format(PREROLL, BUFFERS), 1, true) ~= nil,
      "the line reports the live queue depth")
check(line:find("rate=" .. ChipSynth.SAMPLE_RATE, 1, true) ~= nil,
      "and the sample rate the source was built at")

stats:drain(PREROLL)
stats.playing = false
for _ = 1, 60 do ChipAudio.update() end
local counters = ChipAudio._audioStatsForTest()
eq(counters.underruns, 60, "a dry queue is counted as an underrun every frame")
eq(counters.restarts, 0, "nothing restarted while the queue was dry")

deliver(PREROLL)
ChipAudio.update()
ChipAudio.ensureMusicPlaying()
eq(ChipAudio._audioStatsForTest().restarts, 1,
   "the restart the reporter hears as a click is counted")

local logAfter = #Logger.history
ChipAudio._setAudioStatsForTest(false)
for _ = 1, 120 do ChipAudio.update() end
eq(ChipAudio._audioStatsForTest().frames, 120,
   "the counters keep running with the per-second log gated off")
eq(#Logger.history, logAfter,
   "and an ungated session logs nothing")

T.finish("chip audio pre-roll")
