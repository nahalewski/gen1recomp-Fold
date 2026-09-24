-- engine/pokemon/learn.asm:135-166
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

local Chrome = require("src.ui.gen2.Chrome")
local ForgetMoveList = require("src.ui.gen2.ForgetMoveList")
local MoveDeleter = require("src.ui.gen2.MoveDeleter")

local L = ForgetMoveList
T.same({ L.x, L.y, L.interiorW, L.interiorH }, { 5, 2, 13, 8 },
  "ForgetMove's Textbox is (5,2) with NUM_MOVES*2 x MOVE_NAME_LENGTH inside")
T.same({ L.nameX, L.y0, L.step, L.cursorX }, { 7, 4, 2, 6 },
  "names run from (7,4) every two rows with the cursor in column 6")

local boxes, texts, cursors
local function spy()
  boxes, texts, cursors = {}, {}, {}
  Chrome.box = function(tx, ty, tw, th)
    boxes[#boxes + 1] = { tx, ty, tw, th }
  end
  Chrome.print = function(text, tx, ty)
    texts[#texts + 1] = { text, tx, ty }
  end
  Chrome.printThrough = function(text, tx, ty)
    texts[#texts + 1] = { text, tx, ty }
  end
  Chrome.printRightThrough = function(text, tx, ty)
    texts[#texts + 1] = { text, tx, ty }
  end
  Chrome.cursor = function(tx, ty) cursors[#cursors + 1] = { tx, ty } end
  Chrome.cursorThrough = function(tx, ty) cursors[#cursors + 1] = { tx, ty } end
end

local MOVE_DATA = {
  TACKLE = { name = "TACKLE" },
  SURF = { name = "SURF" },
}
local function twoMoves()
  return { { id = "TACKLE", pp = 30, maxPp = 35 },
    { id = "SURF", pp = 1, maxPp = 15 } }
end

spy()
ForgetMoveList.draw(twoMoves(), 2, MOVE_DATA)

T.same(boxes[1], { 5, 2, 15, 10 },
  "the list opens its own 15x10 box over the player HUD")
T.eq(#boxes, 1, "nothing else is boxed")
T.same(texts[1], { "TACKLE", 7, 4 }, "first name at (7,4)")
T.same(texts[2], { "SURF", 7, 6 }, "second name two rows down")
T.same(texts[3], { "-", 7, 8 }, "ListMoves fills an empty slot with '-'")
T.same(texts[4], { "-", 7, 10 }, "fourth row is drawn too")
T.eq(#texts, 4, "names only -- ListMoves prints no PP")
T.same(cursors, { { 6, 6 } }, "the cursor sits on its row in column 6")

spy()
local forget = MoveDeleter.new(nil, {
  mon = { moves = twoMoves() }, moves = MOVE_DATA, layout = "forget",
})
forget:draw()
T.same(boxes[1], { 5, 2, 15, 10 }, "the learn-move list uses ForgetMove's box")
T.eq(#texts, 4, "the learn-move list prints names only")

spy()
local deleter = MoveDeleter.new(nil, {
  mon = { moves = twoMoves() }, moves = MOVE_DATA,
})
deleter:draw()
T.same(boxes[1], { 0, 1, 20, 11 }, "the Blackthorn deleter keeps its own box")
T.check(#texts > 4, "the Blackthorn deleter keeps its PP column")

local pressed
local function stubInput(state)
  state.game = { input = { wasPressed = function(_, btn)
    return btn == pressed
  end } }
end

stubInput(forget)
forget.row = 1
pressed = "up"
forget:update(0)
T.eq(forget.row, 2, "ForgetMove's list wraps up to the last move")

stubInput(deleter)
deleter.row = 1
pressed = "up"
deleter:update(0)
T.eq(deleter.row, 1, "the Blackthorn deleter still stops at the top")

T.finish()
