-- Title eye OBP remap lives in ImageWriter.applyTitleObp0; pixel-level
-- coverage is tests/title_pikachu_obp_test.py (love_stub ImageData is a
-- no-op).  This file only pins the export so the Lua bake path stays wired.
--
--   luajit tests/engine/title_pikachu_obp_bug.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("title pikachu OBP export")
local check = S.check

local ImageWriter = require("src.import.ImageWriter")
check(type(ImageWriter.applyTitleObp0) == "function",
      "ImageWriter.applyTitleObp0 is exported for RomExtractor")
check(type(ImageWriter.SHADES) == "table" and #ImageWriter.SHADES == 4,
      "ImageWriter.SHADES exposes the 4 DMG ramps")

S.finish()
