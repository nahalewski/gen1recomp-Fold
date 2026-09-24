package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local LaunchOptions = require("src.core.LaunchOptions")
local savedSystem = love.system
local savedGetenv = os.getenv
local env = {}

os.getenv = function(name)
  if env[name] ~= nil then return env[name] end
  return savedGetenv(name)
end

do
  local request = LaunchOptions.parseURI(
    "gen1recomp++://launch?game=r&cart=custom_cart&slot=slot%202&sync=0&update=1&launcher=1")
  eq(request.game, "red", "URI aliases normalize to the canonical game")
  eq(request.cart, "custom_cart", "URI cart ids are preserved")
  check(request.cartSpecified, "URI records an explicit cart value")
  eq(request.slot, "slot 2", "URI values are percent-decoded")
  eq(request.sync, false, "sync=0 disables sync")
  eq(request.update, true, "update=1 enables updates")
  eq(request.launcher, true, "launcher=1 forces the launcher")
  check(request.gameSpecified, "URI records an explicit game value")
end

do
  local request = LaunchOptions.parseURI(
    "GEN1RECOMP++://LAUNCH?game=blue&sync=true&update=off")
  eq(request.game, "blue", "URI scheme and host are case-insensitive")
  eq(request.sync, true, "boolean URI values accept true")
  eq(request.update, false, "boolean URI values accept off")
  local direct = LaunchOptions.parseURI("gen1recomp++://launch?game=red")
  eq(direct.launcher, nil, "omitted launcher does not force the launcher")
  eq(direct.sync, nil, "omitted sync keeps the normal sync default")
  eq(direct.update, nil, "omitted update keeps the normal update default")
  eq(LaunchOptions.uriFor("r", { cart = "custom cart", slot = "slot 2" }),
    "gen1recomp++://launch?game=red&slot=slot%202",
    "URI builder ignores invalid cart ids")
  eq(LaunchOptions.uriFor("red", { cart = "custom_cart", slot = "slot 2" }),
    "gen1recomp++://launch?game=red&cart=custom_cart&slot=slot%202",
    "URI builder encodes cart and slot values")
  check(LaunchOptions.parseURI("gen1recomp++://other?game=red") == nil,
    "unknown URI hosts are rejected")
  check(LaunchOptions.parseURI("https://launch?game=red") == nil,
    "unknown URI schemes are rejected")
  check(LaunchOptions.parseURI("gen1recomp++://launch?game=%") == nil,
    "malformed percent escapes are rejected")
  check(LaunchOptions.parseURI("gen1recomp++://launch/red") == nil,
    "path-style URI variants are rejected")
  check(LaunchOptions.isLaunchURI("gen1recomp++://launch?game=%") ,
    "recognized URI authority survives malformed query values")
end

do
  love.system = {
    getOS = function() return "Android" end,
    getLaunchGame = function() return "yellow" end,
    getLaunchURI = function()
      return "gen1recomp++://launch?game=gold&slot=slot9&sync=0&update=1"
    end,
  }
  env.POKEPORT_GAME = "silver"
  env.POKEPORT_SLOT = "slot8"
  env.POKEPORT_LAUNCH_SYNC = "1"
  env.POKEPORT_LAUNCH_UPDATE = "0"

  local resolved = LaunchOptions.resolveRequest({
    "--game=red", "--slot=slot2", "--no-sync", "--update" }, {})
  eq(resolved.game, "red", "command-line game overrides URI and environment")
  eq(resolved.slot, "slot2", "command-line slot overrides URI and environment")
  eq(resolved.tasks.sync, false, "command-line no-sync overrides URI")
  eq(resolved.tasks.update, true, "command-line update overrides URI")

  resolved = LaunchOptions.resolveRequest({}, {})
  eq(resolved.game, "gold", "URI game overrides the Android legacy intent and environment")
  eq(resolved.slot, "slot9", "URI slot overrides the environment")
  eq(resolved.tasks.sync, false, "URI sync overrides the environment")
  eq(resolved.tasks.update, true, "URI update overrides the environment")

  love.system.getLaunchURI = function()
    return "gen1recomp++://launch?game=not-a-game&launcher=0"
  end
  env.POKEPORT_GAME = "silver"
  env.POKEPORT_FORCE_LAUNCHER = "1"
  resolved = LaunchOptions.resolveRequest({}, {})
  eq(resolved.game, nil, "unsupported URI games do not fall through to the environment")
  eq(resolved.launcher, false, "launcher=0 overrides the environment")
end

do
  local uriCalls = 0
  love.system = {
    getLaunchURI = function()
      uriCalls = uriCalls + 1
      if uriCalls == 1 then
        return "gen1recomp++://launch?game=red&sync=0&update=1"
      end
      return nil
    end,
  }
  env.POKEPORT_LAUNCH_SYNC = nil
  env.POKEPORT_LAUNCH_UPDATE = nil
  local resolved = LaunchOptions.resolveRequest({}, {})
  eq(uriCalls, 1, "one launch request consumes one cold-start URI")
  eq(resolved.game, "red", "cold-start URI remains available to boot resolution")
  eq(resolved.tasks.sync, false, "cold-start URI sync reaches preflight")
  eq(resolved.tasks.update, true, "cold-start URI update reaches preflight")
end

do
  love.system.getLaunchURI = function() return nil end
  env.POKEPORT_GAME = nil
  env.POKEPORT_SLOT = nil
  env.POKEPORT_LAUNCH_SYNC = nil
  env.POKEPORT_LAUNCH_UPDATE = nil
  local request = LaunchOptions.fromGame("g")
  eq(request.game, "gold", "legacy Android game intents use shared normalization")
  eq(request.tasks.update, false, "legacy Android intents do not run updates")
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local body = file:read("*a")
  file:close()
  return body
end

local main = read("main.lua")
local java = read("mobile/android/love/src/main/java/org/love2d/android/GameActivity.java")
local androidManifest = read("mobile/android/app/src/main/AndroidManifest.xml")
local plist = read("mobile/ios/overlays/love-ios.plist")
local artifactWorkflow = read(".github/workflows/platform-artifact-comment.yml")

check(main:find("function love.handlers.intent_uri", 1, true) ~= nil,
  "main.lua defines the URI intent handler")
check(main:find("LaunchOptions.parseURI(filename)", 1, true) ~= nil,
  "iOS SDL URL drop events are parsed before file import")
check(main:find("startLaunchRequest(request or {})", 1, true) ~= nil,
  "malformed recognized URLs fall back to the launcher")
check(main:find("tasks = request.tasks or {}", 1, true) ~= nil,
  "URI launches use the shared prelaunch task request")
check(main:find("LaunchOptions.pollURI()", 1, true) ~= nil,
  "iOS warm URL opens are polled through the shared request path")
check(java:find("nativeOnLaunchURI", 1, true) ~= nil,
  "Android forwards warm URI intents to native")
check(java:find("getLaunchURI", 1, true) ~= nil,
  "Android exposes the cold-start URI")
check(androidManifest:find('android:scheme="gen1recomp++"', 1, true) ~= nil,
  "Android registers the gen1recomp++ scheme")
check(androidManifest:find('android:host="launch"', 1, true) ~= nil,
  "Android restricts the URI host to launch")
check(plist:find("CFBundleURLTypes", 1, true) ~= nil,
  "iOS registers URL types")
check(plist:find("gen1recomp++", 1, true) ~= nil,
  "iOS registers the gen1recomp++ scheme")
check(artifactWorkflow:find("workflows: [ci]", 1, true) ~= nil,
  "artifact comments are driven by the unified CI workflow")
check(artifactWorkflow:find("cancel-in-progress: false", 1, true) ~= nil,
  "artifact comment runs are serialized per branch")
check(artifactWorkflow:find('comment-tag: platform-build-result', 1, true) ~= nil,
  "all platform artifacts use one stable comment tag")
check(artifactWorkflow:find("gen1recomp-android-apk", 1, true) ~= nil,
  "the unified artifact comment includes Android")
check(artifactWorkflow:find("gen1recomp-win64", 1, true) ~= nil,
  "the unified artifact comment includes Windows")
check(artifactWorkflow:find("gen1recomp-linux-x86_64", 1, true) ~= nil,
  "the unified artifact comment includes Linux x86_64")
local pickerBridge = read("mobile/ios/native/GRPickerBridge.swift")
local bootstrap = read("mobile/ios/native/GRBootstrap.m")
local iosPatch = read("mobile/ios/patch_love_src.py")
local launcherView = read("src/import/LauncherView.lua")
local webClip = read("src/core/WebClip.lua")
check(pickerBridge:find("installWebClipWithLabel:url:icon:iconLength:", 1, true) ~= nil,
  "iOS exposes managed Home Screen profile installation")
check(pickerBridge:find("SFSafariViewController", 1, true) ~= nil,
  "iOS presents the profile through Safari")
check(bootstrap:find("safari_isHTTPFamilyURL", 1, true) ~= nil,
  "iOS accepts the profile data URL in Safari")
check(bootstrap:find("UIApplicationLaunchOptionsURLKey", 1, true) ~= nil,
  "iOS captures cold-start launch URLs")
check(bootstrap:find("GRApplicationOpenURL", 1, true) ~= nil,
  "iOS captures warm launch URLs")
check(bootstrap:find("GRSceneWillConnect", 1, true) ~= nil,
  "iOS captures scene cold-start URLs")
check(bootstrap:find("GRSceneOpenURLContexts", 1, true) ~= nil,
  "iOS captures scene warm launch URLs")
check(iosPatch:find('"installWebClip", w_installWebClip', 1, true) ~= nil,
	"iOS patches the WebClip bridge into love.system")
check(iosPatch:find('"pollLaunchURI", w_pollLaunchURI', 1, true) ~= nil,
  "iOS exposes a warm launch URI poll")
check(launcherView:find("LONG_PRESS_SECONDS", 1, true) ~= nil,
  "iOS launcher tracks long presses on ready cartridges")
check(launcherView:find("Add to Home Screen", 1, true) ~= nil,
  "iOS launcher exposes the Home Screen action")
check(launcherView:find("Home Screen", 1, true) ~= nil,
  "iOS exposes a Home Screen action for each installed cart")
check(webClip:find("LaunchOptions.uriFor", 1, true) ~= nil,
	"WebClip URLs use the shared launch URI builder")
check(webClip:find("Pokémon Red", 1, true) ~= nil,
	"Red Home Screen entries use the accented Pokémon label")

os.getenv = savedGetenv
love.system = savedSystem
T.finish("URI launch arguments")
