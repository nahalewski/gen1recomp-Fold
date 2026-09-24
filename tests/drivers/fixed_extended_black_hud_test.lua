local U = require("tests.drivers.util")

local OUT = os.getenv("SHOT_DIR") or "fixed-extended-black"
local FULL = OUT .. "/fixed_extended_black_full.png"
local SMALL = OUT .. "/fixed_extended_black_small_16x9.png"
local OVERLAY = OUT .. "/fixed_extended_black_overlay.png"

return function(game)
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")

  os.remove(FULL)
  os.remove(SMALL)
  os.remove(OVERLAY)

  love.window.setMode(2048, 1152, { resizable = true })
  U.wait(3)

  local options = game.save.options
  options.battleLayout = "wide"
  options.battleFit = "fixed"
  options.battleHud = "extended"
  options.battleBg = "black"

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

  assert(battle:extendedHUD(), "BLACK activates the approved extended HUD")
  assert(battle:extendedBlackHUD(), "BLACK activates the white vertical battle band")
  assert(not battle:extendedWorldHUD(), "BLACK remains separate from WORLD")
  assert(U.shot(game, FULL), "full black-background screenshot was written")

  love.window.setMode(960, 540, { resizable = true })
  U.wait(10)
  assert(U.shot(game, SMALL), "small black-background screenshot was written")

  love.window.setMode(2048, 1152, { resizable = true })
  U.wait(10)
  battle.blankForAskName = true
  local naming = require("src.ui.NamingScreen").new(game, {
    title = "NICKNAME?", maxLen = 10, onDone = function() end,
  })
  game.stack:push(naming)
  U.wait(10)
  assert(U.shot(game, OVERLAY), "black-background overlay screenshot was written")

  print("[driver] FIXED_EXTENDED_BLACK_PASS")
  love.event.quit(0)
end
