-- AeonDX's own apps in the Nintendo eShop (fold3ds/eshop.lua): listed on
-- its shelves beside the mods, and put on the HOME menu once downloaded
-- (the 3DS HOME menu's applet bar, the Switch skin's system row).  Their
-- code is in the app already; downloading adds them to the menus, and what
-- they fetch themselves (emuPoke Bank's Pokemon pictures) comes on first
-- use.  Kept in fold3ds_apps.cfg: one installed id per line.
local A = {}

local FILE = "fold3ds_apps.cfg"

A.LIST = {
  { id = "app:pokebank", app = "pokebank", title = "emuPoke Bank", author = "AeonDX",
    icon = "fold3ds/pokebank/ui/app_icon_l.png",
    summary = "A Pokemon Bank for every game's save: bring your Pokemon in from the Game Boy, "
      .. "Game Boy Color and Game Boy Advance games (DS, 3DS and Switch as they come), keep "
      .. "them in 100 boxes, and see them with their HOME pictures." },
}

local installed

local function load()
  if installed then return installed end
  installed = {}
  local ok, text = pcall(love.filesystem.read, FILE)
  for line in ((ok and text) or ""):gmatch("[^\r\n]+") do installed[line] = true end
  return installed
end

local function save()
  local out = {}
  for id in pairs(load()) do out[#out + 1] = id end
  table.sort(out)
  pcall(love.filesystem.write, FILE, table.concat(out, "\n") .. "\n")
end

function A.installed(app) return load()[app] == true end
function A.install(app) load()[app] = true; save() end
function A.remove(app) load()[app] = nil; save() end

-- the eShop entry for an app id ("pokebank"), or nil
function A.entry(app)
  for _, e in ipairs(A.LIST) do if e.app == app then return e end end
end

return A
