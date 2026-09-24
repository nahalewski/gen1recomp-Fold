local U = require("tests.drivers.util")
local Fixup = require("src.render.ShaderFixup")
local View = require("src.import.LauncherView")

local FIXTURES = "tests/data/shaderfx"

return function()
  local fails, total = 0, 0
  local realSupported = love.graphics.getSupported

  local function withGlsl3(flag, fn)
    love.graphics.getSupported = function()
      local t = realSupported()
      t.glsl3 = flag
      return t
    end
    local ok, a, b = pcall(fn)
    love.graphics.getSupported = realSupported
    if not ok then error(a, 0) end
    return a, b
  end

  local function report(label, ok, err)
    total = total + 1
    if ok then
      U.log(("PASS %s"):format(label))
    else
      fails = fails + 1
      U.log(("FAIL %s: %s"):format(label, (tostring(err):gsub("%s*\n%s*", " | ")):sub(1, 400)))
    end
  end

  local function validateBoth(label, gles, frag, vert)
    for _, g3 in ipairs({ true, false }) do
      local ok, err = withGlsl3(g3, function()
        return love.graphics.validateShader(gles, frag, vert)
      end)
      report(("%s gles=%s glsl3=%s"):format(label, tostring(gles), tostring(g3)), ok, err)
    end
  end

  validateBoth("CART_HOVER_SHADER", true, View.CART_HOVER_SHADER)
  validateBoth("CART_HOVER_SHADER", false, View.CART_HOVER_SHADER)
  do
    local ok, err = pcall(love.graphics.newShader, View.CART_HOVER_SHADER)
    report("CART_HOVER_SHADER newShader (this desktop)", ok, err)
  end

  for _, dialect in ipairs({ { dir = "es", gles = true }, { dir = "gl", gles = false } }) do
    local dir = FIXTURES .. "/" .. dialect.dir
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    report("fixtures present in " .. dir, #items > 0, "no fixture artifacts")
    for _, name in ipairs(items) do
      if name:match("%.lua$") then
        local chunk, lerr = love.filesystem.load(dir .. "/" .. name)
        report(dir .. "/" .. name .. " loads", chunk ~= nil, lerr)
        if chunk then
          local preset = chunk()
          for i, pass in ipairs(preset.passes) do
            local label = ("%s/%s pass%d"):format(dialect.dir, (name:gsub("%.lua$", "")), i - 1)
            local okF, fragBody, fragManifest = pcall(Fixup.fragment, pass.fragment)
            local okV, vert, vertManifest = pcall(Fixup.vertex, pass.vertex)
            report(label .. " fixup", okF and okV, (not okF and fragBody) or (not okV and vert) or nil)
            if okF and okV then
              report(label .. " manifests agree", #fragManifest == #vertManifest,
                ("frag %d vs vert %d"):format(#fragManifest, #vertManifest))
              for _, g3 in ipairs({ true, false }) do
                local firstOk, errs = nil, {}
                for headIdx, head in ipairs(Fixup.PREC_HEADS) do
                  local ok, err = withGlsl3(g3, function()
                    return love.graphics.validateShader(dialect.gles, head .. fragBody, vert)
                  end)
                  if ok then firstOk = headIdx break end
                  errs[#errs + 1] = ("variant %d: %s"):format(headIdx, tostring(err))
                end
                report(("%s validate gles=%s glsl3=%s"):format(label, tostring(dialect.gles), tostring(g3)),
                  firstOk ~= nil, table.concat(errs, " | "))
              end
              if not dialect.gles then
                local ok, err = pcall(love.graphics.newShader, Fixup.PREC_HEADS[1] .. fragBody, vert)
                if not ok then
                  ok, err = pcall(love.graphics.newShader, Fixup.PREC_HEADS[2] .. fragBody, vert)
                end
                report(label .. " newShader (this desktop)", ok, err)
              end
            end
          end
        end
      end
    end
  end

  local function walk(dir, out)
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
      local rel = dir .. "/" .. name
      local info = love.filesystem.getInfo(rel)
      if info and info.type == "directory" then
        walk(rel, out)
      elseif name:match("%.lua$") then
        out[#out + 1] = rel
      end
    end
  end
  local files = {}
  walk("src", files)
  table.sort(files)
  local literals = 0
  for _, path in ipairs(files) do
    local text = love.filesystem.read(path)
    if text then
      local index = 0
      for eq, body in text:gmatch("%[(=*)%[(.-)%]%1%]") do
        if body:find("vec4%s+effect%s*%(") or body:find("vec4%s+position%s*%(") then
          index = index + 1
          literals = literals + 1
          local label = ("%s literal %d"):format(path, index)
          validateBoth(label, true, body)
          validateBoth(label, false, body)
        end
      end
    end
  end
  report("inline shader literals swept", literals >= 8, ("only %d found"):format(literals))

  U.log(("shader validation: %d checks, %d FAIL"):format(total, fails))
  if fails > 0 then
    error(("shader validation: %d of %d checks failed"):format(fails, total), 0)
  end
end
