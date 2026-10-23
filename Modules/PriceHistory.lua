local _, AP = ...

-- Price-history statistics, the relative value and the item tooltip rows
AP.Trend = {}

-- ===== Price-history statistics =====
-- Two weeks of daily minimums: long enough to smooth single scans, short enough to follow the market
local HISTORY_WINDOW_DAYS = 14

-- Below this a quartile trim is too thin to stop same-side freak days, the median is safer
local MIN_TRIM_SAMPLES = 8

local function medianOf(sorted)
    local count = #sorted
    local mid = math.floor(count / 2)
    if count % 2 == 0 then
        return (sorted[mid] + sorted[mid + 1]) / 2
    end
    return sorted[mid + 1]
end

-- Interquartile mean of daily prices: dropping the cheapest and priciest quarter removes dump days and thin-supply days by construction, with no tuning constants to misjudge a market
local function interquartileMean(prices)
    table.sort(prices)
    if #prices < MIN_TRIM_SAMPLES then
        return medianOf(prices)
    end

    local trim = math.floor(#prices * 0.25)
    local total, count = 0, 0
    for index = trim + 1, #prices - trim do
        total = total + prices[index]
        count = count + 1
    end
    return total / count
end

-- Auctionator's day index (days since SCAN_DAY_0), as carried by each history row's rawDay
local function currentScanDay()
    return math.floor((time() - Auctionator.Constants.SCAN_DAY_0) / 86400)
end

-- Average minimum buyout inside the history window for one price-database key; nil without usable history
local function averageFor(dbKey)
    local cutoffDay = currentScanDay() - HISTORY_WINDOW_DAYS
    local recent = {}
    for _, entry in ipairs(AP.Bridge.PriceHistory(dbKey)) do
        local day = tonumber(entry.rawDay)
        local minSeen = tonumber(entry.minSeen)
        if (not day or day > cutoffDay) and minSeen and minSeen > 0 then
            recent[#recent + 1] = minSeen
        end
    end
    if #recent == 0 then return nil end
    return math.floor(interquartileMean(recent) + 0.5)
end

-- Averages of this frame, false for keys without history. A listing decorates every row of one item in one pass, so they share one history build. Shortcut: cleared next frame, so prices recorded later never read stale, but distinct items still build their history each time; a cache cleared on Auctionator's price writes would cover that
local frameAverages

local function cachedAverage(dbKey)
    if not frameAverages then
        frameAverages = {}
        C_Timer.After(0, function() frameAverages = nil end)
    end
    if frameAverages[dbKey] == nil then
        frameAverages[dbKey] = averageFor(dbKey) or false
    end
    return frameAverages[dbKey] or nil
end

-- First key with usable history, so a suffix or item-level key measures against its own market before the pooled base item, matching Auctionator's price lookups
function AP.Trend.AverageFor(itemRef)
    for _, dbKey in ipairs(AP.Bridge.DBKeys(itemRef) or {}) do
        local average = cachedAverage(dbKey)
        if average and average > 0 then return average end
    end
    return nil
end

-- ===== Trend percentage =====
-- Colour modes: UP_GREEN for selling (an increase is good), UP_RED for buying
AP.Trend.UP_GREEN = "upGreen"
AP.Trend.UP_RED = "upRed"

-- Whole-percent deviation of currentPrice from average; nil when either input is unusable
function AP.Trend.Percent(currentPrice, average)
    if type(currentPrice) ~= "number" or currentPrice <= 0 then return nil end
    if type(average) ~= "number" or average <= 0 then return nil end
    return math.floor((currentPrice - average) / average * 100 + 0.5)
end

-- "+N%" / "-N%" / "0%" wrapped in the colour dictated by mode; nil pct yields nil so callers can skip an empty trend
function AP.Trend.Colorize(pct, mode)
    if type(pct) ~= "number" then return nil end

    if pct == 0 then return HIGHLIGHT_FONT_COLOR:WrapTextInColorCode("0%") end
    local increaseGood = mode == AP.Trend.UP_GREEN
    local color = ((pct > 0) == increaseGood) and GREEN_FONT_COLOR or RED_FONT_COLOR
    return color:WrapTextInColorCode(string.format("%+d%%", pct))
end

-- ===== Item tooltip rows =====
local function addRow(tooltip, label, text)
    if text then
        GameTooltip_AddColoredDoubleLine(tooltip, label, text, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR, false)
    end
end

local function shown(frame)
    return frame ~= nil and frame:IsVisible()
end

-- Seller's colours in the selling views, buyer's colours anywhere else in an open Auction House
local function trendMode()
    local ah = AuctionHouseFrame
    if not shown(ah) then return AP.Trend.UP_GREEN end
    if shown(AuctionatorSellingFrame) or shown(ah.ItemSellFrame) or shown(ah.CommoditiesSellFrame) then
        return AP.Trend.UP_GREEN
    end
    return AP.Trend.UP_RED
end

-- The average, then the last known price against it; nothing without history, and Auctionator's own lines are left untouched
local function addPriceRows(tooltip, itemLink)
    local average = AP.Trend.AverageFor(itemLink)
    if not average then return end

    local auction = AP.Bridge.AuctionPrice(itemLink)
    GameTooltip_AddBlankLineToTooltip(tooltip)
    addRow(tooltip, "14-day average", AP.Bridge.Money(average))
    addRow(tooltip, "Last price vs average", AP.Trend.Colorize(AP.Trend.Percent(auction, average), trendMode()))

    -- Resize so the added lines render inside the tooltip frame
    tooltip:Show()
end

-- Only the two player-facing tooltips get rows
local PLAYER_TOOLTIPS = { [GameTooltip] = true, [ItemRefTooltip] = true }

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if not PLAYER_TOOLTIPS[tooltip] then return end
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    if itemLink then pcall(addPriceRows, tooltip, itemLink) end
end)
