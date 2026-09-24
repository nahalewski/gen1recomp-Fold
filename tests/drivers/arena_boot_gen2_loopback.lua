-- Driver: boots Gold straight into an online arena battle
-- (POKEPORT_ARENA_SPEC), plays it against an in-process headless guest over
-- Net.loopbackPair, and screenshots the battle and the launcher the arena
-- returns to.  The Gen 2 peer of tests/drivers/arena_boot_loopback.lua.
--
--   SHOT_DIR=/tmp/shots POKEPORT_TOUCH=0 POKEPORT_VERSION=gold \
--     POKEPORT_IDENTITY=<a sandbox holding a gold cache> POKEPORT_SPEED=10 \
--     POKEPORT_ARENA_SPEC=tests/drivers/arena_boot_gen2_spec.lua \
--     POKEPORT_DRIVER=tests/drivers/arena_boot_gen2_loopback.lua love .
--
-- POKEPORT_SPEED matters here: the headless guest takes that many fixed steps
-- per rendered frame, and it is the pacing side of the lockstep, so at 1 the
-- match runs at a fraction of real speed.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"
  os.execute('mkdir -p "' .. DIR .. '" 2>/dev/null')

  local ctx = _G.POKEPORT_ARENA_TEST
  if not ctx then
    U.log("FAIL POKEPORT_ARENA_SPEC did not run (no loopback context)")
    love.event.quit(1)
    return
  end

  local arena = game.stack.states[1]
  U.log("arena state:", tostring(arena and arena.screenId),
        "stage:", tostring(arena and arena.stage))
  if not (arena and arena.screenId == "Gen2ArenaState") then
    U.log("FAIL the game did not boot into the Gen 2 ArenaState")
    love.event.quit(1)
    return
  end
  if arena.stage ~= "running" then
    U.log("FAIL the arena battle did not construct:", tostring(arena.message))
    love.event.quit(1)
    return
  end

  local shots = {
    [90] = DIR .. "/arena2_0_battle.png",
    [400] = DIR .. "/arena2_1_turns.png",
  }

  local function verify()
    local ok = true
    for _, path in pairs(shots) do
      local f = io.open(path, "rb")
      if f then
        f:close()
        U.log("captured", path)
      else
        ok = false
        U.log("FAIL screenshot did not reach disk:", path)
      end
    end
    U.log("arena finished: host result", tostring(ctx.result),
          "guest result", tostring(ctx.guestResult))
    if ctx.result ~= "win" and ctx.result ~= "lose" and ctx.result ~= "draw" then
      ok = false
      U.log("FAIL the arena reported no battle result")
    end
    if ctx.result == "win" and ctx.guestResult ~= "lose" then ok = false end
    if ctx.result == "lose" and ctx.guestResult ~= "win" then ok = false end
    if not ok then U.log("FAIL the two sides disagree on the outcome") end
    return ok
  end

  local baseDraw = love.draw
  local launcherShot, launcherFrames = false, 0
  love.draw = function()
    baseDraw()
    -- ctx.readyForShot: the guest finished too (or ran out of grace), so the
    -- launcher behind the arena is settled and both results can be compared.
    if ctx.readyForShot and not launcherShot then
      launcherFrames = launcherFrames + 1
      if launcherFrames > 45 then
        launcherShot = true
        love.graphics.captureScreenshot(function(imagedata)
          local encoded = imagedata:encode("png")
          local path = DIR .. "/arena2_2_launcher.png"
          local f = io.open(path, "wb")
          if f then
            f:write(encoded:getString())
            f:close()
            U.log("captured", path)
          else
            U.log("FAIL screenshot did not reach disk:", path)
          end
          love.event.quit(verify() and 0 or 1)
        end)
      end
    end
  end

  local LinkBattle2 = require("src.link.LinkBattle2")

  -- The guest has no window: a bare pad, a bare stack and no save of its own,
  -- which is everything src/ui/gen2/BattleState.lua asks a game for.
  local guestInput = {
    pressed = { a = true },
    state = {},
    pressQueue = {},
    wasPressed = function(_, button) return button == "a" end,
    isDown = function() return false end,
    step = function() end,
  }
  local guestStack = { list = {} }
  function guestStack:push(state, ...)
    table.insert(self.list, state)
    if state.enter then state:enter(...) end
  end
  function guestStack:pop() return table.remove(self.list) end
  function guestStack:top() return self.list[#self.list] end
  function guestStack:clear() self.list = {} end
  function guestStack:update(dt)
    local top = self:top()
    if top and top.update then top:update(dt) end
  end

  local guestGame = {
    data = game.data,
    input = guestInput,
    stack = guestStack,
    options = {},
    save = { party = {}, player = { name = "SILVER" }, inventory = {},
             pokedex = { seen = {}, caught = {} } },
  }
  local guest, why = LinkBattle2.newGuest(guestGame, ctx.guestNet, {
    myParty = ctx.guestParty,
    theirParty = ctx.hostParty or (arena.spec and arena.spec.myParty),
    theirName = "GOLD",
    seed = ctx.seed,
    verdict = "full",
    strict = true,
    keepNetOpen = true,
  })
  if not guest then
    U.log("FAIL headless guest could not start:", tostring(why))
    love.event.quit(1)
    return
  end
  guest.onFinish = function(result) ctx.guestResult = result end
  guestStack:push(guest)
  U.log("headless guest running")

  -- The guest runs several fixed steps per rendered frame: it is the pacing
  -- side of the lockstep (the host waits for its action), so at one step a
  -- frame the whole match would crawl at half real speed.
  local GUEST_STEPS = tonumber(os.getenv("POKEPORT_SPEED")) or 6
  for step = 1, 6000 do
    table.insert(game.input.pressQueue, "a")
    for _ = 1, GUEST_STEPS do guestStack:update(1 / 60) end
    if shots[step] then game.capturePath = shots[step] end
    coroutine.yield()
    if ctx.result then break end
  end

  if not ctx.result then
    U.log("FAIL the arena battle never finished")
    love.event.quit(1)
    return
  end

  -- The host reports the moment its own screen pops; the guest is still
  -- draining the last of its message queue, so give it its own frames rather
  -- than reading a result it has not written yet.
  for _ = 1, 600 do
    if ctx.guestResult then break end
    for _ = 1, GUEST_STEPS do guestStack:update(1 / 60) end
    coroutine.yield()
  end
  ctx.readyForShot = true

  while true do
    coroutine.yield()
  end
end
