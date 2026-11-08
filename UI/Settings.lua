local _, AP = ...

-- The addon's page in Blizzard's Settings window, under Options > AddOns

local function plusPercent(value) return ("+%d%%"):format(value) end
local function minusPercent(value) return ("-%d%%"):format(value) end
local function bandPercent(value) return ("±%d%%"):format(value) end

local function levels(value) return ("±%d levels"):format(value) end
local function plusMinus(value) return ("±%d"):format(value) end

-- Rows in display order: key, label, help, then min, max, step and value formatter for a slider, or checkbox = true.
-- A row with a parent greys out while that checkbox is off.
local ROWS = {
    { "sellThresholdPct", "Sell Threshold", "Bag items glow green once their last price sits this far above the 14-day average.", 5, 100, 1, plusPercent },
    { "dealThresholdPct", "Deal Threshold", "Rows in the Auction House buy lists glow green once their price sits this far below the 14-day average.", 5, 100, 1, minusPercent },
    { "showSimilar", "Show Similar Items", "With gear or a bag in the sale slot, comparable auctions join the current prices, marked Similar. Click one to undercut it.", checkbox = true },
    { "levelTolerance", "Level Range", "Comparable gear may require a level this far above or below the sale item.", 0, 10, 1, levels, parent = "showSimilar" },
    { "dpsTolerancePct", "Weapon DPS Range", "Comparable weapons must deal damage per second within this share of the sale item's.", 0, 50, 5, bandPercent, parent = "showSimilar" },
    { "statValueTolerance", "Stat Value Range", "Each stat of comparable gear must sit within this share of the sale item's amount.", 0, 100, 5, bandPercent, parent = "showSimilar" },
    { "statCountTolerance", "Stat Count Range", "Comparable gear must carry every stat of the sale item. Its total stat count may differ by this many.", 0, 5, 1, plusMinus, parent = "showSimilar" },
}

-- What the addon does, where it works and what stays the game's own, before any row asks for a choice
local INTRO = "Compares every auction price with its 14-day average from Auctionator's scans, and with TSM's market "
    .. "value where TradeSkillMaster has one. The percentages show in item tooltips, in Auctionator's Shopping and "
    .. "Selling tabs and in Blizzard's auction lists and sell windows. A gray percentage rests on fewer than 3 days "
    .. "of prices.\n\n"
    .. "Items worth selling glow green in the Selling tab's bag list, and deals glow green in Blizzard's buy lists. "
    .. "The settings below set both thresholds and which gear counts as similar. Scanning, buying and posting stay "
    .. "Auctionator's and Blizzard's own."

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

-- One row below the intro, its label in GameFontNormal from x 37 to the row's centre less 85. A checkbox
-- (SettingsCheckboxTemplate) goes at the row's CENTER -80, a WowStyle1DropdownTemplate 220 wide at CENTER -48.
-- Within one page, controls share one left edge.
local function AddRow(panel, index, label, fillTooltip)
    local y = -INTRO_GAP - (index - 1) * (ROW_HEIGHT + ROW_SPACING)
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", panel.intro, "BOTTOMLEFT", -LABEL_X, y)
    row:SetPoint("TOPRIGHT", panel.intro, "BOTTOMRIGHT", LABEL_X, y)
    row:EnableMouse(true)
    AP.AttachTooltip(row, fillTooltip)
    local text = AP.CreateText(row, GameFontNormal)
    text:SetPoint("LEFT", LABEL_X, 0)
    text:SetPoint("RIGHT", row, "CENTER", -85, 0)
    text:SetText(label)
    -- Kept for greying the label, as Blizzard's list does for a child setting
    row.text = text
    return row
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

-- Blizzard's settings slider sits 250 wide with its left edge at the row's CENTER -80, 3 up
-- (SettingsSliderControlMixin:OnLoad, Blizzard_SettingControls.lua:713-715); the checkbox shares that left edge
local CONTROL_X, SLIDER_WIDTH, SLIDER_Y = -80, 250, 3

-- Each row and control by its setting key
local rows, controls = {}, {}

-- A child row greys its label and control while its checkbox is off, as SettingsListElementMixin:DisplayEnabled does
local function updateEnabled()
    local db = AP.DB()
    for _, def in ipairs(ROWS) do
        if def.parent then
            local enabled = db[def.parent] == true
            rows[def[1]].text:SetTextColor((enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
            controls[def[1]]:SetEnabled(enabled)
        end
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

local function addSlider(panel, index, def)
    local key, label, _, minValue, maxValue, step, formatter = unpack(def)
    local fill = fillFor(def)
    local row = AddRow(panel, index, label, fill)
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
    rows[key], controls[key] = row, slider
end

-- The checkbox Blizzard's list builds for a checkbox row (SettingsCheckboxControlMixin), on the addon's own canvas.
-- Init wires the click to its own callback registry and its tooltip to SettingsTooltip.
local function addCheckbox(panel, index, def)
    local key, label = def[1], def[2]
    local fill = fillFor(def)
    local row = AddRow(panel, index, label, fill)
    local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
    checkbox:SetPoint("LEFT", row, "CENTER", CONTROL_X, 0)
    checkbox:Init(AP.DB()[key], function() fill(SettingsTooltip) end)
    checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, checked)
        setValue(key, checked)
    end, row)
    rows[key], controls[key] = row, checkbox
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
    for index, def in ipairs(ROWS) do
        if def.checkbox then addCheckbox(panel, index, def) else addSlider(panel, index, def) end
    end
    updateEnabled()
    RegisterPanel(panel)
end)

-- /ap already belongs to Blizzard's commentator commands, so the short form is /amv.
SLASH_AUCTIONATORMARKETVALUE1, SLASH_AUCTIONATORMARKETVALUE2 = "/auctionatormarketvalue", "/amv"
SlashCmdList.AUCTIONATORMARKETVALUE = AP.OpenSettings

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
