-- engine/menus/start_sub_menus.asm:97-104
-- engine/pokemon/status_screen.asm:82, home/pokemon.asm:186
--   luajit tests/engine/status_screen_white_hold_2060.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local rects = {}
local color = { 1, 1, 1, 1 }
love = love or {}
love.graphics = {
  setColor = function(r, g, b, a) color = { r, g, b, a or 1 } end,
  rectangle = function(_, x, y, w, h)
    rects[#rects + 1] = { x = x, y = y, w = w, h = h, color = color }
  end,
  draw = function() end,
  push = function() end, pop = function() end,
  translate = function() end, scale = function() end,
}

package.loaded["src.render.Font"] = {
  draw = function() end, drawCode = function() end, drawBox = function() end,
  width = function() return 0 end,
}
package.loaded["src.render.HudTiles"] = {
  statusTile = function() end, tile = function() end, drawHPBar = function() end,
}
package.loaded["src.render.PaletteFX"] = {
  shader = function() return nil end,
  pal = function() return nil end,
  markTrueColor = function() end,
}
package.loaded["src.pokemon.Sprites"] = { path = function() return nil, false end }
local cries = {}
package.loaded["src.core.Sound"] = {
  play = function() end,
  playCry = function(_, species) cries[#cries + 1] = species end,
}
package.loaded["src.mods.Runtime"] = {
  wants = function() return false end,
  wantsHook = function() return false end,
  emit = function() end,
  call = function(_, fallback, ...) return fallback(...) end,
}
package.loaded["src.ui.Screens"] = {}

local Transition = require("src.render.Transition")
local SummaryMenu = assert(loadfile("src/ui/SummaryMenu.lua"))()

local function mkGame()
  local stack = { states = {} }
  function stack:push(s) self.states[#self.states + 1] = s end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  local input = { pressed = nil }
  function input:wasPressed(b) return self.pressed == b end
  return {
    data = {
      pokemon = { BULBASAUR = { name = "BULBASAUR", dex = 1, types = { "GRASS" } } },
      moves = {},
      statuses = nil,
    },
    save = { player = { id = 1, name = "RED" } },
    stack = stack,
    input = input,
  }
end

local function mkMon()
  return {
    nickname = "SAUR", species = "BULBASAUR", level = 5, exp = 100,
    hp = 10, stats = { hp = 10, attack = 5, defense = 5, speed = 5, special = 5 },
    moves = {},
  }
end

local game = mkGame()
local mon = mkMon()
local FRAMES = Transition.flashFrames(game)
T.check(type(FRAMES) == "number" and FRAMES > 0,
  "Transition.flashFrames reports the white_flash record's frame count")

local function step(button)
  game.input.pressed = button
  local top = game.stack:top()
  if top and top.update then top:update(1 / 60) end
  game.input.pressed = nil
end

local function fullScreenRects()
  rects = {}
  local top = game.stack:top()
  if top and top.draw then top:draw() end
  local n = 0
  for _, r in ipairs(rects) do
    if r.x == 0 and r.y == 0 and r.w == 160 and r.h == 144 then n = n + 1 end
  end
  return n
end

-- engine/pokemon/status_screen.asm:82
local screen = SummaryMenu.new(game, mon)
game.stack:push(screen)
T.eq(screen.whiteHold, FRAMES, "SummaryMenu opens with a full white hold")
T.eq(#cries, 0, "and the cry has not played yet (status_screen.asm:168-172)")
T.eq(fullScreenRects(), 2,
  "the held frame paints the page and then a white overlay on top")

for i = 1, FRAMES - 1 do
  step("a")
  T.eq(screen.whiteHold, FRAMES - i, "the hold burns one frame per update")
  T.eq(screen.page, 1, "A pressed during the hold is eaten, not a page flip")
  T.eq(#cries, 0, "the cry waits for GBPalNormal")
end

step()
T.eq(screen.whiteHold, 0, "the hold ends after its frame budget")
T.eq(#cries, 1, "PlayCry fires exactly once, at the end of the hold")
T.eq(cries[1], "BULBASAUR", "and it is this mon's cry")
T.eq(fullScreenRects(), 1, "after the hold the page draws with no overlay")

step("a")
T.eq(screen.page, 2, "A flips to page 2 once the hold is over")
T.eq(#game.stack.states, 1, "the page flip pushes nothing")

step("a")
T.eq(#game.stack.states, 2, "closing page 2 pushes the exit white-out")
local blink = game.stack:top()
T.check(blink ~= nil and blink.pages == nil and blink.isOpaque == true
  and type(blink.frames) == "number",
  "the pushed state is the opaque WhiteFlash, not a text box")
T.eq(blink.frames, FRAMES, "and it holds for the same white_flash budget")
T.eq(fullScreenRects(), 1, "the exit hold paints solid white over everything")

for i = 1, FRAMES - 1 do
  step()
  T.eq(#game.stack.states, 2,
    "the status screen is still on the stack at hold frame " .. i)
end
step()
T.eq(#game.stack.states, 0,
  "the flash and the status screen come off together (status_screen.asm:431)")
T.eq(#cries, 1, "closing does not replay the cry")

-- engine/pokemon/status_screen.asm:172
local zeroGame = mkGame()
zeroGame.data.transitions = { white_flash = { kind = "fade", frames = 0 } }
cries = {}
T.eq(Transition.flashFrames(zeroGame), 0,
  "a mod can zero the white_flash record's frames")
local zeroScreen = SummaryMenu.new(zeroGame, mkMon())
zeroGame.stack:push(zeroScreen)
T.eq(zeroScreen.whiteHold, 0, "the status screen then opens with no hold")
T.eq(#cries, 1, "and the cry still plays, immediately on entry")
T.eq(cries[1], "BULBASAUR", "and it is this mon's cry")

zeroGame.input.pressed = nil
zeroScreen:update(1 / 60)
T.eq(#cries, 1, "the zero-frame hold does not replay the cry")
T.eq(zeroScreen.page, 1, "and an idle frame does not flip the page")
zeroGame.input.pressed = "a"
zeroScreen:update(1 / 60)
zeroGame.input.pressed = nil
T.eq(zeroScreen.page, 2, "input is live at once with no hold to burn")

T.finish("status_screen_white_hold_2060")
