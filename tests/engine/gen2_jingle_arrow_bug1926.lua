-- TextCommand_PROMPT_BUTTON's LoadBlinkingCursor (home/text.asm:749)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local TextBox = require("src.render.TextBox")
local Sound = require("src.core.Sound")

local busy = true
local realBusy, realPlay = Sound.sfxBusy, Sound.play
Sound.sfxBusy = function() return busy end
Sound.play = function() return nil end

local function newGame()
  local game = {
    save = { player = {}, options = { textSpeed = "FAST" } },
    data = { text = {} },
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

do
  local game = newGame()
  local popped = false
  local box = TextBox.new(game, "GOLD put the POTION\nin the ITEM POCKET.",
                          function() popped = true end, { sfxWait = true })
  game.stack:push(box)

  local frames = 0
  while not box.done and frames < 600 do
    box:update(1 / 60)
    frames = frames + 1
  end
  check(box.done, "the page finished typing")
  check(not box:arrowVisible(), "no arrow while the jingle is still ringing")

  game.input.queue.a = true
  box:update(1 / 60)
  check(not popped, "and A does not advance it either")
  check(not box:arrowVisible(), "the arrow is still refused")
  game.input.queue.b = true
  box:update(1 / 60)
  check(not popped, "nor does B")
  game.input.queue.a, game.input.queue.b = false, false

  busy = false
  box:update(1 / 60)
  check(box.sfxWait == nil, "the hold is released the frame the sfx ends")
  check(box:arrowVisible(), "and the arrow appears")
  game.input.queue.a = true
  box:update(1 / 60)
  check(popped, "the press the arrow advertises now works")
end

do
  local game = newGame()
  busy = true
  local box = TextBox.new(game, "GOLD put the POTION\nin the ITEM POCKET.",
                          nil, { sfxWait = true })
  box.waiting = true
  check(not box:arrowVisible(), "a mid-text page break waits for the jingle")
  box.sfxWait = nil
  check(box:arrowVisible(), "and prints the arrow once it has stopped")
end

do
  local game = newGame()
  busy = true
  local box = TextBox.new(game, "GOLD put the POTION\nin the ITEM POCKET.")
  local frames = 0
  while not box.done and frames < 600 do
    box:update(1 / 60)
    frames = frames + 1
  end
  check(box:arrowVisible(), "a plain finished box still blinks its arrow")
  box.choice = function() end
  check(not box:arrowVisible(), "a choice box still does not")
  box.choice = nil
  box.stay = {}
  check(not box:arrowVisible(), "and neither does a stay box with no prompt")
  box.stay = { prompt = true }
  check(box:arrowVisible(), "a stay box that prompts does")
end

Sound.sfxBusy, Sound.play = realBusy, realPlay

eq(TextBox.new(newGame(), "hi").sfxWait, nil,
  "sfxWait is opt-in; no Gen 1 caller sets it")

T.finish("gen2 jingle arrow bug1926")
