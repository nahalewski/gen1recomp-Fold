-- Unstamped builds derive "0.0.0-dev+<commit>" so two checkouts never pair as
-- `full` on an exact engineVersion match (online plan 0.9).
--   luajit tests/engine/version_dev_identity_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check = T.check
local eq = T.eq

local Version = require("src.core.Version")
local Handshake = require("src.link.Handshake")

local PLACEHOLDER = "0.0.0-dev"
local HASH = "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b"

local root = os.getenv("TMPDIR") or "/tmp"
root = root:gsub("/$", "") .. "/pokeport-version-dev-" .. tostring(os.time())

local function write(path, text)
  os.execute(("mkdir -p '%s'"):format(path:match("^(.*)/[^/]+$")))
  local handle = assert(io.open(path, "wb"))
  handle:write(text)
  handle:close()
end

-- --- ref: HEAD resolved through refs/heads
local repoDir = root .. "/checkout"
write(repoDir .. "/.git/HEAD", "ref: refs/heads/dev\n")
write(repoDir .. "/.git/refs/heads/dev", HASH .. "\n")

local derived = Version.devEngine(PLACEHOLDER, repoDir)
check(derived:match("^0%.0%.0%-dev%+%x+$") ~= nil,
  "derived dev identity is 0.0.0-dev+<hex>, got " .. tostring(derived))
eq(derived, PLACEHOLDER .. "+" .. HASH:sub(1, 12),
  "the suffix is the first 12 hex of the resolved commit")
eq(tonumber(derived:match("^(%d+)")), 0,
  "semver major still parses as 0 (Handshake.checkCompat major())")

-- --- a second checkout at another commit derives a different string
local otherDir = root .. "/checkout2"
local OTHER = "9f8e7d6c5b4a39281706f5e4d3c2b1a098765432"
write(otherDir .. "/.git/HEAD", "ref: refs/heads/dev\n")
write(otherDir .. "/.git/refs/heads/dev", OTHER .. "\n")
local otherDerived = Version.devEngine(PLACEHOLDER, otherDir)
check(otherDerived ~= derived, "two checkouts derive different engine strings")

-- --- packed-refs fallback (a fresh clone has no loose ref file)
local packedDir = root .. "/packed"
write(packedDir .. "/.git/HEAD", "ref: refs/heads/dev\n")
write(packedDir .. "/.git/packed-refs",
  "# pack-refs with: peeled fully-peeled sorted\n"
  .. HASH .. " refs/heads/dev\n")
eq(Version.devEngine(PLACEHOLDER, packedDir), PLACEHOLDER .. "+" .. HASH:sub(1, 12),
  "packed-refs resolves the branch when no loose ref exists")

-- --- detached HEAD holds the hash directly
local detachedDir = root .. "/detached"
write(detachedDir .. "/.git/HEAD", HASH .. "\n")
eq(Version.devEngine(PLACEHOLDER, detachedDir), PLACEHOLDER .. "+" .. HASH:sub(1, 12),
  "detached HEAD is read as the commit")

-- --- no repo, and a stamped release, are both left alone
eq(Version.devEngine(PLACEHOLDER, root .. "/nope"), PLACEHOLDER,
  "no .git leaves the placeholder untouched")
eq(Version.devEngine("0.1.73", repoDir), "0.1.73",
  "a stamped release version is returned untouched")
eq(Version.devEngine("1.0.0-rc1", repoDir), "1.0.0-rc1",
  "only the exact placeholder is derived from")


-- --- a packaged build reads its commit out of build-info.json
local savedRead = love.filesystem.read
love.filesystem.read = function(name)
  if name == "build-info.json" then
    return '{"gitCommit": "deadbee", "gitCommitFull": "' .. HASH .. '"}'
  end
  return savedRead(name)
end
eq(Version.devEngine(PLACEHOLDER, root .. "/nope"), PLACEHOLDER .. "+" .. HASH:sub(1, 12),
  "build-info.json wins over the git walk in a packaged tree")
love.filesystem.read = savedRead

os.execute(("rm -rf '%s'"):format(root))

-- --- the verdict two dev checkouts now get
local function hello(engine)
  return {
    type = "hello",
    protocol = Handshake.PROTOCOL,
    engineVersion = engine,
    apiVersion = Version.modApi,
    generation = 1,
    fingerprint = "same-surface",
  }
end

local verdict, reason = Handshake.checkCompat(hello(derived), hello(otherDerived))
eq(verdict, "engine_skew", "different +hash suffixes are an engine skew")
eq(reason, "engine_release_mismatch", "and the skew names the release mismatch")
check(not Handshake.battleAllowed(verdict), "so no lockstep battle is started")

verdict = Handshake.checkCompat(hello(derived), hello(derived))
eq(verdict, "full", "identical dev identities still pair as full")

verdict = Handshake.checkCompat(hello(PLACEHOLDER), hello(derived))
eq(verdict, "engine_skew", "a bare placeholder and a derived build are skewed")

T.finish("version dev identity")
