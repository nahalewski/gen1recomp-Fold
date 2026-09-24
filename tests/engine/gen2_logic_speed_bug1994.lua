
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Game2 = require("src.core.Game2")

local function game(fields)
  return setmetatable(fields or {}, { __index = Game2 })
end

eq(game():logicSpeed(), 1, "a bare game with no options at all is 1X")
eq(game({ options = {} }):logicSpeed(), 1, "options with no speed is 1X")
eq(game({ options = { speed = 4 } }):logicSpeed(), 4,
  "the saved GAME SPEED option is the ordinary source")
eq(game({ options = { speed = 4 }, speedOverride = 10 }):logicSpeed(), 10,
  "speedOverride (--speed/POKEPORT_SPEED) wins over the saved option")
eq(game({ options = { speed = "8" } }):logicSpeed(), 8,
  "a string from the options file is coerced")
eq(game({ options = { speed = 0 } }):logicSpeed(), 1, "0X is floored to 1X")
eq(game({ options = { speed = -5 } }):logicSpeed(), 1,
  "and so is a negative")
eq(game({ options = { speed = "fast" } }):logicSpeed(), 1,
  "an unparseable option falls back rather than erroring")

local Gen2Compat = require("src.mods.Gen2Compat")
local live = game({ options = { speed = 4 } })
Gen2Compat.bind(function() return live end)
local Facade = Gen2Compat.resolve("src.core.Game", "bug1994")
eq(Facade.logicSpeed(), 4, "the Gen 1 facade reports the engine's own speed")
live.speedOverride = 10
eq(Facade.logicSpeed(), 10, "and follows it when it changes")
Gen2Compat.bind(function() return nil end)
eq(Facade.logicSpeed(), 1, "with no live game the facade still answers 1X")
check(Facade.logicSpeed() >= 1, "and never below 1")

T.finish("gen2 logic speed bug 1994")
