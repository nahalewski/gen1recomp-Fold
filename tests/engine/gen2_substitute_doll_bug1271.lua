-- engine/battle_anims/anim_commands.asm:905-960 GetSubstitutePic

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local AnimRunner = require("src.battle.gen2.AnimRunner")
local Assets = require("src.render.Assets")
local BattleState = require("src.ui.gen2.BattleState")

local MONSTER = { getDimensions = function() return 16, 96 end }
Assets.image = function(path)
  if path == "assets/generated/sprites/monster.png" then return MONSTER end
  return nil
end

local drawn
love.graphics.draw = function(image, a, b, c)
  if type(a) == "table" then
    drawn[#drawn + 1] = { image = image, quad = a, x = b, y = c }
  else
    drawn[#drawn + 1] = { image = image, x = a, y = b }
  end
end

do
  local runner = { env = { battleTurn = 0 }, picOverride = {} }
  AnimRunner.COMMANDS.raisesub(runner)
  T.eq(runner.picOverride.player, "substitute",
    "anim_raisesub puts the doll up on the acting side")
  AnimRunner.COMMANDS.dropsub(runner)
  T.eq(runner.picOverride.player, false,
    "anim_dropsub writes false, not nil")
  T.check(runner.picOverride.player ~= nil,
    "so LowerSub reads as an override and not as `no animation running`")
end

do
  local runner = { env = { battleTurn = 1 }, picOverride = {} }
  AnimRunner.COMMANDS.raisesub(runner)
  T.eq(runner.picOverride.enemy, "substitute", "and the enemy side too")
  T.eq(runner.picOverride.player, nil, "without touching the other one")
end

local function newAnim(overrides)
  return {
    bg = { hidden = {}, picSize = {}, slide = {}, monShade = {} },
    picOverride = overrides or {},
  }
end

local function newScreen(anim)
  local image = { getDimensions = function() return 56, 56 end }
  local back = { getDimensions = function() return 48, 48 end }
  return setmetatable({
    picHidden = {}, anim = anim,
    pic = function(_, _, isBack) return isBack and back or image end,
    picScale = function() return 1 end,
    faintSink = function() return 0 end,
  }, { __index = BattleState }), image, back
end

do
  local screen = newScreen(newAnim({ enemy = "substitute" }))
  T.eq(screen:animPicState("enemy").pic, "substitute",
    "animPicState surfaces the runner's override")
end

do
  local screen, image = newScreen(newAnim({ enemy = "substitute" }))
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = {} }, false)
  T.eq(#drawn, 1, "one blit")
  T.eq(drawn[1].image, MONSTER, "the doll, not the frontpic")
  T.check(drawn[1].image ~= image, "the mon's own pic is not drawn")
  T.eq(drawn[1].x, 112, "enemy doll x, GetSubstitutePic's cols 2-3")
  T.eq(drawn[1].y, 40, "enemy doll y, rows 5-6 of the 7-tall box")
  local quad = drawn[1].quad or {}
  T.eq(quad.x, 0, "cut from the facing-DOWN frame")
  T.eq(quad.y, 0, "at the top of monster.png")
  T.eq(quad.w, 16, "16 wide")
  T.eq(quad.h, 16, "16 tall")
end

do
  local screen = newScreen(newAnim({ player = "substitute" }))
  drawn = {}
  screen:drawPic({ species = "TYPHLOSION", volatile = {} }, true)
  T.eq(#drawn, 1, "one blit")
  T.eq(drawn[1].x, 32, "player doll x, cols 2-3 of the 6-wide box")
  T.eq(drawn[1].y, 80, "player doll y, rows 4-5 of the 6-tall box")
  T.eq((drawn[1].quad or {}).y, 16, "cut from the facing-UP frame")
end

do
  local anim = newAnim({ enemy = "substitute" })
  anim.bg.slide.enemy = 8
  local screen = newScreen(anim)
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = {} }, false)
  T.eq(drawn[1].x, 120, "REMOVE_MON / ENTER_MON still slide the doll")
end

do
  local screen, image = newScreen(nil)
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = { substitute = 22 } }, false)
  T.eq(drawn[1].image, MONSTER, "with no animation running the volatile wins")
  T.check(drawn[1].image ~= image, "and the frontpic stays down")
end

do
  local screen, image = newScreen(nil)
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = {} }, false)
  T.eq(drawn[1].image, image, "no substitute, no doll")
  T.eq(drawn[1].x, 96, "the frontpic sits in its own box")
  T.eq(drawn[1].y, 0, "at hlcoord 12, 0")
end

do
  local screen, image = newScreen(newAnim({ enemy = false }))
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = { substitute = 22 } }, false)
  T.eq(drawn[1].image, image,
    "a dropsub override beats the still-standing substitute volatile")
  T.eq(drawn[1].x, 96, "and the mon is drawn in its own box")
end

do
  local screen = newScreen(newAnim({ enemy = nil }))
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = { substitute = 22 } }, false)
  T.eq(drawn[1].image, MONSTER,
    "an animation that never touched the pic leaves the doll up")
end

do
  local screen, image = newScreen(newAnim({ enemy = "transform" }))
  drawn = {}
  screen:drawPic({ species = "GASTLY", volatile = { substitute = 22 } }, false)
  T.eq(drawn[1].image, image,
    "and any other override is not the doll either")
end

T.finish("gen2 substitute doll bug 1271")
