local _, AP = ...

-- TSM's market value: DBMarket, the realm market value in copper, as TSM v4.15.2 defines it on Forever.
-- With the TSM addon loaded it comes through TSM_API. With it off or missing, the toc loads the TSM app's AppData.lua
-- into this addon, which reads the same figure from there. Without either, the TSM rows stay hidden.
AP.TSM = {}

local MARKET_SOURCE = "DBMarket"
local MARKET_FIELD = "marketValue"

-- ===== TSM addon =====
-- TSM item string for a link, an item string or an auction item key. Keys pool suffixed gear into the base item, and TSM itself falls back to the base item when a variant has no data
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

local function addonValue(itemRef)
    local itemString = itemStringFor(itemRef)
    if not itemString then return nil end
    local ok, amount = pcall(TSM_API.GetCustomPriceValue, MARKET_SOURCE, itemString)
    return ok and amount or nil
end

-- ===== TSM app data =====
-- The blocks holding marketValue for this realm and for this region's commodities: the value's column and each item's packed row
local appBlocks = {}

-- TSM keys Forever realm data by ruleset and faction instead of the realm name, and region data as Forever-<region> or Forever-HC-<region>
local function rulesetName()
    if C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then return "Hardcore", true end
    local rp = C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset)
    local pvp = C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset)
    return (rp and pvp and "Roleplay PvP") or (rp and "Roleplay") or (pvp and "PvP") or "Normal", false
end

local function isOwnBlock(tag, realmOrRegion)
    local ruleset, hardcore = rulesetName()
    if tag:match("^AUCTIONDB_NON_COMMODITY_") then
        return realmOrRegion:lower() == (ruleset .. "-" .. (UnitFactionGroup("player") or "")):lower()
    end
    if tag:match("^AUCTIONDB_COMMODITY_") then
        -- shortcut: any Forever region matches, wrong only when one install holds data of two Forever regions, match the portal then
        return realmOrRegion:match("^Forever%-") ~= nil and (realmOrRegion:match("^Forever%-HC%-") ~= nil) == hardcore
    end
    return false
end

-- AppData.lua calls this once per block. The TSM addon imports the file itself while it is loaded, so nothing is kept then
function AP.LoadData(tag, realmOrRegion, data)
    if TSM_API or type(tag) ~= "string" or type(realmOrRegion) ~= "string" or type(data) ~= "string" then return end
    if not isOwnBlock(tag, realmOrRegion) then return end

    -- The payload reads return {downloadTime=...,fields={"itemString",...},data={{item,value,...},...}}
    local head, body = data:match("^(.-),data={(.*)}}%s*$")
    local fields = head and head:match("fields={(.-)}")
    if not fields then return end

    -- itemString is the first field and the key of each row, so the nth field is the row's (n - 1)th value
    local column, index = nil, 0
    for field in fields:gmatch('"([^"]+)"') do
        if field == MARKET_FIELD then column = index end
        index = index + 1
    end
    if not column or column == 0 then return end

    local rows = {}
    for item, values in body:gmatch('{"?([^,"]+)"?,([^}]+)}') do
        rows[tonumber(item) and ("i:" .. item) or item] = values
    end
    appBlocks[#appBlocks + 1] = { column = column, rows = rows }
end

-- TSM packs each value in base 32 and cuts values over 6 digits in two, since tonumber only holds 32 bits
local function unpackValue(packed)
    if #packed > 6 then
        local low, high = tonumber(packed:sub(-6), 32), tonumber(packed:sub(1, -7), 32)
        return low and high and low + high * 2 ^ 30
    end
    return tonumber(packed, 32)
end

-- shortcut: reads the base item only, so suffixed gear gets the pooled value TSM falls back to, key rows by TSM's level item strings if variants matter
local function appValue(itemRef)
    local itemID = type(itemRef) == "table" and itemRef.itemID or (type(itemRef) == "string" and itemRef:match("item:(%d+)"))
    if not itemID then return nil end
    local key = "i:" .. itemID
    for _, block in ipairs(appBlocks) do
        local row = block.rows[key]
        if row then
            local packed = select(block.column, strsplit(",", row))
            return packed and unpackValue(packed)
        end
    end
    return nil
end

-- Realm market value in copper from the TSM addon while it is loaded, otherwise from the TSM app's data. Nil without a figure
function AP.TSM.MarketValueFor(itemRef)
    local amount
    if TSM_API then amount = addonValue(itemRef) else amount = appValue(itemRef) end
    if type(amount) == "number" and amount > 0 then return amount end
    return nil
end
