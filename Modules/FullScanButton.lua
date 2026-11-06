local _, AP = ...

local UI = LibStub("LibNativeUI-1.0")

-- "Full Scan" on Auctionator's Shopping tab: starts Auctionator's own full scan in the scan mode its options set, as the
-- Full Scan button on Auctionator's tab does, and shows the scan's progress in its label
AP.FullScanButton = {}

local BUTTON_LABEL = "Full Scan"

-- Fixed, so the progress label never resizes the button or moves the Filter button beside it
local BUTTON_WIDTH = 112

-- How long the final percentage stays before the label returns to Full Scan
local RESULT_SECONDS = 2

local scanButton, resetTimer
local lastPercent = 0

local function setLabel(text)
    if scanButton then scanButton:SetText(text) end
end

local function cancelReset()
    if resetTimer then
        resetTimer:Cancel()
        resetTimer = nil
    end
end

local function percentLabel(percent)
    return ("%s %d%%"):format(BUTTON_LABEL, percent)
end

local function showProgress(percent)
    cancelReset()
    lastPercent = percent
    setLabel(percentLabel(percent))
end

-- Green at 100% after a finished scan, red at the reached percentage after a failed one, then back to Full Scan
local function showResult(percent, color)
    cancelReset()
    setLabel(color:WrapTextInColorCode(percentLabel(percent)))
    resetTimer = C_Timer.NewTimer(RESULT_SECONDS, function()
        resetTimer = nil
        setLabel(BUTTON_LABEL)
    end)
end

-- Both scan modes report the same steps under their own event names, with progress as a fraction
local SCAN_STEPS = { "ScanStart", "ScanProgress", "ScanComplete", "ScanFailed" }
local stepOf, scanEvents = {}, {}
for _, events in ipairs({ Auctionator.FullScan.Events, Auctionator.IncrementalScan.Events }) do
    for _, step in ipairs(SCAN_STEPS) do
        local eventName = events[step]
        if eventName then
            stepOf[eventName] = step
            scanEvents[#scanEvents + 1] = eventName
        end
    end
end

AP.Bridge.Listen(scanEvents, function(_, eventName, progress)
    local step = stepOf[eventName]
    if step == "ScanStart" then
        showProgress(0)
    elseif step == "ScanProgress" then
        showProgress(math.min(99, math.floor((progress or 0) * 100)))
    elseif step == "ScanComplete" then
        showResult(100, GREEN_FONT_COLOR)
    elseif step == "ScanFailed" then
        showResult(lastPercent, RED_FONT_COLOR)
    end
end)

-- The default incremental scan pages the client's one browse result set, as a shopping search does, so it waits for the
-- search; Alternate Scan Mode reads its own list and always starts. Auctionator's own button never meets a running
-- search, since leaving the Shopping tab stops it
local function blockedBySearch()
    local shoppingFrame = AuctionatorShoppingFrame
    return not AP.Bridge.IsReplicateScan() and shoppingFrame ~= nil and shoppingFrame.searchRunning == true
end

local function addStateLines(tooltip)
    if AP.Bridge.IsReplicateScan() then
        GameTooltip_AddNormalLine(tooltip, "Alternate Scan Mode is on: one scan every 15 minutes.", true)
    end
    if blockedBySearch() then
        GameTooltip_AddErrorLine(tooltip, "Wait for the shopping search to finish first.", true)
    end
end

-- Bottom-left of the results inset, on the Export Results row. Parented to that button so it hides with it whenever a
-- buy screen covers the results
function AP.FullScanButton.Ensure()
    if scanButton then return true end
    local shoppingFrame = AuctionatorShoppingFrame
    local inset = shoppingFrame and shoppingFrame.ShoppingResultsInset
    local exportButton = shoppingFrame and shoppingFrame.ExportCSV
    if not inset or not exportButton then return false end

    local button = UI.CreateButton(exportButton, BUTTON_LABEL, BUTTON_WIDTH)
    UI.AttachTooltip(button, function(tooltip)
        GameTooltip_SetTitle(tooltip, BUTTON_LABEL)
        GameTooltip_AddHighlightLine(tooltip, "Runs Auctionator's full scan of the Auction House, like the Full Scan button on Auctionator's own tab, so every price and average is current.", true)
        addStateLines(tooltip)
    end, "ANCHOR_TOP")
    button:SetPoint("LEFT", inset, "LEFT", 0, 0)
    button:SetPoint("BOTTOM", exportButton, "BOTTOM", 0, 0)
    button:SetScript("OnClick", function()
        if not blockedBySearch() then AP.Bridge.StartFullScan() end
    end)

    scanButton = button
    return true
end

-- The Filter button sits to the right of it
function AP.FullScanButton.Button()
    return scanButton
end
