package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
local eq = T.eq

love = love or require("tests.love_stub")

local clock = 0
love.timer = love.timer or {}
local realGetTime = love.timer.getTime
love.timer.getTime = function() return clock end

local Transition = require("src.ui.kit.Transition")
local Kit = require("src.ui.kit.Kit")

local function near(a, b, tol)
  return math.abs(a - b) <= (tol or 1e-9)
end

eq(Transition.ease(0), 0, "the easing starts at zero")
eq(Transition.ease(1), 1, "and ends at one")
check(Transition.ease(0.5) > 0.5, "easeOutCubic runs ahead of linear")
eq(Transition.ease(-1), 0, "a negative input clamps to zero")
eq(Transition.ease(2), 1, "an overshoot clamps to one")

Transition.reset()
Transition.reduceMotion = false
Transition.armed = false

clock = 10
check(not Transition.start("tabs", "tab", { dir = 1 }),
  "an unarmed launcher does not animate")
check(not Transition.active(), "so nothing is running")
eq(Transition.progress("tabs"), 1, "and the layer reads as finished")

Transition.armed = true
clock = 10
check(Transition.start("tabs", "tab", { dir = -1, from = "red", to = "blue" }),
  "an armed launcher starts the tab slide")
check(Transition.active("tabs"), "which is active on its own layer")
check(Transition.active(), "and answers the any-layer question")
eq(Transition.kind("tabs"), "tab", "the kind is kept for the draw")
eq(Transition.dir("tabs"), -1, "and so is the direction")
eq(Transition.progress("tabs"), 0, "progress starts at zero")

clock = 10 + Transition.DURATIONS.tab / 2
Transition.update()
check(Transition.progress("tabs") > 0.5,
  "halfway through the clock the eased progress is past half")
check(Transition.active("tabs"), "and the layer is still running")

clock = 10 + Transition.DURATIONS.tab * 1.5
Transition.update()
eq(Transition.progress("tabs"), 1, "the end of the duration is progress 1")
check(not Transition.active("tabs"), "and the layer retires itself")
eq(Transition.get("tabs"), nil, "a retired layer hands back no record")

-- ------------------------------------------------- one per layer, replaced

clock = 20
Transition.start("online", "push", { dir = 1, from = "home", to = "play" })
clock = 20 + Transition.DURATIONS.push / 2
Transition.update()
check(near(Transition.progress("online"), Transition.ease(0.5)),
  "the online layer eases off its own start time")
Transition.start("online", "pop", { dir = -1, from = "play", to = "home" })
eq(Transition.kind("online"), "pop", "a second start replaces the first")
eq(Transition.progress("online"), 0, "and restarts its clock")
eq(Transition.dir("online"), -1, "with the new direction")

Transition.start("modal", "in")
check(Transition.active("modal") and Transition.active("online"),
  "layers run independently")
eq(Transition.DURATIONS["in"], 0.12, "a modal pops in over 120 ms")
eq(Transition.DURATIONS.out, 0.09, "and out over 90 ms")
eq(Transition.DURATIONS.tab, 0.18, "a tab change takes 180 ms")
eq(Transition.DURATIONS.push, 0.16, "an online push takes 160 ms")
eq(Transition.DURATIONS.pop, 0.16, "and so does a pop")

clock = 30
Transition.update()
check(not Transition.active(), "every layer retires once its time is up")

-- ------------------------------------------------------------ input block

clock = 40
Transition.start("tabs", "tab", { dir = 1 })
Kit.beginFrame(0, 0, false, 0)
check(Kit.blockClicks, "a running transition shields the frame from clicks")
Kit.endFrame()

clock = 40 + Transition.DURATIONS.tab * 1.5
Kit.beginFrame(0, 0, false, 0)
check(not Kit.blockClicks, "and lets go on the frame it ends")
Kit.endFrame()

-- ----------------------------------------------------------- reduce motion

Transition.reduceMotion = true
clock = 50
check(not Transition.start("modal", "in"), "reduce motion refuses to animate")
check(not Transition.active("modal"), "so no transition is running")
eq(Transition.progress("modal"), 1, "and the layer snaps to done")
eq(Transition.kind("modal"), nil, "with no kind for the draw to honour")

Transition.reduceMotion = false
Transition.reset()
Transition.armed = false
love.timer.getTime = realGetTime

T.finish("kit transition")
