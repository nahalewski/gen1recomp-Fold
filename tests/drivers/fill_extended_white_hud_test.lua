-- Visual acceptance driver for WIDE + FILL + EXTENDED + WHITE.
-- The full physical-window backing remains white while the four battle HUD
-- panels move to their approved window anchors.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")

  love.window.setMode(2048, 1152, { resizable = true })
  U.wait(3)

  local options = game.save.options
  options.battleLayout = "wide"
  options.battleFit = "fill"
  options.battleHud = "extended"
  options.battleBg = "white"

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

  assert(battle:extendedHUD(), "FILL/WHITE activates the approved extended HUD")
  assert(not battle:extendedWorldHUD(), "FILL/WHITE does not use FIXED's paper band")

  local path = DIR .. "/fill_extended_white_separate_layer.png"
  os.remove(path)
  local ok = U.shot(game, path)

  love.window.setMode(960, 540, { resizable = true })
  U.wait(5)
  local smallPath = DIR .. "/fill_extended_white_small_16x9.png"
  os.remove(smallPath)
  ok = U.shot(game, smallPath) and ok

  love.window.setMode(2048, 1152, { resizable = true })
  U.wait(5)
  local NamingScreen = require("src.ui.NamingScreen")
  game.stack:push(NamingScreen.new(game, {
    title = "NICKNAME?", maxLen = 10, onDone = function() end,
  }))
  U.wait(5)
  local overlayPath = DIR .. "/fill_extended_white_naming_overlay.png"
  os.remove(overlayPath)
  ok = U.shot(game, overlayPath) and ok

  U.log(ok and "FILL_EXTENDED_WHITE_PASS" or "FILL_EXTENDED_WHITE_FAIL")
  love.event.quit(ok and 0 or 1)
end
