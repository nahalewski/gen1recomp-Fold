-- engine/menus/naming_screen.asm:84
-- "NICKNAME?" at hlcoord 1,3.  No POKEPORT_SPEED: the icon's two frames
--   POKEPORT_DRIVER=tests/drivers/naming_screen_bug1947_test.lua POKEPORT_IDENTITY=red-aug28 POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Pokemon = require("src.pokemon.Pokemon")
  local Strings = require("src.core.Strings")
  local NamingScreen = require("src.ui.NamingScreen")

  local SHOT_DIR = os.getenv("POKEPORT_SHOT_DIR") or os.getenv("SHOT_DIR")
    or "/tmp/shots"
  local ok = true
  local function check(label, pass)
    U.log(pass and "PASS" or "FAIL", label)
    if not pass then ok = false end
    return pass
  end

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  game.save.player.name = "RED"
  U.wait(10)

  local function typeABC()
    U.tap(game, "a")
    U.wait(4)
    U.tap(game, "right")
    U.wait(4)
    U.tap(game, "a")
    U.wait(4)
    U.tap(game, "right")
    U.wait(4)
    U.tap(game, "a")
    U.wait(20)
  end

  local function run(label, file, opts)
    local done = false
    opts.onDone = function() done = true end
    Screens.push(game, "NamingScreen", opts)
    U.wait(20)
    local screen = game.stack:top()
    check(label .. ": screen is up", getmetatable(screen) == NamingScreen)
    typeABC()
    check(label .. ": three glyphs typed", #screen.glyphs == 3)
    check(label .. ": shot " .. file, U.shot(game, SHOT_DIR .. "/" .. file))
    U.tap(game, "start")
    U.wait(20)
    check(label .. ": confirmed and popped", done)
  end

  run("player", "naming-player.png",
      { title = Strings("YOUR NAME?"), maxLen = 7 })
  run("rival", "naming-rival.png",
      { title = Strings("RIVAL's NAME?"), maxLen = 7 })

  local mon = Pokemon.new(game.data, "CHARMANDER", 5)
  run("nickname", "naming-nickname.png",
      { title = Strings("NICKNAME?"), maxLen = 10, mon = mon })

  if ok then
    U.log("three shots in " .. SHOT_DIR .. ": naming-player.png,")
    U.log("naming-rival.png, naming-nickname.png. in every one the letter grid")
    U.log("sits INSIDE a drawn box whose top edge is the fifth tile row, the")
    U.log("typed ABC is on its own row with a full row of underscores beneath")
    U.log("it, and the underscore under the next free slot is raised a few")
    U.log("pixels above the others -- one row of hyphens with letters written")
    U.log("over them is the old bug.")
    U.log("naming-player.png reads YOUR NAME?; naming-rival.png reads")
    U.log("RIVAL's NAME? with the 's as one glyph -- HIS NAME? is the old bug.")
    U.log("naming-nickname.png has an animated CHARMANDER icon in the top left")
    U.log("with CHARMANDER beside it, and NICKNAME? sits on the underscore row")
    U.log("immediately left of the name, not up on the title row.")
    U.log("the nickname screen is still up; watch the icon flip frames.")
  else
    U.log("a check above failed, so nothing on screen is worth reading yet.")
  end

  Screens.push(game, "NamingScreen",
    { title = Strings("NICKNAME?"), maxLen = 10, mon = mon,
      onDone = function() end })

  while true do
    coroutine.yield()
  end
end
