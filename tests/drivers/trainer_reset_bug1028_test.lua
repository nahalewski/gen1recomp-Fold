-- Driver: a trainer who walked up to the player must be back on her spawn
-- cell the next time her map loads, connection crossings included (#1028).
-- .loadNewMap calls LoadMapHeader for a seam crossing exactly as a warp does,
-- and .loadSpriteData zeroes the sprite state data and re-seeds every
-- SPRITESTATEDATA2_MAPY/MAPX from the map header's object data
-- (pokered home/overworld.asm), so only the save-side defeat flag survives.
--
-- Route 3's Lass (data/maps/objects/Route3.asm object_event 23, 4,
-- SPRITE_COOLTRAINER_F, STAY, LEFT, ..., OPP_LASS) has sight range 4, so
-- standing above the third Bug Catcher at (19,4) is inside her line and she
-- walks dist-1 = 3 cells west to (20,4) -- the reporter's exact setup.
--
-- POKEPORT_DRIVER=tests/drivers/trainer_reset_bug1028_test.lua \
--   POKEPORT_IDENTITY=bug1028 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Zoom = require("src.render.Zoom")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local MAP = "ROUTE_3"
  local TARGET = 6
  local SPAWN = { x = 23, y = 4 }
  local STAND = { x = 19, y = 4 }

  local pass = true
  local function check(label, ok)
    if not ok then pass = false end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local function lass()
    local ow = game.overworld
    for _, n in ipairs(ow and ow.npcs or {}) do
      if n.def and n.def.index == TARGET then return n end
    end
    return nil
  end

  local function at(n) return n and (n.cellX .. "," .. n.cellY) or "absent" end

  -- hold a direction until cond() or the budget runs out, then let the
  -- half-finished step land
  local function holdUntil(btn, cond, budget)
    local first = true
    for _ = 1, budget or 900 do
      if cond() then break end
      if first then table.insert(game.input.pressQueue, btn); first = false end
      game.input.state[btn] = true
      coroutine.yield()
    end
    game.input.state[btn] = false
    for _ = 1, 40 do
      local ow = game.overworld
      if ow and not ow.player.moving then break end
      coroutine.yield()
    end
    U.wait(4)
    return cond()
  end

  local function walkTo(btn, axis, want, budget)
    return holdUntil(btn, function()
      local p = game.overworld and game.overworld.player
      return p and p[axis] == want and not p.moving
    end, budget)
  end

  local function onMap(id)
    return game.overworld and game.overworld.map and game.overworld.map.id == id
  end

  -- mash A until the battle stack unwinds back to the overworld
  local function mashToOverworld(budget)
    for _ = 1, budget or 4000 do
      if game.stack:top() == game.overworld and not game.overworld.engaging then
        return true
      end
      U.tap(game, "a")
      U.wait(3)
    end
    return false
  end

  -- absolute zoom: reset first so every shot frames the same amount of world
  local function survey(n)
    Zoom.reset()
    U.wait(2)
    for _ = 1, n do game:zoomStep(-1) end
    U.wait(30)
  end

  -- back up to the sighting cell so the before/after shots share a camera
  local function returnToStand()
    walkTo("right", "cellX", 11)
    walkTo("up", "cellY", 4)
    walkTo("right", "cellX", STAND.x)
  end

  game.save.party = {
    Pokemon.new(game.data, "CHARIZARD", 80),
    Pokemon.new(game.data, "SNORLAX", 80),
  }
  game.save.player.name = "MATT"

  U.teleport(game, MAP, STAND.x, STAND.y, "right")
  U.wait(20)

  -- only the target Lass may engage: the reporter has already cleared the
  -- Bug Catchers and Youngsters ahead of her
  local ow = game.overworld
  for _, n in ipairs(ow.npcs) do
    if n.def.trainerClass and n.def.index ~= TARGET then
      game.save.defeatedTrainers[n.id] = true
    end
  end

  local l = lass()
  check("Lass starts on her spawn cell " .. SPAWN.x .. "," .. SPAWN.y,
        l ~= nil and l.cellX == SPAWN.x and l.cellY == SPAWN.y)
  U.log("spawn:", at(l))

  -- she sights the player and walks up, then the battle runs
  for _ = 1, 600 do
    if ow.engaging then break end
    coroutine.yield()
  end
  check("the Lass sighted the player at " .. STAND.x .. "," .. STAND.y, ow.engaging == true)
  check("the battle ran to completion", mashToOverworld())
  U.wait(30)

  l = lass()
  local movedX, movedY = l and l.cellX, l and l.cellY
  U.log("after the walk-up she stands at", at(l))
  check("she is off her spawn cell after walking up",
        l ~= nil and not (movedX == SPAWN.x and movedY == SPAWN.y))
  check("she is recorded as defeated", game.save.defeatedTrainers[l.id] == true)

  survey(4)
  U.shot(game, DIR .. "/bug1028_1_walked_up.png")
  Zoom.reset()
  U.wait(5)

  -- west along row 4, down the single gap at column 11, then west on row 9
  -- to the Pewter City seam
  walkTo("left", "cellX", 11)
  walkTo("down", "cellY", 9)
  check("reached the descent column", game.overworld.player.cellX == 11
        and game.overworld.player.cellY == 9)

  -- crossing x=0 westward is the seam: crossConnection, not a warp
  holdUntil("left", function() return onMap("PEWTER_CITY") end, 1200)
  check("crossed the seam into Pewter City", onMap("PEWTER_CITY"))

  survey(12)
  U.shot(game, DIR .. "/bug1028_2_pewter_survey.png")
  Zoom.reset()
  U.wait(5)

  -- and back east into Route 3, the map load that must re-seed her
  holdUntil("right", function() return onMap(MAP) end, 1200)
  check("crossed back into Route 3", onMap(MAP))
  U.wait(30)

  l = lass()
  U.log("after the return crossing she stands at", at(l))
  check("she is back on her spawn cell " .. SPAWN.x .. "," .. SPAWN.y,
        l ~= nil and l.cellX == SPAWN.x and l.cellY == SPAWN.y)
  check("she is still recorded as defeated",
        l ~= nil and game.save.defeatedTrainers[l.id] == true)

  -- same cell, same zoom as shot 1: she should now be three cells further
  -- east, and being defeated she must not re-engage on the way back in
  returnToStand()
  check("walked back to the sighting cell",
        game.overworld.player.cellX == STAND.x
        and game.overworld.player.cellY == STAND.y)
  check("a defeated trainer does not re-engage", game.overworld.engaging ~= true)

  survey(4)
  U.shot(game, DIR .. "/bug1028_3_reset.png")

  Zoom.reset()
  U.log(pass and "RESULT PASS" or "RESULT FAIL")
  love.event.quit(pass and 0 or 1)
  while true do coroutine.yield() end
end
