
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check

local function listLua(dir)
  local out = {}
  local p = io.popen('find "' .. dir .. '" -name "*.lua" | sort')
  if not p then return out end
  for line in p:lines() do out[#out + 1] = line end
  p:close()
  return out
end

local function readAll(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local scanned, shaders = 0, 0
for _, path in ipairs(listLua("src")) do
  local text = readAll(path)
  if text then
    scanned = scanned + 1
    for eq, body in text:gmatch("%[(=*)%[(.-)%]%1%]") do
      if body:find("vec4%s+effect%s*%(") then
        shaders = shaders + 1
        local stmt = body:match("precision%s+%a+%s+float%s*;") or body:match("precision%s+%a+%s+int%s*;")
        check(stmt == nil,
          ("%s: an effect() shader must not change the default precision (found `%s`); "
            .. "LOVE parses effect()'s prototype under its own header first"):format(path, tostring(stmt)))
        local raisedDefault = body:find("precision%s+highp") ~= nil
        local unqualified = body:find("vec4%s+effect%s*%(%s*vec4") ~= nil
        check(not (raisedDefault and unqualified),
          path .. ": effect() parameters unqualified after a precision change would mismatch LOVE's prototype")
      end
    end
  end
end

check(scanned > 100, "the sweep read the source tree (" .. scanned .. " files)")
check(shaders >= 8, "the sweep found the inline effect() shaders (" .. shaders .. ")")

T.finish("shader_no_default_precision")
