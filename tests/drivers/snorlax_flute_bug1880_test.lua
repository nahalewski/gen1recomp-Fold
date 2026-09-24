-- pokered engine/items/item_effects.asm:1794 (#1880)
--   POKEPORT_DRIVER=tests/drivers/snorlax_flute_bug1880_test.lua \
--     POKEPORT_IDENTITY=bug1880 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
-- No POKEPORT_SPEED: the tune runs on the audio clock.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Bag = require("src.inventory.Bag")
  local Pokemon = require("src.pokemon.Pokemon")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
    return ok
  end

  local vol = game.save.options and game.save.options.sfxVol
  if vol == 0 then
    U.log("sfxVol is 0; turn it up in OPTION or the ear half of this check is moot")
  end

  game.save.party = { Pokemon.new(game.data, "PIDGEOTTO", 30) }
  Bag.add(game.save, "POKE_FLUTE", 1)

  U.teleport(game, "ROUTE_12", 10, 30, "down")
  U.wait(20)
  local ow = game.overworld
  local snorlax
  for _, npc in ipairs(ow.npcs or {}) do
    if npc.def and tostring(npc.def.name or ""):find("SNORLAX") then snorlax = npc end
  end
  if not check("ROUTE_12 has its SNORLAX", snorlax ~= nil) then
    U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
    while true do coroutine.yield() end
  end
  U.teleport(game, "ROUTE_12", snorlax.cellX, snorlax.cellY - 1, "down")
  U.wait(20)
  ow = game.overworld

  local bag = Screens.push(game, "BagMenu")
  U.wait(20)
  local row
  for i, item in ipairs(bag.items) do
    if item.value == "POKE_FLUTE" then row = i end
  end
  if not check("the POKé FLUTE is in the bag", row ~= nil) then
    U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
    while true do coroutine.yield() end
  end
  bag.index = row
  U.tap(game, "a")
  U.wait(20)
  if game.stack:top() ~= bag and not game.stack:top().isTextBox then
    U.tap(game, "a")
    U.wait(20)
  end

  local box
  for _ = 1, 240 do
    local top = game.stack:top()
    if top and top.isTextBox then box = top break end
    U.wait(1)
  end
  if not check("the played-flute box opened", box ~= nil) then
    U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
    while true do coroutine.yield() end
  end

  for _ = 1, 240 do
    if box.done then break end
    U.tap(game, "a")
  end
  check("the line typed out", box.done == true)
  check("nothing has played yet", box.autoStarted ~= true and box.autoSrc == nil)
  U.log("the box should read '<PLAYER> played the POKé FLUTE.' with a blinking")
  U.log("arrow and NO tune yet; the map music is still going")
  U.shot(game, "/tmp/shots/bug1880_prompt.png")

  U.tap(game, "a")
  U.wait(2)
  check("the prompt was answered", box.autoPrompted == true)
  check("the tune started", box.autoSrc ~= nil)
  U.log("the tune plays now, with the same box still on screen")

  local heldFrames, wokeEarly = 0, false
  for _ = 1, 600 do
    local playing = box.autoSrc and box.autoSrc.isPlaying and box.autoSrc:isPlaying()
    if not playing then break end
    heldFrames = heldFrames + 1
    if game.stack:top() ~= box then wokeEarly = true break end
    U.tap(game, "a")
  end
  check("A never cut the tune short", not wokeEarly)
  check("the tune held the box for a while", heldFrames > 30)
  U.log(("the box stayed up for %d frames of tune"):format(heldFrames))

  U.wait(30)
  U.log("SNORLAX should be waking up only now, after the tune finished")
  U.shot(game, "/tmp/shots/bug1880_after.png")
  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))

  while true do
    coroutine.yield()
  end
end
