local Kit = require("src.ui.kit.Kit")
local Theme = require("src.ui.kit.Theme")
local Strings = require("src.core.Strings")
local Ui = require("src.import.online.Ui")

local PAL = Theme.PAL

local Room = {}

local function LV() return require("src.import.LauncherView") end
local function OP() return require("src.import.OnlinePanel") end
local function Client() return require("src.online.Client") end

Room.TRADE_STAGE_TEXT = {
  waiting = "Waiting for the other trainer",
  ready = "Both trainers are here",
  battling = "Trade in progress",
  ended = "Trade over",
}

Room.STAGE_TEXT = {
  waiting = "Waiting for a challenger",
  ready = "Both trainers are picking a team",
  battling = "Battle in progress",
  ended = "Match over",
}

function Room.codeCard(imp, x, y, w, m, code, idPrefix, copied)
  local _, gap = Ui.pads(m)
  local rowH = math.max(m.rowH, Kit.tapMin())
  local btnH = math.max(m.btnH, Kit.tapMin())
  local copyW = math.floor(80 * m.s)
  Kit.card(x, y, w, rowH)
  Kit.text("title", tostring(code or "------"), x + math.floor(12 * m.s),
    y + (rowH - Kit.textHeight("title")) / 2, PAL.heading)
  LV().btn(imp, x + w - copyW - math.floor(8 * m.s), y + (rowH - btnH) / 2,
    copyW, btnH, idPrefix .. "-copy", Strings("Copy"),
    { kind = "ghost", font = "small",
      action = function()
        if love.system and love.system.setClipboardText then
          pcall(love.system.setClipboardText, tostring(code or ""))
        end
        local st = OP().state(imp)
        st.status, st.statusOk = Strings(copied), true
      end })
  return rowH + gap
end

function Room.draw(imp, x, y, w, availH, m)
  local OnlinePanel = OP()
  local st = OnlinePanel.state(imp)
  local client = Client()
  local room = client.room()
  local _, gap, tiny = Ui.pads(m)
  local rowH = math.max(m.rowH, Kit.tapMin())
  local btnH = math.max(m.btnH, Kit.tapMin())

  if not room then
    local pending = st.pending
    local line = Strings("You are not in a room.")
    if st.joinWant then
      line = Strings("Joining room %s...", tostring(st.joinWant.code))
    elseif pending and not pending.done then
      line = pending.code
        and Strings("Joining room %s...", tostring(pending.code))
        or Strings("Creating the room...")
    end
    local cy = y + Ui.header(imp, x, y, w, m, Strings("Room"))
    Kit.emptyBox(x, cy, w, rowH * 2, line)
    cy = cy + rowH * 2 + tiny
    cy = cy + Ui.statusLine(imp, x, cy, w, m)
    return cy - y
  end

  local stage = tostring(room.stage or "waiting")
  local trade = tostring(room.intent or "battle") == "trade"
  local cy = y + Ui.header(imp, x, y, w, m,
    trade and Strings("Trade room") or Strings("Room"),
    Strings(trade and (Room.TRADE_STAGE_TEXT[stage] or stage)
      or (Room.STAGE_TEXT[stage] or stage)), PAL.lineStrong)
  cy = cy + Room.codeCard(imp, x, cy, w, m, room.code, "online",
    "Room code copied.")
  cy = cy + Kit.textWrapped("small",
    Strings("Give this code to your friend."), x, cy, w, PAL.muted, 1) + tiny

  if not trade then
    local rule = room.profile and room.profile.rule
    cy = cy + Ui.label(Strings("Rules"), x, cy) + tiny
    cy = cy + Kit.textWrapped("small",
      Strings("%s  -  %s", OnlinePanel.arenaText(room.profile or {}),
        OnlinePanel.ruleText(rule)), x, cy, w, PAL.muted, 1) + tiny
  end

  local deadline = not trade and room.deadlines
    and (room.deadlines.ready or room.deadlines.shot)
  if type(deadline) == "number" then
    local left = OnlinePanel.countdown(deadline, client.serverTime() or 0)
    if left then
      cy = cy + Kit.textWrapped("small", Strings("%ds left", left), x, cy, w,
        left <= 10 and PAL.red or PAL.muted, 1) + tiny
    end
  end

  if OnlinePanel.lastResult then
    cy = cy + Kit.textWrapped("small",
      Strings(OnlinePanel.RESULT_TEXT[OnlinePanel.lastResult]
        or "The match ended."), x, cy, w, PAL.green, 1) + tiny
  end

  local need = st.roomCart
  if need then
    cy = cy + Kit.textWrapped("small",
      Strings("This room plays the %s cart.", tostring(need.id)),
      x, cy, w, PAL.yellow, 2) + tiny
    LV().btn(imp, x, cy, w, btnH, "online-install-cart",
      st.cartInstall and Strings("Installing...") or Strings("Install cart"),
      { kind = "accent", font = "small", enabled = st.cartInstall == nil,
        action = function() OnlinePanel.installCart(imp, need) end })
    cy = cy + btnH + gap
  end

  local me = OnlinePanel.mySeatId()
  local hosting = me ~= nil and room.host == me
  local playing = false
  cy = cy + Ui.label(Strings("Players"), x, cy) + tiny
  for _, player in ipairs(room.players or {}) do
    if me and player.id == me then playing = true end
    Kit.card(x, cy, w, rowH, "badge")
    local text = tostring(player.name or "?")
    if player.verified then text = text .. "  *" end
    if player.online == false then text = text .. Strings("  (away)") end
    Kit.text("small", Kit.ellipsize("small", text, w - math.floor(96 * m.s)),
      x + math.floor(10 * m.s), cy + (rowH - Kit.textHeight("small")) / 2,
      PAL.heading)
    if not trade then
      local tagW = math.floor(74 * m.s)
      Kit.tag(x + w - tagW - math.floor(8 * m.s), cy + (rowH - 18 * m.s) / 2,
        tagW, math.floor(18 * m.s), player.ready and "READY" or "PICKING",
        player.ready and PAL.green or PAL.line)
    end
    cy = cy + rowH + tiny
  end

  if trade then
    cy = cy + Kit.textWrapped("small",
      (#(room.players or {}) < 2)
        and Strings("Waiting for the other trainer.")
        or Strings("Opening the trade..."),
      x, cy, w, PAL.muted, 2) + tiny
    LV().btn(imp, x, cy, w, btnH, "online-leave",
      st.confirmLeave and Strings("Really leave?") or Strings("Leave"),
      { kind = "danger", font = "small",
        action = function()
          if not st.confirmLeave then
            st.confirmLeave = true
            return
          end
          st.confirmLeave, st.ready = nil, false
          client.leaveRoom()
          OnlinePanel.clearPresence()
          OnlinePanel.go(imp, "trade")
        end })
    cy = cy + btnH + tiny
    cy = cy + Ui.statusLine(imp, x, cy, w, m)
    return cy - y
  end

  local spectators = room.spectators or {}
  cy = cy + Ui.label(Strings("Spectators (%d)", #spectators), x, cy) + gap

  local rematch = OnlinePanel.lastResult ~= nil and stage ~= "battling"
  local half = math.floor((w - gap) / 2)
  LV().btn(imp, x, cy, half, btnH, "online-ready",
    st.ready and Strings("Unready")
      or (rematch and Strings("Rematch") or Strings("Ready")),
    { kind = st.ready and "ghost" or "primary", font = "small",
      enabled = playing and stage ~= "battling",
      action = function()
        if st.ready then
          OnlinePanel.unready(imp)
        else
          OnlinePanel.sendReady(imp)
        end
      end })
  LV().btn(imp, x + half + gap, cy, half, btnH, "online-leave",
    st.confirmLeave and Strings("Really leave?") or Strings("Leave"),
    { kind = "danger", font = "small",
      action = function()
        if not st.confirmLeave then
          st.confirmLeave = true
          return
        end
        st.confirmLeave, st.ready = nil, false
        client.leaveRoom()
        OnlinePanel.clearPresence()
        OnlinePanel.go(imp, "play")
      end })
  cy = cy + btnH + tiny

  if hosting then
    LV().btn(imp, x, cy, w, btnH, "online-host-more",
      st.hostMore and Strings("Hide host controls")
        or Strings("Host controls"),
      { kind = "ghost", font = "small",
        action = function() st.hostMore = not st.hostMore end })
    cy = cy + btnH + tiny
    if st.hostMore then
      for _, watcher in ipairs(spectators) do
        local kickW = math.floor(64 * m.s)
        Kit.text("small", Kit.ellipsize("small",
          tostring(watcher.name or "?"), w - kickW), x + math.floor(10 * m.s),
          cy + math.floor(4 * m.s), PAL.muted)
        local id = watcher.id
        LV().btn(imp, x + w - kickW, cy, kickW, btnH,
          "online-kick-" .. tostring(id), Strings("Kick"),
          { kind = "danger", font = "small",
            action = function()
              if type(client.kick) == "function" then pcall(client.kick, id) end
            end })
        cy = cy + btnH + tiny
      end
      LV().btn(imp, x, cy, w, btnH, "online-close-room",
        Strings("Close the room"),
        { kind = "danger", font = "small",
          action = function()
            pcall(client.closeRoom)
            OnlinePanel.go(imp, "play")
          end })
      cy = cy + btnH + tiny
    end
  end
  cy = cy + Ui.statusLine(imp, x, cy, w, m)
  return cy - y
end

return Room
