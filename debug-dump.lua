local ax = require("hs.axuielement")

local function safeAttr(el, name)
  local ok, value = pcall(function()
    return el:attributeValue(name)
  end)
  if ok then return value end
  return nil
end

local function dump(el, depth)
  depth = depth or 0
  if depth > 14 or not el then return end

  local indent = string.rep("  ", depth)
  local role = safeAttr(el, "AXRole")
  local subrole = safeAttr(el, "AXSubrole")
  local title = safeAttr(el, "AXTitle")
  local desc = safeAttr(el, "AXDescription")
  local value = safeAttr(el, "AXValue")
  local help = safeAttr(el, "AXHelp")

  print(
    indent ..
    "role=" .. tostring(role) ..
    " subrole=" .. tostring(subrole) ..
    " title=" .. tostring(title) ..
    " desc=" .. tostring(desc) ..
    " value=" .. tostring(value) ..
    " help=" .. tostring(help)
  )

  for _, child in ipairs(safeAttr(el, "AXChildren") or {}) do
    dump(child, depth + 1)
  end
end

local chrome = hs.application.find("Google Chrome")
if not chrome then
  print("Google Chrome is not running")
  return
end

local appAx = ax.applicationElement(chrome)
for _, win in ipairs(safeAttr(appAx, "AXWindows") or {}) do
  dump(win)
end
