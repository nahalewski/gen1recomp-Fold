-- scripts/MtMoonPokecenter.asm:30-34
-- Museum1F.asm:72-79

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Commands = require("src.script.Commands")
local TextBox = require("src.render.TextBox")

local function newGame()
  local game = { save = { player = {}, money = 5326 }, data = { text = {} } }
  game.stack = {
    states = {},
    push = function(self, s) table.insert(self.states, s) end,
    pop = function(self) return table.remove(self.states) end,
    top = function(self) return self.states[#self.states] end,
  }
  game.input = {
    wasPressed = function() return false end,
    isDown = function() return false end,
  }
  return game
end

local function askWith(moneyOpt)
  local game = newGame()
  game.data.text.TEST_DEAL = "MAN: Hello, there!\nHave I got a deal"
  local runner = { yield = function() end, resume = function() end }
  local ctx = { game = game, runner = runner, save = game.save }
  Commands.text_opts(ctx, { money = moneyOpt })
  Commands.ask(ctx, "TEST_DEAL")
  return game, game.stack:top()
end

local game, box = askWith("choice")
check(getmetatable(box) == TextBox, "the pitch is a TextBox")
check(type(box.money) == "function", "money = \"choice\" still arms the live wallet reader")
eq(box.money(), 5326, "the reader returns the save's money")
check(box.moneyWithChoice, "money = \"choice\" defers the box to the YES/NO menu")
check(not box:moneyVisible(), "no money box on the first frame of the offer")

for _ = 1, 600 do
  if box.done then break end
  box:update(1 / 60)
  check(not box:moneyVisible(), "no money box while the offer is typing")
end
check(box.done, "the offer finished typing")
check(not box:moneyVisible(), "still no money box on the frame typing ends")

box:update(1 / 60)
eq(#game.stack.states, 2, "the YES/NO box is up")
check(box:moneyVisible(), "the money box appears on the same frame as the menu")

local game2, box2 = askWith(true)
check(not box2.moneyWithChoice, "money = true is unchanged")
check(box2:moneyVisible(), "Museum-style money = true draws from frame 1")
eq(box2.money(), 5326, "money = true still reads the live wallet")
eq(#game2.stack.states, 1, "only the text box is up before the menu")

local plain = TextBox.new(newGame(), "hi", nil, {})
check(not plain:moneyVisible(), "a box with no money opt never draws one")

T.finish("magikarp_money_box_bug1983")
