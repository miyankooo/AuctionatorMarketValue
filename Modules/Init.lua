local _, AP = ...

-- Setting defaults; the settings panel uses the same keys as its variable keys
AP.Defaults = {
    sellThresholdPct = 15,
    showSimilar = true,
    levelTolerance = 2,
    dpsTolerancePct = 20,
    statValueTolerance = 30,
    statCountTolerance = 0,
}

-- The table last seeded, so the defaults are filled once per saved table instead of on every call
local seededDB

-- Account-wide store for the settings and the shopping stat filter. Seeds missing defaults itself, so readers never see nil even before the settings panel registers
function AP.DB()
    if type(AuctionatorPlusDB) ~= "table" then
        AuctionatorPlusDB = {}
    end
    if seededDB ~= AuctionatorPlusDB then
        for key, value in pairs(AP.Defaults) do
            if AuctionatorPlusDB[key] == nil then AuctionatorPlusDB[key] = value end
        end
        seededDB = AuctionatorPlusDB
    end
    return AuctionatorPlusDB
end
