-- engine/overworld/healing_machine.asm:74
-- color/data/spritepalettes.asm:2

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("heal machine palette #1986")
local check, eq = S.check, S.eq

local GameVersion = require("src.core.GameVersion")
local PaletteFX = require("src.render.PaletteFX")
local OW = require("src.world.OverworldController")

local function upvalue(fn, want)
  local i = 1
  while true do
    local n, v = debug.getupvalue(fn, i)
    if not n then return nil end
    if n == want then return v end
    i = i + 1
  end
end

local prevVer = GameVersion.get()
local prevMode = PaletteFX.mode

GameVersion.set("red")
PaletteFX.setMode("redpp")

eq(PaletteFX.HEAL_MACHINE_GROUP, 4, "the heal machine wears OBJ palette 4")

local obp = PaletteFX.healMachineObp and PaletteFX.healMachineObp()
check(type(obp) == "table" and #obp == 4,
      "Advanced resolves a 4-color heal-machine palette")
obp = obp or { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
eq(obp[1][1], 222, "shade 0 is the pack's light green (R)")
eq(obp[2][1], 255, "shade 1 is orange (R)")
eq(obp[2][2], 156, "shade 1 is orange (G)")
eq(obp[2][3], 82, "shade 1 is orange (B)")
eq(obp[3][1], 247, "shade 2 is red (R)")
eq(obp[3][2], 82, "shade 2 is red (G)")
eq(obp[3][3], 49, "shade 2 is red (B)")
eq(obp[4][1], 0, "shade 3 stays black")
check(obp[2][1] ~= obp[3][1] or obp[2][2] ~= obp[3][2],
      "the two ball shades are not the same color")

local grays = PaletteFX.GRAYS
for i = 1, 4 do
  check(obp[i][1] ~= grays[i][1] or obp[i][2] ~= grays[i][2]
        or obp[i][3] ~= grays[i][3] or i == 4,
        "shade " .. (i - 1) .. " is not a DMG gray")
end

local healShader = upvalue(OW.drawWorld, "healMachineShader")
check(type(healShader) == "function",
      "the heal overlay picks its palette through healMachineShader")

local realShader, realSend = PaletteFX.shader, PaletteFX.sendColors
local realSetShader = love.graphics.setShader
local STUB = { stub = true }
local sent, bound
PaletteFX.shader = function() return STUB end
PaletteFX.sendColors = function(_, colors) sent = colors end
love.graphics.setShader = function(s) bound = s end

local function beat(visible)
  sent, bound = nil, nil
  local s = healShader(visible)
  return s, sent, bound
end

local ok, err = pcall(function()
  PaletteFX.setMode("redpp")

  local s, lit, bnd = beat(true)
  eq(s, STUB, "Advanced shades the machine on a lit beat")
  eq(bnd, STUB, "and binds that shader before the sprites are drawn")
  check(type(lit) == "table", "a lit beat sends a palette")
  eq(lit[2][1], obp[2][1], "the lit ball keeps the pack's orange (R)")
  eq(lit[2][2], obp[2][2], "the lit ball keeps the pack's orange (G)")
  eq(lit[3][1], obp[3][1], "the lit ball keeps the pack's red (R)")
  eq(lit[3][2], obp[3][2], "the lit ball keeps the pack's red (G)")
  check(lit[2][1] ~= PaletteFX.GRAYS[2][1],
        "a lit beat is not the DMG gray ramp")

  -- engine/overworld/healing_machine.asm:54
  local _, flashed = beat(false)
  check(type(flashed) == "table", "a flashed half-beat sends a palette")
  eq(flashed[2][1], obp[1][1], "the flash beat lifts shade 1 to shade 0")
  eq(flashed[3][1], obp[2][1], "the flash beat lifts shade 2 to shade 1")
  eq(flashed[4][1], obp[3][1], "the flash beat lifts shade 3 to shade 2")
  check(flashed[2][1] ~= obp[3][1],
        "the Advanced flash lifts brightness instead of swapping the middle shades")

  for _, mode in ipairs({ "gbc", "og", "classic" }) do
    PaletteFX.setMode(mode)
    check(not PaletteFX.usesGbcPack(), mode .. " is not the Advanced pack")
    local ds, dlit, dbnd = beat(true)
    eq(ds, nil, mode .. " leaves a lit beat unshaded")
    eq(dlit, nil, mode .. " sends no palette on a lit beat")
    eq(dbnd, nil, mode .. " binds no shader on a lit beat")
    local _, dflash = beat(false)
    check(type(dflash) == "table", mode .. " still shades the flashed half-beat")
    eq(dflash[2][1], PaletteFX.GRAYS[3][1],
       mode .. " swaps the two middle DMG grays on the flash beat")
    eq(dflash[3][1], PaletteFX.GRAYS[2][1],
       mode .. " swaps them back for shade 2")
  end
end)

PaletteFX.shader, PaletteFX.sendColors = realShader, realSend
love.graphics.setShader = realSetShader
check(ok, "the heal palette pass ran: " .. tostring(err))

PaletteFX.setMode(prevMode)
GameVersion.set(prevVer)

S.finish()
