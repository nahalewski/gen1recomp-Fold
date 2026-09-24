-- ../pokecrystal/home/print_text.asm:1 PrintLetterDelay (#2046)
local U = require("tests.drivers.util")

local POKECENTER = os.getenv("POKEPORT_PC_MAP") or "CHERRYGROVE_POKECENTER_1F"
local COLL_PC = 0x93

return function(game)
  local out = os.getenv("POKEPORT_SHOT_DIR") or "/tmp/gen2-text-speed"
  local failed = 0

  local function pass(ok, line)
    if not ok then failed = failed + 1 end
    U.log((ok and "PASS " or "FAIL ") .. line)
  end

  local function tap(btn, frames)
    U.tap(game, btn)
    U.wait(frames or 6)
  end

  local function shown()
    local top = game.stack:top()
    local typer = top and top.typer
    if not typer then return nil end
    return typer.shown, typer.total
  end

  U.wait(45)
  local world = game.world
  assert(world and world.map, "gen2 world did not boot")

  game.save.options = game.save.options or {}
  game.save.options.textSpeed = "SLOW"

  local Mon = require("src.battle.gen2.Mon")
  game.save.party = { Mon.new(game.data, "CYNDAQUIL", 10) }

  world:warpToMapId(POKECENTER, 4, 4, "up")
  U.wait(20)
  local pcX, pcY
  for cy = 0, world.map.heightCells - 1 do
    for cx = 0, world.map.widthCells - 1 do
      if world.map:cellCollision(cx, cy) == COLL_PC then pcX, pcY = cx, cy end
    end
  end
  assert(pcX, "no COLL_PC tile on " .. POKECENTER)
  world:warpToMapId(POKECENTER, pcX, pcY + 1, "up")
  U.wait(20)

  U.tap(game, "a")
  U.wait(2)
  local top = game.stack:top()
  pass(top ~= nil and top.screenId == "Gen2CenterPcMenu",
    "the PC opened (top: " .. tostring(top and top.screenId) .. ")")

  U.wait(10)
  local a = shown()
  U.shot(game, out .. "/01-typing-early.png")
  U.wait(30)
  local b = shown()
  U.shot(game, out .. "/02-typing-later.png")
  pass(a ~= nil and b ~= nil and b > a,
    ("the turn-on line is still filling in (%s -> %s glyphs)")
      :format(tostring(a), tostring(b)))

  -- ../pokecrystal/home/print_text.asm:59
  U.tap(game, "a")
  U.wait(2)
  local p, ptotal = shown()
  pass(p ~= nil and ptotal ~= nil and p < ptotal,
    ("A mid-line does not dump the page (%s of %s glyphs)")
      :format(tostring(p), tostring(ptotal)))
  U.shot(game, out .. "/02b-press-mid-line.png")

  U.wait(120)
  local c, total = shown()
  pass(c ~= nil and total ~= nil and c == total,
    "and it finishes on its own at SLOW")
  U.shot(game, out .. "/03-typed.png")

  U.log("01/02: the same page part-printed at two different lengths -- proof")
  U.log("the OPTION text speed reaches the PC box. 03: the whole line, with")
  U.log("the Pokecenter still drawn behind it.")

  tap("a", 10)
  U.log("04-whose-pc: 'Access whose PC?' is PC_DisplayTextWaitMenu, which sets")
  U.log("NO_TEXT_SCROLL -- this one is meant to be instant.")
  U.shot(game, out .. "/04-whose-pc.png")

  U.log(("%d check(s) failed"):format(failed))

  while true do coroutine.yield() end
end
