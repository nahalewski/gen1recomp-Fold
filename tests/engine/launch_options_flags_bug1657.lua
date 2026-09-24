
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local eq = T.eq
love = love or require("tests.love_stub")

local LaunchOptions = require("src.core.LaunchOptions")

local realGetenv = os.getenv
local env = {}
os.getenv = function(name)
  if env[name] ~= nil then return env[name] end
  return realGetenv(name)
end

local function tasks(argv, rawArgv)
  return LaunchOptions.tasks(argv, rawArgv)
end

do
  local t = tasks({}, nil)
  eq(t.sync, nil, "with no flags sync is left to the device's own setup")
  eq(t.update, false, "and the update stage is strictly opt-in")
end

do
  eq(tasks({ "--update" }, nil).update, true, "--update turns the stage on")
  eq(tasks({ "-update" }, nil).update, true, "-update does too")
  eq(tasks({}, { "-update" }).update, true,
    "a single-dash -update LOVE swallowed is still found in the raw argv")
  eq(tasks({}, { "--update" }).update, true, "as is the double-dash spelling")
  eq(tasks({ "--sync" }, nil).sync, true, "--sync forces the sync stage")
  eq(tasks({ "-sync" }, nil).sync, true, "-sync forces it too")
end

do
  eq(tasks({ "--no-sync" }, nil).sync, false, "--no-sync opts out")
  eq(tasks({ "--sync", "--no-sync" }, nil).sync, false,
    "no- beats the positive flag in the same argv")
  eq(tasks({ "--sync" }, { "--no-sync" }).sync, false,
    "and beats it across the parsed / raw argv split")
  eq(tasks({ "--update", "--no-update" }, nil).update, false,
    "--no-update cancels an --update on the same line")
end

do
  env.POKEPORT_LAUNCH_SYNC = "0"
  eq(tasks({}, nil).sync, false, "POKEPORT_LAUNCH_SYNC=0 opts out")
  eq(tasks({ "--sync" }, nil).sync, true, "an explicit --sync overrides it")
  env.POKEPORT_LAUNCH_SYNC = "1"
  eq(tasks({}, nil).sync, true, "POKEPORT_LAUNCH_SYNC=1 opts in")
  eq(tasks({ "--no-sync" }, nil).sync, false, "--no-sync overrides that")
  env.POKEPORT_LAUNCH_SYNC = "yes"
  eq(tasks({}, nil).sync, nil, "any other value is not an opinion")
  env.POKEPORT_LAUNCH_SYNC = nil

  env.POKEPORT_LAUNCH_UPDATE = "1"
  eq(tasks({}, nil).update, true, "POKEPORT_LAUNCH_UPDATE=1 opts in")
  eq(tasks({ "--no-update" }, nil).update, false, "--no-update overrides it")
  env.POKEPORT_LAUNCH_UPDATE = nil
end

do
  eq(LaunchOptions.forceLauncher({ "-launcher" }), true,
    "-launcher forces the launcher like --launcher does")
end

do
  eq(LaunchOptions.commandFor("red"), "--game red",
    "the bare shortcut command is unchanged")
  eq(LaunchOptions.commandFor("red", "slot2"), "--game red --slot slot2",
    "and so is the slot form")
  local cmd = LaunchOptions.commandFor("red", "slot2",
    { update = true, sync = false })
  eq(cmd, "--game red --slot slot2 --update --no-sync",
    "task flags append in a stable order")

  local argv = {}
  for word in cmd:gmatch("%S+") do argv[#argv + 1] = word end
  local game, slot = LaunchOptions.resolve(argv)
  eq(game, "red", "the round-tripped command still names the game")
  eq(slot, "slot2", "and the slot")
  local t = tasks(argv, nil)
  eq(t.update, true, "and the update task survives the round trip")
  eq(t.sync, false, "and so does the sync opt-out")
end

os.getenv = realGetenv

T.finish("launch options task flags (#1657)")
