-- ../pokecrystal/home/map.asm:1910-1940
-- ../pokecrystal/engine/menus/start_menu.asm:444-518

package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or require("tests.love_stub")

local T = require("tests.harness")
local eq, check = T.eq, T.check
local MenuFade = require("src.ui.gen2.MenuFade")
local World = require("src.world.gen2.World")
local StateStack = require("src.core.StateStack")
local Game2 = require("src.core.Game2")

local function newStack()
  local stack = setmetatable({}, { __index = StateStack })
  stack:init()
  return stack
end

do
  eq(MenuFade.OUT_FRAMES, 8,
    "FadeToMenu -> FadeOutToWhite: 4 entries x DelayFrames 2 = 8")
  eq(MenuFade.OUT_WHITE_FRAMES, 2,
    "of which entry 6 (every index -> colour 0, white) is the last 2")
  eq(MenuFade.IN_RAMP_FRAMES, 6,
    "FadeInFromWhite entries 5, 4, 3 at 2 frames each after the white")
  eq(MenuFade.PARTY_FONT_FRAMES, 3,
    "LoadPartyMenuGFX -> _LoadFontsBattleExtra: Get2bppViaHDMA 25 tiles then"
      .. " LoadFrame's 6 and 1, one DelayFrame each with the LCD on")
  eq(MenuFade.PARTY_WHITE, 11,
    "StartMenu_Pokemon: .choosemenu ClearBGPalettes 4 + the font's 3"
      .. " + WaitBGMap 4 = 11; the DelayFrame at :518 is the colour latch")
  eq(MenuFade.PARTY_ICON_FRAMES, 3,
    "InitPartyMenuGFX: GetIconGFX 8 tiles 2 + HeldItemIcons 2 tiles 1 per mon")
  eq(MenuFade.openWhite("pokemon", 6), 11 + 18, "six mons: 29")
  eq(MenuFade.PACK_WHITE, 16,
    "Pack_InitGFX: ClearBGPalettes 4 + ClearTilemap 4 + LCD off 2"
      .. " + DrawPackGFX 15 tiles 2 + Pack_InitColors WaitBGMap 4 = 16")
  eq(MenuFade.GEAR_WHITE, 20,
    "PokeGear.InitTilemap: ClearBGPalettes 4 + ClearTilemap 4 + LCD off 5"
      .. " + InitPokegearTilemap.UpdateBGMap 3 + 4 = 20")
  eq(MenuFade.CARD_WHITE, 14,
    "TrainerCard.InitRAM: ClearBGPalettes 4 + ClearTilemap 4 + LCD off 2"
      .. " + WaitBGMap 4 = 14; the second WaitBGMap latches the colour")
  eq(MenuFade.DEX_WHITE, 27,
    "InitPokedex: ClearBGPalettes 4 + ClearTilemap 4 + LCD off 6 + DelayFrame 1"
      .. " + SetBGMapMode 4 then 3 for 8 + WaitBGMap 4 = 27")
  eq(MenuFade.OPTION_WHITE, 8, "_Option: ClearBGPalettes 4 + WaitBGMap 4 = 8")
  eq(MenuFade.openWhite("save"), nil, "SAVE draws over the map, no fade")
  eq(MenuFade.openWhite("mods"), nil, "and MODS is not a cart page")
  eq(MenuFade.exitWhite(), World.MENU_EXIT_WHITE_FRAMES,
    "CloseSubmenu shares ExitAllMenus' count")
  eq(MenuFade.closeWhite("pack"), 23,
    "CloseSubmenu: ClearBGPalettes 4 + reload 9 + WaitBGMap2 8 + entry 6 for 2")
  eq(MenuFade.closeWhite("pokegear"), 27,
    "PokeGear.done's own ClearBGPalettes 4 ahead of CloseSubmenu's 23")
  eq(MenuFade.closeWhite("status"), 23, "the card returns straight into it")
  eq(MenuFade.closeWhite("save"), nil, "SAVE closes with no white")
end

do
  local stack = newStack()
  local game = { stack = stack, world = {} }
  local fired = 0
  local fade = MenuFade.new(game, { kind = "out", white = 16,
    onDone = function() fired = fired + 1 end })
  stack:push(fade)
  local want = { .25, .25, .5, .5, .75, .75, 1, 1 }
  local levels = { fade:level() }
  for _ = 1, 8 + 16 - 1 do
    fade:update()
    levels[#levels + 1] = fade:level()
  end
  eq(#levels, 24, "the PACK fade is 8 + 16 = 24 drawn frames")
  for i = 1, 8 do
    eq(levels[i], want[i], ("ramp frame %d at %.2f"):format(i, want[i]))
  end
  local white = 0
  for i = 1, #levels do if levels[i] >= 1 then white = white + 1 end end
  eq(white, 2 + 16, "18 of them white: entry 6's 2 plus the pack's 16")
  eq(fired, 0, "the page is not up yet")
  eq(stack:top(), fade, "and the fade still owns the stack")
  fade:update()
  eq(fired, 1, "the 24th update hands over")
  eq(stack:top(), nil, "after popping itself")
  fade:update()
  eq(fired, 1, "...once")
end

do
  local stack = newStack()
  local game = { stack = stack, world = {} }
  local fade = MenuFade.new(game, { kind = "in", white = 23 })
  stack:push(fade)
  local levels = { fade:level() }
  for _ = 1, 23 + 6 - 1 do
    fade:update()
    levels[#levels + 1] = fade:level()
  end
  eq(#levels, 29, "CloseSubmenu: 23 white + 6 ramp = 29 drawn frames")
  for i = 1, 23 do
    check(levels[i] >= 1, ("frame %d white"):format(i))
  end
  local ramp = { .75, .75, .5, .5, .25, .25 }
  for i = 1, 6 do
    eq(levels[23 + i], ramp[i], ("ramp frame %d at %.2f"):format(i, ramp[i]))
  end
  eq(stack:top(), fade, "still up on the last ramp frame")
  fade:update()
  eq(stack:top(), nil, "the 29th update pops it")
end

do
  local stack = newStack()
  local pushed = {}
  local game = setmetatable({
    stack = stack, world = {}, data = {},
    save = { party = { {}, {} } },
  }, { __index = Game2 })
  game.pushStartMenuItem = function(_, id) pushed[#pushed + 1] = id end

  game:openStartMenuItem("pokemon")
  local fade = stack:top()
  eq(fade and fade.screenId, "Gen2MenuFade", "POKEMON opens on the fade")
  eq(fade.kind, "out", "outward")
  eq(fade.white, 11 + 3 * 2, "two mons: 11 + 6 white after the ramp")
  for _ = 1, 8 + 17 - 1 do fade:update() end
  eq(#pushed, 0, "24 updates: still white")
  fade:update()
  eq(pushed[1], "pokemon", "the 25th pushes the list")
  eq(stack:top(), nil, "over a stack the fade has left")

  game:openStartMenuItem("pack")
  eq(stack:top().white, 16, "PACK: 16")
  stack:clear()
  game:openStartMenuItem("pokegear")
  eq(stack:top().white, 20, "POKEGEAR: 20")
  stack:clear()
  game:openStartMenuItem("status")
  eq(stack:top().white, 14, "trainer card: 14")
  stack:clear()
  game:openStartMenuItem("pokedex")
  eq(stack:top().white, 27, "POKEDEX: 27")
  stack:clear()
  game:openStartMenuItem("option")
  eq(stack:top().white, 8, "OPTION: 8")
  stack:clear()

  pushed = {}
  game:openStartMenuItem("save")
  eq(pushed[1], "save", "SAVE goes straight to the page")
  eq(stack:top(), nil, "with no fade")

  local page = { screenId = "Gen2PackMenu" }
  stack:push({ screenId = "Gen2StartMenu" })
  stack:push(page)
  game:closeStartMenuItem("pack")
  local out = stack:top()
  eq(out and out.screenId, "Gen2MenuFade", "closing the PACK pops it onto a fade")
  eq(out.kind, "in", "inward")
  eq(out.white, 23, "23 white")
  eq(#stack.states, 2, "over the START menu")
  for _ = 1, 23 + 6 do out:update() end
  eq(stack:top().screenId, "Gen2StartMenu", "which is back after 29 frames")

  stack:push({ screenId = "Gen2Pokegear" })
  game:closeStartMenuItem("pokegear")
  eq(stack:top().white, 27, "the gear's close holds 27")
  stack:pop()
  stack:push({ screenId = "Gen2SaveMenu" })
  game:closeStartMenuItem("save")
  eq(stack:top().screenId, "Gen2StartMenu", "SAVE just pops")
end

do
  local PartyMenu = require("src.ui.gen2.PartyMenu")
  local PackMenu = require("src.ui.gen2.PackMenu")
  local function harness()
    local calls = 0
    local world = {
      exitMenusFade = function() calls = calls + 1 end,
    }
    local stack = newStack()
    stack:push({ screenId = "Gen2StartMenu" })
    stack:push({ screenId = "page" })
    return { stack = stack, world = world }, function() return calls end, world
  end

  local game, calls = harness()
  local party = setmetatable({ game = game }, PartyMenu)
  party:exitToField()
  eq(#game.stack.states, 0, "the field-move exit clears the stack")
  eq(calls(), 1, "and runs ExitAllMenus' fade")

  local game2, calls2, world2 = harness()
  world2.mapSetup = { phase = "in" }
  local party2 = setmetatable({ game = game2 }, PartyMenu)
  party2:exitToField()
  eq(calls2(), 0, "a fade already armed (FLY) is left alone")

  local game3, calls3 = harness()
  local pack = setmetatable({ game = game3 }, PackMenu)
  pack.storeCursor = function() end
  pack:exitToField()
  eq(#game3.stack.states, 0, "PACKSTATE_QUITRUNSCRIPT clears the stack")
  eq(calls3(), 1, "through the same fade")
end

T.finish("gen2 START page whites S6")
