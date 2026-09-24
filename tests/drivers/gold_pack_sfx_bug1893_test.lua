-- engine/menus/scrolling_menu.asm:23 (#1893)
--   POKEPORT_IDENTITY=gold-dev POKEPORT_GAME=gold POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/gold_pack_sfx_bug1893_test.lua love .
-- No POKEPORT_SPEED: the cues are the thing under test.
local U = require("tests.drivers.util")

local Bag = require("src.inventory.Bag")
local PackMenu = require("src.ui.gen2.PackMenu")
local Sound = require("src.core.Sound")

local HOME = { map = "NEW_BARK_TOWN", x = 13, y = 6 }

local SEED = {
  { "POTION", 5 },
  { "SUPER_POTION", 3 },
  { "ESCAPE_ROPE", 2 },
  { "POKE_BALL", 7 },
}

local CUES = { "Sfx_ReadText2", "Sfx_SwitchPockets", "Sfx_SwitchPokemon" }

return function(game)
  local failed = 0

  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")
  local world, save = game.world, game.save

  world:setMap(HOME.map, HOME.x, HOME.y, "down")
  U.wait(12)

  local sfx = game.data and game.data.audio and game.data.audio.sfx or {}
  for _, name in ipairs(CUES) do
    pass(sfx[Sound.resolve(game.data, name)] ~= nil,
      ("this cache carries %s, so the PACK has something to play"):format(name))
  end

  save.inventory = {}
  save.bagOrder = {}
  for _, entry in ipairs(SEED) do
    if game.data.items and game.data.items[entry[1]] then
      save.inventory[entry[1]] = entry[2]
      table.insert(save.bagOrder, entry[1])
    else
      pass(false, entry[1] .. " is not in this cache, so its row is missing")
    end
  end
  Bag.order(save, { items = game.data.items })

  local heard = {}
  local realPlay = Sound.play
  Sound.play = function(data, name)
    heard[#heard + 1] = name
    return realPlay(data, name)
  end

  local function since(mark)
    return heard[#heard] ~= nil and #heard > mark and heard[#heard] or "nothing"
  end

  game.packCursor = nil
  local pack = PackMenu.new(game, { save = save, world = world,
    onClose = function() game.stack:pop() end })
  game.stack:push(pack)
  U.wait(20)

  local function tap(button, frames)
    U.tap(game, button)
    U.wait(frames or 25)
  end

  U.log("listen from here: five sounds, in this order.")

  local mark = #heard
  tap("down")
  tap("up")
  pass(#heard == mark, "moving up and down the list plays nothing")
  U.log("1. no sound at all while the arrow walks the list.")

  mark = #heard
  tap("right")
  pass(since(mark) == "Sfx_SwitchPockets",
    ("right into POKe BALLS played %s"):format(since(mark)))
  U.log("2. the pocket flip: a short two-note sweep as POKe BALLS comes up.")

  mark = #heard
  tap("left")
  pass(since(mark) == "Sfx_SwitchPockets",
    ("left back to ITEMS played %s"):format(since(mark)))
  U.log("3. the same sweep coming back to ITEMS.")

  mark = #heard
  tap("a")
  pass(since(mark) == "Sfx_ReadText2",
    ("A on POTION played %s"):format(since(mark)))
  U.log("4. the menu click as the USE/GIVE/TOSS box opens, and the same")
  U.log("   click again on the B below.")
  tap("b")

  mark = #heard
  tap("select")
  pass(#heard == mark, "SELECT arming the move is silent on the cart too")
  tap("down")
  tap("a")
  local beeps = 0
  for i = mark + 1, #heard do
    if heard[i] == "Sfx_SwitchPokemon" then beeps = beeps + 1 end
  end
  -- engine/items/pack.asm:1309, :1311
  pass(beeps == 2,
    ("placing the item played the swap chirp %d time(s)"):format(beeps))
  U.log("5. the party-swap chirp as POTION lands on the second row, TWICE --")
  U.log("   the second only after the first has finished sounding.")

  Sound.play = realPlay
  U.log(("%d cue(s) missing"):format(failed))
  U.log("cues dispatched: " .. table.concat(heard, ", "))

  while true do coroutine.yield() end
end
