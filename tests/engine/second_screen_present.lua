package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local name = "src.render.SecondScreen"
local oldModule = package.loaded[name]
local oldFfi = package.loaded.ffi
local oldPreload = package.preload.ffi
local calls = {}
local null = {}

local C = {
  love_android_secondary_ready = function() return 0 end,
  love_android_push_secondary = function(ptr, w, h)
    calls.push = { ptr, w, h }
  end,
  love_android_secondary_enable = function(on) calls.enabled = on end,
  love_android_secondary_target = function(target) calls.target = target end,
  love_android_secondary_detected = function() return 1 end,
  love_android_present_secondary = function(ptr, w, h, background, cover)
    calls.present = { ptr, w, h, background, cover }
    return 1
  end,
  love_android_poll_secondary_touch = function() return null end,
}
local fakeFfi = {
  C = C,
  NULL = null,
  cdef = function() end,
  load = function() return C end,
  string = function(value) return value end,
}

package.loaded[name] = nil
package.loaded.ffi = nil
package.preload.ffi = function() return fakeFfi end

local SecondScreen = require(name)
local image = { getFFIPointer = function() return "pixels" end }

T.eq(SecondScreen.available(), false,
  "an unbound presentation is not render-ready")
T.eq(SecondScreen.detected(), true,
  "physical display detection is independent of presentation readiness")
T.eq(SecondScreen.push(image, 160, 144, 0x112233, "secondary:cover"), true,
  "extended Android presentation accepts frame metadata")
T.same(calls.present, { "pixels", 160, 144, 0x112233, 1 },
  "cover and RGB background reach the native bridge")
T.eq(calls.target, 2, "secondary routing reaches the optional native bridge")
T.eq(SecondScreen.push(image, 160, 144, 0x112233, "handheld"), true,
  "handheld routing remains a contain presentation")
T.eq(calls.target, 1, "handheld routing reaches the optional native bridge")
T.eq(SecondScreen.push(image, 160, 144, 0x112233, "secondary"), true,
  "contain presentation remains available")
T.same(calls.present, { "pixels", 160, 144, 0x112233, 0 },
  "contain is the default native fit")
T.eq(SecondScreen.push(image, 160, 144, nil, "secondary:cover"), true,
  "a fit preference can request extended presentation by itself")
T.same(calls.present, { "pixels", 160, 144, 0, 1 },
  "preference-only presentation defaults to a black background")
T.eq(calls.target, 2, "a suffixed route keeps its target")
T.eq(SecondScreen.push(image, 160, 144), true,
  "the original push ABI remains available")
T.same(calls.push, { "pixels", 160, 144 },
  "legacy callers retain the original frame path")

package.loaded[name] = oldModule
package.loaded.ffi = oldFfi
package.preload.ffi = oldPreload

T.finish("Android secondary presentation facade")
