
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local TouchSkin = require("src.core.TouchSkin")
local Studio = require("src.ui.SkinStudio")
local Kit = require("src.ui.kit.Kit")

local oldDims = love.graphics.getDimensions
local oldSafe = love.window.getSafeArea
local oldThumb, oldSummary = Studio.libraryThumb, Studio.skinSummary
Studio.libraryThumb = function() return nil end
Studio.skinSummary = function() return "12 buttons  2 pages" end

local SIZES = {
  { 1600, 720, "1600x720 landscape phone" },
  { 2400, 1080, "2400x1080 landscape phone" },
  { 1280, 720, "1280x720" },
  { 1920, 1080, "1920x1080" },
  { 720, 1600, "720x1600 portrait phone" },
  { 400, 800, "400x800 small portrait" },
}

local function open(w, h, n)
  love.graphics.getDimensions = function() return w, h end
  love.window.getSafeArea = function() return 0, 0, w, h end
  Studio.skin = TouchSkin.newSkin("t")
  Studio.mode = "library"
  Studio.modal, Studio.confirm = nil, nil
  Studio.available = {}
  for i = 1, n do
    Studio.available[i] = { id = "skin" .. i, source = "user" }
  end
  Studio.libraryScroll, Studio.libraryScrollMax = 0, 0
  Studio.libraryPress = nil
end

local function inside(r, f)
  return r.x >= f.x - 0.5 and r.y >= f.y - 0.5
    and r.x + r.w <= f.x + f.w + 0.5 and r.y + r.h <= f.y + f.h + 0.5
end

local function tappable(r)
  if not r.clip then return { x = r.x, y = r.y, w = r.w, h = r.h } end
  local x1 = math.max(r.x, r.clip.x)
  local y1 = math.max(r.y, r.clip.y)
  local x2 = math.min(r.x + r.w, r.clip.x + r.clip.w)
  local y2 = math.min(r.y + r.h, r.clip.y + r.clip.h)
  if x2 <= x1 or y2 <= y1 then return nil end
  return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

for _, size in ipairs(SIZES) do
  local w, h, label = size[1], size[2], size[3]
  local frame = { x = 0, y = 0, w = w, h = h }
  for _, n in ipairs({ 3, 9 }) do
    open(w, h, n)
    Kit.audit = {}
    check(pcall(Studio.draw), label .. " with " .. n .. " skins draws")

    local escaped = nil
    for _, r in ipairs(Kit.audit or {}) do
      local vis = tappable(r)
      if vis and not inside(vis, frame) then escaped = r.label end
    end
    eq(escaped, nil, label .. "/" .. n
      .. ": no tappable control escapes the window")

    local maxScroll = Studio.libraryScrollMax or 0
    local reached = {}
    local step = Kit.scrollStep()
    local offset = 0
    while true do
      Studio.libraryScroll = offset
      Kit.audit = {}
      check(pcall(Studio.draw), label .. "/" .. n
        .. ": draws at scroll " .. math.floor(offset))
      local view = Studio.libraryView
      for id, r in pairs(Studio.libraryRects or {}) do
        if inside(r, view) and inside(r, frame) then reached[id] = true end
      end
      if offset >= maxScroll then break end
      offset = math.min(maxScroll, offset + step)
    end
    local missing = nil
    for i = 1, n do
      if not reached["skin" .. i] then missing = "skin" .. i end
    end
    eq(missing, nil, label .. "/" .. n
      .. ": every skin's Select can be scrolled fully into view")
  end
end

Kit.audit = nil

do
  open(1600, 720, 3)
  Studio.draw()
  eq(Studio.libraryScrollMax, 0, "three skins fit a 1600x720 window with no scroll")
  local view = Studio.libraryView
  for i = 1, 3 do
    local r = Studio.libraryRects["skin" .. i]
    check(r ~= nil and inside(r, view),
      "skin" .. i .. "'s Select is on screen at rest")
  end
end

do
  open(1600, 720, 9)
  Studio.draw()
  check((Studio.libraryScrollMax or 0) > 0,
    "nine skins overflow the same window and become scrollable")
end


do
  open(1600, 720, 9)
  Studio.draw()
  local maxScroll = Studio.libraryScrollMax
  local x, y = 800, 400

  Studio.clicked = false
  Studio.touchpressed("f1", x, y)
  eq(Studio.clicked, false, "a press in the library does not dispatch a tap")
  check(Studio.libraryPress ~= nil, "it arms a drag instead")
  Studio.touchmoved("f1", x, y - 200)
  check(Studio.libraryScroll > 0, "dragging up scrolls the list")
  eq(Studio.libraryScroll, math.min(200, maxScroll),
    "by exactly the distance the finger travelled, clamped to the extent")
  Studio.touchreleased("f1", x, y - 200)
  eq(Studio.clicked, false, "and the drag never becomes a tap on release")
  eq(Studio.libraryPress, nil, "the press is cleared")

  Studio.touchmoved("f1", x, y - 400)
  eq(Studio.libraryScroll, math.min(200, maxScroll),
    "a move after release moves nothing")

  Studio.libraryScroll = 0
  Studio.clicked = false
  Studio.touchpressed("f1", x, y)
  Studio.touchmoved("f1", x + 2, y - 2)
  eq(Studio.libraryScroll, 0, "a jitter inside the tap slop is not a drag")
  Studio.touchreleased("f1", x + 2, y - 2)
  eq(Studio.clicked, true, "a press with no travel dispatches the tap on release")
end

do
  open(1600, 720, 9)
  Studio.draw()
  Studio.libraryScroll = 0
  Studio.touchpressed("f1", 800, 400)
  Studio.touchmoved("f1", 800, 400 + 500)
  eq(Studio.libraryScroll, 0, "dragging down past the top clamps at zero")
  Studio.touchreleased("f1", 800, 900)
end

do
  open(1600, 720, 3)
  Studio.mode = "editor"
  Studio.clicked = false
  Studio.libraryPress = nil
  Studio.mousepressed(800, 400, 1)
  eq(Studio.clicked, true, "the editor still dispatches its tap on press")
  eq(Studio.libraryPress, nil, "and never arms a library drag")
end

Studio.libraryThumb, Studio.skinSummary = oldThumb, oldSummary
love.graphics.getDimensions = oldDims
love.window.getSafeArea = oldSafe

T.finish("My Skins library reach and scroll (#1912)")
