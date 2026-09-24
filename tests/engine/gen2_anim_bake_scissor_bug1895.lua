-- engine/battle_anims/bg_effects.asm:2638 (#1895, #1869)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local G = love.graphics

local scissor = { 112, 24, 800, 720 }
local seenInCanvas = {}
G.intersectScissor = nil
G.setScissor = function(x, y, w, h)
  if x then scissor = { x, y, w, h } else scissor = nil end
end
G.getScissor = function()
  if scissor then return scissor[1], scissor[2], scissor[3], scissor[4] end
end

local function drawBody(label)
  seenInCanvas[label] = scissor and "clipped" or "clear"
end

do
  local BattleAnimView = require("src.ui.gen2.BattleAnimView")
  local view = setmetatable({}, { __index = BattleAnimView })
  view:bake(function() drawBody("bake") end)
  T.eq(seenInCanvas.bake, "clear", "the panel bakes with no window scissor")
  T.eq(scissor and scissor[1], 112, "and the caller's scissor x comes back")
  T.eq(scissor and scissor[4], 720, "with its height")

  scissor = nil
  view:bake(function() drawBody("bake2") end)
  T.eq(seenInCanvas.bake2, "clear", "a bake with no scissor stays clear")
  T.eq(scissor, nil, "and leaves none behind")
end

do
  local BattleState = require("src.ui.gen2.BattleState")
  scissor = { 112, 24, 800, 720 }
  local state = setmetatable({
    battle = { enemy = {}, player = {} },
    animPicState = function(_, side)
      if side == "enemy" then return { lifted = { 0, 7 } } end
    end,
    drawPic = function() drawBody("lift") end,
  }, { __index = BattleState })
  state:drawLiftedRows(state.battle)
  T.eq(seenInCanvas.lift, "clear", "lifted rows bake with no window scissor")
  T.eq(scissor and scissor[1], 112, "and the caller's scissor comes back")
end

T.finish("gen2 anim bake scissor bug 1895")
