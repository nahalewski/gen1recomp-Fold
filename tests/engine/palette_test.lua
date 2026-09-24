-- Tests the COLORS picker's 699-palette pack (src/render/Palette.lua) and
-- its substitution seam in src/render/PaletteFX.lua. ROM-free, since the
-- pack is committed data rather than ROM-imported.
--   luajit tests/engine/palette_test.lua
--
-- Covers the ramp ordering flip in Palette.ramp() (the pack stores darkest
-- first, PaletteFX wants lightest first), the substitution seam itself (a
-- custom palette has to win outright and get a zone invented for it, same
-- as OG/OG INV/CLASSIC), and that BattleState/WideBattle's mono checks stay
-- in sync with that seam.

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local function hex(c)
  return type(c) == "table" and ("%02x%02x%02x"):format(c[1], c[2], c[3]) or "?"
end

local Palette = require("src.render.Palette")
local PaletteFX = require("src.render.PaletteFX")

-- ------- the pack

do
  eq(#Palette.packs(), 32, "32 groups")
  local total = 0
  for _, group in ipairs(Palette.packs()) do
    total = total + #(group.palettes or {})
  end
  eq(total, 699, "699 palettes")
end

-- ------- the folders

do
  local seen, total = {}, 0
  for _, category in ipairs(Palette.categories()) do
    for _, item in ipairs(category.palettes) do
      total = total + 1
      seen[item.id] = category.key
    end
  end
  eq(total, 699, "every palette is filed")

  local counted = 0
  for _ in pairs(seen) do counted = counted + 1 end
  eq(counted, 699, "no palette is filed twice")

  -- the DMG ramp is the case HUE_ARC was tuned around
  eq(seen[Palette.packId("GalleryWebApp Palettes", "Original GB")],
     "single", "the DMG green is one colour")
  eq(seen[Palette.packId("BGB", "Grey")], "grey", "BGB Grey is grey")
  eq(seen[Palette.packId("GB Color (Unique Palettes)", "GBC Palette 119 (World)")],
     "full", "a yellow and red cart palette is full colour")
  -- the GBC boot palette for Red is white/pink/dark red/black: a red ramp
  eq(seen[Palette.packId("GB Color (Unique Palettes)",
                          "GBC Palette 093 (USA, Europe)")],
     "single", "a tinted grey ramp is one colour")

  local first = Palette.categories()[1].palettes[1]
  check(type(first.id) == "string" and Palette.ramp(first.id) ~= nil,
        "a bucket entry carries a resolvable id")
  check(type(first.pack) == "string" and first.pack ~= "",
        "a bucket entry remembers its source pack")

  local key, at = Palette.locate("p:BGB/Blue")
  eq(key, "single", "locate answers the bucket")
  eq(Palette.categories()[2].palettes[at].id, "p:BGB/Blue",
     "and the tile")
  check(Palette.locate("p:Nope/Nothing") == nil, "an unknown id is nowhere")
end

-- ------- classifying a ramp

do
  local function cat(a, b, c, d) return Palette.categoryOf({ a, b, c, d }) end
  eq(cat({ 255, 255, 255 }, { 170, 170, 170 }, { 85, 85, 85 }, { 0, 0, 0 }),
     "grey", "four greys are greyscale")
  eq(cat({ 155, 188, 15 }, { 139, 172, 15 }, { 48, 98, 48 }, { 15, 56, 15 }),
     "single", "one hue at four strengths is a single colour")
  eq(cat({ 255, 255, 255 }, { 255, 132, 132 }, { 148, 58, 58 }, { 0, 0, 0 }),
     "single", "greys among one hue do not make it full colour")
  eq(cat({ 255, 0, 0 }, { 0, 255, 0 }, { 0, 0, 255 }, { 0, 0, 0 }),
     "full", "three hues is full colour")
  eq(cat({ 255, 40, 20 }, { 255, 10, 40 }, { 128, 5, 20 }, { 40, 2, 6 }),
     "single", "a ramp straddling 0 degrees is one colour")
  check(Palette.categoryOf(nil) == nil, "nothing classifies as nothing")
end

-- ------- hex decoding

do
  local c = Palette.unhex("0f380f30623077a1129bbc0f")
  check(c and hex(c[1]) == "0f380f", "first colour is the string's first")
  check(c and hex(c[4]) == "9bbc0f", "last colour is the string's last")
  check(Palette.unhex("abc") == nil, "short string rejected")
  check(Palette.unhex("zz380f30623077a1129bbc0f") == nil, "non-hex rejected")
  check(Palette.unhex(nil) == nil, "nil rejected")
end

-- ------- ordering
--
-- #9BBC0F is the PAPER and #0F380F is the INK, so ramp()[1] must be pale.

do
  local id = Palette.packId("GalleryWebApp Palettes", "Original GB")
  local ramp = Palette.ramp(id)
  check(ramp ~= nil, "Original GB resolves")
  eq(hex(ramp[1]), "9bbc0f", "ramp[1] is the lightest (paper)")
  eq(hex(ramp[4]), "0f380f", "ramp[4] is the darkest (ink)")

  local sw = Palette.swatch(id)
  eq(hex(sw[1]), "0f380f", "swatch[1] is the darkest")
  eq(hex(sw[4]), "9bbc0f", "swatch[4] is the lightest")
end

-- cross-check against PaletteFX.GBC_BG, the same palette hardcoded there
do
  local ramp = Palette.ramp(Palette.packId(
    "GB Color (Unique Palettes)", "GBC Palette 093 (USA, Europe)"))
  for i = 1, 4 do
    eq(hex(ramp[i]), hex(PaletteFX.GBC_BG[i]),
       "pack Red ramp[" .. i .. "] agrees with PaletteFX.GBC_BG")
  end
end

-- ------- monochrome

do
  local id = Palette.monoId(0x9b, 0xbc, 0x0f)
  eq(id, "m:9bbc0f", "id encodes as hex")
  local ramp = Palette.ramp(id)
  eq(hex(ramp[1]), "9bbc0f", "lightest is the chosen colour")
  check(ramp[4][1] < ramp[1][1], "darkest is darker than lightest")
  eq(Palette.label(id), "GREEN", "a known colour gets its name")
  eq(Palette.label("m:123456"), "MONO", "an unknown one falls back")
end

-- ------- ids

do
  check(Palette.label("") == nil, "empty id has no label")
  eq(Palette.label("p:BGB/Blue"), "Blue", "pack label is the name")
  check(Palette.ramp("") == nil, "empty id resolves to nothing")
  check(Palette.ramp("p:Nope/Nothing") == nil, "missing palette resolves to nothing")
  check(Palette.ramp("garbage") == nil, "malformed id resolves to nothing")
end

-- ------- every palette in the pack parses

do
  local bad, checked = {}, 0
  for _, group in ipairs(Palette.packs()) do
    for _, entry in ipairs(group.palettes or {}) do
      local ramp = Palette.ramp(Palette.packId(group.name, entry[1]))
      checked = checked + 1
      if not ramp then bad[#bad + 1] = group.name .. "/" .. tostring(entry[1]) end
    end
  end
  eq(checked, 699, "checked every palette")
  eq(#bad, 0, "all resolve (" .. table.concat(bad, ", ", 1, math.min(#bad, 3)) .. ")")
end

-- ------- the picker's state machine
--
-- update() touches no love API, so we can drive it with a stub game.

local PaletteScreen = require("src.ui.PaletteScreen")

do
  local pressed = {}

  local function open(stored)
    local state = { stored = stored or "", popped = 0, mode = "redpp" }
    state.screen = PaletteScreen.new({
      input = { wasPressed = function(_, k) return pressed[k] == true end },
      stack = { states = {},
                pop = function() state.popped = state.popped + 1 end },
    }, {
      palette = Palette,
      get = function() return state.stored end,
      set = function(v) state.stored = v end,
      modes = { { "SGB", "gbc" }, { "ADVANCED", "redpp" } },
      getMode = function() return state.mode end,
      setMode = function(v) state.mode = v end,
    })
    return state
  end

  local function press(state, key)
    pressed = { [key] = true }
    state.screen:update()
    pressed = {}
  end

  local fresh = open()
  eq(fresh.screen.view, "root", "a fresh profile opens at the root")
  eq(#fresh.screen.rows, 6, "four folders and two modes")
  eq(fresh.screen.rows[4].label, "MONOCHROME")
  check(fresh.screen.rows[4].folder, "MONOCHROME is the fourth folder")
  eq(fresh.screen.rows[5].mode, "gbc")
  check(not fresh.screen.rows[5].folder, "an engine mode is a row and not a folder")

  press(fresh, "a")
  eq(fresh.screen.view, "tiles", "A on a folder opens its grid one level down")
  eq(#fresh.screen.stackTrail, 1)
  press(fresh, "b")
  eq(fresh.screen.view, "root", "B steps back up to the root")
  eq(fresh.popped, 0)
  press(fresh, "b")
  eq(fresh.popped, 1, "B at the root closes the screen")

  -- a stored selection should open straight into its grid
  local stored = open("p:BGB/Blue")
  eq(stored.screen.view, "tiles", "a stored palette opens in its folder")
  eq(stored.screen.group.key, "single", "and in the RIGHT folder")
  eq(stored.screen:idAt(stored.screen.index), "p:BGB/Blue",
     "with the cursor on the stored tile")
  eq(#stored.screen.stackTrail, 1, "the skipped level is on the trail")
  press(stored, "b")
  eq(stored.screen.view, "root", "B steps up instead of closing")
  eq(stored.popped, 0)
  eq(stored.screen.index, 2, "and lands on the folder it came from")

  -- an engine mode and a palette share the same slot
  local modes = open("p:BGB/Blue")
  press(modes, "b")
  for _ = 1, 3 do press(modes, "down") end
  eq(modes.screen.rows[modes.screen.index].mode, "gbc", "walked to the SGB row")
  press(modes, "a")
  eq(modes.stored, "", "picking an engine mode clears the palette")
  eq(modes.mode, "gbc", "and sets the mode")

  local pick = open()
  press(pick, "a")
  press(pick, "right")
  local wanted = pick.screen:idAt(pick.screen.index)
  press(pick, "a")
  eq(pick.stored, wanted, "A on a tile stores that tile's id")
  check(wanted ~= nil)
end

-- ------- the picker's REAL wiring: PaletteScreen.new(game) with no opts
--
-- Everything above injects its own opts to keep update() engine-free, so
-- none of it would catch a bug in liveOpts/dropConflictingMode. This
-- builds the screen the way OptionsMenu actually does, with no opts at all.

do
  local game = {
    input = { wasPressed = function() return false end },
    stack = { states = {}, pop = function() end },
    save = { options = { colors = "redpp" } },
  }
  PaletteFX.mode = "redpp"
  local screen = PaletteScreen.new(game)
  check(screen.view == "root", "a live-opts screen opens at the root")
  check(type(screen.get) == "function" and type(screen.set) == "function",
        "liveOpts wired real get/set functions")
  eq(game.save.options.colors, "gbc",
     "opening the picker while ADVANCED was active dropped it to SGB "
     .. "(dropConflictingMode ran)")
  eq(PaletteFX.mode, "gbc", "and the live mode followed")

  local id = Palette.packId("BGB", "Blue")
  screen.set(id)
  eq(game.save.options.palette, id, "storing a palette writes save.options.palette")
  eq(hex(PaletteFX.customRamp[1]), hex(Palette.ramp(id)[1]),
     "and PaletteFX.setCustomRamp actually ran")

  screen.set("")
  check(PaletteFX.customRamp == nil, "storing empty clears the custom ramp")
  PaletteFX.mode = "gbc"
end

-- ------- PaletteFX seam: a custom ramp wins outright

do
  PaletteFX.setCustomRamp(nil)
  PaletteFX.mode = "gbc"
  check(not PaletteFX.forcesRawGrays(), "no custom ramp: forcesRawGrays is false")

  local id = Palette.packId("GalleryWebApp Palettes", "Original GB")
  local ramp = Palette.ramp(id)
  PaletteFX.setCustomRamp(ramp)
  check(PaletteFX.forcesRawGrays(), "a stored custom ramp: forcesRawGrays is true")

  local someZoneColors = { { 9, 9, 9 }, { 8, 8, 8 }, { 7, 7, 7 }, { 6, 6, 6 } }
  local out = PaletteFX.effectiveColors(someZoneColors)
  for i = 1, 4 do
    eq(hex(out[i]), hex(ramp[i]),
       "effectiveColors[" .. i .. "] is the custom ramp, not the zone's own colours")
  end

  -- it should win even over a mode with its own fixed palette
  PaletteFX.mode = "classic"
  local out2 = PaletteFX.effectiveColors(someZoneColors)
  eq(hex(out2[1]), hex(ramp[1]), "a custom ramp beats CLASSIC too")
  PaletteFX.mode = "gbc"
end

-- ------- picker immunity
--
-- The picker's swatches are real RGB, so effectiveColors and ensureZones
-- both have to back off while it's on top or it would recolour its own
-- swatches.

do
  local Game = require("src.core.Game")

  Game.stack = nil
  check(not PaletteFX.pickerActive(), "no stack: pickerActive is false")

  Game.stack = { states = { { screenId = "OptionsMenu" } } }
  check(not PaletteFX.pickerActive(), "some other screen on top: pickerActive is false")

  Game.stack = { states = { { screenId = "OptionsMenu" },
                             { screenId = "PaletteScreen" } } }
  check(PaletteFX.pickerActive(), "PaletteScreen on top of the stack: pickerActive is true")

  local id = Palette.packId("BGB", "Red")
  local ramp = Palette.ramp(id)
  PaletteFX.setCustomRamp(ramp)
  PaletteFX.mode = "gbc"

  local someZoneColors = { { 9, 9, 9 }, { 8, 8, 8 }, { 7, 7, 7 }, { 6, 6, 6 } }
  local out = PaletteFX.effectiveColors(someZoneColors)
  eq(hex(out[1]), hex(someZoneColors[1]),
     "with the picker on top, effectiveColors does NOT substitute the custom ramp")

  check(PaletteFX.ensureZones(nil) == nil,
        "with the picker on top, ensureZones invents nothing for the custom ramp")

  -- closing the picker should restore the substitution immediately
  Game.stack = { states = { { screenId = "OptionsMenu" } } }
  check(not PaletteFX.pickerActive(), "closing the picker: pickerActive is false again")
  local out2 = PaletteFX.effectiveColors(someZoneColors)
  eq(hex(out2[1]), hex(ramp[1]), "and the custom ramp substitutes again")
  local invented = PaletteFX.ensureZones(nil)
  check(invented and #invented == 1, "and ensureZones invents its zone again")

  Game.stack = nil
  PaletteFX.setCustomRamp(nil)
end

-- ------- PaletteFX seam: the invented zone, end to end
--
-- A state with no SGB zones of its own gets one invented by ensureZones,
-- and effectiveColors then has to turn that zone's colours into the
-- chosen ramp.

do
  PaletteFX.setCustomRamp(nil)
  check(PaletteFX.ensureZones(nil) == nil,
        "no custom ramp, no mono mode: ensureZones invents nothing")

  local id = Palette.packId("BGB", "Red")
  local ramp = Palette.ramp(id)
  PaletteFX.setCustomRamp(ramp)

  local invented = PaletteFX.ensureZones(nil)
  check(invented and #invented == 1, "a custom ramp invents one zone")
  eq(invented[1].w, 160, "the invented zone is whole-screen (w)")
  eq(invented[1].h, 144, "the invented zone is whole-screen (h)")
  for i = 1, 4 do
    eq(hex(invented[1].colors[i]), hex(PaletteFX.GRAYS[i]),
       "the invented zone is plain DMG grays, not the ramp itself")
  end

  -- run it back through effectiveColors, the way Renderer.sendColors would
  local final = PaletteFX.effectiveColors(invented[1].colors)
  for i = 1, 4 do
    eq(hex(final[i]), hex(ramp[i]),
       "the invented zone resolves to the custom ramp at send time")
  end

  local realZones = { { colors = { { 1, 1, 1 } }, x = 0, y = 0, w = 40, h = 40 } }
  check(PaletteFX.ensureZones(realZones) == realZones,
        "a state with real zones is left alone")

  PaletteFX.setCustomRamp(nil)
  check(not PaletteFX.forcesRawGrays(), "clearing the ramp clears forcesRawGrays")
end

-- ------- the four sync points
--
-- BattleState:picImage, BattleState:drawZonePass, WideBattle's monoMode and
-- PaletteFX.ensureZones all gate on the same "forced raw grays" condition.
-- This is a structural check (source-level, no ROM) that none of the four
-- got missed when forcesRawGrays was added.

do
  local function read(path)
    local f = assert(io.open(path, "r"))
    local src = f:read("*a")
    f:close()
    return src
  end

  local battleSrc = read("src/battle/BattleState.lua")
  local picImage = battleSrc:match("function BattleState:picImage%(img%)(.-)\nend")
  check(picImage and picImage:find("forcesRawGrays", 1, true) ~= nil,
        "picImage's mono check includes forcesRawGrays")

  local drawZonePass = battleSrc:match(
    "function BattleState:drawZonePass%(src, sx, sy%)(.-)\nend")
  check(drawZonePass and drawZonePass:find("forcesRawGrays", 1, true) ~= nil,
        "drawZonePass's mono check includes forcesRawGrays")

  local wideSrc = read("src/battle/WideBattle.lua")
  local monoMode = wideSrc:match("local function monoMode%(%)(.-)\nend")
  check(monoMode and monoMode:find("forcesRawGrays", 1, true) ~= nil,
        "WideBattle's monoMode includes forcesRawGrays")

  local fxSrc = read("src/render/PaletteFX.lua")
  local ensureZones = fxSrc:match("function PaletteFX.ensureZones%(zones%)(.-)\nend")
  check(ensureZones and ensureZones:find("forcesRawGrays", 1, true) ~= nil,
        "ensureZones itself includes forcesRawGrays")
end

-- ------- COLORS row wiring
--
-- OptionsMenu's colors row should open the picker instead of cycling in place.

do
  local optSrc = (function()
    local f = assert(io.open("src/ui/OptionsMenu.lua", "r"))
    local s = f:read("*a")
    f:close()
    return s
  end)()
  -- bounded to the row itself, or the scan would run into TILT's own step
  local block = optSrc:match('{ id = "colors",(.-)\n    { id =')
  check(block ~= nil, "colors row block found")
  check(block:find("activate = function%(g%)") ~= nil,
        "colors row has an activate")
  check(block:find('Screens"%).push%(g, "PaletteScreen"%)', 1, false) ~= nil
        or block:find('Screens").push(g, "PaletteScreen")', 1, true) ~= nil,
        "colors row's activate pushes PaletteScreen")
  check(block:find("step = function") == nil,
        "colors row no longer has a step")
end

T.finish("palette")
