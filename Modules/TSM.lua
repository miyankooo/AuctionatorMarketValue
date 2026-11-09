local _, AP = ...

-- TSM's figures for an item through TSM_API, as TSM v4.15.2 defines them on Forever: the region sale average, the
-- market value the percentages measure against wherever TSM has one, the region sale rate and the region's daily
-- sales, the trend of the player's own auction house, plus when the TSM app last synced. TradeSkillMaster is optional; every figure is nil without it, for an item
-- without TSM data, or while TSM is not ready yet.
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

-- How many the region sells a day, asked for in thousandths as its own tooltip does
function AP.TSM.DailySold(itemRef)
    local permille = value("DBRegionSoldPerDay * 1000", itemRef)
    return permille and permille / 1000
end

-- ===== The player's auction house =====
-- Forever has no named realms: TSM keys its local data by ruleset and faction, such as PvP-Alliance (LibTSMWoW
-- SessionInfo.lua), and the app fills it for stackables and gear alike, so these are the player's own auction house.
-- The timing verdict reads its trend from them

-- TSM's market value on the player's auction house, in copper
function AP.TSM.HouseAverage(itemRef)
    return value("DBMarket", itemRef)
end

-- TSM's long-run price on the player's auction house, in copper
function AP.TSM.HouseHistorical(itemRef)
    return value("DBHistorical", itemRef)
end

-- ===== Sync time =====
-- TSM keeps the app's last sync private, so the addon reads it where TradeSkillMaster_AppHelper hands it over: AppHelper
-- passes each block of the app's data file to TSM's global TSM_APPHELPER_LOAD_DATA as it loads, and the APP_INFO block
-- carries lastSync (LibTSMService AppHelper.lua). The toc's OptionalDeps loads this file after TSM defines that global,
-- and the client's alphabetical load order before AppHelper; when AppHelper loads first, the age is simply unknown.
-- TSM's function, not Blizzard's, so no taint
local lastSync

if type(TSM_APPHELPER_LOAD_DATA) == "function" then
    hooksecurefunc("TSM_APPHELPER_LOAD_DATA", function(tag, _, data)
        if tag == "APP_INFO" and type(data) == "string" then
            lastSync = tonumber(data:match("lastSync=(%d+)")) or lastSync
        end
    end)
end

-- When the TSM app last synced its data, as time(); nil when unknown
function AP.TSM.SyncTime()
    return lastSync
end
