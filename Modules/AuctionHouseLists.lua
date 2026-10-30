local _, AP = ...

-- The relative value on Blizzard's own auction lists: a short coloured percentage in each row's price cell, and buy
-- list rows at least the deal threshold below the average glow. A frame of the addon's own repaints the visible rows
-- while the Auction House shows, so no addon code ever runs inside Blizzard's list updates, whose row data later
-- feeds the restricted purchase calls.
AP.AuctionHouseLists = {}

-- Each list by its keys under AuctionHouseFrame, the row field with its price, and whether the player buys from it.
local LISTS = {
    { "BrowseResultsFrame", "ItemList", price = "minPrice", buy = true },
    { "CommoditiesBuyFrame", "ItemList", price = "unitPrice", buy = true },
    { "ItemBuyFrame", "ItemList", price = "buyoutAmount", buy = true },
    { "CommoditiesSellList", price = "unitPrice" },
    { "ItemSellList", price = "buyoutAmount" },
}

-- Blizzard's own row highlight, tinted green, so a deal reads as part of the list
local DEAL_ATLAS = "auctionhouse-ui-row-highlight"

local UI = LibStub("LibNativeUI-1.0")

local function listFrame(list)
    local frame = AuctionHouseFrame
    for _, key in ipairs(list) do
        frame = frame and frame[key]
    end
    return frame
end

-- The cell that shows the price: the last one with money in it, since the item lists put the bid before the buyout
local function priceCell(row)
    local found
    for _, cell in ipairs(row.cells or {}) do
        if cell.MoneyDisplay then found = cell end
    end
    return found
end

-- The money fills the cell, aligned right unless the template asks for left, so the badge takes the other side
local function badgeFor(cell)
    local badge = cell.apRelative
    if not badge then
        badge = UI.CreateText(cell, "body", "OVERLAY")
        if cell.leftAlign then
            badge:SetPoint("RIGHT", cell, "RIGHT", -UI.Space.tight, 0)
            badge:SetJustifyH("RIGHT")
        else
            badge:SetPoint("LEFT", cell, "LEFT", UI.Space.tight, 0)
        end
        cell.apRelative = badge
    end
    return badge
end

local function dealGlowFor(row)
    local glow = row.apDeal
    if not glow then
        glow = row:CreateTexture(nil, "BACKGROUND", nil, 2)
        glow:SetAtlas(DEAL_ATLAS)
        glow:SetAllPoints()
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(GREEN_FONT_COLOR:GetRGB())
        row.apDeal = glow
    end
    return glow
end

-- Rows keep the same result table until Blizzard hands them another, so a row is only worked out again on a change
local function paintRow(row, list)
    local rowData, threshold = row.rowData, AP.DB().dealThresholdPct
    if row.apRowData == rowData and row.apThreshold == threshold then return end
    row.apRowData, row.apThreshold = rowData, threshold

    local text, pct, days
    if rowData then
        text, pct, days = AP.Trend.Relative(rowData[list.price], AP.Trend.RefFor(rowData), list.buy and AP.Trend.UP_RED or AP.Trend.UP_GREEN)
    end

    local cell = priceCell(row)
    if cell then
        local badge = badgeFor(cell)
        badge:SetText(text or "")
    end

    local isDeal = list.buy and pct ~= nil and days >= AP.Trend.MIN_DAYS and pct <= -threshold
    if isDeal or row.apDeal then dealGlowFor(row):SetShown(isDeal) end
end

-- One painter per list, made once, so the per-frame walk allocates nothing
for _, list in ipairs(LISTS) do
    list.paint = function(row) paintRow(row, list) end
end

local function paint()
    for _, list in ipairs(LISTS) do
        local frame = listFrame(list)
        if frame and frame:IsVisible() and frame.ScrollBox then
            frame.ScrollBox:ForEachFrame(list.paint)
        end
    end
end

-- Children of the Auction House only update while it shows, so the painter costs nothing elsewhere
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local painter = CreateFrame("Frame", nil, AuctionHouseFrame)
    painter:SetScript("OnUpdate", paint)
end)
