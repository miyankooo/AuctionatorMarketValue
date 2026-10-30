local _, AP = ...

-- The relative value of the price being typed in a sell window, live: Blizzard's item and commodity sell frames and
-- Auctionator's sale slot. A frame of the addon's own reads each price while the Auction House shows, so no addon code
-- runs inside Blizzard's posting code.
AP.PostingCheck = {}

local UI = LibStub("LibNativeUI-1.0")

-- Blizzard's price row keeps its error icon 10 px right of the money input, 20 px wide, so the label starts past it
local BLIZZARD_LABEL_OFFSET = 36

local function blizzardWindow(key)
    return {
        frame = function() return AuctionHouseFrame[key] end,
        price = function(frame) return frame.PriceInput:GetAmount() end,
        item = function(frame)
            local location = frame:GetItem()
            return location and C_Item.DoesItemExist(location) and C_Item.GetItemLink(location) or nil
        end,
        anchor = function(frame) return frame.PriceInput.MoneyInputFrame, BLIZZARD_LABEL_OFFSET end,
    }
end

local WINDOWS = {
    blizzardWindow("ItemSellFrame"),
    blizzardWindow("CommoditiesSellFrame"),
    {
        frame = function() return AuctionatorSellingFrame and AuctionatorSellingFrame.SaleItemFrame end,
        price = function(frame) return frame.Price:GetAmount() end,
        item = function(frame) return frame.itemInfo and frame.itemInfo.itemLink end,
        anchor = function(frame) return frame.Price.MoneyInput, UI.Space.gap end,
    },
}

local function labelFor(window, frame)
    if not window.label then
        local anchor, offset = window.anchor(frame)
        window.label = UI.CreateText(frame, "body", "OVERLAY")
        window.label:SetPoint("LEFT", anchor, "RIGHT", offset, 0)
    end
    return window.label
end

-- A window is only worked out again when its item or price changed
local function update(window)
    local frame = window.frame()
    if not frame or not frame:IsVisible() then return end

    local link, price = window.item(frame), window.price(frame)
    if link == window.link and price == window.lastPrice then return end
    window.link, window.lastPrice = link, price

    local text = link and AP.Trend.Relative(price, link, AP.Trend.UP_GREEN)
    labelFor(window, frame):SetText(text and (text .. " " .. HIGHLIGHT_FONT_COLOR:WrapTextInColorCode("vs average")) or "")
end

local function updateAll()
    for _, window in ipairs(WINDOWS) do update(window) end
end

-- Children of the Auction House only update while it shows, so the check costs nothing elsewhere
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local checker = CreateFrame("Frame", nil, AuctionHouseFrame)
    checker:SetScript("OnUpdate", updateAll)
end)
