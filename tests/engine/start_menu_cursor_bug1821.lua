-- The START cursor is unsaved WRAM (ram/wram.asm:238-242) and lies outside
-- sGameData (ram/sram.asm:17-21), so it must not ride the save file (#1821).
--   luajit tests/run_engine.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
require("src.render.Font").load(Data)
local SaveData = require("src.core.SaveData")
local StartMenu = require("src.ui.StartMenu")

local function stubGame(save)
  local stack = { states = {} }
  function stack:push(s) self.states[#self.states + 1] = s end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  return {
    data = Data, save = save, stack = stack,
    input = { wasPressed = function() return false end,
              isDown = function() return false end },
  }
end

do
  local save = SaveData.newGame()
  local game = stubGame(save)
  local menu = StartMenu.new(game)
  menu.index = math.min(3, #menu.items)
  menu:update(1 / 60)
  T.eq(game.startMenuIndex, menu.index, "the cursor slot lands on the game")
  T.check(save.startMenuIndex == nil, "and never on the save table")

  local reopened = StartMenu.new(stubGame(save))
  T.eq(reopened.index, 1, "a fresh session opens on the top row")

  local same = StartMenu.new(game)
  T.eq(same.index, menu.index, "the same session reopens where it was")
end

do
  local save = SaveData.newGame()
  save.startMenuIndex = 5
  local encoded = SaveData.encodeForTest and SaveData.encodeForTest(save) or nil
  T.check(encoded == nil or encoded:find("startMenuIndex") == nil,
    "no serializer writes the cursor back out")
  local game = stubGame(save)
  local menu = StartMenu.new(game)
  T.eq(menu.index, 1,
    "a legacy save file's stored slot no longer reopens the menu on it")
end

T.finish("START menu cursor is session state (#1821)")
