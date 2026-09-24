-- engine/events/halloffame.asm:270 (#1869)

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local G = love.graphics

local scissors = {}
G.intersectScissor = nil
G.setScissor = function(x, y, w, h)
  scissors[#scissors + 1] = { x = x, y = y, w = w, h = h }
end

local Chrome = require("src.ui.gen2.Chrome")

local WIN_W, WIN_H = 1280, 840
local PANEL_W, PANEL_H = Chrome.SCREEN_W * 8, Chrome.SCREEN_H * 8

local function only(label)
  T.eq(#scissors, 1, label .. " sets exactly one scissor")
  local rect = scissors[1]
  scissors = {}
  return rect or {}
end

local function checkPanel(label, scale)
  local rect = only(label)
  local ox, oy = Chrome.fitOrigin(WIN_W, WIN_H, scale)
  T.eq(rect.x, ox, label .. " clips from the panel's own origin x")
  T.eq(rect.y, oy, label .. " clips from the panel's own origin y")
  T.eq(rect.w, PANEL_W * scale, label .. " clips to the scaled panel width")
  T.eq(rect.h, PANEL_H * scale, label .. " clips to the scaled panel height")
end

do
  local scale = Chrome.fitScale(WIN_W, WIN_H)
  T.check(scale >= 1, "1280x840 fits at least one whole GB pixel per window pixel")
  local drew = false
  Chrome.withPanel(WIN_W, WIN_H, 0, 0, 0, function() drew = true end)
  T.eq(drew, true, "Chrome.withPanel runs the panel body")
  checkPanel("Chrome.withPanel", scale)

  Chrome.withPanel(WIN_W, WIN_H, 1, 1, 1, function() end, 3)
  checkPanel("an explicit panel scale", 3)

  drew = false
  Chrome.withClip(function() drew = true end)
  T.eq(drew, true, "Chrome.withClip runs the panel body")
  local rect = only("Chrome.withClip")
  T.eq(rect.x, 0, "the 1:1 clip starts at the panel origin")
  T.eq(rect.y, 0, "on both axes")
  T.eq(rect.w, PANEL_W, "and is 160 wide")
  T.eq(rect.h, PANEL_H, "by 144 tall")
end

do
  local HallOfFame = require("src.ui.gen2.HallOfFame")
  local hof = setmetatable({ drawPanel = function() end },
    { __index = HallOfFame })
  hof:drawWidescreen(WIN_W, WIN_H)
  checkPanel("HallOfFame:drawWidescreen", Chrome.fitScale(WIN_W, WIN_H))
  hof:draw()
  T.eq(only("HallOfFame:draw").w, PANEL_W, "and its 1:1 draw clips to the LCD")
end

do
  local Credits = require("src.ui.gen2.Credits")
  local credits = setmetatable({ drawPanel = function() end },
    { __index = Credits })
  credits:drawWidescreen(WIN_W, WIN_H)
  checkPanel("Credits:drawWidescreen", Chrome.fitScale(WIN_W, WIN_H))
  credits:draw()
  T.eq(only("Credits:draw").w, PANEL_W, "and its 1:1 draw clips to the LCD")
end

do
  local BattleState = require("src.ui.gen2.BattleState")
  local battle = setmetatable({ drawScene = function() end },
    { __index = BattleState })
  local scale = battle:battlePanelScale(WIN_W, WIN_H)
  battle:drawWidescreen(WIN_W, WIN_H)
  checkPanel("BattleState:drawWidescreen", scale)
  battle:draw()
  T.eq(only("BattleState:draw").w, PANEL_W, "and its 1:1 draw clips to the LCD")
end

T.finish("gen2 widescreen clip bug 1869")
