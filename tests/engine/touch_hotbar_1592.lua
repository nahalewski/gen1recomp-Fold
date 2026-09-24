
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local TC = require("src.core.TouchControls")

love.window = love.window or {}
local function setRect(w, h)
  love.window.getSafeArea = function() return 0, 0, w, h end
  love.graphics.getDimensions = function() return w, h end
  TC.layoutW, TC.layoutH, TC.layoutOx, TC.layoutOy, TC.L = nil, nil, nil, nil, nil
end


local inList = false
for _, name in ipairs(TC.CONTROLS) do
  if name == "hotbar" then inList = true end
end
check(inList, "hotbar is one of the pad's controls, so the editor can drag it")

for _, r in ipairs({ { 380, 720 }, { 800, 400 } }) do
  local L = TC.defaultLayout(r[1], r[2])
  local z = L.hotbar
  check(z ~= nil, "defaultLayout places the toggle at " .. r[1] .. "x" .. r[2])
  check(z.cx - z.w / 2 >= 0 and z.cx + z.w / 2 <= r[1],
        "the toggle sits inside the rect horizontally")
  check(z.cy - z.w / 2 >= 0 and z.cy + z.w / 2 <= r[2],
        "and vertically")
  check(z.cy < L.dpad.cy, "it is up top, clear of the thumbs")
  check(z.cx > L.dpad.cx, "and on the right")
end


TC:init()
TC.active = true
TC:ensureImages()
TC.img = TC.img or {}
setRect(380, 720)
TC:applyOptions({ touchControls = { enabled = true } })
setRect(380, 720)

local L = TC:layout()
eq(TC:hitTest(L.hotbar.cx, L.hotbar.cy), "hotbar",
   "the toggle is what a press at its centre finds")
eq(TC:hitTest(L.a.cx, L.a.cy), "a", "the face buttons are unchanged")


check(TC:hotbarStrip() ~= nil, "a strip is laid out")
check(TC:hotbarCellAt(TC:hotbarStrip()[1].x + 1, TC:hotbarStrip()[1].y + 1) == nil,
      "but nothing hits while it is folded away")

check(TC:touchpressed("t1", L.hotbar.cx, L.hotbar.cy),
      "the toggle captures its press")
check(TC.hotbarOpen, "and opens the strip")
TC:touchreleased("t1", L.hotbar.cx, L.hotbar.cy)

local cells = TC:hotbarStrip()
eq(#cells, 6, "six host keys")
local _, _, sw, sh = require("src.core.SafeArea").windowRect()
for _, cell in ipairs(cells) do
  check(cell.x >= 0 and cell.x + cell.w <= sw, cell.label .. " fits across")
  check(cell.y >= 0 and cell.y + cell.h <= sh, cell.label .. " fits down")
end


local keys = {}
local origDown, origUp = love.keypressed, love.keyreleased
love.keypressed = function(key) keys[#keys + 1] = "+" .. key end
love.keyreleased = function(key) keys[#keys + 1] = "-" .. key end

local save = cells[1]
eq(save.label, "SAVE", "the first cell is quicksave")
local cx, cy = save.x + save.w / 2, save.y + save.h / 2
local hit = TC:hotbarCellAt(cx, cy)
eq(hit and hit.ctl, save.ctl, "the open strip hit-tests its cells")
check(TC:touchpressed("t2", cx, cy), "a cell captures its press (#807)")
eq(table.concat(keys, " "), "+f1", "the press synthesizes f1 once")
TC:touchreleased("t2", cx, cy)
eq(table.concat(keys, " "), "+f1 -f1", "and the lift releases it once")

local underA = TC:layout().a
check(TC:hitTest(underA.cx, underA.cy) == "a", "fixture: A is still A")


keys = {}
check(TC:touchpressed("t3", cx, cy), "second press lands")
eq(table.concat(keys, " "), "+f1", "held")
TC:reset()
eq(table.concat(keys, " "), "+f1 -f1", "reset releases the synthesized key")
check(not TC.hotbarOpen, "and folds the strip away")

love.keypressed, love.keyreleased = origDown, origUp


TC:applyOptions({ touchControls = { enabled = true }, hotbar = false })
setRect(380, 720)
L = TC:layout()
check(not TC:hotbarShown(), "options.hotbar = false hides the toggle")
eq(TC:hitTest(L.hotbar.cx, L.hotbar.cy), nil, "nothing to hit there")
check(TC:touchpressed("t4", L.hotbar.cx, L.hotbar.cy) == nil,
      "and the press falls through to the mod pointer seam")

TC:applyOptions({ touchControls = { enabled = true }, hotbar = true })
setRect(380, 720)
check(TC:hotbarShown(), "and back on again")


L = TC:layout()
TC:setControlCenter("hotbar", L.a.cx, L.a.cy)
L = TC:layout()
eq(TC:hitTest(L.a.cx, L.a.cy), "hotbar",
   "a toggle dragged onto A is what the editor picks up there")
TC.hotbarOpen = false
check(TC:touchpressed("t5", L.a.cx, L.a.cy), "and the press goes to it too")
check(TC.hotbarOpen, "so hitTest and touchpressed agree on the overlap")
TC:touchreleased("t5", L.a.cx, L.a.cy)
TC.hotbarOpen = false
TC:clearPositions()
setRect(380, 720)


TC.img = {
  dpad = love.graphics.newImage("assets/touch/dpad.png"),
  a = love.graphics.newImage("assets/touch/a.png"),
  b = love.graphics.newImage("assets/touch/b.png"),
  start = love.graphics.newImage("assets/touch/start.png"),
  select = love.graphics.newImage("assets/touch/select.png"),
}
check(TC:visible(), "fixture: the overlay draws at all")
TC.hotbarOpen = true
check(pcall(function() TC:draw() end), "the open strip draws")
TC.hotbarOpen = false
check(pcall(function() TC:draw() end), "and so does the folded toggle")


local TouchSkin = require("src.core.TouchSkin")
TouchSkin.setActive(TouchSkin.newSkin("stub"))
check(not TC:hotbarShown(), "a skin suppresses the toggle")
TouchSkin.setActive(nil)

TC:init()
T.finish("touch_hotbar_1592")
