-- ..(engine/movie/title.asm ln 321 DrawPlayerCharacter, ball at ln 99)
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local P = require("src.render.PaletteFX")
  local GameVersion = require("src.core.GameVersion")
  local TitleState = require("src.ui.TitleState")
  local SHOT_DIR = os.getenv("SHOT_DIR") or "/tmp/shots"

  local REST_OBJ_MIN, REST_OBJ_MAX = 340, 520
  local MENU_OBJ_SLACK = 8
  -- ..(engine/movie/title.asm ln 321): 40x56 at (82,80), plus a margin
  local BAND = { 74, 74, 132, 144 }

  local fails = 0
  local function check(label, ok, detail)
    U.log(ok and "PASS" or "FAIL", label, detail or "")
    if not ok then fails = fails + 1 end
    return ok
  end

  local rendered = 0
  local hostDraw = love.draw
  love.draw = function(...)
    local r = hostDraw(...)
    rendered = rendered + 1
    return r
  end

  local function waitRenderedFrames(frames)
    local target = rendered + (frames or 2)
    for _ = 1, 2400 do
      if rendered >= target then return true end
      U.wait(1)
    end
    return false
  end

  local function waitFor(pred, limit)
    for _ = 1, limit or 1800 do
      if pred() then return true end
      U.wait(1)
    end
    return false
  end

  local function redrawCount(frames)
    local m = 0
    for _ = 1, frames or 4 do
      waitRenderedFrames(1)
      local n = #P.uiSpriteRedraws()
      if n > m then m = n end
    end
    return m
  end

  local objRamp
  local function isObj(R, G, B)
    for _, c in ipairs(objRamp) do
      if math.abs(R - c[1]) <= 12 and math.abs(G - c[2]) <= 12
         and math.abs(B - c[3]) <= 12 then
        return true
      end
    end
    return false
  end

  local function letterbox(img)
    local W, H = img:getWidth(), img:getHeight()
    local x1, y1, x2, y2 = W, H, -1, -1
    for y = 0, H - 1 do
      for x = 0, W - 1 do
        local r, g, b = img:getPixel(x, y)
        if r > 0.02 or g > 0.02 or b > 0.02 then
          if x < x1 then x1 = x end
          if x > x2 then x2 = x end
          if y < y1 then y1 = y end
          if y > y2 then y2 = y end
        end
      end
    end
    local bw, bh = x2 - x1 + 1, y2 - y1 + 1
    if x2 >= x1 and math.abs(bw / 160 - bh / 144) < 0.05 then
      return x1, y1, bh / 144
    end
    local s = math.min(W / 160, H / 144)
    return math.floor((W - 160 * s) / 2), math.floor((H - 144 * s) / 2), s
  end

  local function census(path, bx1, by1, bx2, by2)
    local f = io.open(path, "rb")
    if not f then return nil end
    local bytes = f:read("*a")
    f:close()
    local ok, img = pcall(function()
      return love.image.newImageData(
        love.filesystem.newFileData(bytes, "shot.png"))
    end)
    if not ok or not img then return nil end
    local W, H = img:getWidth(), img:getHeight()
    local ox, oy, scale = letterbox(img)
    local x1 = ox + math.floor((bx1 or 0) * scale)
    local y1 = oy + math.floor((by1 or 0) * scale)
    local x2 = ox + math.ceil((bx2 or 160) * scale) - 1
    local y2 = oy + math.ceil((by2 or 144) * scale) - 1
    local c = { grey = 0, obj = 0, ink = 0, scale = scale, w = W, h = H }
    for y = math.max(0, y1), math.min(H - 1, y2) do
      for x = math.max(0, x1), math.min(W - 1, x2) do
        local r, g, b = img:getPixel(x, y)
        local R = math.floor(r * 255 + 0.5)
        local G = math.floor(g * 255 + 0.5)
        local B = math.floor(b * 255 + 0.5)
        if R == G and G == B and R > 60 and R < 240 then c.grey = c.grey + 1 end
        if R < 30 and G < 30 and B < 30 then c.ink = c.ink + 1 end
        if isObj(R, G, B) then c.obj = c.obj + 1 end
      end
    end
    local d = scale * scale
    c.rawGrey, c.rawObj, c.rawInk = c.grey, c.obj, c.ink
    c.grey = math.floor(c.grey / d + 0.5)
    c.obj = math.floor(c.obj / d + 0.5)
    c.ink = math.floor(c.ink / d + 0.5)
    return c
  end

  local function report(tag, c)
    U.log(string.format(
      "%s: obj=%d grey=%d ink=%d  (raw obj=%d grey=%d at %dx%d, scale %.2f)",
      tag, c.obj, c.grey, c.ink, c.rawObj, c.rawGrey, c.w, c.h, c.scale))
  end

  local version = GameVersion.get()

  U.wait(5)
  U.tap(game, "start")
  local title
  check("reached the title screen", waitFor(function()
    title = game.stack:top()
    return getmetatable(title) == TitleState
  end, 300))
  if getmetatable(title) ~= TitleState then
    U.log("BUG #1214 DRIVER ABORTED: never reached TitleState")
    love.event.quit(1)
    return
  end

  game.save.options.colors = "ogred"
  P.applyOptions(game.save.options)
  check("COLORS is ogred", P.mode == "ogred", P.mode)
  check("usesSpriteObp() true, so the OBJ ramp is baked",
        P.usesSpriteObp() == true)
  objRamp = { P.ogObj()[2], P.ogObj()[3] }
  U.log("version:", tostring(version), "boot-ROM OBJ ramp:",
        string.format("(%d,%d,%d)/(%d,%d,%d)",
          objRamp[1][1], objRamp[1][2], objRamp[1][3],
          objRamp[2][1], objRamp[2][2], objRamp[2][3]))

  check("title reached the loop phase",
        waitFor(function() return title.phase == "loop" end))
  check("mon cycle reached the hold beat",
        waitFor(function() return title.scrollPhase == "hold" end))
  waitRenderedFrames(3)

  local restObj
  do
    check("nothing is occluding the title", game.stack:top() == title
          and title.titleUiBox == nil)
    check("at rest the four player draws are recorded for replay",
          redrawCount(6) == 4, "#" .. #P.uiSpriteRedraws())
    local shot = SHOT_DIR .. "/bug1214_1_ogred_rest.png"
    if U.shot(game, shot) then
      local c = census(shot)
      local band = census(shot, BAND[1], BAND[2], BAND[3], BAND[4])
      report("REST screen", c)
      report("REST player band", band)
      restObj = c.obj
      check("#1214 REST: player wears the boot-ROM OBJ ramp (expect ~427"
            .. " canvas px, 12141 raw on a 1024x768 window)",
            c.obj >= REST_OBJ_MIN and c.obj <= REST_OBJ_MAX, c.obj)
      check("#1214 REST: no DMG grey in the player band (r==g==b, 60<r<240)",
            band.grey == 0, band.grey)
    end
  end

  do
    check("caught the mon sliding through the player bbox",
          waitFor(function()
            return title.scrollPhase == "in" and title.monOffset
                   and title.monOffset >= 10 and title.monOffset <= 60
          end))
    local before = title.monOffset
    local shot = SHOT_DIR .. "/bug1214_2_ogred_midscroll.png"
    if U.shot(game, shot) then
      local c = census(shot)
      local band = census(shot, BAND[1], BAND[2], BAND[3], BAND[4])
      U.log("mid-scroll monOffset:", tostring(before), "->",
            tostring(title.monOffset))
      report("MIDSCROLL screen", c)
      report("MIDSCROLL player band", band)
      check("#1214 MIDSCROLL: no grey leaking through the transparent"
            .. " player sprite (was ~6135 raw px before the replay)",
            band.grey == 0, band.grey)
      check("#1214 MIDSCROLL: player still wears the OBJ ramp",
            c.obj >= REST_OBJ_MIN and c.obj <= REST_OBJ_MAX, c.obj)
    end
  end

  local saveName = require("src.core.SaveData").saveFilename(version)
  do
    check("mon cycle back on the hold beat",
          waitFor(function() return title.scrollPhase == "hold" end))
    waitRenderedFrames(3)
    pcall(function() love.filesystem.write(saveName, "return {}") end)
    title:openMenu()
    waitRenderedFrames(3)
    local menu = game.stack:top()
    local box = menu and menu.titleUiBox
    U.log("menu titleUiBox:", box and table.concat(box, ",") or "nil")
    check("main menu lists CONTINUE, so the box bottom is y 80",
          box ~= nil and box[4] == 9,
          box and tostring(box[4]) or "nil")
    check("#1214 MENU: a box ending at y 80 does not suppress the player,"
          .. " who starts at y 80",
          redrawCount(6) == 4, "#" .. #P.uiSpriteRedraws())
    local shot = SHOT_DIR .. "/bug1214_3_ogred_menu.png"
    if U.shot(game, shot) then
      local c = census(shot)
      local band = census(shot, BAND[1], BAND[2], BAND[3], BAND[4])
      report("MENU screen", c)
      report("MENU player band", band)
      check("#1214 MENU: OBJ ramp count unchanged from rest",
            restObj ~= nil and math.abs(c.obj - restObj) <= MENU_OBJ_SLACK,
            string.format("%d vs rest %d", c.obj, restObj or -1))
      check("#1214 MENU: no DMG grey in the player band",
            band.grey == 0, band.grey)
    end
    game.stack:pop()
    waitRenderedFrames(2)
  end

  do
    local ContinueInfo
    for i = 1, 40 do
      local name, val = debug.getupvalue(TitleState.openMenu, i)
      if not name then break end
      if name == "ContinueInfo" then ContinueInfo = val break end
    end
    check("ContinueInfo class reachable", ContinueInfo ~= nil)
    local info
    if ContinueInfo then
      local ok, st = pcall(ContinueInfo.new, title,
        { player = { name = "RED" }, playTime = 0, pokedex = { owned = {} } })
      check("ContinueInfo.new", ok, not ok and tostring(st) or "")
      if ok then info = st end
    end
    if info then
      check("CONTINUE window box is (4,7)-(19,16)",
            info.titleUiBox and info.titleUiBox[1] == 4
            and info.titleUiBox[2] == 7 and info.titleUiBox[3] == 19
            and info.titleUiBox[4] == 16)
      game.stack:push(info)
      waitRenderedFrames(3)
      check("#1214 CONTINUE: every player draw overlapping the window is"
            .. " suppressed", redrawCount(6) == 0,
            "#" .. #P.uiSpriteRedraws())
      local shot = SHOT_DIR .. "/bug1214_4_ogred_continue.png"
      if U.shot(game, shot) then
        local c = census(shot, 33, 57, 159, 135)
        report("CONTINUE box interior", c)
        check("#1214 CONTINUE: no OBJ ramp bleeding over the window",
              c.obj == 0, c.obj)
        local row = census(shot, 33, 103, 159, 113)
        report("CONTINUE POKeDEX row", row)
        check("#1214 CONTINUE: the POKeDEX row is legible ink, not sprite",
              row.ink > 30 and row.obj == 0,
              string.format("ink=%d obj=%d", row.ink, row.obj))
      end
      game.stack:pop()
      waitRenderedFrames(2)
    end
  end
  pcall(function() love.filesystem.remove(saveName) end)

  do
    for _, mode in ipairs({ "gbc", "og", "og_inv", "gbc_inv", "classic" }) do
      P.applyOptions({ colors = mode })
      waitRenderedFrames(2)
      check(mode .. " records no UI sprite redraws", redrawCount(4) == 0)
    end
    P.applyOptions({ colors = "gbc" })
    check("mon cycle back on the hold beat under gbc",
          waitFor(function() return title.scrollPhase == "hold" end))
    waitRenderedFrames(3)
    local shot = SHOT_DIR .. "/bug1214_5_gbc.png"
    if U.shot(game, shot) then
      local c = census(shot)
      report("GBC", c)
      check("#1214 GBC: the SGB title never wears the boot-ROM OBJ ramp",
            c.obj == 0, c.obj)
    end
  end

  game.save.options.colors = "ogred"
  P.applyOptions(game.save.options)
  waitRenderedFrames(3)

  if fails > 0 then
    U.log("################################################################")
    U.log("#1214 FAILED: " .. fails .. " check(s) above, shots in " .. SHOT_DIR)
    U.log("################################################################")
  else
    U.log("#1214 PASS: all checks, shots in " .. SHOT_DIR)
  end
  U.log("On screen now: the OG RED title in COLORS = OG.  The player and the")
  U.log("pokeball in his hand must be the boot ROM's OBJ ramp (green on Red,")
  U.log("pink on Blue) while the logo, ribbon, cycling mon and copyright line")
  U.log("stay on the BG ramp.  Before #1214 he was BG dark red, and the first")
  U.log("attempt at the fix left grey rectangles around him as mons slid past.")
  U.log("START opens the menu, whose box ends one pixel above his head.")

  while true do
    coroutine.yield()
  end
end
