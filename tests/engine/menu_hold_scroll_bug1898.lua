-- home/joypad2.asm:16-53 (#1898)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

package.loaded["src.render.Font"] = {
  BORDER = { tl = 1, tr = 2, bl = 3, br = 4, h = 5, v = 6 },
  draw = function() end,
  drawCode = function() end,
  drawBox = function() end,
  width = function(text) return #tostring(text) * 8 end,
  split = function(text)
    local spans = {}
    for i = 1, #tostring(text) do spans[i] = { from = i, to = i } end
    return spans
  end,
  spansFitting = function(spans) return #spans end,
}

local MenuRepeat = require("src.ui.MenuRepeat")
local ListMenu = require("src.ui.ListMenu")

local function newInput()
  local input = { edges = {}, held = {} }
  function input:press(button)
    self.edges[button] = true
    self.held[button] = true
  end
  function input:release(button)
    self.edges[button] = nil
    self.held[button] = nil
  end
  function input:wasPressed(button)
    if self.edges[button] then
      self.edges[button] = nil
      return true
    end
    return false
  end
  function input:isDown(button) return self.held[button] == true end
  return input
end

do
  eq(MenuRepeat.GEN1_DELAY, 30, "half a second before the first repeat")
  eq(MenuRepeat.GEN1_RATE, 5, "then 1/12 of a second between repeats")
  eq(MenuRepeat.GEN2_DELAY, 15, "JoyTextDelay seeds wTextDelayFrames with 15")
  eq(MenuRepeat.GEN2_RATE, 5, "and reseeds it with 5")

  local input = newInput()
  local state = MenuRepeat.new(MenuRepeat.GEN1_DELAY, MenuRepeat.GEN1_RATE)
  input:press("down")
  local dir, edge = MenuRepeat.direction(state, input, { "up", "down" })
  eq(dir, "down", "the press itself reports immediately")
  eq(edge, true, "and is flagged as the edge")

  local fired = {}
  for frame = 1, 60 do
    local d = MenuRepeat.direction(state, input, { "up", "down" })
    if d then fired[#fired + 1] = frame end
  end
  eq(fired[1], 30, "the hold is ignored for half a second")
  eq(fired[2], 35, "then repeats every five frames")
  eq(fired[3], 40, "and keeps repeating")
  eq(#fired, 7, "seven repeats in the second after the press")

  input:release("down")
  eq(MenuRepeat.direction(state, input, { "up", "down" }), nil,
     "letting go stops it")
  eq(state.frames, 0, "and clears the counter, so the next hold waits again")

  local off = MenuRepeat.new(MenuRepeat.GEN1_DELAY, MenuRepeat.GEN1_RATE, false)
  input:press("down")
  MenuRepeat.direction(off, input, { "up", "down" })
  local repeated = false
  for _ = 1, 120 do
    if MenuRepeat.direction(off, input, { "up", "down" }) then repeated = true end
  end
  check(not repeated, "a disabled state stays edge-only")
  input:release("down")
end

do
  local items = {}
  for i = 1, 10 do items[i] = { value = i, label = "ITEM " .. i } end
  local input = newInput()
  local game = { input = input,
                 stack = { push = function() end, pop = function() end,
                           top = function() end } }
  local list = ListMenu.new(game, "ITEMS", items, { kind = "bag", itemBox = true })
  eq(list.keyRepeat, true,
     "DisplayListMenuID runs with hJoy7 = 1, with no mod hook in sight")
  eq(list.repeatDelay, 30, "at the cart's half-second delay")
  eq(list.repeatRate, 5, "and the cart's repeat rate")

  input:press("down")
  list:update(1 / 60)
  eq(list.index, 2, "the press moves the cursor one row")
  for _ = 1, 29 do list:update(1 / 60) end
  eq(list.index, 2, "a short hold moves nothing more")
  list:update(1 / 60)
  eq(list.index, 3, "the 30th held frame is the first repeat")
  for _ = 1, 5 do list:update(1 / 60) end
  eq(list.index, 4, "and every fifth frame after that")
  for _ = 1, 60 do list:update(1 / 60) end
  eq(list.index, 10, "holding Down walks to the end of the list")
  eq(list.scroll, 7, "with the window scrolled to the bottom")

  input:release("down")
  input:press("up")
  list:update(1 / 60)
  for _ = 1, 200 do list:update(1 / 60) end
  eq(list.index, 1, "holding Up walks back to the top")
  eq(list.scroll, 0, "and the window comes with it")
end

-- home/list_menu.asm:47, 61-64, 338-342, 176-190; home/window.asm:14-18
do
  local items = {}
  for i = 1, 10 do items[i] = { value = i, label = "ITEM " .. i } end
  local input = newInput()
  local game = { input = input,
                 stack = { push = function() end, pop = function() end,
                           top = function() end } }
  local list = ListMenu.new(game, "ITEMS", items, { kind = "bag", itemBox = true })
  eq(list.cursorBlank, 0, "the arrow is up before anything moves")

  local function step(dir)
    input:press(dir)
    list:update(1 / 60)
    input:release(dir)
  end

  step("down")
  eq(list.index, 2, "the press moves one row")
  eq(list.scroll, 0, "inside the rows already printed")
  eq(list.cursorBlank, 0, "so nothing reprints and the arrow stays up")
  step("down")
  eq(list.scroll, 0, "the third row is the last wMaxMenuItem reaches")
  eq(list.cursorBlank, 0, "and the arrow is still up")

  step("down")
  eq(list.index, 4, "the fourth row is past it")
  eq(list.scroll, 1, "so wListScrollOffset moves and the entries reprint")
  eq(list.cursorBlank, 3, "which wipes the arrow")
  list:update(1 / 60)
  eq(list.cursorBlank, 2, "it counts down one frame at a time")
  list:update(1 / 60)
  eq(list.cursorBlank, 1, "over the Delay3 window")
  list:update(1 / 60)
  eq(list.cursorBlank, 0, "and the arrow comes back")
  list:update(1 / 60)
  eq(list.cursorBlank, 0, "and stays back while the cursor sits still")

  step("down")
  eq(list.cursorBlank, 3, "the next scrolling step blanks it again")
  step("up")
  eq(list.cursorBlank, 2,
     "moving back inside the window reprints nothing, so it just counts down")

  local plain = ListMenu.new(game, "ITEMS", items, { kind = "generic" })
  input:press("down")
  for _ = 1, 200 do plain:update(1 / 60) end
  input:release("down")
  check(plain.scroll > 0, "the generic list scrolled to the bottom")
  eq(plain.cursorBlank, 0, "without ever blanking its cursor")
end

do
  local data = { pokemon = {}, constants = { dexSize = 151, dexDigits = 3 } }
  for n = 1, 151 do
    local id = ("DEXMON_%03d"):format(n)
    data.pokemon[id] = { id = id, name = ("MON%03d"):format(n), dex = n }
  end
  local save = { pokedex = { seen = {}, owned = {} } }
  for n = 1, 20 do save.pokedex.seen[("DEXMON_%03d"):format(n)] = true end
  local input = newInput()
  local game = { data = data, save = save, input = input,
                 stack = { push = function() end, pop = function() end,
                           top = function() end } }
  local PokedexMenu = require("src.ui.PokedexMenu")
  local dex = PokedexMenu.new(game, {})
  eq(#dex.items, 20, "twenty seen species in the list")

  input:press("down")
  dex:update(1 / 60)
  eq(dex.index, 2, "ShowPokedexMenu's own list moves on the press")
  for _ = 1, 29 do dex:update(1 / 60) end
  eq(dex.index, 2, "and waits out the same half second")
  dex:update(1 / 60)
  eq(dex.index, 3, "before the first repeat")
  for _ = 1, 200 do dex:update(1 / 60) end
  eq(dex.index, 20, "a long hold reaches the last seen species")
  -- arrow is never wiped (engine/menus/pokedex.asm:18, 217-221)
  eq(dex.cursorBlank, nil, "and the dex cursor is never blanked")

  input:release("down")
  input:press("right")
  dex:update(1 / 60)
  eq(dex.scroll, 13, "Right pages the scroll offset and clamps at the end")
  for _ = 1, 60 do dex:update(1 / 60) end
  eq(dex.scroll, 13, "holding Right at the bottom cannot page past it")
  input:release("right")

  input:press("left")
  dex:update(1 / 60)
  eq(dex.scroll, 6, "Left pages back seven rows")
  for _ = 1, 40 do dex:update(1 / 60) end
  eq(dex.scroll, 0, "and a held Left runs the list back to the top")
  input:release("left")
end

do
  local PackMenu = require("src.ui.gen2.PackMenu")
  local Save = require("src.core.gen2.Save")
  local items = {}
  local order = {}
  for i = 1, 8 do
    local id = "FAKEITEM_" .. i
    items[id] = { id = id, name = "ITEM " .. i, pocket = "ITEM", index = i,
                  canToss = true, canSelect = false,
                  fieldMenu = "ITEMMENU_CLOSE" }
    order[i] = id
  end
  local save = Save.newGame()
  save.inventory = {}
  for _, id in ipairs(order) do save.inventory[id] = 1 end
  save.bagOrder = order
  local input = newInput()
  local game = { input = input, save = save, options = save.options,
                 data = { items = items, moves = {}, pokemon = {},
                          audio = { sfx = {} } },
                 stack = { push = function() end, pop = function() end } }
  local pack = PackMenu.new(game, { save = save, pocket = "ITEM",
    onClose = function() end, world = { useFieldItem = function() end } })
  pack.gfx = { available = function() return false end, draw = function() end,
               colorsAt = function() return nil end }
  eq(pack.hold.delay, 15, "the pocket list runs at JoyTextDelay's cadence")
  eq(pack.hold.rate, 5, "with the cart's five-frame repeat")

  local total = pack:total()
  check(total >= 9, "eight items plus the CANCEL row")
  input:press("down")
  pack:update(1 / 60)
  eq(pack.index, 2, "the press moves one row")
  for _ = 1, 14 do pack:update(1 / 60) end
  eq(pack.index, 2, "fifteen frames of delay first")
  pack:update(1 / 60)
  eq(pack.index, 3, "then the first repeat")
  for _ = 1, 200 do pack:update(1 / 60) end
  eq(pack.index, total,
     "a held Down stops on the last row rather than wrapping round")
  input:release("down")
end

do
  local Gen2Dex = require("src.ui.gen2.PokedexMenu")
  local entries, seen = {}, {}
  for n = 1, 30 do
    local id = ("G2MON_%03d"):format(n)
    entries[id] = { dex = n, species = id, name = ("MON%03d"):format(n) }
    seen[id] = true
  end
  local input = newInput()
  local save = { pokedex = { seen = seen, caught = {} } }
  local game = { data = {}, save = save, input = input }
  local dex = Gen2Dex.new(game, { save = save,
    pokedex = { entries = entries },
    pokemon = {} })
  eq(dex.hold.delay, 15, "the listing runs at JoyTextDelay's cadence")
  check(#dex.rows >= 30, "thirty seen species in the listing")

  input:press("down")
  dex:update(1 / 60)
  eq(dex.index, 2, "the press moves one row")
  for _ = 1, 14 do dex:update(1 / 60) end
  eq(dex.index, 2, "after the same fifteen-frame delay")
  dex:update(1 / 60)
  eq(dex.index, 3, "the hold starts repeating")
  for _ = 1, 400 do dex:update(1 / 60) end
  eq(dex.index, #dex.rows,
     "Pokedex_ListingMoveCursorDown stops at the end of the listing")
  input:release("down")
end

T.finish("menu hold-to-scroll bug 1898")
