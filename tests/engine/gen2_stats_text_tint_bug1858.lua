-- engine/gfx/color.asm:342-359 / engine/gfx/cgb_layouts.asm:167-192

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

local Chrome = require("src.ui.gen2.Chrome")
local SummaryMenu = require("src.ui.gen2.SummaryMenu")

local printed, through
local realPrint, realThrough = Chrome.print, Chrome.printThrough
Chrome.print = function(text, tx, ty)
  printed[#printed + 1] = { text = text, x = tx, y = ty }
  return 0
end
Chrome.printThrough = function(text, tx, ty, palette)
  through[#through + 1] = { text = text, x = tx, y = ty, palette = palette }
  return 0
end

local function fake(page, placements)
  local self = setmetatable({ page = page, mon = {}, party = {} },
    { __index = SummaryMenu })
  self.greenPlacements = function() return placements end
  self.bluePlacements = function() return placements end
  self.pinkPlacements = function() return placements end
  self.drawVerticalDivider = function() end
  return self
end

local rows = {
  { text = "ITEM", x = 0, y = 8 },
  { text = "MOVE", x = 0, y = 10 },
}

for _, page in ipairs({ SummaryMenu.PINK_PAGE, SummaryMenu.GREEN_PAGE,
                        SummaryMenu.BLUE_PAGE }) do
  local self = fake(page, rows)
  printed, through = {}, {}
  if page == SummaryMenu.GREEN_PAGE then
    self:drawGreenPage()
  elseif page == SummaryMenu.BLUE_PAGE then
    self:drawBluePage()
  else
    self:drawPlacements(self:pinkPlacements(), self:lowerColors())
  end
  T.eq(#printed, 0, "no lower-half string prints on the white default paper")
  T.eq(#through, #rows, "every lower-half string prints through a palette")
  local tint = SummaryMenu.PAGE_TINTS[page]
  for _, call in ipairs(through) do
    T.eq(call.palette and call.palette[1][1], tint[1], "paper red is the page tint")
    T.eq(call.palette and call.palette[1][2], tint[2], "paper green is the page tint")
    T.eq(call.palette and call.palette[1][3], tint[3], "paper blue is the page tint")
    T.eq(call.palette and call.palette[4][1], 0, "ink stays black")
  end
end

-- Rows 0-7 are filled with palette $1, whose colour 0 is white, so the upper
-- half keeps the default paper.
do
  local self = fake(SummaryMenu.PINK_PAGE, rows)
  printed, through = {}, {}
  self:drawPlacements(rows)
  T.eq(#printed, #rows, "upper-half strings still take the default paper")
  T.eq(#through, 0, "upper-half strings do not force a page tint")
end

Chrome.print, Chrome.printThrough = realPrint, realThrough

T.finish("gen2 stats text tint bug 1858")
