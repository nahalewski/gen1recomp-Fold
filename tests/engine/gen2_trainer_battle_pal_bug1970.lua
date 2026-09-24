-- ../pokecrystal/engine/battle/battle_transition.asm:584

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local GbcPalette = require("src.render.GbcPalette")
local Transition = require("src.ui.gen2.BattleTransition")

local function scale5(value)
  return math.floor(value * 255 / 31 + 0.5)
end

local function ramps(pal, rows)
  for index, row in ipairs(rows) do
    local color = pal[index]
    T.eq(color[1], scale5(row[1]), "colour " .. index .. " red")
    T.eq(color[2], scale5(row[2]), "colour " .. index .. " green")
    T.eq(color[3], scale5(row[3]), "colour " .. index .. " blue")
  end
end

do
  ramps(Transition.TRAINER_PAL, {
    { 31, 18, 29 }, { 31, 11, 15 }, { 31, 5, 5 }, { 7, 7, 7 },
  })
  ramps(Transition.TRAINER_PAL_DARK, {
    { 31, 18, 29 }, { 31, 5, 5 }, { 31, 5, 5 }, { 31, 5, 5 },
  })
end

local function make(opts)
  opts.environment = opts.environment or "TOWN"
  return Transition.new(nil, opts)
end

do
  local wild = make({ trainer = false })
  T.eq(wild:trainerRamp(), nil, "a wild transition keeps the map's colours")
  local trainer = make({ trainer = true })
  T.check(trainer:trainerRamp() == Transition.TRAINER_PAL,
    "a trainer transition repaints the background red")
  local dark = make({ trainer = true, dark = true })
  T.check(dark:trainerRamp() == Transition.TRAINER_PAL_DARK,
    "a DARKNESS map takes .darkpals")
end

do
  local lit = make({ trainer = true })
  T.eq(lit:flashFrames(), Transition.FLASH_FRAMES, "the flash runs in full")
  local dark = make({ trainer = true, dark = true })
  T.eq(dark:flashFrames(), Transition.FLASH_CYCLES,
    "DoFlashAnimation bails out on DARKNESS_PALSET: one frame per Flash slot")
  T.eq(dark.phase, "pokeball", "a trainer battle still stamps the ball")
  local darkWild = make({ trainer = false, dark = true })
  T.eq(darkWild.phase, "flash", "and a wild one walks the three empty slots")
  T.eq(darkWild:flashPal(), nil, "...with no palette written")
  for _ = 1, Transition.FLASH_CYCLES do darkWild:update() end
  T.eq(darkWild.phase, "outro", "...and reaches the outro on the fourth frame")
end

do
  local bgA = { { 10, 10, 10 }, { 20, 20, 20 }, { 30, 30, 30 }, { 40, 40, 40 } }
  local bgB = { { 50, 50, 50 }, { 60, 60, 60 }, { 70, 70, 70 }, { 80, 80, 80 } }
  local tree = { { 90, 90, 90 }, { 91, 91, 91 }, { 92, 92, 92 }, { 93, 93, 93 } }
  local other = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 }, { 11, 12, 13 } }
  local objs = { other, other, other, other, other, other, tree, other }
  local src, dst, count = GbcPalette.remapTable({ bgA, bgB },
    GbcPalette.BGP_IDENTITY, objs, Transition.TRAINER_PAL,
    Transition.RAMPED_OBJ)
  local function mapped(from)
    for i = 1, count do
      if src[i][1] == from[1] and src[i][2] == from[2]
          and src[i][3] == from[3] then
        return dst[i]
      end
    end
  end
  for index = 1, 4 do
    local want = Transition.TRAINER_PAL[index]
    for _, palette in ipairs({ bgA, bgB }) do
      local got = mapped(palette[index])
      T.check(got and got[1] == want[1] and got[2] == want[2]
        and got[3] == want[3],
        "every BG palette's colour " .. index .. " takes the ramp")
    end
    local treeGot = mapped(tree[index])
    T.check(treeGot and treeGot[1] == want[1] and treeGot[2] == want[2]
      and treeGot[3] == want[3],
      "PAL_OW_TREE takes it too")
    local otherGot = mapped(other[index])
    T.check(otherGot and otherGot[1] == other[index][1],
      "an OBJ palette the cart leaves alone maps to itself")
  end
end

do
  local bgA = { { 10, 10, 10 }, { 20, 20, 20 }, { 30, 30, 30 }, { 40, 40, 40 } }
  local src, dst, count = GbcPalette.remapTable({ bgA }, 0xff)
  T.eq(count, 4, "no ramp: the table is the palette itself")
  T.check(src[1][1] == 10 and dst[1][1] == 40,
    "and $ff still sends every colour to shade 3")
end

T.finish("gen2 trainer battle palette bug 1970")
