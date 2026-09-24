return function(game)
  local U = dofile("tests/drivers/util.lua")
  local FrameCap = require("src.core.FrameCap")
  local RefreshRate = require("src.core.RefreshRate")
  local VSync = require("src.core.VSync")
  local PresentSync = require("src.core.PresentSync")

  local FRAMES = 300

  U.log("MAX FPS reads", FrameCap.label(game.save.options.fpsCap),
        "live cap", FrameCap.current,
        "(0 = DISPLAY, no software pacing)")
  U.log("VSYNC reads", VSync.label(game.save.options.vsync),
        "driver says",
        (love.window.getVSync and tostring(love.window.getVSync())) or "unknown")

  local sync = PresentSync.status()
  U.log("PresentSync",
        "linux=" .. tostring(sync.linux),
        "driver=" .. tostring(sync.driver),
        "nest=" .. tostring(sync.nest),
        "gamescope=" .. tostring(sync.gamescope),
        "gated=" .. tostring(sync.gated),
        "strategy=" .. tostring(sync.strategy),
        "needsSoftwareCap=" .. tostring(sync.needsSoftwareCap),
        "probe=" .. tostring(sync.probeCount))

  local snapped = dofile("src/core/FixedStep.lua")
  local bare = dofile("src/core/FixedStep.lua")
  local snappedSteps, bareSteps = 0, 0
  snapped:init(function() snappedSteps = snappedSteps + 1 end)
  bare:init(function() bareSteps = bareSteps + 1 end)

  local hist, worstRun, run = {}, 0, 0
  local margin, total = 1, 0
  local last = love.timer.getTime()
  for _ = 1, FRAMES do
    U.wait(1)
    local now = love.timer.getTime()
    local dt = now - last
    last = now
    total = total + dt
    RefreshRate.sample(dt)
    snapped.refreshPeriod = require("src.core.PresentSync").logicRefreshPeriod()
    local before = snappedSteps
    snapped:update(dt)
    bare:update(dt)
    local n = snappedSteps - before
    hist[n] = (hist[n] or 0) + 1
    run = (n == 0) and run + 1 or 0
    if run > worstRun then worstRun = run end
    local residual = snapped.accum % snapped.STEP
    margin = math.min(margin, residual, snapped.STEP - residual)
  end

  sync = PresentSync.status()
  U.log("PresentSync after",
        "gated=" .. tostring(sync.gated),
        "strategy=" .. tostring(sync.strategy),
        "needsSoftwareCap=" .. tostring(sync.needsSoftwareCap),
        "probe=" .. tostring(sync.probeCount))

  local hz = RefreshRate.hz()
  U.log("SDL/measured refresh", hz and string.format("%.2fHz", hz) or "unknown",
        "measured present rate",
        string.format("%.2fHz", FRAMES / math.max(total, 1e-6)))
  U.log("mismatch (not a multiple of 60Hz)",
        tostring(RefreshRate.mismatch() ~= nil))
  local counts = {}
  for n = 0, 4 do
    if hist[n] then counts[#counts + 1] = n .. "x" .. hist[n] end
  end
  U.log("steps per display frame", table.concat(counts, " "))
  U.log("longest run of duplicated frames", worstRun)
  U.log("snapped steps", snappedSteps, "unsnapped steps", bareSteps,
        "expected", math.floor(total * 60 + 0.5))
  U.log("closest the accumulator came to the step boundary",
        string.format("%.3fms", margin * 1000))

  U.log("watch the overworld scroll now; PASS is even motion, FAIL is a",
        "two-fast-one-stalled beat")
end
