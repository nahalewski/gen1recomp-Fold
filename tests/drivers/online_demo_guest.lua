-- Live-relay demo, guest seat.  Armed by POKEPORT_ONLINE_SHOT=demo-guest.
--
--   POKEPORT_IDENTITY=pokemon-love2d-demo-b POKEPORT_TOUCH=0 \
--     POKEPORT_LAUNCHER_TAB=online POKEPORT_ONLINE_SHOT=demo-guest love .

local Demo = require("tests.drivers.online_demo_common")

return function(OnlinePanel, imp)
  return Demo.run(OnlinePanel, imp, {
    role = "guest",
    prefix = "guest",
    name = os.getenv("POKEPORT_DEMO_NAME") or "DEMO-B",
    slotId = os.getenv("POKEPORT_DEMO_SLOT") or "slot3",
    team = { 1, 3, 4 },
  })
end
