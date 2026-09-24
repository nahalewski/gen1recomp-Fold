-- ../pokered/engine/events/prize_menu.asm:217 (#2034)
--   SHOT_DIR=/tmp/prize2034 POKEPORT_IDENTITY=red-aug28 POKEPORT_TOUCH=0 \
--     POKEPORT_VERSION=red \
--     POKEPORT_DRIVER=tests/drivers/prize_full_party_bug2034_test.lua love .

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  os.execute("mkdir -p " .. DIR)

  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local PrizeCounter = require("src.ui.PrizeCounter")

  game.save.party = {}
  for _ = 1, 6 do
    game.save.party[#game.save.party + 1] =
      Pokemon.new(game.data, "BULBASAUR", 5)
  end
  game.save.inventory = game.save.inventory or {}
  game.save.inventory.COIN_CASE = 1
  game.save.coins = 5000

  local function topMeta() return getmetatable(game.stack:top()) end
  local function pageText()
    local top = game.stack:top()
    if getmetatable(top) ~= TextBox then return "" end
    local parts = {}
    for _, page in ipairs(top.pages or {}) do
      if type(page) == "table" then
        for _, line in ipairs(page) do parts[#parts + 1] = tostring(line) end
      end
    end
    return table.concat(parts, " ")
  end
  local function settleText(maxFrames)
    for _ = 1, maxFrames or 60 do
      local top = game.stack:top()
      if getmetatable(top) == TextBox and top.waiting then break end
      U.wait(1)
    end
  end

  U.teleport(game, "GAME_CORNER_PRIZE_ROOM", 2, 3, "up")
  local ow = game.overworld
  U.shot(game, DIR .. "/prize2034_0_before.png")

  U.tap(game, "a")
  local sawMenu = false
  for _ = 1, 120 do
    if topMeta() == PrizeCounter then sawMenu = true break end
    U.tap(game, "a")
    U.wait(1)
  end
  assert(sawMenu, "prize window never opened")
  U.shot(game, DIR .. "/prize2034_1_menu.png")

  local prize = game.stack:top().prizes[1]
  U.log("picking", prize.name, "for", prize.cost, "coins")
  U.tap(game, "a")

  local sawAsk = false
  for _ = 1, 60 do
    if topMeta() == ChoiceBox then sawAsk = true break end
    U.wait(1)
  end
  assert(sawAsk, "SoYouWantPrizeText's YES/NO never appeared")
  U.shot(game, DIR .. "/prize2034_2_confirm.png")
  U.tap(game, "a")

  local sawGot, sawBox = false, false
  for _ = 1, 900 do
    if game.stack:top() == ow then break end
    local text = pageText()
    if text:find("got", 1, true) and text:find(prize.name, 1, true) then
      if not sawGot then
        sawGot = true
        settleText(60)
        U.shot(game, DIR .. "/prize2034_3_gotmon.png")
      end
    end
    if text:find("BOX", 1, true) and text:find("sent", 1, true) then
      if not sawBox then
        sawBox = true
        settleText(120)
        U.shot(game, DIR .. "/prize2034_4_senttobox.png")
      end
    end
    if topMeta() == ChoiceBox then
      U.tap(game, "b")
    else
      U.tap(game, "a")
    end
    U.wait(1)
  end

  U.shot(game, DIR .. "/prize2034_5_after.png")
  U.log("sawGot", sawGot, "sawBox", sawBox, "coins", game.save.coins,
        "top", tostring(topMeta()))
  assert(game.stack:top() == ow,
    "softlock: the prize counter never returned to the overworld (#2034)")
  assert(sawGot, "GotMonText never printed (give_pokemon.asm:68)")
  assert(sawBox, "SentToBoxText never printed (give_pokemon.asm:36)")
  assert(game.save.coins == 5000 - prize.cost,
    "coins were not subtracted exactly once (prize_menu.asm:238)")

  local found = false
  for _, box in ipairs(game.save.boxes or {}) do
    for _, mon in ipairs(box or {}) do
      if mon.species == prize.prize.species then found = true end
    end
  end
  assert(found, "the prize mon is not in a box")
  U.log("prize_full_party_bug2034_test: ok")
end
