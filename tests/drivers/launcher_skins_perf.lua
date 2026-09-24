return function(game)
  local U = dofile("tests/drivers/util.lua")
  local RomImporter = require("src.import.RomImporter")
  local SaveData = require("src.core.SaveData")

  local dir = os.getenv("SHOT_DIR") or os.getenv("POKEPORT_SHOT_DIR")
    or "/tmp/skinperf"
  os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
  love.window.setMode(1280, 800, { resizable = true, highdpi = true })
  U.wait(2)

  local reads = 0
  local realLoad = SaveData.loadOptions
  SaveData.loadOptions = function(...)
    reads = reads + 1
    return realLoad(...)
  end

  local imp = RomImporter.new(function() end, { launcher = true })
  local pending = nil
  love.draw = function()
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

  local function measure(label, frames)
    reads = 0
    local t0 = love.timer.getTime()
    for _ = 1, frames do
      imp:update(1 / 60)
      coroutine.yield()
    end
    local ms = (love.timer.getTime() - t0) * 1000 / frames
    U.log(label, string.format("%.2f ms/frame", ms),
      "loadOptions reads:", tostring(reads))
  end

  imp:_switchTab("skins")
  U.wait(30)
  U.log("tab:", tostring(imp.tab))
  measure("skins", 120)

  pending = dir .. "/skins_tab.png"
  for _ = 1, 90 do
    if not pending then break end
    imp:update(1 / 60)
    coroutine.yield()
  end
  U.wait(3)
  local f = io.open(dir .. "/skins_tab.png", "rb")
  U.log(f and "shot" or "FAIL shot", "skins_tab.png")
  if f then f:close() end

  imp:_switchTab("mods")
  U.wait(30)
  measure("mods", 120)

  SaveData.loadOptions = realLoad
  U.log("done")
  love.event.quit()
  while true do coroutine.yield() end
end
