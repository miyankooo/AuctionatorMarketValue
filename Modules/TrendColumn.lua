local _, AP = ...

-- Relative column for Auctionator's shopping results, the selling tab's current prices and the shopping buy screens of one item and of one commodity; it stores a display string and a numeric sort key on every result entry. The provider mixins exist at load time; the AH frames that copy them are created on first open

-- Entry fields the column shows and sorts by
local TEXT_FIELD = "apTrendText"
local SORT_FIELD = "apTrendValue"
-- Whether a buyer's row is a great deal, for the rows Highlight Deals lights
local GREAT_DEAL_FIELD = "apGreatDeal"

-- Relative value of price against the item's average, in the colours of mode
local function setTrend(entry, price, itemRef, mode)
    local text, pct, trusted = AP.Trend.Relative(price, itemRef, mode)
    entry[SORT_FIELD] = pct
    entry[TEXT_FIELD] = text or ""
    entry[GREAT_DEAL_FIELD] = mode == AP.Trend.UP_RED and AP.Trend.IsGreatDeal(pct, trusted, itemRef) or nil
end

-- Auctionator's listings only read their layout entries, so the three providers share one
local TREND_COLUMN = {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerParameters = { SORT_FIELD },
    headerText = AP.Trend.HEADER,
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { TEXT_FIELD },
    width = 64,
}

-- The commodity buy list sits in a narrow inset, so the column follows the price, as on Blizzard's lists, and takes
-- its width from the blank Auctionator's price column keeps left of the money; three-digit gold still fits
local COMMODITY_PRICE_WIDTH = 120

local function besidePrice(columns)
    local price = columns[1]
    if not (price and price.cellTemplate == "AuctionatorPriceCellTemplate") then
        columns[#columns + 1] = TREND_COLUMN
        return
    end
    local narrow = {}
    for key, value in pairs(price) do narrow[key] = value end
    narrow.width = COMMODITY_PRICE_WIDTH
    columns[1] = narrow
    table.insert(columns, 2, TREND_COLUMN)
end

-- Add the column once per provider through a private copy, so Auctionator's shared layout table stays untouched:
-- at the end, or where place puts it
local function wrapLayout(mixin, place)
    local original = mixin.GetTableLayout
    mixin.GetTableLayout = function(self)
        if not self.apLayout then
            local merged = {}
            for _, column in ipairs(original(self)) do
                merged[#merged + 1] = column
            end
            if place then
                place(merged)
            else
                merged[#merged + 1] = TREND_COLUMN
            end
            self.apLayout = merged
        end
        return self.apLayout
    end
end

-- Sort our column numerically with blanks last; every other field falls through to the original sort, which has no comparator for ours
local function wrapSort(mixin)
    local original = mixin.Sort
    mixin.Sort = function(self, fieldName, sortDirection)
        if fieldName ~= SORT_FIELD then
            return original(self, fieldName, sortDirection)
        end
        local ascending = sortDirection == Auctionator.Constants.SORT.ASCENDING
        table.sort(self.results, function(a, b)
            local av, bv = a[fieldName], b[fieldName]
            -- Ties keep the list's own order: Auctionator's result index, or a commodity row's place by price
            if av == bv then
                return (a.sortingIndex or a.rowIndex or 0) < (b.sortingIndex or b.rowIndex or 0)
            end
            if av == nil then return false end
            if bv == nil then return true end
            if ascending then return av < bv end
            return av > bv
        end)
        self:SetDirty()
    end
end

local function decorateEach(priceField, mode)
    return function(_, entries)
        if type(entries) ~= "table" then return end
        for _, entry in ipairs(entries) do
            setTrend(entry, entry[priceField], AP.Trend.RefFor(entry), mode)
        end
    end
end

-- Shopping results: a buyer's view, cheaper than average is good
wrapLayout(AuctionatorShoppingTabDataProviderMixin)
wrapSort(AuctionatorShoppingTabDataProviderMixin)
hooksecurefunc(AuctionatorShoppingTabDataProviderMixin, "PrettifyData", decorateEach("minPrice", AP.Trend.UP_RED))

-- Selling tab current prices: a seller's view
wrapLayout(AuctionatorSearchDataProviderMixin)
wrapSort(AuctionatorSearchDataProviderMixin)
hooksecurefunc(AuctionatorSearchDataProviderMixin, "AppendEntries", decorateEach("price", AP.Trend.UP_GREEN))

-- Shopping buy screen of one item: a buyer's view
wrapLayout(AuctionatorBuyItemDataProviderMixin)
wrapSort(AuctionatorBuyItemDataProviderMixin)
hooksecurefunc(AuctionatorBuyItemDataProviderMixin, "AppendEntries", decorateEach("price", AP.Trend.UP_RED))

-- Shopping buy screen of one commodity: a buyer's view. Its rows carry only a unit price, so the item comes from the
-- frame that holds the provider, set before its search
wrapLayout(AuctionatorBuyCommodityDataProviderMixin, besidePrice)
wrapSort(AuctionatorBuyCommodityDataProviderMixin)
hooksecurefunc(AuctionatorBuyCommodityDataProviderMixin, "AppendEntries", function(self, entries)
    local itemID = self:GetParent().expectedItemID
    if type(entries) ~= "table" or not itemID then return end
    local itemRef = AP.Bridge.BaseItemKey(itemID)
    for _, entry in ipairs(entries) do
        setTrend(entry, entry.price, itemRef, AP.Trend.UP_RED)
    end
end)
