local _, AP = ...

-- The relative value: a price against the item's market value, TSM's region sale average where the TSM app has
-- one, otherwise the 14-day average of Auctionator's scans. Also the item tooltip rows
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

-- Spread of the daily prices on a log scale (sample standard deviation): how far this item's price normally swings
-- from day to day, 0.1 for about 10%; nil below two days
local function logSpread(prices)
    if #prices < 2 then return nil end
    local sum = 0
    for _, price in ipairs(prices) do sum = sum + math.log(price) end
    local mean = sum / #prices
    local squares = 0
    for _, price in ipairs(prices) do squares = squares + (math.log(price) - mean) ^ 2 end
    return math.sqrt(squares / (#prices - 1))
end

-- Auctionator's day index (days since SCAN_DAY_0), as carried by each history row's rawDay
local function currentScanDay()
    return math.floor((time() - Auctionator.Constants.SCAN_DAY_0) / 86400)
end

-- Average minimum buyout inside the history window for one price-database key, the days it rests on and their log
-- spread; nil without usable history
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
    return { math.floor(interquartileMean(recent) + 0.5), #recent, logSpread(recent) }
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
-- base item, matching Auctionator's price lookups, the days of history behind it, that key and the daily prices'
-- log spread
function AP.Trend.AverageFor(itemRef)
    for _, dbKey in ipairs(AP.Bridge.DBKeys(itemRef) or {}) do
        local average = cachedAverage(dbKey)
        if average and average[1] > 0 then return average[1], average[2], dbKey, average[3] end
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
-- At least this far under the market value, in whole percent, with at least this TSM sale rate: an item that is cheap
-- and still sells, the rows Highlight Deals lights
AP.Trend.GREAT_DEAL_PCT = 50
AP.Trend.GREAT_DEAL_SALE_RATE = 80

-- A sale rate of 0.779 as the whole percent 78, the figure the tooltip shows and colours
function AP.Trend.SalePercent(rate)
    return rate and math.floor(rate * 100 + 0.5)
end

-- Whether a price pct whole percent off the item's market value, trusted as Relative returns it, is a great deal: far
-- enough under it, and an item TSM sees sell often enough; never without TSM's sale rate
function AP.Trend.IsGreatDeal(pct, trusted, itemRef)
    if not (trusted and type(pct) == "number" and pct <= -AP.Trend.GREAT_DEAL_PCT) then return false end
    local salePercent = AP.Trend.SalePercent(AP.TSM.SaleRate(itemRef))
    return salePercent ~= nil and salePercent >= AP.Trend.GREAT_DEAL_SALE_RATE
end

-- ===== Item tooltip rows =====
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

local function money(amount)
    return amount and GetMoneyString(amount, true)
end

-- How easily an item sells by TSM's sale rate: the lowest whole percent of each colour, best first; red below the last
local SALE_RATE_COLORS = {
    { 80, GREEN_FONT_COLOR },
    { 60, YELLOW_FONT_COLOR },
    { 40, ORANGE_FONT_COLOR },
}

-- "78%" for a sale rate of 0.779, green from 80%, yellow from 60%, orange from 40%, red below
local function share(rate)
    local pct = AP.Trend.SalePercent(rate)
    if not pct then return nil end
    local color = RED_FONT_COLOR
    for _, band in ipairs(SALE_RATE_COLORS) do
        if pct >= band[1] then
            color = band[2]
            break
        end
    end
    return color:WrapTextInColorCode(("%d%%"):format(pct))
end

-- "35" for 34.89 sales a day
local function whole(number)
    return number and ("%d"):format(math.floor(number + 0.5))
end

local function count(amount, unit)
    return ("%d %s%s ago"):format(amount, unit, amount == 1 and "" or "s")
end

-- "12 minutes ago" for a time(): minutes within the hour, hours within the day, days after that
local function ago(when)
    local minutes = math.max(0, math.floor((time() - when) / 60))
    if minutes < 60 then return count(math.max(1, minutes), "minute") end
    if minutes < 1440 then return count(math.floor(minutes / 60), "hour") end
    return count(math.floor(minutes / 1440), "day")
end

-- When Auctionator last got a price for the key: to the minute once the addon saw it, otherwise in Auctionator's
-- whole scan days
local function auctionatorAge(dbKey)
    local seen = AP.Bridge.SeenTime(dbKey)
    if seen then return ago(seen) end
    local days = AP.Bridge.PriceAge(dbKey)
    if days then return days == 0 and "today" or count(days, "day") end
    return nil
end

-- A source's sub-heading in white with the age of its data in grey on the right
local function addHeading(tooltip, title, age)
    if age then
        GameTooltip_AddColoredDoubleLine(tooltip, title, age, HIGHLIGHT_FONT_COLOR, GRAY_FONT_COLOR, false)
    else
        GameTooltip_AddHighlightLine(tooltip, title)
    end
end

-- Rows sit one grid step in from their sub-heading, through the helpers' own leftOffset (SharedTooltipTemplates.lua)
local ROW_INDENT = 8

-- A figure under its sub-heading; nothing without a figure
local function addRow(tooltip, label, text)
    if text then
        GameTooltip_AddColoredDoubleLine(tooltip, label, text, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR, false, ROW_INDENT)
    end
end

-- After a blank line, the gold heading Market Value with the timing verdict on its right, over one block per source
-- that has figures: Auctionator, with when it last saw a price, its 14-day average and the last price against it;
-- then TSM, with when its app last synced, the region sale average, sale rate and daily sales, and the same last price
-- against the sale average. Each row shows only with
-- its figure, and the lines of TSM and Auctionator themselves are left untouched
local function addPriceRows(tooltip, itemLink)
    local average, days, dbKey = AP.Trend.AverageFor(itemLink)
    local saleAverage = AP.TSM.SaleAverage(itemLink)
    local saleRate, dailySold = AP.TSM.SaleRate(itemLink), AP.TSM.DailySold(itemLink)
    if not (average or saleAverage or saleRate or dailySold) then return end

    local mode, lastPrice = AP.Trend.Mode(), AP.Bridge.AuctionPrice(itemLink)
    local verdict, verdictColor = AP.Timing.Verdict(lastPrice, itemLink, mode)
    GameTooltip_AddBlankLineToTooltip(tooltip)
    if verdict then
        GameTooltip_AddColoredDoubleLine(tooltip, "Market Value", verdict, NORMAL_FONT_COLOR, verdictColor, false)
    else
        GameTooltip_AddNormalLine(tooltip, "Market Value")
    end
    if average then
        addHeading(tooltip, "Auctionator", auctionatorAge(dbKey))
        addRow(tooltip, "List Average", money(average))
        addRow(tooltip, "Market Value", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, average), mode, days))
    end
    if saleAverage or saleRate or dailySold then
        local synced = AP.TSM.SyncTime()
        addHeading(tooltip, "TSM", synced and ago(synced))
        addRow(tooltip, "Sale Average", money(saleAverage))
        addRow(tooltip, "Sale Rate", share(saleRate))
        addRow(tooltip, "Daily Sold", whole(dailySold))
        addRow(tooltip, "Market Value", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, saleAverage), mode))
    end

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
