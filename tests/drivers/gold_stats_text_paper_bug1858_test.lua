-- #1858: stats-screen strings stamped white paper over the tinted lower half.
-- Rows 8-17 stay on BG palette 0, whose colour 0 LoadStatsScreenPals sets to
-- the page tint, so a glyph's blank pixels show that tint -- engine/gfx/
-- color.asm:342-359, engine/gfx/cgb_layouts.asm:167-192.  Never POKEPORT_SPEED
-- here: the page redraw and its cry are being judged in order.
--   POKEPORT_IDENTITY=c10-gold POKEPORT_GAME=gold POKEPORT_TOUCH=0 POKEPORT_DRIVER=tests/drivers/gold_stats_text_paper_bug1858_test.lua POKEPORT_SHOT_DIR=/tmp/gold-bug1858 love .
local U = require("tests.drivers.util")

local GbcPalette = require("src.render.GbcPalette")
local Mon = require("src.battle.gen2.Mon")
local SummaryMenu = require("src.ui.gen2.SummaryMenu")

-- The rows the lower half prints on: EXP POINTS / LEVEL UP / TO on the pink
-- page, ITEM and the move list on green, <ID>№. and OT/ on blue.
local TEXT_ROWS = {
  [SummaryMenu.PINK_PAGE] = {
    { "the EXP POINTS row", 80, 72, 159, 79 },
    { "the STATUS/ row", 0, 96, 55, 103 },
    { "the LEVEL UP row", 80, 96, 159, 103 },
  },
  [SummaryMenu.GREEN_PAGE] = {
    { "the ITEM row", 0, 64, 159, 71 },
    { "the first move name", 64, 80, 159, 87 },
    { "the first PP row", 96, 88, 159, 95 },
  },
  [SummaryMenu.BLUE_PAGE] = {
    { "the ID No. row", 0, 72, 79, 79 },
    { "the OT/ row", 0, 96, 79, 103 },
    { "the ATTACK row", 88, 64, 159, 71 },
  },
}

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-bug1858"
  local fails, lines = 0, {}
  local function claim(ok, text)
    if not ok then fails = fails + 1 end
    lines[#lines + 1] = (ok and "PASS " or "FAIL ") .. text
    return ok
  end
  local function tap(button)
    U.tap(game, button)
    U.wait(4)
  end
  local function top() return game.stack:top() end
  local function waitFor(id, limit)
    for _ = 1, limit or 120 do
      local state = top()
      if (state and state.screenId or nil) == id then return true end
      U.wait(1)
    end
    return false
  end

  U.wait(45)
  if not (game.world and game.world.map) then
    U.log("FAIL the gold world never booted, nothing to open a summary over")
    while true do coroutine.yield() end
  end

  local save = game.save
  save.player.name = "GOLD"
  save.party = { Mon.new(game.data, "CYNDAQUIL", 22),
                 Mon.new(game.data, "TOTODILE", 18) }
  local lead = save.party[1]
  lead.item = "BERRY"
  lead.hp = math.max(1, math.floor((lead.maxHp or 1) * 0.45))
  claim(GbcPalette.available(), "the GBC shade-remap shader compiled")
  game.options = game.options or {}
  game.options.color = "gbc"
  save.options = game.options
  GbcPalette.applyOptions(game.options)
  claim(GbcPalette.mode == "gbc", "COLOR is GBC for the run")

  -- The summary draws at GB coordinates, so a 160x144 canvas at scale 1 makes
  -- a GB pixel a pixel and the paper countable.
  local function frameOf(screen)
    local G = love.graphics
    local canvas = G.newCanvas(160, 144)
    G.setCanvas(canvas)
    G.clear(0, 0, 0, 1)
    G.setColor(1, 1, 1, 1)
    screen:draw()
    G.setCanvas()
    G.setColor(1, 1, 1, 1)
    return canvas:newImageData()
  end

  local function whitePct(img, rect)
    local white, total = 0, 0
    for y = rect[3], rect[5] do
      for x = rect[2], rect[4] do
        local r, g, b = img:getPixel(x, y)
        total = total + 1
        if r * 255 > 250 and g * 255 > 250 and b * 255 > 250 then
          white = white + 1
        end
      end
    end
    return white / total * 100
  end

  tap("start")
  local menu = top()
  if not claim(menu and menu.screenId == "Gen2StartMenu",
      "START opened the menu") then
    for _, line in ipairs(lines) do U.log(line) end
    while true do coroutine.yield() end
  end
  for _ = 1, 10 do
    if menu.list:current().value == "pokemon" then break end
    tap("down")
  end
  tap("a")
  waitFor("Gen2PartyMenu", 90)
  local party = top()
  if not claim(party and party.screenId == "Gen2PartyMenu",
      "that opened the party list") then
    for _, line in ipairs(lines) do U.log(line) end
    while true do coroutine.yield() end
  end
  tap("a")
  tap("a")
  local summary = top()
  if not claim(summary and summary.screenId == "Gen2SummaryMenu",
      "STATS opened the summary") then
    for _, line in ipairs(lines) do U.log(line) end
    while true do coroutine.yield() end
  end

  local NAMES = { "pink", "green", "blue" }
  local function inspect(shot)
    local img = frameOf(summary)
    local page = summary.page
    for _, rect in ipairs(TEXT_ROWS[page] or {}) do
      local pct = whitePct(img, rect)
      U.log(("  %-22s %5.1f%% white"):format(rect[1], pct))
      claim(pct <= 1, ("%s (%s page) has no white paper behind it"):format(
        rect[1], NAMES[page] or "?"))
    end
    U.shot(game, ("%s/%s.png"):format(out, shot))
  end

  inspect("01-pink-page")
  tap("right")
  claim(summary.page == SummaryMenu.GREEN_PAGE, "right reached the green page")
  inspect("02-green-page")
  tap("right")
  claim(summary.page == SummaryMenu.BLUE_PAGE, "right reached the blue page")
  inspect("03-blue-page")
  tap("right")

  for _, line in ipairs(lines) do U.log(line) end
  U.log(("%d checks, %d failed"):format(#lines, fails))
  if fails > 0 then
    U.log("a FAIL above means the run is not showing what it claims to")
  end
  U.log("what right looks like: everything under the rule is one flat wash of")
  U.log("the page colour, with the letters and numbers sitting straight on it.")
  U.log("a white box the width of each string is the bug; a white box behind")
  U.log("only the numbers, or only the upper half tinted, is a half fix.")
  U.log("left and right turn the page; the pad is yours.")

  while true do coroutine.yield() end
end
