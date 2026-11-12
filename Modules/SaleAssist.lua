local _, AP = ...

-- Sale Assist: where and when to sell an item, as one call. It weighs what a vendor pays at once against what an
-- auction is expected to bring after the auction house's cut and the deposits lost on listings that do not sell.
--
-- The model. Listing at price P sells with probability s, TSM's sale rate. A sale pays P less the cut and returns
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

-- The deposit as a share of the vendor price for each of the game's three durations, 2, 8 and 24 hours. The same
-- table's DepositRate is 5; taken for every 2 hours, the vanilla rule, it gives these. The game computes deposits on
-- its servers, so this start is an assumption: the rates the game itself answers with replace it (learnDeposit)
local ASSUMED_DEPOSIT_RATES = { 0.05, 0.20, 0.60 }

-- A deposit on less vendor value than this, in copper, is rounded too coarsely to measure a rate from
local MIN_MEASURED_VALUE = 100

-- Without TSM's sale rate an item counts as selling this often, near the middle of the region's sale rates (the
-- median was 34% on EU on 2026-11-12); an assumption
local TYPICAL_SALE_RATE = 0.3

-- The lowest sale rate reckoned with, so an item TSM saw sell once in a thousand listings does not divide by nothing
local MIN_SALE_RATE = 0.01

-- ===== Deposits =====
-- Learned rates by duration index, saved with the settings
local function depositRates()
    local db = AP.DB()
    if type(db.depositRates) ~= "table" then db.depositRates = {} end
    return db.depositRates
end

-- The game's own deposit for an item about to be posted, as a share of its vendor value. The newest measurement
-- wins, so a rule Blizzard changes is picked up; one on too little value only fills a gap
local function learnDeposit(itemLink, duration, quantity, deposit)
    local sellPrice = AP.Bridge.SellPrice(itemLink)
    if not (sellPrice and type(duration) == "number" and type(quantity) == "number" and quantity > 0
        and type(deposit) == "number" and deposit > 0) then
        return
    end
    local value = sellPrice * quantity
    local rates = depositRates()
    if value < MIN_MEASURED_VALUE and rates[duration] then return end
    rates[duration] = deposit / value
end

AP.Bridge.WatchDeposits(learnDeposit)

-- The deposit for one of the item at the duration the player posts with, in copper
local function depositFor(sellPrice)
    local duration = AP.Bridge.PostDuration()
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

local function call(itemLink)
    if not AP.Bridge.CanAuction(itemLink) then return nil end
    local vendor = AP.Bridge.SellPrice(itemLink) or 0

    -- Two prices an auction could fetch: the cheapest the player last saw, and the usual one, the market value the
    -- percentages measure against
    local now = AP.Bridge.AuctionPrice(itemLink)
    local usual = AP.TSM.SaleAverage(itemLink)
    if not usual then
        local average, days = AP.Trend.AverageFor(itemLink)
        usual = average and days >= AP.Trend.MIN_DAYS and average or nil
    end
    if not (now or usual) then
        -- Nothing known about its auctions: only an item made for the vendor gets a call
        return vendor > 0 and AP.Bridge.IsJunk(itemLink) and VENDOR or nil
    end

    local saleRate = math.max(AP.TSM.SaleRate(itemLink) or TYPICAL_SALE_RATE, MIN_SALE_RATE)
    local deposit = depositFor(vendor)
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

-- The call for an item and its colour; nil for an item that cannot be auctioned or has nothing to go by
function AP.SaleAssist.Advice(itemLink)
    local advice = call(itemLink)
    if advice then return advice[1], advice[2] end
    return nil
end
