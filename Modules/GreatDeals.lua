local _, AP = ...

-- "Highlight Deals", a checkbox beside Full Scan on Auctionator's Shopping tab: while ticked, only great deals glow
-- green in the buy lists, Blizzard's and Auctionator's alike. A great deal is at least 50% under both TSM's sale
-- average and Auctionator's 14-day average with a TSM sale rate of 80% or more (AP.Trend.IsGreatDeal). The choice is saved, like a filter, and needs TSM's sale rates
AP.GreatDeals = {}

local LABEL = "Highlight Deals"

-- Space between the checkbox and Full Scan, the gap between related controls
local GAP = 8

-- Blizzard's own row highlight tinted green, the glow deal rows take in Blizzard's lists
local GLOW_ATLAS = "auctionhouse-ui-row-highlight"

-- Auctionator's buy lists, by the global name of the frame holding each: shopping results, and the buy screens of one
-- item and of one commodity. Auctionator makes them on or shortly after the first Auction House visit
local LISTING_HOLDERS = { "AuctionatorShoppingFrame", "AuctionatorBuyItemFrame", "AuctionatorBuyCommodityFrame" }

local checkbox
local attached = {}

-- On while the player turned it on and TSM's sale rates exist, so saved data that went missing never leaves every
-- list without a glow
function AP.GreatDeals.IsOn()
    return AP.DB().greatDeals == true and AP.TSM.HasSaleRates()
end

-- ===== Auctionator's rows =====
-- Per-row state lives here, keyed by Auctionator's rows, never on their frames
local WEAK = { __mode = "k" }
local glows, paintedData, paintedOn = setmetatable({}, WEAK), setmetatable({}, WEAK), setmetatable({}, WEAK)

local function glowFor(row)
    local glow = glows[row]
    if not glow then
        -- Over the row stripe Auctionator draws in OVERLAY at sublevel 0
        glow = row:CreateTexture(nil, "OVERLAY", nil, 1)
        glow:SetAtlas(GLOW_ATLAS)
        glow:SetAllPoints()
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(GREEN_FONT_COLOR:GetRGB())
        glows[row] = glow
    end
    return glow
end

-- Whether the switch is on in the pass under way, worked out once per frame instead of once per row
local passOn

-- The Relative column marks great deals on each entry as it decorates it, so a row only reads its mark, and only on a
-- change of its entry or of the switch
local function paintRow(row)
    local rowData, on = row.rowData, passOn
    if paintedData[row] == rowData and paintedOn[row] == on then return end
    paintedData[row], paintedOn[row] = rowData, on

    local great = on and type(rowData) == "table" and rowData.apGreatDeal == true
    if great or glows[row] then glowFor(row):SetShown(great) end
end

-- One painter per listing, a child of it, so it only runs while the listing shows; true once all are in place
local function attachListings()
    local done = true
    for _, holderName in ipairs(LISTING_HOLDERS) do
        local holder = _G[holderName]
        local listing = holder and holder.ResultsListing
        local scrollBox = listing and listing.ScrollArea and listing.ScrollArea.ScrollBox
        if not attached[holderName] and scrollBox then
            local painter = CreateFrame("Frame", nil, listing)
            painter:SetScript("OnUpdate", function()
                passOn = AP.GreatDeals.IsOn()
                scrollBox:ForEachFrame(paintRow)
            end)
            attached[holderName] = true
        end
        done = done and attached[holderName] == true
    end
    return done
end

-- ===== Checkbox =====
local function fillTooltip(tooltip)
    GameTooltip_SetTitle(tooltip, LABEL)
    GameTooltip_AddNormalLine(tooltip, ("Ticked, only great deals glow green in every buy list: items priced at least "
        .. "%d%% below both TSM's sale average and Auctionator's 14-day average, that TSM sees sell %d%% of the time or "
        .. "more. Unticked, Blizzard's buy lists glow every deal past your Deal Threshold.")
        :format(AP.Trend.GREAT_DEAL_PCT, AP.Trend.GREAT_DEAL_SALE_RATE))
    if not AP.TSM.HasSaleRates() then
        GameTooltip_AddErrorLine(tooltip, "Needs the sale rates of the TSM desktop app.")
    end
end

-- To the right of Full Scan, on the Export Results row, with its parent, so it hides whenever a buy screen covers the
-- results; true once the checkbox and every listing painter are in place
function AP.GreatDeals.Ensure()
    local listingsReady = attachListings()
    if checkbox then return listingsReady end
    local scanButton = AP.FullScanButton.Button()
    if not scanButton then return false end

    checkbox = AP.CreateCheckbox(scanButton:GetParent(), LABEL)
    checkbox:SetPoint("LEFT", scanButton, "RIGHT", GAP, 0)
    checkbox:SetChecked(AP.GreatDeals.IsOn())
    -- Off without TSM's sale rates: the box disabled and its label grey, as Blizzard greys an option that cannot
    -- apply, and the tooltip says why
    local enabled = AP.TSM.HasSaleRates()
    checkbox:SetEnabled(enabled)
    if not enabled then checkbox.Text:SetTextColor(GRAY_FONT_COLOR:GetRGB()) end
    checkbox:SetMotionScriptsWhileDisabled(true)
    AP.AttachTooltip(checkbox, fillTooltip)
    -- The template plays no sound, so the click plays the checkbox sounds Blizzard's options use
    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        AP.DB().greatDeals = checked
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end)
    return listingsReady
end
