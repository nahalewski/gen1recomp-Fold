-- pokered engine/items/item_effects.asm:1794 (#1880)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local check, eq = T.check, T.eq
local Data = T.fixtures.fresh()
require("src.render.Font").load(Data)
local TextBox = require("src.render.TextBox")

local plays = {}
local sources = {}
local function newSource(file)
  local src = sources[file]
  if src then return src end
  src = {
    playing = false,
    setVolume = function() end,
    setPitch = function() end,
    stop = function() end,
    isPlaying = function(self) return self.playing end,
    play = function(self)
      plays[#plays + 1] = file
      self.playing = true
    end,
  }
  sources[file] = src
  return src
end
love.audio = { newSource = newSource }
Data.audio = { sfx = { Press_AB = "ab.wav", Pokeflute = "flute.wav" },
               fanfares = {} }

local function tunes()
  local n = 0
  for _, file in ipairs(plays) do
    if file == "flute.wav" then n = n + 1 end
  end
  return n
end

local stack = { states = {} }
function stack:push(s) self.states[#self.states + 1] = s end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local pressed = {}
local game = {
  data = Data,
  save = { player = { name = "RED" }, options = { textSpeed = 1 } },
  stack = stack,
  input = {
    wasPressed = function(_, key) return pressed[key] or false end,
    isDown = function() return false end,
  },
}

local function step(btn)
  pressed = btn and { [btn] = true } or {}
  local top = stack:top()
  if top then top:update(1 / 60) end
  pressed = {}
end

local woke = 0
local opts = TextBox.soundOpts(game, "Pokeflute",
  { auto = { wait = false, delay = 0, promptFirst = true } })
local box = TextBox.new(game, "RED PLAYED THE\nPOKE FLUTE",
                        function() woke = woke + 1 end, opts)
stack:push(box)

for _ = 1, 2000 do
  if box.done then break end
  step(box.waiting and "a" or nil)
end
check(box.done, "the played-flute line typed out")
eq(tunes(), 0, "the tune has not started yet")

step()
eq(tunes(), 0, "still silent while the prompt is up")
eq(stack:top(), box, "and the box is still on screen")
eq(woke, 0, "the woke-up script has not started")

step("a")
eq(box.autoPrompted, true, "A answers the prompt")
step()
eq(tunes(), 1, "and the tune starts after it")
eq(box.autoSrc, sources["flute.wav"], "the box holds the flute source")
eq(stack:top(), box, "the played-flute line stays up under it")

for _ = 1, 30 do step("a") end
eq(tunes(), 1, "A neither retriggers nor cuts the tune short")
eq(stack:top(), box, "and cannot dismiss the box")
eq(woke, 0, "so Snorlax does not wake mid-tune")

sources["flute.wav"].playing = false
step()
eq(stack:top(), nil, "the box pops itself once the tune is over")
eq(woke, 1, "and the woke-up script runs, with no second button")

T.finish("poke_flute_prompt_bug1880")
