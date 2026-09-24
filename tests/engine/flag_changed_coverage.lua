-- Every story/event flag a mod can watch has to travel through
-- src/script/Flags.lua, which is what emits flag.changed.  The overworld used
-- to write nine of them straight into save.flags -- card-key doors, defeated
-- trainer events, victory items and rewards, the two gate guards, a Seafoam
-- boulder and a warp-origin battle -- so a mod listening for the beat never
-- heard it.  A behaviour check plus a guard against writing raw again.
--   luajit tests/engine/flag_changed_coverage.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

local Events = require("src.mods.Events")
local Hooks = require("src.mods.Hooks")
local Runtime = require("src.mods.Runtime")
local Flags = require("src.script.Flags")

Runtime.install(Events.new(), Hooks.new(), {})

-- ------------------------------------------------------------- behaviour

local seen = {}
Runtime.events:on("flag.changed", function(payload)
  seen[#seen + 1] = { name = payload.name, value = payload.value }
end, nil, "flagcoverage")

local save = { flags = {} }
Flags.set(save, "EVENT_BEAT_FIX_YOUNGSTER")
T.eq(#seen, 1, "setting a fresh flag emits once")
T.eq(seen[1].name, "EVENT_BEAT_FIX_YOUNGSTER", "the payload names the flag")
T.eq(seen[1].value, true, "and carries its new value")

Flags.set(save, "EVENT_BEAT_FIX_YOUNGSTER")
T.eq(#seen, 1, "setting it again is silent")

Flags.clear(save, "EVENT_BEAT_FIX_YOUNGSTER")
T.eq(#seen, 2, "clearing it emits")
T.eq(seen[2].value, false, "with the cleared value")
T.eq(Flags.get(save, "EVENT_BEAT_FIX_YOUNGSTER"), false, "and the flag is off")

-- --------------------------------------------------------------- guard

local function readFile(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local body = fh:read("*a")
  fh:close()
  return body
end

for _, path in ipairs({ "src/world/OverworldController.lua",
                        "src/world/WorldAPI.lua",
                        "src/script/Commands.lua",
                        "src/inventory/ItemEffects.lua" }) do
  local body = readFile(path)
  T.check(body ~= nil, path .. " is readable")
  local raw = 0
  for line in (body or ""):gmatch("[^\n]+") do
    if line:match("%f[%w]flags%[[^%]]+%]%s*=") then raw = raw + 1 end
  end
  T.eq(raw, 0, path .. " writes event flags through Flags, not save.flags")
end

T.finish("flag.changed coverage")
