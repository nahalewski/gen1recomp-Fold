-- Party submenu box geometry (#1819) with PokemonMenuEntries in full (#1833).
-- pokered anchors this box to the bottom row of the screen and grows it
-- upward two rows per field move, indenting it by the widest field move name
-- (engine/menus/text_box.asm:397-440, data/moves/field_moves.asm,
-- data/text_boxes.asm:33).
--   POKEPORT_DRIVER=tests/drivers/party_submenu_box_bug1819_test.lua POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local Font = require("src.render.Font")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local mon = Pokemon.new(game.data, "CHANSEY", 40)
  game.save.party = { mon }
  game.save.player.name = "bryan"
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  -- record the boxes one real draw pass puts on screen; the submenu is the
  -- only one that does not start at column 0
  local function boxThisFrame()
    local seen = {}
    local real = Font.drawBox
    Font.drawBox = function(tx, ty, tw, th, ...)
      seen[#seen + 1] = { tx, ty, tw, th }
      return real(tx, ty, tw, th, ...)
    end
    U.wait(2)
    Font.drawBox = real
    for i = #seen, 1, -1 do
      if seen[i][1] > 0 then return seen[i] end
    end
    return nil
  end

  local function openSubmenu(moves)
    mon.moves = moves
    Screens.push(game, "PartyMenu", {})
    U.wait(12)
    U.tap(game, "a")
    U.wait(12)
    return game.stack:top()
  end

  local function closeSubmenu()
    U.tap(game, "b")
    U.wait(8)
    U.tap(game, "b")
    U.wait(8)
  end

  local function move(id)
    local def = game.data.moves[id]
    return { id = id, pp = def and def.pp or 10 }
  end

  -- tx, ty, tw, th the port should hand Font.drawBox, per case
  local cases = {
    { name = "no field moves", shot = "bug1819_submenu_plain.png",
      moves = { move("POUND") }, rows = 3, box = { 11, 11, 9, 7 } },
    { name = "one field move (STRENGTH indents to tile 10)",
      shot = "bug1819_submenu_strength.png",
      moves = { move("STRENGTH") }, rows = 4, box = { 9, 8, 11, 10 } },
    { name = "SOFTBOILED, the widest name (tile 8)",
      shot = "bug1819_submenu_softboiled.png",
      moves = { move("SOFTBOILED") }, rows = 4, box = { 7, 8, 13, 10 } },
  }

  for _, c in ipairs(cases) do
    local pm = openSubmenu(c.moves)
    local ok = pm and pm.submenu
    check(c.name .. ": the submenu opened", ok == true)
    if ok then
      local labels = {}
      for i, e in ipairs(pm.subItems) do labels[i] = e.label end
      U.log(c.name .. " lists:", table.concat(labels, " / "))
      check(c.name .. ": " .. c.rows .. " rows ending in CANCEL",
            #pm.subItems == c.rows
              and pm.subItems[#pm.subItems].action == "cancel")
      local b = boxThisFrame()
      if not b then
        check(c.name .. ": a submenu box was drawn", false)
      else
        U.log(c.name .. " box tx,ty,tw,th:", b[1], b[2], b[3], b[4])
        check(c.name .. ": box is " .. table.concat(c.box, ","),
              b[1] == c.box[1] and b[2] == c.box[2]
                and b[3] == c.box[3] and b[4] == c.box[4])
        check(c.name .. ": its bottom border is on tile row 17",
              b[2] + b[4] - 1 == 17)
        check(c.name .. ": its right edge is on tile column 19",
              b[1] + b[3] - 1 == 19)
      end
      U.shot(game, SHOT_DIR .. "/" .. c.shot)
      U.log("captured", SHOT_DIR .. "/" .. c.shot)
    end
    closeSubmenu()
  end

  -- leave the last one up for the eye
  openSubmenu({ move("SOFTBOILED") })

  U.log("The submenu on screen should sit flush against the bottom of the")
  U.log("screen, its lower border sharing the screen's last pixel row, with")
  U.log("SOFTBOILED / STATS / SWITCH / CANCEL inside it and one blank row")
  U.log("above SOFTBOILED. The near-miss to watch for is an 8px gap under")
  U.log("the box that shows the message box's own bottom line, so the two")
  U.log("borders read as a doubled or detached line.")

  while true do
    coroutine.yield()
  end
end
