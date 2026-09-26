-- emuPoke Bank: the Pokemon in a 3DS save (Azahar: the game's "main" file,
-- AeonDX/azahar/data/sdmc/Nintendo 3DS/<id0>/<id1>/title/00040000/<title>/
-- data/00000001/main).
--   Gen 6: X, Y, Omega Ruby, Alpha Sapphire (PK6)
--   Gen 7: Sun, Moon, Ultra Sun, Ultra Moon (PK7)
-- The file is plain (the 3DS decrypts it); told apart by its size and the
-- "BEEF" block table at the end.  Pokemon are encrypted with their
-- encryption constant as the LCG seed.  Offsets from PKHeX (SAV6*.cs,
-- SAV7*.cs, SaveBlockAccessor6*/7*.cs, MyStatus6/7.cs, G6PKM.cs).
--
-- read(bytes) -> nil, why | { gen, game, trainer, tid, sid, mons }
local P = require("fold3ds.pokebank.pkm")

local G = {}
local u8, u16 = P.u8, P.u16

local function fmt(gen)
  return { gen = gen, format = "pk" .. gen, pid = 0x18, moves = 0x5A, iv = 0x74, nick = 0x40, ot = 0xB0,
    nickChars = 13, otChars = 13, text = P.utf16, shinyBelow = 16, levelAt = 0xEC }
end
local PK6, PK7 = fmt(6), fmt(7)

-- by file size: game, format, party, boxes (count), trainer block, its name
local GAMES = {
  [0x65600] = { game = "X / Y", f = PK6, party = 0x14200, box = 0x22600, boxes = 31, status = 0x14000, name = 0x48 },
  [0x76000] = { game = "Omega Ruby / Alpha Sapphire", f = PK6, party = 0x14200, box = 0x33000, boxes = 31,
    status = 0x14000, name = 0x48 },
  [0x6BE00] = { game = "Sun / Moon", f = PK7, party = 0x1400, box = 0x4E00, boxes = 32, status = 0x1200, name = 0x38 },
  [0x6CC00] = { game = "Ultra Sun / Ultra Moon", f = PK7, party = 0x1600, box = 0x5200, boxes = 32,
    status = 0x1400, name = 0x38 },
}

function G.read(b)
  local g = GAMES[#b]
  if not g or b:sub(#b - 0x1F0 + 1, #b - 0x1F0 + 4) ~= "FEEB" then return nil, "not a 3DS Pokemon save" end
  local out = {}
  P.party(b, g.party, u8(b, g.party + 6 * 0x104), 0x104, 0xE8, g.f, out)
  P.boxes(b, g.box, g.boxes, 0xE8, 0xE8, g.f, out)
  return { gen = g.f.gen, game = g.game, trainer = P.utf16(b, g.status + g.name, 13), tid = u16(b, g.status),
    sid = u16(b, g.status + 2), mons = out }
end

return G
