-- engine/menus/pokedex.asm:256
-- engine/gfx/load_pokedex_tiles.asm:8-11
-- engine/battle/draw_hud_pokeball_gfx.asm:189-192
-- data/sgb/sgb_packets.asm:222
--   SHOT_DIR=/tmp/shots POKEPORT_DRIVER=tests/drivers/pokedex_ball_bug2067_test.lua POKEPORT_IDENTITY=bug2067 POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  os.execute('mkdir -p "' .. SHOT_DIR .. '" 2>/dev/null')

  local fails = 0
  local function check(label, ok)
    if not ok then fails = fails + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  check("renderer is up", game.renderer ~= nil)
  check("the cache carries the pokeball sheet",
        love.filesystem.getInfo("assets/generated/battle/balls.png") ~= nil)

  local sheet = love.image.newImageData("assets/generated/battle/balls.png")
  local mids = 0
  for y = 0, 7 do
    for x = 0, 7 do
      local r, g, b, a = sheet:getPixel(x, y)
      if (a or 1) > 0.5 and not (r > 0.9 and g > 0.9 and b > 0.9)
         and not (r < 0.1 and g < 0.1 and b < 0.1) then
        mids = mids + 1
      end
    end
  end
  check("tile 0 of balls.png carries mid shades to colorize (" .. mids .. " px)",
        mids > 0)

  local byDex = {}
  for _, def in pairs(game.data.pokemon) do
    if def.dex then byDex[def.dex] = def end
  end
  game.save.pokedex = { seen = {}, owned = {} }
  for n = 1, 20 do
    local def = byDex[n]
    if def then game.save.pokedex.seen[def.id] = true end
  end
  for _, n in ipairs({ 1, 2, 3 }) do
    local def = byDex[n]
    if def then game.save.pokedex.owned[def.id] = true end
  end

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(20)
  local dex = Screens.push(game, "PokedexMenu")
  U.wait(20)
  check("the dex list is on the stack", game.stack:top() == dex)
  check("dex 001 is owned, so its row carries the ball marker",
        dex.items[1] and dex.items[1].ball == true)

  local function capture()
    local shot
    love.graphics.captureScreenshot(function(imagedata) shot = imagedata end)
    for _ = 1, 180 do
      if shot then break end
      coroutine.yield()
    end
    return shot
  end

  local function ballPixels(shot)
    local r = game.renderer:frameRects()
    local ox, oy = r.uox * r.dpiX, r.uoy * r.dpiY
    local w, h = shot:getDimensions()
    local out = {}
    for gy = 24, 31 do
      for gx = 24, 31 do
        local px = math.floor(ox + (gx + 0.5) * r.Up)
        local py = math.floor(oy + (gy + 0.5) * r.Up)
        if px >= 0 and py >= 0 and px < w and py < h then
          local cr, cg, cb = shot:getPixel(px, py)
          out[#out + 1] = { cr, cg, cb }
        end
      end
    end
    return out
  end

  local function report(mode, label)
    game.save.options = game.save.options or {}
    game.save.options.colors = mode
    game:applyOptions(game.save.options)
    U.wait(4)
    local shot = capture()
    if not check(label .. ": captured a frame", shot ~= nil) then return end
    local path = ("%s/bug2067_%s.png"):format(SHOT_DIR, mode)
    local fd = shot:encode("png")
    local f = io.open(path, "wb")
    if f then f:write(fd:getString()) f:close() end
    local px = ballPixels(shot)
    check(label .. ": the marker cell was sampled", #px > 0)
    local mid, hued = 0, 0
    for _, c in ipairs(px) do
      local white = c[1] > 0.9 and c[2] > 0.9 and c[3] > 0.9
      local black = c[1] < 0.1 and c[2] < 0.1 and c[3] < 0.1
      if not white and not black then
        mid = mid + 1
        if math.abs(c[1] - c[3]) > 0.1 then hued = hued + 1 end
      end
    end
    U.log(label, "mid-shade pixels:", mid, "hued:", hued, "->", path)
    check(label .. ": the marker has mid-shade pixels", mid > 0)
    if mode == "redpp" or mode == "gbc" or mode == "ogred" then
      check(label .. ": the marker carries a hue", hued > 0)
    end
  end

  report("redpp", "ADVANCED")
  report("gbc", "SGB")
  report("ogred", "OG RED")
  report("og", "OG")

  U.log(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
  U.log("Shots are in " .. SHOT_DIR .. ". In every shot the marker left of")
  U.log("MON001 must be the cart's 8x8 pokeball tile - a ringed ball with a")
  U.log("light lower half and a dark upper rim, the same bitmap the party")
  U.log("ball row uses in battle - not a smooth filled circle. In")
  U.log("bug2067_redpp.png it must read brown/orange like the divider column")
  U.log("beside it; the near-miss to watch for is a flat black-and-white ball")
  U.log("while the rest of the screen colorizes.")

  while true do
    coroutine.yield()
  end
end
