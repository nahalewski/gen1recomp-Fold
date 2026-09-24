-- engine/gfx/screen_effects.asm:1-12 (#1872)

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local check, eq = T.check, T.eq

local Data = T.fixtures.fresh()

local SaveData = require("src.core.SaveData")
local Pokemon  = require("src.pokemon.Pokemon")
local PaletteFX = require("src.render.PaletteFX")
local OW = require("src.world.OverworldController")

local function setUpvalue(fn, name, val)
  local i = 1
  while true do
    local n = debug.getupvalue(fn, i)
    if not n then return false end
    if n == name then debug.setupvalue(fn, i, val); return true end
    i = i + 1
  end
end

do
  local bgp = 0xE4
  local want = {}
  for i = 0, 3 do
    local shade = math.floor(bgp / (4 ^ i)) % 4
    want[i] = (i == 0) and (shade % 4 >= 2 and shade or shade + 2) or shade
  end
  for i = 0, 3 do
    eq(PaletteFX.POISON_BGP[i], want[i],
       ("POISON_BGP color %d matches `or $2` on rBGP"):format(i))
  end

  local colors = { { 1, 1, 1 }, { 2, 2, 2 }, { 3, 3, 3 }, { 4, 4, 4 } }
  local out = PaletteFX.permute(colors, PaletteFX.POISON_BGP)
  eq(out[1][1], 3, "poison shows DMG white as shade 2")
  eq(out[2][1], 2, "poison leaves shade 1 alone")
  eq(out[4][1], 4, "poison leaves shade 3 alone")
end

do
  local realSound = package.loaded["src.core.Sound"]
  package.loaded["src.core.Sound"] = { play = function() end, playCry = function() end }
  local save = SaveData.newGame()
  save.party = { Pokemon.new(Data, "FIXMON_A", 20) }
  save.party[1].status = "PSN"
  save.party[1].hp = 20
  save.poisonSteps = 3
  local game = { data = Data, save = save, stack = { push = function() end } }
  setUpvalue(OW.applyFieldPoison, "Game", game)
  local self_ = setmetatable({}, { __index = OW })
  self_:applyFieldPoison()
  eq(self_.poisonFlash, 4, "a poison tick arms four frames of flicker")

  -- engine/events/poison.asm:75-91 .countPoisonedLoop
  local sounds = {}
  package.loaded["src.core.Sound"] = {
    play = function(_, id) sounds[#sounds + 1] = id end,
    playCry = function() end,
  }
  save.party = { Pokemon.new(Data, "FIXMON_A", 20), Pokemon.new(Data, "FIXMON_A", 20) }
  save.party[1].status = "PSN"
  save.party[1].hp = 1
  save.party[2].status = nil
  save.party[2].hp = 20
  save.poisonSteps = 3
  local realTextBox = require("src.render.TextBox")
  setUpvalue(OW.applyFieldPoison, "TextBox", { new = function() return {} end })
  local fainter = setmetatable({}, { __index = OW })
  fainter:applyFieldPoison()
  setUpvalue(OW.applyFieldPoison, "TextBox", realTextBox)
  eq(save.party[1].hp, 0, "the last poisoned mon faints on this tick")
  eq(fainter.poisonFlash, nil, "a party with nothing left poisoned never flashes")
  eq(#sounds, 0, "and plays no SFX_POISONED")

  save.party[2].status = "PSN"
  save.poisonSteps = 3
  local other = setmetatable({}, { __index = OW })
  other:applyFieldPoison()
  eq(other.poisonFlash, 4, "a mon still poisoned after the loop keeps the flash")
  eq(sounds[1], "Poisoned", "and the sound")
  package.loaded["src.core.Sound"] = realSound
end

do
  local rects = {}
  local savedRect = love.graphics.rectangle
  love.graphics.rectangle = function(mode, x, y, w, h)
    rects[#rects + 1] = { mode = mode, x = x, y = y, w = w, h = h }
  end
  local savedShader = PaletteFX.shader
  PaletteFX.shader = function() return { send = function() end } end

  local renderer = {}
  setUpvalue(OW.drawUI, "Game", { renderer = renderer })
  local self_ = setmetatable({ poisonFlash = 4 }, { __index = OW })

  PaletteFX.setShadeMap(nil)
  self_:drawUI()
  eq(#rects, 0, "the poison flicker paints no rect on the UI canvas")
  check(PaletteFX.shadeMap() == PaletteFX.POISON_BGP,
        "the flicker arms the poison BGP map, which the world and UI blits both read")

  -- engine/gfx/screen_effects.asm:1-12, DelayFrames counts vblanks (#1908)
  for _ = 1, 10 do
    PaletteFX.setShadeMap(nil)
    self_:drawUI()
  end
  eq(self_.poisonFlash, 4, "drawing never spends the flicker")

  -- home/fade.asm:66
  PaletteFX.setShadeMap(PaletteFX.DARK_BGP)
  self_:drawUI()
  check(PaletteFX.shadeMap() == PaletteFX.DARK_BGP,
        "the flicker leaves a dark map's shade map in place")
  eq(#rects, 0, "and still paints no rect")

  PaletteFX.shader = function() return nil end
  PaletteFX.setShadeMap(nil)
  renderer.screenVeil = nil
  self_:drawUI()
  check(renderer.screenVeil ~= nil and renderer.screenVeil[1] == 0
        and renderer.screenVeil[2] > 0,
        "with no shader the flicker becomes a screen-space veil")
  eq(#rects, 0, "and still not a 160x144 fill")

  PaletteFX.shader = function() return { send = function() end } end
  local savedMode = PaletteFX.mode
  PaletteFX.mode = "redpp"
  self_.map = { renderer = { gbcAtlas = {} } }
  PaletteFX.setShadeMap(nil)
  renderer.screenVeil = nil
  self_:drawUI()
  check(renderer.screenVeil ~= nil and renderer.screenVeil[2] > 0,
        "a baked GBC atlas falls back to the screen-space veil")
  check(PaletteFX.shadeMap() == nil, "and does not arm a map nothing reads")
  eq(self_:poisonShadeMap(), nil,
     "and drawWorld arms none either, so the veil is not doubled up")

  self_.map = { renderer = {} }
  PaletteFX.setShadeMap(nil)
  renderer.screenVeil = nil
  self_:drawUI()
  eq(renderer.screenVeil, nil, "a zoned world needs no veil")
  check(PaletteFX.shadeMap() == PaletteFX.POISON_BGP,
        "it arms the poison map instead")
  check(self_:poisonShadeMap() == PaletteFX.POISON_BGP,
        "and drawWorld arms the same one")
  PaletteFX.mode = savedMode
  self_.map = nil

  -- engine/events/poison.asm:57, :93
  local other = {}
  setUpvalue(OW.drawUI, "Game",
             { renderer = renderer, stack = { top = function() return other end } })
  PaletteFX.setShadeMap(nil)
  renderer.screenVeil = nil
  self_:drawUI()
  eq(renderer.screenVeil, nil, "a flicker under a text box paints nothing")
  check(PaletteFX.shadeMap() == nil, "and arms no shade map")
  eq(self_.poisonFlash, 4, "and is still there for when the box closes")
  eq(self_:poisonShadeMap(), nil, "and drawWorld holds the map back too")
  setUpvalue(OW.drawUI, "Game",
             { renderer = renderer, stack = { top = function() return self_ end } })
  PaletteFX.setShadeMap(nil)
  self_:drawUI()
  check(PaletteFX.shadeMap() == PaletteFX.POISON_BGP,
        "and flashes once the overworld owns the loop again")
  setUpvalue(OW.drawUI, "Game", { renderer = renderer })

  -- `ld c, 4 / call DelayFrames` (engine/gfx/screen_effects.asm:1-12)
  local ticker = setmetatable({ poisonFlash = 4 }, { __index = OW })
  for i = 3, 0, -1 do
    OW.tickPoisonFlash(ticker)
    eq(ticker.poisonFlash, i, "update spends one flicker frame per logic tick")
  end
  OW.tickPoisonFlash(ticker)
  eq(ticker.poisonFlash, 0, "and stops at zero")
  eq(ticker:poisonShadeMap(), nil, "a spent flash arms no shade map")

  PaletteFX.setShadeMap(nil)
  PaletteFX.shader = savedShader
  love.graphics.rectangle = savedRect
end
