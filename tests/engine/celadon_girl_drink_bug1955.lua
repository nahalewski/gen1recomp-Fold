-- scripts/CeladonMartRoof.asm:44

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
  soundOpts = function(_, sound, opts)
    opts = opts or {}
    opts.sound = sound
    return opts
  end,
}
package.loaded["src.core.Sound"] = {
  play = function() end,
}
local bagFull = false
local bagged, removed = {}, {}
package.loaded["src.inventory.Bag"] = {
  add = function(_, id)
    if bagFull then return false end
    bagged[#bagged + 1] = id
    return true
  end,
  remove = function(save, id, qty)
    removed[#removed + 1] = id
    save.inventory[id] = (save.inventory[id] or 0) - (qty or 1)
    if save.inventory[id] <= 0 then save.inventory[id] = nil end
  end,
}
package.loaded["src.ui.Menu"] = nil
package.loaded["src.ui.Theme"] = nil

local M = assert(loadfile("data/scripts/story4.lua"))()
local girl = M.CELADON_MART_ROOF.talk.TEXT_CELADONMARTROOF_LITTLE_GIRL

local function found(kind, pred)
  for _, c in ipairs(calls) do
    if c[1] == kind and pred(c) then return c end
  end
  return nil
end

local pressed, done
local function mkGame(inventory, flags)
  bagged, removed, done = {}, {}, false
  return {
    data = {
      text = {
        _CeladonMartRoofLittleGirlImThirstyText = "I'm thirsty!",
        _CeladonMartRoofLittleGirlGiveHerADrinkText = "Give her a drink?",
        _CeladonMartRoofLittleGirlGiveHerWhichDrinkText =
          "Give her which\ndrink?",
        _CeladonMartRoofLittleGirlYayFreshWaterText = "Yay! Fresh water!",
        _CeladonMartRoofLittleGirlReceivedTM13Text = "{PLAYER} received\nTM13!",
        _CeladonMartRoofLittleGirlTM13ExplanationText = "\fTM13 is ICE BEAM!",
        _CeladonMartRoofLittleGirlNoRoomText = "You don't have\nspace for this!",
        _CeladonMartRoofLittleGirlImNotThirstyText = "I'm not thirsty!",
      },
      items = {
        FRESH_WATER = { name = "FRESH WATER" },
        SODA_POP = { name = "SODA POP" },
        LEMONADE = { name = "LEMONADE" },
        TM_ICE_BEAM = { name = "TM13" },
        TM_ROCK_SLIDE = { name = "TM48" },
        TM_TRI_ATTACK = { name = "TM49" },
      },
    },
    save = {
      inventory = inventory,
      flags = flags or {},
      player = { name = "RED" },
    },
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

local function sayYes(game)
  local ask = game.stack:top()
  game.stack:pop()
  ask.opts.choice(true)
end

local function dismiss(game)
  local box = game.stack:pop()
  if box.onDone then box.onDone() end
  return box
end

local function open(inventory, flags)
  local game = mkGame(inventory, flags)
  girl(game, nil, nil, function() done = true end)
  return game
end

local ALL = function()
  return { FRESH_WATER = 1, SODA_POP = 1, LEMONADE = 1 }
end

do
  local game = open({})
  local box = game.stack:top()
  check(box.isTextBox and tostring(box.text):find("thirsty") ~= nil,
        "no drinks in the bag prints ImThirstyText")
  check(box.opts == nil or box.opts.choice == nil,
        "and asks nothing")
end

do
  local game = open(ALL())
  local ask = game.stack:top()
  check(ask.isTextBox and ask.opts.choice ~= nil,
        "with drinks in the bag, YesNoChoice follows GiveHerADrinkText")

  sayYes(game)
  local which = game.stack:top()
  check(which.isTextBox and tostring(which.text):find("which") ~= nil,
        "YES prints GiveHerWhichDrinkText")
  check(which.opts.instant == true, "BIT_NO_TEXT_DELAY: no typewriter")
  check(which.opts.stay ~= nil, "text_end: the box stays up, waiting for nothing")
  check(which.opts.stay.prompt ~= true, "and never prompts for a button")
  check(which.onDone == nil, "so nothing pops it on A")

  which.opts.stay.onShown()
  local menu = game.stack:top()
  check(menu ~= which and menu.items ~= nil, "the drink list opens over it")
  check(menu.isOpaque ~= true, "it is not a screen of its own")
  eq(menu.title, nil, "TextBoxBorder writes no title")
  eq(menu.tx, 0, "hlcoord 0, 0")
  eq(menu.ty, 0, "row 0")
  eq(menu.tw, 14, "14 tiles wide (c = 12)")
  eq(menu.th, 8, "2n + 2 tall for three drinks")
  eq(menu.itemY, 2, "wTopMenuItemY 2")
  eq(menu.noWrap, true, "wMenuWrappingEnabled is never set")
  eq(#menu.items, 3, "wFilteredBagItems only, no CANCEL row")
  eq(menu.items[1].label, "FRESH WATER", "CeladonMartRoofDrinkList order")
  eq(menu.items[3].label, "LEMONADE", "with LEMONADE last")

  calls = {}
  menu:draw()
  for i, name in ipairs({ "FRESH WATER", "SODA POP", "LEMONADE" }) do
    local y = (2 + (i - 1) * 2) * 8
    check(found("draw", function(c)
      return c[2] == name and c[3] == 16 and c[4] == y
    end) ~= nil, name .. " sits at hlcoord 2, " .. (2 + (i - 1) * 2))
  end
  check(found("code", function(c) return c[3] == 8 end) ~= nil,
        "the cursor sits in column 1 (wTopMenuItemX)")
end

do
  local game = open(ALL())
  sayYes(game)
  game.stack:top().opts.stay.onShown()
  local which = game.stack.states[1]
  local menu = game.stack:top()

  pressed = "a"
  menu:update(1 / 60)
  pressed = nil
  eq(#game.stack.states, 3, "A on a drink keeps the list up (keepOpen)")
  eq(game.stack.states[1], which, "the which-drink box is still under it")
  eq(game.stack.states[2], menu, "with the list between it and her reply")
  local yay = game.stack:top()
  check(tostring(yay.text):find("Yay", 1, true) ~= nil,
        "and prints YayFreshWaterText")

  dismiss(game)
  eq(removed[1], "FRESH_WATER", "RemoveItemByID takes the drink")
  eq(bagged[1], "TM_ICE_BEAM", "GiveItem hands over TM13")
  local received = game.stack:top()
  check(tostring(received.text):find("received", 1, true) ~= nil,
        "then ReceivedTM13Text")
  eq(received.opts.sound, "Get_Item1", "with sound_get_item_1")
  eq(#game.stack.states, 3, "the list is still on screen")

  dismiss(game)
  local explain = game.stack:top()
  check(tostring(explain.text):find("ICE BEAM", 1, true) ~= nil,
        "then the TM13 explanation on the same text_far chain")
  eq(#game.stack.states, 3, "still with the list up")

  dismiss(game)
  eq(#game.stack.states, 0, "TextScriptEnd finally clears list and box")
  check(done, "and hands control back to the script")
  eq(game.save.flags.EVENT_GOT_TM13, true, "SetEvent EVENT_GOT_TM13")
end

do
  local game = open(ALL(), { EVENT_GOT_TM13 = true })
  sayYes(game)
  game.stack:top().opts.stay.onShown()
  local menu = game.stack:top()
  menu.items[1].onSelect()
  local box = game.stack:top()
  check(tostring(box.text):find("not thirsty", 1, true) ~= nil,
        ".alreadyGaveDrink prints ImNotThirstyText")
  eq(#removed, 0, "and takes no drink")
  eq(#bagged, 0, "and gives no TM")
  dismiss(game)
  eq(#game.stack.states, 0, "the list and the box close after it")
  check(done, "and the script resumes")
end

do
  bagFull = true
  local game = open(ALL())
  sayYes(game)
  game.stack:top().opts.stay.onShown()
  game.stack:top().items[1].onSelect()
  dismiss(game)
  local box = game.stack:top()
  check(tostring(box.text):find("space for this", 1, true) ~= nil,
        ".bagFull prints NoRoomText")
  eq(game.save.flags.EVENT_GOT_TM13, nil, "with the event still unset")
  dismiss(game)
  eq(#game.stack.states, 0, "and the list and the box close after it")
  check(done, "and the script resumes")
  bagFull = false
end

do
  local game = open(ALL())
  sayYes(game)
  game.stack:top().opts.stay.onShown()
  local menu = game.stack:top()
  eq(menu.index, 1, "the cursor starts on the first drink")
  pressed = "up"
  menu:update(1 / 60)
  pressed = nil
  eq(menu.index, 1, "Up on the first row does not wrap")

  pressed = "b"
  menu:update(1 / 60)
  pressed = nil
  eq(#game.stack.states, 0, "B closes the list and the box (bit B_PAD_B)")
  check(done, "and returns to the script")
  eq(#bagged, 0, "with nothing given")
end

do
  local game = open({ SODA_POP = 1 })
  sayYes(game)
  game.stack:top().opts.stay.onShown()
  local menu = game.stack:top()
  eq(#menu.items, 1, "only the drinks actually in the bag are listed")
  eq(menu.items[1].label, "SODA POP", "SODA POP alone")
  eq(menu.th, 4, "2n + 2 shrinks the box to four rows")
end

package.loaded["src.render.Font"] = realFont
package.loaded["src.render.TextBox"] = realTextBox
package.loaded["src.core.Sound"] = nil
package.loaded["src.inventory.Bag"] = nil
package.loaded["src.ui.Menu"] = nil
package.loaded["src.ui.Theme"] = nil
require("src.ui.Screens").invalidate()

T.finish()
