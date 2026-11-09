local _, AP = ...

-- The addon's page in Blizzard's Settings window, under Options > AddOns

local function plusPercent(value) return ("+%d%%"):format(value) end
local function minusPercent(value) return ("-%d%%"):format(value) end

-- Sections in display order; a row is key, label, help, then the slider's min, max, step and value formatter
local SECTIONS = {
    { "Selling", {
        { "sellThresholdPct", "Sell Threshold", "While you sell, percentages this far above the market value turn green and bag items glow green. As far below turns them red.", 5, 100, 1, plusPercent },
    } },
    { "Buying", {
        { "dealThresholdPct", "Deal Threshold", "While you buy, percentages this far below the market value turn green and rows in the Auction House buy lists glow green. As far above turns them red.", 5, 100, 1, minusPercent },
    } },
}

-- What the addon does, where it works and what stays the game's own, before any row asks for a choice
local INTRO = "Shows every auction price as a percentage of its market value: TSM's region sale average with "
    .. "the TSM desktop app, otherwise the 14-day average of Auctionator's scans. Green marks a good "
    .. "price, yellow a fair one and red a poor one, by the thresholds below. A gray percentage rests on fewer than 3 "
    .. "days of prices.\n\n"
    .. "The percentages show in item tooltips, in Auctionator's Shopping and Selling tabs and in Blizzard's auction "
    .. "lists. Deals glow green in Blizzard's buy lists, and items worth selling in the Selling tab's bag list. Item "
    .. "tooltips also judge whether now is a good time to buy or sell."

-- The addon's page in Blizzard's Settings window, as its own canvas, copying the settings list's look
-- (Blizzard_SettingsList.xml:14-30, Blizzard_SettingControls.xml, Blizzard_SettingControls.lua). Never a settings
-- list: a pick in a list dropdown runs addon code in Blizzard's pooled controls and taints its settings until /reload.
local ROW_HEIGHT, ROW_SPACING, LABEL_X, INTRO_Y, INTRO_GAP = 26, 9, 37, -64, 16
local categoryID

local function BuildPanel(introText, restoreDefaults)
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetJustifyH("LEFT")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(AP.title)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", 0, -50)
    local defaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    defaults:SetSize(96, 22)
    defaults:SetPoint("TOPRIGHT", -36, -16)
    defaults:SetText(SETTINGS_DEFAULTS)
    defaults:SetScript("OnClick", restoreDefaults)
    panel.intro = AP.CreateText(panel, GameFontHighlight)
    panel.intro:SetPoint("TOPLEFT", LABEL_X, INTRO_Y)
    panel.intro:SetPoint("TOPRIGHT", -LABEL_X, INTRO_Y)
    panel.intro:SetText(introText)
    return panel
end

-- One row below the previous one, its label in GameFontNormal from x 37 to the row's centre less 85. Its slider, a
-- MinimalSliderWithSteppersTemplate 250 wide, starts at the row's CENTER -40, 3 up. `above` is panel.intro for the
-- first row.
local CONTROL_X, SLIDER_WIDTH = -40, 250
local function AddRow(panel, above, label, fillTooltip)
    local gap = above == panel.intro and INTRO_GAP or ROW_SPACING
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", above == panel.intro and -LABEL_X or 0, -gap)
    row:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", above == panel.intro and LABEL_X or 0, -gap)
    row:EnableMouse(true)
    AP.AttachTooltip(row, fillTooltip)
    row.label = AP.CreateText(row, GameFontNormal)
    row.label:SetPoint("LEFT", LABEL_X, 0)
    row.label:SetPoint("RIGHT", row, "CENTER", -85, 0)
    row.label:SetText(label)
    return row
end

-- Blizzard's section header for a group of rows: a 45 px slot, the title in GameFontHighlightLarge at 7, -16
-- (Blizzard_SettingControls.xml:12-20). The next row anchors below it with `above` set to the header.
local function AddSectionHeader(panel, above, title)
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(45)
    header:SetPoint("TOPLEFT", above, "BOTTOMLEFT", above == panel.intro and -LABEL_X or 0, 0)
    header:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", above == panel.intro and LABEL_X or 0, 0)
    local text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetJustifyH("LEFT")
    text:SetPoint("TOPLEFT", 7, -16)
    text:SetText(title)
    return header
end

local function RegisterPanel(panel)
    local category = Settings.RegisterCanvasLayoutCategory(panel, AP.title)
    Settings.RegisterAddOnCategory(category)
    categoryID = category:GetID()
end

-- Opening in combat waits for combat to end, since the settings panel's open path has restrictions.
local waitingForCombat = false
function AP.OpenSettings()
    if not categoryID then return end
    if InCombatLockdown() then
        AP.Print("Opens after combat.")
        if not waitingForCombat then
            waitingForCombat = true
            EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
                waitingForCombat = false
                AP.OpenSettings()
            end)
        end
        return
    end
    Settings.OpenToCategory(categoryID)
end

-- The slider Blizzard's own settings use. Its Init takes a step count, not a step size.
local function CreateSlider(parent, width, name)
    local slider = CreateFrame("Frame", name, parent, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(width)
    return slider
end

-- Blizzard's settings slider row lifts the slider 3 px (SettingsSliderControlMixin:OnLoad, Blizzard_SettingControls.lua:715)
local SLIDER_Y = 3

-- Each slider by its setting key
local controls = {}

local function setValue(key, value)
    AP.DB()[key] = value
    -- Painted glows depend on the threshold
    if key == "sellThresholdPct" then AP.BagGlow.Repaint() end
end

local function fillFor(def)
    return function(tooltip)
        GameTooltip_SetTitle(tooltip, def[2])
        GameTooltip_AddNormalLine(tooltip, def[3])
    end
end

local function addSlider(panel, above, def)
    local key, label, _, minValue, maxValue, step, formatter = unpack(def)
    local fill = fillFor(def)
    local row = AddRow(panel, above, label, fill)
    local slider = CreateSlider(row, SLIDER_WIDTH)
    slider:SetPoint("LEFT", row, "CENTER", CONTROL_X, SLIDER_Y)
    slider:Init(AP.DB()[key], minValue, maxValue, (maxValue - minValue) / step, {
        [MinimalSliderWithSteppersMixin.Label.Right] = formatter,
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        -- Whole steps, whatever fraction the step division leaves
        setValue(key, math.floor(value + 0.5))
    end, row)
    -- The template's slider sets its own OnEnter, so the tooltip hooks it
    slider.Slider:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        fill(GameTooltip)
        GameTooltip:Show()
    end)
    slider.Slider:HookScript("OnLeave", GameTooltip_Hide)
    controls[key] = slider
    return row, slider
end

local function restoreDefaults()
    local db = AP.DB()
    for key, value in pairs(AP.Defaults) do
        db[key] = value
        controls[key]:SetValue(value)
    end
    AP.BagGlow.Repaint()
end

EventUtil.ContinueOnPlayerLogin(function()
    local panel = BuildPanel(INTRO, restoreDefaults)
    local above = panel.intro
    for _, section in ipairs(SECTIONS) do
        local title, rows = unpack(section)
        above = AddSectionHeader(panel, above, title)
        for _, def in ipairs(rows) do
            above = addSlider(panel, above, def)
        end
    end
    RegisterPanel(panel)
end)

-- One long command and the short alias /smv. The bare command opens the settings; help and intro are the shared words, and any other word prints the hint.
SLASH_SIMPLEMARKETVALUE1, SLASH_SIMPLEMARKETVALUE2 = "/simplemarketvalue", "/smv"
SlashCmdList.SIMPLEMARKETVALUE = function(message)
    local command = strtrim(message or ""):lower()
    if command == "" then
        AP.OpenSettings()
    elseif command == "help" or command == "?" then
        AP.Print("Type /smv for the settings, /smv intro to see the welcome line and the tip again, or /smv help for this list.")
    elseif command == "intro" then
        AP.ReplayIntro()
    else
        AP.Print("Unknown command. Type /smv help for the list.")
    end
end

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the menu row.
function SimpleMarketValue_CompartmentClick()
    AP.OpenSettings()
end

function SimpleMarketValue_CompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, AP.title)
    GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
    GameTooltip:Show()
end

function SimpleMarketValue_CompartmentLeave()
    GameTooltip:Hide()
end
