-- Live PresentProbe driver. Boots far enough to present, waits for the
-- gated/ungated classification (present() block time, not inter-frame gaps),
-- then prints the result and quits.
--
--   cd /home/autumn/src/gen1recomp-gaia
--   POKEPORT_DRIVER=tests/drivers/linux_present_probe.lua POKEPORT_TOUCH=0 \
--     POKEPORT_IDENTITY=linux-present-probe love .
--
-- Force XWayland (common Deck / Gamescope path):
--   SDL_VIDEODRIVER=x11 POKEPORT_DRIVER=... love .

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local LPS = require("src.core.PresentProbe")
  local VSync = require("src.core.VSync")
  local FrameCap = require("src.core.FrameCap")
  local RefreshRate = require("src.core.RefreshRate")

  -- Prefer a known pacing setup so the probe is comparable across runs.
  VSync.apply("on")
  FrameCap.apply(FrameCap.DISPLAY)

  U.log("=== linux present probe start ===")
  U.log("env",
    "XDG_SESSION_TYPE=" .. tostring(os.getenv("XDG_SESSION_TYPE")),
    "WAYLAND_DISPLAY=" .. tostring(os.getenv("WAYLAND_DISPLAY")),
    "DISPLAY=" .. tostring(os.getenv("DISPLAY")),
    "SDL_VIDEODRIVER=" .. tostring(os.getenv("SDL_VIDEODRIVER") or "<unset>"),
    "GAMESCOPE=" .. tostring(os.getenv("GAMESCOPE_WAYLAND_DISPLAY") or ""))

  local function dump(tag)
    local s = LPS.status()
    local hz = RefreshRate.hz()
    U.log(tag,
      "driver=" .. tostring(s.driver),
      "nest=" .. tostring(s.nest),
      "gamescope=" .. tostring(s.gamescope),
      "gated=" .. tostring(s.gated),
      "strategy=" .. tostring(s.strategy),
      "needsSoftwareCap=" .. tostring(s.needsSoftwareCap),
      "probe=" .. tostring(s.probeCount),
      "hz=" .. tostring(hz),
      "vsyncWant=" .. tostring(VSync.isOn()),
      "vsyncEff=" .. tostring(VSync.effective and VSync.effective() or "?"),
      "fpsCap=" .. FrameCap.label(FrameCap.current))
  end

  dump("before-wait")

  -- Probe needs ~45 present samples; give the run loop room past that.
  for i = 1, 120 do
    U.wait(1)
    local s = LPS.status()
    if s.gated ~= nil and i >= 50 then break end
  end

  dump("after-probe")

  local s = LPS.status()
  if not s.linux then
    U.log("RESULT", "FAIL not-linux")
  elseif s.nest == "wayland" and s.strategy == "sdl" and s.gated == true then
    U.log("RESULT", "PASS wayland-sdl-gated (SDL frame wait is doing the work)")
  elseif s.nest == "wayland" and s.needsSoftwareCap then
    U.log("RESULT", "WARN wayland-ungated (SDL vsync ineffective; FrameCap thermal net)")
  elseif (s.nest == "x11" or s.nest == "xwayland") and s.strategy == "sdl" and s.gated == true then
    U.log("RESULT", "PASS " .. s.nest .. "-sdl-gated (GLX swap-interval gating)")
  elseif (s.nest == "x11" or s.nest == "xwayland") and (s.strategy == "oml" or s.strategy == "sgi") then
    U.log("RESULT", "PASS " .. s.nest .. "-glx-" .. s.strategy .. " (real wait bound after ungated probe)")
  elseif s.nest == "xwayland" and s.needsSoftwareCap then
    U.log("RESULT", "PASS xwayland-ungated-softcap (no GLX wait; FrameCap thermal net)")
  elseif (s.nest == "x11" or s.nest == "xwayland") and s.needsSoftwareCap then
    U.log("RESULT", "WARN " .. s.nest .. "-ungated-no-glx (thermal net only; no OML/SGI bind)")
  else
    U.log("RESULT", "INFO see-after-probe-line")
  end

  U.log("=== linux present probe done ===")
  love.event.quit()
end
