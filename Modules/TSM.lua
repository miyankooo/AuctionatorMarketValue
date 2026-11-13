local addonName, AP = ...

-- TSM's figures for an item, read straight from the TSM desktop app's data file, so the TradeSkillMaster addon can be
-- disabled or load in any order: the region sale average (the market value the list percentages measure against
-- wherever it exists), the region sale rate, and how old they are. Never a single auction's price: that comes from Auctionator, which holds what the player saw
-- in the Auction House. The app's AppData.lua hands each block to AP.LoadData, as TradeSkillMaster_AppHelper's own
-- load of the same file hands it to TSM (see Loading below). Every figure is nil without the app's data for this
-- region, ruleset and faction. Tags, keys, fields and packing as TSM v4.15.6 reads them (LibTSMService
-- AppHelper/AppHelper.lua and AuctionDB/AuctionDB.lua, LibTSMApp Config/AuctionDBConfig.lua)
AP.TSM = {}

-- ===== The player's blocks =====
-- Forever has no named realms: TSM keys local data by ruleset and faction, such as PvP-Alliance, and region data as
-- Forever-<region> or Forever-HC-<region> (LibTSMWoW SessionInfo.lua, LibTSMService AppHelper.lua)
local function ownKeys()
    local rule = C_GameRules.IsGameRuleActive
    local hardcore = rule(Enum.GameRule.HardcoreRuleset)
    local rp, pvp = rule(Enum.GameRule.RPRuleset), rule(Enum.GameRule.PvPRuleset)
    local ruleset = (hardcore and "Hardcore") or (rp and pvp and "Roleplay PvP") or (rp and "Roleplay") or (pvp and "PvP") or "Normal"
    return {
        realm = (ruleset .. "-" .. (UnitFactionGroup("player") or "")):lower(),
        region = ((hardcore and "Forever-HC-" or "Forever-") .. GetCurrentRegionName()):lower(),
    }
end

-- The blocks holding the fields read below; commodity blocks carry the house's figures for stackables per region,
-- which TSM merges into the realm's data. On Forever they come empty, since stackables sit in the realm blocks
local BLOCK_KEYS = {
    AUCTIONDB_REGION_SALE = "region",
}

local keys
local blocks = {}

-- AppData.lua calls this once per block as select(2, ...).LoadData(tag, realmOrRegion, data). The player's blocks are
-- kept as text and parsed at their first lookup, so login pays only for a few string matches
function AP.LoadData(tag, realmOrRegion, data)
    if type(tag) ~= "string" or type(realmOrRegion) ~= "string" or type(data) ~= "string" then return end
    -- An error here would stop the rest of the file, so unknown keys only mean no blocks match
    if not keys then
        local ok, own = pcall(ownKeys)
        keys = ok and own or {}
    end
    if realmOrRegion:lower() ~= keys[BLOCK_KEYS[tag]] then return end

    -- The payload reads return {downloadTime=...,fields={"itemString",...},data={{item,value,...},...}}
    local _, dataStart = data:find(",data={", 1, true)
    local fieldList = dataStart and data:sub(1, dataStart):match("fields={(.-)}")
    if not fieldList then return end
    -- itemString is the first field and the key of each row, so the nth field is the row's (n - 1)th value
    local fields, column = {}, 0
    for field in fieldList:gmatch('"([^"]+)"') do
        if column > 0 then fields[field] = column end
        column = column + 1
    end
    -- downloadTime is when TSM built the block, the time TSM's own "last updated" goes by (AuctionDB.lua)
    local built = tonumber(data:sub(1, dataStart):match("downloadTime=(%d+)"))
    blocks[#blocks + 1] = { fields = fields, built = built, body = data:sub(dataStart + 1, -3) }
end

-- Rows by item string, "i:<itemID>" for a plain item. A variant such as i:259891::i1 also answers for its base item,
-- since the addon looks items up by item ID and TSM falls back to the base item
local function rowsOf(block)
    if not block.rows then
        local rows = {}
        for item, values in block.body:gmatch('{"?([^,"]+)"?,([^}]+)}') do
            local key = tonumber(item) and ("i:" .. item) or item
            local base = key:match("^i:%d+")
            if base and base ~= key and not rows[base] then rows[base] = values end
            rows[key] = values
        end
        block.rows, block.body = rows, nil
    end
    return block.rows
end

-- TSM packs each value in base 32 and cuts values over 6 digits in two, since tonumber only holds 32 bits
local function unpack32(packed)
    if #packed > 6 then
        local low, high = tonumber(packed:sub(-6), 32), tonumber(packed:sub(1, -7), 32)
        return low and high and low + high * 2 ^ 30 or 0
    end
    return tonumber(packed, 32) or 0
end

-- A row's values, unpacked at its first lookup and kept unpacked, as TSM does
local function valuesOf(rows, key)
    local row = rows[key]
    if type(row) == "string" then
        local values = { strsplit(",", row) }
        for index, packed in ipairs(values) do values[index] = unpack32(packed) end
        rows[key] = values
        row = values
    end
    return row
end

-- An item's field from the first block that has both; nil when missing or zero, as TSM's own lookup. Takes a link, an
-- item string or an auction item key
local function value(field, itemRef)
    local itemID = type(itemRef) == "table" and itemRef.itemID
        or type(itemRef) == "string" and (itemRef:match("item:(%d+)") or itemRef:match("^i:(%d+)"))
    if not itemID then return nil end
    local key = "i:" .. itemID
    for _, block in ipairs(blocks) do
        local column = block.fields[field]
        local values = column and valuesOf(rowsOf(block), key)
        if values then
            local amount = values[column]
            return amount and amount > 0 and amount or nil
        end
    end
    return nil
end

-- ===== Figures =====
-- What the item sold for across the region, in copper (DBRegionSaleAvg)
function AP.TSM.SaleAverage(itemRef)
    return value("regionSale", itemRef)
end

-- The share of the item's auctions that sell across the region, from 0 to 1; the app writes it in thousandths
-- (DBRegionSaleRate)
function AP.TSM.SaleRate(itemRef)
    local permille = value("regionSalePercent", itemRef)
    return permille and permille / 1000
end

-- Whether the app's data for this region carries sale rates, which great deals need
function AP.TSM.HasSaleRates()
    for _, block in ipairs(blocks) do
        if block.fields.regionSalePercent then return true end
    end
    return false
end

-- When TSM built the data behind a field, as time(): the region's figures for regionSale, about daily. Not when the
-- app last synced, which says only that the app looked for news. nil without that data
function AP.TSM.BuiltTime(field)
    local newest
    for _, block in ipairs(blocks) do
        if block.fields[field] and block.built and block.built > (newest or 0) then newest = block.built end
    end
    return newest
end

-- ===== Loading =====
-- AppData.lua lives in TSM's AppHelper folder, which players without TSM do not have, and a toc line naming a missing
-- file raises a Lua warning at every login (seen in game on 2026-11-12). So the file is listed by a load-on-demand
-- helper shipped with the addon, SimpleMarketValue_TSM, loaded only where the AppHelper folder exists, enabled or not
local HELPER, APP_HELPER = "SimpleMarketValue_TSM", "TradeSkillMaster_AppHelper"

-- The helper's first file hands AppData.lua's blocks to this, a global, since add-ons share no tables
function SimpleMarketValue_LoadTSMData(tag, realmOrRegion, data)
    AP.LoadData(tag, realmOrRegion, data)
end

-- Loads the app's data through the helper where TSM's AppHelper folder exists; once, as the client loads an add-on
function AP.TSM.LoadAppData()
    if C_AddOns.DoesAddOnExist(APP_HELPER) and C_AddOns.DoesAddOnExist(HELPER) then
        C_AddOns.LoadAddOn(HELPER)
    end
end

-- At this addon's own load, before login, so the data is there for the first tooltip and the welcome line
EventUtil.ContinueOnAddOnLoaded(addonName, AP.TSM.LoadAppData)
