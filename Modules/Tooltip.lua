local _, AP = ...

-- Rows right under Auctionator's own Vendor and Auction lines on item tooltips, which stay as Auctionator writes them.
-- A section per source that has figures, its name followed by the age of its data:
-- Auctionator: the average of its minimum buyouts over 14 days, and its last minimum buyout against it.
-- TSM, from the TSM desktop app: the region sale average, the same minimum buyout against it, and the region sale rate.
-- Both percentages start from Auctionator's minimum buyout, the price the player sees in the auction listing, and
-- each label names the figure it measures against. Each row shows only with its figure. Prices are for one item

-- Only the two player-facing tooltips get the block
local PLAYER_TOOLTIPS = { [GameTooltip] = true, [ItemRefTooltip] = true }

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
    local lastPrice, priceKey = AP.Bridge.AuctionPrice(itemLink)
    local average, days, averageKey = AP.Trend.AverageFor(itemLink)
    local saleAverage, saleRate = AP.TSM.SaleAverage(itemLink), AP.TSM.SaleRate(itemLink)
    if not (average or saleAverage or saleRate) then return end

    local mode = AP.Trend.Mode()
    if average then
        addHeading(tooltip, "Auctionator", auctionatorAge(priceKey or averageKey))
        addRow(tooltip, "Min. Buyout Average", money(average))
        addRow(tooltip, "vs Min. Buyout Average", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, average), mode, days))
    end
    if saleAverage or saleRate then
        local built = AP.TSM.BuiltTime("regionSale")
        addHeading(tooltip, "TSM", built and age(built))
        addRow(tooltip, "Sale Average", money(saleAverage))
        addRow(tooltip, "vs Sale Average", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, saleAverage), mode))
        addRow(tooltip, "Sale Rate", share(saleRate))
    end

    -- Resize so the added lines render inside the tooltip frame
    tooltip:Show()
end

-- Right after Auctionator's own Vendor and Auction lines, in the same call that adds them, so other addons' tooltip
-- lines, such as Questie's or RestedXP's, never come between; also when Auctionator adds its lines later, once an
-- item's data has loaded. Only on a player tooltip that shows one item: Auctionator also prices every item of a
-- mail with several, on a tooltip that is no item tooltip
AP.Bridge.AfterPriceLines(function(tooltip, itemLink)
    if PLAYER_TOOLTIPS[tooltip] and tooltip:IsTooltipType(Enum.TooltipDataType.Item) then
        pcall(addBlock, tooltip, itemLink)
    end
end)
