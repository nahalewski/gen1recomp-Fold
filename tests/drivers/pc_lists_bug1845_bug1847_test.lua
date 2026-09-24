-- The four PC list screens: the player's PC item lists (#1845) and Bill's
-- PC mon lists plus CHANGE BOX (#1847).  Both are LIST_MENU_BOX screens in
-- the original (home/list_menu.asm:29-31, engine/menus/save.asm:437-506),
-- not full-screen lists of their own.
--   SHOT_DIR=/tmp/pc_lists POKEPORT_DRIVER=tests/drivers/pc_lists_bug1845_bug1847_test.lua POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local Boxes = require("src.pokemon.Boxes")
  local BoxMenu = require("src.ui.BoxMenu")
  local Font = require("src.render.Font")
  local ListMenu = require("src.ui.ListMenu")
  local Menu = require("src.ui.Menu")
  local PlayerPC = require("src.ui.PlayerPC")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")

  local pass = true
  local function check(label, ok)
    if ok then U.log("PASS", label) else pass = false; U.log("FAIL", label) end
    return ok
  end

  -- record every Font.drawBox/Font.draw of one frame so the geometry can be
  -- asserted instead of eyeballed
  local function capture()
    local out = {}
    local savedDraw, savedBox = Font.draw, Font.drawBox
    Font.draw = function(text, x, y)
      out[#out + 1] = { kind = "text", text = tostring(text), x = x, y = y }
      return savedDraw(text, x, y)
    end
    Font.drawBox = function(tx, ty, tw, th)
      out[#out + 1] = { kind = "box", tx = tx, ty = ty, tw = tw, th = th }
      return savedBox(tx, ty, tw, th)
    end
    game.stack:draw()
    Font.draw, Font.drawBox = savedDraw, savedBox
    return out
  end

  local function hasBox(drawn, tx, ty, tw, th)
    for _, d in ipairs(drawn) do
      if d.kind == "box" and d.tx == tx and d.ty == ty
         and d.tw == tw and d.th == th then return true end
    end
    return false
  end

  local function textOnRow(drawn, y)
    for _, d in ipairs(drawn) do
      if d.kind == "text" and d.y == y and d.text ~= "" then return d end
    end
    return nil
  end

  local function hasText(drawn, want)
    for _, d in ipairs(drawn) do
      if d.kind == "text" and d.text == want then return d end
    end
    return nil
  end

  -- pokered data/maps/objects/ViridianPokecenter.asm keeps the floor east of
  -- the counter free; the PC itself is a hidden object, so the screens are
  -- pushed directly rather than bumped into
  local MAP, STAND = "VIRIDIAN_POKECENTER", { x = 13, y = 4 }
  U.teleport(game, MAP, STAND.x, STAND.y, "up")
  U.wait(6)
  local function freeNeighbour(ow)
    for dy = -2, 2 do
      for dx = -2, 2 do
        local cx, cy = STAND.x + dx, STAND.y + dy
        if ow.map:isWalkableCell(cx, cy) and not ow:npcAtCell(cx, cy) then
          return cx, cy
        end
      end
    end
  end
  local ow = game.overworld
  if ow and ow.map and not ow.map:isWalkableCell(STAND.x, STAND.y) then
    local cx, cy = freeNeighbour(ow)
    if cx then
      U.log("stand cell blocked, standing on", cx, cy)
      U.teleport(game, MAP, cx, cy, "up")
      U.wait(6)
    end
  end

  -- #1845: the player's PC item lists
  game.save.pcItems = { POTION = 3, ANTIDOTE = 1, REPEL = 5, ESCAPE_ROPE = 2 }
  game.stack:push(PlayerPC.new(game))
  U.wait(4)
  U.tap(game, "a") -- WITHDRAW ITEM
  U.wait(6)
  local list = game.stack:top()
  check("WITHDRAW ITEM opened a list", getmetatable(list) == ListMenu)
  if getmetatable(list) == ListMenu then
    check("the list is drawn as LIST_MENU_BOX, not a screen", list.itemBox == true)
    check("the PC menu underneath stays visible", list.isOpaque == false)
    check("PrintListMenuEntries' four rows", list.rows == 4)
    check("the list ends on the CANCEL terminator",
          list.items[#list.items].cancel == true)
    check("the withdraw prompt is up before anything is chosen",
          type(list.footer) == "string" and list.footer:find("withdraw", 1, true) ~= nil)
    local drawn = capture()
    check("LIST_MENU_BOX at tile 4,2 (16x11)", hasBox(drawn, 4, 2, 16, 11))
    check("the prompt's text box at tile 0,12 (20x6)", hasBox(drawn, 0, 12, 20, 6))
    check("nothing on the invented title row (y=4)", textOnRow(drawn, 4) == nil)
    local name = hasText(drawn, list.items[1].label)
    check("first name at hlcoord 6,4 (48,32)",
          name ~= nil and name.x == 48 and name.y == 32)
  end
  U.shot(game, DIR .. "/pc_1845_withdraw_item.png")
  U.tap(game, "b") -- back to the PC menu
  U.wait(4)
  U.tap(game, "down"); U.tap(game, "down"); U.tap(game, "down")
  U.wait(2)
  U.tap(game, "a") -- LOG OFF
  U.wait(6)

  -- #1847: Bill's PC mon lists and CHANGE BOX
  local boxes = Boxes.ensure(game.save)
  boxes[1] = {
    Pokemon.new(game.data, "PIDGEY", 12),
    Pokemon.new(game.data, "RATTATA", 7),
    Pokemon.new(game.data, "NIDORAN_M", 15),
    Pokemon.new(game.data, "ZUBAT", 9),
    Pokemon.new(game.data, "ONIX", 22),
  }
  boxes[3] = { Pokemon.new(game.data, "MAGIKARP", 5) }
  game.save.currentBox = 1
  game.save.party = { Pokemon.new(game.data, "CHARMANDER", 14) }
  game.stack:push(BoxMenu.new(game))
  U.wait(4)
  U.tap(game, "a") -- WITHDRAW POKéMON
  U.wait(6)
  local mons = game.stack:top()
  check("WITHDRAW POKéMON opened a list", getmetatable(mons) == ListMenu)
  if getmetatable(mons) == ListMenu then
    check("the mon list is drawn as LIST_MENU_BOX", mons.itemBox == true)
    check("the mon list ends on CANCEL",
          mons.items[#mons.items].cancel == true)
    check("the level is a row of its own, not part of the name",
          mons.items[1].sub == ":L12"
          and mons.items[1].label:find(":L") == nil)
    local drawn = capture()
    check("LIST_MENU_BOX at tile 4,2 (16x11)", hasBox(drawn, 4, 2, 16, 11))
    check("no invented BOX 1 (WITHDRAW) title",
          hasText(drawn, "BOX 1 (WITHDRAW)") == nil)
    local lvl = hasText(drawn, ":L12")
    check("PrintLevel one row down, 8 columns right (112,40)",
          lvl ~= nil and lvl.x == 112 and lvl.y == 40)
  end
  U.shot(game, DIR .. "/pc_1847_withdraw_mon.png")
  U.tap(game, "b")
  U.wait(4)

  U.tap(game, "down"); U.tap(game, "down"); U.tap(game, "down")
  U.wait(2)
  U.tap(game, "a") -- CHANGE BOX
  U.wait(30)
  local ask = game.stack:top()
  check("CHANGE BOX asks before it shows the box list",
        getmetatable(ask) == TextBox)
  U.shot(game, DIR .. "/pc_1847_change_box_prompt.png")
  -- page through "When you change a POKéMON BOX..." and take the YES
  local function isPicker(s)
    return getmetatable(s) == Menu and s.kind == "pc_box_change"
  end
  for _ = 1, 12 do
    if isPicker(game.stack:top()) then break end
    U.tap(game, "a")
    U.wait(12)
  end
  local picker = game.stack:top()
  check("YES opens the box picker", isPicker(picker))
  if isPicker(picker) then
    check("twelve boxes", #picker.items == 12)
    check("BoxNames spelling", picker.items[1].label == "BOX 1"
          and picker.items[12].label == "BOX12")
    check("the cursor starts on the current box",
          picker.index == game.save.currentBox)
    local drawn = capture()
    check("box list at tile 11,0 (9x14)", hasBox(drawn, 11, 0, 9, 14))
    check("BOX No. panel at tile 0,0 (11x4)", hasBox(drawn, 0, 0, 11, 4))
    local first = hasText(drawn, "BOX 1")
    check("BoxNames at hlcoord 13,1 (104,8)",
          first ~= nil and first.x == 104 and first.y == 8)
  end
  U.shot(game, DIR .. "/pc_1847_change_box.png")

  U.log(pass and "RESULT: ALL PASS" or "RESULT: SEE FAILURES ABOVE")
  U.log("On screen now: the CHANGE BOX picker. BOX 1..BOX12 sit in a tall")
  U.log("box on the right, BOX No. 1 in a small panel top-left, and a")
  U.log("pokeball marks BOX 1 and BOX 3 only, the two that hold POKéMON.")
  U.log("The near-miss to watch for is a marker on all twelve boxes, or on")
  U.log("none, and BOX10-12 spelled with the space of BOX 1 to BOX 9.")
  U.log("Shots are in " .. DIR .. "; the two list shots must show the")
  U.log("PC menu and the What? box around a bordered list, never a white")
  U.log("page with a title row.")

  while true do
    coroutine.yield()
  end
end
