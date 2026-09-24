-- Portable writability probe + Flatpak skip.
--   luajit tests/engine/portable_writable_probe_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

local tmp = os.getenv("TMPDIR") or "/tmp"
local base = tmp .. "/gen1recomp-portable-probe-" .. tostring(os.time())
os.execute('mkdir -p "' .. base .. '"')
local marker = assert(io.open(base .. "/portable.txt", "wb"))
marker:write("1\n")
marker:close()

-- Minimal LOVE stubs so SaveData.gameFolders returns our base.
_G.love = {
  filesystem = {
    getSource = function() return base .. "/game" end,
    getSourceBaseDirectory = function() return base end,
  },
  system = {
    getOS = function() return "Linux" end,
  },
}

local env = {}
local realGetenv = os.getenv
function os.getenv(k)
  if env[k] ~= nil then return env[k] end
  return realGetenv(k)
end

package.loaded["src.core.SaveData"] = nil
local SaveData = require("src.core.SaveData")

check(SaveData.isPortable() == true, "writable portable parent activates portable mode")
eq(SaveData.portableBaseDir(), base, "portable base is the probed folder")

SaveData._resetPortableCacheForTests()
env.FLATPAK_ID = "com.theboisclub.gen1recomp"
check(SaveData.isPortable() == false, "Flatpak ignores portable.txt")
eq(SaveData.portableBaseDir(), nil, "Flatpak has no portable base")

-- Read-only parent: create a dir we cannot write (best-effort).
SaveData._resetPortableCacheForTests()
env.FLATPAK_ID = nil
local ro = base .. "-ro"
os.execute('mkdir -p "' .. ro .. '" && touch "' .. ro .. '/portable.txt" && chmod 555 "' .. ro .. '"')
_G.love.filesystem.getSourceBaseDirectory = function() return ro end
_G.love.filesystem.getSource = function() return ro .. "/game" end
SaveData._resetPortableCacheForTests()
-- chmod 555 may still allow owner write on some FS; accept either outcome
-- but must not throw.
local ok, portable = pcall(function() return SaveData.isPortable() end)
check(ok, "RO portable probe must not throw")
if portable then
  check(SaveData.portableBaseDir() ~= nil, "if still writable, portable stays on")
else
  eq(SaveData.portableBaseDir(), nil, "unwritable portable parent falls back")
end

os.getenv = realGetenv
os.execute('chmod 755 "' .. ro .. '" 2>/dev/null; rm -rf "' .. base .. '" "' .. ro .. '"')
print("ok")
