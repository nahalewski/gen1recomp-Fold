--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal \
--     POKEPORT_DRIVER=tests/drivers/crystal_hp_bar_cadence.lua \
--     POKEPORT_SHOT_DIR=/tmp/crystal-hp-bar-cadence love .
-- ../pokecrystal/engine/battle/anim_hp_bar.asm:286
local U = require("tests.drivers.util")

local Mon = require("src.battle.gen2.Mon")
local HpBar = require("src.battle.gen2.HpBar")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-hp-bar-cadence"
  os.execute('mkdir -p "' .. out .. '" 2>/dev/null')
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[hp-bar-cadence] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "the crystal world did not boot")

  local lead = Mon.new(game.data, "CYNDAQUIL", 12)
  assert(lead, "could not build a CYNDAQUIL")
  lead.moves = { { id = "EMBER", pp = 25, maxPp = 25 } }
  game.save.party = { lead }
  game.save.inventory = { POKE_BALL = 5 }

  local wild = Mon.new(game.data, "PIDGEY", 3)
  assert(wild, "could not build a wild PIDGEY")
  wild.maxHp = 15
  wild.hp = 15
  if wild.stats then wild.stats.hp = 15 end
  wild.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }

  assert(world:startBattle({ wild = wild }), "startBattle failed")
  local screen
  for _ = 1, 600 do
    local top = game.stack:top()
    if top and top.battle then screen = top break end
    U.wait(1)
  end
  assert(screen and screen.battle, "battle screen never came up")

  for _ = 1, 900 do
    if screen.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(2)
  end
  ok(screen.phase == "menu", "reached the battle menu")
  U.tap(game, "a")
  U.wait(4)
  U.tap(game, "a")

  local enemy = screen.battle.enemy
  local maxHp = enemy.maxHp or (enemy.stats and enemy.stats.hp) or 0
  local start = screen.shownHp.enemy
  print(("[hp-bar-cadence] enemy %d/%d before EMBER"):format(start, maxHp))

  local tick, firstChange, lastChange, changes = 0, nil, nil, 0
  local startPx = HpBar.pixels(start, maxHp)
  local lastHp, lastPx = start, startPx
  local shooting = false
  local gaps = {}
  for _ = 1, 900 do
    local hp = screen.shownHp.enemy
    local px = screen.hudHpPixels and screen:hudHpPixels(enemy, "enemy")
      or HpBar.pixels(hp, maxHp)
    if hp ~= lastHp or px ~= lastPx then
      changes = changes + 1
      if not firstChange then firstChange = tick end
      if lastChange then gaps[#gaps + 1] = tick - lastChange end
      lastChange = tick
      shooting = true
    end
    if shooting then
      print(("[hp-bar-cadence] tick %3d shownHp %2d px %2d hpAnim %s")
        :format(tick, hp, px, tostring(screen.hpAnim ~= nil)))
      game.capturePath = ("%s/t%03d.png"):format(out, tick)
    end
    lastHp, lastPx = hp, px
    if shooting and hp == 0 and not screen.hpAnim then break end
    U.wait(1)
    tick = tick + 1
  end

  local span = (firstChange and lastChange) and (lastChange - firstChange) or -1
  print(("[hp-bar-cadence] %d changes, first at tick %s, last at tick %s, span %d")
    :format(changes, tostring(firstChange), tostring(lastChange), span))
  local allTwo = #gaps > 0
  for _, g in ipairs(gaps) do if g ~= 2 then allTwo = false end end
  ok(lastHp == 0, "the bar drained to zero")
  ok(changes == startPx,
    ("one change per pixel: %d of %d"):format(changes, startPx))
  ok(allTwo, "every change two ticks after the last")
  ok(span == 2 * (startPx - 1),
    ("first to last change spans %d ticks (expect %d)")
      :format(span, 2 * (startPx - 1)))

  print("[hp-bar-cadence] " .. (fails == 0 and "PASS all claims" or
    (fails .. " claims failed")) .. " -- shots in " .. out)
  love.event.quit(fails == 0 and 0 or 1)
end
