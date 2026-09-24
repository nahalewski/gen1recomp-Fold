-- pokeyellow scripts/BillsHouse.asm:211, :232 (#1875)
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")

  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local function idle()
    while true do coroutine.yield() end
  end

  if not check("running the Yellow cache (POKEPORT_VERSION=yellow)",
               GameVersion.isYellow()) then
    U.log("Re-run with POKEPORT_VERSION=yellow; Red and Blue have no script 7/8.")
    idle()
  end

  -- data/events/hidden_events.asm: BillsHousePC is hidden_event 1,4 facing up,
  local MAP, PC_STAND = "BILLS_HOUSE", { x = 1, y = 5, facing = "up" }

  game.save.party = { Pokemon.new(game.data, "PIKACHU", 12) }
  game.save.player.name = "bryan"
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_BILL_SAID_USE_CELL_SEPARATOR = true
  game.save.flags.EVENT_USED_CELL_SEPARATOR_ON_BILL = nil
  game.save.flags.EVENT_MET_BILL = nil
  game.save.flags.EVENT_MET_BILL_2 = nil
  game.save.flags.EVENT_GOT_SS_TICKET = nil
  game.save.flags.EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING = nil

  U.teleport(game, MAP, PC_STAND.x, PC_STAND.y, PC_STAND.facing)
  U.wait(20)

  local ow = game.overworld
  if not check("Bill's House loaded", ow ~= nil and ow.map
               and ow.map.id == MAP) then
    idle()
  end
  check("standing on the PC cell facing up",
        ow.player.cellX == PC_STAND.x and ow.player.cellY == PC_STAND.y
        and ow.player.facing == "up")

  local startX, startY = ow.player.cellX, ow.player.cellY

  U.tap(game, "a")
  U.wait(20)
  for _ = 1, 120 do
    if game.save.flags.EVENT_USED_CELL_SEPARATOR_ON_BILL then break end
    U.tap(game, "a")
    U.wait(6)
  end
  check("the cell separator ran (EVENT_USED_CELL_SEPARATOR_ON_BILL)",
        game.save.flags.EVENT_USED_CELL_SEPARATOR_ON_BILL == true)

  for _ = 1, 900 do
    if game.save.flags.EVENT_MET_BILL_2 then break end
    U.wait(1)
  end
  check("Bill left the machine (EVENT_MET_BILL_2)",
        game.save.flags.EVENT_MET_BILL_2 == true)

  local function bill()
    for _, n in ipairs(ow.npcs or {}) do
      if n.def and n.def.name == "BILLSHOUSE_BILL1" then return n end
    end
    return nil
  end

  local b = bill()
  check("BILL1 is on the map", b ~= nil)
  if b then U.log("Bill at", b.cellX, b.cellY, "(scripts say 4,4)") end

  for _ = 1, 600 do
    if ow.player.cellX >= startX + 3 then break end
    U.wait(1)
  end
  check("the player was walked three cells east with no input",
        ow.player.cellX == startX + 3 and ow.player.cellY == startY)
  local opened = false
  for _ = 1, 300 do
    if game.stack:top() ~= ow then opened = true break end
    U.wait(1)
  end
  check("the SS Ticket text opened with no A press", opened)
  check("the player ends facing up (SPRITE_FACING_UP)",
        ow.player.facing == "up")
  if b then
    check("BILL1 was turned down to face the player", b.facing == "down")
  end
  U.shot(game, SHOT_DIR .. "/bug1875_bills_auto_talk.png")

  for _ = 1, 300 do
    if game.save.flags.EVENT_GOT_SS_TICKET then break end
    U.tap(game, "a")
    U.wait(6)
  end
  check("the S.S. TICKET was handed over", game.save.flags.EVENT_GOT_SS_TICKET == true)
  check("the ticket is in the bag",
        (game.save.inventory and game.save.inventory.S_S_TICKET or 0) > 0)

  U.log("On the cart you never walk over to Bill: after the separator he steps")
  U.log("out, you slide three cells east on your own and he starts talking.")
  U.log("Watch for the slide being cancellable (holding a direction should do")
  U.log("nothing through it), and for the ticket jingle riding the RECEIVED")
  U.log("box rather than firing early.  Input is yours now; walking out to")
  U.log("Route 25 arms the Eevee list on the PC.")

  idle()
end
