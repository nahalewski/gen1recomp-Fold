--   POKEPORT_DRIVER=tests/drivers/link_addr_entry_bug1295_test.lua POKEPORT_IDENTITY=bug1295 POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local LinkState = require("src.link.LinkState")

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  check("10.0.0.1 round-trips unpadded",
        LinkState.addrText(LinkState.addrEntry("10.0.0.1")) == "10.0.0.1")
  check("192.168.1.40 does not gain trailing zeroes",
        LinkState.addrText(LinkState.addrEntry("192.168.1.40")) == "192.168.1.40")

  U.newGame(game)
  U.wait(10)

  local link = LinkState.new(game)
  link.stage = "addrEntry"
  link.addr = LinkState.addrEntry("10.42.0.1")
  game.stack:push(link)
  U.wait(5)

  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  U.shot(game, SHOT_DIR .. "/bug1295_addr_entry.png")
  U.log("captured", SHOT_DIR .. "/bug1295_addr_entry.png")

  U.log("ENTER HOST ADDRESS is on screen, seeded with 10.42.0.1 and reading")
  U.log("exactly that, the way the HOSTING screen prints it.  Before #1295 it")
  U.log("was twelve fixed digits and the same address read 010.042.000.001.")
  U.log("Left/right walks the slots, up/down cycles 0-9 then '.' then blank,")
  U.log("so a shorter address just leaves the tail slots empty.  A on")
  U.log("something that is not a dotted quad says so instead of dialling.")

  while true do
    coroutine.yield()
  end
end
