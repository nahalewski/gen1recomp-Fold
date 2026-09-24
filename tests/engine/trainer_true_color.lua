-- trainers.trueColor: the same 4-shade opt-out pokemon and sprites already
-- carry, now on the trainers registry.  ROM-free.
--   luajit tests/engine/trainer_true_color.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local BattleState = require("src.battle.BattleState")
local Gen2Battle = require("src.ui.gen2.BattleState")
local Schemas = require("src.mods.Schemas")
local OakSpeech = require("src.ui.OakSpeech")

local spec = Schemas.REGISTRIES.trainers
T.check(spec.fields.trueColor ~= nil,
  "Gen 1 trainers schema lists trueColor")
T.check(Schemas.check(spec, "trainers", "OPP_BROCK",
                      { trueColor = true }, "patch"),
  "a trueColor patch validates")
T.check(not Schemas.check(spec, "trainers", "OPP_BROCK",
                          { trueColor = "yes" }, "patch"),
  "trueColor rejects a non-boolean")

local gen2 = Schemas.shapeFor("trainers", spec, 2)
T.check(gen2.fields.trueColor ~= nil and gen2.fields.pic ~= nil,
  "Gold trainers schema lists pic and trueColor")
T.check(Schemas.check(spec, "trainers", "BEAUTY",
                      { pic = "mods/x/beauty.png", trueColor = true },
                      "patch", 2),
  "a Gold pic+trueColor patch validates")

T.eq(BattleState.trainerTrueColor(nil, nil), false,
  "no trainer is not trueColor")
T.eq(BattleState.trainerTrueColor(nil, { pic = "a.png" }), false,
  "a vanilla portrait is not trueColor")
T.eq(BattleState.trainerTrueColor(nil, { trueColor = true }), true,
  "the record's own flag wins")
T.eq(BattleState.trainerTrueColor(nil, { trueColor = false }), false,
  "explicit false stays false")

local data = {
  trainers = {
    BASE = { pic = "base.png", trueColor = true },
    VANILLA = { pic = "vanilla.png" },
  },
}
T.eq(BattleState.trainerTrueColor(data, { basePic = "BASE" }), true,
  "a basePic reuse inherits the base flag")
T.eq(BattleState.trainerTrueColor(data,
      { basePic = "BASE", trueColor = false }), false,
  "an explicit false on the subclass beats the base")
T.eq(BattleState.trainerTrueColor(data, { basePic = "VANILLA" }), false,
  "reusing a vanilla base stays unshaded-off")

local goldData = {
  gen2Trainers = {
    classes = {
      BEAUTY = { pic = "mods/x/beauty.png", trueColor = true },
      BUG_CATCHER = {},
    },
  },
  gen2MenuGfx = {
    battleHud = {
      trainerPics = {
        BEAUTY = "assets/generated/trainers/beauty.png",
        BUG_CATCHER = "assets/generated/trainers/bug_catcher.png",
      },
    },
  },
}
local beautyPath, beautyTc = Gen2Battle.trainerArt(goldData, "BEAUTY")
T.eq(beautyPath, "mods/x/beauty.png",
  "a class pic wins over the extracted sheet")
T.eq(beautyTc, true, "and keeps trueColor")
local bugPath, bugTc = Gen2Battle.trainerArt(goldData, "BUG_CATCHER")
T.eq(bugPath, "assets/generated/trainers/bug_catcher.png",
  "a class without pic keeps the extracted sheet")
T.eq(bugTc, false, "and is not trueColor")
T.eq(select(1, Gen2Battle.trainerArt(goldData, nil)), nil,
  "no class is no pic")

local game = {
  data = {
    trainers = {
      OPP_BROCK = { pic = "brock.png", trueColor = true },
      OPP_PROF_OAK = { pic = "oak.png", trueColor = true },
    },
  },
}
local _, _, oakTc = OakSpeech.resolvePic(game,
  { type = "trainer", id = "OPP_BROCK" })
T.eq(oakTc, true, "OakSpeech reports a trainer record's trueColor")

T.finish("trainer true color")
