-- engine/items/item_effects.asm:779-793 (#2072)
--   POKEPORT_IDENTITY=red-dev POKEPORT_VERSION=red POKEPORT_TOUCH=0 \
--     POKEPORT_DRIVER=tests/drivers/evo_stone_sfx_bug2072_test.lua love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local Bag = require("src.inventory.Bag")
  local PartyMenu = require("src.ui.PartyMenu")
  local EvolutionState = require("src.ui.EvolutionState")
  local Sound = require("src.core.Sound")

  local failed = 0
  local function check(label, ok)
    if not ok then failed = failed + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end
  local function findByMeta(mt)
    for _, s in ipairs(game.stack.states) do
      if getmetatable(s) == mt then return s end
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

  local heard = {}
  local realPlay = Sound.play
  Sound.play = function(data, name, ...)
    heard[#heard + 1] = name
    return realPlay(data, name, ...)
  end
  local function firstAfter(mark)
    for i = mark + 1, #heard do
      if heard[i] ~= "Press_AB" then return heard[i], i end
    end
    return nil, nil
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
    return findByMeta(PartyMenu)
  end

  if not check("the party picker opened", openPicker() ~= nil) then
    while true do coroutine.yield() end
  end

  local picker = findByMeta(PartyMenu)
  picker.index, game.partyMenuSavedIndex = 2, 2
  U.wait(4)
  local mark = #heard
  U.tap(game, "a")
  U.wait(6)
  local cue = firstAfter(mark)
  check("the wrong-target stone plays Heal_Ailment, got " .. tostring(cue),
        cue == "Heal_Ailment")
  check("and the no-effect box follows it",
        waitFor(function()
          local t = topText()
          return t ~= nil and t:find("effect") ~= nil
        end, 240))

  for _ = 1, 30 do
    if findByMeta(PartyMenu) == nil then break end
    U.tap(game, "a")
    U.wait(10)
  end
  U.wait(20)

  if not check("the picker reopened for the second stone",
               openPicker() ~= nil) then
    while true do coroutine.yield() end
  end
  picker = findByMeta(PartyMenu)
  picker.index, game.partyMenuSavedIndex = 1, 1
  U.wait(4)
  mark = #heard
  U.tap(game, "a")
  U.wait(6)
  local cue2, at = firstAfter(mark)
  check("the evolving stone plays Heal_Ailment, got " .. tostring(cue2),
        cue2 == "Heal_Ailment")
  check("GLOOM starts evolving", waitFor(function()
    local t = topText()
    return t ~= nil and t:find("evolving") ~= nil
  end, 240))
  check("the movie starts", waitFor(function()
    return findByMeta(EvolutionState) ~= nil
  end, 400))
  local tink
  for i = (at or 0) + 1, #heard do
    if heard[i] == "Tink" then tink = i break end
  end
  check("and the movie's Tink lands after the jingle, not before",
        tink ~= nil and at ~= nil and tink > at)
  check("the evolution lands", waitFor(function()
    return gloom.species == "VILEPLUME"
  end, 900))

  U.log("cues:", table.concat(heard, " "))
  U.log(failed == 0 and "ALL PASS" or (failed .. " FAILURES"))
  U.log("By ear: a healing jingle on BOTH stone uses - the one that says")
  U.log("\"It won't have any effect!\" and the one that evolves GLOOM.")

  while true do coroutine.yield() end
end
