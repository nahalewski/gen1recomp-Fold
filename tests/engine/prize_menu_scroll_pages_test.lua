-- PrizeMenu.TEXTS' Game Corner vendor messages used \f (paragraph/clear)
-- where the real cart text ends in \v (cont/scroll), for four separate
-- messages (Celadon and Goldenrod's prize-vendor intros, Goldenrod's
-- quit line, and the coin vendor's no-COIN-CASE refusal) -- confirmed
-- against poke-corpus's GoldSilver English text (gs.CeladonGameCornerPrizeRoom.
-- CeladonPrizeRoom_PrizeVendorIntroText and siblings, which all end
-- <LINE>...<CONT>..., not <PARA>). CommonText.pages() renders \f as an
-- unrelated fresh page (no continuity) and \v as a scroll (the previous
-- line stays visible on top); with \f, the vendor's last line used to
-- appear alone with no lead-in.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local CommonText = require("src.core.gen2.CommonText")

local function lastPageScrolls(text, expectedTop, expectedBottom)
  local pages = CommonText.pages(text)
  local last = pages[#pages]
  T.eq(last[1], expectedTop, "the scrolled-up line is the previous page's bottom row")
  T.eq(last[2], expectedBottom, "the new line lands under it")
end

lastPageScrolls("Welcome!\fWe exchange your\ncoins for fabulous\vprizes!",
  "coins for fabulous", "prizes!")
lastPageScrolls("Welcome!\fWe exchange your\ngame coins for\vfabulous prizes!",
  "game coins for", "fabulous prizes!")
lastPageScrolls("OK. Please save\nyour coins and\vcome again!",
  "your coins and", "come again!")
lastPageScrolls("Do you need game\ncoins?\fOh, you don't have\na COIN CASE for\vyour coins.",
  "a COIN CASE for", "your coins.")

T.finish("prize_menu_scroll_pages_test")
