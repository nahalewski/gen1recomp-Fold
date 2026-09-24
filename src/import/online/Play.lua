local Kit = require("src.ui.kit.Kit")
local Theme = require("src.ui.kit.Theme")
local Strings = require("src.core.Strings")
local Ui = require("src.import.online.Ui")

local PAL = Theme.PAL

local Play = {}

local function LV() return require("src.import.LauncherView") end
local function OP() return require("src.import.OnlinePanel") end
local function Client() return require("src.online.Client") end

function Play.yourLobby(imp, x, y, w, m)
  local OnlinePanel = OP()
  local c = OnlinePanel.cache(imp)
  local mine = c.mine
  if not mine then return 0 end
  local _, gap, tiny = Ui.pads(m)
  local rowH = math.max(m.rowH, Kit.tapMin())
  local btnH = math.max(m.btnH, Kit.tapMin())
  local h = rowH + btnH + tiny + math.floor(16 * m.s)
  Kit.card(x, y, w, h)
  local tx = x + math.floor(12 * m.s)
  local cy = y + math.floor(8 * m.s)
  Kit.textBold("small", Strings("Your lobby"), tx, cy, PAL.heading)
  cy = cy + Kit.textHeight("small") + tiny
  Kit.text("micro", Kit.ellipsize("micro",
    (mine.players or 0) < 2 and Strings("Waiting for an opponent - code %s",
      tostring(mine.code or "------"))
      or Strings("Code %s", tostring(mine.code or "------")),
    w - math.floor(24 * m.s)), tx, cy, PAL.muted)
  cy = cy + Kit.textHeight("micro") + tiny
  local half = math.floor((w - math.floor(24 * m.s) - gap) / 2)
  LV().btn(imp, tx, cy, half, btnH, "online-mine-return", Strings("Return"),
    { kind = "primary", font = "small",
      action = function() OnlinePanel.go(imp, "room") end })
  LV().btn(imp, tx + half + gap, cy, half, btnH, "online-mine-close",
    Strings("Close"),
    { kind = "danger", font = "small",
      action = function()
        pcall(Client().closeRoom)
        OnlinePanel.invalidate(imp, "lobby")
      end })
  return h + gap
end

function Play.filters(imp, x, y, w, m)
  local OnlinePanel = OP()
  local _, gap, tiny = Ui.pads(m)
  local h = math.max(math.floor(26 * m.s), Kit.tapMin())
  local cy = y + Ui.label(Strings(OnlinePanel.FILTER_LABEL), x, y) + tiny
  local current = OnlinePanel.filter(imp)
  local n = #OnlinePanel.FILTERS
  local chipW = math.floor((w - gap * (n - 1)) / n)
  for i, filter in ipairs(OnlinePanel.FILTERS) do
    local id = filter.id
    if Kit.chip(x + (i - 1) * (chipW + gap), cy, chipW, h,
                Strings(filter.label), current == id, PAL.lineStrong,
                "online-filter-" .. id) then
      LV().queueAction(imp, "online-filter-" .. id, function()
        OnlinePanel.setFilter(imp, id)
      end)
    end
  end
  return (cy - y) + h + tiny
end

function Play.roomList(imp, x, y, w, availH, m, rows, idPrefix, action, label)
  local _, gap, tiny = Ui.pads(m)
  local rowH = math.max(m.rowH, Kit.tapMin())
  local btnH = math.max(m.btnH, Kit.tapMin())
  local online = Client().state() == "online"
  local cy = y
  if #rows == 0 then
    Kit.emptyBox(x, cy, w, rowH * 2, online
      and Strings("No open lobbies right now. Host one and it shows up here.")
      or Strings("Connect to see who is playing."))
    return (rowH * 2) + gap
  end
  imp._pages = imp._pages or {}
  local pageKey = idPrefix
  local perPage = Kit.rowsThatFit(math.max(rowH * 2, availH), rowH, tiny, 2, 10)
  local first, last, pageNow = Kit.pageBounds(imp._pages[pageKey] or 1,
    #rows, perPage)
  imp._pages[pageKey] = pageNow
  local joinW = math.floor(84 * m.s)
  for i = first, last do
    local row = rows[i]
    local ink = LV().rowHit(imp, x, cy, w, rowH, false,
      idPrefix .. "-" .. row.id, nil)
    local tx = x + math.floor(10 * m.s)
    local textW = w - joinW - math.floor(24 * m.s)
    Kit.text("small", Kit.ellipsize("small", row.name, textW), tx,
      cy + math.floor(5 * m.s),
      row.reason and PAL.faint or (ink or PAL.heading))
    if row.verified then
      local bw = math.floor(16 * m.s)
      Kit.tag(tx + Kit.textWidth("small", row.name) + math.floor(6 * m.s),
        cy + math.floor(5 * m.s), bw, math.floor(14 * m.s), "*", PAL.green)
    end
    local sub = row.reason and Strings("Can't join: %s", row.reason)
      or ("%s  %s  %s  %s"):format(row.game, row.arena, row.rule,
        Strings("%d watching", row.spectators))
    if not row.reason and row.note then sub = sub .. "  " .. row.note end
    Kit.text("micro", Kit.ellipsize("micro", sub, textW), tx,
      cy + rowH - Kit.textHeight("micro") - math.floor(5 * m.s),
      row.reason and PAL.yellow or PAL.muted)
    if row.reason == nil then
      local code, rule = row.code, row.ruleTable
      LV().btn(imp, x + w - joinW - math.floor(6 * m.s),
        cy + (rowH - btnH) / 2, joinW, btnH, idPrefix .. "-go-" .. row.id,
        Strings(label),
        { kind = "accent", font = "small", enabled = online,
          action = function() action(code, rule, row) end })
    end
    cy = cy + rowH + tiny
  end
  if #rows > perPage then
    local page, ph = Kit.pager(x, cy, w, pageNow, #rows, perPage, pageKey)
    imp._pages[pageKey] = page
    cy = cy + ph
  end
  return (cy - y) + gap
end

function Play.draw(imp, x, y, w, availH, m)
  local OnlinePanel = OP()
  local st = OnlinePanel.state(imp)
  local c = OnlinePanel.cache(imp)
  local client = Client()
  local _, gap, tiny = Ui.pads(m)
  local btnH = math.max(m.btnH, Kit.tapMin())
  local online = client.state() == "online"
  local version = OnlinePanel.engineVersion(imp)
  local profile = OnlinePanel.myProfile(imp)
  local canBattle = online and OnlinePanel.canBattleWith(version)

  local cy = y + Ui.header(imp, x, y, w, m, Strings("Play"),
    online and "ONLINE" or "OFFLINE", online and PAL.green or PAL.line)

  cy = cy + Play.yourLobby(imp, x, cy, w, m)

  if version and OnlinePanel.isGen2(version) and not OnlinePanel.gen2Battles() then
    cy = cy + Kit.textWrapped("small",
      Strings("Gen 2 battles come later; you can still browse and trade."),
      x, cy, w, PAL.yellow, 2) + tiny
  end

  LV().btn(imp, x, cy, w, btnH, "online-host", Strings("Host a battle"),
    { kind = "primary", font = "small", enabled = canBattle,
      action = function() OnlinePanel.startWizard(imp, "hostBattle") end })
  cy = cy + btnH + gap

  cy = cy + Ui.label(Strings("Join by code"), x, cy) + tiny
  local codeW = math.floor(w * 0.5)
  Ui.field(imp, x, cy, codeW, btnH, "online-code", st.joinCode,
    Strings("Six characters"), imp._onlineFocus == "online-code",
    function(text) st.joinCode = OnlinePanel.sanitizeCode(text) end)
  LV().btn(imp, x + codeW + gap, cy, w - codeW - gap, btnH,
    "online-join-code", Strings("Join"),
    { kind = "accent", font = "small",
      enabled = online and #st.joinCode == OnlinePanel.CODE_LEN,
      action = function() OnlinePanel.startJoin(imp, st.joinCode) end })
  cy = cy + btnH + gap

  local rows = c.rooms
  if #rows > OnlinePanel.FILTER_AT then
    cy = cy + Play.filters(imp, x, cy, w, m)
  end

  cy = cy + Ui.label(Strings("Open lobbies"), x, cy) + tiny
  cy = cy + Play.roomList(imp, x, cy, w,
    math.max(m.rowH * 2, availH - (cy - y) - btnH * 2), m, rows,
    "online-entry", function(code, rule)
      OnlinePanel.startJoin(imp, code, rule)
    end, "Join")

  LV().btn(imp, x, cy, w, btnH, "online-tour-open",
    Strings("Host a tournament"),
    { kind = "ghost", font = "small", enabled = online and profile ~= nil,
      action = function() OnlinePanel.startWizard(imp, "hostTournament") end })
  cy = cy + btnH + tiny
  cy = cy + Ui.statusLine(imp, x, cy, w, m)
  return cy - y
end

return Play
