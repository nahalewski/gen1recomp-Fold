-- Driver: boots straight into an online arena battle (POKEPORT_ARENA_SPEC),
-- plays it against an in-process headless guest over Net.loopbackPair, and
-- screenshots the battle and the launcher the arena returns to.
--
--   SHOT_DIR=/tmp/shots POKEPORT_ARENA_SPEC=tests/drivers/arena_boot_spec.lua \
--     POKEPORT_DRIVER=tests/drivers/arena_boot_loopback.lua love .

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
  if not (arena and arena.screenId == "ArenaState") then
    U.log("FAIL the game did not boot into ArenaState")
    love.event.quit(1)
    return
  end
  if arena.stage ~= "running" then
    U.log("FAIL the arena battle did not construct")
    love.event.quit(1)
    return
  end

  local shots = {
    [60] = DIR .. "/arena_0_battle.png",
    [400] = DIR .. "/arena_1_turns.png",
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
    return ok
  end

  local baseDraw = love.draw
  local launcherShot, launcherFrames = false, 0
  love.draw = function()
    baseDraw()
    if ctx.result and not launcherShot then
      launcherFrames = launcherFrames + 1
      if launcherFrames > 45 then
        launcherShot = true
        love.graphics.captureScreenshot(function(imagedata)
          local encoded = imagedata:encode("png")
          local path = DIR .. "/arena_2_launcher.png"
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

  local LinkBattle = require("src.link.LinkBattle")
  local SaveData = require("src.core.SaveData")

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
  function guestStack:update(dt)
    local top = self:top()
    if top and top.update then top:update(dt) end
  end

  local guestGame = {
    data = game.data,
    input = guestInput,
    stack = guestStack,
    save = SaveData.newGame(),
  }
  local guest, why = LinkBattle.newGuest(guestGame, ctx.guestNet, {
    myParty = ctx.guestParty,
    theirParty = ctx.hostParty,
    theirName = "RED",
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

  for step = 1, 8000 do
    table.insert(game.input.pressQueue, "a")
    guestStack:update(1 / 60)
    if shots[step] then game.capturePath = shots[step] end
    coroutine.yield()
    if ctx.result then break end
  end

  if not ctx.result then
    U.log("FAIL the arena battle never finished")
    love.event.quit(1)
    return
  end

  while true do
    coroutine.yield()
  end
end
