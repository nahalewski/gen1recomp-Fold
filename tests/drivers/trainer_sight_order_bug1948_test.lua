-- engine/overworld/emotion_bubbles.asm:18
-- engine/battle/battle_transitions.asm:28
--   POKEPORT_DRIVER=tests/drivers/trainer_sight_order_bug1948_test.lua \
--   POKEPORT_IDENTITY=red-aug28 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
              or "/tmp/shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local BattleTransition = require("src.render.BattleTransition")
  local PaletteFX = require("src.render.PaletteFX")
  local SpriteRenderer = require("src.render.SpriteRenderer")

  local function check(label, ok)
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  game.save.player.name = "bryan"
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 50) }

  U.teleport(game, "PALLET_TOWN", 3, 7, "down")
  U.wait(30)
  local ow = game.overworld
  check("overworld is up", ow ~= nil)
  if not ow then while true do coroutine.yield() end end

  local npc
  for _, e in ipairs(ow.entities) do
    if e ~= ow.player then npc = e break end
  end
  check("found an NPC on PALLET_TOWN to stand in for the trainer", npc ~= nil)

  local savedMode = PaletteFX.mode
  for _, mode in ipairs({ "gbc", "ogred" }) do
    PaletteFX.setMode(mode)
    ow.emote = { npc = npc or ow.player, frames = 600, bubble = 1 }
    U.wait(6)
    local path = DIR .. "/bug1948_emote_" .. mode .. ".png"
    check("emote shot reached disk: " .. mode, U.shot(game, path))
    U.log("captured", path, "-- the \"!\" must sit ON TOP of the player")
  end
  ow.emote = nil
  PaletteFX.setMode(savedMode)
  U.wait(6)

  local battle = BattleState.newTrainer(game, "OPP_YOUNGSTER", 1)
  battle.onFinish = function() end
  ow:pushBattle(battle, npc)
  local tr = game.stack:top()
  check("a BattleTransition was pushed", getmetatable(tr) == BattleTransition)
  check("the engaged NPC is the kept OAM block", ow.battleOamKeep == npc)
  if tr.wipeLen then tr.wipeLen = 240 end

  local function replayRecord()
    local cv = love.graphics.newCanvas(160, 144)
    love.graphics.setCanvas(cv)
    PaletteFX.clearSpriteRedraws()
    local ok = pcall(function() ow:drawWipeSprites() end)
    love.graphics.setCanvas()
    local recs = PaletteFX.spriteRedraws()
    return ok, recs[#recs]
  end

  local shots = 0
  for _ = 1, 900 do
    if game.stack:top() ~= tr then break end
    local w = game.renderer and game.renderer.battleWipe
    local prog = w and w.prog or 0
    if prog > 0.25 and shots == 0 then
      shots = 1
      check("wipe shot 1 reached disk",
            U.shot(game, DIR .. "/bug1948_wipe_25.png"))
    elseif prog > 0.55 and shots == 1 then
      shots = 2
      check("wipe shot 2 reached disk",
            U.shot(game, DIR .. "/bug1948_wipe_55.png"))
      PaletteFX.setMode("ogred")
      U.wait(2)
      check("ogred wipe shot reached disk",
            U.shot(game, DIR .. "/bug1948_wipe_ogred.png"))
      local ok, last = replayRecord()
      local sp = ow.player.sprite
      local want = SpriteRenderer.obpImage(sp.def.image, PaletteFX.ogObj())
      local dmg = SpriteRenderer.obpImage(sp.def.image, PaletteFX.dmgObj())
      check("the ogred wipe replay queued a redraw", ok and last ~= nil)
      check("the replayed survivor is the ogObj bake, not the DMG bake",
            last ~= nil and last.image == want and want ~= dmg)
      PaletteFX.setMode(savedMode)
      U.wait(2)
    elseif prog > 0.85 and shots == 2 then
      shots = 3
      check("wipe shot 3 reached disk",
            U.shot(game, DIR .. "/bug1948_wipe_85.png"))
    elseif prog >= 1 and shots == 3 then
      shots = 4
      check("black shot reached disk",
            U.shot(game, DIR .. "/bug1948_wipe_black.png"))
    end
    U.wait(1)
  end
  check("all four wipe frames were captured", shots == 4)

  U.log("bug1948_wipe_25/55/85.png: the player and the one NPC must still be")
  U.log("visible over the black tiles; EVERY other NPC must already be gone.")
  U.log("bug1948_wipe_ogred.png: the same two survivors in OG RED boot-ROM")
  U.log("green, NOT DMG gray.")
  U.log("bug1948_wipe_black.png: solid black, nobody left.")

  while true do
    coroutine.yield()
  end
end
