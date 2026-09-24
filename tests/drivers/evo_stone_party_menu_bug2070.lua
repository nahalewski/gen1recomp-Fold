-- engine/items/item_effects.asm:772-793
-- engine/pokemon/evos_moves.asm:120-134
-- engine/menus/start_sub_menus.asm:408-419
--   SHOT_DIR=/tmp/evo2070 POKEPORT_DRIVER=tests/drivers/evo_stone_party_menu_bug2070.lua \
--     POKEPORT_IDENTITY=bug2070 POKEPORT_VERSION=red POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local Bag = require("src.inventory.Bag")
  local PartyMenu = require("src.ui.PartyMenu")
  local EvolutionState = require("src.ui.EvolutionState")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/evo2070"
  os.execute("mkdir -p " .. SHOT_DIR)

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end
  local function findByMeta(mt)
    for _, s in ipairs(game.stack.states) do
      if getmetatable(s) == mt then return s end
    end
  end
  local function findPicker() return findByMeta(PartyMenu) end
  local function findEvo() return findByMeta(EvolutionState) end
  local function bagList()
    for _, s in ipairs(game.stack.states) do
      if s.screenId == "BagMenu" then return s end
    end
  end
  local function topText()
    local t = game.stack:top()
    if not (t and t.pages) then return nil end
    local out = {}
    for _, page in ipairs(t.pages) do
      for _, line in ipairs(page) do out[#out + 1] = line end
    end
    return table.concat(out, " ")
  end
  local function waitFor(fn, frames)
    for _ = 1, frames or 600 do
      if fn() then return true end
      U.wait(1)
    end
    return false
  end
  local function hasText(needle)
    return function()
      local t = topText()
      return t ~= nil and t:find(needle) ~= nil
    end
  end

  local gloom = Pokemon.new(game.data, "GLOOM", 25)
  local rattata = Pokemon.new(game.data, "RATTATA", 25)
  game.save.party = { gloom, rattata }
  game.save.inventory = {}
  Bag.add(game.save, "LEAF_STONE", 2, game.data)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  local function openPicker()
    Screens.push(game, "BagMenu", {})
    U.wait(12)
    U.tap(game, "a")
    U.wait(12)
    U.tap(game, "a")
    U.wait(12)
    return findPicker()
  end

  if not check("the party picker opened for the first stone", openPicker() ~= nil) then
    while true do coroutine.yield() end
  end
  U.tap(game, "down")
  U.wait(8)
  U.tap(game, "a")
  check("a stone RATTATA cannot use prints ItemUseNoEffect",
        waitFor(hasText("effect"), 200))
  U.wait(20)
  U.shot(game, SHOT_DIR .. "/evo2070_1_no_effect.png")
  check("with the party menu still on the stack under it",
        findPicker() ~= nil)
  check("and the stone was not consumed",
        game.save.inventory.LEAF_STONE == 2)
  for _ = 1, 40 do
    if findPicker() == nil and game.stack:top() == bagList() then break end
    U.tap(game, "a")
    U.wait(10)
  end
  check("dismissing it lands back on the ITEM list",
        findPicker() == nil and game.stack:top() == bagList())

  U.tap(game, "a")
  U.wait(12)
  U.tap(game, "a")
  U.wait(12)
  local picker = findPicker()
  if not check("the picker opened again", picker ~= nil) then
    while true do coroutine.yield() end
  end
  picker.index, game.partyMenuSavedIndex = 1, 1
  U.wait(4)
  U.tap(game, "a")
  check("GLOOM starts evolving", waitFor(hasText("evolving"), 200))
  U.wait(20)
  U.shot(game, SHOT_DIR .. "/evo2070_2_is_evolving.png")
  check("with the party menu still up through the 50-frame hold",
        findPicker() ~= nil)

  check("the movie starts", waitFor(findEvo, 400))
  U.wait(20)
  U.shot(game, SHOT_DIR .. "/evo2070_3_movie.png")
  check("the evolution lands", waitFor(function()
    return gloom.species == "VILEPLUME"
  end, 900))

  for _ = 1, 40 do
    if findEvo() == nil and findPicker() == nil
       and game.stack:top() == bagList() then break end
    U.tap(game, "a")
    U.wait(12)
  end
  U.wait(20)
  U.shot(game, SHOT_DIR .. "/evo2070_4_back_in_items.png")
  check("and the player is returned to the ITEM list, picker gone",
        findPicker() == nil and game.stack:top() == bagList())

  U.log("shots in", SHOT_DIR)
  U.log("Right: shots 1 and 2 show the PARTY list (GLOOM/RATTATA with HP bars)")
  U.log("behind the text box; shot 4 is the ITEM list with LEAF STONE x1.")
  U.log("Wrong: shot 1 or 2 shows the ITEM list behind the box, or shot 4")
  U.log("still has the party menu over the bag.")

  while true do coroutine.yield() end
end
