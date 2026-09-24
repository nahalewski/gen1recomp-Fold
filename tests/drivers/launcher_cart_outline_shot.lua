--   POKEPORT_IDENTITY=crystal-aug31 SHOT_DIR=/tmp/cartoutline \
--     POKEPORT_DRIVER=tests/drivers/launcher_cart_outline_shot.lua love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local RomImporter = require("src.import.RomImporter")
  local Kit = require("src.ui.kit.Kit")

  local dir = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/cartoutline"
  os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
  love.window.setMode(1024, 768, { resizable = true, highdpi = true })
  U.wait(2)

  local imp = RomImporter.new(function() end, { launcher = true })

  local hold = nil
  local pending = nil
  love.draw = function()
    if hold then
      Kit.focusId = hold
      Kit._ringShown = true
    end
    imp:draw()
    if pending then
      local path = pending
      pending = nil
      love.graphics.captureScreenshot(function(imagedata)
        local f = io.open(path, "wb")
        if f then f:write(imagedata:encode("png"):getString()) f:close() end
      end)
    end
  end
  local function shot(name)
    pending = dir .. "/" .. name
    for _ = 1, 90 do
      if not pending then break end
      imp:update(1 / 60)
      coroutine.yield()
    end
    U.wait(3)
    local f = io.open(dir .. "/" .. name, "rb")
    U.log(f and "shot" or "FAIL shot", name)
    if f then f:close() end
  end

  for _, version in ipairs({ "crystal", "red" }) do
    imp:_switchTab(version)
    for _ = 1, 60 do imp:update(1 / 60); coroutine.yield() end
    U.log("tab:", imp.tab, "ready:", tostring(imp.ready and imp.ready[version]),
      "blockClicks:", tostring(Kit.blockClicks))

    hold = "play-" .. version
    U.wait(20)
    shot(version .. "_highlighted.png")

    hold = nil
    imp:touchpressed(1, 40, 40, 0, 0, 1)
    U.wait(20)
    U.log("ring after touch:", tostring(Kit._ringShown))
    shot(version .. "_plain.png")
  end

  U.log("done")
  love.event.quit()
  while true do coroutine.yield() end
end
