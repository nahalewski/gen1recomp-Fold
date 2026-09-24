-- Gen 2's answer to tests/engine/palette_test.lua: the same COLORS picker,
-- wired onto Gold's COLOR row and its own substitution seam
-- (src/render/GbcPalette.lua) instead of Gen 1's PaletteFX.
--   luajit tests/engine/gen2_palette_picker_test.lua
--
-- Covers GbcPalette.customRamp/setCustomRamp (the seam every Gen 2 draw call
-- shares), that a stored palette beats CLASSIC's present pass the same way
-- it beats OG/OG INV/CLASSIC on Gen 1, and that the COLOR row opens the
-- picker while GBC/DMG/CLASSIC stay reachable inside it.

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local function hex(c)
  return type(c) == "table" and ("%02x%02x%02x"):format(c[1], c[2], c[3]) or "?"
end

local Palette = require("src.render.Palette")
local GbcPalette = require("src.render.GbcPalette")

-- ------- GbcPalette seam: a custom ramp wins outright

do
  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("gbc")

  local cartColors = { { 9, 9, 9 }, { 8, 8, 8 }, { 7, 7, 7 }, { 6, 6, 6 } }
  eq(GbcPalette.resolve(cartColors), cartColors,
     "no custom ramp: GBC mode passes the cart's own colours through")

  local id = Palette.packId("GalleryWebApp Palettes", "Original GB")
  local ramp = Palette.ramp(id)
  GbcPalette.setCustomRamp(ramp)

  local out = GbcPalette.resolve(cartColors)
  for i = 1, 4 do
    eq(hex(out[i]), hex(ramp[i]),
       "resolve[" .. i .. "] is the custom ramp, not the cart's own colours")
  end

  -- it should win even over DMG, since DMG's whole effect lives at this seam
  GbcPalette.setMode("dmg")
  local out2 = GbcPalette.resolve(cartColors)
  eq(hex(out2[1]), hex(ramp[1]), "a custom ramp beats DMG too")

  GbcPalette.setMode("gbc")
  GbcPalette.setCustomRamp(nil)
  eq(GbcPalette.resolve(cartColors), cartColors,
     "clearing the ramp restores the cart's own colours")
end

-- ------- CLASSIC is a present pass, same as Gen 1: it has to be dropped

do
  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("classic")
  check(GbcPalette.presentColors() ~= nil,
        "CLASSIC has a present pass before any palette is picked")

  local id = Palette.packId("BGB", "Red")
  local ramp = Palette.ramp(id)
  GbcPalette.setCustomRamp(ramp)
  -- resolve() alone can't save CLASSIC: presentColors bypasses resolve
  -- entirely, so the picker's opts have to drop the mode itself. Covered
  -- below via the real row wiring.
  GbcPalette.setMode("gbc")
  GbcPalette.setCustomRamp(nil)
end

-- ------- applyOptions: a saved palette re-applies on load, like Gen 1's

do
  GbcPalette.setCustomRamp(nil)
  local id = Palette.packId("BGB", "Blue")
  GbcPalette.applyOptions({ color = "dmg", palette = id })
  eq(GbcPalette.mode, "dmg", "applyOptions still sets the mode")
  check(GbcPalette.customRamp ~= nil, "applyOptions applied the saved palette")
  eq(hex(GbcPalette.customRamp[1]), hex(Palette.ramp(id)[1]),
     "and it's the right ramp")

  GbcPalette.applyOptions({ color = "gbc", palette = "" })
  check(GbcPalette.customRamp == nil,
        "applyOptions with no palette clears the custom ramp")
end

-- ------- the COLOR row's real wiring: activate opens the picker

local OptionsMenu = require("src.ui.gen2.OptionsMenu")

local function rowNamed(rows, label)
  for _, row in ipairs(rows) do
    if row.label == label then return row end
  end
  return nil
end

do
  local colorRow = rowNamed(OptionsMenu.ROWS, "COLOR")
  check(colorRow ~= nil, "COLOR is still a row")
  check(colorRow.cycle == nil, "COLOR no longer cycles in place")
  check(type(colorRow.activate) == "function",
        "COLOR opens the picker instead")

  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("classic")

  local pushed
  local game = {
    options = { color = "classic", palette = "" },
    stack = { states = {},
              push = function(self, inst) pushed = inst end },
    persistOptions = function() end,
  }

  colorRow.activate(game)
  check(pushed ~= nil, "activate pushed a screen")
  check(pushed.view == "root", "the pushed screen is a real PaletteScreen")
  eq(game.options.color, "gbc",
     "opening the picker while CLASSIC was active dropped it to GBC")
  eq(GbcPalette.mode, "gbc", "and the live mode followed")

  -- the root offers the engine's own GBC/DMG/CLASSIC ladder alongside the
  -- 699-pack folders and MONOCHROME: "the original options" still work
  local sawModes = {}
  for _, row in ipairs(pushed.rows) do
    if row.mode then sawModes[row.mode] = true end
  end
  check(sawModes.gbc and sawModes.dmg and sawModes.classic,
        "GBC, DMG and CLASSIC are all still reachable from the picker")

  local id = Palette.packId("BGB", "Blue")
  pushed.set(id)
  eq(game.options.palette, id, "storing a palette writes options.palette")
  check(GbcPalette.customRamp ~= nil, "and GbcPalette.setCustomRamp actually ran")
  eq(hex(GbcPalette.customRamp[1]), hex(Palette.ramp(id)[1]), "with the right ramp")

  pushed.set("")
  check(GbcPalette.customRamp == nil, "storing empty clears the custom ramp")
  eq(game.options.color, "gbc",
     "clearing a palette lands back on GEN 2, not whatever mode was active")
  eq(GbcPalette.mode, "gbc", "and the live mode followed")

  -- picking an engine mode through the picker still works and clears the
  -- stored palette, exactly like Gen 1's picker
  pushed.set(id)
  pushed.setMode("dmg")
  eq(game.options.color, "dmg", "setMode still writes options.color")
  eq(GbcPalette.mode, "dmg", "and drives the live module")

  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("gbc")
end

-- ------- GBC/GEN 2 relabel: GbcPalette.MODES keeps its id "gbc", but the
-- label the player sees for it moved to "GEN 2", freeing "GBC" up as
-- CUSTOM_MODE's own label, the state a stored palette actually lands on.

do
  eq(GbcPalette.MODE_LABELS.gbc, "GEN 2",
     "GEN 2 is the engine's own unique-colour mode's display name now")
  eq(GbcPalette.MODE_LABELS[GbcPalette.CUSTOM_MODE], "GBC",
     "GBC is the label for a stored custom palette's state")
  check(not (function()
    for _, id in ipairs(GbcPalette.MODES) do
      if id == GbcPalette.CUSTOM_MODE then return true end
    end
    return false
  end)(), "CUSTOM_MODE is deliberately not one of the root ladder's own modes")
end

-- ------- the bug this session's relabel fixes: picking a palette from a
-- non-GEN-2 mode used to strand the player there once the palette cleared,
-- because only CLASSIC ever got dropped back. Now ANY mode lands on
-- CUSTOM_MODE the moment a palette is picked, so clearing it always finds
-- its way back to GEN 2's own unique colours.

do
  local OptionsMenu = require("src.ui.gen2.OptionsMenu")
  local colorRow = nil
  for _, r in ipairs(OptionsMenu.ROWS) do
    if r.key == "color" then colorRow = r end
  end
  check(colorRow ~= nil, "found the COLOR row")

  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("dmg")

  local pushed
  local game = {
    options = { color = "dmg", palette = "" },
    stack = { states = {}, push = function(self, inst) pushed = inst end },
    persistOptions = function() end,
  }
  colorRow.activate(game)

  -- opening the picker from DMG (not CLASSIC) doesn't touch the mode yet:
  -- dropClassic only fires for CLASSIC, exactly as before.
  eq(game.options.color, "dmg", "opening the picker from DMG leaves it alone")

  local id = Palette.packId("BGB", "Blue")
  pushed.set(id)
  eq(game.options.color, GbcPalette.CUSTOM_MODE,
     "picking a palette from DMG now lands on CUSTOM_MODE, not DMG")
  eq(GbcPalette.mode, GbcPalette.CUSTOM_MODE, "and the live mode followed")

  pushed.set("")
  eq(game.options.color, "gbc",
     "clearing it lands on GEN 2 (the bug: this used to stay on DMG, " ..
     "with no selectable row left to get back to GEN 2's unique colours)")
  eq(GbcPalette.mode, "gbc", "and the live mode followed")

  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("gbc")
end

-- ------- TitleState's two baked art sets: GEN 2 and a picked custom
-- palette both want the colour set (there's no live recolour of this
-- screen's art either way); only DMG/CLASSIC want the grey set.

do
  local TitleState = require("src.ui.gen2.TitleState")
  GbcPalette.setMode("gbc")
  check(not TitleState.gray(), "GEN 2 shows the colour art")
  GbcPalette.setMode(GbcPalette.CUSTOM_MODE)
  check(not TitleState.gray(), "a picked custom palette also shows the colour art")
  GbcPalette.setMode("dmg")
  check(TitleState.gray(), "DMG shows the grey art")
  GbcPalette.setMode("classic")
  check(TitleState.gray(), "CLASSIC shows the grey art (then the green present pass)")
  GbcPalette.setMode("gbc")
end

-- ------- the "2" hotkey ladder (Game2:hotkey) and GbcPalette.cycle(): the
-- bug this session fixes. Unlike the picker's own row.mode branch (tested
-- above), this ladder used to change GbcPalette.mode/options.color without
-- touching customRamp or options.palette, so resolve() stayed locked onto
-- the old pack's colours no matter how many times "2" landed back on "gbc".

do
  local Game2 = require("src.core.Game2")
  local cartColors = { { 9, 9, 9 }, { 8, 8, 8 }, { 7, 7, 7 }, { 6, 6, 6 } }

  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("gbc")

  local id = Palette.packId("BGB", "Blue")
  local ramp = Palette.ramp(id)
  local game = {
    options = { color = GbcPalette.CUSTOM_MODE, palette = id },
    persistOptions = function() end,
  }
  GbcPalette.setMode(GbcPalette.CUSTOM_MODE)
  GbcPalette.setCustomRamp(ramp)

  -- cycle() isn't in GbcPalette.MODES so a custom-mode start is treated as
  -- index 1: three "2" presses walk dmg -> classic -> gbc.
  for _ = 1, 3 do Game2.hotkey(game, "2") end

  eq(game.options.color, "gbc", "three presses land back on GEN 2's label")
  eq(game.options.palette, "",
     "BUG FIX: the hotkey ladder clears options.palette too, not just color")
  check(GbcPalette.customRamp == nil,
        "BUG FIX: GbcPalette.cycle() drops the live custom ramp")
  eq(GbcPalette.resolve(cartColors), cartColors,
     "BUG FIX: resolve() answers with the cart's own colours again, not " ..
     "the stale custom ramp")

  GbcPalette.setCustomRamp(nil)
  GbcPalette.setMode("gbc")
end

T.finish("gen2 palette picker")
