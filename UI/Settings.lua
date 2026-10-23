local _, AP = ...

local UI = LibStub("LibNativeUI-1.0")

-- Options page under Options > AddOns
AP.SettingsPanel = {}

local TITLE = "Auctionator Plus"

local function plusPercent(value) return ("+%d%%"):format(value) end
local function bandPercent(value) return ("±%d%%"):format(value) end

local function levels(value) return ("±%d levels"):format(value) end
local function plusMinus(value) return ("±%d"):format(value) end

-- Sections in display order; a control is key, label, tooltip, then min, max, step, value formatter for sliders or checkbox = true
local SECTIONS = {
    { "Bag Glow", {
        { "sellThresholdPct", "Sell Threshold", "Bag items glow green once their last price sits this far above the 14-day average.", 5, 100, 1, plusPercent },
    } },
    { "Similar Items", {
        { "showSimilar", "Show Similar Items", "With gear or a bag in the sale slot, comparable auctions join the current prices, marked Similar. Click one to undercut it.", checkbox = true },
        { "levelTolerance", "Level Range", "Comparable gear may require a level this far above or below the sale item.", 0, 10, 1, levels },
        { "dpsTolerancePct", "Weapon DPS Range", "Comparable weapons must deal damage per second within this share of the sale item's.", 0, 50, 5, bandPercent },
        { "statValueTolerance", "Stat Value Range", "Each stat of comparable gear must sit within this share of the sale item's amount.", 0, 100, 5, bandPercent },
        { "statCountTolerance", "Stat Count Range", "Comparable gear must carry every stat of the sale item. Its total stat count may differ by this many.", 0, 5, 1, plusMinus },
    } },
}

local category

local function addControl(db, def)
    local key, label, tooltip, minValue, maxValue, step, formatter = unpack(def)
    local varType = def.checkbox and Settings.VarType.Boolean or Settings.VarType.Number
    local setting = Settings.RegisterAddOnSetting(category, "AUCTIONATORPLUS_" .. key:upper(), key, db, varType, label, AP.Defaults[key])
    if def.checkbox then
        return Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Painted glows depend on the threshold
    if key == "sellThresholdPct" then
        setting:SetValueChangedCallback(AP.BagGlow.Repaint)
    end
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    return Settings.CreateSlider(category, setting, options, tooltip)
end

function AP.SettingsPanel.Register()
    local db = AP.DB()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(TITLE)

    for _, section in ipairs(SECTIONS) do
        local title, controls = unpack(section)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
        local parentRow, parentKey
        for _, def in ipairs(controls) do
            local row = addControl(db, def)

            -- A section's checkbox leads it, and the range rows below grey out while it is off
            if def.checkbox then
                parentRow, parentKey = row, def[1]
            elseif parentRow then
                row:SetParentInitializer(parentRow, function() return AP.DB()[parentKey] end)
            end
        end
    end

    Settings.RegisterAddOnCategory(category)
end

local waitingForCombat = false

-- C_SettingsUtil.OpenSettingsPanel is flagged HasRestrictions (SettingsUtilDocumentation.lua:17), so a request in combat waits until combat ends, once however often it was asked
function AP.SettingsPanel.Open()
    if not category then return end

    if InCombatLockdown() then
        UI.Print(TITLE, "Opens after combat.")
        if not waitingForCombat then
            waitingForCombat = true
            EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
                waitingForCombat = false
                AP.SettingsPanel.Open()
            end)
        end
        return
    end

    Settings.OpenToCategory(category:GetID())
end

-- /ap already belongs to Blizzard's commentator commands, so the short form is /aplus.
SLASH_AUCTIONATORPLUS1, SLASH_AUCTIONATORPLUS2 = "/auctionatorplus", "/aplus"
SlashCmdList.AUCTIONATORPLUS = AP.SettingsPanel.Open

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the menu row.
function AuctionatorPlus_CompartmentClick()
    AP.SettingsPanel.Open()
end

function AuctionatorPlus_CompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, TITLE)
    GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
    GameTooltip:Show()
end

function AuctionatorPlus_CompartmentLeave()
    GameTooltip:Hide()
end
