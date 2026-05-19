local ax = require("hs.axuielement")

local chromeNames = {
  ["Google Chrome"] = true,
  ["Google Chrome Beta"] = true,
  ["Google Chrome Canary"] = true,
  ["Chromium"] = true,
}

local function safeAttr(el, name)
  local ok, value = pcall(function()
    return el:attributeValue(name)
  end)
  if ok then return value end
  return nil
end

local function nonempty(v)
  if type(v) == "string" and v ~= "" then return v end
  if v ~= nil and type(v) ~= "string" then return tostring(v) end
  return nil
end

local function textOf(el)
  return table.concat({
    nonempty(safeAttr(el, "AXTitle")) or "",
    nonempty(safeAttr(el, "AXDescription")) or "",
    nonempty(safeAttr(el, "AXValue")) or "",
    nonempty(safeAttr(el, "AXHelp")) or "",
  }, " ")
end

local function childrenOf(el)
  return safeAttr(el, "AXChildren") or {}
end

local function isDialogContainer(el)
  local role = tostring(safeAttr(el, "AXRole") or "")
  local subrole = tostring(safeAttr(el, "AXSubrole") or "")

  return role == "AXSheet" or
    role == "AXDialog" or
    subrole:find("Dialog", 1, true) ~= nil
end

local function dump(el, depth)
  depth = depth or 0
  if depth > 8 or not el then return end

  local indent = string.rep("  ", depth)
  print(
    indent ..
    "role=" .. tostring(safeAttr(el, "AXRole")) ..
    " subrole=" .. tostring(safeAttr(el, "AXSubrole")) ..
    " text=" .. textOf(el) ..
    " position=" .. hs.inspect(safeAttr(el, "AXPosition")) ..
    " size=" .. hs.inspect(safeAttr(el, "AXSize"))
  )

  for _, child in ipairs(childrenOf(el)) do
    dump(child, depth + 1)
  end
end

local function findDialogs(el, depth)
  depth = depth or 0
  if depth > 20 or not el then return end

  if isDialogContainer(el) then
    print("")
    print("== Dialog-like container ==")
    dump(el)
  end

  for _, child in ipairs(childrenOf(el)) do
    findDialogs(child, depth + 1)
  end
end

print("Chrome dialog debug started")

for _, app in ipairs(hs.application.runningApplications()) do
  if chromeNames[app:name()] then
    print("Checking app: " .. app:name())
    local appAx = ax.applicationElement(app)
    for _, win in ipairs(safeAttr(appAx, "AXWindows") or {}) do
      findDialogs(win)
    end
  end
end
