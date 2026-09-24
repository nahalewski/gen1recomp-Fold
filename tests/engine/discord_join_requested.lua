-- Unit coverage for event:discord.join_requested (DiscordPresence Ask-to-Join).
-- Mods subscribe through Runtime; the engine emits before it hands the code
-- to the launcher's online client.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Events = require("src.mods.Events")
local DiscordPresence = require("src.core.DiscordPresence")

local joined = {}
local savedClient = package.loaded["src.online.Client"]
package.loaded["src.online.Client"] = {
  joinRoom = function(code, as)
    joined[#joined + 1] = { code = code, as = as }
  end,
}

local function freshGame(withLauncher)
  local items = {}
  local game = {
    returned = nil,
    stack = {
      items = items,
      top = function(self) return self.items[#self.items] end,
      push = function(self, screen) self.items[#self.items + 1] = screen end,
    },
  }
  if withLauncher ~= false then
    game.returnToLauncher = function(opts) game.returned = opts end
  end
  return game
end

local bus = Events.new()
local savedEvents, savedHooks = Runtime.events, Runtime.hooks
Runtime.events = bus

local function listen()
  local seen = {}
  bus:on("discord.join_requested", function(ev)
    seen[#seen + 1] = ev
  end, 0, "discord_join_test")
  return seen
end

do
  local game = freshGame()
  local st = DiscordPresence._state
  st.game = game
  st.activity = "exploring"
  local seen = listen()

  joined = {}
  DiscordPresence.handleJoinRequest("m:HOST01")
  T.eq(#seen, 1, "match join emits discord.join_requested")
  T.eq(seen[1].code, "HOST01", "payload carries the match code")
  T.eq(seen[1].kind, "m", "payload carries kind tag m")
  T.eq(game.returned and game.returned.tab, "online",
    "a running game returns to the launcher's online tab")
  T.eq(game.returned and game.returned.joinCode, "HOST01",
    "the launcher is handed the code")
  T.eq(#joined, 1, "the online client is asked to join the room")
  T.eq(joined[1].code, "HOST01", "...with the code")
  T.eq(joined[1].as, "player", "...as a player")
  T.eq(game.stack:top(), nil, "no in-game link screen is pushed any more")
  bus:removeOwner("discord_join_test")
end

do
  local st = DiscordPresence._state
  st.game = nil -- the launcher, with no game booted
  st.activity = "menu"
  local seen = listen()

  joined = {}
  DiscordPresence.handleJoinRequest("t:TOUR99")
  T.eq(#seen, 1, "a tournament secret still emits discord.join_requested")
  T.eq(seen[1].kind, "t", "payload carries kind tag t")
  T.eq(joined[1] and joined[1].code, "TOUR99", "it joins that room code")
  bus:removeOwner("discord_join_test")
end

do
  local game = freshGame()
  local st = DiscordPresence._state
  st.game = game
  st.activity = "exploring"
  local seen = listen()

  joined = {}
  DiscordPresence.handleJoinRequest("PLAIN42")
  T.eq(#seen, 1, "plain secret still emits discord.join_requested")
  T.eq(seen[1].kind, "m", "plain secret defaults to match kind")
  T.eq(seen[1].code, "PLAIN42", "plain secret is the whole code")
  T.eq(joined[1] and joined[1].code, "PLAIN42", "and it joins that room")
  bus:removeOwner("discord_join_test")
end

do
  local game = freshGame(false) -- a build with no returnToLauncher
  local st = DiscordPresence._state
  st.game = game
  st.activity = "exploring"
  local seen = listen()

  joined = {}
  DiscordPresence.handleJoinRequest("m:NOWAY")
  T.eq(#seen, 1, "the event still fires so a mod can act on it")
  T.eq(#joined, 0, "a game that cannot reach the launcher joins nothing")
  bus:removeOwner("discord_join_test")
end

do
  local game = freshGame()
  local st = DiscordPresence._state
  st.game = game
  st.activity = "battle"
  local seen = listen()

  joined = {}
  DiscordPresence.handleJoinRequest("m:NOPE")
  T.eq(#seen, 0, "battle activity suppresses join dispatch")
  T.eq(#joined, 0, "battle activity joins no room")
  bus:removeOwner("discord_join_test")
end

do
  local game = freshGame()
  game.stack:push({ stage = true, net = {} }) -- already in a link session
  local st = DiscordPresence._state
  st.game = game
  st.activity = "exploring"
  local seen = listen()

  joined = {}
  DiscordPresence.handleJoinRequest("m:NOPE")
  T.eq(#seen, 0, "active link session suppresses join dispatch")
  T.eq(#joined, 0, "active link session joins no room")
  T.eq(#game.stack.items, 1, "active link session is not replaced")
  bus:removeOwner("discord_join_test")
end

DiscordPresence._state.game = nil
DiscordPresence._state.activity = "menu"
Runtime.events, Runtime.hooks = savedEvents, savedHooks
package.loaded["src.online.Client"] = savedClient

T.finish("discord_join_requested")
