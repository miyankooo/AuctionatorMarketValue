local _, AP = ...

-- Each returns true once its piece is in place in Auctionator's frames
local ENSURES = {
    AP.SaleScan.Ensure,
    AP.FullScanButton.Ensure,
    AP.GreatDeals.Ensure,
}

-- Retry until every piece is in place; Auctionator creates the host frames on or shortly after the first AH open
local function ensureButtons(attempt)
    local ready = true
    for _, ensure in ipairs(ENSURES) do
        if not ensure() then ready = false end
    end
    if ready or attempt > 20 then return end
    C_Timer.After(0.5, function() ensureButtons(attempt + 1) end)
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("AUCTION_HOUSE_SHOW")
bootstrap:SetScript("OnEvent", function()
    ensureButtons(1)
end)
