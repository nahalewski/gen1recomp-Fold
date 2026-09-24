package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

local RG = require("src.core.RequireGuard")

local loaders = package.loaders or package.searchers
check(type(loaders) == "table", "package.loaders is a table on this interpreter")

local original = {}
for i = 1, #loaders do original[i] = loaders[i] end

local function restore()
  for i = #loaders, 1, -1 do loaders[i] = nil end
  for i = 1, #original do loaders[i] = original[i] end
end

local function indexOf(fn)
  for i = 1, #loaders do
    if loaders[i] == fn then return i end
  end
  return nil
end

local fakeA = function() end
local fakeB = function() end

local savedLove = _G.love
_G.love = { filesystem = {} }

table.insert(loaders, 2, fakeA)
check(RG.capture() == true, "capture() snapshots package.loaders[2] under love")
check(RG.captured() == true, "captured() reports the snapshot")
check(RG.present() == true, "present() is true on an intact chain")
check(RG.repair() == false, "repair() on an intact chain reports no repair")
eq(#loaders, #original + 1, "repair() on an intact chain adds no entry")

table.insert(loaders, 2, fakeB)
check(RG.capture() == false, "capture() is idempotent")

table.remove(loaders, indexOf(fakeA))
check(RG.present() == false, "present() detects the dropped love searcher")
check(RG.repair() == true, "repair() puts the love searcher back")
eq(indexOf(fakeA), 2, "repair() reinserts the searcher at index 2")
check(RG.present() == true, "present() is true again after repair")
check(RG.repair() == false, "a second repair() adds nothing")
eq(#loaders, #original + 2, "chain length is stable across repairs")

restore()

_G.love = nil
package.loaded["src.core.RequireGuard"] = nil
local Fresh = require("src.core.RequireGuard")
check(Fresh.capture() == false, "capture() without love.filesystem is a no-op")
check(Fresh.captured() == false, "no snapshot is taken without love.filesystem")
check(Fresh.present() == true, "present() stays true when nothing was captured")
check(Fresh.repair() == false, "repair() without a snapshot changes nothing")
eq(#loaders, #original, "an uncaptured guard leaves package.loaders alone")

package.loaded["src.core.RequireGuard"] = nil
_G.love = savedLove

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local body = f:read("*a")
  f:close()
  return body
end

local mainBody = readFile("main.lua")
check(mainBody ~= nil, "main.lua is readable from the repo root")
mainBody = mainBody or ""

check(mainBody:find('require("src.core.RequireGuard").capture()', 1, true) ~= nil,
  "love.load captures love's filesystem searcher")

local function functionBody(header)
  local s = mainBody:find(header)
  if not s then return "" end
  local e = mainBody:find("\nend\n", s, true) or #mainBody
  return mainBody:sub(s, e)
end

local bootBody = functionBody("function bootGame%(")
check(bootBody ~= "", "main.lua still defines bootGame")
check(bootBody:find('require("src.core.RequireGuard").repair()', 1, true) ~= nil,
  "bootGame repairs the loader chain before its first cold require")

local returnBody = functionBody("local function returnToLauncher%(")
check(returnBody ~= "", "main.lua still defines returnToLauncher")
check(returnBody:find('require("src.core.RequireGuard").repair()', 1, true) ~= nil,
  "returnToLauncher repairs the loader chain")

local issueBody = readFile("src/core/IssueReport.lua") or ""
check(issueBody:find("RequireGuard", 1, true) ~= nil
    and issueBody:find("Loader chain", 1, true) ~= nil,
  "diagnostics report a missing love searcher")

T.finish()
