--   POKEPORT_IDENTITY=crystal-sep01 POKEPORT_VERSION=crystal \
--   POKEPORT_DRIVER=tests/drivers/crystal_evolution_anim_shots.lua \
--   POKEPORT_SHOT_DIR=/tmp/crystal-evo love .
-- ../pokecrystal/engine/movie/evolution_animation.asm:82-92, :113-130
-- ../pokecrystal/engine/gfx/pic_animation.asm:73
local U = require("tests.drivers.util")

local Evolution = require("src.core.gen2.Evolution")
local EvolutionAnim = require("src.ui.gen2.EvolutionAnim")
local Mon = require("src.battle.gen2.Mon")
local Music = require("src.core.Music")
local Palettes = require("src.world.gen2.Palettes")

local FRAME_LIMIT = 1800

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-evo"
  local species = os.getenv("POKEPORT_EVO_SPECIES") or "CYNDAQUIL"
  local level = tonumber(os.getenv("POKEPORT_EVO_LEVEL") or "16")
  local fails = 0
  local function ok(cond, line)
    if not cond then fails = fails + 1 end
    print("[evoanim] " .. (cond and "PASS " or "FAIL ") .. line)
  end

  U.wait(45)
  assert(game.world and game.world.map, "crystal world did not boot")

  local probe = Mon.new(game.data, species, level)
  local entry = Evolution.checkMon(game.data, probe,
    { timeOfDay = Palettes.clockDaytime() })
  assert(entry, species .. " at " .. level .. " has no evolution")
  local def = game.data.pokemon[entry.into]
  ok(def and def.anim ~= nil,
    entry.into .. " has an anim row in this cache")

  game.save.party = { Mon.new(game.data, species, level) }
  local mapSong = Music.current()
  local finished = nil
  local screen = EvolutionAnim.new(game, {
    mon = game.save.party[1], entry = entry, index = 1,
    party = game.save.party, save = game.save,
    onDone = function(result) finished = result end,
  })
  game.stack:push(screen)

  local first, last, anim = {}, {}, 0
  local musicAt = nil
  local steps = 0
  while not finished and steps < FRAME_LIMIT do
    local phase = screen.phase or "?"
    local now = U.frame()
    first[phase] = first[phase] or now
    last[phase] = now
    local song = Music.current()
    if not musicAt and song and song ~= mapSong then musicAt = now end
    if phase == "picAnim" then
      anim = anim + 1
      U.shot(game, ("%s/anim-%04d.png"):format(out, anim))
    elseif phase ~= "cry" and phase ~= "flash" and steps % 8 == 0 then
      U.shot(game, ("%s/evo-%04d-%s.png"):format(out, steps, phase))
    else
      U.wait(1)
    end
    steps = steps + 1
  end
  U.shot(game, ("%s/evo-end.png"):format(out))
  assert(finished, "the evolution screen never finished")

  -- ../pokecrystal/engine/movie/evolution_animation.asm:85-89
  ok(first.cry ~= nil and musicAt ~= nil and musicAt > first.cry,
    "MUSIC_EVOLUTION starts after the old cry (cry at "
      .. tostring(first.cry) .. ", music at " .. tostring(musicAt) .. ")")
  ok(first.flash ~= nil and musicAt ~= nil
    and first.flash - musicAt >= Evolution.MUSIC_FRAMES - 2,
    "and the 80 DelayFrames are spent after it, not under the cry")

  -- ../pokecrystal/engine/gfx/pic_animation.asm:73
  ok(anim > 1, "ANIM_MON_EVOLVE ran (" .. anim .. " iterations)")
  ok(first.congrats ~= nil and first.picAnim ~= nil
    and first.congrats > last.picAnim,
    "the congratulations page waits for the scene to end")
  ok(game.save.party[1].species == entry.into,
    "the party slot took " .. entry.into)

  print("[evoanim] shots in " .. out)
  print("[evoanim] " .. (fails == 0 and "all claims passed"
    or (fails .. " claims failed")))
  love.event.quit(fails == 0 and 0 or 1)
end
