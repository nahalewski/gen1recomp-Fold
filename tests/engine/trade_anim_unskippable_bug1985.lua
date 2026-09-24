package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local ids = T.fixtures.ids

local S = require("tests.harness").suite("trade anim unskippable")
local check = S.check

local Game = require("src.core.Game")
local Input = require("src.core.Input")
local StateStack = require("src.core.StateStack")
local SaveData = require("src.core.SaveData")
local Pokemon = require("src.pokemon.Pokemon")
local TradeAnim = require("src.ui.TradeAnim")

Game.data = Data
Game.input = Input; Input:init()
Game.stack = StateStack; StateStack:init()
Game.save = SaveData.newGame()
require("src.render.Font").load(Data)

local sent = Pokemon.new(Data, ids.species[1], 10)
local recv = Pokemon.new(Data, ids.species[2], 10)
recv.nickname = "DUX"
recv.ot = "TRAINER"
recv.otId = 8193

local done = false
local anim = TradeAnim.new(Game, {
  sent = sent, received = recv, enemyName = "TRAINER",
  onDone = function() done = true end,
})
Game.stack:push(anim)
if anim.enter then anim:enter() end

check(anim:skipHeld() == false, "skipHeld is false with no button held")

local frames = 0
local function mash(n)
  for _ = 1, n do
    if done then return end
    frames = frames + 1
    Input.pressed = { a = true, b = true }
    StateStack:update(1 / 60)
    Input.pressed = {}
  end
end

mash(60)
check(not done, "60 frames of A+B does not finish the cinematic")
check(anim.phase == "show_player",
  "still in show_player after 60 frames of mashing, got " .. tostring(anim.phase))
check(anim.sub == "slide",
  "Trade_ShowPlayerMon's 63-frame slide is still running, got " .. tostring(anim.sub))

local guard = 0
while not done and guard < 20000 do
  guard = guard + 1
  mash(1)
end
check(done, "the cinematic still reaches onDone on its own timers")
check(frames >= 1000,
  "the full sequence runs on cart-length delays, took " .. frames .. " frames")

S.finish()
