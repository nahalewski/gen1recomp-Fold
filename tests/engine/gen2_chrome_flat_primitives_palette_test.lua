-- Chrome.print / Chrome.cursor / Chrome.printRight are the flat,
-- hardcoded-black primitives ~40 Gen 2 screens still call directly, so any
-- glyph through them rendered solid black regardless of COLORS. Made the
-- primitives themselves palette-aware instead of migrating 40 files.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

love = require("tests.love_stub")

require("src.core.Logger").warn = function() end

local GbcPalette = require("src.render.GbcPalette")
local Chrome = require("src.ui.gen2.Chrome")

local calls
local function spy(name)
  local original = GbcPalette[name]
  GbcPalette[name] = function(...)
    calls[name] = (calls[name] or 0) + 1
    return original(...)
  end
end

local function reset()
  calls = {}
  spy("resolve"); spy("use"); spy("useRaw"); spy("with")
end

local function touched()
  return (calls.resolve or 0) + (calls.use or 0) + (calls.useRaw or 0) + (calls.with or 0)
end

do
  GbcPalette.available = function() return true end
  GbcPalette.setCustomRamp({ { 255, 0, 255 }, { 200, 0, 200 }, { 100, 0, 100 },
                              { 0, 0, 0 } })

  reset()
  Chrome.print("HELLO", 1, 1)
  T.check(touched() > 0, "Chrome.print() reaches the GbcPalette seam when a shader is available")

  reset()
  Chrome.cursor(1, 1)
  T.check(touched() > 0, "Chrome.cursor() reaches the GbcPalette seam when a shader is available")

  reset()
  Chrome.printRight("42", 10, 1)
  T.check(touched() > 0, "Chrome.printRight() reaches the GbcPalette seam when a shader is available")
end

-- Unthemed / no-shader boot must still degrade to the plain literal black
-- glyph draw, byte-identical to before this fix.
do
  GbcPalette.available = function() return false end

  reset()
  local ok = pcall(Chrome.print, "HELLO", 1, 1)
  T.check(ok, "Chrome.print() does not error with no shader available")
  T.eq(touched(), 0, "Chrome.print() does not touch GbcPalette when no shader is available")

  reset()
  ok = pcall(Chrome.cursor, 1, 1)
  T.check(ok, "Chrome.cursor() does not error with no shader available")
  T.eq(touched(), 0, "Chrome.cursor() does not touch GbcPalette when no shader is available")

  reset()
  ok = pcall(Chrome.printRight, "42", 10, 1)
  T.check(ok, "Chrome.printRight() does not error with no shader available")
  T.eq(touched(), 0, "Chrome.printRight() does not touch GbcPalette when no shader is available")
end

T.finish()
