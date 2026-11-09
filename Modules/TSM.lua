local _, AP = ...

-- TSM's figures for an item through TSM_API, as TSM v4.15.2 defines them on Forever: the region sale average, the
-- market value the percentages measure against wherever TSM has one, and the region sale rate. TradeSkillMaster is
-- optional; every figure is nil without it, for an item without TSM data, or while TSM is not ready yet.
AP.TSM = {}

-- TSM item string for a link, an item string or an auction item key. Keys pool suffixed gear into the base item, and
-- TSM itself falls back to the base item when a variant has no data
local function itemStringFor(itemRef)
    if type(itemRef) == "table" and itemRef.itemID then
        return "i:" .. itemRef.itemID
    end
    if type(itemRef) == "string" and itemRef ~= "" then
        local ok, itemString = pcall(TSM_API.ToItemString, itemRef)
        return ok and itemString or nil
    end
    return nil
end

local function value(source, itemRef)
    if not TSM_API then return nil end
    local itemString = itemStringFor(itemRef)
    if not itemString then return nil end
    local ok, amount = pcall(TSM_API.GetCustomPriceValue, source, itemString)
    if ok and type(amount) == "number" and amount > 0 then return amount end
    return nil
end

-- What the item sold for across the region, in copper
function AP.TSM.SaleAverage(itemRef)
    return value("DBRegionSaleAvg", itemRef)
end

-- The share of the item's auctions that sell across the region, from 0 to 1. TSM rounds every value to a whole number,
-- so it is asked for a thousand times the rate, as its own tooltip does (LibTSMApp Tooltip/Internal/AuctionDB.lua)
function AP.TSM.SaleRate(itemRef)
    local permille = value("DBRegionSaleRate * 1000", itemRef)
    return permille and permille / 1000
end
