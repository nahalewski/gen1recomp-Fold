-- home/delay.asm:15

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Sound = require("src.core.Sound")
local TextBox = require("src.render.TextBox")

Sound.setRate(1)

local function stub(dur, playFor)
  local src = { playing = true, steps = 0, stopped = false }
  src.getDuration = function() return dur end
  src.getPitch = function() return 1 end
  src.isPlaying = function(self)
    return self.playing and (not playFor or self.steps < playFor)
  end
  src.stop = function(self) self.stopped = true; self.playing = false end
  return src
end

local function newGame(speed)
  local game = {
    save = { player = {}, options = { textSpeed = "FAST" } },
    data = { audio = { fanfares = {}, sfx = {} }, text = {} },
    logicSpeed = function() return speed end,
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
  return game
end

local budget = Sound.waitFrames(stub(1))
eq(budget, 62, "a 1 s sfx is 60 logic frames plus margin at 1X")

do
  local game = newGame(4)
  local src = stub(1, 240)
  local box = TextBox.new(game, "Hi.", nil, { preSound = function() return src end })
  game.stack:push(box)
  local held = 0
  for _ = 1, 1000 do
    if not box.preSound then break end
    box:update(1 / 60)
    if not box.preSound then break end
    src.steps = src.steps + 1
    held = held + 1
  end
  check(not src.stopped, "at 4X the preSound gate never stops a source still playing")
  eq(held, 240, "the gate holds every logic step of the sound's real length")
  eq(box.preSrc, nil, "and releases once the source goes quiet")
end

do
  local game = newGame(4)
  local src = stub(1)
  local box = TextBox.new(game, "Hi.", nil, { preSound = function() return src end })
  game.stack:push(box)
  local held = 0
  for _ = 1, budget * 4 + 200 do
    box:update(1 / 60)
    if not box.preSound then break end
    held = held + 1
  end
  check(src.stopped, "at 4X the safety stop still lands on a stuck source")
  eq(held, budget * 4 - 1, "after the same wall time, four times the logic steps")
end

do
  local game = newGame(1)
  local src = stub(1)
  local box = TextBox.new(game, "Hi.", nil, { preSound = function() return src end })
  game.stack:push(box)
  local held = 0
  for _ = 1, budget + 200 do
    box:update(1 / 60)
    if not box.preSound then break end
    held = held + 1
  end
  check(src.stopped, "at 1X a stuck source is stopped")
  eq(held, budget - 1, "after exactly the frame budget")
end

do
  local game = newGame(0 / 0)
  local src = stub(1)
  local box = TextBox.new(game, "Hi.", nil, { preSound = function() return src end })
  game.stack:push(box)
  box:update(1 / 60)
  eq(box.preSrcLeft, budget - 1, "a NaN speed decrements by a whole frame")
end

-- engine/items/item_effects.asm:1807
do
  local game = newGame(4)
  local src = stub(1, 240)
  local box = TextBox.new(game, "Hi.", nil, {
    auto = { wait = false, delay = 0, sound = function() return src end },
  })
  game.stack:push(box)
  local frames = 0
  while not box.done and frames < 600 do
    box:update(1 / 60)
    frames = frames + 1
  end
  check(box.done, "the box finishes typing")
  local held = 0
  for _ = 1, 1000 do
    if #game.stack.states == 0 then break end
    box:update(1 / 60)
    if #game.stack.states == 0 then break end
    src.steps = src.steps + 1
    held = held + 1
  end
  check(not src.stopped, "at 4X the auto gate never stops a source still playing")
  eq(held, 240, "the auto gate holds every logic step of the sound's real length")
  eq(#game.stack.states, 0, "and the box pops once the source goes quiet")
end

do
  local game = newGame(4)
  local src = stub(1)
  local box = TextBox.new(game, "Hi.", nil, {
    auto = { wait = false, delay = 0, sound = function() return src end },
  })
  game.stack:push(box)
  local frames = 0
  while not box.done and frames < 600 do
    box:update(1 / 60)
    frames = frames + 1
  end
  local held = 0
  for _ = 1, budget * 4 + 200 do
    box:update(1 / 60)
    if #game.stack.states == 0 then break end
    held = held + 1
  end
  check(src.stopped, "at 4X a stuck auto source is still stopped")
  eq(held, budget * 4 - 1, "after four times the logic steps")
end

T.finish("textbox_sfx_speed_bug2087")
