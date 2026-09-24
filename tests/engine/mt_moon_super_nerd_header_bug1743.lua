-- #1743: Mt. Moon B2F Super Nerd is text_asm with no def_trainers row, so
-- Yellow never gets trainerHeaders.MtMoonB2F[1]. Without a seed,
-- engageTrainer falls through to the "I like shorts!" fallback.
--
--   luajit tests/engine/mt_moon_super_nerd_header_bug1743.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("mt moon super nerd header #1743")
local check, eq = S.check, S.eq

local Data = require("src.core.Data")

local empty = { trainer_headers = {} }
Data.seedMtMoonB2FSuperNerd(empty)
local seeded = empty.trainer_headers.MtMoonB2F[1]
check(seeded ~= nil, "seed fills MtMoonB2F[1] when missing")
eq(seeded.battle, "_MtMoonB2FSuperNerdTheyreBothMineText",
   "pre-battle text is They're both mine")
eq(seeded.won, "_MtMoonB2FSuperNerdOkIllShareText", "won text seeded")
eq(seeded.after, "_MtMoonB2FSuperNerdTheresAPokemonLabText", "after text seeded")
eq(seeded.event, "EVENT_BEAT_MT_MOON_3_SUPER_NERD",
   "event name matches shipped Red/Blue pin")

-- idempotent: existing header wins
empty.trainer_headers.MtMoonB2F[1] = { battle = "KEEP" }
Data.seedMtMoonB2FSuperNerd(empty)
eq(empty.trainer_headers.MtMoonB2F[1].battle, "KEEP",
   "seed does not overwrite an existing header")

S.finish()
