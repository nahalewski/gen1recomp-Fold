return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Kit = require("src.ui.kit.Kit")
  local Theme = require("src.ui.kit.Theme")

  local dir = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/spin2048"
  os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
  love.window.setMode(1024, 768, { resizable = true, highdpi = true })
  U.wait(2)

  local frozen = 0
  local pending = nil
  love.draw = function()
    Kit.scale = 2
    Theme.fill(0, 0, 1024, 768, Theme.PAL.bg, 1)
    Kit.spinner(256, 384, 120, frozen)
    Kit.spinner(768, 384, 24, frozen)
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
      coroutine.yield()
    end
    U.wait(3)
    local f = io.open(dir .. "/" .. name, "rb")
    U.log(f and "shot" or "FAIL shot", name)
    if f then f:close() end
  end

  for i = 0, 3 do
    frozen = i * 0.1
    U.wait(4)
    shot(string.format("spin_t%02d.png", i))
  end

  love.draw = function()
    Kit.scale = 2
    Kit.time = love.timer.getTime()
    Theme.fill(0, 0, 1024, 768, Theme.PAL.bg, 1)
    Kit.spinner(256, 384, 120)
    Kit.spinner(768, 384, 24)
  end
  U.wait(180)

  U.log("done")
  love.event.quit()
  while true do coroutine.yield() end
end
