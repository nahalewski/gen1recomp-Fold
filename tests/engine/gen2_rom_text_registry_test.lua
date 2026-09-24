-- Gold has two text datasets: VM script text keyed by bank:address and
-- engine prose keyed by disassembly label.  Their public registries must not
-- alias even though the shared RomText helper reads the latter at data.text.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local RomText = require("src.core.RomText")
local Schemas = require("src.mods.Schemas")

local files = T.sdk.memfs({
  ["mods/rom_text_probe/manifest.json"] = [[{
    "id": "rom_text_probe",
    "name": "Rom Text Probe",
    "version": "1.0.0",
    "entry": "main.lua",
    "api": 2,
    "gen2compat": true
  }]],
  ["mods/rom_text_probe/main.lua"] = [[
    local mod = ...
    mod.content.rom_text:override("_WokeUpText", "{USER} se réveille !")
    mod.content.text:override("55:4067", "SCRIPT PATCH")
  ]],
})

local data = {
  text = { _WokeUpText = "{USER} woke up!" },
  gen2Text = { ["55:4067"] = "SCRIPT BASE" },
}
local run = T.sdk.loadMods({ "mods/rom_text_probe" }, {
  fs = files, data = data, generation = 2,
})

T.eq(#run.errors, 0,
  "the rom_text mod loads cleanly (" .. table.concat(run.errors, "; ") .. ")")
T.eq(Schemas.targetFor("rom_text", Schemas.REGISTRIES.rom_text, 2), "text",
  "rom_text routes to the label-keyed Gen 2 table")
T.eq(Schemas.targetFor("text", Schemas.REGISTRIES.text, 2), "gen2Text",
  "text keeps the VM script table")
T.eq(RomText(run.data, "_WokeUpText", "%s woke up!", "GOLD"),
  "GOLD se réveille !", "RomText consumes the merged rom_text override")
T.eq(run.data.gen2Text["55:4067"], "SCRIPT PATCH",
  "the ordinary text registry still patches Gen 2 script text")
T.eq(run.data.gen2Text._WokeUpText, nil,
  "the rom_text label does not leak into gen2Text")
T.eq(run.data.text["55:4067"], nil,
  "the VM script address does not leak into rom_text")

run.release()
T.finish("gen2_rom_text_registry")
