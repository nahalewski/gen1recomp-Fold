-- ../pokecrystal/engine/battle/battle_transition.asm:584

package.path = "./?.lua;./?/init.lua;" .. package.path

love = require("tests.love_stub")

local T = require("tests.harness")
local Transition = require("src.ui.gen2.BattleTransition")
local World = require("src.world.gen2.World")

local ballCalls = 0
local realCells = Transition.pokeballCells
Transition.pokeballCells = function(...)
  ballCalls = ballCalls + 1
  return realCells(...)
end

local function fakeWorld()
  local world = {
    map = { id = "NEW_BARK_TOWN", def = {} }, daytime = "DAY",
    npcs = {}, ghosts = {}, log = {},
  }
  function world:gbScreenOrigin() return 0, 0 end
  function world:fitScale() return 1 end
  function world:zoomScale() return 1 end
  function world:drawGround() self.log[#self.log + 1] = "ground" end
  function world:drawPeople() self.log[#self.log + 1] = "people" end
  world.drawWorldBody = World.drawWorldBody
  function world:draw() self:drawWorldBody(1) end
  return world
end

local function make(opts)
  opts.environment = opts.environment or "TOWN"
  local world = fakeWorld()
  opts.world = world
  local state = Transition.new(nil, opts)
  local inner = world.bgOverlay
  if inner then
    world.bgOverlay = function(s)
      world.log[#world.log + 1] = world.peopleHidden and "bgonly" or "overlay"
      inner(s)
    end
  end
  return state, world
end

local function frame(state)
  local world = state.world
  world.log = {}
  ballCalls = 0
  state:drawWidescreen(160, 144)
  local seq = table.concat(world.log, ",")
  local layered = seq:find("ground,overlay,people", 1, true) ~= nil
  return layered, ballCalls > 0, seq
end

local function pastBall(state)
  state:update()
  state:update()
end

do
  local cells = Transition.pokeballCells()
  T.eq(#cells, 112, ".PokeBallTransition sets 112 bits")
  local minX, minY, maxY = 20, 18, -1
  for _, cell in ipairs(cells) do
    minX = math.min(minX, cell[1])
    minY = math.min(minY, cell[2])
    maxY = math.max(maxY, cell[2])
  end
  T.eq(minX, Transition.POKEBALL_X, "the stamp starts at hlcoord 2, 1 (x)")
  T.eq(minY, Transition.POKEBALL_Y, "the stamp starts at hlcoord 2, 1 (y)")
  T.eq(maxY - minY + 1, 16, "and it is sixteen rows tall")
end

do
  local state, world = make({ trainer = true })
  T.eq(state.phase, "pokeball", "a trainer battle stamps the ball first")
  T.check(world.bgOverlay ~= nil, "the ball is BG content: an overlay seam")
  local layered, ball, seq = frame(state)
  T.check(layered, "drawn between the ground and the people: " .. seq)
  T.check(ball, "and it is the ball that is painted there")
  state:update()
  T.eq(state.phase, "pokeball", "two frames of ball before the flash")
  T.check((frame(state)), "...both with the ball under the sprites")

  state:update()
  T.eq(state.phase, "flash", "then the flash starts")
  local seen = 0
  for _ = 1, Transition.FLASH_FRAMES do
    local l, b = frame(state)
    if l and b then seen = seen + 1 end
    state:update()
  end
  T.eq(seen, Transition.FLASH_FRAMES,
    "the ball is still in the tilemap for every flash frame")
  T.eq(state.phase, "outro", "the flash hands off to the outro")

  local drawn, missed, guard = 0, 0, 0
  local filtered = 0
  while state.phase == "outro" and guard < 400 do
    local l, b = frame(state)
    if l and b then drawn = drawn + 1 else missed = missed + 1 end
    if world.spriteFilter then filtered = filtered + 1 end
    state:update()
    guard = guard + 1
  end
  T.check(drawn > 0, "and the outro paints over a ball that is still there")
  T.eq(missed, 0, "no outro frame drops it early")
  T.eq(filtered, drawn - 1,
    "RespawnPlayerAndOpponent hides the bystanders from the second outro frame")
  T.eq(state.phase, "black", "the outro ends on the black hold")
  local l, b, blackSeq = frame(state)
  T.eq(blackSeq, "", "which is solid black, ball included")
  T.eq(l or b, false, "...no world draw at all")

  while not state.finished do state:update() end
  T.eq(world.bgOverlay, nil, "finish takes the seam back down")
  T.eq(world.spriteFilter, nil, "...and the sprite filter with it")
end

do
  local state, world = make({ trainer = false })
  T.eq(state.phase, "flash", "a wild battle has no ball to stamp")
  local drew, guard = false, 0
  while not state.finished and guard < 400 do
    local _, b = frame(state)
    if b then drew = true end
    state:update()
    guard = guard + 1
  end
  T.eq(drew, false, "and never draws one")
  T.eq(world.bgOverlay, nil, "the seam still comes down at the end")
end

do
  local state = make({ trainer = true, dark = true })
  T.eq(state.phase, "pokeball", "a DARKNESS trainer battle still stamps it")
  pastBall(state)
  T.eq(state.phase, "flash", "DARKNESS still walks the three Flash slots")
  T.eq(state:flashPal(), nil, "...each returning on its first frame")
  T.check((frame(state)), "...with the ball still on screen")
  for _ = 1, Transition.FLASH_CYCLES do state:update() end
  T.eq(state.phase, "outro", "...one frame per slot, then the outro")
end

do
  local state, world = make({
    trainer = true, environment = "CAVE", playerLevel = 10, enemyLevel = 5,
  })
  T.eq(state.style, "sine", "a cave trainer battle wobbles")
  pastBall(state)
  local guard = 0
  while state.phase == "flash" and guard < 400 do
    state:update()
    guard = guard + 1
  end
  T.eq(state:lyOverrides(), nil, "NextScene: no wave yet")
  state:update()
  T.eq(state:lyOverrides(), nil, "SetUpForWavyOutro: still flat")
  state:update()
  T.check(state:lyOverrides() ~= nil, "SineWave from the third outro frame")
  state.quad = { setViewport = function() end }
  local layered, ball, seq = frame(state)
  T.check(ball, "the ball rides the sine outro")
  T.eq(seq, "ground,bgonly,people",
    "the BG is captured without the people, who are drawn flat after")
  T.eq(world.peopleHidden, nil, "and the people flag is not left set")
end

T.finish("gen2 trainer ball lifetime bug 2021")
