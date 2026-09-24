-- pokered engine/gfx/screen_effects.asm:1-12 (#1872)
--   POKEPORT_DRIVER=tests/drivers/poison_flicker_bug1872_test.lua POKEPORT_IDENTITY=bug1872 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local PaletteFX = require("src.render.PaletteFX")
  local Zoom = require("src.render.Zoom")
  local Renderer = require("src.render.Renderer")

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 50) }
  game.save.party[1].status = "PSN"
  game.save.player.name = "bryan"

  local lo = Zoom.offsetRange(Renderer:fitScale())
  game.save.options.zoom = lo
  Zoom.applyOptions(game.save.options)

  U.teleport(game, "ROUTE_1", 5, 20, "down")
  U.wait(20)

  local rects = {}
  local realRect = love.graphics.rectangle
  love.graphics.rectangle = function(mode, x, y, w, h, ...)
    if mode == "fill" and x == 0 and y == 0 and w == 160 and h == 144 then
      rects[#rects + 1] = true
    end
    return realRect(mode, x, y, w, h, ...)
  end

  -- engine/events/poison.asm
  local ow = game.overworld
  local function walkToTick()
    for i = 1, 160 do
      local dir = (i % 2 == 0) and "up" or "down"
      for _ = 1, 2 do
        table.insert(game.input.pressQueue, dir)
        game.input.state[dir] = true
        coroutine.yield()
        ow = game.overworld
        if (ow and ow.poisonFlash or 0) > 0 then
          game.input.state[dir] = false
          return true
        end
      end
      game.input.state[dir] = false
    end
    return false
  end

  local armed = walkToTick()
  check("a poison tick armed the flicker while walking", armed)

  -- DelayFrames counts vblanks (engine/gfx/screen_effects.asm:1-12, #1908)
  local lit, sawMap, drawSafe = armed and 1 or 0, false, true
  for _ = 1, 12 do
    local before = ow.poisonFlash or 0
    if before > 0 then
      for _ = 1, 3 do pcall(function() ow:drawUI() end) end
      if (ow.poisonFlash or 0) ~= before then drawSafe = false end
    end
    if PaletteFX.shadeMap() == PaletteFX.POISON_BGP then sawMap = true end
    coroutine.yield()
    ow = game.overworld
    if (ow.poisonFlash or 0) > 0 then lit = lit + 1 else break end
  end
  U.log("tinted frames", lit)
  if armed then
    check("it arms four frames, like `ld c, 4 / call DelayFrames`", lit == 4)
    check("extra draws inside one logic step never shorten it", drawSafe)
  end
  check("the flicker goes through the rBGP shade map, not a canvas overlay",
        sawMap)
  check("nothing filled the 160x144 UI canvas during the flash", #rects == 0)
  love.graphics.rectangle = realRect

  U.shot(game, "poison_flicker_bug1872.png")

  PaletteFX.setMode("redpp")
  game.save.options.colors = "redpp"
  U.wait(30)
  ow = game.overworld
  local advanced = PaletteFX.usesGbcPack() and ow.map and ow.map.renderer
                   and ow.map.renderer.gbcAtlas ~= nil
  check("ADVANCED is live with a baked atlas", advanced and true or false)
  if walkToTick() then
    local veiled, doubled = false, false
    for _ = 1, 8 do
      local r = game.renderer
      if r and r.screenVeil and r.screenVeil[2] > 0 then veiled = true end
      if PaletteFX.shadeMap() == PaletteFX.POISON_BGP then doubled = true end
      if (ow.poisonFlash or 0) <= 0 then break end
      coroutine.yield()
      ow = game.overworld
    end
    check("ADVANCED falls back to the whole-window veil", veiled)
    check("and arms no shade map on top of the veil", not doubled)
    U.shot(game, "poison_flicker_bug1908_advanced.png")
  else
    check("a second poison tick fired under ADVANCED", false)
  end
  U.log("walk around with the poisoned CHARIZARD: every fourth step the WHOLE")
  U.log("window should darken for four frames, survey map and letterbox bars")
  U.log("included, not just the 160x144 box in the middle.")
  U.log("white background pixels drop one shade; sprites and dark tiles stay put.")
  U.log("The run left COLORS on ADVANCED, where the shift comes from the veil")
  U.log("rather than the shade map: switch back through OPTIONS and compare --")
  U.log("both should darken by the same amount and for the same four frames.")

  while true do
    coroutine.yield()
  end
end
