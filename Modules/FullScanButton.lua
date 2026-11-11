local _, AP = ...

-- "Full Scan" on Auctionator's Shopping tab: starts Auctionator's own full scan in the scan mode its options set, as the
-- Full Scan button on Auctionator's tab does, and shows the scan's progress in its label
AP.FullScanButton = {}

local BUTTON_LABEL = "Full Scan"

-- Fixed, so the progress label never resizes the button
local BUTTON_WIDTH = 112

-- How long the final percentage stays before the label returns to Full Scan
local RESULT_SECONDS = 2

-- The first step for a new player: prices before any percentage can show
local TIP_TEXT = "Click Full Scan to load today's prices for every percentage and average."

local scanButton, resetTimer, showTip
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
        GameTooltip_AddNormalLine(tooltip, "Alternate Scan Mode is on: one scan every 15 minutes.")
    end
    if blockedBySearch() then
        GameTooltip_AddErrorLine(tooltip, "Wait for the shopping search to finish first.")
    end
end

-- Blizzard's yellow glowing callout, the one the Auction House uses for its undercut tip
-- (Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua:507), as an own HelpTipTemplate frame on the
-- target. HelpTip:Show would take a frame from Blizzard's shared pool, and writing to that pool from addon code would
-- taint the help tips Blizzard shows later. It shows each time the target shows until the player closes it or uses
-- the feature, then never again on the account; it hides with the target without being marked. Reset runs before
-- every Init: only Blizzard's pool resets a tip, and Init leaves `acknowledged` set (HelpTip.lua:419-431, 495, 687),
-- so a tip closed once and brought back by /smv intro would count as seen when it merely hides with its target.
local function AttachTip(target, text, targetPoint, relativeRegion)
    local tip
    local info = {
        text = text,
        buttonStyle = HelpTip.ButtonStyle.Close,
        targetPoint = targetPoint,
        onAcknowledgeCallback = function() AP.DB().tipSeen = true end,
    }
    local function ShowTip()
        if AP.DB().tipSeen or (tip and tip:IsShown()) then return end
        if not tip then
            tip = CreateFrame("Frame", nil, target, "HelpTipTemplate")
            tip.width = HelpTip.width
            tip:SetWidth(tip.width)
        end
        tip:Reset()
        tip:Init(target, info, relativeRegion or target)
        tip:Show()
    end
    target:HookScript("OnShow", ShowTip)
    -- Auctionator's button can be made while its tab already shows, so it gets no OnShow of its own
    if target:IsVisible() then ShowTip() end

    -- The player used the feature: the tip goes for good, shown or not.
    local function Retire()
        if tip and tip.info then tip:Acknowledge() else AP.DB().tipSeen = true end
    end
    return ShowTip, Retire
end

-- The button once placed, for Highlight Great Deals beside it; nil before
function AP.FullScanButton.Button()
    return scanButton
end

-- /smv intro brings the tip back now while Full Scan shows, otherwise at its next show
function AP.FullScanButton.ShowTip()
    if showTip and scanButton:IsVisible() then showTip() end
end

-- Bottom-left of the results inset, on the Export Results row. Parented to that button so it hides with it whenever a
-- buy screen covers the results
function AP.FullScanButton.Ensure()
    if scanButton then return true end
    local shoppingFrame = AuctionatorShoppingFrame
    local inset = shoppingFrame and shoppingFrame.ShoppingResultsInset
    local exportButton = shoppingFrame and shoppingFrame.ExportCSV
    if not inset or not exportButton then return false end

    local button = AP.CreateButton(exportButton, BUTTON_LABEL, BUTTON_WIDTH)
    AP.AttachTooltip(button, function(tooltip)
        GameTooltip_SetTitle(tooltip, BUTTON_LABEL)
        GameTooltip_AddNormalLine(tooltip, "Runs Auctionator's full scan of the Auction House, like the Full Scan button on Auctionator's own tab, so every price and average is current.")
        addStateLines(tooltip)
    end)
    button:SetPoint("LEFT", inset, "LEFT", 0, 0)
    button:SetPoint("BOTTOM", exportButton, "BOTTOM", 0, 0)
    -- Above the button, where the results list leaves room
    local retireTip
    showTip, retireTip = AttachTip(button, TIP_TEXT, HelpTip.Point.TopEdgeCenter)
    button:SetScript("OnClick", function()
        retireTip()
        if not blockedBySearch() then AP.Bridge.StartFullScan() end
    end)

    scanButton = button
    return true
end
