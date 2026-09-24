-- ../pokered/engine/battle/animations.asm:1722
-- ../pokered/engine/battle/animations.asm:2120
-- ../pokered/engine/battle/core.asm:1181
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local BattleState = require("src.battle.BattleState")
local Timing = require("src.core.Timing")

local fakeImg = { getWidth = function() return 40 end,
                  getHeight = function() return 40 end }

local function newStub()
  local battle = setmetatable({ picFx = {}, fx = {} }, BattleState)
  function battle:colorMode() return false end
  function battle:sgbBattlePals() return nil end
  function battle:picImage() return fakeImg end
  return battle
end

local function recordRects(fn)
  local rects = {}
  local real = love.graphics.rectangle
  love.graphics.rectangle = function(_, x, y, w, h)
    rects[#rects + 1] = { x = x, y = y, w = w, h = h }
  end
  local ok, err = pcall(fn)
  love.graphics.rectangle = real
  if not ok then error(err, 0) end
  local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
  for _, r in ipairs(rects) do
    if r.x < x0 then x0 = r.x end
    if r.x + r.w - 1 > x1 then x1 = r.x + r.w - 1 end
    if r.y < y0 then y0 = r.y end
    if r.y + r.h - 1 > y1 then y1 = r.y + r.h - 1 end
  end
  return x0, x1, y0, y1
end

do
  local ex, ey = BattleState.picSlotOrigin(false)
  T.eq(ex, 96, "the enemy pic slot is hlcoord 12,0")
  T.eq(ey, 0, "the enemy pic slot is hlcoord 12,0")
  local px, py = BattleState.picSlotOrigin(true)
  T.eq(px, 8, "the player pic slot is hlcoord 1,5")
  T.eq(py, 40, "the player pic slot is hlcoord 1,5")

  local bx, by = BattleState.minimizedBlobOrigin(false)
  T.eq(bx, 120, "enemy blob: slot x + 3 tiles")
  T.eq(by, 34, "enemy blob: slot y + 4 tiles + 2 pixel rows")
  local qx, qy = BattleState.minimizedBlobOrigin(true)
  T.eq(qx, 32, "player blob: slot x + 3 tiles")
  T.eq(qy, 74, "player blob: slot y + 4 tiles + 2 pixel rows")
end

do
  local battle = newStub()
  local enemy = { isPlayer = false, sprite = "e" }
  local x0, x1, y0, y1 = recordRects(function()
    battle:drawMinimizedBlob(enemy, 0, 0)
  end)
  T.eq(x0, 121, "enemy blob widest row starts at x=121")
  T.eq(x1, 126, "enemy blob widest row ends at x=126")
  T.eq(y0, 34, "enemy blob top row at y=34")
  T.eq(y1, 38, "enemy blob is 5 rows tall")

  local player = { isPlayer = true, sprite = "p" }
  x0, x1, y0, y1 = recordRects(function()
    battle:drawMinimizedBlob(player, 0, 0)
  end)
  T.eq(x0, 33, "player blob widest row starts at x=33")
  T.eq(y0, 74, "player blob top row at y=74")
  T.eq(y1, 78, "player blob is 5 rows tall")
end

do
  local battle = newStub()
  local enemy = { isPlayer = false, sprite = "e" }
  local a0, a1, b0 = recordRects(function()
    battle:drawMinimizedBlob(enemy, 0, 0)
  end)
  function battle:picImage()
    return { getWidth = function() return 56 end,
             getHeight = function() return 56 end }
  end
  local c0, c1, d0 = recordRects(function()
    battle:drawMinimizedBlob(enemy, 0, 0)
  end)
  T.eq(c0, a0, "a 7x7 pic puts the blob in the same column as a 5x5")
  T.eq(c1, a1, "a 7x7 pic puts the blob in the same column as a 5x5")
  T.eq(d0, b0, "a 7x7 pic puts the blob on the same row as a 5x5")
end

do
  local battle = newStub()
  local enemy = { isPlayer = false, sprite = "e" }
  local x0, _, y0 = recordRects(function()
    battle:drawMinimizedBlob(enemy, -2, 3)
  end)
  T.eq(x0, 119, "shakeX moves the blob")
  T.eq(y0, 37, "shakeY moves the blob")
end

do
  local battle = newStub()
  local enemy = { isPlayer = false, sprite = "e" }
  T.eq(battle:faintPicKind(enemy), "pic", "a plain mon slides its own pic")

  enemy.substituteHP = 20
  T.eq(battle:faintPicKind(enemy), "doll", "a substitute slides the doll")

  battle.picFx[enemy] = { minimized = true }
  T.eq(battle:faintPicKind(enemy), "blob", "minimize wins over the doll")

  enemy.substituteHP = nil
  T.eq(battle:faintPicKind(enemy), "blob", "a minimized mon slides its blob")
end

do
  local battle = newStub()
  local enemy = { isPlayer = false, sprite = "e" }
  battle.picFx[enemy] = { minimized = true }
  battle.fx = { faint = { battler = enemy, frames = 7 } }
  T.check(battle:fxFaintActive(enemy), "the slide is armed")

  local got
  function battle:drawMinimizedBlob(b, sx, sy) got = { b = b, sx = sx, sy = sy } end
  local drew = false
  local realDraw = love.graphics.draw
  love.graphics.draw = function() drew = true end
  local ok, err = pcall(function() battle:drawBattlerPic(enemy, 104, 16, 1, 0, 0) end)
  love.graphics.draw = realDraw
  if not ok then error(err, 0) end

  T.check(got ~= nil, "the faint slide draws the blob, not the mon pic")
  T.check(not drew, "the mon's own pic never reappears for the slide")
  T.eq(got.sy, (Timing.FAINT_SLIDE - 7) * Timing.FAINT_SLIDE_STEP,
       "the blob sinks by the faint slide offset")
end

do
  local battle = newStub()
  local enemy = { isPlayer = false, sprite = "e", substituteHP = 20 }
  battle.fx = { faint = { battler = enemy, frames = 7 } }
  local got
  function battle:drawSubstituteDoll(b, dx, dy) got = { b = b, dx = dx, dy = dy } end
  battle:drawBattlerPic(enemy, 104, 16, 1, 0, 0)
  T.check(got ~= nil, "a mon fainting behind a substitute slides the doll")
  T.eq(got.dy, (Timing.FAINT_SLIDE - 7) * Timing.FAINT_SLIDE_STEP,
       "the doll sinks by the faint slide offset")
end
