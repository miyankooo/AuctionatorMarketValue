local _, AP = ...

-- The addon's page in Blizzard's Settings window, under Options > AddOns

local function plusPercent(value) return ("+%d%%"):format(value) end
local function minusPercent(value) return ("-%d%%"):format(value) end
local function bandPercent(value) return ("±%d%%"):format(value) end

local function levels(value) return ("±%d levels"):format(value) end
local function plusMinus(value) return ("±%d"):format(value) end

-- Sections in display order; a row is key, label, help, then min, max, step and value formatter for a slider, or
-- checkbox = true. A row with a parent is indented and greys out while that checkbox is off.
local SECTIONS = {
    { "Bag Glow", {
        { "sellThresholdPct", "Sell Threshold", "Bag items glow green once their last price sits this far above the 14-day average.", 5, 100, 1, plusPercent },
    } },
    { "Deals", {
        { "dealThresholdPct", "Deal Threshold", "Rows in the Auction House buy lists glow green once their price sits this far below the 14-day average.", 5, 100, 1, minusPercent },
    } },
    { "Similar Items", {
        { "showSimilar", "Show Similar Items", "With gear or a bag in the sale slot, comparable auctions join the current prices, marked Similar. Click one to undercut it.", checkbox = true },
        { "levelTolerance", "Level Range", "Comparable gear may require a level this far above or below the sale item.", 0, 10, 1, levels, parent = "showSimilar" },
        { "dpsTolerancePct", "Weapon DPS Range", "Comparable weapons must deal damage per second within this share of the sale item's.", 0, 50, 5, bandPercent, parent = "showSimilar" },
        { "statValueTolerance", "Stat Value Range", "Each stat of comparable gear must sit within this share of the sale item's amount.", 0, 100, 5, bandPercent, parent = "showSimilar" },
        { "statCountTolerance", "Stat Count Range", "Comparable gear must carry every stat of the sale item. Its total stat count may differ by this many.", 0, 5, 1, plusMinus, parent = "showSimilar" },
    } },
}

-- What the addon does, where it works and what stays the game's own, before any row asks for a choice
local INTRO = "Compares every auction price with its 14-day average from Auctionator's scans, and with TSM's market "
    .. "value where TradeSkillMaster has one. The percentages show in item tooltips, in Auctionator's Shopping and "
    .. "Selling tabs and in Blizzard's auction lists and sell windows. A gray percentage rests on fewer than 3 days "
    .. "of prices.\n\n"
    .. "Items worth selling glow green in the Selling tab's bag list, and deals glow green in Blizzard's buy lists. "
    .. "Scanning, buying and posting stay Auctionator's and Blizzard's own."

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

-- One row below the previous one, its label in GameFontNormal from x 37 (52 for a dependent row) to the row's centre
-- less 85. Every control starts at the row's CENTER -40: a SettingsCheckboxTemplate, a WowStyle1DropdownTemplate
-- 220 wide, or a MinimalSliderWithSteppersTemplate 250 wide and 3 up. `above` is panel.intro for the first row.
local CONTROL_X, DEPENDENT_INDENT, SLIDER_WIDTH = -40, 15, 250
local function AddRow(panel, above, label, fillTooltip, dependent)
    local gap = above == panel.intro and INTRO_GAP or ROW_SPACING
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", above == panel.intro and -LABEL_X or 0, -gap)
    row:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", above == panel.intro and LABEL_X or 0, -gap)
    row:EnableMouse(true)
    AP.AttachTooltip(row, fillTooltip)
    row.label = AP.CreateText(row, GameFontNormal)
    row.label:SetPoint("LEFT", LABEL_X + (dependent and DEPENDENT_INDENT or 0), 0)
    row.label:SetPoint("RIGHT", row, "CENTER", -85, 0)
    row.label:SetText(label)
    return row
end

-- A dependent row greys out while its parent option is off, as Blizzard's settings list does.
local function SetRowEnabled(row, control, enabled)
    row.label:SetTextColor((enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
    control:SetEnabled(enabled)
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

-- Each control by its setting key, and the dependent rows with their parent's key
local controls, dependents = {}, {}

local function updateEnabled()
    local db = AP.DB()
    for _, dependent in ipairs(dependents) do
        SetRowEnabled(dependent.row, dependent.control, db[dependent.parent] == true)
    end
end

local function setValue(key, value)
    AP.DB()[key] = value
    -- Painted glows depend on the threshold
    if key == "sellThresholdPct" then AP.BagGlow.Repaint() end
    updateEnabled()
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
    local row = AddRow(panel, above, label, fill, def.parent ~= nil)
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

-- The checkbox Blizzard's list builds for a checkbox row (SettingsCheckboxControlMixin), on the addon's own canvas.
-- Init wires the click to its own callback registry and its tooltip to SettingsTooltip.
local function addCheckbox(panel, above, def)
    local key, label = def[1], def[2]
    local fill = fillFor(def)
    local row = AddRow(panel, above, label, fill, def.parent ~= nil)
    local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
    checkbox:SetPoint("LEFT", row, "CENTER", CONTROL_X, 0)
    checkbox:Init(AP.DB()[key], function() fill(SettingsTooltip) end)
    checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, checked)
        -- The sound Blizzard's checkbox row plays on every change (SettingsCheckboxControlMixin:SetValue)
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        setValue(key, checked)
    end, row)
    -- A click on the label ticks the box, as the row's tooltip region does in Blizzard's list
    -- (SettingsCheckboxControlMixin:OnLoad, Blizzard_SettingControls.lua:617)
    row:SetScript("OnMouseUp", function()
        if checkbox:IsEnabled() then checkbox:Click() end
    end)
    controls[key] = checkbox
    return row, checkbox
end

local function restoreDefaults()
    local db = AP.DB()
    for key, value in pairs(AP.Defaults) do
        db[key] = value
        controls[key]:SetValue(value)
    end
    updateEnabled()
    AP.BagGlow.Repaint()
end

EventUtil.ContinueOnPlayerLogin(function()
    local panel = BuildPanel(INTRO, restoreDefaults)
    local above = panel.intro
    for _, section in ipairs(SECTIONS) do
        local title, rows = unpack(section)
        above = AddSectionHeader(panel, above, title)
        for _, def in ipairs(rows) do
            local row, control = (def.checkbox and addCheckbox or addSlider)(panel, above, def)
            if def.parent then
                dependents[#dependents + 1] = { row = row, control = control, parent = def.parent }
            end
            above = row
        end
    end
    updateEnabled()
    RegisterPanel(panel)
end)

-- One long command and one short alias; /ap already belongs to Blizzard's commentator commands, so the short form is
-- /amv. The bare command opens the settings; help and intro are the shared words, and any other word prints the hint.
SLASH_AUCTIONATORMARKETVALUE1, SLASH_AUCTIONATORMARKETVALUE2 = "/auctionatormarketvalue", "/amv"
SlashCmdList.AUCTIONATORMARKETVALUE = function(message)
    local command = strtrim(message or ""):lower()
    if command == "" then
        AP.OpenSettings()
    elseif command == "help" or command == "?" then
        AP.Print("Type /amv for the settings, /amv intro to see the welcome line and the tip again, or /amv help for this list.")
    elseif command == "intro" then
        AP.ReplayIntro()
    else
        AP.Print("Unknown command. Type /amv help for the list.")
    end
end

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the menu row.
function AuctionatorMarketValue_CompartmentClick()
    AP.OpenSettings()
end

function AuctionatorMarketValue_CompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, AP.title)
    GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
    GameTooltip:Show()
end

function AuctionatorMarketValue_CompartmentLeave()
    GameTooltip:Hide()
end
