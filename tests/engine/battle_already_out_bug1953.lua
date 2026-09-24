-- engine/battle/core.asm:2396-2408
-- engine/battle/core.asm:1473-1488

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local check, eq = T.check, T.eq
local Data = T.fixtures.fresh()
require("src.render.Font").load(Data)

local BattleState = require("src.battle.BattleState")
local PartyMenu = require("src.ui.PartyMenu")
local TextBox = require("src.render.TextBox")
local Pokemon = require("src.pokemon.Pokemon")
local SaveData = require("src.core.SaveData")
local TypeChart = require("src.battle.TypeChart")
TypeChart.load(Data)

local function newGame()
  local save = SaveData.newGame()
  save.player.name = "RED"
  save.party = { Pokemon.new(Data, "FIXMON_A", 40),
                 Pokemon.new(Data, "FIXMON_B", 40) }
  local game = { data = Data, save = save }
  game.stack = {
    states = {},
    push = function(self, s) table.insert(self.states, s) end,
    pop = function(self) return table.remove(self.states) end,
    top = function(self) return self.states[#self.states] end,
  }
  game.input = {
    queue = {},
    wasPressed = function(self, btn) return self.queue[btn] or false end,
    isDown = function() return false end,
  }
  return game
end

local function press(pm, btn)
  pm.game.input.queue = { [btn] = true }
  pm:update(1 / 60)
  pm.game.input.queue = {}
end

local function pickerOpts(battle, open)
  battle.queue, battle.nextInsert = {}, 0
  battle.buildScreen = function(_, _, opts) return opts end
  open(battle)
  local opts = battle.queue[1].ui()
  battle.queue, battle.nextInsert = {}, 0
  return opts
end

local function openMenu(game, opts)
  local pm = PartyMenu.new(game, opts)
  game.stack:push(pm)
  return pm
end

do
  local game = newGame()
  local battle = BattleState.newWild(game, "FIXMON_C", 40)
  battle.rng = function(a) if a then return a end return 0 end
  local opts = pickerOpts(battle, battle.openParty)
  check(opts.keepOpen == true, "the battle picker asks to stay open")

  local pm = openMenu(game, opts)
  press(pm, "a")
  eq(pm.subItems[1].action, "battle_switch", "SWITCH leads the battle submenu")
  press(pm, "a")

  eq(#game.stack.states, 2, "the party list is still on the stack")
  eq(game.stack.states[1], pm, "underneath its own message box")
  check(getmetatable(game.stack.states[2]) == TextBox,
    "AlreadyOutText prints in the party menu's box, not the battle's")
  check(not pm.submenu, ".partyMonDeselected blanks the SWITCH/STATS/CANCEL box")
  eq(#battle.queue, 0, "and nothing is queued on the battle screen")

  game.stack:pop()
  press(pm, "down")
  press(pm, "a")
  press(pm, "a")
  eq(#game.stack.states, 0, "a real switch closes the picker (core.asm:2409)")
  check(#battle.queue > 0, "and runs SwitchPlayerMon")
end

do
  local game = newGame()
  local battle = BattleState.newWild(game, "FIXMON_C", 40)
  battle.rng = function(a) if a then return a end return 0 end
  local opts = pickerOpts(battle, battle.openParty)
  game.save.party[2].hp = 0
  local pm = openMenu(game, opts)
  press(pm, "down")
  press(pm, "a")
  press(pm, "a")
  eq(#game.stack.states, 2, "NoWillText keeps the list up too")
  check(getmetatable(game.stack.states[2]) == TextBox, "in the menu's own box")
  eq(#battle.queue, 0, "with no battle-queue round trip")
end

do
  local game = newGame()
  local battle = BattleState.newWild(game, "FIXMON_C", 40)
  battle.rng = function(a) if a then return a end return 0 end
  local opts = pickerOpts(battle, battle.openReplacementMenu)
  check(opts.keepOpen == true and opts.forceSwitch == true,
    "the replacement picker is forced and stays open")
  game.save.party[2].hp = 0
  local pm = openMenu(game, opts)
  press(pm, "down")
  press(pm, "a")
  eq(#game.stack.states, 2, "a fainted replacement prints over the list")
  check(getmetatable(game.stack.states[2]) == TextBox, "in the menu's own box")
  eq(#battle.queue, 0, "and does not reopen the menu")

  game.stack:pop()
  press(pm, "up")
  press(pm, "a")
  eq(#game.stack.states, 0, "a healthy replacement closes the picker")
  check(#battle.queue > 0, "and sends the mon out")
end

do
  local game = newGame()
  local battle = BattleState.newWild(game, "FIXMON_C", 40)
  battle.rng = function(a) if a then return a end return 0 end
  local opts = pickerOpts(battle, battle.openParty)
  opts.onSwitch(battle.player.mon)
  check(battle.queue[1] and battle.queue[1].text
        and battle.queue[1].text:find("already out", 1, true) ~= nil,
    "a nil menu falls back to the battle message")
  check(battle.queue[2] and battle.queue[2].fn ~= nil, "and the reprompt")
end

T.finish("battle party refusals (#1953)")
