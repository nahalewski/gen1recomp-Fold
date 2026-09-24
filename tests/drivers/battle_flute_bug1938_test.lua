-- engine/items/item_effects.asm:1706-1745
--   POKEPORT_DRIVER=tests/drivers/battle_flute_bug1938_test.lua \
--     POKEPORT_IDENTITY=bug1938 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
-- No POKEPORT_SPEED: the tune runs on the audio clock.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/shots"
  local Bag = require("src.inventory.Bag")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
    return ok
  end
  local function finish()
    U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
    while true do coroutine.yield() end
  end

  local vol = game.save.options and game.save.options.sfxVol
  if vol == 0 then
    U.log("sfxVol is 0; turn it up in OPTION or the ear half of this check is moot")
  end

  local lead = Pokemon.new(game.data, "CHARIZARD", 50)
  game.save.party = { lead }
  Bag.add(game.save, "POKE_FLUTE", 1)
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(20)

  local battle = BattleState.newWild(game, "PIDGEY", 8)
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  for _ = 1, 120 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(4)
  end
  if not check("the wild battle reached its FIGHT menu", battle.phase == "menu") then
    finish()
  end

  lead.status = "SLP"
  local turns = 0
  local realItemUsed = battle.itemUsed
  battle.itemUsed = function(self, ...)
    turns = turns + 1
    return realItemUsed(self, ...)
  end

  local bag
  for _ = 1, 20 do
    local top = game.stack:top()
    if top and top.screenId == "BagMenu" then bag = top break end
    U.tap(game, "down"); U.wait(4)
    U.tap(game, "left"); U.wait(4)
    U.tap(game, "a"); U.wait(14)
  end
  if not check("ITEM opened the bag", bag ~= nil) then finish() end

  local row
  for i, item in ipairs(bag.items or {}) do
    if item.value == "POKE_FLUTE" then row = i end
  end
  if not check("the POKé FLUTE is in the battle bag", row ~= nil) then finish() end
  for _ = 1, 40 do
    if bag.index == row then break end
    U.tap(game, bag.index < row and "down" or "up")
    U.wait(3)
  end
  U.tap(game, "a")
  U.wait(20)

  local box
  for _ = 1, 240 do
    local top = game.stack:top()
    if top and top.isTextBox then box = top break end
    U.wait(1)
  end
  if not check("the played-flute box opened", box ~= nil) then finish() end

  for _ = 1, 240 do
    if box.done then break end
    U.tap(game, "a")
  end
  check("the line typed out", box.done == true)
  check("nothing has played yet", box.autoStarted ~= true and box.autoSrc == nil)
  U.shot(game, DIR .. "/bug1938_prompt.png")

  U.tap(game, "a")
  U.wait(2)
  check("the prompt was answered", box.autoPrompted == true)
  check("the tune started", box.autoSrc ~= nil)
  U.shot(game, DIR .. "/bug1938_tune.png")

  local heldFrames, brokeOut = 0, false
  for _ = 1, 900 do
    local playing = box.autoSrc and box.autoSrc.isPlaying and box.autoSrc:isPlaying()
    if not playing then break end
    heldFrames = heldFrames + 1
    if game.stack:top() ~= box then brokeOut = true break end
    U.tap(game, "a")
  end
  check("A never cut the tune short (.musicWaitLoop)", not brokeOut)
  check("the tune held the box for a while", heldFrames > 30)
  check("and the turn did not resolve over it", turns == 0)
  U.log(("the box stayed up for %d frames of tune"):format(heldFrames))

  U.wait(20)
  local woke = game.stack:top()
  check("FluteWokeUpText follows the tune",
        woke ~= nil and woke ~= box and woke.isTextBox == true)
  U.shot(game, DIR .. "/bug1938_woke.png")

  for _ = 1, 200 do
    if turns > 0 then break end
    U.tap(game, "a")
    U.wait(4)
  end
  check("dismissing it spends the turn", turns == 1)
  check("the lead is awake", lead.status == nil)
  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))

  while true do
    coroutine.yield()
  end
end
