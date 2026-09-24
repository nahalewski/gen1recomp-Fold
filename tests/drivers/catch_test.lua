-- Driver: throw Poké Balls and capture the catch suspense sequence
-- (toss -> poof -> mon hides -> ball shakes -> breakout or capture),
-- #159 nickname ask (text + white field, YES then NO), and #172
-- full-party catch nickname prompt before box transfer.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local ChoiceBox = require("src.ui.ChoiceBox")
  table.insert(game.save.party, Pokemon.new(game.data, "CHARMANDER", 12))
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local ow = game.overworld

  local BattleState = require("src.battle.BattleState")

  local function topIs(cls)
    return getmetatable(game.stack:top()) == cls
  end

  local function mashUntil(cond, n)
    for _ = 1, (n or 400) do
      if cond() then return true end
      U.tap(game, "a")
      U.wait(3)
    end
    return false
  end

  local function onNicknameChoice()
    return topIs(ChoiceBox)
  end

  -- one throw, screenshotting every 20 frames through the chain
  local function throwAndShoot(tag, rng)
    local battle = BattleState.newWild(game, "PIDGEY", 8)
    battle.onFinish = function() end
    battle.rng = rng
    ow:pushBattle(battle)
    for _ = 1, 14 do U.tap(game, "a"); U.wait(6) end
    -- what openItems does before BagMenu calls throwBall
    battle.phase = "messages"
    battle.afterQueue = "menu"
    battle:throwBall("POKE_BALL")
    for _ = 1, 4 do U.tap(game, "a"); U.wait(4) end
    for i = 0, 13 do
      U.shot(game, ("%s/catch_%s_%02d.png"):format(DIR, tag, i))
      U.wait(18)
    end
    -- unwind the battle for the next run
    for _ = 1, 20 do U.tap(game, "a"); U.wait(6) end
    while game.stack:top() ~= ow do game.stack:pop() end
    U.wait(5)
  end

  -- rng high: breakout with wobbles, mon reappears
  throwAndShoot("break", function(a, b) return b end)
  -- rng low: clean capture, ball stays shut
  throwAndShoot("caught", function(a, b) return a end)

  -- data/text/text_6.asm:29-35
  local function contHoldShoot()
    local battle = BattleState.newWild(game, "PIDGEY", 8)
    battle.onFinish = function() end
    battle.rng = function(a, b) return a end
    ow:pushBattle(battle)
    for _ = 1, 14 do U.tap(game, "a"); U.wait(6) end
    battle.phase = "messages"
    battle.afterQueue = "menu"
    battle:throwBall("POKE_BALL")
    local held = false
    for _ = 1, 900 do
      local cur = battle.current
      if battle.msgWaiting and cur and cur.text
         and cur.text:find("All right!", 1, true) then
        held = true
        break
      end
      U.wait(1)
    end
    U.log("caught-line CONT hold:", held,
          battle.current and battle.current.text or "nil")
    U.wait(30)
    U.shot(game, DIR .. "/catch_cont_hold.png")
    U.tap(game, "a")
    U.wait(45)
    U.shot(game, DIR .. "/catch_cont_after.png")
    for _ = 1, 30 do U.tap(game, "a"); U.wait(4) end
    while game.stack:top() ~= ow do game.stack:pop() end
    U.wait(5)
  end
  contHoldShoot()

  -- #159: party catch -> nickname ask on white (YES cursor, then NO)
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 5) }
  game.save.pokedex = game.save.pokedex or { owned = {}, seen = {} }
  game.save.pokedex.owned.RATTATA = true
  game.save.pokedex.seen.RATTATA = true

  local battle = BattleState.newWild(game, "RATTATA", 3)
  battle.onFinish = function() end
  battle.rng = function(a, b) return a end
  ow:pushBattle(battle)
  for _ = 1, 14 do U.tap(game, "a"); U.wait(6) end
  battle.phase = "messages"
  battle.afterQueue = "menu"
  battle:throwBall("POKE_BALL")

  U.log("nick YES:", mashUntil(onNicknameChoice, 600))
  U.shot(game, DIR .. "/catch_nickname_yes.png")
  U.tap(game, "down")
  U.wait(4)
  U.shot(game, DIR .. "/catch_nickname_no.png")
  U.tap(game, "a") -- confirm NO
  U.wait(8)
  for _ = 1, 20 do U.tap(game, "a"); U.wait(4) end
  while game.stack:top() ~= ow do game.stack:pop() end
  U.wait(5)

  -- #172: full party of 6 -> nickname ask, then "sent to BOX" / PC text
  game.save.party = {}
  for _ = 1, 6 do
    table.insert(game.save.party, Pokemon.new(game.data, "RATTATA", 5))
  end
  game.save.pokedex.owned.PIDGEY = true
  game.save.pokedex.seen.PIDGEY = true
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_MET_BILL = true

  battle = BattleState.newWild(game, "PIDGEY", 8)
  battle.onFinish = function() end
  battle.rng = function(a, b) return a end
  ow:pushBattle(battle)
  for _ = 1, 14 do U.tap(game, "a"); U.wait(6) end
  battle.phase = "messages"
  battle.afterQueue = "menu"
  battle:throwBall("POKE_BALL")

  U.log("full-party nick ask:", mashUntil(onNicknameChoice, 600))
  U.wait(4)
  U.shot(game, DIR .. "/catch_fullparty_nickname.png")

  -- decline nickname (NO), then wait (no A/B) for ItemUseBallText07
  if topIs(ChoiceBox) then
    U.tap(game, "b") -- NO
  end
  -- drain the B edge before the transfer text can see it
  for _ = 1, 8 do U.wait(1) end
  local sawBox = false
  for _ = 1, 400 do
    if game.stack:top() == battle and battle.current and battle.current.text
       and battle.current.text:find("transferred", 1, true) then
      sawBox = true
      -- wait until the typewriter has drawn most of the line
      if (battle.charIndex or 0) >= math.floor((battle.total or 0) * 0.7) then
        break
      end
    end
    U.wait(1)
  end
  U.log("full-party box text:", sawBox,
        battle.current and battle.current.text or "nil")
  U.shot(game, DIR .. "/catch_fullparty_box.png")

  for _ = 1, 30 do U.tap(game, "a"); U.wait(4) end
  while game.stack:top() ~= ow do game.stack:pop() end
  U.wait(5)

  -- engine/menus/pokedex.asm:581-582 (#2069)
  game.save.party = {}
  for _ = 1, 6 do
    table.insert(game.save.party, Pokemon.new(game.data, "RATTATA", 5))
  end
  game.save.pokedex.owned.SLOWPOKE = nil
  game.save.pokedex.seen.SLOWPOKE = nil
  game.save.flags.EVENT_MET_BILL = true

  battle = BattleState.newWild(game, "SLOWPOKE", 15)
  battle.onFinish = function() end
  battle.rng = function(a, b) return a end
  ow:pushBattle(battle)
  for _ = 1, 14 do U.tap(game, "a"); U.wait(6) end
  battle.phase = "messages"
  battle.afterQueue = "menu"
  battle:throwBall("POKE_BALL")

  U.log("new-dex full-party nick ask:", mashUntil(onNicknameChoice, 900))
  U.wait(4)
  U.shot(game, DIR .. "/catch_newdex_fullparty_nickname.png")
  if topIs(ChoiceBox) then
    U.tap(game, "b")
  end
  for _ = 1, 8 do U.wait(1) end
  sawBox = false
  for _ = 1, 400 do
    if game.stack:top() == battle and battle.current and battle.current.text
       and battle.current.text:find("transferred", 1, true) then
      sawBox = true
      if (battle.charIndex or 0) >= math.floor((battle.total or 0) * 0.7) then
        break
      end
    end
    U.wait(1)
  end
  U.log("new-dex full-party box text:", sawBox,
        battle.current and battle.current.text or "nil")
  U.shot(game, DIR .. "/catch_newdex_fullparty_box.png")

  for _ = 1, 30 do U.tap(game, "a"); U.wait(4) end
  while game.stack:top() ~= ow do game.stack:pop() end
end
