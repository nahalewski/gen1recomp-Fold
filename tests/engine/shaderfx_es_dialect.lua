
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq

local Fixup = require("src.render.ShaderFixup")

local FIXTURES = "tests/data/shaderfx"
local NAMES = { "bevel", "gameboy", "gb-palette-dmg", "lcd3x", "pixel_transparency", "zfast-lcd" }

local function loadFixture(dialect, name)
  local chunk, err = loadfile(("%s/%s/%s.lua"):format(FIXTURES, dialect, name))
  check(chunk ~= nil, ("fixture %s/%s loads (%s)"):format(dialect, name, tostring(err)))
  return chunk and chunk()
end

local EFFECT_SIG = "EFFECT_PREC vec4 effect(EFFECT_PREC vec4 love_UnusedColor, Image love_UnusedTex, "
  .. "EFFECT_PREC vec2 love_UnusedTc, EFFECT_PREC vec2 love_UnusedSc)"

local function countPlain(s, needle)
  local n, at = 0, 1
  while true do
    local i, j = s:find(needle, at, true)
    if not i then return n end
    n, at = n + 1, j + 1
  end
end

local function checkPass(label, dialect, pass)
  local frag, fragManifest = Fixup.fragment(pass.fragment)
  local vert, vertManifest = Fixup.vertex(pass.vertex)
  eq(#fragManifest, #vertManifest, label .. ": push/UBO manifests agree between stages")
  check(frag:find(EFFECT_SIG, 1, true) ~= nil,
    label .. ": effect()'s return type carries the same EFFECT_PREC head as its parameters")
  check(frag:find(EFFECT_SIG .. "\n{\n    vec4 gbFragColor;", 1, true) ~= nil,
    label .. ": gbFragColor is declared at the top of effect()")
  check(not frag:find("void%s+main") and not vert:find("void%s+main"),
    label .. ": no void main() survives in either stage")
  for _, stage in ipairs({ { "frag", frag }, { "vert", vert } }) do
    local src = stage[2]
    check(not src:find("%f[%w_]uint%f[^%w_]"), label .. " " .. stage[1] .. ": no uint token")
    check(not src:find("#extension", 1, true), label .. " " .. stage[1] .. ": no #extension directive")
    check(not src:find("gl_FragData", 1, true) and not src:find("gl_Position", 1, true),
      label .. " " .. stage[1] .. ": no gl_FragData / gl_Position")
  end
  eq(countPlain(frag, "precision highp float;"), 1,
    label .. ": exactly one default float precision statement (the guarded one)")
  local guardAt = frag:find("#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\nprecision highp int;\n#endif", 1, true)
  check(guardAt ~= nil, label .. ": the highp pair sits under the GL_FRAGMENT_PRECISION_HIGH guard")
  check(not vert:find("precision%s+%a+%s+float"), label .. ": the vertex stage never changes the default precision")
  if dialect == "es" then
    check(not frag:find("texture2DLod", 1, true) and not frag:find("dFdx", 1, true),
      label .. ": ES 1.00 output uses no ES 3 only builtins")
    check(not frag:find("[%w_%)]%s*%%%s*[%w_%(]"), label .. ": ES 1.00 output has no % operator")
  end
end

for _, dialect in ipairs({ "es", "gl" }) do
  for _, name in ipairs(NAMES) do
    local preset = loadFixture(dialect, name)
    if preset then
      eq(preset.pass_count, #preset.passes, ("%s/%s: pass_count matches"):format(dialect, name))
      for i, pass in ipairs(preset.passes) do
        checkPass(("%s/%s pass%d"):format(dialect, name, i - 1), dialect, pass)
      end
    end
  end
end

do
  local raw = 0
  for _, name in ipairs({ "bevel", "gb-palette-dmg", "lcd3x", "zfast-lcd" }) do
    local preset = loadFixture("gl", name)
    local v = preset and preset.passes[1].vertex or ""
    if v:find("uint", 1, true) and v:find("#extension GL_EXT_gpu_shader4", 1, true) then raw = raw + 1 end
  end
  eq(raw, 4, "the GL fixtures really carry the bridge's uint FrameCount + GL_EXT_gpu_shader4 shape")
end

do
  local src = "#extension GL_EXT_gpu_shader4 : require\nuniform uint FrameCount;\nuint x = uint(FrameCount) + uinty;\n"
  local out = Fixup.rewriteGpuShader4(src)
  eq(out, "uniform int FrameCount;\nint x = int(FrameCount) + uinty;\n",
    "rewriteGpuShader4 rewrites whole uint tokens only and drops the extension line")
end

T.finish("shaderfx_es_dialect")
