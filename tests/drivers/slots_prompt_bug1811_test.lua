-- Manual check of the Game Corner slot prompt, emote and menus (#1811).
-- PromptUserToPlaySlots prints "Want to play?" and floats SMILE_BUBBLE over
-- the player on the map, and only then loads the slot screen, whose bet menu
-- is hlcoord 14,11 b=5 c=4 (engine/slots/slot_machine.asm:9-23, :83-86).
-- Box geometry is asserted in tests/engine/slot_machine_boxes_bug1811.lua.
--   POKEPORT_DRIVER=tests/drivers/slots_prompt_bug1811_test.lua POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local TextBox = require("src.render.TextBox")
  local SlotMachine = require("src.ui.SlotMachine")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local vol = game.save.options and game.save.options.sfxVol
  if vol == 0 then
    U.log("sfx volume is 0 in options; raise it or the menu beeps are silent")
  end

  -- AbleToPlaySlotsCheck wants a COIN CASE with coins in it
  game.save.inventory = game.save.inventory or {}
  game.save.inventory.COIN_CASE = 1
  game.save.coins = math.max(game.save.coins or 0, 50)

  -- the seats are hidden events on the machine tiles (data/events/
  -- hidden_events.asm StartSlotMachine); stand on any walkable neighbour
  local seats = (game.data.field.slotMachines or {}).GAME_CORNER or {}
  local placed = nil
  U.teleport(game, "GAME_CORNER", 9, 15, "down")
  local ow = game.overworld
  local sides = {
    { 0, 1, "up" }, { 0, -1, "down" }, { 1, 0, "left" }, { -1, 0, "right" },
  }
  for _, seat in ipairs(seats) do
    if seat.state == "ok" then
      for _, s in ipairs(sides) do
        local cx, cy = seat.x + s[1], seat.y + s[2]
        if ow.map:isWalkableCell(cx, cy) and not ow:npcAtCell(cx, cy) then
          U.teleport(game, "GAME_CORNER", cx, cy, s[3])
          U.wait(10)
          ow = game.overworld
          local fx, fy = ow.player:facingCell()
          if fx == seat.x and fy == seat.y then
            placed = { seat = seat, x = cx, y = cy, facing = s[3] }
          end
          break
        end
      end
    end
    if placed then break end
  end
  check("standing at a working slot machine", placed ~= nil)
  if placed then
    U.log(("machine at (%d, %d), player at (%d, %d) facing %s")
            :format(placed.seat.x, placed.seat.y, placed.x, placed.y,
                    placed.facing))
  end

  U.tap(game, "a")
  U.wait(30)
  local top = game.stack:top()
  local isBox = getmetatable(top) == TextBox
  check("A opens a text box, not the slot screen", isBox)
  check("the slot screen is not on the stack yet",
        getmetatable(top) ~= SlotMachine)
  if isBox then
    local shown = {}
    for _, page in ipairs(top.pages or {}) do
      for _, line in ipairs(page) do shown[#shown + 1] = line end
    end
    U.log("box reads:", table.concat(shown, " / "))
  end
  U.shot(game, SHOT_DIR .. "/bug1811_prompt.png")

  -- through the text, then YES
  for _ = 1, 8 do
    if game.overworld.emote then break end
    U.tap(game, "a")
    U.wait(12)
  end
  U.wait(4)
  local emote = game.overworld.emote
  check("YES floats an emotion bubble over the player", emote ~= nil)
  check("it is SMILE_BUBBLE, the third crop", emote and emote.bubble == 3)
  check("and it is over the player, not an NPC",
        emote and emote.npc == game.overworld.player)
  U.shot(game, SHOT_DIR .. "/bug1811_smile.png")

  for _ = 1, 120 do
    if getmetatable(game.stack:top()) == SlotMachine then break end
    U.wait(2)
  end
  local slots = game.stack:top()
  check("the slot screen opens after the bubble",
        getmetatable(slots) == SlotMachine)
  check("and it opens on the bet menu", slots.stage == "bet")
  U.wait(10)
  U.shot(game, SHOT_DIR .. "/bug1811_bet.png")
  U.log("captured", SHOT_DIR .. "/bug1811_{prompt,smile,bet}.png")

  U.log("Right: the prompt box sits over the still-drawn Game Corner floor,")
  U.log("then a smiley pops over the player, then the machine appears with a")
  U.log("bet menu whose bottom edge is the last row of the screen.  The")
  U.log("near-miss is the machine already drawn behind the prompt, or a bet")
  U.log("box two rows short of the bottom.")

  while true do
    coroutine.yield()
  end
end
