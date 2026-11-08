local addonName, AP = ...

-- The toc Title, the addon's in-game name, for chat lines, the settings page and the addon menu
AP.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

-- Setting defaults; the settings panel uses the same keys as its variable keys
AP.Defaults = {
    sellThresholdPct = 15,
    dealThresholdPct = 20,
    showSimilar = true,
    levelTolerance = 2,
    dpsTolerancePct = 20,
    statValueTolerance = 30,
    statCountTolerance = 0,
}

-- The table last seeded, so the defaults are filled once per saved table instead of on every call
local seededDB

-- Account-wide store for the settings. Seeds missing defaults itself, so readers never see nil even before the settings panel registers
function AP.DB()
    if type(AuctionatorMarketValueDB) ~= "table" then
        AuctionatorMarketValueDB = {}
    end
    if seededDB ~= AuctionatorMarketValueDB then
        for key, value in pairs(AP.Defaults) do
            if AuctionatorMarketValueDB[key] == nil then AuctionatorMarketValueDB[key] = value end
        end
        seededDB = AuctionatorMarketValueDB
    end
    return AuctionatorMarketValueDB
end

-- Every chat line: the bracketed title in the gold of Blizzard's own chat links, the message uncoloured
function AP.Print(message)
    print(NORMAL_FONT_COLOR:WrapTextInColorCode("[" .. AP.title .. "]") .. ": " .. message)
end

-- Text in a font role: GameFontNormal (heading, gold), GameFontHighlight (body, white), GameFontDisable (muted,
-- grey), GameFontNormalLarge (title, 16 px, a dialog's subject line only).
function AP.CreateText(parent, fontObject, layer)
    local text = parent:CreateFontString(nil, layer or "ARTWORK")
    text:SetFontObject(fontObject or GameFontHighlight)
    text:SetJustifyH("LEFT")
    return text
end

-- A GameTooltip owned by the hovered frame, filled with Blizzard's GameTooltip_* line helpers. A frame whose
-- template already sets OnEnter gets HookScript instead.
function AP.AttachTooltip(frame, fill, anchor)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        fill(GameTooltip, self)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- A content button one row (24) tall. Without a width it fits its label the way UIPanelButtonTemplate's FitToText
-- does (text plus 40, SecureUIPanelTemplates.xml:42), at least 64, rounded up to 8 so neighbours share widths.
function AP.CreateButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(label)
    width = width or math.max(64, math.ceil((button:GetTextWidth() + 40) / 8) * 8)
    button:SetSize(width, 24)
    return button
end
