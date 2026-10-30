local _, AP = ...

local UI = LibStub("LibNativeUI-1.0")

AP.ShoppingFilter = {}

-- Filterable stats in dialog order, physical column first; every key matches AP.ItemStats.FullStatSet
local STAT_ORDER = {
    "strength", "agility", "stamina", "intellect", "spirit",
    "attackpower", "rangedattackpower", "hit", "crit", "haste", "expertise", "armorpenetration", "defense",
    "spellpower", "healing", "spellhit", "spellcrit", "spellpenetration", "mp5",
    "arcanedamage", "firedamage", "frostdamage", "holydamage", "naturedamage", "shadowdamage",
}

-- Labels are the client's own stat names, so they match the item tooltips in every locale
local FILTER_LABELS = {
    attackpower = ITEM_MOD_ATTACK_POWER_SHORT,
    rangedattackpower = ITEM_MOD_RANGED_ATTACK_POWER_SHORT,
    hit = ITEM_MOD_HIT_RATING_SHORT,
    crit = ITEM_MOD_CRIT_RATING_SHORT,
    haste = ITEM_MOD_HASTE_RATING_SHORT,
    expertise = ITEM_MOD_EXPERTISE_RATING_SHORT,
    armorpenetration = ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT,
    defense = ITEM_MOD_DEFENSE_SKILL_RATING_SHORT,
    spellpower = ITEM_MOD_SPELL_POWER_SHORT,
    healing = ITEM_MOD_SPELL_HEALING_DONE_SHORT,
    spellhit = ITEM_MOD_HIT_SPELL_RATING_SHORT,
    spellcrit = ITEM_MOD_CRIT_SPELL_RATING_SHORT,
    spellpenetration = ITEM_MOD_SPELL_PENETRATION_SHORT,
    mp5 = ITEM_MOD_MANA_REGENERATION_SHORT,
    arcanedamage = ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT,
    firedamage = ITEM_MOD_FIRE_DAMAGE_DONE_SHORT,
    frostdamage = ITEM_MOD_FROST_DAMAGE_DONE_SHORT,
    holydamage = ITEM_MOD_HOLY_DAMAGE_DONE_SHORT,
    naturedamage = ITEM_MOD_NATURE_DAMAGE_DONE_SHORT,
    shadowdamage = ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT,
}
for key, label in pairs(AP.ItemStats.STAT_LABELS) do
    FILTER_LABELS[key] = label
end

-- The dialog's stats as a set, for dropping saved keys it no longer lists
local OFFERED = {}
for _, key in ipairs(STAT_ORDER) do
    OFFERED[key] = true
end

local FILTER_COLUMNS = 2
local FILTER_ROWS = math.ceil(#STAT_ORDER / FILTER_COLUMNS)
local COLUMN_WIDTH = 208
local DROPDOWN_WIDTH = 120
local DIALOG_WIDTH = 2 * UI.Space.dialog + FILTER_COLUMNS * COLUMN_WIDTH

local filterButton, dialog
local provider, originalAppend

-- Every entry Auctionator appended for the current search, in arrival order, so a filter change rebuilds the visible rows without a new search
local allEntries = {}

-- Bumps on every search start and refilter; stale item-load callbacks compare against it and drop out
local generation = 0

-- Offered stats of a saved filter; a saved key the dialog no longer lists never constrains it
local function offeredStats(stats)
    local kept = {}
    for key in pairs(stats) do
        if OFFERED[key] then kept[key] = true end
    end
    return kept
end

-- Account-wide filter: { stats = { strength = true, ... }, logic = "AND"|"OR" }; nil when unset
local function activeFilter()
    local filter = AP.DB().shoppingStatFilter
    if type(filter) ~= "table" or type(filter.stats) ~= "table" then return nil end
    local stats = offeredStats(filter.stats)
    if not next(stats) then return nil end
    return { stats = stats, logic = filter.logic }
end

-- A school filter is also met by generic spell power, which boosts every school
local function hasStat(present, key)
    if present[key] then return true end
    return key:match("damage$") ~= nil and present.spellpower ~= nil
end

local function statsMatch(itemText, filter)
    local present = AP.ItemStats.FullStatSet(itemText)
    if filter.logic == "OR" then
        for key in pairs(filter.stats) do
            if hasStat(present, key) then return true end
        end
        return false
    end

    for key in pairs(filter.stats) do
        if not hasStat(present, key) then return false end
    end
    return true
end

-- Whether a result survives the filter: equipment must carry the chosen stats, while consumables, trade goods and missing-term placeholders (which carry the unobtainable non-equipment item 1217) always stay. Second return asks for a retry once the item cache fills
local function entryMatches(entry, filter)
    local itemRef = entry.itemKey
    if not itemRef then return true, false end

    local classID = select(6, AP.ItemStats.InstantInfo(itemRef))
    if not AP.Bridge.IsEquipment(classID) then return true, false end

    local itemText = AP.ItemStats.Text(itemRef)
    if not itemText then return false, true end

    return statsMatch(itemText, filter), false
end

local function filterLabel(count)
    return ("%s (%d)"):format(FILTER, count)
end

local function updateButtonState()
    local filter = activeFilter()
    if filterButton then
        filterButton:SetText(filter and filterLabel(AP.ItemStats.Count(filter.stats)) or FILTER)
    end
    if dialog then dialog.clearButton:SetEnabled(filter ~= nil) end
end

-- Re-append an uncached entry once its item data arrives, if it matches by then; the provider dedups by item, so double appends are safe
local function retryOnLoad(entry)
    local itemID = AP.ItemStats.InstantInfo(entry.itemKey)
    if not itemID then return end

    local startedGeneration = generation
    Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
        if generation ~= startedGeneration then return end

        local filter = activeFilter()
        if filter and not entryMatches(entry, filter) then return end
        originalAppend(provider, { entry }, provider.searchCompleted)
    end)
end

local function filterEntries(entries)
    local filter = activeFilter()
    if not filter then return entries end

    local kept = {}
    for _, entry in ipairs(entries) do
        local matched, needsLoad = entryMatches(entry, filter)
        if matched then
            kept[#kept + 1] = entry
        elseif needsLoad then
            retryOnLoad(entry)
        end
    end
    return kept
end

-- Rebuild the visible rows from the recorded entries under the current filter; Auctionator's search stays untouched
local function reapplyFilter()
    updateButtonState()
    if not originalAppend then return end

    generation = generation + 1
    local searchWasComplete = provider.searchCompleted
    provider:Reset()
    originalAppend(provider, filterEntries(allEntries), searchWasComplete)
end

local function readControls()
    local stats = {}
    for _, key in ipairs(STAT_ORDER) do
        if dialog.statChecks[key]:GetChecked() then
            stats[key] = true
        end
    end

    if not next(stats) then return nil end
    return { stats = stats, logic = dialog.statLogic }
end

local function applyToControls(filter)
    for _, key in ipairs(STAT_ORDER) do
        dialog.statChecks[key]:SetChecked(filter and filter.stats[key])
    end
    dialog.statLogic = filter and filter.logic or "AND"

    -- GenerateMenu re-runs the radio setup so the button text reflects the applied value
    dialog.logicDropdown:GenerateMenu()
end

-- Every change applies at once, so the dialog needs no Apply button
local function saveControls()
    AP.DB().shoppingStatFilter = readControls()
    reapplyFilter()
end

local function clearFilter()
    AP.DB().shoppingStatFilter = nil
    applyToControls(nil)
    reapplyFilter()
end

-- Two columns of stat checkboxes in one block, filled top to bottom
local function createStatGrid(parent)
    local grid = CreateFrame("Frame", nil, parent)
    grid:SetSize(FILTER_COLUMNS * COLUMN_WIDTH, FILTER_ROWS * UI.Size.row)
    dialog.statChecks = {}
    for index, key in ipairs(STAT_ORDER) do
        local check = UI.CreateCheckbox(grid, FILTER_LABELS[key])
        local column = math.floor((index - 1) / FILTER_ROWS)
        local row = (index - 1) % FILTER_ROWS
        check:SetPoint("TOPLEFT", grid, "TOPLEFT", column * COLUMN_WIDTH, -row * UI.Size.row)
        check:SetScript("OnClick", saveControls)
        dialog.statChecks[key] = check
    end
    return grid
end

-- Parented to the shopping frame so it hides with the Auction House. Escape closes it with the Auction House through UISpecialFrames; an addon-registered GameMenuEsc handler would taint Escape in combat
local function buildDialog()
    dialog = UI.CreateDialog({ name = "AuctionatorMarketValueStatFilterDialog", title = "Stat Filter", width = DIALOG_WIDTH, parent = AuctionatorShoppingFrame })

    dialog.statLogic = "AND"
    local logicDropdown = UI.CreateDropdown(dialog, DROPDOWN_WIDTH)
    MenuUtil.CreateRadioMenu(logicDropdown,
        function(value) return dialog.statLogic == value end,
        function(value)
            dialog.statLogic = value
            saveControls()
        end,
        { "Match All", "AND" },
        { "Match Any", "OR" })
    dialog.logicDropdown = logicDropdown

    -- The native 25 px dropdown sits in a slot snapped to the grid
    dialog:AddField(logicDropdown, UI.Snap(UI.Native.dropdownHeight), nil, UI.Native.dropdownArt)
    dialog:AddField(createStatGrid(dialog), FILTER_ROWS * UI.Size.row, UI.Space.gap)
    dialog.clearButton = dialog:AddButton(CLEAR_ALL, clearFilter)
    dialog:Fit()

    dialog:SetScript("OnShow", function()
        applyToControls(activeFilter())
        updateButtonState()
    end)

    -- Closed with its tab, so it never reopens by itself on the next visit
    AuctionatorShoppingFrame:HookScript("OnHide", function() dialog:Hide() end)
end

-- Bottom-left of the results inset, on the Export Results row. Parented to that button so it hides with it whenever a buy screen covers the results. Sized once for the longest label, so the count never moves it
local function ensureButton()
    if filterButton then return true end
    local shoppingFrame = AuctionatorShoppingFrame
    local inset = shoppingFrame and shoppingFrame.ShoppingResultsInset
    local exportButton = shoppingFrame and shoppingFrame.ExportCSV
    if not inset or not exportButton then return false end

    filterButton = UI.CreateButton(exportButton, filterLabel(#STAT_ORDER))
    filterButton:SetPoint("LEFT", inset, "LEFT", 0, 0)
    filterButton:SetPoint("BOTTOM", exportButton, "BOTTOM", 0, 0)
    filterButton:SetScript("OnClick", function()
        if not dialog then buildDialog() end
        dialog:SetShown(not dialog:IsShown())
    end)

    updateButtonState()
    return true
end

-- Instance wrap, not a mixin hook: record the unfiltered entries and forward only survivors, leaving Auctionator's search pipeline untouched
local function installProviderFilter()
    if originalAppend then return true end

    provider = AuctionatorShoppingFrame and AuctionatorShoppingFrame.DataProvider
    if not provider or type(provider.AppendEntries) ~= "function" then return false end

    originalAppend = provider.AppendEntries
    provider.AppendEntries = function(self, entries, isLastSet)
        for _, entry in ipairs(entries) do
            allEntries[#allEntries + 1] = entry
        end
        return originalAppend(self, filterEntries(entries), isLastSet)
    end
    return true
end

AP.Bridge.Listen({ Auctionator.Shopping.Tab.Events.SearchStart }, function()
    generation = generation + 1
    allEntries = {}
end)

function AP.ShoppingFilter.Ensure()
    local buttonsReady = ensureButton()
    local providerReady = installProviderFilter()
    return buttonsReady and providerReady
end
