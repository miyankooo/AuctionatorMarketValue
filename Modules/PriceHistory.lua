local _, AP = ...

-- The relative value: a price against the item's market value, TSM's region sale average where the TSM app has
-- one, otherwise the 14-day average of Auctionator's scans
AP.Trend = {}

-- ===== Auctionator's 14-day average =====
-- Two weeks of daily minimums: long enough to smooth single scans, short enough to follow the market
local HISTORY_WINDOW_DAYS = 14

-- Below this a quartile trim is too thin to stop same-side freak days, the median is safer
local MIN_TRIM_SAMPLES = 8

-- An average built from fewer days of history says little, so its percentage shows in grey and moves no glow
AP.Trend.MIN_DAYS = 3

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

-- Average minimum buyout inside the history window for one price-database key and the days it rests on; nil without
-- usable history
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
    return { math.floor(interquartileMean(recent) + 0.5), #recent }
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

-- First key with usable history, so a suffix or item-level key measures against its own market before the pooled
-- base item, matching Auctionator's price lookups, the days of history behind it and that key
function AP.Trend.AverageFor(itemRef)
    for _, dbKey in ipairs(AP.Bridge.DBKeys(itemRef) or {}) do
        local average = cachedAverage(dbKey)
        if average and average[1] > 0 then return average[1], average[2], dbKey end
    end
    return nil
end

-- Browse rows carry an item key, item rows a link and commodity rows only an item id
function AP.Trend.RefFor(entry)
    if entry.itemLink then return entry.itemLink end
    if entry.itemKey then return entry.itemKey end
    if entry.itemID then return AP.Bridge.BaseItemKey(entry.itemID) end
    return nil
end

-- ===== Relative value =====
-- Colour modes: UP_GREEN for selling (an increase is good), UP_RED for buying
AP.Trend.UP_GREEN = "upGreen"
AP.Trend.UP_RED = "upRed"

-- Header of the percentage column in Auctionator's and Blizzard's lists
AP.Trend.HEADER = "Relative"

-- Whole-percent deviation of currentPrice from average; nil when either input is unusable
function AP.Trend.Percent(currentPrice, average)
    if type(currentPrice) ~= "number" or currentPrice <= 0 then return nil end
    if type(average) ~= "number" or average <= 0 then return nil end
    return math.floor((currentPrice - average) / average * 100 + 0.5)
end

-- "+N%" / "-N%" / "0%" in the colour of its distance from the market value: green from the threshold the glows use on
-- the good side of mode (the Sell Threshold for a seller, the Deal Threshold for a buyer), red as far on the bad side,
-- yellow in between, so green figures match the glowing rows. Grey when fewer than MIN_DAYS of history back it; nil
-- pct yields nil so callers can skip an empty trend
function AP.Trend.Colorize(pct, mode, days)
    if type(pct) ~= "number" then return nil end

    local text = pct == 0 and "0%" or string.format("%+d%%", pct)
    if days and days < AP.Trend.MIN_DAYS then return GRAY_FONT_COLOR:WrapTextInColorCode(text) end
    local db = AP.DB()
    local seller = mode == AP.Trend.UP_GREEN
    local threshold = seller and db.sellThresholdPct or db.dealThresholdPct
    local gain = seller and pct or -pct
    local color = gain >= threshold and GREEN_FONT_COLOR or gain <= -threshold and RED_FONT_COLOR or YELLOW_FONT_COLOR
    return color:WrapTextInColorCode(text)
end

-- A price against the item's market value, in the colours of mode: TSM's region sale average where TSM has one,
-- otherwise Auctionator's 14-day average. Returns the coloured text, the percentage and whether enough data backs it
-- for a glow, which a thin Auctionator history does not; nil text without a market value
function AP.Trend.Relative(price, itemRef, mode)
    local saleAverage = AP.TSM.SaleAverage(itemRef)
    if saleAverage then
        local pct = AP.Trend.Percent(price, saleAverage)
        return AP.Trend.Colorize(pct, mode), pct, pct ~= nil
    end
    local average, days = AP.Trend.AverageFor(itemRef)
    local pct = AP.Trend.Percent(price, average)
    return AP.Trend.Colorize(pct, mode, days), pct, pct ~= nil and days >= AP.Trend.MIN_DAYS
end

-- ===== Great deals =====
-- At least this far under every average, in whole percent, with at least this TSM sale rate: an item that is cheap
-- by the region's sales and on the player's own auction house, and still sells; the rows Highlight Deals lights
AP.Trend.GREAT_DEAL_PCT = 50
AP.Trend.GREAT_DEAL_SALE_RATE = 80

-- A sale rate of 0.779 as the whole percent 78, the figure the tooltip shows and colours and great deals go by
function AP.Trend.SalePercent(rate)
    return rate and math.floor(rate * 100 + 0.5)
end

-- Whether price is a great deal for the item: an item TSM sees sell often enough, priced far enough under each
-- average the addon has for it. TSM's region sale average is what it sells for across the region; Auctionator's
-- 14-day average, once enough days back it, is what it lists for on the player's own auction house, so a price that
-- is only normal there is no deal. Never without TSM's sale rate and at least one average
function AP.Trend.IsGreatDeal(price, itemRef)
    local salePercent = AP.Trend.SalePercent(AP.TSM.SaleRate(itemRef))
    if not (salePercent and salePercent >= AP.Trend.GREAT_DEAL_SALE_RATE) then return false end

    local salePct = AP.Trend.Percent(price, AP.TSM.SaleAverage(itemRef))
    if salePct and salePct > -AP.Trend.GREAT_DEAL_PCT then return false end
    local average, days = AP.Trend.AverageFor(itemRef)
    local localPct = average and days >= AP.Trend.MIN_DAYS and AP.Trend.Percent(price, average) or nil
    if localPct and localPct > -AP.Trend.GREAT_DEAL_PCT then return false end
    return (salePct or localPct) ~= nil
end

-- ===== The player's side =====
local function shown(frame)
    return frame and frame:IsVisible()
end

-- The player's side in the view that shows, the same rule as the lists: a seller outside the Auction House, while
-- posting and among their own auctions, a buyer while browsing, buying and among their bids
function AP.Trend.Mode()
    local ah = AuctionHouseFrame
    if not shown(ah) then return AP.Trend.UP_GREEN end
    local auctions = ah.AuctionsFrame
    if shown(AuctionatorSellingFrame) or shown(AuctionatorCancellingFrame) or shown(ah.ItemSellFrame) or shown(ah.CommoditiesSellFrame)
        or (shown(auctions) and not auctions:IsDisplayingBids()) then
        return AP.Trend.UP_GREEN
    end
    return AP.Trend.UP_RED
end
