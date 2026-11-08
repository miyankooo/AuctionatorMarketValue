local _, AP = ...

-- The relative value on Blizzard's own auction lists: a coloured percentage column beside each row's price, and buy
-- list rows at least the deal threshold below the average glow. A frame of the addon's own repaints the visible rows
-- while the Auction House shows, so no addon code ever runs inside Blizzard's list updates, whose row data later
-- feeds the restricted purchase calls.
AP.AuctionHouseLists = {}

-- Each list by its keys under AuctionHouseFrame, the row field with its price, whether the player buys from it, and
-- where its column sits: the row cell it hangs on (that cell's money with money = true), the point of the percentage
-- (also its justification), the point on the cell, the offset, and whether a header labels it.
-- Places come from Blizzard_AuctionHouseTableBuilder.lua: money sits left in its cell at the width of the list's
-- widest price, with the owned checkmark 6 px right of it and 16 wide, so each column takes space no text of
-- Blizzard's reaches.
local LISTS = {
    -- Price first and right-aligned: the free left of the price cell
    { "BrowseResultsFrame", "ItemList", price = "minPrice", buy = true, cell = 1, point = "LEFT", to = "LEFT", x = 4 },
    -- No headers and a narrow quantity column: right after the price and its checkmark
    { "CommoditiesBuyFrame", "ItemList", price = "unitPrice", buy = true, cell = 1, money = true, point = "LEFT", to = "RIGHT", x = 28 },
    -- Quantity left-aligned in a wide column: the end of that column, before the socket icon
    { "ItemBuyFrame", "ItemList", price = "buyoutAmount", buy = true, cell = 3, point = "RIGHT", to = "RIGHT", x = -4, header = true },
    -- Quantity keeps 80 px blank before the seller: the end of that blank
    { "CommoditiesSellList", price = "unitPrice", cell = 3, point = "RIGHT", to = "LEFT", x = -16, header = true },
    -- Buyout fills the row: the end of the buyout column
    { "ItemSellList", price = "buyoutAmount", cell = 2, point = "RIGHT", to = "RIGHT", x = -4, header = true },
}

-- Blizzard's own row highlight, tinted green, so a deal reads as part of the list
local DEAL_ATLAS = "auctionhouse-ui-row-highlight"

local UI = LibStub("LibNativeUI-1.0")

-- Per-row state lives here, keyed by Blizzard's rows, never on their frames
local WEAK = { __mode = "k" }
local texts, glows = setmetatable({}, WEAK), setmetatable({}, WEAK)
local paintedData, paintedThreshold, anchoredTo = setmetatable({}, WEAK), setmetatable({}, WEAK), setmetatable({}, WEAK)

local function listFrame(list)
    local frame = AuctionHouseFrame
    for _, key in ipairs(list) do
        frame = frame and frame[key]
    end
    return frame
end

-- The frame the column hangs on in this row. Blizzard hands cells between rows when it lays a list out again,
-- so it is looked up every pass
local function anchorFor(row, list)
    local cell = row.cells and row.cells[list.cell]
    if cell and list.money then return cell.MoneyDisplay end
    return cell
end

-- The percentage belongs to the row, so it moves and clips with it whichever cells Blizzard gives the row
local function textFor(row, list)
    local text = texts[row]
    if not text then
        text = UI.CreateText(row, "body", "OVERLAY")
        text:SetJustifyH(list.point)
        texts[row] = text
    end
    return text
end

local function dealGlowFor(row)
    local glow = glows[row]
    if not glow then
        glow = row:CreateTexture(nil, "BACKGROUND", nil, 2)
        glow:SetAtlas(DEAL_ATLAS)
        glow:SetAllPoints()
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(GREEN_FONT_COLOR:GetRGB())
        glows[row] = glow
    end
    return glow
end

-- The header sits over the column in the list's own header row, at the column's offset from that row
local function placeHeader(list, frame, anchor)
    local container = frame.HeaderContainer
    local edge = list.to == "LEFT" and anchor:GetLeft() or anchor:GetRight()
    local left = container and container:GetLeft()
    if not (edge and left) then return end

    local x = edge + list.x - left
    if list.headerX == x then return end
    list.headerX = x

    if not list.headerText then
        list.headerText = UI.CreateText(container, "body", "OVERLAY")
        list.headerText:SetText(AP.Trend.HEADER)
    end
    list.headerText:ClearAllPoints()
    list.headerText:SetPoint(list.point, container, "LEFT", x, 0)
end

-- Rows keep the same result table until Blizzard hands them another, so a row is only worked out again on a change
local function paintRow(row, list)
    local anchor = anchorFor(row, list)
    if not anchor then return end
    list.sample = anchor

    local text = textFor(row, list)
    if anchoredTo[row] ~= anchor then
        text:ClearAllPoints()
        text:SetPoint(list.point, anchor, list.to, list.x, 0)
        anchoredTo[row] = anchor
    end

    local rowData, threshold = row.rowData, AP.DB().dealThresholdPct
    if paintedData[row] == rowData and paintedThreshold[row] == threshold then return end
    paintedData[row], paintedThreshold[row] = rowData, threshold

    local value, pct, days
    if rowData then
        value, pct, days = AP.Trend.Relative(rowData[list.price], AP.Trend.RefFor(rowData), list.buy and AP.Trend.UP_RED or AP.Trend.UP_GREEN)
    end
    text:SetText(value or "")

    local isDeal = list.buy and pct ~= nil and days >= AP.Trend.MIN_DAYS and pct <= -threshold
    if isDeal or glows[row] then dealGlowFor(row):SetShown(isDeal) end
end

-- One painter per list, made once, so the per-frame walk allocates nothing
for _, list in ipairs(LISTS) do
    list.paint = function(row) paintRow(row, list) end
end

local function paint()
    for _, list in ipairs(LISTS) do
        local frame = listFrame(list)
        if frame and frame:IsVisible() and frame.ScrollBox then
            list.sample = nil
            frame.ScrollBox:ForEachFrame(list.paint)
            if list.header and list.sample then placeHeader(list, frame, list.sample) end
        end
    end
end

-- Children of the Auction House only update while it shows, so the painter costs nothing elsewhere
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local painter = CreateFrame("Frame", nil, AuctionHouseFrame)
    painter:SetScript("OnUpdate", paint)
end)
