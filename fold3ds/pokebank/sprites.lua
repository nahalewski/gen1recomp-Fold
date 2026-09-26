-- emuPoke Bank's Pokemon pictures, #1 to #1025 (Bulbasaur to Pecharunt):
-- PokeAPI's sprites (github.com/PokeAPI/sprites), fetched on the phone the
-- first time each is shown and kept in the save folder (pokebank/sprites/):
--   "box"   the small front sprite, for the boxes
--   "home"  the HOME render (every Pokemon, the Switch era's look), for the
--           picked one on the top screen
-- The same for shinies.  Until one is there, the sheet's silhouette stands in.
local SP = {}

local lg = love.graphics
local BASE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
local cache, asked = {}, {}

local function file(n, kind, shiny)
  return ("pokebank/sprites/%s%s/%d.png"):format(kind, shiny and "_shiny" or "", n)
end

local function url(n, kind, shiny)
  if kind == "home" then return BASE .. "other/home/" .. (shiny and "shiny/" or "") .. n .. ".png" end
  return BASE .. (shiny and "shiny/" or "") .. n .. ".png"
end

function SP.get(n, kind, shiny)
  if not n or n < 1 or n > 1025 then return nil end
  kind = kind or "box"
  local f = file(n, kind, shiny)
  local c = cache[f]
  if c ~= nil then return c or nil end
  if love.filesystem.getInfo(f) then
    local ok, img = pcall(lg.newImage, f)
    cache[f] = ok and img or false
    if ok then img:setFilter(kind == "box" and "nearest" or "linear", kind == "box" and "nearest" or "linear") end
    return ok and img or nil
  end
  if not asked[f] then
    asked[f] = true
    local ok, E = pcall(require, "fold3ds.emucore")
    if ok and E.fetch then pcall(E.fetch, url(n, kind, shiny), f) end
  end
  return nil
end

-- look again for pictures that have arrived since
function SP.refresh()
  for f, v in pairs(cache) do if v == false then cache[f] = nil end end
end

return SP
