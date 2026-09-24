-- HostShell.httpPost must work with Lua/LuaJIT's one-way io.popen.
--
-- io.popen accepts "r" or "w", not "rw".  POST needs both a request body
-- and a response status, so the body is staged in a temporary file and curl
-- is opened read-only for its response.
--   luajit tests/engine/host_shell_postlog.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
local HostShell = require("src.core.HostShell")

local MARK = "\n__gen1recomp_http__"
local STAGE_DIR = "/tmp/gen1recomp-postlog-stage"
local URL = "https://logs.example.com/logs"
local BODY = "debug log body\n"

local realOpen = io.open
local realPopen = io.popen
local realGetenv = os.getenv
local realRemove = os.remove
local realHaveCurl = HostShell.haveCurl

local openedPath, openedMode, writtenBody
local popenCommand, popenMode, removedPath

HostShell.haveCurl = function() return true end
os.getenv = function(name)
  if name == "TEMP" or name == "TMP" or name == "TMPDIR" then
    return STAGE_DIR
  end
  return realGetenv(name)
end
os.remove = function(path)
  removedPath = path
  return true
end

io.open = function(path, mode)
  openedPath, openedMode = path, mode
  return {
    write = function(_, value)
      writtenBody = value
      return true
    end,
    close = function() return true end,
  }
end

io.popen = function(command, mode)
  popenCommand, popenMode = command, mode
  return {
    read = function() return MARK .. "200" end,
    close = function() return true end,
  }
end

local ok, err = HostShell.httpPost(URL, BODY, "text/plain", "gen1recomp-mod/test", 10)

io.open = realOpen
io.popen = realPopen
os.getenv = realGetenv
os.remove = realRemove
HostShell.haveCurl = realHaveCurl

eq(ok, true, "a desktop POST succeeds through the read-only response pipe: " .. tostring(err))
check(type(openedPath) == "string" and openedPath:find(STAGE_DIR .. "/gen1recomp-post-", 1, true) == 1, "the request body is staged under the OS temp dir")
check(openedPath and openedPath:sub(-4) == ".tmp", "the staged body carries a .tmp name")
eq(openedMode, "wb", "the temporary request body is opened for binary writing")
eq(writtenBody, BODY, "the complete log body is staged")
eq(popenMode, "r", "curl is opened in the supported read-only mode")
check(popenCommand:find("--data-binary", 1, true) ~= nil,
  "curl reads the staged body with --data-binary")
check(openedPath and popenCommand:find(openedPath, 1, true) ~= nil,
  "curl receives the temporary body path")
check(popenCommand:find(BODY, 1, true) == nil,
  "the log body is not placed directly in the command line")
eq(removedPath, openedPath, "the staged request body is removed")

T.finish("host shell postlog")
