local addonName, AP = ...

-- Calls into Auctionator's functions, pcalled wherever Auctionator can raise on bad input; frames, mixins and event names are read in place by the modules. Item references are either an item link or an auction item key table
AP.Bridge = {}

function AP.Bridge.IsEquipment(classID)
    return Auctionator.Utilities.IsEquipment(classID)
end

-- Bare item key for a gear search, the same key Auctionator's own sell search uses
function AP.Bridge.BaseItemKey(itemID)
    return { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

function AP.Bridge.ItemKeyString(itemKey)
    return Auctionator.Utilities.ItemKeyString(itemKey)
end

function AP.Bridge.SameItemKey(a, b)
    return AP.Bridge.ItemKeyString(a) == AP.Bridge.ItemKeyString(b)
end

-- ===== Price database =====
-- Auctionator answers through a callback that runs at once for cached items; an uncached link yields nil instead of waiting
local function keysForLink(itemLink)
    local keys
    pcall(Auctionator.Utilities.DBKeyFromLink, itemLink, function(result) keys = result end)
    if type(keys) == "table" and #keys > 0 then return keys end
    return nil
end

local function keysForItemKey(itemKey)
    local ok, keys = pcall(Auctionator.Utilities.DBKeyFromBrowseResult, { itemKey = itemKey })
    if ok and type(keys) == "table" and #keys > 0 then return keys end
    return nil
end

-- Price-database keys, most specific first; nil when the reference is unusable
function AP.Bridge.DBKeys(itemRef)
    if type(itemRef) == "table" and itemRef.itemID ~= nil then return keysForItemKey(itemRef) end
    if type(itemRef) == "string" then return keysForLink(itemRef) end
    return nil
end

-- Last recorded minimum price and the key that holds it, the first key with a price as Auctionator's own lookup
-- (GetFirstPrice, Source/Database/Mixin.lua); nil when unknown or before Auctionator opened its database
function AP.Bridge.AuctionPrice(itemRef)
    local db = Auctionator.Database
    local keys = db and AP.Bridge.DBKeys(itemRef)
    if not keys then return nil end
    for _, dbKey in ipairs(keys) do
        local ok, price = pcall(db.GetPrice, db, dbKey)
        if ok and type(price) == "number" and price > 0 then return price, dbKey end
    end
    return nil
end

-- Daily rows for one database key, newest first; empty without history
function AP.Bridge.PriceHistory(dbKey)
    local db = Auctionator.Database
    if not db then return {} end
    local ok, history = pcall(db.GetPriceHistory, db, dbKey)
    return ok and type(history) == "table" and history or {}
end

-- Whole scan days since the key's newest price, the age Auctionator's own tooltip shows; nil without history
function AP.Bridge.PriceAge(dbKey)
    local db = Auctionator.Database
    if not db then return nil end
    local ok, days = pcall(db.GetPriceAge, db, dbKey)
    return ok and type(days) == "number" and days or nil
end

-- ===== Price times =====
-- Auctionator keeps one row per day and no time of day, so the addon notes when each key last got a price: every
-- SetPrice, from Auctionator's scans, its sell searches and Sale Scan alike. Kept per realm, like Auctionator's own
-- database, and for the 14 days the average looks back
local SEEN_KEEP_SECONDS = 14 * 86400

-- This realm's price-database key to time(); nil until the saved table has loaded
local seenTimes

local function noteSeen(_, dbKey)
    if seenTimes and dbKey ~= nil then seenTimes[dbKey] = time() end
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    local db = AP.DB()
    if type(db.seenTimes) ~= "table" then db.seenTimes = {} end
    local realm = tostring(Auctionator.State and Auctionator.State.CurrentRealm or GetRealmName())
    if type(db.seenTimes[realm]) ~= "table" then db.seenTimes[realm] = {} end
    seenTimes = db.seenTimes[realm]

    local cutoff = time() - SEEN_KEEP_SECONDS
    for dbKey, seen in pairs(seenTimes) do
        if type(seen) ~= "number" or seen < cutoff then seenTimes[dbKey] = nil end
    end
end)

-- Auctionator builds its database at its own ADDON_LOADED, before this file runs, so the instance gets the hook; the
-- mixin covers a database it builds again later, as its database commands do. Auctionator's tables, not Blizzard's,
-- so no taint
if Auctionator.DatabaseMixin and Auctionator.DatabaseMixin.SetPrice then
    hooksecurefunc(Auctionator.DatabaseMixin, "SetPrice", noteSeen)
end
if Auctionator.Database and Auctionator.Database.SetPrice then
    hooksecurefunc(Auctionator.Database, "SetPrice", noteSeen)
end

-- When a key last got a price on this realm, as time(); nil when the addon never saw it
function AP.Bridge.SeenTime(dbKey)
    return seenTimes and seenTimes[dbKey]
end

-- Record a live minimum price under every key of the item, the way Auctionator's own sell search does
function AP.Bridge.RecordPrice(itemKey, price)
    local db = Auctionator.Database
    if not db or type(price) ~= "number" or price <= 0 then return end
    for _, dbKey in ipairs(keysForItemKey(itemKey) or {}) do
        pcall(db.SetPrice, db, dbKey, price)
    end
end

-- ===== Event bus =====
-- Subscribe a handler for the whole session; listeners are tables with a ReceiveEvent method, called as (listener, eventName, ...)
function AP.Bridge.Listen(events, handler)
    local listener = { ReceiveEvent = handler }
    Auctionator.EventBus:Register(listener, events)
    return listener
end

-- ===== Auction house =====
-- Whether Auctionator's "Alternate Scan Mode" option is on: Auctionator then runs the replicate scan, allowed once per
-- 15 minutes, and otherwise (its default) the incremental browse scan
function AP.Bridge.IsReplicateScan()
    return Auctionator.Config.Get(Auctionator.Config.Options.REPLICATE_SCAN) == true
end

-- Start the full scan the way Auctionator's own Full Scan button does (Source_ModernAH ScanButton.lua); both scan
-- frames exist once the Auction House has opened
function AP.Bridge.StartFullScan()
    local state = Auctionator.State
    local scanFrame = AP.Bridge.IsReplicateScan() and state.FullScanFrameRef or state.IncrementalScanFrameRef
    if scanFrame then scanFrame:InitiateScan() end
end

-- Single-item search through Auctionator's retrying scanner, with owned auctions split out as Auctionator's own searches do; gear uses the sell search so every suffix variant answers
function AP.Bridge.SearchItem(itemKey, isGear)
    if isGear then
        return pcall(Auctionator.AH.SendSellSearchQueryByItemKey, itemKey, { Auctionator.Constants.ItemResultsSorts }, true)
    end
    return pcall(Auctionator.AH.SendSearchQueryByItemKey, itemKey, { Auctionator.Constants.CommodityResultsSorts }, true)
end
