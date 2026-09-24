-- scripts/Daycare.asm:58,133,161,202
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local Growth = require("src.pokemon.Growth")
  local Sound = require("src.core.Sound")
  local TextBox = require("src.render.TextBox")

  local calls = {}
  local realPlay, realPlayCry, realPlayPika =
    Sound.play, Sound.playCry, Sound.playPikaCry
  Sound.play = function(data, name, ...)
    calls[#calls + 1] = "sfx:" .. tostring(name)
    return realPlay(data, name, ...)
  end
  Sound.playCry = function(data, species, ...)
    calls[#calls + 1] = "cry:" .. tostring(species)
    return realPlayCry(data, species, ...)
  end
  Sound.playPikaCry = function(data, n, ...)
    calls[#calls + 1] = "pika:" .. tostring(n)
    return realPlayPika(data, n, ...)
  end

  local function has(prefix)
    for _, c in ipairs(calls) do
      if c:sub(1, #prefix) == prefix then return true end
    end
    return false
  end

  local function report(ok, what)
    U.log((ok and "PASS " or "FAIL ") .. what)
  end

  local function findBox(pred)
    for _, st in ipairs(game.stack.states) do
      if getmetatable(st) == TextBox and pred(st) then return st end
    end
  end

  local function inOverworld()
    return game.stack:top() == game.overworld
  end

  local function advanceUntil(pred, budget)
    for _ = 1, (budget or 300) do
      if pred() then return true end
      U.tap(game, "a")
      U.wait(4)
    end
    return pred()
  end

  local function idleUntil(pred, budget)
    for _ = 1, (budget or 600) do
      if pred() then return true end
      U.wait(1)
    end
    return pred()
  end

  game.save.party = {
    Pokemon.new(game.data, "RATTATA", 5),
    Pokemon.new(game.data, "PIDGEY", 5),
  }
  game.save.money = 10000
  game.save.player.name = "RED"
  game.save.daycare = nil

  U.teleport(game, "DAYCARE", 2, 4, "up")
  U.wait(30)

  -- scripts/Daycare.asm:47
  U.tap(game, "a")
  U.wait(10)
  advanceUntil(function()
    local b = findBox(function(st) return st.choicePushed end)
    return b ~= nil
  end, 120)
  U.tap(game, "a") -- YES
  U.wait(10)
  advanceUntil(function()
    return game.stack:top() ~= nil
      and game.stack:top().pickOnly ~= nil
  end, 120)
  U.tap(game, "a") -- slot 1
  U.wait(10)
  advanceUntil(function()
    return findBox(function(st) return st.preSound ~= nil end) ~= nil
      or game.save.daycare ~= nil and has("cry:")
  end, 200)
  idleUntil(function() return findBox(function(st) return st.preSound ~= nil end) == nil end, 300)
  report(game.save.daycare ~= nil and game.save.daycare.mon ~= nil, "mon left at the daycare")
  report(has("cry:") or has("pika:"), "cry requested on leave (Daycare.asm:58)")
  advanceUntil(inOverworld, 200)
  U.wait(20)

  -- scripts/Daycare.asm:131
  local dc = game.save.daycare
  if dc and dc.mon then
    local def = game.data.pokemon[dc.mon.species]
    dc.steps = Growth.expForLevel(def.growthRate, dc.mon.level + 2)
      - Growth.expForLevel(def.growthRate, dc.mon.level)
  end
  calls = {}
  U.tap(game, "a")
  U.wait(10)
  local oweBox
  advanceUntil(function()
    oweBox = findBox(function(st) return st.choicePushed end)
    return oweBox ~= nil
  end, 200)
  U.wait(10)
  report(oweBox ~= nil and oweBox:moneyVisible(),
    "OweMoney YES/NO box shows the MONEY box (Daycare.asm:133)")
  U.shot(game, DIR .. "/daycare_2107_00_owe_money_box.png")
  U.tap(game, "a") -- YES
  U.wait(10)
  idleUntil(function() return has("sfx:Purchase") end, 120)
  report(has("sfx:Purchase"), "SFX_PURCHASE requested on YES (Daycare.asm:161)")
  local heres = findBox(function(st) return st.money ~= nil and not st.choice end)
  report(heres ~= nil and heres:moneyVisible(), "MONEY box stays up on HeresYourMon")
  U.shot(game, DIR .. "/daycare_2107_01_heres_your_mon.png")
  advanceUntil(function() return has("cry:") or has("pika:") end, 200)
  report(has("cry:") or has("pika:"), "cry requested on take-back (Daycare.asm:202)")
  report(game.save.daycare == nil and #game.save.party == 2, "mon back in the party")
  U.shot(game, DIR .. "/daycare_2107_02_got_back.png")
  U.log("sound calls:", table.concat(calls, ","))
  U.log("shots under", DIR)

  U.log("input is yours now")
end
