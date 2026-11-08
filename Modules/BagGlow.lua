local _, AP = ...

AP.BagGlow = {}

-- Glow once the last known price sits the sell threshold or more above an average with enough days behind it
local function favorable(itemLink)
    local _, pct, days = AP.Trend.Relative(AP.Bridge.AuctionPrice(itemLink), itemLink)
    return pct ~= nil and days >= AP.Trend.MIN_DAYS and pct >= AP.DB().sellThresholdPct
end

-- Marks an item the addon recommends: the default bags' new-item glow on the item's icon, ADD blended so it stays
-- visible next to a quality border. One texture per button, made on first need.
local function ShowItemGlow(itemButton, shown)
    local glow = itemButton.addonGlow
    if shown and not glow then
        glow = itemButton:CreateTexture(nil, "OVERLAY", nil, 1)
        glow:SetAllPoints(itemButton.Icon)
        glow:SetBlendMode("ADD")
        glow:SetAtlas("bags-glow-green")
        itemButton.addonGlow = glow
    end
    if glow then glow:SetShown(shown) end
end

local function apply(button, itemLink)
    ShowItemGlow(button, itemLink ~= nil and favorable(itemLink))
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
