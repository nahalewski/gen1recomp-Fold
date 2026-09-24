-- Visual acceptance driver for the first EXTENDED HUD configuration only:
-- WIDE + FIXED + EXTENDED + WORLD.
--   POKEPORT_DRIVER=tests/drivers/fixed_extended_world_hud_test.lua \
--     POKEPORT_IDENTITY=fixed-extended-world POKEPORT_TOUCH=0 \
--     SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")

  -- Match the 16:9 acceptance screenshot so the fixed 304x144 surface has
  -- measurable space above and below it.
  love.window.setMode(2048, 1152, { resizable = true })
  U.wait(3)

  local options = game.save.options
  options.battleLayout = "wide"
  options.battleFit = "fixed"
  options.battleHud = "extended"
  options.battleBg = "world"

  game.save.party = { Pokemon.new(game.data, "PIKACHU", 100) }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(60)

  local battle = BattleState.newWild(game, "PIDGEY", 3,
    { onFinish = function() end })
  game.overworld:pushBattle(battle)
  U.wait(360)

  battle.introSlide = 0
  battle.introBalls = nil
  battle.showEnemyTrainer = false
  battle.showPlayerBack = false
  battle.enemySendingOut = false
  battle.sendingOut = false
  battle.phase = "menu"
  battle.menuIndex = 1
  U.wait(2)

  local path = DIR .. "/fixed_extended_world_separate_layer.png"
  os.remove(path)
  local ok = U.shot(game, path)

  love.window.setMode(960, 540, { resizable = true })
  U.wait(5)
  local smallPath = DIR .. "/fixed_extended_world_small_16x9.png"
  os.remove(smallPath)
  ok = U.shot(game, smallPath) and ok

  love.window.setMode(2048, 1152, { resizable = true })
  U.wait(5)
  local NamingScreen = require("src.ui.NamingScreen")
  game.stack:push(NamingScreen.new(game, {
    title = "NICKNAME?", maxLen = 10, onDone = function() end,
  }))
  U.wait(5)
  local overlayPath = DIR .. "/fixed_extended_world_naming_overlay.png"
  os.remove(overlayPath)
  ok = U.shot(game, overlayPath) and ok

  U.log(ok and "FIXED_EXTENDED_WORLD_PASS" or "FIXED_EXTENDED_WORLD_FAIL")
  love.event.quit(ok and 0 or 1)
end
