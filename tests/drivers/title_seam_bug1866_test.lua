-- Manual check for #1866: black hairlines at the title's SGB zone boundaries
-- (canvas rows 64 and 80, BlkPacket_Titlescreen, data/sgb/sgb_packets.asm:
-- 123-127) at window heights that are not a whole multiple of 144.
--   POKEPORT_DRIVER=tests/drivers/title_seam_bug1866_test.lua POKEPORT_TOUCH=0 SHOT_DIR=/tmp/shots love .
-- Do not set POKEPORT_SPEED: fast-forward desynchronizes the title music.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local title
  for _ = 1, 120 do
    local top = game.stack:top()
    if top and top.screenId == "TitleState" and top.sgbPalettes then
      title = top
      break
    end
    U.tap(game, "start")
    U.wait(9)
  end
  check("the title screen is on top", title ~= nil)
  if not (title and title.sgbPalettes) then
    U.log("No title state to look at; nothing below can run.")
    while true do coroutine.yield() end
  end

  local opts = game.save.options
  local mode = opts and opts.colors or PaletteFX.mode
  if PaletteFX.mode ~= "gbc" then
    U.log("COLORS is", tostring(mode) .. "; switching the view to SGB for the check")
    PaletteFX.setMode("gbc")
    U.wait(20)
  end
  local zones = PaletteFX.ensureZones(title:sgbPalettes(game))
  check("the title builds three SGB zones", zones ~= nil and #zones == 3)

  -- Every height below is odd and none is a multiple of 144, so the picture
  -- never lands on a whole number of screen pixels per GB pixel.  "fill"
  -- additionally drops the integer fit scale, which is the shape the report's
  -- screenshot was taken in (about 5.98 screen pixels per GB pixel).
  local HEIGHTS = { 721, 823, 907, 1013 }
  local WIDTH = 1157
  local worstRows, worstTag = 0, "none"

  -- the control: a zone list with a real hole in it, drawn the way the
  -- per-zone pass alone would draw it.  It proves the sampler below can see
  -- a seam at all, and that the underpaint is what closes this one.
  local gapped = {}
  for i, z in ipairs(zones) do
    gapped[i] = { x = z.x, y = z.y, w = z.w, h = z.h, colors = z.colors }
  end
  if gapped[2] then
    gapped[2].y = gapped[2].y + 1
    gapped[2].h = gapped[2].h - 2
  end

  local function drawZonesOnly(zoneList, Ux, Uy, uox, uoy)
    local shader = PaletteFX.shader()
    love.graphics.setShader(shader)
    for _, z in ipairs(zoneList) do
      PaletteFX.sendColors(shader, z.colors)
      love.graphics.setScissor(uox + z.x * Ux, uoy + z.y * Uy,
                               z.w * Ux, z.h * Uy)
      love.graphics.draw(Renderer.canvas, uox, uoy, 0, Ux, Uy)
    end
    love.graphics.setScissor()
    love.graphics.setShader()
  end

  local function probeAt(ph, fill, zoneList, zonesOnly)
    local dpi = 1
    local probe = love.graphics.newCanvas(WIDTH, ph, { dpiscale = dpi })
    local Up
    if fill then
      Up = math.min(ph / 144, WIDTH / 160)
    else
      Up = math.max(1, math.floor(math.min(WIDTH / 160, ph / 144)))
    end
    local Ux, Uy = Up / dpi, Up / dpi
    local uox = math.floor((WIDTH - 160 * Up) / 2) / dpi
    local uoy = math.floor((ph - 144 * Up) / 2) / dpi
    local uvpw, uvph = 160 * Ux, 144 * Uy
    love.graphics.setCanvas(probe)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    if zonesOnly then
      drawZonesOnly(zoneList, Ux, Uy, uox, uoy)
    else
      Renderer:blitCanvas(Renderer.canvas, Ux, Uy, zoneList, Ux, Uy,
                          uox, uoy, uox, uoy, uvpw, uvph, dpi, dpi)
    end
    love.graphics.setCanvas()
    local data = probe:newImageData()
    local top = math.floor(uoy * dpi) + 1
    local bottom = math.min(math.floor((uoy + uvph) * dpi) - 1, data:getHeight() - 1)
    local col = math.floor(uox * dpi) + 2
    local rows = {}
    for py = top, bottom do
      local r, g, b = data:getPixel(col, py)
      if r < 0.02 and g < 0.02 and b < 0.02 then rows[#rows + 1] = py end
    end
    return rows, ("%dx%d %s"):format(WIDTH, ph, fill and "fill" or "fit")
  end

  for _, ph in ipairs(HEIGHTS) do
    for _, fill in ipairs({ false, true }) do
      local rows, tag = probeAt(ph, fill, zones, false)
      if #rows > worstRows then worstRows, worstTag = #rows, tag end
      check(tag .. ": no letterbox row shows through a zone boundary",
            #rows == 0)
      if #rows > 0 then
        U.log("  black rows:", table.concat(rows, ","))
      end
    end
  end
  U.log("worst case:", worstRows, "black rows at", worstTag)

  local holeRows = probeAt(HEIGHTS[3], true, gapped, true)
  check("a zone list with a hole in it does show the letterbox clear",
        #holeRows > 0)
  local filledRows = probeAt(HEIGHTS[3], true, gapped, false)
  check("and the same hole drawn through the renderer shows none",
        #filledRows == 0)

  -- and the live window at one of those heights, for the eye
  local ok = pcall(love.window.setMode, WIDTH, HEIGHTS[3],
                   { resizable = true, vsync = 0 })
  check("the window resized to " .. WIDTH .. "x" .. HEIGHTS[3], ok)
  U.wait(20)
  check("wrote " .. SHOT_DIR .. "/bug1866_title_907.png",
        U.shot(game, SHOT_DIR .. "/bug1866_title_907.png"))
  pcall(love.window.setMode, WIDTH, HEIGHTS[4], { resizable = true, vsync = 0 })
  U.wait(20)
  check("wrote " .. SHOT_DIR .. "/bug1866_title_1013.png",
        U.shot(game, SHOT_DIR .. "/bug1866_title_1013.png"))

  PaletteFX.setMode(mode)
  U.wait(10)

  U.log("Look along the title picture where the POKeMON logo meets the red")
  U.log("VERSION ribbon, and where the ribbon meets RED and the copyright: the")
  U.log("off-white background must run through both boundaries unbroken.")
  U.log("The near-miss is a hairline one or two pixels tall that is dark grey")
  U.log("or slightly off-white rather than black; that is still the seam.")

  while true do
    coroutine.yield()
  end
end
