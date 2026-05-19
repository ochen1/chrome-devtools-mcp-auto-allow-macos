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

local function safeAction(el, name)
  local ok, a, b, c = pcall(function()
    return el:performAction(name)
  end)
  return ok, a, b, c
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

local function actionsOf(el)
  local ok, actions = pcall(function()
    return el:actionNames()
  end)
  if ok then return actions or {} end
  return {}
end

local function containsText(el, needle, depth)
  depth = depth or 0
  if depth > 20 or not el then return false end

  if textOf(el):find(needle, 1, true) then
    return true
  end

  for _, child in ipairs(childrenOf(el)) do
    if containsText(child, needle, depth + 1) then
      return true
    end
  end

  return false
end

local function findButtonByText(el, wantedText, depth)
  depth = depth or 0
  if depth > 20 or not el then return nil end

  local role = tostring(safeAttr(el, "AXRole") or "")
  local text = textOf(el)

  if role == "AXButton" and text:find(wantedText, 1, true) then
    return el
  end

  for _, child in ipairs(childrenOf(el)) do
    local found = findButtonByText(child, wantedText, depth + 1)
    if found then return found end
  end

  return nil
end

local function isDialogContainer(el)
  local role = tostring(safeAttr(el, "AXRole") or "")
  local subrole = tostring(safeAttr(el, "AXSubrole") or "")

  return role == "AXSheet" or
    role == "AXDialog" or
    subrole:find("Dialog", 1, true) ~= nil
end

local function findApprovalDialog(el, depth)
  depth = depth or 0
  if depth > 20 or not el then return nil end

  if isDialogContainer(el) then
    local isDialog =
      containsText(el, "Allow remote debugging?") or
      containsText(el, "An external app wants full control") or
      containsText(el, "remote debugging")

    if isDialog then
      return el
    end
  end

  for _, child in ipairs(childrenOf(el)) do
    local found = findApprovalDialog(child, depth + 1)
    if found then return found end
  end

  return nil
end

local function describe(el, label)
  print("")
  print("== " .. label .. " ==")
  print("role=" .. tostring(safeAttr(el, "AXRole")))
  print("subrole=" .. tostring(safeAttr(el, "AXSubrole")))
  print("title=" .. tostring(safeAttr(el, "AXTitle")))
  print("description=" .. tostring(safeAttr(el, "AXDescription")))
  print("value=" .. tostring(safeAttr(el, "AXValue")))
  print("help=" .. tostring(safeAttr(el, "AXHelp")))
  print("enabled=" .. tostring(safeAttr(el, "AXEnabled")))
  print("focused=" .. tostring(safeAttr(el, "AXFocused")))
  print("position=" .. hs.inspect(safeAttr(el, "AXPosition")))
  print("size=" .. hs.inspect(safeAttr(el, "AXSize")))
  print("actions=" .. table.concat(actionsOf(el), ", "))
end

local function dialogStillPresent()
  for _, app in ipairs(hs.application.runningApplications()) do
    if chromeNames[app:name()] then
      local appAx = ax.applicationElement(app)
      for _, win in ipairs(safeAttr(appAx, "AXWindows") or {}) do
        if findApprovalDialog(win) then
          return true
        end
      end
    end
  end

  return false
end

local function run()
  print("Chrome DevTools approval debug started")

  for _, app in ipairs(hs.application.runningApplications()) do
    if chromeNames[app:name()] then
      print("Checking app: " .. app:name())
      app:activate()

      local appAx = ax.applicationElement(app)
      for _, win in ipairs(safeAttr(appAx, "AXWindows") or {}) do
        local dialog = findApprovalDialog(win)

        if dialog then
          describe(dialog, "Matched dialog container")

          local allow = findButtonByText(dialog, "Allow")
          if not allow then
            print("No Allow AXButton found")
            return false
          end

          describe(allow, "Matched Allow button")

          local ok, a, b, c = safeAction(allow, "AXPress")
          print("")
          print("AXPress pcall ok=" .. tostring(ok))
          print("AXPress returns=" .. tostring(a) .. ", " .. tostring(b) .. ", " .. tostring(c))

          hs.timer.doAfter(0.3, function()
            print("Dialog still present after AXPress: " .. tostring(dialogStillPresent()))
          end)

          return true
        end
      end
    end
  end

  print("No Chrome remote debugging approval dialog found")
  return false
end

run()
