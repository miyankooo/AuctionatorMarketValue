local _, AP = ...

-- The Market Value block on item tooltips, the one place for every price of the item. After a blank line and a gold
-- heading: what a vendor pays, then a section per source that has figures, its name followed by the age of its data.
-- Auctionator: the minimum buyout it last saw, its average price over 14 days and the minimum buyout against it.
-- TSM, from the TSM desktop app: the region sale average, the same minimum buyout against it, the region sale rate
-- and daily sales.
-- Both percentages start from Auctionator's minimum buyout, the price the player sees in the auction listing, and
-- each label names the figure it measures against.
-- Each row shows only with its figure. Auctionator's own price lines stay off these tooltips, since the block carries
-- them, stack prices included: where Auctionator would price the whole stack, every price in the block is for the
-- stack and the heading says so

-- Only the two player-facing tooltips get the block
local PLAYER_TOOLTIPS = { [GameTooltip] = true, [ItemRefTooltip] = true }

-- A price for one, or for the whole stack
local function money(amount, stack)
    return amount and GetMoneyString(amount * (stack or 1), true)
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

-- "13m" for a time(): minutes within the hour, hours within the day, days after that
local function age(when)
    local minutes = math.max(0, math.floor((time() - when) / 60))
    if minutes < 60 then return ("%dm"):format(math.max(1, minutes)) end
    if minutes < 1440 then return ("%dh"):format(math.floor(minutes / 60)) end
    return ("%dd"):format(math.floor(minutes / 1440))
end

-- When Auctionator last got a price for the key: to the minute once the addon saw it, otherwise in Auctionator's
-- whole scan days, "<1d" for a price from today
local function auctionatorAge(dbKey)
    if dbKey == nil then return nil end
    local seen = AP.Bridge.SeenTime(dbKey)
    if seen then return age(seen) end
    local days = AP.Bridge.PriceAge(dbKey)
    if days then return days == 0 and "<1d" or ("%dd"):format(days) end
    return nil
end

-- A source's sub-heading in white, the age of its data after it in grey brackets: "Auctionator (13m)"
local function addHeading(tooltip, title, dataAge)
    if dataAge then title = title .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. dataAge .. ")") end
    GameTooltip_AddHighlightLine(tooltip, title)
end

-- Rows sit one grid step in from their sub-heading, through the helpers' own leftOffset (SharedTooltipTemplates.lua)
local ROW_INDENT = 8

-- A figure under its sub-heading; nothing without a figure
local function addRow(tooltip, label, text)
    if text then
        GameTooltip_AddColoredDoubleLine(tooltip, label, text, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR, false, ROW_INDENT)
    end
end

local function addBlock(tooltip, itemLink)
    local stack = AP.Bridge.TakeStack(tooltip, itemLink)
    local vendor = AP.Bridge.VendorPrice(itemLink)
    local lastPrice, priceKey = AP.Bridge.AuctionPrice(itemLink)
    local average, days, averageKey = AP.Trend.AverageFor(itemLink)
    local saleAverage = AP.TSM.SaleAverage(itemLink)
    local saleRate, dailySold = AP.TSM.SaleRate(itemLink), AP.TSM.DailySold(itemLink)
    local hasTSM = saleAverage or saleRate or dailySold
    if not (vendor or lastPrice or average or hasTSM) then return end

    local mode = AP.Trend.Mode()
    GameTooltip_AddBlankLineToTooltip(tooltip)
    if stack then
        GameTooltip_AddColoredDoubleLine(tooltip, "Market Value", ("Stack of %d"):format(stack), NORMAL_FONT_COLOR, GRAY_FONT_COLOR, false)
    else
        GameTooltip_AddNormalLine(tooltip, "Market Value")
    end
    if vendor then
        GameTooltip_AddColoredDoubleLine(tooltip, "Vendor", money(vendor, stack), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR, false)
    end
    if lastPrice or average then
        addHeading(tooltip, "Auctionator", auctionatorAge(priceKey or averageKey))
        addRow(tooltip, "Min Buyout", money(lastPrice, stack))
        addRow(tooltip, "Average Price", money(average, stack))
        addRow(tooltip, "vs Average Price", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, average), mode, days))
    end
    if hasTSM then
        local built = AP.TSM.BuiltTime("regionSale")
        addHeading(tooltip, "TSM", built and age(built))
        addRow(tooltip, "Sale Average", money(saleAverage, stack))
        addRow(tooltip, "vs Sale Average", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, saleAverage), mode))
        addRow(tooltip, "Sale Rate", share(saleRate))
        addRow(tooltip, "Daily Sold", whole(dailySold))
    end

    -- Resize so the added lines render inside the tooltip frame
    tooltip:Show()
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if not PLAYER_TOOLTIPS[tooltip] then return end
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    if itemLink then pcall(addBlock, tooltip, itemLink) end
end)

-- Auctionator prices a tooltip from its own post call, which runs before the one above, or later once an uncached
-- item has loaded; either way its price lines stay off a player tooltip that shows an item
AP.Bridge.TakeOverPriceLines(function(tooltip)
    return PLAYER_TOOLTIPS[tooltip] and tooltip:IsTooltipType(Enum.TooltipDataType.Item)
end)
