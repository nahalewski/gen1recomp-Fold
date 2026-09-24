package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local Fetch = require("src.net.Fetch")
local ModIndex = require("src.mods.ModIndex")
local HostShell = require("src.core.HostShell")
local RomImporter = require("src.import.RomImporter")

ModIndex.fetchText = function() error("Details fetched on the render thread") end
ModIndex.httpGet = function() error("Details fetched on the render thread") end
HostShell.httpGet = function() error("Details fetched on the render thread") end

local requested, released, cancelled, answer
Fetch.get = function(url)
  requested[#requested + 1] = url
  return #requested
end
Fetch.poll = function() return answer end
Fetch.release = function(id) released[#released + 1] = id end
Fetch.cancel = function(id) cancelled[#cancelled + 1] = id end

local function launcher()
  requested, released, cancelled = {}, {}, {}
  answer = { status = "pending" }
  return setmetatable({ tab = "find" }, RomImporter)
end

local ENTRY = { id = "rare_soda", title = "Rare Soda",
                summary = "A soda, but rare.",
                description_url = "mods/rare_soda.md",
                _base = "https://example.invalid/" }

do
  local ri = launcher()
  ri:_findShowDetails(ENTRY)
  check(ri._findDetails ~= nil, "Details opens on the click that asked for it")
  eq(ri._findDetails.title, "Rare Soda", "titled with the entry")
  eq(ri._findDetails.body, "A soda, but rare.",
    "showing the listing summary while the markdown is in flight")
  check(ri._findDetails.loading, "and saying so")

  ri:_pumpFindDetails()
  eq(#requested, 1, "the frame after the click is what goes to the network")
  eq(requested[1], "https://example.invalid/mods/rare_soda.md",
    "asking for the entry's description, resolved against its index")
  check(ri._findDetails.loading, "and the modal is still waiting")

  ri:_pumpFindDetails()
  check(ri._findDetails.loading, "a pending poll leaves the modal as it was")
  eq(#released, 0, "and holds the job")

  answer = { status = "ok", body = "# Rare Soda\n\nIt is rare." }
  ri:_pumpFindDetails()
  eq(ri._findDetails.body, "# Rare Soda\n\nIt is rare.",
    "the markdown replaces the summary when it lands")
  eq(ri._findDetails.loading, false, "and the modal stops waiting")
  eq(#released, 1, "the job is released")
  eq(ri._findDetailsFetch, nil, "and the handle is dropped")

  ri:_pumpFindDetails()
  eq(#requested, 1, "a settled modal asks for nothing more")
end

do
  local ri = launcher()
  ri:_findShowDetails(ENTRY)
  ri:_pumpFindDetails()
  answer = { status = "error", err = "timeout" }
  ri:_pumpFindDetails()
  eq(ri._findDetails.body, "A soda, but rare.",
    "a failed description keeps the summary")
  eq(ri._findDetails.loading, false, "and the modal is done waiting")
end

do
  local ri = launcher()
  ri:_findShowDetails(ENTRY)
  ri:_pumpFindDetails()
  ri._findDetails = nil
  ri:_pumpFindDetails()
  eq(#cancelled, 1, "closing the modal cancels the request behind it")
  eq(ri._findDetailsFetch, nil, "and drops the handle")
  answer = { status = "ok", body = "# Too late" }
  ri:_pumpFindDetails()
  eq(ri._findDetails, nil, "so a late answer does not reopen the modal")
end

do
  local ri = launcher()
  ri:_findShowDetails(ENTRY)
  ri:_pumpFindDetails()
  ri:_findShowDetails(ENTRY)
  eq(#cancelled, 1, "the first request is cancelled")
  ri:_pumpFindDetails()
  eq(#requested, 2, "and the second one is what the modal is waiting on")
end

do
  local ri = launcher()
  ri:_findShowDetails({ id = "bare", title = "Bare", summary = "Nothing more." })
  check(ri._findDetails ~= nil, "the modal still opens")
  eq(ri._findDetails.loading, false, "with nothing to wait for")
  ri:_pumpFindDetails()
  eq(#requested, 0, "and no request at all")
end

T.finish("launcher find details")
