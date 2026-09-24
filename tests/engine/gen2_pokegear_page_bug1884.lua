-- engine/pokegear/pokegear.asm:454, :740 (#1884)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
love = love or require("tests.love_stub")

local Pokegear = require("src.ui.gen2.Pokegear")

local function newInput()
  local input = { pressed = {} }
  function input:press(button) self.pressed[button] = true end
  function input:wasPressed(button)
    if self.pressed[button] then
      self.pressed[button] = nil
      return true
    end
    return false
  end
  function input:isDown() return false end
  return input
end

local function newGear(ids)
  local input = newInput()
  local cards = {}
  for index, id in ipairs(ids) do cards[index] = { id = id, label = id } end
  local gear = setmetatable({
    cards = cards, cardIndex = 1, mode = "strip", station = 1,
    game = { input = input },
  }, { __index = Pokegear })
  gear.updatePhone = function() end
  gear.stepMapCursor = function() end
  gear.ensureTuned = function() end
  gear.tickRadio = function() end
  gear.tuneRadio = function() end
  gear.stopRadio = function() end
  return gear, input
end

local function press(gear, input, button)
  input:press(button)
  gear:update(0)
end

local gear, input = newGear({ "clock", "phone" })
check(gear:card().id == "clock", "the gear opens on the clock")
press(gear, input, "right")
check(gear:card().id == "phone", "right takes the phone")
gear:update(0)
check(gear.mode == "card", "which enters its card without an A")
press(gear, input, "left")
check(gear:card().id == "clock", "left goes back to the clock")
press(gear, input, "right")
check(gear:card().id == "phone", "and the clock still pages right")

local full, fullInput = newGear({ "clock", "map", "phone", "radio" })
full.cardIndex, full.mode = 3, "card"
press(full, fullInput, "left")
check(full:card().id == "map", "the phone's left takes the map first")
press(full, fullInput, "right")
check(full:card().id == "phone", "and the map pages back")
press(full, fullInput, "right")
check(full:card().id == "radio", "the phone's right takes the radio")
press(full, fullInput, "left")
check(full:card().id == "phone", "and the radio's left takes it back")

local radioOnly, radioInput = newGear({ "clock", "radio" })
radioOnly.mode = "card"
press(radioOnly, radioInput, "right")
check(radioOnly:card().id == "radio", "the clock falls through to the radio")
press(radioOnly, radioInput, "left")
check(radioOnly:card().id == "clock", "and the radio falls back to the clock")

local left, leftInput = newGear({ "clock", "map" })
left.mode = "card"
press(left, leftInput, "left")
check(left:card().id == "clock", "left does nothing on the clock")

T.finish("gen2 pokegear paging bug 1884")
