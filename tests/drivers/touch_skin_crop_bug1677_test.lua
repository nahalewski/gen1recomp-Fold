--   SHOT_DIR=/tmp/skin1677 POKEPORT_TOUCH=1 \
--     POKEPORT_DRIVER=tests/drivers/touch_skin_crop_bug1677_test.lua love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local TouchControls = require("src.core.TouchControls")
  local TouchSkin = require("src.core.TouchSkin")
  local Pokemon = require("src.pokemon.Pokemon")

  local dir = os.getenv("SHOT_DIR") or "/tmp/skin1677"
  local skinId = os.getenv("SKIN") or "gb_anim"
  local shotW = tonumber(os.getenv("SHOT_W")) or 1600
  local shotH = tonumber(os.getenv("SHOT_H")) or 720
  love.window.setMode(shotW, shotH, { resizable = true, highdpi = true })
  U.wait(2)

  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 50) }
  game.save.player.name = "bryan"
  game.save.options.touchControls = { enabled = true, skin = skinId }
  game.save.options.tilt = 0
  game.save.options.zoom = 0
  game.save.options.pipelines = {}
  game:applyOptions()

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  local ww, wh = love.graphics.getDimensions()
  local page = TouchSkin.page()
  U.log("skin:", tostring(TouchControls.skinId), "page:", page and page.name,
        "window:", ww .. "x" .. wh)
  if not page then
    U.log("FAIL: no skin page active, cannot judge the overlay art")
    while true do coroutine.yield() end
  end

  local bx, by, bw, bh = TouchSkin.pageBox(page, ww, wh)
  U.log("page box:", string.format("%.1f,%.1f %.1fx%.1f", bx, by, bw, bh))

  local function report(label, img, w, h)
    if not img then return true end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, sy = TouchSkin.imageFit(iw, ih, w, h)
    if not sx then
      U.log("FAIL:", label, "zero-sized image")
      return false
    end
    local dw, dh = iw * sx, ih * sy
    local fits = dw <= w + 0.01 and dh <= h + 0.01
    U.log(string.format("%-14s art %dx%d dest %.1fx%.1f drawn %.1fx%.1f%s",
      label, iw, ih, w, h, dw, dh, fits and "" or "  CROPPED"))
    return fits
  end

  local ok = report("page bezel", page.image, bw, bh)
  for i, ctl in ipairs(page.controls) do
    if ctl.image then
      local _, _, halfW, halfH = TouchSkin.controlGeometry(page, ctl, ww, wh)
      local label = (ctl.buttons and ctl.buttons[1]) or ("desc" .. (i - 1))
      if not report(label, ctl.image, halfW * 2, halfH * 2) then ok = false end
    end
  end

  U.log(ok and "PASS: every overlay bitmap draws whole inside its dest box"
           or "FAIL: some overlay art is drawn larger than its dest box")
  U.shot(game, dir .. "/skin_wide.png")
  U.log("shot:", dir .. "/skin_wide.png")
  U.log("right looks like: each button keeps its full outline ring, and the")
  U.log("art may look stretched on a window that is not the overlay aspect,")
  U.log("but no edge of any button graphic is sliced off.")

  while true do coroutine.yield() end
end
