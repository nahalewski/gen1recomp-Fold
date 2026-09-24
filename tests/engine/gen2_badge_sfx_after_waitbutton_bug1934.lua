-- home/joypad.asm:292

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

local savedAudio = love.audio
love.audio = {
  newSource = function(file) return setmetatable({ file = file }, Source) end,
}

local Sound = require("src.core.Sound")
local Vm = require("src.script.gen2.Vm")
local Events = require("src.world.gen2.Events")

Sound.invalidate()

-- constants/sfx_constants.asm:11
local order = {}
for i = 1, 160 do order[i] = ("Sfx_Pad%d"):format(i) end
order[0x08 + 1] = "Sfx_ReadText2"
order[0x41 + 1] = "Sfx_Tackle"
order[0x6e + 1] = "Sfx_Elevator"
order[0x9c + 1] = "Sfx_GetBadge"

local data = {
  audio = {
    fanfares = {},
    sfxOrder = order,
    sfx = {
      Sfx_ReadText2 = { file = "sfx/readtext2.wav", generation = 2 },
      Sfx_Tackle = { file = "sfx/tackle.wav", generation = 2 },
      Sfx_Elevator = { file = "sfx/elevator.wav", generation = 2 },
      Sfx_GetBadge = { file = "sfx/getbadge.wav", generation = 2 },
    },
  },
  text = {},
}

do
  local blip = Sound.playPress(data)
  check(blip ~= nil, "the box blip sounds")
  check(Sound.play(data, "Sfx_GetBadge") == nil,
    "PlaySFX's cp e / jr c drops SFX_GET_BADGE under the $08 blip")

  Sound.dropPressSfx()
  check(not blip:isPlaying(), "the blip the cart never rang is retired")
  local badge = Sound.play(data, "Sfx_GetBadge")
  check(badge ~= nil, "and the badge fanfare now plays")
  badge:stop()
end

do
  local tackle = Sound.play(data, "Sfx_Tackle")
  check(tackle ~= nil, "the tackle sounds")
  Sound.dropPressSfx()
  check(tackle:isPlaying(), "a script sound is not a press blip")
  check(Sound.play(data, "Sfx_Elevator") == nil,
    "the elevator rumble is still dropped")
  tackle:stop()
end

do
  local gen1 = { audio = { fanfares = {}, sfx = { Press_AB = "sfx/ab.wav" } } }
  local src = Sound.playPress(gen1)
  check(src ~= nil, "the Gen 1 beep still plays")
  Sound.dropPressSfx()
  check(src:isPlaying(), "and is left alone: no wCurSFX to retire")
  src:stop()
end

do
  local TextBox = require("src.render.TextBox")
  local game = {
    save = { player = {}, options = { textSpeed = "FAST" } },
    data = data,
  }
  game.stack = {
    states = {},
    push = function(self, s) table.insert(self.states, s) end,
    pop = function(self) return table.remove(self.states) end,
    top = function(self) return self.states[#self.states] end,
  }
  game.input = {
    queue = {},
    wasPressed = function(self, btn) return self.queue[btn] or false end,
    isDown = function(self, btn) return self.queue[btn] or false end,
  }
  local box = TextBox.new(game, "CLAIR: Here.\nTake this.")
  game.stack:push(box)
  local frames = 0
  while not box.done and frames < 600 do
    box:update(1 / 60)
    frames = frames + 1
  end
  game.input.queue.a = true
  box:update(1 / 60)
  eq(#game.stack.states, 0, "the press closed the box")
  check(Sound.play(data, "Sfx_GetBadge") == nil,
    "its blip holds the channels the way PlaySFX would read them")
  Sound.dropPressSfx()
  check(Sound.play(data, "Sfx_GetBadge") ~= nil,
    "and the script's playsound retires it first")
  Sound.waitSfxDone()
end

-- ../pokecrystal/maps/DragonShrine.asm:159-163
do
  local scripts = {
    generation = 2,
    ["s:badge"] = {
      { op = "writetext", text = "t:badge" },
      { op = "waitbutton" },
      { op = "setflag", flag = 0 },
      { op = "playsound", id = 0x9c },
      { op = "waitsfx" },
      { op = "end" },
    },
  }
  local heard = {}
  local vm = Vm.new(scripts, { ["t:badge"] = "Take the RISINGBADGE!" },
                    Events.new(), {
    showText = function(body, onDone)
      Sound.playPress(data)
      onDone()
    end,
    setFlag = function() end,
    playSound = function(id)
      Sound.dropPressSfx()
      local name = order[(id or 0) + 1]
      heard[#heard + 1] = { id, Sound.play(data, name) ~= nil }
    end,
    waitSfx = function() return not Sound.sfxBusy() end,
  })
  check(vm:start("s:badge"), "the badge script starts")
  for _ = 1, 400 do vm:update() end
  eq(#heard, 1, "playsound ran once")
  eq(heard[1][1], 0x9c, "with SFX_GET_BADGE")
  check(heard[1][2], "and the fanfare was not dropped by the box's own blip")
  Sound.waitSfxDone()
end

Sound.invalidate()
love.audio = savedAudio

T.finish("gen2 badge sfx after waitbutton bug1934")
