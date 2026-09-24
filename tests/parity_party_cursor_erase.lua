-- engine/items/item_effects.asm:1226-1238, engine/menus/party_menu.asm:8-13
-- engine/menus/start_sub_menus.asm:285-295, home/window.asm:119
-- Self-contained; run via `luajit tests/parity_party_cursor_erase.lua`.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end
local S = require("tests.harness").suite("parity party cursor erase")
local check, eq = S.check, S.eq

local Data = require("src.core.Data")
Data:load()

local Pokemon = require("src.pokemon.Pokemon")
local Bag = require("src.inventory.Bag")

local realTextBox = package.loaded["src.render.TextBox"]
local realBag = package.loaded["src.ui.BagMenu"]
local realParty = package.loaded["src.ui.PartyMenu"]
local soundOpts = require("src.render.TextBox").soundOpts
package.loaded["src.render.TextBox"] = {
  new = function(_, text, done) return { textBox = true, text = text, done = done } end,
  soundOpts = soundOpts,
}
package.loaded["src.ui.BagMenu"] = nil
package.loaded["src.ui.PartyMenu"] = nil
local BagMenu = require("src.ui.BagMenu")
local PartyMenu = require("src.ui.PartyMenu")
require("src.ui.Screens").invalidate()

local function newStack()
  local stack = { states = {} }
  function stack:push(s) self.states[#self.states + 1] = s end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  return stack
end

local function newInput()
  local input = { pressed = nil }
  function input:wasPressed(b) return self.pressed == b end
  return input
end

local function freshGame(hp)
  local lead = Pokemon.new(Data, "CHARIZARD", 50)
  lead.hp = hp
  local game = {
    data = Data,
    stack = newStack(),
    input = newInput(),
    save = {
      party = { lead },
      player = { name = "RED" },
      inventory = {},
      options = { battleStyle = "set", battleAnim = "on" },
      pokedex = { seen = {}, owned = {} },
      flags = {},
      money = 0,
    },
  }
  Bag.add(game.save, "POTION", 5)
  return game, lead
end

local function isPicker(s) return getmetatable(s) == PartyMenu end
local function isBox(s) return type(s) == "table" and s.textBox == true end

local function rowFor(list, id)
  for i, r in ipairs(list.items) do
    if r.value == id then return i end
  end
  return nil
end

local function usePotion(game, list)
  local row = rowFor(list, "POTION")
  if not row then return nil, "no POTION row in the bag" end
  list.index = row
  list.onChoose(list.items[row], list)
  local sub = game.stack:top()
  if sub and sub.items and sub.items[1] and sub.items[1].onSelect then
    game.stack:pop()
    sub.items[1].onSelect()
  end
  local picker = game.stack:top()
  if not isPicker(picker) then return nil, "party picker never opened" end
  game.input.pressed = "a"
  picker:update(1 / 60)
  game.input.pressed = nil
  return picker
end

do
  local game, lead = freshGame(1)
  local list = BagMenu.new(game, {})
  game.stack:push(list)

  local picker, why = usePotion(game, list)
  check(isPicker(picker), "the party picker opened for POTION" ..
        (why and (" (" .. why .. ")") or ""))
  check(type(picker.heal) == "table", "UpdateHPBar2's fill is running")
  check(picker.cursorsErased ~= true, "the cursor is still drawn while the bar fills")

  local frames = 0
  while picker.heal and frames < 400 do
    picker:update(1 / 60)
    frames = frames + 1
  end
  check(frames > 1 and frames < 400, "the fill landed")
  eq(lead.hp, 21, "the POTION restored 20 HP")

  local box = game.stack:top()
  check(isBox(box), "the message box opened over the picker")
  check(isPicker(game.stack.states[2]), "the party menu is still the backdrop")
  check(picker.cursorsErased == true,
        "the menu cursor is erased while the message prints (#2062)")

  picker:update(1 / 60)
  check(picker.cursorsErased == nil,
        "the cursor comes back the frame the picker reads input again")
end

do
  local game, lead = freshGame(nil)
  lead.hp = lead.stats.hp
  local list = BagMenu.new(game, {})
  game.stack:push(list)

  local picker = usePotion(game, list)
  check(isPicker(picker), "the picker opened for the full-HP mon")
  check(picker.heal == nil, "no fill for a refusal")
  check(isBox(game.stack:top()), "the no-effect message opened")
  check(picker.cursorsErased ~= true,
        "the refusal leaves the cursor alone (ItemUseNoEffect, no RedrawPartyMenu)")
  eq(game.save.inventory.POTION, 5, "and the POTION was not consumed")
end

do
  local game = freshGame(10)
  local picker = PartyMenu.new(game, { pickOnly = true })
  check(type(picker.eraseCursors) == "function", "PartyMenu:eraseCursors exists")
  check(picker.cursorsErased == nil, "a fresh picker draws its cursor")
end

package.loaded["src.render.TextBox"] = realTextBox
package.loaded["src.ui.BagMenu"] = realBag
package.loaded["src.ui.PartyMenu"] = realParty
require("src.ui.Screens").invalidate()
S.finish()
