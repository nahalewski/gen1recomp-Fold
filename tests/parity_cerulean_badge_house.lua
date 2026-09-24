-- Parity: leaving the Cerulean Badge House badge-description menu must
-- return control to the overworld after viewing a badge (#454).
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("parity Cerulean Badge House")
local eq, check = S.eq, S.check
local script = require("data.scripts.flavor.cerulean_badge_house")
  .CERULEAN_BADGE_HOUSE.talk.TEXT_CERULEANBADGEHOUSE_MIDDLE_AGED_MAN

local states = {}
local game = {
  data = {
    items = {
      BOULDERBADGE = { name = "BOULDERBADGE" },
      CASCADEBADGE = { name = "CASCADEBADGE" },
      THUNDERBADGE = { name = "THUNDERBADGE" },
      RAINBOWBADGE = { name = "RAINBOWBADGE" },
      SOULBADGE = { name = "SOULBADGE" },
      MARSHBADGE = { name = "MARSHBADGE" },
      VOLCANOBADGE = { name = "VOLCANOBADGE" },
      EARTHBADGE = { name = "EARTHBADGE" },
    },
    text = {
      _CeruleanBadgeHouseMiddleAgedManText = "",
      _CeruleanBadgeHouseMiddleAgedManWhichBadgeText = "",
      _CeruleanBadgeHouseBoulderBadgeText = "",
      _CeruleanBadgeHouseCascadeBadgeText = "",
      _CeruleanBadgeHouseThunderBadgeText = "",
      _CeruleanBadgeHouseRainbowBadgeText = "",
      _CeruleanBadgeHouseSoulBadgeText = "",
      _CeruleanBadgeHouseMarshBadgeText = "",
      _CeruleanBadgeHouseVolcanoBadgeText = "",
      _CeruleanBadgeHouseEarthBadgeText = "",
      _CeruleanBadgeHouseMiddleAgedManVisitAnyTimeText = "",
    },
  },
  save = { player = { name = "RED" } },
  input = { wasPressed = function(_, key) return key == "b" end },
  stack = {
    push = function(_, state) states[#states + 1] = state end,
    pop = function() return table.remove(states) end,
    top = function() return states[#states] end,
  },
}

local done = false
script(game, nil, nil, function() done = true end)

local function dismissText()
  local text = game.stack:pop()
  if text.onDone then text.onDone() end
end

-- (text/CeruleanBadgeHouse.asm:19, home/list_menu.asm:29-31)
local function showList()
  local box = game.stack:top()
  check(box.stay ~= nil, "the WhichBadge box stays up under the list")
  box.stay.onShown()
end

dismissText()
showList()

local firstMenu = game.stack:top()
-- (home/list_menu.asm:29-31, 46-52; data/text_boxes.asm:13)
check(firstMenu.itemBox == true, "the badge list uses LIST_MENU_BOX")
eq(firstMenu.rows, 4, "four badge rows are printed")
eq(firstMenu.cursorRows, 3, "wMaxMenuItem is 2, so the cursor reaches 3 rows")
check(firstMenu.isOpaque == false, "the map stays visible around the box")
eq(#states, 2, "the WhichBadge box stays on the stack under the list")

-- home/list_menu.asm:160-171; scripts/CeruleanBadgeHouse.asm:16-18, 47
firstMenu.index, firstMenu.scroll = 5, 2
firstMenu.onChoose(firstMenu.items[5], firstMenu)
eq(#states, 3, "the badge description prints over the still-open list")
check(states[2] == firstMenu, "the list is not torn down for the description")
dismissText()
local reprompt = game.stack:top()
check(reprompt.stay ~= nil, ".loop reprints WhichBadgeText over the list")
reprompt.stay.onShown()
check(game.stack:top() == firstMenu, "the same list menu is armed again")
eq(firstMenu.index, 5, "wCurrentMenuItem survives .loop")
eq(firstMenu.scroll, 2, "wListScrollOffset survives .loop")

-- B follows ListMenu's real cancellation path: pop menu, then show goodbye.
game.stack:top():update(0)
dismissText()

eq(#states, 0, "backing out after viewing a badge leaves no menu behind")
eq(done, true, "backing out after viewing a badge completes the NPC script")

-- PrintListMenuEntries writes ListMenuCancelText where the item list's $FF
-- terminator lands (home/list_menu.asm), so a DisplayListMenuID list always
-- offers CANCEL on screen; choosing it is `cp c / jp c, ExitListMenu`, which
-- sets carry, so the badge script's `jr c, .done` treats it exactly like B
-- (pokered scripts/CeruleanBadgeHouse.asm).  The row was missing (#569).
local cancelled = false
script(game, nil, nil, function() cancelled = true end)
dismissText()
showList()

local menu = game.stack:top()
eq(#menu.items, 9, "eight badges plus the CANCEL row")
eq(menu.items[#menu.items].label, "CANCEL", "CANCEL is the last row")
check(menu.items[#menu.items].value == nil,
      "the CANCEL row carries no badge, so it cannot print a description")
-- (home/list_menu.asm:372, 518-524)
check(menu.items[#menu.items].cancel == true,
      "the CANCEL row is marked, so the more-arrow stops on it")
for i = 1, 8 do
  check(menu.items[i].value ~= nil, "badge row " .. i .. " still picks a badge")
end

menu.onChoose(menu.items[#menu.items], menu)
eq(#states, 1, "choosing CANCEL closes the list and its prompt box")
dismissText()
eq(#states, 0, "choosing CANCEL leaves no menu behind")
eq(cancelled, true, "choosing CANCEL takes the same .done exit as B")

S.finish()
