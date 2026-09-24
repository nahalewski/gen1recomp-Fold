-- ../pokered/engine/battle/animations.asm:1733
-- ../pokered/engine/battle/core.asm:1181
--   POKEPORT_DRIVER=tests/drivers/minimize_pos_bug1940_test.lua POKEPORT_IDENTITY=red-aug28 POKEPORT_TOUCH=0 SHOT_DIR=/tmp/shots love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Timing = require("src.core.Timing")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1 else fail = fail + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local bx, by = BattleState.minimizedBlobOrigin(false)
  check("enemy blob origin is (120, 34)", bx == 120 and by == 34)
  local px, py = BattleState.minimizedBlobOrigin(true)
  check("player blob origin is (32, 74)", px == 32 and py == 74)

  local clefairy = Pokemon.new(game.data, "CLEFAIRY", 20)
  local squirtle = Pokemon.new(game.data, "SQUIRTLE", 30)
  game.save.party = { squirtle }
  game.save.player.name = "RED"
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(10)
  local ow = game.overworld
  check("the overworld is up on ROUTE_1", ow ~= nil)

  local battle = BattleState.newWild(game, "CLEFAIRY", 20)
  battle.onFinish = function() end
  ow:pushBattle(battle)
  for _ = 1, 400 do
    if game.stack:top() == battle and (battle.introSlide or 0) == 0 then break end
    U.wait(1)
  end
  check("the battle reached the screen", game.stack:top() == battle)
  battle.enemy.mon.stats.hp = 400
  battle.enemy.mon.hp = 400
  battle.enemy.shownHP = 400

  local box, inside = nil, false
  local realRect = love.graphics.rectangle
  love.graphics.rectangle = function(mode, x, y, w, h)
    if box and inside then
      box.x0 = math.min(box.x0, x)
      box.x1 = math.max(box.x1, x + w - 1)
      box.y0 = math.min(box.y0, y)
      box.y1 = math.max(box.y1, y + h - 1)
    end
    return realRect(mode, x, y, w, h)
  end
  local blobCalls = 0
  local realBlob = getmetatable(battle).drawMinimizedBlob
  battle.drawMinimizedBlob = function(self, ...)
    blobCalls = blobCalls + 1
    inside = true
    realBlob(self, ...)
    inside = false
  end
  local function measure(frames)
    box = { x0 = math.huge, x1 = -math.huge, y0 = math.huge, y1 = -math.huge }
    U.wait(frames or 3)
    local b = box
    box = nil
    return b
  end

  battle.picFx = battle.picFx or {}
  battle.picFx[battle.enemy] = { minimized = true }
  local b = measure(4)
  U.log(("standing blob: x %s..%s y %s..%s")
          :format(tostring(b.x0), tostring(b.x1), tostring(b.y0), tostring(b.y1)))
  check("the blob spans x 121..126 (was 129..134 with the pic pad)",
        b.x0 == 121 and b.x1 == 126)
  check("the blob spans y 34..38 (was 50..54)", b.y0 == 34 and b.y1 == 38)
  U.shot(game, DIR .. "/bug1940_minimized_enemy.png")

  battle.fx = battle.fx or {}
  -- ../pokered/engine/battle/core.asm:1180
  local HELD = Timing.FAINT_SLIDE - 4
  battle.fx.faint = setmetatable({ battler = battle.enemy }, {
    __index = function(_, k) if k == "frames" then return HELD end end,
    __newindex = function() end,
  })
  blobCalls = 0
  local sunk = measure(3)
  U.shot(game, DIR .. "/bug1941_minimized_faint.png")
  check("the faint slide still draws the blob", blobCalls > 0)
  check("and it is sinking", sunk.y0 ~= math.huge and sunk.y0 > 34)
  U.log(("sinking blob: y %s..%s"):format(tostring(sunk.y0), tostring(sunk.y1)))
  battle.fx.faint = nil

  U.log(("machine checks: %d passed, %d failed"):format(pass, fail))
  U.log("Eyes: " .. DIR .. "/bug1940_minimized_enemy.png -- the tiny blob sits")
  U.log("high in the foe's slot (x 121..126, y 34..38), not down-right of it.")
  U.log("bug1941_minimized_faint.png -- the blob, not CLEFAIRY's pic, is the")
  U.log("thing part-way through the faint slide.")

  while true do
    coroutine.yield()
  end
end
