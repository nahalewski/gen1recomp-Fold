-- #1639: Yellow-only Advanced overlay — BEACH_HOUSE world bake, sprite
-- coverage past Red's 72 entries, saturated YELLOWMON — without changing
-- Red/Blue Advanced.
--
--   luajit tests/engine/yellow_advanced_palette_bug1639.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("yellow advanced palette #1639")
local check, eq = S.check, S.eq

local GameVersion = require("src.core.GameVersion")
local PaletteFX = require("src.render.PaletteFX")

local prevVer = GameVersion.get()
local prevMode = PaletteFX.mode

PaletteFX.setMode("redpp")

-- Red: no BEACH_HOUSE, shared HOUSE still present
GameVersion.set("red")
check(not PaletteFX.hasWorldTileset("BEACH_HOUSE"),
      "Red Advanced has no BEACH_HOUSE tileset")
check(PaletteFX.hasWorldTileset("HOUSE"), "Red Advanced still has HOUSE")
local redHouse = PaletteFX.worldGroupColors(nil, "HOUSE", "PALLET_TOWN", 0)

-- Blue unchanged for BEACH_HOUSE
GameVersion.set("blue")
check(not PaletteFX.hasWorldTileset("BEACH_HOUSE"),
      "Blue Advanced has no BEACH_HOUSE tileset")

-- Yellow: BEACH_HOUSE present, HOUSE still inherits from Red pack
GameVersion.set("yellow")
check(PaletteFX.hasWorldTileset("BEACH_HOUSE"),
      "Yellow Advanced profiles BEACH_HOUSE")
check(PaletteFX.hasWorldTileset("HOUSE"),
      "Yellow Advanced still sees shared HOUSE")
local beach = PaletteFX.worldGroupColors(nil, "BEACH_HOUSE", "SUMMER_BEACH_HOUSE", 0)
check(beach ~= nil and #beach == 8, "BEACH_HOUSE has 8 group colors")
eq(beach[1][1][1], 255, "BEACH_HOUSE sand group is warm (R=255)")

-- Sprite: Pikachu @60 and high indices resolve; Red path for bike stays 0
local pika = PaletteFX.spriteObp({ source = "ROM:SpriteSheetPointerTable[60]" }, "pika")
check(pika ~= nil, "Yellow SPRITE_PIKACHU gets an OBP")
eq(pika[2][2], 255, "Pikachu OBP mid shade is saturated yellow G=255")
local boulder = PaletteFX.spriteObp({ source = "ROM:SpriteSheetPointerTable[72]" }, "b")
check(boulder ~= nil, "Yellow boulder (index 72) gets an OBP")

GameVersion.set("red")
local redBall = PaletteFX.spriteObp({ source = "ROM:SpriteSheetPointerTable[60]" }, "ball")
check(redBall ~= nil, "Red poke-ball @60 still resolves")
-- Red group 0 mid is orange skin, not pure yellow
check(redBall[2][2] < 200, "Red @60 is not Yellow's Pikachu ramp")

-- YELLOWMON / MEWMON / LOGO: Advanced uses CGBBase (saturated), not washed
-- SuperPalettes
GameVersion.set("yellow")
local yellowMon = PaletteFX.pal(nil, "YELLOWMON")
eq(yellowMon[2][2], 255, "Advanced Yellow YELLOWMON mid is saturated yellow G")
eq(yellowMon[2][3], 0, "Advanced Yellow YELLOWMON mid is pure yellow B=0")
local mewmon = PaletteFX.pal(nil, "MEWMON")
eq(mewmon[2][1], 255, "MEWMON stays Yellow title yellow (not Red++ purple)")
eq(mewmon[2][2], 255, "MEWMON body is saturated yellow G=255 (not washed 156)")
eq(mewmon[2][3], 0, "MEWMON body is pure yellow B=0")
check(mewmon[3][3] < 150, "MEWMON cheek stays red, not purple")
local logo2 = PaletteFX.pal(nil, "LOGO2")
eq(logo2[2][2], 255, "LOGO2 fill is saturated yellow under Advanced")
eq(logo2[2][3], 0, "LOGO2 fill is pure yellow B=0")

-- Red HOUSE colors identical before/after Yellow merge path
GameVersion.set("red")
local redHouse2 = PaletteFX.worldGroupColors(nil, "HOUSE", "PALLET_TOWN", 0)
eq(redHouse2[1][1][1], redHouse[1][1][1], "Red HOUSE colors unchanged")

PaletteFX.setMode(prevMode)
GameVersion.set(prevVer)

S.finish()
