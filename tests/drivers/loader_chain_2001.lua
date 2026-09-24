return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Guard = require("src.core.RequireGuard")
  local loaders = package.loaders or package.searchers

  U.wait(30)
  U.log("loader_chain_2001: captured=", tostring(Guard.captured()),
    "present=", tostring(Guard.present()))

  local searcher = loaders[2]
  table.remove(loaders, 2)
  U.log("loader_chain_2001: removed package.loaders[2], present=",
    tostring(Guard.present()))

  U.wait(5)
  local repaired = Guard.repair()
  U.log("loader_chain_2001: repair=", tostring(repaired),
    "present=", tostring(Guard.present()),
    "slot2_restored=", tostring(loaders[2] == searcher))

  U.wait(5)
  local ok = pcall(require, "src.core.GameSpeed")
  U.log("loader_chain_2001: cold require after repair ok=", tostring(ok))

  U.wait(30)
  love.event.quit()

  while true do
    coroutine.yield()
  end
end
