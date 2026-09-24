-- ../pokecrystal/engine/events/map_name_sign.asm:3

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local engine = "crystal"
package.loaded["src.core.GameVersion"] = {
  engine = function() return engine end,
}
package.loaded["src.render.Assets"] = {
  register = function() end,
  resolve = function(path) return path end,
  exists = function() return false end,
  image = function() error("no sheet in the fixture cache") end,
}
local withCalls = {}
package.loaded["src.render.GbcPalette"] = {
  available = function() return true end,
  with = function(colors, body)
    withCalls[#withCalls + 1] = colors
    body()
    return true
  end,
}
package.loaded["src.render.Font"] = {
  ttfActive = function() return false end,
  encode = function(text)
    local out = {}
    for i = 1, #tostring(text) do out[i] = string.byte(text, i) end
    return out
  end,
  width = function(text) return #tostring(text) * 8 end,
  draw = function() end,
}
package.loaded["src.world.gen2.MapNameSign"] = nil
local Sign = require("src.world.gen2.MapNameSign")

local NAMES = {
  LANDMARK_NEW_BARK_TOWN = "NEW BARK\nTOWN",
  LANDMARK_ROUTE_29 = "ROUTE 29",
  LANDMARK_ROUTE_35 = "ROUTE 35",
  LANDMARK_SPECIAL = "SPECIAL",
  LANDMARK_RADIO_TOWER = "RADIO TOWER",
  LANDMARK_LAV_RADIO_TOWER = "RADIO TOWER",
  LANDMARK_UNDERGROUND_PATH = "UNDERGROUND",
  LANDMARK_INDIGO_PLATEAU = "INDIGO\nPLATEAU",
  LANDMARK_POWER_PLANT = "POWER PLANT",
}

local World = {}
World.__index = World

function World.new(prev)
  return setmetatable({ mapSignState = { prev = prev } }, World)
end

function World:go(mapId, landmark, environment, via)
  self.map = { id = mapId,
    def = { landmark = landmark, environment = environment or "ROUTE" } }
  Sign.init(self, via)
  return self.mapSign
end

function World:currentLandmarkId()
  return self.map and self.map.def and self.map.def.landmark or nil
end

function World:landmarkName()
  return NAMES[self:currentLandmarkId()]
end

local w = World.new("LANDMARK_NEW_BARK_TOWN")
local sign = w:go("ROUTE_29", "LANDMARK_ROUTE_29")
if check(sign ~= nil, "crossing into a new landmark raises the sign") then
  eq(sign.timer, 60, "wLandmarkSignTimer starts at 60")
  eq(sign.name, "ROUTE 29", "the town-map name is what is placed")
end
eq(w.mapSignState.prev, "LANDMARK_ROUTE_29", "wPrevLandmark takes wCurLandmark")

eq(w:go("ROUTE_29", "LANDMARK_ROUTE_29"), nil,
  "a second load inside the same landmark shows nothing")

local nb = World.new("LANDMARK_ROUTE_29")
local sign2 = nb:go("NEW_BARK_TOWN", "LANDMARK_NEW_BARK_TOWN")
if check(sign2 ~= nil, "walking back into New Bark raises the sign") then
  eq(sign2.name, "NEW BARK TOWN", "<BSP> prints as a space, not a line break")
end

local gate = World.new("LANDMARK_ROUTE_29")
eq(gate:go("ROUTE_43_GATE", "LANDMARK_ROUTE_43", "GATE"), nil,
  "a GATE environment takes wCurLandmark to -1")
eq(gate.mapSignState.prev, false, "and -1 is still stamped into wPrevLandmark")

for _, mapId in ipairs({ "ROUTE_35_NATIONAL_PARK_GATE",
                         "ROUTE_36_NATIONAL_PARK_GATE" }) do
  local park = World.new("LANDMARK_ROUTE_29")
  eq(park:go(mapId, "LANDMARK_ROUTE_35", "INDOOR"), nil,
    mapId .. " is forced to -1 by name, not by environment")
end

for _, id in ipairs({ "LANDMARK_SPECIAL", "LANDMARK_RADIO_TOWER",
                      "LANDMARK_LAV_RADIO_TOWER", "LANDMARK_UNDERGROUND_PATH",
                      "LANDMARK_INDIGO_PLATEAU", "LANDMARK_POWER_PLANT" }) do
  local quiet = World.new("LANDMARK_ROUTE_29")
  eq(quiet:go("SOMEWHERE", id), nil, id .. " gets no pop-up sign")
  eq(quiet.mapSignState.prev, id, id .. " is still stamped into wPrevLandmark")
end

local fromSpecial = World.new("LANDMARK_SPECIAL")
eq(fromSpecial:go("ROUTE_29", "LANDMARK_ROUTE_29"), nil,
  "a previous landmark of LANDMARK_SPECIAL suppresses the next sign")

-- ../pokecrystal/engine/menus/intro_menu.asm:467-468
for _, via in ipairs({ "boot", "continue" }) do
  local booted = World.new("LANDMARK_NEW_BARK_TOWN")
  eq(booted:go("ROUTE_29", "LANDMARK_ROUTE_29", "ROUTE", via), nil,
    "the first map load after " .. via .. " shows no sign")
  eq(booted.mapSignState.prev, "LANDMARK_ROUTE_29",
    "but .dont_do_map_sign still stamps wPrevLandmark")
end

-- ../pokecrystal/engine/overworld/events.asm:177-191
local ticker = World.new("LANDMARK_NEW_BARK_TOWN")
ticker:go("ROUTE_29", "LANDMARK_ROUTE_29")
eq(ticker.mapSign.shown, false, "the sign is armed hidden (hWY untouched)")
for _ = 1, 3 do Sign.frame(ticker) end
eq(ticker.mapSign.shown, false, "still hidden after 3 real frames (a = 60)")
Sign.frame(ticker)
eq(ticker.mapSign.shown, true, "shown on the 4th (second HandleMap, a = 59)")
for _ = 5, 121 do Sign.frame(ticker) end
check(ticker.mapSign ~= nil, "the sign is still up after 121 real frames")
Sign.frame(ticker)
eq(ticker.mapSign, nil, "and gone on the 122nd (61st call, a = 0)")

local stepped = World.new("LANDMARK_NEW_BARK_TOWN")
stepped:go("ROUTE_29", "LANDMARK_ROUTE_29")
for _ = 1, 30 do Sign.tick(stepped) end
eq(stepped.mapSign.timer, 60, "the logic step never counts the sign down")
stepped.mapSetup = { phase = "in" }
for _ = 1, 30 do Sign.frame(stepped) end
eq(stepped.mapSign.timer, 60, "nor does a real frame under the map setup fade")
stepped.mapSetup = nil
Sign.frame(stepped)
Sign.frame(stepped)
eq(stepped.mapSign.timer, 59, "the countdown resumes once the setup is done")

-- ../pokecrystal/home/window.asm:42
local talked = World.new("LANDMARK_NEW_BARK_TOWN")
talked:go("ROUTE_29", "LANDMARK_ROUTE_29")
talked.textbox = true
Sign.tick(talked)
eq(talked.mapSign, nil, "a text box takes the sign down")

-- ../pokecrystal/engine/overworld/events.asm:284-285
for _, site in ipairs({ "a battle", "the START menu", "a trainer sighting" }) do
  local pushed = World.new("LANDMARK_NEW_BARK_TOWN")
  check(pushed:go("ROUTE_29", "LANDMARK_ROUTE_29") ~= nil,
    "the sign is up when " .. site .. " arrives")
  Sign.cancel(pushed)
  eq(pushed.mapSign, nil, site .. " clears wLandmarkSignTimer")
  Sign.tick(pushed)
  eq(pushed.mapSign, nil, "and it does not come back after the state pops")
end

local idle = World.new("LANDMARK_NEW_BARK_TOWN")
Sign.cancel(idle)
eq(idle.mapSign, nil, "cancelling with no sign up is a no-op")
Sign.cancel(nil)

local frozen = World.new("LANDMARK_NEW_BARK_TOWN")
local held = frozen:go("ROUTE_29", "LANDMARK_ROUTE_29")
if check(held ~= nil, "a sign raised before a push starts at 60") then
  for _ = 1, 20 do Sign.frame(frozen) end
  eq(held.timer, 50, "twenty real frames are ten HandleMap calls: ten off the timer")
  Sign.cancel(frozen)
  eq(frozen.mapSign, nil,
    "and the remaining 50 are dropped rather than frozen under the push")
end

eq(Sign.textX("NEW BARK TOWN"), 24, "a 13-character name starts at column 3")
eq(Sign.textX("ROUTE 29"), 48, "an 8-character name starts at column 6")
eq(Sign.textX("CHERRYGROVE CITY"), 16, "the longest name starts at column 2")

local rows = Sign.tiles()
eq(rows[0][0], 1, "top left is MAP_NAME_SIGN_START + 1")
eq(rows[0][19], 4, "top right is + 4")
eq(rows[1][0], 5, "left of the first line is + 5")
eq(rows[1][19], 11, "right of the first line is + 11")
eq(rows[2][0], 6, "left of the second line is + 6")
eq(rows[2][19], 12, "right of the second line is + 12")
eq(rows[3][0], 7, "bottom left is + 7")
eq(rows[3][19], 10, "bottom right is + 10")
eq(rows[1][9], 13, ".FillMiddle lays + 13 across the interior")
eq(rows[2][9], 13, "on both interior rows")
local top = {}
for col = 1, 18 do top[col] = rows[0][col] end
eq(table.concat(top, ","), "3,3,2,2,3,3,2,2,3,3,2,2,3,3,2,2,3,3",
  ".FillTopBottom writes +3,+3 then four runs of +2,+2,+3,+3")
local bottom = {}
for col = 1, 18 do bottom[col] = rows[3][col] end
eq(table.concat(bottom, ","), "9,9,8,8,9,9,8,8,9,9,8,8,9,9,8,8,9,9",
  "and the same pattern off + 8 along the bottom")

-- ../pokecrystal/engine/events/map_name_sign.asm:181
-- ../pokecrystal/gfx/tilesets/bg_tiles.pal:9
local TEXT_ROW = {
  { 255, 255, 132 }, { 255, 255, 132 }, { 115, 74, 0 }, { 0, 0, 0 },
}
local fakeSheet = { getDimensions = function() return 14 * 8, 8 end }
local assets = package.loaded["src.render.Assets"]
assets.exists = function() return true end
assets.image = function() return fakeSheet end
local drawn = 0
love.graphics.draw = function() drawn = drawn + 1 end
love.graphics.newQuad = love.graphics.newQuad or function() return {} end
love.graphics.push = love.graphics.push or function() end
love.graphics.pop = love.graphics.pop or function() end
love.graphics.translate = love.graphics.translate or function() end
love.graphics.scale = love.graphics.scale or function() end
love.graphics.setColor = love.graphics.setColor or function() end
local cw = World.new("LANDMARK_NEW_BARK_TOWN")
cw.palettes = { bg = { [8] = TEXT_ROW } }
cw.fitScale = function() return 1 end
cw:go("ROUTE_29", "LANDMARK_ROUTE_29")
Sign.draw(cw, 160, 144, 0)
eq(drawn, 0, "nothing is drawn before PlaceMapNameSign's second call")
for _ = 1, 4 do Sign.frame(cw) end
Sign.draw(cw, 160, 144, 0)
eq(#withCalls, 1, "the sign blits through one GbcPalette.with")
if check(withCalls[1] ~= nil, "with a palette") then
  eq(withCalls[1][1][1], 255, "PAL_BG_TEXT color 0 is cream")
  eq(withCalls[1][1][3], 132, "not white")
  eq(withCalls[1][3][1], 115, "color 2 is the brown frame line")
  eq(withCalls[1][4][1], 0, "color 3 is black")
end
check(drawn >= 80, "all 80 frame tiles were drawn inside the fold")
local noPal = World.new("LANDMARK_NEW_BARK_TOWN")
noPal.fitScale = function() return 1 end
noPal:go("ROUTE_29", "LANDMARK_ROUTE_29")
for _ = 1, 4 do Sign.frame(noPal) end
drawn = 0
Sign.draw(noPal, 160, 144, 0)
eq(#withCalls, 1, "no palette table means a plain blit")
check(drawn >= 80, "and the sign still draws")

engine = "gold"
local gold = World.new("LANDMARK_NEW_BARK_TOWN")
eq(gold:go("ROUTE_29", "LANDMARK_ROUTE_29"), nil,
  "Gold never raises a map name sign")
engine = "crystal"

T.finish("crystal map name sign bug 1943")
