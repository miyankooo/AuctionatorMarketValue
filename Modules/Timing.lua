local _, AP = ...

-- The timing verdict: whether now is a good moment to buy or to sell. The price is measured against the market value
-- (TSM's region sale average, else Auctionator's 14-day average) in units of the item's normal swing, the spread of
-- Auctionator's daily prices, so a 10% cut counts as noise on a jumpy item and as news on a steady one. TSM's sale
-- rate, the trend on the player's auction house and the vendor price refine it
AP.Timing = {}

-- The swing never counts below 5%, so a strong buy, two swings under the market value, always clears a 5% cut
local MIN_SWING = 0.05
-- The swing assumed while Auctionator holds fewer than Trend.MIN_DAYS days of prices
local DEFAULT_SWING = 0.15
-- Days of prices behind a verdict in full colour, and the daily sales when TSM sets the market value; thinner data
-- shows the verdict in grey
local CONFIDENT_DAYS = 7
local CONFIDENT_DAILY_SOLD = 1
-- A strong buy needs at least this share of the item's auctions to sell, so it can be sold on
local RESALE_RATE = 0.3
-- Selling at a fair price pays at once when at least this share sells
local QUICK_SALE_RATE = 0.5

-- What a vendor pays for one, the price no buy should top; nil when unknown or worthless
local function vendorPrice(itemRef)
    local item = type(itemRef) == "table" and itemRef.itemID or itemRef
    local ok, sellPrice = pcall(function() return select(11, C_Item.GetItemInfo(item)) end)
    if ok and type(sellPrice) == "number" and sellPrice > 0 then return sellPrice end
    return nil
end

-- Buyer: Strong Buy (below the vendor price, or two swings under the market value in an item that sells and a market
-- not falling faster than a swing), Buy (one swing under), Overpriced (one swing over), else Fair.
-- Seller: Sell Now (one swing over, or a fair price on an item that mostly sells), Hold (one swing under in a market
-- that is not falling, so the price can recover), else Fair.
-- Returns the label and its colour for price in mode (Trend.Mode), grey on thin data; nil without a price or a market
-- value
function AP.Timing.Verdict(price, itemRef, mode)
    if type(price) ~= "number" or price <= 0 then return nil end
    local average, days, _, spread = AP.Trend.AverageFor(itemRef)
    local saleAverage = AP.TSM.SaleAverage(itemRef)
    local fair = saleAverage or average
    if not fair then return nil end

    days = days or 0
    local swing = (days >= AP.Trend.MIN_DAYS and spread) and math.max(spread, MIN_SWING) or DEFAULT_SWING
    local z = math.log(price / fair) / swing
    local rate = AP.TSM.SaleRate(itemRef)
    local house, historical = AP.TSM.HouseAverage(itemRef), AP.TSM.HouseHistorical(itemRef)
    local trend = (house and historical) and math.log(house / historical) or 0
    local confident = days >= CONFIDENT_DAYS
        and (not saleAverage or (AP.TSM.DailySold(itemRef) or 0) >= CONFIDENT_DAILY_SOLD)

    local label, color
    if mode == AP.Trend.UP_RED then
        local vendor = vendorPrice(itemRef)
        if vendor and price < vendor then
            label, color, confident = "Strong Buy", GREEN_FONT_COLOR, true
        elseif z <= -2 and (rate or 1) >= RESALE_RATE and trend > -swing then
            label, color = "Strong Buy", GREEN_FONT_COLOR
        elseif z <= -1 then
            label, color = "Buy", GREEN_FONT_COLOR
        elseif z >= 1 then
            label, color = "Overpriced", RED_FONT_COLOR
        else
            label, color = "Fair", HIGHLIGHT_FONT_COLOR
        end
    elseif z >= 1 or (z > -1 and (rate or 0) >= QUICK_SALE_RATE) then
        label, color = "Sell Now", GREEN_FONT_COLOR
    elseif z <= -1 and trend >= 0 then
        label, color = "Hold", RED_FONT_COLOR
    else
        label, color = "Fair", HIGHLIGHT_FONT_COLOR
    end
    return label, confident and color or GRAY_FONT_COLOR
end
