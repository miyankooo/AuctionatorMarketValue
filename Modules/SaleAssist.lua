local _, AP = ...

-- Sale Assist: where and when to sell an item, as one call. It weighs what a vendor pays at once against what an
-- auction is expected to bring after the auction house's cut and the deposits lost on listings that do not sell.
--
-- The model. Listing at price P sells with probability s, TSM's sale rate where the TSM app gives one. A sale pays P less the cut and returns
-- the deposit D; a listing that runs out returns the item and keeps the deposit. A seller who relists until it sells
-- loses (1 - s) / s deposits on average for each sale, so an auction is worth
--     P * (1 - cut) - D * (1 - s) / s
-- and beats the vendor only above the vendor price. Relisting once and then vendoring is never better: if one more
-- listing beats the vendor now, it does after every failed listing too. The one formula covers the cheap item (P near
-- the vendor price), the item that rarely sells (many lost deposits) and the item with no margin after fees alike,
-- since the deposit grows with the vendor price.
AP.SaleAssist = {}

-- The auction house's share of a sale. ConsignmentRate 5 for every faction auction house in the client's
-- AuctionHouse table (wago.tools, product wowf, build 1.60.1.70888); the neutral goblin houses take 15, which the
-- addon does not model
local CUT = 0.05

-- The last resort for a deposit: its share of the vendor price for each of the game's three durations, 2, 8 and 24
-- hours. The same table's DepositRate is 5; taken for every 2 hours, the vanilla rule, it gives these. An assumption,
-- used only until the game has answered once for the duration (gameDeposit, learnDeposit)
local ASSUMED_DEPOSIT_RATES = { 0.05, 0.20, 0.60 }

-- A deposit on less vendor value than this, in copper, is rounded too coarsely to measure a rate from
local MIN_MEASURED_VALUE = 100

-- Without TSM's sale rate the call must hold for an item that sells badly and for one that sells well, the tenth and
-- ninetieth percent of the region's sale rates (10% and 73.5% on EU on 2026-11-12). Where the two disagree, how well
-- the item sells decides, and nobody knows it, so there is no call
local LOW_SALE_RATE, HIGH_SALE_RATE = 0.1, 0.7

-- The lowest sale rate reckoned with, so an item TSM saw sell once in a thousand listings does not divide by nothing
local MIN_SALE_RATE = 0.01

-- ===== Deposits =====
-- The game's own deposit for posting the item, before it is listed, and the quantity it is for: the two calls
-- Blizzard's sell windows show their deposit from (Blizzard_AuctionHouseItemSellFrame.lua:434,
-- Blizzard_AuctionHouseCommoditiesSellFrame.lua:86), the only place the client exposes a deposit; it exposes neither
-- its deposit rate nor its cut. An item in the bags answers by its location, for its whole stack; any other item only
-- by its ID, which the game answers for commodities. Nothing where the game gives no answer, as it may away from an
-- auctioneer: Blizzard's own code only asks with the Auction House open
local function gameDeposit(itemLink, itemGUID, duration)
    local location = itemGUID and AP.CanAccess(itemGUID) and C_Item.GetItemLocation(itemGUID)
    local deposit, quantity
    if location and location:IsValid() then
        quantity = C_Item.GetStackCount(location) or 1
        if C_AuctionHouse.GetItemCommodityStatus(location) == Enum.ItemCommodityStatus.Commodity then
            deposit = C_AuctionHouse.CalculateCommodityDeposit(C_Item.GetItemID(location), duration, quantity)
        else
            deposit = C_AuctionHouse.CalculateItemDeposit(location, duration, quantity)
        end
    else
        quantity = 1
        deposit = C_AuctionHouse.CalculateCommodityDeposit(C_Item.GetItemInfoInstant(itemLink), duration, quantity)
    end
    if type(deposit) == "number" and deposit > 0 and type(quantity) == "number" and quantity > 0 then
        return deposit, quantity
    end
    return nil
end

-- The share of the vendor price the game last charged per duration index, saved with the settings: what stands in
-- wherever the game gives no answer for the item itself
local function depositRates()
    local db = AP.DB()
    if type(db.depositRates) ~= "table" then db.depositRates = {} end
    return db.depositRates
end

-- Keeps the rate behind a deposit the game answered with. The newest answer wins, so a rule Blizzard changes is
-- picked up; one on too little vendor value, rounded too coarsely, only fills a gap
local function learnDeposit(sellPrice, duration, quantity, deposit)
    if sellPrice <= 0 then return end
    local value = sellPrice * quantity
    local rates = depositRates()
    if value < MIN_MEASURED_VALUE and rates[duration] then return end
    rates[duration] = deposit / value
end

-- The deposit for one of the item at the duration the player posts with, in copper: the game's own answer for the
-- item; else the rate the game last charged for that duration; else the assumed rate
local function depositFor(itemLink, itemGUID, sellPrice)
    local duration = AP.Bridge.PostDuration()
    local ok, deposit, quantity = pcall(gameDeposit, itemLink, itemGUID, duration)
    if ok and deposit then
        learnDeposit(sellPrice, duration, quantity, deposit)
        return deposit / quantity
    end
    return sellPrice * (depositRates()[duration] or ASSUMED_DEPOSIT_RATES[duration])
end

-- ===== The call =====
local function auctionValue(price, deposit, saleRate)
    return price * (1 - CUT) - deposit * (1 - saleRate) / saleRate
end

-- The three calls, each with the colour it shows in: green for the auction house, yellow for an auction that pays
-- at the usual price but not at today's, white for the vendor
local VENDOR = { "Vendor", HIGHLIGHT_FONT_COLOR }
local AUCTION = { "Auction", GREEN_FONT_COLOR }
local AUCTION_MAYBE = { "Auction maybe", YELLOW_FONT_COLOR }

-- The call at one sale rate for an item a vendor pays `vendor` for, costing `deposit` to list, last seen at `now` and
-- usually selling for `usual`
local function callAt(saleRate, vendor, deposit, now, usual)
    local valueNow = now and auctionValue(now, deposit, saleRate)
    local valueUsual = usual and auctionValue(usual, deposit, saleRate)
    if math.max(valueNow or -math.huge, valueUsual or -math.huge) <= vendor then
        return vendor > 0 and VENDOR or nil
    end

    -- Worth an auction. Only maybe when today's price does not beat the vendor but the usual one does, or when it
    -- sits a Sell Threshold under the usual one, the dip a seller's percentage shows in red: waiting may pay more
    if now and usual and (valueNow <= vendor or AP.Trend.Percent(now, usual) <= -AP.DB().sellThresholdPct) then
        return AUCTION_MAYBE
    end
    return AUCTION
end

local function call(itemLink, itemGUID)
    if not AP.Bridge.CanAuction(itemLink) then return nil end
    local vendor = AP.Bridge.SellPrice(itemLink) or 0

    -- Two prices an auction could fetch: the cheapest the player last saw, and the usual one, the market value the
    -- percentages measure against, once enough data backs it
    local now = AP.Bridge.AuctionPrice(itemLink)
    local usual, days = AP.Trend.MarketValue(itemLink)
    if days and days < AP.Trend.MIN_DAYS then usual = nil end
    if not (now or usual) then
        -- Nothing known about its auctions: only an item made for the vendor gets a call
        return vendor > 0 and AP.Bridge.IsJunk(itemLink) and VENDOR or nil
    end

    local deposit = depositFor(itemLink, itemGUID, vendor)
    local saleRate = AP.TSM.SaleRate(itemLink)
    if saleRate then return callAt(math.max(saleRate, MIN_SALE_RATE), vendor, deposit, now, usual) end
    local cautious = callAt(LOW_SALE_RATE, vendor, deposit, now, usual)
    if cautious == callAt(HIGH_SALE_RATE, vendor, deposit, now, usual) then return cautious end
    return nil
end

-- The call for an item and its colour; nil for an item that cannot be auctioned or has nothing to go by. itemGUID
-- names the very item where the tooltip shows one from the bags, so the game can answer for it
function AP.SaleAssist.Advice(itemLink, itemGUID)
    local advice = call(itemLink, itemGUID)
    if advice then return advice[1], advice[2] end
    return nil
end
