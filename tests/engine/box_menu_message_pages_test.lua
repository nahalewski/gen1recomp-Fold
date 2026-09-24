-- BoxMenu.lua's messagePages() used to split only on \n/\f, grouping every
-- two \n-separated lines into a page regardless of \f; switching it to
-- CommonText.pages() (shared with PackMenu/PrizeMenu) fixed the missing \v
-- handling but exposed that CommonText.pages() treats a bare \n only as the
-- box's second row, not a page break -- a THIRD line needs \f (or \v), not a
-- second bare \n, or it gets glued onto the second line with no separator.
-- This pins the one BOX_FAILURE_SOURCES literal that used to rely on the old
-- "every two \n lines is a page" behavior.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local CommonText = require("src.core.gen2.CommonText")

local pages = CommonText.pages("You'll need a\nPOKéMON to call\fwith.")
T.eq(#pages, 2, "the message splits into two pages")
T.eq(pages[1][1], "You'll need a", "page 1 top row")
T.eq(pages[1][2], "POKéMON to call", "page 1 bottom row")
T.eq(pages[2][1], "with.", "page 2 top row, not glued onto page 1's bottom row")
T.eq(pages[2][2], nil, "page 2 has no second row")

T.finish("box_menu_message_pages_test")
