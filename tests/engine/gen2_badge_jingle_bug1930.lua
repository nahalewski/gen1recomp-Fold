-- home/audio.asm:225

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local playing = {}
local Source = {}
Source.__index = Source
function Source:play() playing[self] = true end
function Source:stop() playing[self] = nil end
function Source:isPlaying() return playing[self] == true end
function Source:setVolume(v) self.volume = v end
function Source:setPitch(p) self.pitch = p end
function Source:getDuration() return self.duration end
function Source:tell() return self.pos end

local Mute = {}
Mute.__index = Mute
function Mute:play() playing[self] = true end
function Mute:stop() playing[self] = nil end
function Mute:isPlaying() return playing[self] == true end
function Mute:setVolume(v) self.volume = v end
function Mute:setPitch(p) self.pitch = p end

local savedAudio = love.audio
love.audio = {
  newSource = function(file)
    local meta = file == "sfx/mute.wav" and Mute or Source
    return setmetatable({ file = file, duration = 0, pos = 0 }, meta)
  end,
}

local Sound = require("src.core.Sound")
local Vm = require("src.script.gen2.Vm")
local Events = require("src.world.gen2.Events")

Sound.invalidate()

local order = {}
for i = 1, 160 do order[i] = ("Sfx_Pad%d"):format(i) end
order[0x9c + 1] = "Sfx_GetBadge"
order[0x9b + 1] = "Sfx_Mute"

local data = {
  audio = {
    fanfares = {},
    sfxOrder = order,
    sfx = {
      Sfx_GetBadge = { file = "sfx/getbadge.wav", generation = 2 },
      Sfx_Mute = { file = "sfx/mute.wav", generation = 2 },
    },
  },
}


eq(Sound.sfxRemaining(), 0, "nothing sounding leaves nothing to wait on")

do
  -- audio/sfx.asm
  local badge = Sound.play(data, "Sfx_GetBadge")
  check(badge ~= nil, "the fanfare plays")
  badge.duration, badge.pos = 4.017, 1.0
  local left = Sound.sfxRemaining()
  check(left and math.abs(left - 3.017) < 1e-6,
    "sfxRemaining reads the tail off the source")
  check(math.ceil(4.017 * 60) > 180,
    "and 241 frames is past the old flat cap")

  badge.pos = 4.017
  eq(Sound.sfxRemaining(), 0, "a finished source has no tail")
  badge:stop()
  eq(Sound.sfxRemaining(), 0, "nor does a stopped one")
end

do
  local mute = Sound.play(data, "Sfx_Mute")
  check(mute ~= nil, "a source that cannot be measured still plays")
  eq(Sound.sfxRemaining(), nil, "and answers nil, not a guess")
  mute:stop()
end


local RISINGBADGE = 7

local function badgeVm(hooks)
  local scripts = {
    generation = 2,
    ["s:badge"] = {
      { op = "playsound", id = 0x9c },
      { op = "waitsfx" },
      { op = "setevent", event = RISINGBADGE },
      { op = "end" },
    },
  }
  local events = Events.new()
  local vm = Vm.new(scripts, {}, events, hooks)
  return vm, events
end

do
  local busyFor = 241
  local ticks = 0
  local vm, events = badgeVm({
    playSound = function() end,
    waitSfx = function() return ticks >= busyFor end,
    waitSfxCap = function() return 271 end,
  })
  check(vm:start("s:badge"), "the badge script starts")
  eq(vm.waitSfxLeft, 271, "the park is capped by the sound, not by 180")

  while ticks < 180 do
    vm:update()
    ticks = ticks + 1
  end
  check(not events:get(RISINGBADGE),
    "the old 180-frame cap no longer walks out from under the fanfare")
  while ticks < busyFor do
    vm:update()
    ticks = ticks + 1
  end
  check(not events:get(RISINGBADGE), "still parked on the last busy frame")
  vm:update()
  check(events:get(RISINGBADGE),
    "and moves on the frame the fanfare ends")
end

do
  local vm = badgeVm({
    playSound = function() end,
    waitSfx = function() return false end,
  })
  vm:start("s:badge")
  eq(vm.waitSfxLeft, 180, "with no cap hook the old guard is the fallback")
end

do
  local vm = badgeVm({
    playSound = function() end,
    waitSfx = function() return false end,
    waitSfxCap = function() return nil end,
  })
  vm:start("s:badge")
  eq(vm.waitSfxLeft, 180, "so is a cap nothing could measure")
end

do
  local vm, events = badgeVm({
    playSound = function() end,
    waitSfx = function() return false end,
    waitSfxCap = function() return 271 end,
  })
  vm:start("s:badge")
  for _ = 1, 271 do vm:update() end
  check(events:get(RISINGBADGE), "a runaway sound does not hang the vm")
end

Sound.invalidate()
love.audio = savedAudio

T.finish("gen2 badge jingle bug1930")
