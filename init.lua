local ax = require("hs.axuielement")

print("Chrome DevTools auto-allow script loaded")

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

local function roleOf(el)
  return safeAttr(el, "AXRole") or ""
end

local function childrenOf(el)
  return safeAttr(el, "AXChildren") or {}
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

  local role = tostring(roleOf(el))
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

local function scanChrome()
  for _, app in ipairs(hs.application.runningApplications()) do
    if chromeNames[app:name()] then
      local appAx = ax.applicationElement(app)
      local windows = safeAttr(appAx, "AXWindows") or {}

      for _, win in ipairs(windows) do
        local isDialog =
          containsText(win, "Allow remote debugging?") or
          containsText(win, "An external app wants full control") or
          containsText(win, "remote debugging")

        if isDialog then
          print("Matched remote debugging dialog")

          local allow = findButtonByText(win, "Allow")
          if allow then
            print("Pressing Allow")
            allow:performAction("AXPress")
            return true
          else
            print("Matched dialog but did not find Allow button")
          end
        end
      end
    end
  end

  return false
end

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "D", function()
  print("Manual scan triggered")
  scanChrome()
end)

hs.timer.doEvery(0.25, scanChrome)
