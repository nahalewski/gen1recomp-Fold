return function(game)
  local U = dofile("tests/drivers/util.lua")
  local RomImporter = require("src.import.RomImporter")

  local dir = os.getenv("SHOT_DIR") or "/tmp/findtags"
  os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
  love.window.setMode(1024, 768, { resizable = true, highdpi = true })
  U.wait(2)

  local imp = RomImporter.new(function() end, { launcher = true })

  local function mod(id, title, games, tags)
    return {
      id = id, title = title, author = "someone", version = "1.0.0",
      summary = "A canned listing for the screenshot.",
      categories = { "GAMEPLAY" }, tags = tags, games = games,
      update_check = "off",
      latest = { version = "1.0.0", zip = {
        url = "https://example.invalid/" .. id .. ".zip" } },
    }
  end

  imp._refreshFindSources = function() end
  imp._refreshFind = function() end
  imp._pumpFindFetch = function() end
  imp._findFetch = nil
  imp.findSources = { { feed = "https://example.invalid/data/index.json",
                        base = "https://example.invalid/",
                        label = "example/index" } }
  imp.findIndex = { schemaVersion = 1, categories = { "GAMEPLAY" }, mods = {
    mod("kanto", "Kanto Only", { "gen1" }, { "challenge", "balance" }),
    mod("johto", "Johto Only", { "gen2" }, { "qol" }),
    mod("both", "Every Game", { "all" }, { "audio" }),
    mod("silent", "Says Nothing", {}, {}),
    mod("gold", "Gold Alone", { "gold" }, { "sprites", "art", "extra" }),
  } }
  imp.findLoaded = true
  imp:_switchTab("find")
  U.wait(3)

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

  imp.modScope = "gold"
  U.wait(2)
  shot("find_tags_all.png")
  U.log("rows with modScope=gold:", tostring(#imp:_findRows()))

  imp._filterPopup = true
  U.wait(2)
  shot("find_filter_popup.png")
  imp._filterPopup = nil

  for _, key in ipairs({ "gen1", "gen2" }) do
    imp:_setFindGame(key)
    U.wait(2)
    shot("find_game_" .. key .. ".png")
    local ids = {}
    for _, e in ipairs(imp:_findRows()) do ids[#ids + 1] = e.id end
    U.log("game " .. key .. ":", table.concat(ids, ", "))
  end
  imp:_setFindGame(nil)

  love.window.setMode(520, 820, { resizable = true, highdpi = true })
  U.wait(4)
  shot("find_tags_narrow.png")

  U.log("done")
  love.event.quit()
end
