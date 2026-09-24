-- ../pokecrystal/home/text.asm:548 PromptText, :566 DoneText

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local Gen2Compat = require("src.mods.Gen2Compat")

local TEXT = {
  ["03:4d41"] = "{STRBUF} used\nSTRENGTH!{DONE}",
  ["03:4d46"] = "{STRBUF} can\nmove boulders.{PROMPT}",
  ["09:6f9b"] = "It's the TOWN MAP.{DONE}",
  ["0f:0000"] = "No terminator at all",
  labels = { _UsedStrengthText = "03:4d41" },
}

local game = { data = { gen2Text = TEXT, pokemon = {} } }
Gen2Compat.bind(function() return game end)

local facade = Gen2Compat.resolve("src.core.Game", "text_probe")
T.check(facade ~= nil, "the Game facade builds")

local text = facade.data.text
T.check(type(text) == "table", "data.text is the renamed gen2Text table")
T.eq(text["03:4d41"], "{STRBUF} used\nSTRENGTH!",
  "DoneText's $57 is gone from the line a mod prints")
T.eq(text["03:4d46"], "{STRBUF} can\nmove boulders.",
  "and PromptText's $58")
T.eq(text["09:6f9b"], "It's the TOWN MAP.", "one-line text too")
T.eq(text["0f:0000"], "No terminator at all", "a line without one is untouched")
T.eq(text.labels and text.labels._UsedStrengthText, "03:4d41",
  "the label index is not text and comes through as it is")

local seen = 0
for _ in pairs(text) do seen = seen + 1 end
T.eq(seen, 5, "and the table still iterates: four lines and the labels")

T.eq(TEXT["03:4d41"], "{STRBUF} used\nSTRENGTH!{DONE}",
  "the engine's own table keeps the terminator TextBox.ending reads")
T.eq(facade.data.text, text, "the stripped table is made once")

Gen2Compat.bind(function() return nil end)

T.finish("gen2 mod text terminator")
