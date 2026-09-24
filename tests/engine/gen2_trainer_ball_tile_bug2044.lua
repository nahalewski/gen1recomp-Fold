-- ../pokecrystal/engine/battle/battle_transition.asm:100-122

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local Transition = require("src.ui.gen2.BattleTransition")
local GbcPalette = require("src.render.GbcPalette")

local function row(t) return table.concat(t, "") end

do
  local tile = Transition.squareTile()
  T.eq(#tile, 8, "BATTLETRANSITION_SQUARE is one 8x8 tile")
  T.eq(tile[1], "33333333", "row 1 is the colour-3 border")
  T.eq(tile[8], "33333333", "row 8 too")
  T.eq(tile[2], "30000003", "row 2: border, then colour 0")
  T.eq(tile[2]:sub(2, 2), "0", "...the interior starts at colour 0")
  T.eq(tile[5], "31122113", "row 5 carries the 1/2 diagonal")
  T.eq(tile[7], "32222223", "row 7 is all colour 2 inside the border")
end

do
  local shades = Transition.squareShades(Transition.flashByte({ 3, 3, 2, 1 }))
  T.eq(row(shades[1]), "44444444", "$F9: the border stays colour 3")
  T.eq(row(shades[2]), "42222224", "$F9 row 2 == 31111113 (1-based shades)")
  T.eq(row(shades[5]), "43344334", "$F9 row 5 == 32233223")
  T.eq(row(shades[6]), "43444434", "$F9 row 6 == 32333323")
  T.eq(row(shades[7]), "44444444", "$F9 row 7 == 33333333")

  local black = Transition.squareShades(Transition.flashByte({ 3, 3, 3, 3 }))
  for y = 1, 8 do
    T.eq(row(black[y]), "44444444", "$FF row " .. y .. " is all colour 3")
  end
  local white = Transition.squareShades(Transition.flashByte({ 0, 0, 0, 0 }))
  for y = 1, 8 do
    T.eq(row(white[y]), "11111111", "$00 row " .. y .. " is all colour 0")
  end
  local id = Transition.squareShades(nil)
  T.eq(row(id[2]), "41111114", "identity row 2 is the tile itself")
  T.eq(row(id[6]), "42333324", "identity row 6 is the tile itself")
  local ninety = Transition.squareShades(Transition.flashByte({ 2, 1, 0, 0 }))
  T.eq(row(ninety[1]), "33333333", "$90: border colour 2")
  T.eq(row(ninety[2]), "31111113", "$90: interior colour 0")
  T.eq(row(ninety[7]), "32222223", "$90: the colour-2 row shows colour 1")
end

do
  local ramp = Transition.TRAINER_PAL
  local mode = GbcPalette.mode
  GbcPalette.setMode("gbc")
  local src, dst, count = GbcPalette.remapTable({},
    Transition.flashByte({ 3, 3, 2, 1 }), {}, ramp)
  GbcPalette.setMode(mode)
  T.eq(count, 4, "the trainer ramp's own four colours enter the flash table")
  local function key(c) return c[1] .. "," .. c[2] .. "," .. c[3] end
  local got = {}
  for i = 1, count do got[key(src[i])] = key(dst[i]) end
  T.eq(got[key(ramp[1])], key(ramp[2]), "$F9: ramp c0 -> c1")
  T.eq(got[key(ramp[2])], key(ramp[3]), "$F9: ramp c1 -> c2")
  T.eq(got[key(ramp[3])], key(ramp[4]), "$F9: ramp c2 -> c3")
  T.eq(got[key(ramp[4])], key(ramp[4]), "$F9: ramp c3 -> c3")
end

do
  T.eq(Transition.FLASH_SLOT_FRAMES, 25,
    "a Flash slot is 12 entries x 2 plus the terminator frame")
  T.eq(Transition.FLASH_FRAMES, 75, "three slots: 75 frames, not 72")
end

local function make(opts)
  opts.environment = opts.environment or "TOWN"
  opts.world = { map = { def = {} }, daytime = "DAY", npcs = {}, ghosts = {},
    vm = { lastTalked = 3, running = function() return true end } }
  local state = Transition.new(nil, opts)
  return state, opts.world
end

do
  local state = make({ trainer = true })
  state:update()
  state:update()
  T.eq(state.phase, "flash", "flash after two ball frames")
  local function palAt(f)
    state.frame = f
    return state:flashPal()
  end
  T.same(palAt(0), { 3, 3, 2, 1 }, "frame 0 is $F9")
  T.same(palAt(1), { 3, 3, 2, 1 }, "frame 1 is still $F9")
  T.same(palAt(2), { 3, 3, 3, 2 }, "frame 2 is $FE")
  T.same(palAt(12), { 2, 1, 0, 0 }, "frame 12 is $90")
  T.same(palAt(22), { 3, 2, 1, 0 }, "frame 22 is the identity")
  T.same(palAt(24), { 3, 2, 1, 0 },
    "frame 24: the terminator row holds the identity one more frame")
  T.same(palAt(25), { 3, 3, 2, 1 }, "frame 25: the second slot restarts at $F9")
  T.same(palAt(74), { 3, 2, 1, 0 }, "frame 74 is the last identity frame")
  state.frame = 0
  local frames = 0
  while state.phase == "flash" do
    frames = frames + 1
    state:update()
  end
  T.eq(frames, 75, "75 flash frames are drawn before the outro")
end

local function outroTimeline(style, opts)
  opts = opts or {}
  opts.style = style
  opts.trainer = opts.trainer ~= false
  local state, world = make(opts)
  while state.phase ~= "outro" do state:update() end
  local events = {}
  local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
  end
  local lastBlack = 0
  local firstFilter
  local frame = 0
  events.black = count(state.black)
  while state.phase == "outro" do
    if world.spriteFilter and not firstFilter then firstFilter = frame end
    state:update()
    frame = frame + 1
    if state.phase == "outro" then
      local n = count(state.black)
      if n ~= lastBlack then
        events[#events + 1] = frame
        lastBlack = n
      end
    end
  end
  return events, frame, firstFilter, state
end

do
  local steps, blackAt, filterAt = outroTimeline("spin")
  T.eq(filterAt, 1, "spin: RespawnPlayerAndOpponent on the SetUpFor frame")
  T.eq(steps[1], 2, "spin: first wedge on outro frame 2")
  T.eq(steps[2], 5, "spin: three frames a wedge")
  T.eq(#steps, 20, "spin: twenty wedges")
  T.eq(steps[20], 59, "spin: last wedge on frame 59")
  T.eq(blackAt, 66, "spin: .end holds four frames, black on 66")
end

do
  local steps, blackAt, filterAt = outroTimeline("zoom")
  T.eq(filterAt, 1, "zoom: respawn on the first box frame")
  T.eq(steps[1], 1, "zoom: no SetUpFor slot, box 1 on frame 1")
  T.eq(steps[2], 5, "zoom: one box per WaitBGMap, four frames")
  T.eq(#steps, 9, "zoom: nine boxes")
  T.eq(steps[9], 33, "zoom: last box on frame 33")
  T.eq(blackAt, 38, "zoom: 36 box frames, one .done frame, black on 38")
end

do
  local steps, blackAt = outroTimeline("speckle",
    { random = function(n) return math.random(n) - 1 end })
  T.eq(steps[1], 2, "speckle: first pass on frame 2")
  T.eq(#steps, 16, "speckle: sixteen passes, one a frame")
  T.eq(steps[16], 17, "speckle: last pass on frame 17")
  T.eq(blackAt, 22, "speckle: .done holds four frames, black on 22")
end

do
  local state = make({ trainer = true, environment = "CAVE",
    playerLevel = 10, enemyLevel = 5 })
  T.eq(state.style, "sine", "cave + not stronger = sine")
  while state.phase ~= "outro" do state:update() end
  local waves = {}
  local frame = 0
  while state.phase == "outro" do
    waves[frame] = state:lyOverrides() ~= nil
    state:update()
    frame = frame + 1
  end
  T.eq(waves[0], false, "sine: NextScene frame is flat")
  T.eq(waves[1], false, "sine: SetUpForWavyOutro frame is flat")
  T.eq(waves[2], true, "sine: the wave starts on frame 2")
  T.eq(waves[16], true, "sine: fifteen wave frames end on 16")
  T.eq(waves[17], true, "sine: the last wave holds through the FINISH frame")
  T.eq(frame, 18, "sine: black on frame 18")
end

do
  local state, world = make({ trainer = true })
  local npc = { def = { index = 2 } }
  local other = { def = { index = 5 } }
  T.eq(state:keepsOpponent(npc), true,
    "the hLastTalked object survives RespawnPlayerAndOpponent")
  T.eq(state:keepsOpponent(other), false, "...and nobody else does")
  world.vm.lastTalked = nil
  T.eq(state:keepsOpponent(npc), false, "no hLastTalked: only the player")
  local wild = make({ trainer = false })
  wild.world.vm.running = function() return false end
  T.eq(wild:keepsOpponent({ def = { index = 2 } }), false,
    "an unscripted wild battle keeps nobody")
end

T.finish("gen2 trainer ball tile bug 2044")
