-- ../pokecrystal/engine/menus/save.asm:209 SaveTheGame_yesorno
local U = require("tests.drivers.util")

local SaveMenu = require("src.ui.gen2.SaveMenu")

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gold-save-prompt"

  U.wait(45)
  assert(game.world and game.world.map, "gold world did not boot")

  local closed = false
  local menu = SaveMenu.new(game, {
    existed = true,
    writer = function() return true end,
    onDone = function()
      closed = true
      game.stack:pop()
    end,
  })
  game.stack:push(menu)

  U.wait(3)
  assert(menu.typer and not menu.typer:done(),
    "confirm question should still be typing")
  assert(not menu:yesNoVisible(), "YES/NO must stay down while typing")
  U.shot(game, out .. "/1-confirm-typing.png")

  for _ = 1, 600 do
    if menu.typer and menu.typer:done() then break end
    U.wait(1)
  end
  U.wait(2)
  assert(menu:yesNoVisible(), "YES/NO should be up after the question")
  U.shot(game, out .. "/2-confirm-done.png")

  U.tap(game, "a")
  U.wait(2)
  assert(menu.phase == "overwrite", "YES should open the overwrite prompt")
  assert(not menu:yesNoVisible(), "overwrite YES/NO must wait for its text")
  U.shot(game, out .. "/3-overwrite-typing.png")

  for _ = 1, 600 do
    if menu.typer and menu.typer:done() then break end
    U.wait(1)
  end
  U.wait(2)
  assert(menu:yesNoVisible(), "overwrite YES/NO should be up after the text")
  U.shot(game, out .. "/4-overwrite-done.png")

  U.tap(game, "b")
  U.wait(5)
  assert(closed, "B should close the save menu without saving")

  print("[driver] PASS gold save prompt shots in " .. out)
end
