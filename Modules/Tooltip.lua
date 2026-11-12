local _, AP = ...

-- The Market Value block on item tooltips, the one place for every price of the item. After a blank line and a gold
-- heading: what a vendor pays, then a block per source that has figures. Auctionator: when it last saw a price, that
-- minimum buyout, its 14-day average and the one against the other. TSM, from the TSM desktop app: how old its last
-- scan is, that scan's minimum buyout, the region sale average, the one against the other, the sale rate and the
-- daily sales. Each row shows only with its figure. Auctionator's own price lines stay off these tooltips, since
-- the block carries them, stack prices included: where Auctionator would price the whole stack, every price in the
-- block is for the stack and the heading says so

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
    if dbKey == nil then return nil end
    local seen = AP.Bridge.SeenTime(dbKey)
    if seen then return ago(seen) end
    local days = AP.Bridge.PriceAge(dbKey)
    if days then return days == 0 and "today" or count(days, "day") end
    return nil
end

-- A white line at the block's left edge with a figure on its right: a source's sub-heading over the grey age of its
-- data, or the vendor price in white
local function addLine(tooltip, title, right, rightColor)
    if right then
        GameTooltip_AddColoredDoubleLine(tooltip, title, right, HIGHLIGHT_FONT_COLOR, rightColor, false)
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

local function addBlock(tooltip, itemLink)
    local stack = AP.Bridge.TakeStack(tooltip, itemLink)
    local vendor = AP.Bridge.VendorPrice(itemLink)
    local lastPrice, priceKey = AP.Bridge.AuctionPrice(itemLink)
    local average, days, averageKey = AP.Trend.AverageFor(itemLink)
    local minBuyout, saleAverage = AP.TSM.MinBuyout(itemLink), AP.TSM.SaleAverage(itemLink)
    local saleRate, dailySold = AP.TSM.SaleRate(itemLink), AP.TSM.DailySold(itemLink)
    local hasTSM = minBuyout or saleAverage or saleRate or dailySold
    if not (vendor or lastPrice or average or hasTSM) then return end

    local mode = AP.Trend.Mode()
    GameTooltip_AddBlankLineToTooltip(tooltip)
    if stack then
        GameTooltip_AddColoredDoubleLine(tooltip, "Market Value", ("Stack of %d"):format(stack), NORMAL_FONT_COLOR, GRAY_FONT_COLOR, false)
    else
        GameTooltip_AddNormalLine(tooltip, "Market Value")
    end
    if vendor then addLine(tooltip, "Vendor", money(vendor, stack), HIGHLIGHT_FONT_COLOR) end
    if lastPrice or average then
        addLine(tooltip, "Auctionator", auctionatorAge(priceKey or averageKey), GRAY_FONT_COLOR)
        addRow(tooltip, "Min Buyout", money(lastPrice, stack))
        addRow(tooltip, "14-Day Average", money(average, stack))
        addRow(tooltip, "Relative", AP.Trend.Colorize(AP.Trend.Percent(lastPrice, average), mode, days))
    end
    if hasTSM then
        -- The age of the scan behind Min Buyout; for an item that scan did not list, of the region's figures
        local built = AP.TSM.BuiltTime(minBuyout and "minBuyout" or "regionSale")
        addLine(tooltip, "TSM", built and ago(built), GRAY_FONT_COLOR)
        addRow(tooltip, "Min Buyout", money(minBuyout, stack))
        addRow(tooltip, "Sale Average", money(saleAverage, stack))
        addRow(tooltip, "Relative", AP.Trend.Colorize(AP.Trend.Percent(minBuyout, saleAverage), mode))
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
