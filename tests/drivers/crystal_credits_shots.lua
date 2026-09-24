-- ../pokecrystal/engine/movie/credits.asm:400-451
local U = require("tests.drivers.util")

local Credits = require("src.ui.gen2.Credits")

local INTERVAL = 60
local LIMIT = 8000

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/crystal-credits"

  U.wait(45)
  assert(game.world and game.world.map, "crystal world did not boot")

  local rolled = false
  local credits = Credits.new(game, {
    allowSkip = true,
    onDone = function() rolled = true end,
  })
  game.stack:clear()
  game.stack:push(credits)

  local banner, strips, field = credits:palettes()
  U.log(("palettes: banner %s strips %s field %s"):format(
    table.concat(banner[1], ","), table.concat(strips[1], ","),
    table.concat(field[1], ",")))
  U.log(("layout: banners %d, strips %s, theEnd row %d"):format(
    #Credits.layout().bannerRows,
    table.concat(Credits.layout().borderRows, "/"),
    Credits.layout().theEndY))

  local shots, scene = 0, -1
  while not credits.exiting and credits.frames < LIMIT do
    U.wait(INTERVAL)
    if credits.scene ~= scene then
      scene = credits.scene
      U.log(("credits scene %d at frame %d (pass %d, pos %d)")
        :format(scene, credits.frames, credits.passes, credits.pos))
    end
    U.shot(game, ("%s/credits-%04d-scene%d.png")
      :format(out, credits.frames, scene))
    shots = shots + 1
  end
  assert(credits.exiting, "the credits script never reached CREDITS_END")
  U.wait(30)
  U.shot(game, ("%s/credits-%04d-theend.png"):format(out, credits.frames))
  U.log(("%d credits shots over %d frames, %d passes")
    :format(shots + 1, credits.frames, credits.passes))
  U.tap(game, "a")
  U.wait(10)
  assert(rolled, "A did not leave the credits once the exit flag was up")
  game.stack:clear()
end
