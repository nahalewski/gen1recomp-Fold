-- Eye/ear check on the Pokemon Tower 6F ghost scene (#1849): entry wipe,
-- the "GHOST appeared!" wording, the SILPH SCOPE unveil colours, and the
-- cry landing on the CUBONE's-mother line.
-- pokered engine/battle/core.asm:6695-6702, data/text/text_2.asm:1251-1255,
-- engine/battle/ghost_marowak_anim.asm:3-5,77, scripts/PokemonTower6F.asm:137-148.
--   POKEPORT_DRIVER=tests/drivers/ghost_marowak_bug1849_test.lua POKEPORT_IDENTITY=bug1849 POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  -- PokemonTower6FMarowakCoords (scripts/PokemonTower6F.asm:43-45) is
  -- (10, 16); the 7F stairs at (9, 16) sit right beside it, so the cell
  -- north of the trigger is open floor.
  local MAP = "POKEMON_TOWER_6F"
  local TRIGGER = { x = 10, y = 16 }
  local STAND = { x = 10, y = 15, facing = "down" }

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local opts = game.save.options or {}
  local sfxVol = opts.sfxVol or 7
  if sfxVol == 0 then
    U.log("FAIL sfx volume is 0: the MAROWAK cry is the audible half of this")
    U.log("     check and will not be heard. Set SFX to 7 in OPTION first.")
  end
  check(("sfx volume %d"):format(sfxVol), sfxVol > 0)

  game.save.party = { Pokemon.new(game.data, "CHARMANDER", 40) }
  game.save.inventory = game.save.inventory or {}
  game.save.inventory.SILPH_SCOPE = 1
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_GHOST_MAROWAK = nil
  check("the SILPH SCOPE is in the bag (this is the unveil path)",
        (game.save.inventory.SILPH_SCOPE or 0) > 0)

  U.teleport(game, MAP, STAND.x, STAND.y, STAND.facing)
  U.wait(20)
  local ow = game.overworld
  check("standing on " .. MAP, ow.map.id == MAP)
  if not ow.map:isWalkableCell(STAND.x, STAND.y) then
    -- a map edit moved the floor: take any free neighbour of the trigger
    for _, d in ipairs({ { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
      local cx, cy = TRIGGER.x + d[1], TRIGGER.y + d[2]
      if ow.map:isWalkableCell(cx, cy) and not ow:npcAtCell(cx, cy) then
        local facing = (d[2] == -1 and "down") or (d[2] == 1 and "up")
                       or (d[1] == -1 and "right") or "left"
        U.log(("(%d, %d) is blocked, standing on"):format(STAND.x, STAND.y),
              cx, cy, "facing", facing)
        U.teleport(game, MAP, cx, cy, facing)
        U.wait(20)
        ow = game.overworld
        break
      end
    end
  end

  -- walk onto the trigger cell ourselves; the Be gone... box opens on arrival
  local BattleTransition = require("src.render.BattleTransition")
  local sawWipe = false
  local battle
  for _ = 1, 240 do
    U.hold(game, "down", 2)
    U.tap(game, "a")
    U.wait(4)
    local top = game.stack:top()
    if getmetatable(top) == BattleTransition then
      sawWipe = true
      U.shot(game, DIR .. "/bug1849_entry_wipe.png")
    end
    if getmetatable(top) == BattleState then
      battle = top
      break
    end
  end
  check("the ghost battle started", battle ~= nil)
  check("an entry wipe ran before it (pushBattle, not a bare stack push)",
        sawWipe)

  if battle then
    check("the foe is disguised as the GHOST", battle.enemy.name == "GHOST")
    U.log("intro line reads:", (tostring(battle.introText):gsub("\n", " / ")))
    check("the intro line is \"GHOST appeared!\", with no article",
          battle.introText == "GHOST\nappeared!")
    check("the scope unveil is queued", battle.scopeReveal == true)

    -- ride the unveil: mash A through the boxes and shoot the anim
    local shotFlash, shotFade, shotDone = false, false, false
    for _ = 1, 900 do
      U.tap(game, "a")
      U.wait(2)
      local gr = battle.ghostReveal
      if gr then
        if not shotFlash and gr.t >= 20 then
          shotFlash = true
          U.shot(game, DIR .. "/bug1849_unveil_flash.png")
        end
        if not shotFade and gr.t >= 100 then
          shotFade = true
          U.shot(game, DIR .. "/bug1849_unveil_fadein.png")
        end
      elseif shotFade and not shotDone then
        shotDone = true
        U.shot(game, DIR .. "/bug1849_unveiled.png")
        break
      end
    end
    check("the unveil animation played", shotFlash and shotFade)
    check("the real name came back: " .. tostring(battle.enemy.name),
          battle.enemy.name ~= "GHOST")
  end

  U.log("Shots are in " .. DIR .. ": bug1849_entry_wipe, _unveil_flash,")
  U.log("_unveil_fadein, _unveiled.png. In OG RED mode MarowakAnim draws the")
  U.log("pic as a sprite under OBJ palette 1, so the flashing ghost and the")
  U.log("fading-in MAROWAK are green (pink in Blue) and only settle back to")
  U.log("the red background palette once the animation ends. The near-miss is")
  U.log("a pic that stays red the whole way through.")
  U.log("Beat the MAROWAK and listen: the cry belongs on the CUBONE's-mother")
  U.log("box, not on the one after it.")

  while true do
    coroutine.yield()
  end
end
