-- The wall TOWN MAP prints TownMapText before the map screen opens (#1330).
-- engine/events/hidden_events/town_map.asm:1
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local screenPushes = {}
package.loaded["src.ui.Screens"] = {
  push = function(_, id, opts)
    screenPushes[#screenPushes + 1] = { id = id, opts = opts }
  end,
}

local OW = require("src.world.OverworldController")

local function setUpvalue(fn, name, val)
  local i = 1
  while true do
    local n = debug.getupvalue(fn, i)
    if not n then return false end
    if n == name then debug.setupvalue(fn, i, val); return true end
    i = i + 1
  end
end

local pushed
local textBoxStub = {
  new = function(_, text, onDone, opts)
    return { text = text, onDone = onDone, opts = opts }
  end,
}
local fakeGame = {
  data = { text = { _TownMapText = "A TOWN MAP." } },
  stack = { push = function(_, box) pushed = box end },
}
T.check(setUpvalue(OW.tryBookshelf, "TextBox", textBoxStub),
  "TextBox upvalue on tryBookshelf")
T.check(setUpvalue(OW.tryBookshelf, "Game", fakeGame),
  "Game upvalue on tryBookshelf")

local map = {
  def = { tileset = "HOUSE" },
  inBounds = function() return true end,
  cellTile = function() return 0x3D end,
}
local fakeSelf = setmetatable({ player = { facing = "up" }, map = map },
  { __index = OW })

pushed, screenPushes = nil, {}
local result = fakeSelf:tryBookshelf(5, 2)
T.eq(result, true, "tryBookshelf consumes the wall TOWN MAP tile")
T.check(pushed ~= nil, "a text box was pushed")
T.eq(pushed.text, "A TOWN MAP.", "the box carries TownMapText")
T.eq(#screenPushes, 0, "the TownMap screen has not opened yet")
T.check(type(pushed.onDone) == "function", "the box has an onDone")

pushed.onDone()
T.eq(#screenPushes, 1, "onDone is what opens the screen")
T.eq(screenPushes[1].id, "TownMap", "the pushed screen id is TownMap")

-- a screen id a mod removed must not crash the interaction
pushed, screenPushes = nil, {}
package.loaded["src.ui.Screens"].push = function() error("no such screen") end
fakeSelf:tryBookshelf(5, 2)
local ok = pcall(pushed.onDone)
T.check(ok, "Screens.push stays wrapped in pcall")

T.finish("town_map_bookshelf_bug1330")
