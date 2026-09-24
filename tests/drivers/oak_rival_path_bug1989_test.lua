-- scripts/OaksLab.asm:343-377 + engine/overworld/pathfinding.asm:36-70
-- (approach), scripts/OaksLab.asm:448-472 and :488-508 (exit + watch facing).

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
              or "/tmp/shots"

  local Commands = require("src.script.Commands")
  local origStartBattle = Commands.start_battle
  Commands.start_battle = function(ctx)
    ctx.lastBattleResult = "win"
    ctx.lastCheck = true
    return nil
  end

  local function resetSave()
    local flags = game.save.flags or {}
    game.save.flags = flags
    flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
    flags.EVENT_GOT_STARTER = true
    flags.EVENT_CHOSE_SQUIRTLE = true
    flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = nil
    if game.save.objectToggles and game.save.objectToggles.OAKS_LAB then
      game.save.objectToggles.OAKS_LAB.OAKSLAB_RIVAL = nil
    end
  end

  -- scripts/OaksLab.asm OaksLabRivalTakePokeBallScript leaves him at (ballX,4)
  local function placeRival(cx, cy)
    local r = game.overworld:npcByIndex(1)
    if not r then return nil end
    r.cellX, r.cellY = cx, cy
    r.px, r.py = cx * 16, cy * 16
    r.moving = false
    r.targetX, r.targetY = nil, nil
    return r
  end

  local function scenario(px, side, tag)
    resetSave()
    U.teleport(game, "OAKS_LAB", px, 5, "down")
    U.wait(6)
    local rival = placeRival(7, 4)
    if not rival then U.log(tag, "FAIL no rival object") return false end

    local cells, facings = {}, {}
    local function sample()
      local r = game.overworld:npcByIndex(1)
      if r then
        local last = cells[#cells]
        if not last or last[1] ~= r.cellX or last[2] ~= r.cellY then
          cells[#cells + 1] = { r.cellX, r.cellY }
        end
      end
      local f = game.overworld.player.facing
      if facings[#facings] ~= f then facings[#facings + 1] = f end
    end

    U.shot(game, DIR .. "/" .. tag .. "_before.png")
    local shotApproach, shotSide = false, false
    for _ = 1, 900 do
      sample()
      if (not shotApproach) and #cells >= 2 then
        U.shot(game, DIR .. "/" .. tag .. "_approach.png")
        shotApproach = true
      end
      if (not shotSide) and facings[#facings] == side then
        U.shot(game, DIR .. "/" .. tag .. "_watch.png")
        shotSide = true
      end
      if game.overworld:npcByIndex(1) == nil then break end
      local p = game.overworld.player
      if p and (p.cellY or 0) < 6 then U.hold(game, "down", 8) end
      U.tap(game, "a")
      U.wait(2)
      sample()
    end
    U.wait(6)
    U.shot(game, DIR .. "/" .. tag .. "_end.png")

    local trail = {}
    for _, c in ipairs(cells) do trail[#trail + 1] = c[1] .. "," .. c[2] end
    U.log(tag, "rival trail:", table.concat(trail, " -> "))
    U.log(tag, "player facing:", table.concat(facings, " -> "))

    -- engine/overworld/pathfinding.asm:36-40
    local horizontalFirst = cells[1] and cells[2]
                            and cells[2][2] == cells[1][2]
                            and cells[2][1] < cells[1][1]
    -- scripts/OaksLab.asm:449-462
    local clearedColumn = true
    for _, c in ipairs(cells) do
      if c[2] >= 6 and c[1] == px then clearedColumn = false end
    end
    local watched, wentDown = false, false
    for i, f in ipairs(facings) do
      if f == side then watched = true end
      if watched and f == "down" and i > 1 then wentDown = true end
    end
    local pass = horizontalFirst and clearedColumn and watched and wentDown
    U.log(tag, "horizontalFirst:", tostring(horizontalFirst),
          "clearedColumn:", tostring(clearedColumn),
          "watched(" .. side .. "):", tostring(watched),
          "thenDown:", tostring(wentDown))
    U.log(tag, pass and "PASS" or "FAIL")
    return pass
  end

  local a = scenario(4, "right", "playerx4")
  local b = scenario(5, "left", "playerx5")

  Commands.start_battle = origStartBattle

  U.log("RESULT bug1989_bug1987", (a and b) and "PASS" or "FAIL")
  assert(a, "player at x=4: rival must approach left-first, sidestep RIGHT "
            .. "out of column 4, and the player must turn right then down")
  assert(b, "player at x=5: rival must approach left-first, sidestep LEFT "
            .. "out of column 5, and the player must turn left then down")
end
