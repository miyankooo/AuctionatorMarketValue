-- Offline smoke test: loads every file in toc order against stubs of the WoW API and Auctionator, opens the
-- Auction House once and checks the tooltip rows, the stat filter, comparable clicks, Sale Scan and the parser.
-- Run from the addon folder: lua Tests/Load.lua

local failures = 0
local function check(label, ok, detail)
    if not ok then failures = failures + 1 end
    print((ok and "ok   " or "FAIL ") .. label .. (ok and "" or ("  (" .. tostring(detail) .. ")")))
end

-- ===== Frames =====
-- Script-capable stand-ins; methods (capitalised) a test does not care about do nothing, unset fields read nil
local frameMethods = {}
local function noop() end
frameMethods.__index = function(_, key)
    if frameMethods[key] then return frameMethods[key] end
    if type(key) == "string" and key:match("^%u") then return noop end
end

function frameMethods:SetScript(kind, fn) self.scripts[kind] = fn end
function frameMethods:GetScript(kind) return self.scripts[kind] end
function frameMethods:HookScript(kind, fn)
    local old = self.scripts[kind]
    self.scripts[kind] = function(...) if old then old(...) end fn(...) end
end
function frameMethods:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
function frameMethods:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end
function frameMethods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function frameMethods:IsShown() return self.shown end
function frameMethods:IsVisible() return self.shown and (not self.owner or self.owner:IsVisible()) end
function frameMethods:SetText(text) self.text = text end
function frameMethods:GetText() return self.text end
function frameMethods:GetTextWidth() return 7 * #(self.text or "") end
function frameMethods:GetStringWidth() return 7 * #(self.text or "") end
function frameMethods:GetStringHeight() return 12 end
function frameMethods:SetEnabled(enabled) self.enabled = enabled end
function frameMethods:IsEnabled() return self.enabled ~= false end
function frameMethods:SetChecked(checked) self.checked = checked and true or false end
function frameMethods:GetChecked() return self.checked end
function frameMethods:SetSize(w, h) self.width, self.height = w, h end
function frameMethods:SetWidth(w) self.width = w end
function frameMethods:SetHeight(h) self.height = h end
function frameMethods:GetWidth() return self.width or 0 end
function frameMethods:GetHeight() return self.height or 0 end
function frameMethods:Click(button) self.scripts.OnClick(self, button or "LeftButton") end
function frameMethods:CreateFontString() return CreateFrame("FontString", nil, self) end
function frameMethods:CreateTexture() return CreateFrame("Texture", nil, self) end
function frameMethods:SetupMenu(fn) self.menu = fn end

function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ scripts = {}, shown = true, owner = parent, kind = kind, template = template }, frameMethods)
    if template and template:find("Checkbox") then frame.Text = CreateFrame("FontString", nil, frame) end
    if template == "DialogHeaderTemplate" then frame.Setup = function(self, title) self.title = title end end
    if name then _G[name] = frame end
    return frame
end

UIParent = CreateFrame("Frame")
GameTooltip, ItemRefTooltip = CreateFrame("GameTooltip"), CreateFrame("GameTooltip")
UISpecialFrames = {}

-- ===== WoW API =====
strmatch = string.match
tinsert = table.insert
unpack = unpack or table.unpack
time = os.time

local nextFrame = {}
C_Timer = {
    After = function(_, fn) nextFrame[#nextFrame + 1] = fn end,
    NewTimer = function() return { Cancel = function() end } end,
}
local function runNextFrame()
    local queued = nextFrame
    nextFrame = {}
    for _, fn in ipairs(queued) do fn() end
end

function hooksecurefunc(target, method, hook)
    local original = target[method]
    target[method] = function(...) local a, b, c = original(...) hook(...) return a, b, c end
end

local function color(name)
    return { WrapTextInColorCode = function(_, text) return "<" .. name .. ">" .. text .. "</>" end }
end
HIGHLIGHT_FONT_COLOR, GREEN_FONT_COLOR, RED_FONT_COLOR = color("white"), color("green"), color("red")
GRAY_FONT_COLOR, YELLOW_FONT_COLOR, NORMAL_FONT_COLOR, WARNING_FONT_COLOR = color("gray"), color("yellow"), color("gold"), color("warn")
ITEM_QUALITY_COLORS = { [2] = { color = color("uncommon") } }

FILTER, CLEAR_ALL = "Filter", "Clear All"
SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT3_NAME, SPELL_STAT4_NAME, SPELL_STAT5_NAME = "Strength", "Agility", "Stamina", "Intellect", "Spirit"
ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC = "Equip:", "Use:", "Chance on hit:"
ITEM_SET_BONUS, ITEM_SET_BONUS_GRAY = "Set: %s", "(%d) Set: %s"
ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell Piercing"

Enum = {
    InventoryType = setmetatable({}, { __index = function() return 0 end }),
    ItemClass = { Armor = 4, Weapon = 2, Container = 1, Quiver = 11 },
    AuctionHouseSortOrder = { Price = 0 },
    TooltipDataType = { Item = 0 },
}

local tooltipPostCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipPostCall = fn end }
TooltipUtil = { GetDisplayedItem = function() return "Worn Sword", "item:25" end }

local tooltipLines = {}
function GameTooltip_AddBlankLineToTooltip() tooltipLines[#tooltipLines + 1] = "" end
function GameTooltip_AddColoredDoubleLine(_, left, right) tooltipLines[#tooltipLines + 1] = left .. "=" .. right end
function GameTooltip_SetTitle() end
function GameTooltip_AddHighlightLine() end
function GameTooltip_AddErrorLine() end
function GameTooltip_AddInstructionLine() end
function GameTooltip_Hide() end

C_Item = {
    GetItemInfoInstant = function() return 25, nil, nil, "INVTYPE_WEAPON", nil, 2, 7 end,
    GetItemInfo = function(link) return "Worn Sword", link, 2 end,
}
C_AuctionHouse = { MakeItemKey = function(itemID) return { itemID = itemID } end }
function FormatLargeNumber(n) return tostring(n) end
function IsModifiedClick() return false end
function InCombatLockdown() return false end

MenuUtil = { CreateRadioMenu = function(dropdown, isSelected, setSelected) dropdown.setSelected = setSelected end }
FrameUtil = { RegisterFrameForEvents = function() end }
EventUtil = { RegisterOnceFrameEventAndCallback = function() end }
SlashCmdList = {}

local registered = {}

-- An initializer stand-in that records its parent row and greying predicate
local function settingRow(setting)
    return { key = setting.key, SetParentInitializer = function(self, parent, predicate)
        registered[self.key].parent, registered[self.key].enabledWhen = parent.key, predicate
    end }
end

Settings = {
    VarType = { Boolean = "boolean", Number = "number" },
    RegisterVerticalLayoutCategory = function(name)
        local category = { GetID = function() return name end }
        return category, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(_, variable, key, db, varType, label, default)
        local entry = { label = label, default = default }
        registered[key] = entry
        return { SetValueChangedCallback = function() entry.repaints = true end, key = key }
    end,
    CreateCheckbox = function(_, setting) return settingRow(setting) end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateSlider = function(_, setting) return settingRow(setting) end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
function CreateSettingsListSectionHeaderInitializer() end

-- ===== Auctionator =====
local fired = {}
local listeners = {}
local historyBuilds = 0

local function provider()
    return {
        GetTableLayout = function() return {} end,
        Sort = function() end,
        PrettifyData = function() end,
        AppendEntries = function() end,
    }
end
AuctionatorShoppingTabDataProviderMixin = provider()
AuctionatorSearchDataProviderMixin = provider()
AuctionatorBuyItemDataProviderMixin = provider()
AuctionatorGroupsViewItemMixin = { SetItemInfo = function() end }
AuctionatorSellSearchRowMixin = { OnClick = function() end }

local eventBus = {}
function eventBus:Register(listener, events) for _, e in ipairs(events) do listeners[e] = listeners[e] or {} table.insert(listeners[e], listener) end end
function eventBus:RegisterSource() return self end
function eventBus:UnregisterSource() return self end
function eventBus:Fire(_, eventName, ...)
    fired[#fired + 1] = { eventName, ... }
    for _, listener in ipairs(listeners[eventName] or {}) do listener:ReceiveEvent(eventName, ...) end
    return self
end

local function events(...)
    local set = {}
    for _, name in ipairs({ ... }) do set[name] = name end
    return set
end

Auctionator = {
    EventBus = eventBus,
    Constants = { SCAN_DAY_0 = 0, SORT = { ASCENDING = 1 }, ITEM_TYPES = { ITEM = 1 } },
    Utilities = {
        IsEquipment = function(classID) return classID == 2 or classID == 4 end,
        CreatePaddedMoneyString = function(amount) return amount .. "c" end,
        DBKeyFromLink = function(_, callback) callback({ "25" }) end,
        DBKeyFromBrowseResult = function() return { "25" } end,
        ItemKeyString = function(key) return tostring(key.itemID) end,
    },
    Database = {
        GetFirstPrice = function() return 120 end,
        GetPriceHistory = function()
            historyBuilds = historyBuilds + 1
            return { { rawDay = math.floor(os.time() / 86400), minSeen = 100 } }
        end,
    },
    State = {},
    AH = { Events = events("ItemSearchResultsReady", "CommoditySearchResultsReady") },
    Selling = { Events = events("SellSearchStart", "ClearBagItem", "PriceSelected") },
    Shopping = { Tab = { Events = events("SearchStart", "SearchEnd") } },
    IncrementalScan = { Events = events("ScanStart", "ScanComplete", "ScanFailed") },
}

-- ===== Load in toc order =====
local AP = {}
for line in io.lines("AuctionatorMarketValue.toc") do
    if line:match("%.lua$") then
        local path = line:gsub("\\", "/")
        assert(loadfile(path))("AuctionatorMarketValue", AP)
    end
end
check("files load in toc order", true)

-- The AH frames Auctionator creates on first open
AuctionatorShoppingFrame = CreateFrame("Frame")
AuctionatorShoppingFrame.ShoppingResultsInset = CreateFrame("Frame")
AuctionatorShoppingFrame.ExportCSV = CreateFrame("Button")
AuctionatorShoppingFrame.DataProvider = {
    Reset = function(self) self.rows = {} end,
    AppendEntries = function(self, entries) for _, e in ipairs(entries) do table.insert(self.rows, e) end end,
    rows = {},
}
AuctionatorSellingFrame = CreateFrame("Frame")
AuctionatorSellingFrame.HistoricalPriceInset = CreateFrame("Frame")
AuctionatorSellingFrame.SaleItemFrame = CreateFrame("Frame")
AuctionatorSellingFrame.SaleItemFrame.Update = function() end

-- ===== Settings =====
AuctionatorMarketValueDB = nil
AP.SettingsPanel.Register()
check("Show Similar Items setting on by default", registered.showSimilar and registered.showSimilar.default == true and AP.DB().showSimilar == true)
check("no TSM or Guide settings", registered.glowRequireBoth == nil and registered.guideAtLogin == nil)
check("settings names in Title Case", registered.sellThresholdPct.label == "Sell Threshold", registered.sellThresholdPct.label)
check("only the threshold repaints the glow", registered.sellThresholdPct.repaints and not registered.levelTolerance.repaints)
check("range rows are children of Show Similar Items", registered.levelTolerance.parent == "showSimilar" and registered.statCountTolerance.parent == "showSimilar" and registered.sellThresholdPct.parent == nil)
AP.DB().showSimilar = false
check("range rows grey out while Show Similar Items is off", registered.levelTolerance.enabledWhen() == false)
AP.DB().showSimilar = true

-- ===== AH open =====
check("Similar ensure", AP.SimilarItems.Ensure())
check("Sale Scan ensure", AP.SaleScan.Ensure())
check("Shopping filter ensure", AP.ShoppingFilter.Ensure())

-- ===== Tooltip rows =====
tooltipPostCall(GameTooltip)
check("tooltip shows the two rows", tooltipLines[2] == "14-day average=100c" and tooltipLines[3] == "Last price vs average=<green>+20%</>", table.concat(tooltipLines, " | "))

-- ===== Memoised average =====
runNextFrame()
historyBuilds = 0
for _ = 1, 5 do AP.Trend.AverageFor("item:25") end
check("one history build per key per frame", historyBuilds == 1, historyBuilds)
runNextFrame()
AP.Trend.AverageFor("item:25")
check("next frame rebuilds", historyBuilds == 2, historyBuilds)

-- ===== Stat filter =====
local dialogName = "AuctionatorMarketValueStatFilterDialog"
check("dialog not built before the first click", _G[dialogName] == nil)

-- The module keeps its widgets in locals, so the test reads them from the closures
local function upvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return v end
        i = i + 1
    end
end
local ensureButton = upvalue(AP.ShoppingFilter.Ensure, "ensureButton")
local button = upvalue(ensureButton, "filterButton")
check("filter button reads Filter and is 24 tall", button and button.text == "Filter" and button.height == 24, button and button.text)
check("filter button sized for the longest label", button and button.width % 8 == 0 and button.width >= 64, button and button.width)
local width = button.width

button:Click()
local dialog = _G[dialogName]
check("dialog built and shown", dialog and dialog:IsShown())
check("dialog height on the grid", dialog.height == 456, dialog.height)

local strength = dialog.statChecks.strength
strength:SetChecked(true)
strength.scripts.OnClick(strength)
check("ticking a stat applies at once", AuctionatorMarketValueDB.shoppingStatFilter and AuctionatorMarketValueDB.shoppingStatFilter.stats.strength == true)
check("button shows the count", button.text == "Filter (1)", button.text)
check("button width never changes", button.width == width)
check("Clear All enabled with a filter", dialog.clearButton:IsEnabled())

dialog.logicDropdown.setSelected("OR")
check("logic change applies at once", AuctionatorMarketValueDB.shoppingStatFilter.logic == "OR")

dialog.clearButton.scripts.OnClick(dialog.clearButton)
check("Clear All empties the filter", AuctionatorMarketValueDB.shoppingStatFilter == nil and not strength:GetChecked())
check("button back to Filter", button.text == "Filter", button.text)
check("Clear All disabled without a filter", not dialog.clearButton:IsEnabled())

check("Escape closes the dialog through UISpecialFrames", UISpecialFrames[#UISpecialFrames] == dialogName)
AuctionatorShoppingFrame:Hide()
check("dialog closes with the shopping tab", not dialog:IsShown())
AuctionatorShoppingFrame:Show()
check("dialog stays closed on the next visit", not dialog:IsShown())

-- ===== Comparable click undercuts =====
fired = {}
AuctionatorSellSearchRowMixin.OnClick({ rowData = { apComparable = true, price = 500 } }, "LeftButton")
local last = fired[#fired]
check("comparable click undercuts", last and last[1] == "PriceSelected" and last[2].buyout == 500 and last[3] == true)

-- ===== Sale Scan disabled while slotted =====
local saleItem = AuctionatorSellingFrame.SaleItemFrame
local scanButton = upvalue(AP.SaleScan.Ensure, "scanButton")
check("Sale Scan enabled with an empty slot", scanButton:IsEnabled())
saleItem.itemInfo = { itemLink = "item:25" }
saleItem:Update()
check("Sale Scan disabled while an item is slotted", not scanButton:IsEnabled())
saleItem.itemInfo = nil
saleItem:Update()
check("Sale Scan enabled again after the slot clears", scanButton:IsEnabled())

-- ===== Parser =====
local stats = AP.ItemStats.FullStatSet("equip: decreases the magical resistances of your spell targets by 10.")
check("vanilla spell piercing parses", stats.spellpenetration == 10, stats.spellpenetration)

print(failures == 0 and "All checks passed." or (failures .. " checks failed."))
os.exit(failures == 0 and 0 or 1)
