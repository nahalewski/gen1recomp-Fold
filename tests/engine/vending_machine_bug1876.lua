-- engine/events/vending_machine.asm (#1876)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local realFont = package.loaded["src.render.Font"]
local realTextBox = package.loaded["src.render.TextBox"]
local calls = {}
package.loaded["src.render.Font"] = {
  BORDER = { tl = 1, tr = 2, bl = 3, br = 4, h = 5, v = 6 },
  draw = function(text, x, y) calls[#calls + 1] = { "draw", text, x, y } end,
  drawCode = function(code, x, y) calls[#calls + 1] = { "code", code, x, y } end,
  drawBox = function(tx, ty, tw, th) calls[#calls + 1] = { "box", tx, ty, tw, th } end,
  width = function(text) return #tostring(text) * 8 end,
  split = function(text)
    local out = {}
    for i = 1, #tostring(text) do out[i] = i end
    return out
  end,
}
package.loaded["src.render.TextBox"] = {
  new = function(_, text, onDone, opts)
    return { text = text, onDone = onDone, opts = opts, isTextBox = true }
  end,
}
local sounds = {}
package.loaded["src.core.Sound"] = {
  play = function(_, name) sounds[#sounds + 1] = name end,
}
local bagFull = false
local bagged = {}
package.loaded["src.inventory.Bag"] = {
  add = function(_, id)
    if bagFull then return false end
    bagged[#bagged + 1] = id
    return true
  end,
}
package.loaded["src.ui.Menu"] = nil
package.loaded["src.ui.Theme"] = nil

local M = assert(loadfile("data/scripts/story4.lua"))()
local machine = M.CELADON_MART_ROOF.talk.TEXT_CELADONMARTROOF_VENDING_MACHINE1

local function found(kind, pred)
  for _, c in ipairs(calls) do
    if c[1] == kind and pred(c) then return c end
  end
  return nil
end

local pressed, done
local function mkGame(cash)
  sounds, bagged, done = {}, {}, false
  return {
    data = {
      text = {
        _VendingMachineText1 = "A vending machine!\nHere's the menu!",
        _VendingMachineText4 = "Oops, not enough\nmoney!",
        _VendingMachineText5 = "{RAM:wStringBuffer}\npopped out!",
        _VendingMachineText6 = "There's no more\nroom for stuff!",
        _VendingMachineText7 = "Not thirsty!",
      },
      items = {
        FRESH_WATER = { name = "FRESH WATER" },
        SODA_POP = { name = "SODA POP" },
        LEMONADE = { name = "LEMONADE" },
      },
    },
    save = { money = cash, inventory = {} },
    input = {
      wasPressed = function(_, b) return pressed == b end,
      isDown = function() return false end,
    },
    stack = {
      states = {},
      push = function(self, s) self.states[#self.states + 1] = s end,
      pop = function(self) return table.remove(self.states) end,
      top = function(self) return self.states[#self.states] end,
    },
  }
end

local function open(cash)
  local game = mkGame(cash)
  machine(game, nil, nil, function() done = true end)
  local intro = game.stack:top()
  return game, intro
end

do
  local game, intro = open(3000)
  check(intro.isTextBox, "talking to the sign prints VendingMachineText1")
  check(tostring(intro.text):find("vending machine", 1, true) ~= nil,
        "with the machine's own greeting")
  check(intro.opts.money ~= nil, "DisplayTextBoxID MONEY_BOX rides along")
  check(intro.opts.stay ~= nil and intro.opts.stay.prompt,
        "the greeting prompts, then stays up under the list")

  intro.opts.stay.onShown()
  local menu = game.stack:top()
  check(menu ~= intro and menu.items ~= nil, "the drink list opens over it")
  eq(menu.tx, 0, "TextBoxBorder at hlcoord 0,3")
  eq(menu.ty, 3, "row 3")
  eq(menu.tw, 14, "14 tiles wide (b=8, c=12)")
  eq(menu.th, 10, "10 tiles tall")
  eq(#menu.items, 4, "wMaxMenuItem 3: three drinks and CANCEL")
  eq(menu.items[4].label, "CANCEL", "CANCEL is the last row")
  eq(menu.noWrap, true,
     "wMenuWrappingEnabled is never set (home/window.asm:56-83)")

  calls = {}
  menu:draw()
  for i, name in ipairs({ "FRESH WATER", "SODA POP", "LEMONADE", "CANCEL" }) do
    local y = (5 + (i - 1) * 2) * 8
    check(found("draw", function(c)
      return c[2] == name and c[3] == 16 and c[4] == y
    end) ~= nil, name .. " sits at (16, " .. y .. ")")
  end
  for i, price in ipairs({ "¥200", "¥300", "¥350" }) do
    local y = (6 + (i - 1) * 2) * 8
    check(found("draw", function(c)
      return c[2] == price and c[3] == 72 and c[4] == y
    end) ~= nil, price .. " sits a row under its drink at (72, " .. y .. ")")
  end
end

do
  local game, intro = open(3000)
  intro.opts.stay.onShown()
  local menu = game.stack:top()
  menu.items[1].onSelect()
  local waiter = game.stack:top()
  check(waiter ~= menu and waiter.update ~= nil,
        "the delivery rumble runs before the text")
  eq(game.save.money, 3000, "money is still untouched during the rumble")
  for _ = 1, 120 do
    if game.stack:top() ~= waiter then break end
    waiter:update(1 / 60)
  end
  eq(#sounds, 60, "SFX_PUSH_BOULDER restarts 60 times")
  eq(sounds[1], "Push_Boulder", "and it is the boulder push, not Cut")
  check(bagged[1] == "FRESH_WATER", "the drink lands in the bag")
  eq(game.save.money, 2800, "SubBCDPredef takes the drink's price")
  local result = game.stack:top()
  check(result.isTextBox and tostring(result.text):find("popped out") ~= nil,
        "then VendingMachineText5 names the drink")
  check(tostring(result.text):find("FRESH WATER", 1, true) ~= nil,
        "out of wStringBuffer")
  check(result.opts ~= nil and result.opts.money ~= nil,
        "the money box is redrawn with the new balance")
  eq(#game.stack.states, 1,
     "the drink list and the greeting are gone by then")
  result.onDone()
  check(done, "dismissing it hands control back to the script")
end

do
  local game, intro = open(3000)
  intro.opts.stay.onShown()
  local menu = game.stack:top()
  menu.index = 4
  pressed = "a"
  menu:update(1 / 60)
  pressed = nil
  local result = game.stack:top()
  check(result.isTextBox and tostring(result.text):find("thirsty") ~= nil,
        "CANCEL prints VendingMachineText7")
  eq(#game.stack.states, 1, "with the list and the greeting closed")
  eq(#bagged, 0, "and nothing bought")

  game, intro = open(3000)
  intro.opts.stay.onShown()
  menu = game.stack:top()
  pressed = "b"
  menu:update(1 / 60)
  pressed = nil
  check(tostring(game.stack:top().text):find("thirsty") ~= nil,
        "B does the same (.notThirsty)")
end

do
  local game, intro = open(100)
  intro.opts.stay.onShown()
  game.stack:top().items[1].onSelect()
  local result = game.stack:top()
  check(tostring(result.text):find("enough", 1, true) ~= nil,
        "no money prints VendingMachineText4")
  eq(game.save.money, 100, "and spends nothing")
  eq(#bagged, 0, "and hands over no drink")

  bagFull = true
  game, intro = open(3000)
  intro.opts.stay.onShown()
  game.stack:top().items[1].onSelect()
  result = game.stack:top()
  check(tostring(result.text):find("room for stuff", 1, true) ~= nil,
        "a full bag prints VendingMachineText6")
  eq(game.save.money, 3000, "with the money untouched (.BagFull)")
  bagFull = false
end

package.loaded["src.render.Font"] = realFont
package.loaded["src.render.TextBox"] = realTextBox
package.loaded["src.core.Sound"] = nil
package.loaded["src.inventory.Bag"] = nil
package.loaded["src.ui.Menu"] = nil
package.loaded["src.ui.Theme"] = nil
require("src.ui.Screens").invalidate()

T.finish()
