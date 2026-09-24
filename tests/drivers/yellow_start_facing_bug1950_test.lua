-- ../pokeyellow/engine/menus/main_menu.asm:156
--   POKEPORT_DRIVER=tests/drivers/yellow_start_facing_bug1950_test.lua \
--   POKEPORT_IDENTITY=bug1950 POKEPORT_TOUCH=0 POKEPORT_VERSION=yellow love .
return function(game)
  local U = dofile("tests/drivers/util.lua")

  local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR")
    or os.getenv("SHOT_DIR") or "/tmp/shots"
  local ok = true
  local function check(label, pass)
    U.log(pass and "PASS" or "FAIL", label)
    if not pass then ok = false end
    return pass
  end

  U.newGame(game)
  local landed = false
  for _ = 1, 900 do
    if game.overworld and game.stack:top() == game.overworld then
      landed = true
      break
    end
    U.tap(game, "a")
    U.wait(2)
  end
  U.wait(30)

  local p = game.overworld and game.overworld.player
  check("the Oak speech handed control to the overworld", landed)
  U.log("facing =", tostring(p and p.facing))
  check("the bedroom spawn faces up", p ~= nil and p.facing == "up")
  check("still in the bedroom", game.save.player.map == "REDS_HOUSE_2F")

  U.shot(game, SHOT_DIR .. "/bug1950_yellow_start_facing.png")

  U.log(ok and "all clear" or "a check failed")
  while true do coroutine.yield() end
end
