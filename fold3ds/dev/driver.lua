-- Test driver (desktop only, not shipped): POKEPORT_FOLD_TEST=<script>
-- where the script is "frame:action[:arg]" items separated by commas:
--   30:touch:X,Y        press a finger at real-window X,Y for 3 frames
--   30:hold:X,Y,N       hold a finger for N frames
--   30:key:z            love.keypressed / keyreleased
--   60:shot:/tmp/a.png  screenshot
--   200:quit
local D = {}
io.stdout:setvbuf("no")
local frame, actions, fingers, nextId = 0, {}, {}, 1
local function parse(script)
  for item in script:gmatch("[^;]+") do
    local f, act, arg = item:match("^(%d+):(%a+):?(.*)$")
    if f then actions[#actions + 1] = { frame = tonumber(f), act = act, arg = arg } end
  end
  table.sort(actions, function(a, b) return a.frame < b.frame end)
end
function D.start(script, M)
  parse(script)
  M.driverTick = function()
    frame = frame + 1
    if frame % 10 == 0 then print(("driver frame %d t=%.1f fps=%.1f"):format(frame, love.timer.getTime(), love.timer.getFPS())) end
    for _, f in ipairs(fingers) do
      f.left = f.left - 1
      if f.left == 0 then love.touchreleased(f.id, f.x, f.y, 0, 0, 1) end
    end
    for _, a in ipairs(actions) do
      if a.frame == frame then
        print(("driver frame %d t=%.1f %s %s"):format(frame, love.timer.getTime(), a.act, a.arg or ""))
        if a.act == "touch" or a.act == "hold" then
          local x, y, n = a.arg:match("^(%d+)[,@](%d+)[,@]?(%d*)$")
          local id = {}
          nextId = nextId + 1
          fingers[#fingers + 1] = { id = id, x = tonumber(x), y = tonumber(y), left = tonumber(n) or 3 }
          love.touchpressed(id, tonumber(x), tonumber(y), 0, 0, 1)
        elseif a.act == "key" then
          love.keypressed(a.arg, a.arg, false)
          love.keyreleased(a.arg, a.arg)
        elseif a.act == "shot" then
          local path = a.arg
          love.graphics.captureScreenshot(function(img)
            local f = io.open(path, "wb")
            if f then f:write(img:encode("png"):getString()) f:close() end
          end)
        elseif a.act == "drop" then
          local f = love.filesystem.newFile(a.arg)
          love.filedropped(f)
        elseif a.act == "uri" then
          if love.handlers and love.handlers.intent_uri then love.handlers.intent_uri(a.arg) end
        elseif a.act == "quit" then
          love.event.quit()
        end
      end
    end
  end
end
return D
