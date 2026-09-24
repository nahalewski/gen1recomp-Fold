
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

love = love or require("tests.love_stub")

local logged = {}
package.loaded["src.core.Logger"] = {
  info = function() end,
  warn = function() end,
  error = function(fmt, ...) logged[#logged + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end,
}

local written = {}
love.filesystem.write = function(name, content)
  written[name] = content
  return true
end
love.graphics.getRendererInfo = function() return "OpenGL", "4.1 stub", "stub", "stub" end
love.graphics.getSupported = function() return { glsl3 = true } end
love.graphics.flushBatch = function() end
love.timer = love.timer or {}
love.timer.getDelta = love.timer.getDelta or function() return 1 / 60 end

local validateResult, validateErr = true, nil
local validateCalls, newShaderCalls = 0, 0
local newShaderMode = "ok"
love.graphics.validateShader = function(es, frag, vert)
  validateCalls = validateCalls + 1
  check(type(frag) == "string" and type(vert) == "string", "validateShader gets both stages")
  eq(es, false, "the desktop stub validates the desktop dialect")
  return validateResult, validateErr
end
love.graphics.newShader = function(frag, vert)
  newShaderCalls = newShaderCalls + 1
  if newShaderMode == "throw" then error("driver said no: line 5 syntax error") end
  return { send = function() end, frag = frag, vert = vert }
end

local ShaderFX = require("src.render.ShaderFX")

local function entry(name)
  return { name = name .. ".slangp", fullPath = "tests/data/shaderfx/gl/" .. name .. ".slangp", converted = true }
end

do
  validateResult, validateErr = false, "Error validating pixel shader:\nERROR: 0:12: 'x' : boom"
  validateCalls, newShaderCalls, logged = 0, 0, {}
  local ok, err = ShaderFX.activate("main", entry("lcd3x"))
  eq(ok, false, "a preset whose GLSL fails validation does not activate")
  check(type(err) == "string" and err:find("pass0", 1, true) and err:find("boom", 1, true),
    "the activate error names the pass and carries glslang's text (got " .. tostring(err) .. ")")
  eq(ShaderFX.active("main"), false, "the slot stays empty")
  eq(ShaderFX.activeEntry("main"), nil, "and reports no entry")
  eq(validateCalls, #require("src.render.ShaderFixup").PREC_HEADS, "every PREC_HEADS variant was tried")
  eq(newShaderCalls, 0, "newShader is never reached when validation fails")
  check(ShaderFX.lastError() and ShaderFX.lastError():find("lcd3x.slangp", 1, true) ~= nil,
    "lastError() names the preset")
  local log = written[ShaderFX.ERROR_LOG_REL]
  check(type(log) == "string" and log:find("boom", 1, true) ~= nil,
    "shaderfx-error.log carries the compiler text")
  check(log and log:find("es=false", 1, true) and log:find("glsl3=true", 1, true)
    and log:find("4.1 stub", 1, true), "and the dialect, glsl3 state and renderer")
  eq(#logged, 1, "one Logger.error per failed activate, not per frame")
end

do
  validateResult, validateErr = true, nil
  newShaderMode = "throw"
  validateCalls, newShaderCalls, logged = 0, 0, {}
  local ok, err = ShaderFX.activate("main", entry("lcd3x"))
  eq(ok, false, "a driver compile failure inside newShader also fails activate")
  check(err and err:find("newShader", 1, true) and err:find("driver said no", 1, true),
    "and its message reaches the caller (got " .. tostring(err) .. ")")
  eq(ShaderFX.active("main"), false, "the slot stays empty after a newShader throw")
end

do
  newShaderMode = "ok"
  validateCalls, newShaderCalls, logged = 0, 0, {}
  local ok, err = ShaderFX.activate("main", entry("gameboy"))
  eq(ok, true, "a preset that compiles activates (" .. tostring(err) .. ")")
  eq(newShaderCalls, 5, "all five gameboy passes are compiled at activate, none lazily")
  eq(ShaderFX.active("main"), true, "the slot is live")
  ShaderFX.deactivate("main")
end

do
  local ok = ShaderFX.activate("main", entry("lcd3x"))
  eq(ok, true, "lcd3x activates under the stub")
  local before = #ShaderFX._lastErrors
  local realRunChain = ShaderFX.runChain
  ShaderFX.runChain = function() error("GL_INVALID_OPERATION mid-frame") end
  local canvas = setmetatable({ w = 800, h = 720 }, { __index = {
    getWidth = function(self) return self.w end,
    getHeight = function(self) return self.h end,
    getPixelWidth = function(self) return self.w end,
    getPixelHeight = function(self) return self.h end,
  } })
  local rect = { x = 0, y = 0, w = 800, h = 720, scale = 5 }
  ShaderFX.render(canvas, rect, { w = 160, h = 144 }, 1, 1)
  eq(ShaderFX.active("main"), false, "a chain that throws in render deactivates its slot")
  eq(#ShaderFX._lastErrors, before + 1, "and records exactly one error")
  check(ShaderFX.lastError():find("main chain failed", 1, true) ~= nil
    and ShaderFX.lastError():find("GL_INVALID_OPERATION", 1, true) ~= nil,
    "the recorded error names the slot and the failure")
  ShaderFX.render(canvas, rect, { w = 160, h = 144 }, 1, 1)
  eq(#ShaderFX._lastErrors, before + 1, "the next frame is quiet: no per-frame retry, no per-frame log")
  ShaderFX.runChain = realRunChain
end

do
  local ok = ShaderFX.activate("main", entry("lcd3x"))
  eq(ok, true, "lcd3x activates for the crop case")
  local before = #ShaderFX._lastErrors
  logged = {}
  local realQuad = love.graphics.newQuad
  love.graphics.newQuad = function() error("out of video memory") end
  local canvas = setmetatable({ w = 800, h = 720 }, { __index = {
    getWidth = function(self) return self.w end,
    getHeight = function(self) return self.h end,
    getPixelWidth = function(self) return self.w end,
    getPixelHeight = function(self) return self.h end,
  } })
  local rect = { x = 0, y = 0, w = 800, h = 720, scale = 5 }
  ShaderFX.render(canvas, rect, { w = 160, h = 144 }, 1, 1)
  eq(#ShaderFX._lastErrors, before + 1, "a crop failure records one error")
  check(ShaderFX.lastError():find("crop", 1, true) ~= nil,
    "the recorded error names the crop step")
  ShaderFX.render(canvas, rect, { w = 160, h = 144 }, 1, 1)
  ShaderFX.render(canvas, rect, { w = 160, h = 144 }, 1, 1)
  eq(#ShaderFX._lastErrors, before + 1, "a persistently failing crop does not log or write per frame")
  eq(#logged, 1, "one Logger.error for the whole failing run")
  love.graphics.newQuad = realQuad
  ShaderFX.deactivate("main")
end

T.finish("shaderfx_activate_compiles")
