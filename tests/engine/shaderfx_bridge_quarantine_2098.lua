-- #2092, #2098: a boot that died inside the librashader bridge must quarantine
-- it, and a cached artifact must boot without touching the bridge at all.
--   luajit tests/engine/shaderfx_bridge_quarantine_2098.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
love = love or require("tests.love_stub")

local mem = {}
love.filesystem.write = function(name, body) mem[name] = tostring(body) return true end
love.filesystem.remove = function(name) mem[name] = nil return true end
local baseGetInfo = love.filesystem.getInfo
love.filesystem.getInfo = function(name, filter)
  if mem[name] ~= nil then return { type = "file", size = #mem[name] } end
  return baseGetInfo and baseGetInfo(name, filter) or nil
end
local baseRead = love.filesystem.read
love.filesystem.read = function(name)
  if mem[name] ~= nil then return mem[name], #mem[name] end
  if baseRead then return baseRead(name) end
  return nil, "not found"
end

local ShaderFX = require("src.render.ShaderFX")

check(type(ShaderFX.PROBE_REL) == "string" and ShaderFX.PROBE_REL ~= "",
      "PROBE_REL is exported")
check(type(ShaderFX.clearBridgeQuarantine) == "function",
      "clearBridgeQuarantine is exported")

mem[ShaderFX.PROBE_REL] = "dlopen /old/librashader_bridge.so"
check(ShaderFX.canConvert() == false, "quarantined boot refuses the bridge")
local err = tostring(ShaderFX.bridgeError())
check(err:find("quarantined", 1, true) ~= nil,
      "bridgeError names the quarantine")
check(err:find("/old/librashader_bridge.so", 1, true) ~= nil,
      "bridgeError carries the candidate that died")
check(ShaderFX.canConvert() == false, "quarantine answer is stable")

ShaderFX.clearBridgeQuarantine()
check(mem[ShaderFX.PROBE_REL] == nil, "clearBridgeQuarantine removes the probe")
local retried = ShaderFX.canConvert()
local err2 = ShaderFX.bridgeError()
check(retried == true or tostring(err2):find("quarantined", 1, true) == nil,
      "a clean retry never reports quarantine")
check(mem[ShaderFX.PROBE_REL] == nil,
      "a load attempt that returns leaves no probe behind")

local SCRATCH = os.getenv("TMPDIR") or "/tmp"
local slangp = SCRATCH .. "/qfx2098.slangp"
local artifact = SCRATCH .. "/qfx2098.lua"
do local f = assert(io.open(slangp, "wb")) f:write("shaders = 0\n") f:close() end
local entry = { name = "qfx2098", fullPath = slangp }

local realFind, realConvert, realActivate, realCanConvert =
  ShaderFX.findEntry, ShaderFX.convert, ShaderFX.activate, ShaderFX.canConvert
local converts, activateResults = 0, nil
ShaderFX.findEntry = function(name) if name == "qfx2098" then return entry end end
ShaderFX.convert = function() converts = converts + 1 return true end
ShaderFX.activate = function()
  if activateResults and #activateResults > 0 then
    return table.remove(activateResults, 1)
  end
  return true
end
ShaderFX.canConvert = function() return true end

do local f = assert(io.open(artifact, "wb")) f:write("return {}\n") f:close() end
converts = 0
local opts = { shaderfx = "qfx2098", performance = "high" }
ShaderFX.applyOptions(opts)
check(converts == 0, "a cached artifact boots without the bridge")
check(opts.shaderfx == "qfx2098", "the preset choice survives")

os.remove(artifact)
converts = 0
opts = { shaderfx = "qfx2098", performance = "high" }
ShaderFX.applyOptions(opts)
check(converts == 1, "a missing artifact converts once at boot")

do local f = assert(io.open(artifact, "wb")) f:write("return {}\n") f:close() end
converts = 0
activateResults = { false, true }
opts = { shaderfx = "qfx2098", performance = "high" }
ShaderFX.applyOptions(opts)
check(converts == 1, "a stale artifact reconverts once and retries")
check(opts.shaderfx == "qfx2098", "the retried preset stays selected")

converts = 0
activateResults = { false, false }
opts = { shaderfx = "qfx2098", performance = "high" }
local cleared = ShaderFX.applyOptions(opts)
check(opts.shaderfx == nil and cleared == true,
      "a preset that cannot activate is cleared and the boot goes on")

ShaderFX.findEntry, ShaderFX.convert, ShaderFX.activate, ShaderFX.canConvert =
  realFind, realConvert, realActivate, realCanConvert
os.remove(artifact)
os.remove(slangp)

T.finish()
