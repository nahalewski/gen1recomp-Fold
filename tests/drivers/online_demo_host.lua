-- Live-relay demo, host seat.  Armed by POKEPORT_ONLINE_SHOT=demo-host.
--
--   POKEPORT_IDENTITY=pokemon-love2d-demo-a POKEPORT_TOUCH=0 \
--     POKEPORT_LAUNCHER_TAB=online POKEPORT_ONLINE_SHOT=demo-host love .

local Demo = require("tests.drivers.online_demo_common")

return function(OnlinePanel, imp)
  return Demo.run(OnlinePanel, imp, {
    role = "host",
    prefix = "host",
    name = os.getenv("POKEPORT_DEMO_NAME") or "DEMO-A",
    slotId = os.getenv("POKEPORT_DEMO_SLOT") or "slot1",
    team = { 1, 2, 3 },
    note = "live relay demo",
  })
end
