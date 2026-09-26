-- Game Link: the link cable, over the network, for games that had one.
-- Two phones running AeonDX play as if a cable joined them: trade and
-- battle in Pokemon, head-to-head Tetris, and whatever else the game did
-- over its link port.  It is the GB-Link idea (gblink.io) with the phone
-- as the adapter, so no board and no computer are needed between phones.
--
-- It opens from a game's pause menu (HOME) on the 3DS HOME menu and on the
-- Switch skin, as the "Game Link" row, which only appears when the
-- emulator can link that game.  The emulator (a fold3ds.emus provider)
-- does the linking; this is its panel:
--
--   p.link(t) -> nil when the game can't link, else
--     { state = "off" | "hosting" | "joining" | "paired" | "error",
--       code = "AB12CD" (hosting online: the room code to give a friend),
--       address = "192.168.1.20:7777" (hosting on this Wi-Fi),
--       peer = "their game's name", msg = "what went wrong" }
--   p.linkDo(action, arg): "host_online", "host_lan", "join" (arg: a room
--     code or an ip:port), "stop"
--
-- The panel: Host online (a code), Host on this Wi-Fi (an address), Join
-- (a keypad for either), the link's state, Stop, and the manual.
local GL = {}

local lg = love.graphics

local ctx = { font = function(s) return lg.newFont(math.max(6, math.floor(s))) end }
local st = { open = false, page = "main", entry = "", hits = {}, touches = {}, manual = 1 }

local KEYS = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
  "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V",
  "W", "X", "Y", "Z", ".", ":", "DEL", "OK",
}

GL.MANUAL = {
  { title = "Playing with a friend",
    text = "Both of you need AeonDX and the game (Pokemon Red and Blue link like the real "
      .. "carts did; so do Gold, Silver and Crystal, and Ruby, Sapphire, Emerald, FireRed "
      .. "and LeafGreen).  The gen1recomp Pokemon games have their own link in their "
      .. "Cable Club, with the same Host and Join.\n\n"
      .. "3DS HOME Menu: start the game, press HOME (the button under the bottom screen) and "
      .. "pick Game Link.\n"
      .. "Switch skin: start the game, press HOME (or +) and pick Game Link.\n\n"
      .. "One of you hosts, the other joins.  Then walk into the Cable Club (or the game's "
      .. "own link menu) together, as you would with a cable plugged in." },
  { title = "Hosting and joining",
    text = "Host online: you get a six-letter room code.  Tell it to your friend; they pick "
      .. "Join and type it.  Works anywhere with internet, through any router.\n\n"
      .. "Host on this Wi-Fi: for two phones on the same network.  You get an address "
      .. "(like 192.168.1.20:7777); your friend picks Join and types it.  Faster, and no "
      .. "internet needed.\n\n"
      .. "When the panel says Linked, close it (B) and play.  Stop ends the link.  Keep "
      .. "the game open on both phones until the trade or battle is over." },
  { title = "Games that link",
    text = "Game Boy / Game Boy Color: Pokemon Red, Blue, Yellow, Gold, Silver and Crystal "
      .. "(trades, battles, the Time Capsule between them), Tetris, Dr. Mario, and most "
      .. "two-player link-cable games.\n\n"
      .. "Game Boy Advance: Pokemon Ruby, Sapphire, Emerald, FireRed and LeafGreen (Cable "
      .. "Club trades and battles), Advance Wars 1 and 2, and other two-player link-cable "
      .. "games.\n\n"
      .. "The Game Link row only shows for a game the emulator can link." },
  { title = "Real consoles",
    text = "Coming, not in this build yet:\n\n"
      .. "Nintendo DS: DS games that went online (Pokemon Diamond to White 2 and more) "
      .. "reaching real DS and 3DS consoles through the revived Nintendo Wi-Fi Connection "
      .. "(WiiLink WFC / Wiimmfi): GTS, Wi-Fi Club and online trades.\n\n"
      .. "Nintendo Switch / Switch 2: their local wireless can't be reached by a phone on "
      .. "its own; Android does not let apps send raw Wi-Fi frames.  FireRed and "
      .. "LeafGreen on Switch trade with GBA games through a small ESP32 board "
      .. "(switch.gblink.io), which AeonDX could drive over USB instead of a computer.\n\n"
      .. "Real Game Boys: a GB-Link USB adapter plugged into the phone, linking a real "
      .. "console to the game in AeonDX." },
}

function GL.init(context) for k, v in pairs(context or {}) do ctx[k] = v end end
function GL.isOpen() return st.open end

-- can this game link? (the pause menu's Game Link row)
function GL.linkable(p, t)
  if not (p and p.link and p.linkDo) then return false end
  local ok, l = pcall(p.link, t)
  return ok and type(l) == "table"
end

function GL.open(p, t)
  st.open, st.p, st.t, st.page, st.entry = true, p, t, "main", ""
end

function GL.close() st.open, st.p, st.t = false, nil, nil end

local function link()
  if not st.p then return nil end
  local ok, l = pcall(st.p.link, st.t)
  return ok and type(l) == "table" and l or nil
end

local function act(action, arg)
  if st.p and st.p.linkDo then pcall(st.p.linkDo, action, arg) end
  if ctx.sfx then ctx.sfx("select") end
end

local function hit(id, x, y, w, h) st.hits[#st.hits + 1] = { id = id, x = x, y = y, w = w, h = h } end

local function button(id, label, x, y, w, h, primary, on)
  if primary then lg.setColor(0.2, 0.55, 0.95, 1) else lg.setColor(1, 1, 1, 1) end
  lg.rectangle("fill", x, y, w, h, h * 0.25, h * 0.25)
  if on then
    lg.setColor(0.2, 0.55, 0.95, 1)
    lg.setLineWidth(2)
    lg.rectangle("line", x, y, w, h, h * 0.25, h * 0.25)
  end
  local f = ctx.font(h * 0.38)
  lg.setFont(f)
  if primary then lg.setColor(1, 1, 1, 1) else lg.setColor(0.2, 0.22, 0.28, 1) end
  lg.printf(label, x, y + (h - f:getHeight()) / 2, w, "center")
  hit(id, x, y, w, h)
end

local STATE = {
  off = "Not linked",
  hosting = "Waiting for your friend...",
  joining = "Joining...",
  paired = "Linked!  Close this and play",
  error = "The link stopped",
}

local function drawMain(r, pad)
  local l = link() or { state = "off" }
  local y = r.y + r.h * 0.2
  local f = ctx.font(r.h * 0.06)
  lg.setFont(f)
  lg.setColor(0.2, 0.22, 0.28, 1)
  lg.printf(STATE[l.state] or tostring(l.state), r.x + pad, y, r.w - pad * 2, "center")
  y = y + f:getHeight() * 1.3
  local big = ctx.font(r.h * 0.1)
  local show = l.code or l.address
  if (l.state == "hosting" or l.state == "paired") and show then
    lg.setFont(big)
    lg.setColor(0.2, 0.55, 0.95, 1)
    lg.printf(show, r.x + pad, y, r.w - pad * 2, "center")
    y = y + big:getHeight() * 1.2
  elseif l.msg and l.msg ~= "" then
    lg.setColor(0.75, 0.25, 0.25, 1)
    lg.printf(l.msg, r.x + pad, y, r.w - pad * 2, "center")
    y = y + f:getHeight() * 2.4
  else
    y = y + big:getHeight() * 1.2
  end
  local bw, bh = (r.w - pad * 3) / 2, r.h * 0.12
  if l.state == "off" or l.state == "error" then
    button("host_online", "Host online", r.x + pad, y, bw, bh, true)
    button("host_lan", "Host on this Wi-Fi", r.x + pad * 2 + bw, y, bw, bh, false)
    y = y + bh + pad * 0.6
    button("join", "Join", r.x + pad, y, bw, bh, false)
  else
    button("stop", "Stop", r.x + pad, y, bw, bh, false)
  end
  button("manual", "Manual", r.x + pad * 2 + bw, y, bw, bh, false)
end

local function drawJoin(r, pad)
  local f = ctx.font(r.h * 0.055)
  lg.setFont(f)
  lg.setColor(0.2, 0.22, 0.28, 1)
  lg.printf("Your friend's room code, or their address on this Wi-Fi", r.x + pad, r.y + r.h * 0.17, r.w - pad * 2, "center")
  local bx, by, bw, bh = r.x + pad, r.y + r.h * 0.27, r.w - pad * 2, r.h * 0.11
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", bx, by, bw, bh, bh * 0.2, bh * 0.2)
  local vf = ctx.font(bh * 0.6)
  lg.setFont(vf)
  lg.setColor(0.15, 0.15, 0.18, 1)
  local caret = (love.timer.getTime() % 1 < 0.5) and "|" or ""
  lg.printf(st.entry .. caret, bx, by + (bh - vf:getHeight()) / 2, bw, "center")
  -- the keypad: 10 across
  local top = by + bh + pad * 0.6
  local kw = (r.w - pad * 2) / 10
  local kh = math.min(kw * 0.8, (r.y + r.h - pad - top) / 4)
  for i, k in ipairs(KEYS) do
    local c = (i - 1) % 10
    local row = math.floor((i - 1) / 10)
    local w = kw
    local x = r.x + pad + c * kw
    if k == "DEL" or k == "OK" then
      w = kw * 2
      x = r.x + pad + (k == "DEL" and 6 or 8) * kw
    end
    button("key:" .. k, k, x + 2, top + row * kh + 2, w - 4, kh - 4, k == "OK")
  end
end

local function drawManual(r, pad)
  local m = GL.MANUAL[st.manual]
  local tf = ctx.font(r.h * 0.065)
  lg.setFont(tf)
  lg.setColor(0.2, 0.22, 0.28, 1)
  lg.printf(("%s  (%d/%d)"):format(m.title, st.manual, #GL.MANUAL), r.x + pad, r.y + r.h * 0.16, r.w - pad * 2, "left")
  local f = ctx.font(r.h * 0.047)
  lg.setFont(f)
  lg.setColor(0.25, 0.27, 0.32, 1)
  lg.printf(m.text, r.x + pad, r.y + r.h * 0.16 + tf:getHeight() * 1.4, r.w - pad * 2, "left")
  local bw, bh = r.w * 0.2, r.h * 0.1
  if st.manual > 1 then button("mprev", "<", r.x + pad, r.y + r.h - bh - pad * 0.5, bw, bh, false) end
  if st.manual < #GL.MANUAL then button("mnext", ">", r.x + r.w - pad - bw, r.y + r.h - bh - pad * 0.5, bw, bh, true) end
end

function GL.draw(r)
  st.hits = {}
  if not st.open then return end
  lg.push("all")
  lg.setScissor(r.x, r.y, r.w, r.h)
  lg.setColor(0.96, 0.97, 0.98, 1)
  lg.rectangle("fill", r.x, r.y, r.w, r.h)
  local pad = math.floor(r.w * 0.04)
  -- the bar: Back and the title
  local bh = math.floor(r.h * 0.13)
  lg.setColor(0.86, 0.88, 0.92, 1)
  lg.rectangle("fill", r.x, r.y, r.w, bh)
  local bw = r.w * 0.2
  button("back", "Back", r.x + 6, r.y + bh * 0.15, bw, bh * 0.7, true)
  local f = ctx.font(bh * 0.36)
  lg.setFont(f)
  lg.setColor(0.2, 0.22, 0.28, 1)
  local title = "Game Link" .. (st.t and st.t.name and ("  -  " .. st.t.name) or "")
  lg.printf(title, r.x + bw + 12, r.y + (bh - f:getHeight()) / 2, r.w - bw - 24, "center")
  if st.page == "join" then drawJoin(r, pad)
  elseif st.page == "manual" then drawManual(r, pad)
  else drawMain(r, pad) end
  lg.pop()
end

local function back()
  if st.page ~= "main" then st.page = "main" else GL.close() end
  if ctx.sfx then ctx.sfx("back") end
end

local function press(id)
  if id == "back" then back()
  elseif id == "host_online" or id == "host_lan" or id == "stop" then act(id)
  elseif id == "join" then st.page, st.entry = "join", ""
  elseif id == "manual" then st.page, st.manual = "manual", 1
  elseif id == "mprev" then st.manual = math.max(1, st.manual - 1)
  elseif id == "mnext" then st.manual = math.min(#GL.MANUAL, st.manual + 1)
  elseif id:match("^key:") then
    local k = id:sub(5)
    if k == "DEL" then st.entry = st.entry:sub(1, -2)
    elseif k == "OK" then
      if #st.entry > 0 then act("join", st.entry); st.page = "main" end
    elseif #st.entry < 21 then st.entry = st.entry .. k end
  end
end

local function hitAt(x, y)
  for k = #st.hits, 1, -1 do
    local h = st.hits[k]
    if x >= h.x and y >= h.y and x <= h.x + h.w and y <= h.y + h.h then return h end
  end
end

function GL.touch(phase, id, x, y)
  if phase == "pressed" then
    local h = hitAt(x, y)
    st.touches[id] = h and h.id
  elseif phase == "released" then
    local want = st.touches[id]
    st.touches[id] = nil
    local h = hitAt(x, y)
    if want and h and h.id == want then press(want) end
  end
end

function GL.button(btn)
  if btn == "b" or btn == "home" then back()
  elseif st.page == "manual" and btn == "left" then press("mprev")
  elseif st.page == "manual" and (btn == "right" or btn == "a") then press("mnext") end
end

return GL
