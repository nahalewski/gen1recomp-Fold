-- engine/battle/experience.asm:149-256 prints GainedText (prompt), and only
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
              or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local Growth = require("src.pokemon.Growth")
  local BattleState = require("src.battle.BattleState")

  local squirtle = Pokemon.new(game.data, "SQUIRTLE", 5, function(_, b) return b end)
  local def = game.data.pokemon.SQUIRTLE
  local oldHP = 8
  squirtle.hp = oldHP
  squirtle.exp = Growth.expForLevel(def.growthRate, 6, game.data.growth_rates) - 1
  game.save.party = { squirtle }
  local oldMax = squirtle.stats.hp

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local ow = game.overworld

  local battle = BattleState.newWild(game, "SLOWPOKE", 2)
  battle.onFinish = function() end
  battle.rng = function(a, _) return a end
  battle.enemy.mon.hp = 1
  battle.enemy.mon.stats.speed = 1
  ow:pushBattle(battle)

  for _ = 1, 240 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(3)
  end
  if battle.phase ~= "menu" then error("bug1996: never reached the FIGHT menu") end

  U.tap(game, "a")
  for _ = 1, 60 do
    if battle.phase == "moveSelect" then break end
    U.wait(1)
  end
  if battle.phase ~= "moveSelect" then error("bug1996: never reached move select") end
  U.tap(game, "a")

  local sawExpPage = false
  for i = 1, 1200 do
    local cur = battle.current
    if cur and cur.text and cur.text:find("EXP", 1, true) then
      sawExpPage = true
      if squirtle.level ~= 5 then
        error("bug1996: level moved to " .. tostring(squirtle.level) ..
              " while the exp page was still up")
      end
      if squirtle.stats.hp ~= oldMax then
        error("bug1996: max HP moved to " .. tostring(squirtle.stats.hp) ..
              " while the exp page was still up")
      end
      U.shot(game, DIR .. "/bug1996_exp_page.png")
      break
    end
    if i % 6 == 0 then U.tap(game, "a") else U.wait(1) end
    if game.stack:top() ~= battle then break end
  end
  if not sawExpPage then error("bug1996: never saw the gained-EXP page") end

  local landed = false
  for _ = 1, 400 do
    U.tap(game, "a")
    U.wait(1)
    if squirtle.level >= 6 then landed = true break end
  end
  if not landed then error("bug1996: the level never landed after the press") end
  local newMax = squirtle.stats.hp
  if not (newMax > oldMax) then
    error("bug1996: max HP did not grow; repro is meaningless")
  end
  local expectHP = math.min(newMax, oldHP + (newMax - oldMax))
  if squirtle.hp ~= expectHP then
    error("bug1996: current HP wrong: got " .. tostring(squirtle.hp) ..
          ", expected " .. tostring(expectHP))
  end
  local shown = battle.player.shownHP
  if shown ~= squirtle.hp then
    error("bug1996: the bar did not snap with the level: shownHP=" ..
          tostring(shown) .. ", mon.hp=" .. tostring(squirtle.hp))
  end
  U.shot(game, DIR .. "/bug1996_hud_snapped.png")

  local box
  for _ = 1, 400 do
    U.wait(1)
    local top = game.stack:top()
    if top and top ~= battle and top.mon == squirtle then box = top break end
  end
  if not box then
    error("bug1996: the stat box never opened without a button press")
  end
  U.shot(game, DIR .. "/bug1996_stat_box.png")

  -- and one press dismisses it (experience.asm:250)
  U.tap(game, "a")
  for _ = 1, 60 do
    U.wait(1)
    if game.stack:top() ~= box then break end
  end
  if game.stack:top() == box then
    error("bug1996: the stat box did not close on A")
  end

  U.log("bug1996 OK: L6, HP " .. tostring(squirtle.hp) .. "/" .. tostring(newMax) ..
        ", bar snapped from " .. tostring(oldHP) .. " with the level")
end
