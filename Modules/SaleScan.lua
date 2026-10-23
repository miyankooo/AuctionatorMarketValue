local _, AP = ...

local UI = LibStub("LibNativeUI-1.0")

-- "Sale Scan": one live price search per distinct bag item, sequentially through Auctionator's throttle queue, recording each cheapest buyout in Auctionator's price database so the Relative column and the bag glow reflect current prices
AP.SaleScan = {}

local BUTTON_LABEL = "Sale Scan"

-- Fixed, so a changing progress label never resizes the button or moves what sits beside it
local BUTTON_WIDTH = 112

-- A search the server never answers is skipped after this
local QUERY_TIMEOUT_SECONDS = 8

local scanButton

-- queue holds the bag items still to scan (nil while idle), expected the item key of the in-flight search
local state = {
    queue = nil,
    total = 0,
    expected = nil,
    timeout = nil,
}

-- Auctionator runs one item search at a time, so a scan would cancel the slotted item's own price search
local function hasSaleItem()
    local saleItem = AuctionatorSellingFrame and AuctionatorSellingFrame.SaleItemFrame
    return saleItem ~= nil and saleItem.itemInfo ~= nil
end

local function setLabel(text)
    if scanButton then scanButton:SetText(text) end
end

local function cancelTimeout()
    if state.timeout then
        state.timeout:Cancel()
        state.timeout = nil
    end
end

local function stop()
    if not state.queue then return end
    cancelTimeout()
    state.queue = nil
    state.expected = nil
    setLabel(BUTTON_LABEL)
end

local nextQuery

-- Gear searches with the bare key so every suffix variant answers; the cheapest result is recorded under the item's own key by Auctionator's rules
local function runQuery(item)
    local isGear = AP.Bridge.IsEquipment(item.classID)
    local itemKey = isGear and AP.Bridge.BaseItemKey(item.itemID) or C_AuctionHouse.MakeItemKey(item.itemID)
    state.expected = itemKey
    setLabel(("Scanning %d/%d"):format(state.total - #state.queue, state.total))
    if not AP.Bridge.SearchItem(itemKey, isGear) then
        nextQuery()
        return
    end
    state.timeout = C_Timer.NewTimer(QUERY_TIMEOUT_SECONDS, nextQuery)
end

nextQuery = function()
    if not state.queue then return end
    cancelTimeout()
    local item = table.remove(state.queue, 1)
    if not item then
        stop()
        return
    end
    runQuery(item)
end

-- Cheapest listing with a buyout; bid-only listings say nothing about the price an item sells for at once
local function cheapestBuyout(itemKey)
    local best
    for index = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        local buyout = result and result.buyoutAmount
        if buyout and buyout > 0 and (not best or buyout < best.buyoutAmount) then
            best = result
        end
    end
    return best
end

local function recordItemResult(itemKey)
    local result = cheapestBuyout(itemKey)
    if result then
        AP.Bridge.RecordPrice(result.itemKey, result.buyoutAmount)
    end
end

local function recordCommodityResult(itemID)
    if C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID) == 0 then return end
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
    if result then
        AP.Bridge.RecordPrice(C_AuctionHouse.MakeItemKey(itemID), result.unitPrice)
    end
end

local function receiveEvent(_, eventName, payload)
    local expected = state.expected
    if not state.queue or not expected then return end
    if eventName == Auctionator.Selling.Events.SellSearchStart then
        -- the player selected an item; the scanner belongs to the selling flow now
        stop()
        return
    end

    if eventName == Auctionator.AH.Events.ItemSearchResultsReady then
        if type(payload) ~= "table" or not AP.Bridge.SameItemKey(payload, expected) then return end
        recordItemResult(payload)
    elseif eventName == Auctionator.AH.Events.CommoditySearchResultsReady then
        if payload ~= expected.itemID then return end
        recordCommodityResult(payload)
    else
        return
    end

    AP.BagGlow.Repaint()
    nextQuery()
end

-- Registered for the whole session; the handler is inert while no scan runs
AP.Bridge.Listen({
    Auctionator.AH.Events.ItemSearchResultsReady,
    Auctionator.AH.Events.CommoditySearchResultsReady,
    Auctionator.Selling.Events.SellSearchStart,
}, receiveEvent)

-- Distinct auctionable items shown in the bag panel
local function bagItems()
    local seen, items = {}, {}
    AP.BagGlow.EachButton(function(_, info)
        if info.itemID and not seen[info.itemID] then
            seen[info.itemID] = true
            items[#items + 1] = info
        end
    end)
    return items
end

local function start()
    if state.queue or hasSaleItem() then return end
    local items = bagItems()
    if #items == 0 then return end

    state.queue = items
    state.total = #items
    nextQuery()
end

local function addSlottedWarning(tooltip)
    if hasSaleItem() then
        GameTooltip_AddErrorLine(tooltip, "Clear the item in the sale slot first.", true)
    end
end

-- Greyed out while an item is slotted; the tooltip still shows and says why
local function updateEnabled()
    if scanButton then scanButton:SetEnabled(not hasSaleItem()) end
end

-- Under the prices inset, at its right edge, on the row of the price mini-tabs
function AP.SaleScan.Ensure()
    if scanButton then return true end
    local sellingFrame = AuctionatorSellingFrame
    local inset = sellingFrame and sellingFrame.HistoricalPriceInset
    local saleItem = sellingFrame and sellingFrame.SaleItemFrame
    if not inset or not saleItem then return false end

    local button = UI.CreateButton(sellingFrame, BUTTON_LABEL, BUTTON_WIDTH)
    UI.AttachTooltip(button, function(tooltip)
        GameTooltip_SetTitle(tooltip, BUTTON_LABEL)
        GameTooltip_AddHighlightLine(tooltip, "Runs one live price search for every item in the bag panel, so the Relative column and the bag glow use current prices. Click again to cancel. Needs an empty sale slot.", true)
        addSlottedWarning(tooltip)
    end, "ANCHOR_TOP")
    button:SetPoint("TOPRIGHT", inset, "BOTTOMRIGHT", 0, -4)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnClick", function()
        if state.queue then stop() else start() end
    end)

    sellingFrame:HookScript("OnHide", stop)

    -- Auctionator calls Update after every change of the slotted item, including resets after posting
    hooksecurefunc(saleItem, "Update", updateEnabled)

    scanButton = button
    updateEnabled()
    return true
end
