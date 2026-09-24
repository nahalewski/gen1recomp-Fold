package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
love = love or require("tests.love_stub")

local Json = require("src.link.Json")
local SaveData = require("src.core.SaveData")
local SaveSerializer = require("src.core.SaveSerializer")
local GameVersion = require("src.core.GameVersion")
local SyncState = require("src.sync.SyncState")
local SyncEngine = require("src.sync.SyncEngine")

local realFS = love.filesystem

local function memfs(files)
  return {
    files = files,
    write = function(path, content) files[path] = content return true end,
    read = function(path) return files[path] end,
    remove = function(path) files[path] = nil return true end,
    createDirectory = function() return true end,
    getInfo = function(path)
      if files[path] then return { type = "file" } end
      return nil
    end,
  }
end

local function fresh()
  local files = {}
  love.filesystem = memfs(files)
  SaveData.resetSlotState()
  GameVersion.set("red")
  return files
end

local function options(files)
  return SaveSerializer.decode(files["options.lua"] or "") or {}
end

local function opaque(id)
  return type(id) == "string" and #id == 32 and id:match("^%x+$") ~= nil
end

local function installCart(id, base)
  local opts = SaveData.loadOptions()
  opts.carts = type(opts.carts) == "table" and opts.carts or {}
  opts.carts[id] = { id = id, title = id:upper(), base = base or "red",
                     file = "carts/" .. id .. ".g1rcart" }
  SaveData.saveOptions(opts)
end

local function plainSave(name, version)
  return {
    version = version or "red",
    meta = {},
    player = { name = name, map = "PALLET_TOWN", x = 1, y = 1 },
    pokedex = { seen = {}, owned = {} },
    inventory = {},
    playTime = 0,
  }
end

do
  local files = fresh()
  installCart("nuzlocke", "red")
  local provider = SyncEngine.defaultSaves()
  T.eq(#provider.list(), 0, "an installed cart with no slots syncs nothing")

  local slotId = SaveData.createCartSlot("nuzlocke")
  SaveData.setActiveCartSlot("nuzlocke", slotId)
  SaveData.setCart("nuzlocke", "cafe0001")
  local save = SaveData.newGame()
  save.player.name = "NUZ"
  save.meta = SaveData.buildMeta({}, save.meta, os.time() - 60)
  T.check(SaveData.save(save), "an in-game save under a sealed cart lands")
  T.check(files["saves/cart_nuzlocke/slot1.lua"] ~= nil,
    "in the cart's own scope, not the version's")
  T.eq(files["saves/red/slot1.lua"], nil, "and nowhere else")
  T.eq(save.meta.cartId, "nuzlocke",
    "the blob names the cart it belongs to, since the wire key cannot")

  local entries = provider.list()
  T.eq(#entries, 1, "the cart slot is offered to sync")
  T.eq(entries[1].cart, "nuzlocke", "tagged with the cart it came from")
  T.eq(entries[1].version, "red",
    "under the base game version, so the server key stays inside 16 chars")
  T.eq(entries[1].slot, slotId, "and the slot it came from")
  local id = entries[1].playthroughId
  T.check(opaque(id), "with an opaque 32-hex identity")
  T.eq(SaveData.loadOptions().playthroughIds.cart_nuzlocke[slotId], id,
    "persisted under the cart scope")
  T.eq(SaveData.loadOptions().playthroughIds.red, nil,
    "and never under the base version")
  T.eq(provider.list()[1].playthroughId, id, "a second listing answers the same id")
end

do
  fresh()
  installCart("nuzlocke", "red")
  local slotId = SaveData.createCartSlot("nuzlocke")
  T.check(SaveData.writeCartSlot("nuzlocke", slotId, plainSave("NUZ")),
    "seed a cart slot that never touched mod storage")

  local entries = SyncEngine.defaultSaves().list()
  T.eq(#entries, 1, "it still syncs")
  T.check(opaque(entries[1].playthroughId), "an identity is minted for it")
  T.eq(SaveData.cartSlotPlaythroughId("nuzlocke", slotId),
    entries[1].playthroughId, "and the cart wrapper answers the same id")
  T.eq(SaveData.slotPlaythroughId("cart_nuzlocke", slotId), nil,
    "while the version API still refuses a cart scope outright")
  T.check(SaveData.readCartSlotSource("nuzlocke", slotId) ~= nil,
    "readCartSlotSource reaches the cart's bytes")
  T.eq(SaveData.readSlotSource("cart_nuzlocke", slotId), nil,
    "which the version reader cannot")
end

do
  local files = fresh()
  installCart("nuzlocke", "red")
  local slotId = SaveData.createCartSlot("nuzlocke")
  T.check(SaveData.writeCartSlot("nuzlocke", slotId, plainSave("OLD")),
    "seed the cart slot")
  local provider = SyncEngine.defaultSaves()
  local entry = provider.list()[1]

  local incoming = plainSave("NEW")
  incoming.meta = { playthroughId = entry.playthroughId, cartId = "nuzlocke" }
  local landed, created, cart = provider.write(
    "red", entry.playthroughId, SaveSerializer.encode(incoming), "replace")
  T.eq(landed, slotId, "a download replaces the cart slot that id belongs to")
  T.eq(created, false, "without allocating a new one")
  T.eq(cart, "nuzlocke", "and reports the cart it landed in")
  T.eq(files["saves/red/slot1.lua"], nil, "no vanilla Red slot is written")
  T.eq(options(files).saveSlots, nil, "and no version registry is invented")
  T.eq(SaveData.listCartSlots("nuzlocke")[1].name, "NEW",
    "the cart slot holds the downloaded save")
end

do
  local files = fresh()
  installCart("nuzlocke", "red")
  local provider = SyncEngine.defaultSaves()
  local incoming = plainSave("REMOTE")
  incoming.meta = { playthroughId = "a1b2", cartId = "nuzlocke" }
  local landed, created, cart = provider.write(
    "red", "a1b2", SaveSerializer.encode(incoming), "replace")
  T.eq(landed, "slot1", "a first cart save on this device allocates a cart slot")
  T.eq(created, true, "and reports it as new")
  T.eq(cart, "nuzlocke", "in the scope the blob names")
  T.check(files["saves/cart_nuzlocke/slot1.lua"] ~= nil,
    "the bytes land under the cart")
  T.eq(files["saves/red/slot1.lua"], nil, "never in a vanilla slot")
  T.eq(options(files).playthroughIds.cart_nuzlocke.slot1, "a1b2",
    "and the mapping is recorded under the cart scope")
end

do
  local files = fresh()
  local provider = SyncEngine.defaultSaves()
  local incoming = plainSave("REMOTE")
  incoming.meta = { playthroughId = "c3d4", cartId = "ghostcart" }
  local landed, why = provider.write(
    "red", "c3d4", SaveSerializer.encode(incoming), "replace")
  T.eq(landed, false, "a save for a cart this device lacks is skipped")
  T.check(tostring(why):find("ghostcart", 1, true) ~= nil,
    "and the reason names the missing cart")
  T.eq(files["saves/red/slot1.lua"], nil, "it is never misfiled into a vanilla slot")
  T.eq(files["saves/cart_ghostcart/slot1.lua"], nil, "nor invented under the cart")
  T.eq(options(files).cartSlots, nil, "and no registry is left behind")
end

do
  local files = fresh()
  installCart("nuzlocke", "red")
  local slotId = SaveData.createCartSlot("nuzlocke")
  T.check(SaveData.writeCartSlot("nuzlocke", slotId, plainSave("SEALED")),
    "seed the cart slot")
  T.eq(SaveData.slotSealBroken("nuzlocke", slotId), false, "the seal starts intact")
  local provider = SyncEngine.defaultSaves()
  local entry = provider.list()[1]

  local opened = plainSave("OPENED")
  opened.meta = { playthroughId = entry.playthroughId, cartId = "nuzlocke",
                  cartHash = "cafe0001", sealBroken = true }
  T.check(provider.write("red", entry.playthroughId,
    SaveSerializer.encode(opened), "replace"), "a seal-broken save downloads")
  T.eq(SaveData.slotSealBroken("nuzlocke", slotId), true,
    "and the receiving device records the broken seal")
  T.eq(options(files).cartSlots.nuzlocke.broken[slotId], true,
    "in the slot registry the launcher and boot read")
  T.eq(SaveData.listCartSlots("nuzlocke")[1].sealBroken, true,
    "so the row no longer reads as sealed")
  T.eq(SaveData.slotCartHash("nuzlocke", slotId), "cafe0001",
    "the build hash rides along")

  local intact = plainSave("AGAIN")
  intact.meta = { playthroughId = entry.playthroughId, cartId = "nuzlocke" }
  T.check(provider.write("red", entry.playthroughId,
    SaveSerializer.encode(intact), "replace"),
    "a later save carrying no flag downloads too")
  T.eq(SaveData.slotSealBroken("nuzlocke", slotId), true,
    "and a broken seal is never un-broken by a download")
end

do
  local files = fresh()
  local slotId = SaveData.createSlot("red")
  SaveData.setActiveSlot("red", slotId)
  local save = SaveData.newGame()
  save.player.name = "ASH"
  save.meta = SaveData.buildMeta({}, save.meta, os.time() - 60)
  T.check(SaveData.save(save), "a vanilla Red save lands")
  T.eq(save.meta.cartId, nil, "with no cart stamped on it")

  installCart("nuzlocke", "red")
  local cartSlot = SaveData.createCartSlot("nuzlocke")
  T.check(SaveData.writeCartSlot("nuzlocke", cartSlot, plainSave("NUZ")),
    "and a cart save beside it")

  local provider = SyncEngine.defaultSaves()
  local byCart = {}
  for _, row in ipairs(provider.list()) do byCart[row.cart or "-"] = row end
  T.check(byCart["-"] ~= nil, "the vanilla slot is listed")
  T.check(byCart.nuzlocke ~= nil, "and the cart slot beside it")

  local vanilla = byCart["-"]
  local incoming = SaveData.decode(vanilla.blob)
  incoming.player.name = "GARY"
  incoming.meta = type(incoming.meta) == "table" and incoming.meta or {}
  incoming.meta.playthroughId = vanilla.playthroughId
  local landed, _, cart = provider.write("red", vanilla.playthroughId,
    SaveSerializer.encode(incoming), "replace")
  T.eq(landed, slotId, "a version-scoped id still routes to its version slot")
  T.eq(cart, nil, "with no cart scope involved")
  T.eq(SaveData.listSlots("red")[1].name, "GARY", "the vanilla slot is rewritten")
  T.eq(SaveData.listCartSlots("nuzlocke")[1].name, "NUZ",
    "and the cart slot is untouched")
  T.eq(files["saves/cart_nuzlocke/slot2.lua"], nil, "no stray cart slot appears")
end

do
  local files = fresh()
  local redSlot = SaveData.createSlot("red")
  T.check(SaveData.writeSlot("red", redSlot, plainSave("ASH")), "seed a Red slot")
  local blueSlot = SaveData.createSlot("blue")
  T.check(SaveData.writeSlot("blue", blueSlot, plainSave("MISTY", "blue")),
    "and a Blue slot holding a save imported from the same .sav")

  local provider = SyncEngine.defaultSaves()
  local byVersion = {}
  for _, row in ipairs(provider.list()) do byVersion[row.version] = row end
  local blueId = byVersion.blue and byVersion.blue.playthroughId
  T.check(opaque(blueId), "the Blue slot carries its own identity")
  T.check(byVersion.red and byVersion.red.playthroughId ~= blueId,
    "distinct from the Red slot's")

  local incoming = plainSave("REMOTE")
  incoming.meta = { playthroughId = blueId }
  local landed, created, cart = provider.write(
    "red", blueId, SaveSerializer.encode(incoming), "replace")
  T.eq(landed, "slot2",
    "an id mapped only under another version never claims an existing Red slot")
  T.eq(created, true, "a fresh slot is allocated for it")
  T.eq(cart, nil, "with no cart scope involved")
  T.eq(SaveData.listSlots("red")[1].name, "ASH",
    "the unrelated Red slot keeps its own save")
  T.check(files["saves/red/slot2.lua"] ~= nil, "the download lands beside it")
  T.eq(SaveData.listSlots("blue")[1].name, "MISTY", "the Blue slot is untouched")
  T.eq(options(files).playthroughIds.blue[blueSlot], blueId,
    "and so is the Blue mapping")
  T.eq(options(files).playthroughIds.red[landed], blueId,
    "while the download is mapped under the version it landed in")
end

do
  fresh()
  GameVersion.set("gold")
  installCart("johtoplus", "gold")
  local slotId = SaveData.createCartSlot("johtoplus")
  T.check(SaveData.writeCartSlot("johtoplus", slotId, plainSave("GOLD", "gold")),
    "seed a Gold cart slot")
  local entries = SyncEngine.defaultSaves().list()
  T.eq(#entries, 1, "a Gen 2 cart save rides the same path")
  T.eq(entries[1].version, "gold", "under its own base version")
  T.eq(entries[1].cart, "johtoplus", "and its own cart id")
end

local function scripted(routes)
  local t = { sent = {}, routes = routes, handles = {} }
  function t:begin(req)
    self.sent[#self.sent + 1] = req
    local path = req.url:match("^[^?]*"):gsub("^http://sync%.test", "")
    local route = self.routes[req.method .. " " .. path]
    if type(route) == "function" then route = route(req, self) end
    route = route or { code = 404, body = '{"error":"no route"}' }
    self.handles[#self.sent] = { status = "ok", code = route.code or 200,
                                 body = route.body or Json.encode(route.data or {}) }
    return #self.sent
  end
  function t:poll(handle) return self.handles[handle] end
  function t:release() end
  return t
end

local function linkedState()
  local state = SyncState.defaults()
  state.account = "aa11bb22cc33dd44"
  state.deviceToken = "tok"
  state.enabled = true
  return state
end

local function engine(routes)
  local transport = scripted(routes)
  return SyncEngine.new({
    baseUrl = "http://sync.test",
    transport = transport,
    state = linkedState(),
    saves = SyncEngine.defaultSaves(),
    persist = false,
    now = function() return 1700001000 end,
  }), transport
end

local function pump(eng, times)
  for _ = 1, (times or 24) do eng:update(0.05) end
end

do
  fresh()
  installCart("nuzlocke", "red")
  local slotId = SaveData.createCartSlot("nuzlocke")
  local seed = plainSave("NUZ")
  seed.meta = { cartId = "nuzlocke", cartHash = "cafe0001" }
  T.check(SaveData.writeCartSlot("nuzlocke", slotId, seed),
    "a sealed cart save exists on this device")
  local id = SaveData.cartSlotPlaythroughId("nuzlocke", slotId)

  local eng, transport = engine({
    ["GET /sync/state"] = { code = 200, body = '{"saves":{}}' },
    ["PUT /sync/save"] = { code = 200, body = '{"ok":true,"rev":1}' },
  })
  eng:syncNow()
  pump(eng)
  T.eq(transport.sent[2] and transport.sent[2].method, "PUT",
    "Sync now uploads the cart save instead of finding nothing to do")
  local sent = Json.decode(transport.sent[2].body) or {}
  T.eq(sent.version, "red",
    "under the base game version the server will accept")
  T.eq(sent.slot, slotId, "naming the cart's own slot")
  T.check(tostring(sent.blob):find("cartId", 1, true) ~= nil,
    "with the cart identity carried inside the blob")
  T.eq(SyncState.rev(eng.state, "red/" .. id), 1,
    "and the served rev is remembered under that key")
  T.eq(eng.phase, "idle", "the run settles")
end

do
  local files = fresh()
  installCart("nuzlocke", "red")
  local incoming = plainSave("REMOTE")
  incoming.meta = { playthroughId = "d00dfeed", cartId = "nuzlocke",
                    savedAt = 1700000000 }
  local blob = SaveSerializer.encode(incoming)

  local eng = engine({
    ["GET /sync/state"] = { code = 200,
      body = '{"saves":{"red/d00dfeed":{"rev":4}}}' },
    ["GET /sync/save"] = { code = 200,
      body = Json.encode({ blob = blob, rev = 4,
                           meta = { savedAt = 1700000000, device = "Android" } }) },
  })
  eng:syncNow()
  pump(eng)
  T.check(files["saves/cart_nuzlocke/slot1.lua"] ~= nil,
    "a remote-only cart save lands in the cart's scope")
  T.eq(files["saves/red/slot1.lua"], nil, "and never in a vanilla Red slot")
  T.eq(eng.phase, "idle", "the run settles")
  local row = eng.lastDownloads and eng.lastDownloads[1]
  T.eq(row and row.cart, "nuzlocke",
    "and the launcher is told which cart to refresh")
end

do
  local files = fresh()
  local incoming = plainSave("REMOTE")
  incoming.meta = { playthroughId = "d00dfeed", cartId = "ghostcart",
                    savedAt = 1700000000 }
  local blob = SaveSerializer.encode(incoming)

  local eng = engine({
    ["GET /sync/state"] = { code = 200,
      body = '{"saves":{"red/d00dfeed":{"rev":4}}}' },
    ["GET /sync/save"] = { code = 200,
      body = Json.encode({ blob = blob, rev = 4, meta = { savedAt = 1700000000 } }) },
  })
  eng:syncNow()
  pump(eng)
  T.eq(files["saves/red/slot1.lua"], nil,
    "a save for a cart this device lacks is never misfiled into Red")
  T.eq(eng.phase, "idle", "the run still settles rather than erroring out")
  T.check(tostring(eng.status):find("ghostcart", 1, true) ~= nil,
    "and the SYNC card names the cart to install")
  T.eq(SyncState.rev(eng.state, "red/d00dfeed"), nil,
    "no rev is recorded, so it arrives once the cart is installed")
end

love.filesystem = realFS
SaveData.resetSlotState()
GameVersion.set("red")

T.finish("sync_cart_saves")
