-- Flatpak finish-args / packaging contract.
--   luajit tests/engine/flatpak_manifest_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check

local f = assert(io.open("flatpak/com.theboisclub.gen1recomp.yml", "rb"))
local yml = f:read("*a")
f:close()

check(yml:find("%-%-device=all", 1, false) or yml:find("--device=all", 1, true),
  "Flatpak finish-args include --device=all for gamepads")
check(yml:find("--share=network", 1, true), "Flatpak shares network")
check(yml:find("--filesystem=home", 1, true), "Flatpak allows home for ROM import")
check(yml:find("com.theboisclub.gen1recomp", 1, true), "Flatpak app-id present")

local meta = assert(io.open("flatpak/com.theboisclub.gen1recomp.metainfo.xml", "rb"))
local xml = meta:read("*a")
meta:close()
check(xml:find("<releases>", 1, true), "AppStream metainfo includes releases")
check(xml:find("<release ", 1, true), "AppStream metainfo includes a release entry")
check(xml:find("<project_license>MIT</project_license>", 1, true),
  "AppStream metainfo declares MIT project license")
check(not xml:find("LicenseRef-proprietary", 1, true),
  "AppStream metainfo must not claim proprietary")
check(xml:find('url type="homepage">https://gen1re.com/</url>', 1, true),
  "AppStream metainfo homepage is gen1re.com")
check(xml:find('url type="vcs-browser">https://github.com/bryanthaboi/gen1recomp</url>', 1, true),
  "AppStream metainfo vcs-browser points at the public repo")

print("ok")
