-- ../pokecrystal/engine/gfx/load_pics.asm:105-158

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local Assets = require("src.render.Assets")
local UI = require("src.ui.gen2.BattleState")

local FRONT = "assets/generated/battle/front/cyndaquil.png"
local SHEET = "assets/generated/battle/anim/cyndaquil.png"
local MOD_FRONT = "mods/skin/overrides/battle/front/cyndaquil.png"
local MOD_SHEET = "mods/skin/overrides/battle/anim/cyndaquil.png"

local image = { getDimensions = function() return 40, 200 end }
Assets.image = function() return image end

local overrides = {}
Assets.resolve = function(path) return overrides[path] or path end

local mon = { species = "CYNDAQUIL" }
local anim = { sheet = SHEET, tiles = 5, play = { { 1 } } }

local function newSelf(picPath)
  local self = setmetatable({
    pokemon = { CYNDAQUIL = { spriteFront = FRONT, anim = anim } },
    picCache = {},
  }, { __index = UI })
  if picPath then
    self.pic = function() return image, false, picPath end
  end
  return self
end

-- Stock cache, no mod: the sheet still animates.
do
  overrides = {}
  local s = newSelf()
  s:startFrontAnim(mon)
  T.check(s.frontAnim ~= nil, "an unmodded Crystal front pic still animates")
  T.eq(s.frontAnim and s.frontAnim.sheet, image, "off the extracted sheet")
end

-- Gold and Silver have no anim row at all and never reach any of this.
do
  overrides = {}
  local s = newSelf()
  s.pokemon.CYNDAQUIL.anim = nil
  s:startFrontAnim(mon)
  T.eq(s.frontAnim, nil, "a cache with no anim row is untouched")
  s.pokemon.CYNDAQUIL.anim = anim
end

-- The bug: the static pic replaced, the sheet left stock.  Holding the static
-- pic for the whole scene is the only way not to flicker stock art over it.
do
  overrides = { [FRONT] = MOD_FRONT }
  local s = newSelf()
  s:startFrontAnim(mon)
  T.eq(s.frontAnim, nil, "an overridden front pic suppresses the stock frames")
end

do
  overrides = {}
  local s = newSelf(MOD_FRONT)
  s:startFrontAnim(mon)
  T.eq(s.frontAnim, nil, "a pokemon.sprite path also suppresses them")
end

-- A mod that ships both halves keeps its animation.
do
  overrides = { [FRONT] = MOD_FRONT, [SHEET] = MOD_SHEET }
  local s = newSelf()
  s:startFrontAnim(mon)
  T.check(s.frontAnim ~= nil, "a mod that ships a sheet as well still animates")
end

T.finish("gen2 front anim mod sheet bug 1827")
