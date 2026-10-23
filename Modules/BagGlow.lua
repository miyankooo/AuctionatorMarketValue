local _, AP = ...

AP.BagGlow = {}

-- The atlas the default bags use for new uncommon items; bright under ADD blending, so it stays visible next to green-quality borders
local GLOW_ATLAS = "bags-glow-green"

-- Glow once the last known price sits the sell threshold or more above the average
local function favorable(itemLink)
    local price = AP.Bridge.AuctionPrice(itemLink)
    local pct = AP.Trend.Percent(price, AP.Trend.AverageFor(itemLink))
    return pct ~= nil and pct >= AP.DB().sellThresholdPct
end

local function apply(button, itemLink)
    if itemLink and favorable(itemLink) then
        local glow = button.apGlow
        if not glow then
            glow = button:CreateTexture(nil, "OVERLAY", nil, 1)
            glow:SetAllPoints(button.Icon)
            glow:SetBlendMode("ADD")
            glow:SetAtlas(GLOW_ATLAS)
            button.apGlow = glow
        end
        glow:Show()
    elseif button.apGlow then
        button.apGlow:Hide()
    end
end

-- Every item button of the selling tab's bag panel, with its item info; nothing before the AH first opened
function AP.BagGlow.EachButton(fn)
    local listing = AuctionatorSellingFrame and AuctionatorSellingFrame.BagListing
    local view = listing and listing.View
    if not view or type(view.itemMap) ~= "table" then return end

    for _, group in pairs(view.itemMap) do
        for _, button in pairs(group) do
            if type(button) == "table" and button.itemInfo then
                fn(button, button.itemInfo)
            end
        end
    end
end

-- Re-evaluate every bag button in place, for callers that changed prices or settings without touching the bags
function AP.BagGlow.Repaint()
    AP.BagGlow.EachButton(function(button, info)
        apply(button, info.itemLink)
    end)
end

-- Post-hook the mixin before any buttons exist; SetItemInfo runs on every refresh, so recycled buttons drop the glow on their own when an item stops being favorable
hooksecurefunc(AuctionatorGroupsViewItemMixin, "SetItemInfo", function(self, info)
    apply(self, info and info.itemLink)
end)
