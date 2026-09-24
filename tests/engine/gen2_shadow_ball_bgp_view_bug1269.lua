-- engine/battle_anims/anim_commands.asm:1293 BattleAnim_SetBGPals
--
-- gen2_shadow_ball_bgp_bug1269.lua proves the runner lands bg.bgp; it never
-- calls BattleAnimView:present, which is where #1269 actually lived (the byte
-- was landed but nothing read it). This suite drives present() itself and
-- watches the byte GbcPalette carries while the panel is drawn -- CopyPals'
-- forward fold, not a colour-keyed pass over the finished frame (#1961).

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local sentShader = { calls = {} }
function sentShader:send(name, ...) self.calls[#self.calls + 1] = name end
love.graphics.newShader = function() return sentShader end

-- The stub's stand-in Quad has no setViewport/getViewport, which blitRow
-- (the scanline blit present() drives 144 times a frame) needs; the real
-- love.graphics.Quad has both.
love.graphics.newQuad = function(x, y, w, h)
  local q = { x = x, y = y, w = w, h = h }
  function q:setViewport(x2, y2, w2, h2) self.x, self.y, self.w, self.h = x2, y2, w2, h2 end
  function q:getViewport() return self.x, self.y, self.w, self.h end
  return q
end

local T = require("tests.harness")
local GbcPalette = require("src.render.GbcPalette")
local BattleAnimView = require("src.ui.gen2.BattleAnimView")

local bgpDuringFill = "unset"
local realRectangle = love.graphics.rectangle
love.graphics.rectangle = function(...)
  if bgpDuringFill == "unset" then bgpDuringFill = GbcPalette.bgp end
  return realRectangle(...)
end

local view = BattleAnimView.new({}, nil)
-- data/moves/animations.asm:4509 BattleAnim_ShadowBall's anim_bgp $1b, with
-- no scroll and no rBGP window queued, is exactly the frame that used to
-- fall through the old `needsCanvas`-only early-out untouched.
local runner = {
  bg = {
    bgp = 0x1b,
    lcdc = nil,
    scx = 0,
    scy = 0,
    lyStart = 0,
    lyEnd = 0,
    lyBackup = {},
  },
}

T.eq(GbcPalette.bgp, nil, "no byte standing before present")

local bgpDuringPanel = "unset"
view:present(runner, function() bgpDuringPanel = GbcPalette.bgp end, nil)

T.eq(bgpDuringPanel, 0x1b,
  "the panel is DRAWN under the byte: CopyPals' forward fold, not a repaint")
T.eq(bgpDuringFill, 0x1b,
  "the backdrop fill takes the same fold, so the screen behind goes black")
T.eq(GbcPalette.bgp, nil,
  "the byte is put back once present returns, so drawObjects is unaffected")

bgpDuringFill = "unset"
local identityRunner = {
  bg = { bgp = GbcPalette.BGP_IDENTITY, lcdc = nil, scx = 0, scy = 0,
    lyStart = 0, lyEnd = 0, lyBackup = {} },
}
local plainDrawCalled = false
view:present(identityRunner, function() plainDrawCalled = true end, nil)
T.check(plainDrawCalled, "identity rBGP takes the plain drawBg() path")
T.check(bgpDuringFill == "unset",
  "identity rBGP never bakes, so nothing is filled behind the panel")

T.finish("gen2 shadow ball bgp view bug 1269")
