-- engine/movie/evolution.asm:17-19, :20-40 (#2033)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local PIC_LOAD_FRAMES = 84
local CANCEL_GRACE_FRAMES = 80
local CRY_FRAMES = 85

local frame = 0
local played, cries, musicLog = {}, {}, {}

local function fakeSource(len)
  local start = frame
  return {
    isPlaying = function() return frame - start < len end,
    stop = function() end,
    getDuration = function() return len / 60 end,
    getPitch = function() return 1 end,
  }
end

package.loaded["src.core.Sound"] = {
  play = function(_, id) played[#played + 1] = { id = id, frame = frame } end,
  playPress = function() end,
  sfxBusy = function() return false end,
  waitFrames = function(_, fallback) return fallback or 180 end,
  playCry = function(_, species)
    cries[#cries + 1] = { species = species, frame = frame }
    return fakeSource(CRY_FRAMES)
  end,
}

local Music = require("src.core.Music")
for _, name in ipairs({ "stop", "play", "restoreMap" }) do
  local real = Music[name]
  Music[name] = function(...)
    musicLog[#musicLog + 1] = { name = name, frame = frame }
    return real(...)
  end
end

local Fixtures = require("tests.modkit.fixtures")
local EvolutionState = require("src.ui.EvolutionState")
local Input = require("src.core.Input")
local Pokemon = require("src.pokemon.Pokemon")
local StateStack = require("src.core.StateStack")
local TextBox = require("src.render.TextBox")

local Data = Fixtures.fresh()
require("src.render.Font").load(Data)

local EVO_LEVEL = 16
local B_KEY = "x"

local fakeSprite = {
  getWidth = function() return 40 end,
  getHeight = function() return 40 end,
  getDimensions = function() return 40, 40 end,
}

local drawn = 0
local realDraw = love.graphics.draw
love.graphics.draw = function(img, ...)
  if img == fakeSprite then drawn = drawn + 1 return end
  return realDraw(img, ...)
end

local function newGame()
  local game = { data = Data }
  local mon = Pokemon.new(Data, "FIXMON_A", EVO_LEVEL)
  game.save = {
    party = { mon },
    player = { name = "RED", id = 1 },
    options = { textSpeed = 5 },
    flags = {},
    pokedex = { seen = {}, owned = {} },
  }
  game.stack = setmetatable({}, { __index = StateStack })
  game.stack:init()
  game.input = Input
  Input:init()
  return game, mon
end

local function step(game)
  frame = frame + 1
  game.input:step()
  game.stack:update(1 / 60)
end

local function openMovie(game, mon)
  local state = EvolutionState.new(game, mon, "FIXMON_B", nil, "LEVEL")
  state.oldSprite, state.newSprite = fakeSprite, fakeSprite
  game.stack:push(state)
  return state
end

local function textOf(box)
  local out = {}
  for _, page in ipairs(box.pages) do
    for _, line in ipairs(page) do out[#out + 1] = line end
  end
  return table.concat(out, " ")
end

local function lastMusic(name)
  for i = #musicLog, 1, -1 do
    if musicLog[i].name == name then return musicLog[i].frame end
  end
end

do
  local game, mon = newGame()
  played, cries, musicLog = {}, {}, {}
  local state = openMovie(game, mon)

  eq(#played, 1, "one SFX at the clear")
  eq(played[1] and played[1].id, "Tink",
     "and it is SFX_TINK (evolution.asm:17)")
  eq(#cries, 0, "the old cry does not start with the state (evolution.asm:41)")
  eq(state.loading, PIC_LOAD_FRAMES,
     "the pic load window is the frozen-screen stretch (evolution.asm:20-40)")

  drawn = 0
  state:draw()
  eq(drawn, 0, "nothing is painted over the blank field while it loads")

  for _ = 1, PIC_LOAD_FRAMES - 1 do step(game) end
  eq(state.loading, 1, "still loading one frame short of the window")
  eq(#cries, 0, "and still silent")
  eq(state.t, 0, "the cancel-grace clock has not started either")
  drawn = 0
  state:draw()
  eq(drawn, 0, "the pic is still off screen on the last loading frame")

  step(game)
  eq(state.loading, nil, "hAutoBGTransferEnabled comes back (evolution.asm:39)")
  eq(#cries, 1, "the old cry starts on that frame (evolution.asm:41)")
  eq(cries[1] and cries[1].species, "FIXMON_A", "and it is the old species")
  eq(state.cryWait, true, "WaitForSoundToFinish holds the movie (evolution.asm:43)")
  drawn = 0
  state:draw()
  eq(drawn, 1, "the pic appears on the same frame as the cry")

  -- the evolution music only starts once the cry is out (evolution.asm:45)
  local cryFrame = frame
  check(lastMusic("play") == nil, "no evolution music under the cry")
  for _ = 1, 400 do
    if not state.cryWait then break end
    step(game)
  end
  check(lastMusic("play") ~= nil and lastMusic("play") - cryFrame >= CRY_FRAMES - 2,
        "the music waits out the full cry")

  played, cries, musicLog = {}, {}, {}
  for _ = 1, 500 do
    if state.done then break end
    step(game)
  end
  check(state.done, "the flash ran to the end")
  eq(mon.species, "FIXMON_B", "the mon evolved")
  local doneFrame = frame
  eq(#cries, 1, "the new cry starts at .done (evolution.asm:74)")
  eq(cries[1] and cries[1].species, "FIXMON_B", "and it is the evolved species")
  eq(lastMusic("stop"), doneFrame,
     "SFX_STOP_ALL_MUSIC lands first (evolution.asm:70-72)")
  check(game.stack:top() == state,
        "EvolvedText does not print on the cry frame (evos_moves.asm:136)")

  for _ = 1, 400 do
    if game.stack:top() ~= state then break end
    step(game)
  end
  local box = game.stack:top()
  if check(getmetatable(box) == TextBox, "the result text follows the cry") then
    check(textOf(box):find("evolved"), "and it is _EvolvedText + _IntoText")
  end
  check(frame - doneFrame >= CRY_FRAMES - 2,
        "PlayCry blocked the text for the whole cry (home/pokemon.asm:145-149)")
  eq(#played, 0, "and no jingle sounded under it")
end

do
  local game, mon = newGame()
  played, cries, musicLog = {}, {}, {}
  local state = openMovie(game, mon)
  eq(played[1] and played[1].id, "Tink", "the cancel path opens the same way")

  for _ = 1, 600 do
    if state.t > 80 then break end
    step(game)
  end
  check(state.t > 80 and not state.done, "the movie is past the poll window")

  played, cries, musicLog = {}, {}, {}
  Input:keypressed(B_KEY)
  step(game)
  eq(state.canceled, true, "a fresh B press cancels")
  local cancelFrame = frame
  -- evolution.asm:89-94 falls into .done with wEvoOldSpecies
  eq(#cries, 1, "a cancelled evolution still cries at .done")
  eq(cries[1] and cries[1].species, "FIXMON_A", "with the old species")
  eq(lastMusic("stop"), cancelFrame, "and stops the evolution music there")
  check(game.stack:top() == state, "StoppedEvolvingText waits on the cry")

  for _ = 1, 400 do
    if game.stack:top() ~= state then break end
    step(game)
  end
  local box = game.stack:top()
  if check(getmetatable(box) == TextBox, "the stopped-evolving text follows") then
    check(textOf(box):find("stopped evolving"), "and it is _StoppedEvolvingText")
  end
  check(frame - cancelFrame >= CRY_FRAMES - 2, "after the whole cry")
  eq(mon.species, "FIXMON_A", "the mon kept its species")
end

-- ../pokered/engine/movie/evolution.asm:23-26, :49-50, :70-76
do
  local realPaletteFX = package.loaded["src.render.PaletteFX"]
  package.loaded["src.render.PaletteFX"] = {
    pal = function(_, name) return { name = name } end,
    monPal = function(_, species) return { species = species } end,
    whole = function(c) return { whole = c } end,
    wholeNamed = function(_, n) return { { whole = { name = n } } } end,
    markTrueColor = function() end,
  }

  local game, mon = newGame()
  played, cries, musicLog = {}, {}, {}
  local state = openMovie(game, mon)
  local function palOf()
    local packets = state:sgbPalettes(game)
    local w = packets and packets[1] and packets[1].whole
    return w and (w.species or w.name) or "?"
  end

  eq(palOf(), "FIXMON_A", "the old mon's palette is loaded before the pic")

  for _ = 1, PIC_LOAD_FRAMES do step(game) end
  eq(state.cryWait, true, "the cry is holding the movie")
  eq(palOf(), "FIXMON_A", "the pic arrives in the old mon's own colours")

  for _ = 1, 400 do
    if not state.cryWait then break end
    step(game)
  end
  eq(state.t, 0, "the 80-frame grace has not started yet")
  eq(palOf(), "FIXMON_A", "and the music starts with the mon still coloured")

  for _ = 1, CANCEL_GRACE_FRAMES - 1 do step(game) end
  eq(state.t, CANCEL_GRACE_FRAMES - 1, "one frame short of the grace")
  eq(palOf(), "FIXMON_A", "still the mon palette on the last grace frame")

  step(game)
  eq(state.t, CANCEL_GRACE_FRAMES, "the grace is over")
  eq(palOf(), "BLACK", "PAL_BLACK lands with .animLoop, not before it")

  for _ = 1, 400 do
    if state.done then break end
    step(game)
  end
  check(state.done, "the flash finished")
  eq(palOf(), "FIXMON_B", "and the settled form wears its own palette")

  package.loaded["src.render.PaletteFX"] = realPaletteFX
end

love.graphics.draw = realDraw
T.finish()
