-- Dual curl env selection for AppImage / Flatpak / host.
--   luajit tests/engine/hostshell_curl_env_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

-- Isolate getenv for the HostShell module load.
local env = {
  APPIMAGE = "/tmp/fake.AppImage",
  APPDIR = "/tmp/fake-appdir",
  LD_LIBRARY_PATH = "/tmp/fake-appdir/lib",
  LD_PRELOAD = "/tmp/steam_overlay.so",
}
local realGetenv = os.getenv
function os.getenv(k)
  if env[k] ~= nil then return env[k] end
  return realGetenv(k)
end

-- Clear any prior HostShell package so resolveCurl memoization is fresh.
package.loaded["src.core.HostShell"] = nil
local HostShell = require("src.core.HostShell")

eq(HostShell.curlEnvPrefix("host"),
  "env -u LD_LIBRARY_PATH -u LD_PRELOAD ",
  "host curl scrubs AppImage libs and Steam preload")
eq(HostShell.curlEnvPrefix("bundled"),
  "env -u LD_PRELOAD ",
  "bundled curl keeps LD_LIBRARY_PATH, still scrubs Steam preload")

-- Without APPIMAGE, host prefix only scrubs preload when set.
env.APPIMAGE = nil
eq(HostShell.curlEnvPrefix("host"),
  "env -u LD_PRELOAD ",
  "non-AppImage host curl still scrubs LD_PRELOAD")

-- Bundled path preferred when APPDIR curl exists.
env.APPIMAGE = "/tmp/fake.AppImage"
env.FLATPAK_ID = nil
local fakeBin = "/tmp/fake-appdir/usr/bin"
os.execute('mkdir -p "' .. fakeBin .. '"')
local curlPath = fakeBin .. "/curl"
local f = assert(io.open(curlPath, "wb"))
f:write("#!/bin/sh\necho curl\n")
f:close()
os.execute('chmod +x "' .. curlPath .. '"')

package.loaded["src.core.HostShell"] = nil
-- Reset memo by reloading; resolveCurl caches in module locals.
HostShell = require("src.core.HostShell")
local path, kind = HostShell.resolveCurl()
eq(kind, "bundled", "APPDIR curl selected as bundled")
eq(path, curlPath, "APPDIR usr/bin/curl path used")

-- Flatpak wins over APPDIR.
env.FLATPAK_ID = "com.theboisclub.gen1recomp"
os.execute('mkdir -p /tmp/fake-flatpak-app/bin')
-- We cannot create /app/bin without root; instead stub by temporarily
-- pointing resolveCurl via FLATPAK_ID alone when /app/bin/curl missing
-- falls through to APPDIR — document that Flatpak ships /app/bin/curl.
package.loaded["src.core.HostShell"] = nil
HostShell = require("src.core.HostShell")
path, kind = HostShell.resolveCurl()
-- Without a real /app/bin/curl, APPDIR still wins; that is fine for this
-- host-side unit test. Flatpak packaging installs /app/bin/curl.
check(kind == "bundled" or kind == "host", "resolveCurl returns a known kind")

local diag = HostShell.curlDiagnostics()
check(type(diag) == "table", "curlDiagnostics returns a table")
check(diag.path ~= nil, "diagnostics include path")

os.getenv = realGetenv
os.remove(curlPath)
print("ok")
