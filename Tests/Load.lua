-- Offline smoke test: loads every file in toc order against stubs of the WoW API and Auctionator, logs in and opens
-- the Auction House once, and checks the welcome line, the settings page, the tooltip rows, the Full Scan button and
-- its help tip, comparable clicks, Sale Scan, the parser, Blizzard's auction lists and the slash commands.
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
function frameMethods:CreateFontString(_, _, fontObject) return CreateFrame("FontString", nil, self, fontObject) end
function frameMethods:CreateTexture() return CreateFrame("Texture", nil, self) end
function frameMethods:SetupMenu(fn) self.menu = fn end
function frameMethods:SetAtlas(atlas) self.atlas = atlas end
function frameMethods:SetTextColor(r) self.color = r end
function frameMethods:SetPoint(point, relativeTo, relativePoint, x, y) self.points = self.points or {} self.points[point] = { relativeTo, relativePoint, x, y } end

-- Blizzard's callback registry on the settings slider and checkbox: callbacks run with their owner first
local function registerCallback(self, _, fn, owner) table.insert(self.callbacks, function(...) fn(owner, ...) end) end
local function triggerEvent(self, ...) for _, fn in ipairs(self.callbacks) do fn(...) end end

-- MinimalSliderWithSteppersTemplate: Init takes a step count, and a changed value fires OnValueChanged
local sliderMethods = {
    Init = function(self, value, minValue, maxValue, steps, formatters)
        self.value, self.minValue, self.maxValue, self.steps, self.formatters = value, minValue, maxValue, steps, formatters
    end,
    SetValue = function(self, value)
        if value == self.value then return end
        self.value = value
        triggerEvent(self, value)
    end,
}

-- SettingsCheckboxTemplate: Init sets the value and the tooltip function, a click fires OnValueChanged
local checkboxMethods = {
    Init = function(self, value, tooltipFunc) self.checked, self.tooltipFunc = value, tooltipFunc end,
    SetValue = function(self, value) self.checked = value end,
    Click = function(self)
        self.checked = not self.checked
        triggerEvent(self, self.checked)
    end,
}

-- Frames by template, so tests find what the addon built
local templated = {}

function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ scripts = {}, shown = true, owner = parent, kind = kind, template = template }, frameMethods)
    if template and template:find("Checkbox") then frame.Text = CreateFrame("FontString", nil, frame) end
    if template == "DialogHeaderTemplate" then frame.Setup = function(self, title) self.title = title end end
    if template == "MinimalSliderWithSteppersTemplate" then
        for key, fn in pairs(sliderMethods) do frame[key] = fn end
        frame.Slider = CreateFrame("Slider", nil, frame)
    end
    if template == "SettingsCheckboxTemplate" then
        for key, fn in pairs(checkboxMethods) do frame[key] = fn end
    end
    -- HelpTipTemplate starts hidden; Acknowledge closes it and runs the info's callback
    if template == "HelpTipTemplate" then
        frame.shown = false
        frame.Init = function(self, _, info, relativeRegion) self.info, self.relativeRegion = info, relativeRegion end
        frame.Acknowledge = function(self)
            local info = self.info
            self.info, self.shown = nil, false
            info.onAcknowledgeCallback()
        end
    end
    if template then
        frame.callbacks, frame.RegisterCallback = {}, registerCallback
        templated[template] = templated[template] or {}
        table.insert(templated[template], frame)
    end
    if name then _G[name] = frame end
    return frame
end

UIParent = CreateFrame("Frame")
GameTooltip, ItemRefTooltip, SettingsTooltip = CreateFrame("GameTooltip"), CreateFrame("GameTooltip"), CreateFrame("GameTooltip")

-- ===== WoW API =====
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Title" and "Auctionator Market Value" or nil end }
strmatch = string.match
function strtrim(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
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
    -- GetRGB answers the name, so a test reads which colour a text took
    return { WrapTextInColorCode = function(_, text) return "<" .. name .. ">" .. text .. "</>" end, GetRGB = function() return name end }
end
HIGHLIGHT_FONT_COLOR, GREEN_FONT_COLOR, RED_FONT_COLOR = color("white"), color("green"), color("red")
GRAY_FONT_COLOR, YELLOW_FONT_COLOR, NORMAL_FONT_COLOR, WARNING_FONT_COLOR = color("gray"), color("yellow"), color("gold"), color("warn")
ITEM_QUALITY_COLORS = { [2] = { color = color("uncommon") } }

SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT3_NAME, SPELL_STAT4_NAME, SPELL_STAT5_NAME = "Strength", "Agility", "Stamina", "Intellect", "Spirit"
ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC = "Equip:", "Use:", "Chance on hit:"
ITEM_SET_BONUS, ITEM_SET_BONUS_GRAY = "Set: %s", "(%d) Set: %s"
ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell Piercing"

Enum = {
    InventoryType = setmetatable({}, { __index = function() return 0 end }),
    ItemClass = { Armor = 4, Weapon = 2, Container = 1, Quiver = 11 },
    AuctionHouseSortOrder = { Price = 0 },
    TooltipDataType = { Item = 0 },
    GameRule = { HardcoreRuleset = 10, PvPRuleset = 213, RPRuleset = 214 },
}
C_GameRules = { IsGameRuleActive = function(rule) return rule == Enum.GameRule.PvPRuleset end }
function UnitFactionGroup() return "Alliance", "Alliance" end
function strsplit(sep, text)
    local parts = {}
    for part in (text .. sep):gmatch("(.-)" .. sep) do parts[#parts + 1] = part end
    return table.unpack(parts)
end

local tooltipPostCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipPostCall = fn end }
TooltipUtil = { GetDisplayedItem = function() return "Worn Sword", "item:25" end }

local tooltipLines = {}
function GameTooltip_AddBlankLineToTooltip() tooltipLines[#tooltipLines + 1] = "" end
function GameTooltip_AddColoredDoubleLine(_, left, right) tooltipLines[#tooltipLines + 1] = left .. "=" .. right end
function GameTooltip_AddNormalLine(_, text) tooltipLines[#tooltipLines + 1] = "# " .. text end
function GameTooltip_SetTitle() end
function GameTooltip_AddHighlightLine() end
function GameTooltip_AddErrorLine() end
function GameTooltip_AddInstructionLine() end
function GameTooltip_Hide() end

C_Item = {
    DoesItemExist = function() return true end,
    GetItemLink = function() return "item:25" end,
    GetItemInfoInstant = function() return 25, nil, nil, "INVTYPE_WEAPON", nil, 2, 7 end,
    GetItemInfo = function(link) return "Worn Sword", link, 2 end,
}
C_AuctionHouse = { MakeItemKey = function(itemID) return { itemID = itemID } end }
function FormatLargeNumber(n) return tostring(n) end
function IsModifiedClick() return false end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
local sounds = {}
function PlaySound(sound) sounds[#sounds + 1] = sound end
function InCombatLockdown() return false end

MenuUtil = { CreateRadioMenu = function(dropdown, isSelected, setSelected) dropdown.setSelected = setSelected end }
FrameUtil = { RegisterFrameForEvents = function() end }
local addonLoaded, loggedIn = {}, {}
EventUtil = {
    RegisterOnceFrameEventAndCallback = function() end,
    ContinueOnAddOnLoaded = function(name, fn) addonLoaded[name] = addonLoaded[name] or {} table.insert(addonLoaded[name], fn) end,
    ContinueOnPlayerLogin = function(fn) table.insert(loggedIn, fn) end,
}
SlashCmdList = {}
SETTINGS, SETTINGS_DEFAULTS = "Settings", "Defaults"

-- Blizzard hands every addon link click to each addon through one EventRegistry event
local itemRefHandlers = {}
EventRegistry = {
    RegisterCallback = function(_, event, fn, owner)
        if event == "SetItemRef" then itemRefHandlers[owner] = function(...) fn(owner, ...) end end
    end,
}
LinkTypes = { AddOn = "addon" }
-- Blizzard's own formatter (LinkUtil.lua)
LinkUtil = {
    FormatLink = function(linkType, text, ...)
        return table.concat({ ("|H%s"):format(linkType), ... }, ":") .. ("|h%s|h"):format(text)
    end,
}
local SECRET = {}
function issecretvalue(value) return value == SECRET end

-- The canvas the addon registers, and every category it asked to open
local canvas, opened = {}, {}
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        canvas.frame, canvas.name = frame, name
        return { GetID = function() return name end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) opened[#opened + 1] = id end,
}
MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
SettingsCheckboxMixin = { Event = { OnValueChanged = "OnValueChanged" } }
HelpTip = { width = 226, ButtonStyle = { Close = 2 }, Point = { TopEdgeCenter = 2 } }

-- ===== Auctionator =====
local fired = {}
local listeners = {}
local historyBuilds = 0
local historyDays = 3

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

local config, scansStarted = {}, { incremental = 0, replicate = 0 }

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
            local today = math.floor(os.time() / 86400)
            local rows = {}
            for day = 0, historyDays - 1 do rows[#rows + 1] = { rawDay = today - day, minSeen = 100 } end
            return rows
        end,
    },
    Config = { Get = function(key) return config[key] end, Options = { REPLICATE_SCAN = "replicate_scan_3" } },
    State = {
        IncrementalScanFrameRef = { InitiateScan = function() scansStarted.incremental = scansStarted.incremental + 1 end },
        FullScanFrameRef = { InitiateScan = function() scansStarted.replicate = scansStarted.replicate + 1 end },
    },
    AH = { Events = events("ItemSearchResultsReady", "CommoditySearchResultsReady") },
    Selling = { Events = events("SellSearchStart", "ClearBagItem", "PriceSelected") },
    Shopping = { Tab = { Events = events("SearchStart", "SearchEnd") } },
    IncrementalScan = { Events = events("ScanStart", "ScanProgress", "ScanComplete", "ScanFailed") },
    FullScan = { Events = { ScanStart = "replicate_scan_start", ScanProgress = "replicate_scan_progress", ScanComplete = "replicate_scan_complete", ScanFailed = "replicate_scan_failed" } },
}

-- ===== Load in toc order =====
local AP = {}
for line in io.lines("AuctionatorMarketValue.toc") do
    -- Other addons' files, like TSM's AppData.lua, are absent here, as in a game without them
    if line:match("%.lua$") and not line:match("^#") and not line:match("^%.%.") then
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

-- ===== Welcome line =====
-- Chat lines printed while fn runs
local printed = {}
local realPrint = print
local function capture(fn)
    printed = {}
    print = function(line) printed[#printed + 1] = line end
    fn()
    print = realPrint
    return printed
end
local function runAll(callbacks) return function() for _, fn in ipairs(callbacks or {}) do fn() end end end

-- First load on the account: no saved table yet
capture(runAll(addonLoaded.AuctionatorMarketValue))
check("the first load marks the first run and prints nothing", AP.firstRun == true and #printed == 0 and type(AuctionatorMarketValueDB) == "table", #printed)
capture(runAll(loggedIn))
local welcome = printed[1] or ""
check("login prints exactly one welcome line", #printed == 1, #printed)
check("the welcome line opens with the gold title", welcome:find("<gold>[Auctionator Market Value]</>: Shows how", 1, true) == 1, welcome)
check("the welcome line links the settings and names /amv", welcome:find("Open the <gold>|Haddon:AuctionatorMarketValue|h[Settings]|h</> or type /amv to", 1, true) ~= nil, welcome)

local onItemRef = itemRefHandlers[AP]
onItemRef("addon:AuctionatorMarketValue", "[Settings]", "LeftButton")
check("a click on the link opens the settings", #opened == 1 and opened[1] == "Auctionator Market Value", #opened)
onItemRef("addon:OtherAddon", "[Other]", "LeftButton")
onItemRef(SECRET, "[Settings]", "LeftButton")
check("another addon's link or a secret one opens nothing", #opened == 1, #opened)

-- A later login on the same account, in a fresh load of the addon's onboarding
do
    local later = {}
    addonLoaded.AuctionatorMarketValue = {}
    local loginCallbacks = #loggedIn
    for _, path in ipairs({ "Modules/Init.lua", "UI/Welcome.lua" }) do assert(loadfile(path))("AuctionatorMarketValue", later) end
    capture(runAll(addonLoaded.AuctionatorMarketValue))
    capture(function() for index = loginCallbacks + 1, #loggedIn do loggedIn[index]() end end)
    check("a later login prints nothing", later.firstRun == false and #printed == 0, #printed)
end

-- ===== Settings =====
-- The page is built at login, as its own canvas with Blizzard's settings slider and checkbox on each row
local sliders = templated.MinimalSliderWithSteppersTemplate or {}
local checkbox = (templated.SettingsCheckboxTemplate or {})[1]
local sliderFor, labels, headers = {}, {}, {}
for _, slider in ipairs(sliders) do sliderFor[slider.owner.label.text] = slider end
for _, slider in ipairs(sliders) do labels[#labels + 1] = slider.owner.label.text end
for _, text in ipairs(templated.GameFontHighlightLarge or {}) do headers[#headers + 1] = text.text end
local function at(frame, point)
    local anchor = frame.points and frame.points[point] or {}
    return anchor[1], anchor[2], anchor[3], anchor[4]
end

check("the page is its own canvas named after the toc Title", canvas.frame ~= nil and canvas.name == "Auctionator Market Value", canvas.name)
check("an intro opens the page", canvas.frame and canvas.frame.intro.text:find("^Compares every auction price") ~= nil)
check("six sliders and one checkbox", #sliders == 6 and checkbox ~= nil, #sliders)
check("settings names in Title Case", table.concat(labels, ", ") == "Sell Threshold, Deal Threshold, Level Range, Weapon DPS Range, Stat Value Range, Stat Count Range", table.concat(labels, ", "))
check("Show Similar Items on by default", checkbox.owner.label.text == "Show Similar Items" and checkbox.checked == true and AP.DB().showSimilar == true)
check("Blizzard's section headers head the groups", table.concat(headers, ", ") == "Bag Glow, Deals, Similar Items", table.concat(headers, ", "))
local header = templated.GameFontHighlightLarge[1]
local headerX, headerY = at(header, "TOPLEFT")
check("a header is a 45 px slot with its title at 7, -16", header.owner.height == 45 and headerX == 7 and headerY == -16)
check("the first header hangs under the intro", select(1, at(header.owner, "TOPLEFT")) == canvas.frame.intro)
local relativeTo, relativePoint, x, y = at(sliderFor["Sell Threshold"], "LEFT")
check("a slider starts at the row's CENTER -40, 3 up", relativeTo == sliderFor["Sell Threshold"].owner and relativePoint == "CENTER" and x == -40 and y == 3, tostring(x) .. " " .. tostring(y))
relativeTo, relativePoint, x = at(checkbox, "LEFT")
check("the checkbox shares the controls' left edge", relativeTo == checkbox.owner and relativePoint == "CENTER" and x == -40, x)
check("dependent rows are indented 15", at(sliderFor["Level Range"].owner.label, "LEFT") == 52 and at(sliderFor["Deal Threshold"].owner.label, "LEFT") == 37 and at(checkbox.owner.label, "LEFT") == 37)
check("sliders start at the defaults with a step count", sliderFor["Sell Threshold"].value == 15 and sliderFor["Weapon DPS Range"].steps == 10, sliderFor["Weapon DPS Range"].steps)
check("the label shows the value", sliderFor["Deal Threshold"].formatters[MinimalSliderWithSteppersMixin.Label.Right](20) == "-20%")
check("every row and control has a tooltip", sliderFor["Level Range"].owner.scripts.OnEnter ~= nil and sliderFor["Level Range"].Slider.scripts.OnEnter ~= nil and checkbox.tooltipFunc ~= nil)

local repaint, repaints = AP.BagGlow.Repaint, 0
AP.BagGlow.Repaint = function() repaints = repaints + 1 end
sliderFor["Sell Threshold"]:SetValue(30)
sliderFor["Level Range"]:SetValue(4)
check("a slider saves its value", AP.DB().sellThresholdPct == 30 and AP.DB().levelTolerance == 4)
check("only the threshold repaints the glow", repaints == 1, repaints)

checkbox:Click()
check("Show Similar Items saves its value", AP.DB().showSimilar == false)
check("range rows grey out while Show Similar Items is off", sliderFor["Level Range"].enabled == false and sliderFor["Level Range"].owner.label.color == "gray" and sliderFor["Sell Threshold"].enabled == nil)
check("the checkbox sounds like Blizzard's", sounds[#sounds] == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
checkbox.owner.scripts.OnMouseUp(checkbox.owner, "LeftButton")
check("a click on the label ticks the box", checkbox.checked == true and AP.DB().showSimilar == true and sounds[#sounds] == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON and sliderFor["Level Range"].enabled == true)
checkbox:Click()

local defaults
for _, button in ipairs(templated.UIPanelButtonTemplate or {}) do
    if button.text == "Defaults" then defaults = button end
end
repaints = 0
defaults:Click()
check("Defaults restores every setting", AP.DB().sellThresholdPct == 15 and AP.DB().levelTolerance == 2 and AP.DB().showSimilar == true and sliderFor["Sell Threshold"].value == 15 and checkbox.checked == true)
check("Defaults enables the range rows and repaints the glow", sliderFor["Level Range"].enabled == true and sliderFor["Level Range"].owner.label.color == "gold" and repaints > 0)
AP.BagGlow.Repaint = repaint

-- ===== Chat =====
-- Every line goes through the one helper: the bracketed title in gold, the message uncoloured
InCombatLockdown = function() return true end
capture(AP.OpenSettings)
InCombatLockdown = function() return false end
check("an open in combat prints one gold-prefixed line", #printed == 1 and printed[1] == "<gold>[Auctionator Market Value]</>: Opens after combat.", printed[1])

-- ===== AH open =====
check("Similar ensure", AP.SimilarItems.Ensure())
check("Sale Scan ensure", AP.SaleScan.Ensure())
check("Full Scan ensure", AP.FullScanButton.Ensure())

-- ===== Tooltip rows =====
tooltipPostCall(GameTooltip)
check("tooltip shows the Auctionator block", tooltipLines[2] == "# Auctionator" and tooltipLines[3] == "14-day average (3 days)=100c" and tooltipLines[4] == "Last price vs average=<green>+20%</>", table.concat(tooltipLines, " | "))
historyDays = 1
runNextFrame()
tooltipLines = {}
tooltipPostCall(GameTooltip)
check("thin history greys the percentage", tooltipLines[3] == "14-day average (1 day)=100c" and tooltipLines[4] == "Last price vs average=<gray>+20%</>", table.concat(tooltipLines, " | "))
historyDays = 3

-- ===== TSM rows =====
check("no TSM block without TSM", #tooltipLines == 4, #tooltipLines)
TSM_API = {
    ToItemString = function() return "i:25" end,
    GetCustomPriceValue = function(source) return source == "DBMarket" and 80 or nil end,
}
tooltipLines = {}
runNextFrame()
tooltipPostCall(GameTooltip)
check("the TSM block follows the Auctionator block", tooltipLines[5] == "" and tooltipLines[6] == "# TSM" and tooltipLines[7] == "Market value=80c" and tooltipLines[8] == "Last price vs market value=<green>+50%</>", table.concat(tooltipLines, " | "))
-- Launch day on a fresh realm: TSM loaded with no scan yet, or not ready and throwing
for _, lookup in ipairs({ function() return nil end, function() error("not loaded") end }) do
    TSM_API.GetCustomPriceValue = lookup
    tooltipLines = {}
    runNextFrame()
    tooltipPostCall(GameTooltip)
    check("TSM without a figure keeps only the Auctionator block", #tooltipLines == 4, table.concat(tooltipLines, " | "))
end
TSM_API = nil

-- ===== TSM app data =====
-- With the TSM addon off, the same figure comes from the TSM app's AppData.lua, for this ruleset, faction and region only
local function block(fields, rows) return ("return {downloadTime=1,fields={%s},data={%s}}"):format(fields, rows) end
TSM_API = {}
AP.LoadData("AUCTIONDB_NON_COMMODITY_DATA", "PvP-Alliance", block('"itemString","marketValue"', "{25,1}"))
TSM_API = nil
check("app data is skipped while the TSM addon is loaded", AP.TSM.MarketValueFor("item:25") == nil)
AP.LoadData("APP_INFO", "Global", "return {}")
AP.LoadData("AUCTIONDB_NON_COMMODITY_DATA", "Normal-Alliance", block('"itemString","marketValue"', "{25,99}"))
AP.LoadData("AUCTIONDB_NON_COMMODITY_DATA", "PvP-Alliance", block('"itemString","minBuyout","marketValue"', '{25,1,2g},{"i:26::i100",1,1}'))
AP.LoadData("AUCTIONDB_COMMODITY_DATA", "Forever-HC-EU", block('"itemString","marketValue"', "{27,5}"))
AP.LoadData("AUCTIONDB_COMMODITY_DATA", "Forever-EU", block('"itemString","marketValue"', "{27,10000001}"))
check("app data reads this realm's market value", AP.TSM.MarketValueFor({ itemID = 25 }) == 80, AP.TSM.MarketValueFor({ itemID = 25 }))
check("app data unpacks values over 32 bits", AP.TSM.MarketValueFor("item:27") == 1 + 32 * 2 ^ 30, AP.TSM.MarketValueFor("item:27"))
check("app data has no figure for unknown items", AP.TSM.MarketValueFor("item:28") == nil)
tooltipLines = {}
runNextFrame()
tooltipPostCall(GameTooltip)
check("app data fills the TSM block without the TSM addon", tooltipLines[6] == "# TSM" and tooltipLines[7] == "Market value=80c" and tooltipLines[8] == "Last price vs market value=<green>+50%</>", table.concat(tooltipLines, " | "))

-- ===== Memoised average =====
runNextFrame()
historyBuilds = 0
for _ = 1, 5 do AP.Trend.AverageFor("item:25") end
check("one history build per key per frame", historyBuilds == 1, historyBuilds)
runNextFrame()
AP.Trend.AverageFor("item:25")
check("next frame rebuilds", historyBuilds == 2, historyBuilds)

-- The modules keep their widgets in locals, so the test reads them from the closures
local function upvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return v end
        i = i + 1
    end
end

-- ===== Full Scan button =====
local fullScan = upvalue(AP.FullScanButton.Ensure, "scanButton")
check("Full Scan sits bottom-left on the Export Results row", fullScan.text == "Full Scan" and fullScan.points.LEFT[1] == AuctionatorShoppingFrame.ShoppingResultsInset and fullScan.points.BOTTOM[1] == AuctionatorShoppingFrame.ExportCSV)
local tip = (templated.HelpTipTemplate or {})[1]
check("a help tip points at Full Scan", tip and tip.owner == fullScan and tip.shown and tip.info.text == "Click Full Scan to load today's prices for every percentage and average." and tip.info.targetPoint == HelpTip.Point.TopEdgeCenter and tip.info.buttonStyle == HelpTip.ButtonStyle.Close)
fullScan:Hide()
check("the tip hides with its target without being marked", AP.DB().tipSeen == nil)
fullScan:Show()
fullScan:Click()
check("click starts Auctionator's incremental scan by default", scansStarted.incremental == 1 and scansStarted.replicate == 0)
check("using Full Scan closes the tip for good", AP.DB().tipSeen == true and not tip.shown)
fullScan:Hide()
fullScan:Show()
check("the tip stays away once seen", not tip.shown and #templated.HelpTipTemplate == 1)
config.replicate_scan_3 = true
fullScan:Click()
check("Alternate Scan Mode starts the replicate scan", scansStarted.replicate == 1)
config.replicate_scan_3 = nil
AuctionatorShoppingFrame.searchRunning = true
fullScan:Click()
check("no incremental scan during a shopping search", scansStarted.incremental == 1)
AuctionatorShoppingFrame.searchRunning = nil
Auctionator.EventBus:Fire(nil, "ScanStart")
Auctionator.EventBus:Fire(nil, "ScanProgress", 0.42)
check("label shows the scan progress", fullScan.text == "Full Scan 42%", fullScan.text)
Auctionator.EventBus:Fire(nil, "replicate_scan_complete")
check("a finished scan shows green 100%", fullScan.text == "<green>Full Scan 100%</>", fullScan.text)

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

-- ===== Bag glow =====
-- An item whose last price sits the sell threshold above its average takes the bags' green glow on its icon
local bagButton = CreateFrame("Button")
bagButton.Icon = CreateFrame("Texture", nil, bagButton)
bagButton.CreateTexture = function(self) self.texture = CreateFrame("Texture", nil, self) return self.texture end
AuctionatorGroupsViewItemMixin.SetItemInfo(bagButton, { itemLink = "item:25" })
local bagGlow = bagButton.texture
check("a favourable bag item glows green", bagGlow and bagGlow.shown and bagGlow.atlas == "bags-glow-green")
check("the glow is kept off Auctionator's button", rawget(bagButton, "addonGlow") == nil)
AuctionatorGroupsViewItemMixin.SetItemInfo(bagButton, {})
check("an emptied bag slot drops the glow", bagGlow and not bagGlow.shown)

-- ===== Parser =====
local stats = AP.ItemStats.FullStatSet("equip: decreases the magical resistances of your spell targets by 10.")
check("vanilla spell piercing parses", stats.spellpenetration == 10, stats.spellpenetration)

-- ===== Blizzard's auction lists =====
-- A list stand-in: rows with Blizzard's rowData and three cells, each with money and a right edge, that record
-- the font string and texture made on them
local function recordFontString(self)
    self.fontString = CreateFrame("FontString", nil, self)
    return self.fontString
end
local function cellAt(r, right)
    local cell = CreateFrame("Frame", nil, r)
    cell.MoneyDisplay = CreateFrame("Frame", nil, cell)
    cell.GetRight = function() return right end
    return cell
end
local function row(rowData)
    local r = CreateFrame("Button")
    r.rowData = rowData
    r.CreateFontString = recordFontString
    r.CreateTexture = function(self) self.texture = CreateFrame("Texture", nil, self) return self.texture end
    r.cells = { cellAt(r, 150), cellAt(r, 300), cellAt(r, 400) }
    return r
end
local function list(rows)
    local frame = CreateFrame("Frame")
    frame.ScrollBox = { ForEachFrame = function(_, fn) for _, r in ipairs(rows) do fn(r) end end }
    frame.HeaderContainer = CreateFrame("Frame", nil, frame)
    frame.HeaderContainer.GetLeft = function() return 100 end
    frame.HeaderContainer.CreateFontString = recordFontString
    return frame
end

local cheap, dear, thin = row({ itemKey = { itemID = 25 }, buyoutAmount = 70 }), row({ itemKey = { itemID = 25 }, buyoutAmount = 130 }), row({ itemKey = { itemID = 25 } })
local commodity, posted = row({ itemID = 25, unitPrice = 70 }), row({ itemID = 25, unitPrice = 130 })

-- Real frames answer nil for a missing key, the stand-ins a function, so the lists and windows not under test are false
AuctionHouseFrame = CreateFrame("Frame")
AuctionHouseFrame.BrowseResultsFrame, AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.AuctionsFrame = false, false, false
AuctionHouseFrame.CommoditiesBuyFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.CommoditiesBuyFrame.ItemList = list({ commodity })
AuctionHouseFrame.CommoditiesSellList = list({ posted })
AuctionHouseFrame.ItemBuyFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.ItemBuyFrame.ItemList = list({ cheap, dear, thin })
AuctionHouseFrame.ItemSellList = list({})
AuctionHouseFrame.ItemSellList.shown = false
AuctionatorSellingFrame.SaleItemFrame.shown = false

local sellPrice, sellLabel = 110, nil
local sellFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
sellFrame.PriceInput = { GetAmount = function() return sellPrice end, MoneyInputFrame = CreateFrame("Frame") }
sellFrame.GetItem = function() return {} end
sellFrame.CreateFontString = function(self) sellLabel = CreateFrame("FontString", nil, self) return sellLabel end
AuctionHouseFrame.ItemSellFrame = sellFrame

local painters = {}
local createFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent, template)
    if parent == AuctionHouseFrame and kind == "Frame" and not name then painters[#painters + 1] = frame end
    return frame
end
for _, fn in ipairs(addonLoaded.Blizzard_AuctionHouseUI or {}) do fn() end
CreateFrame = createFrame
runNextFrame()
local function update() for _, painter in ipairs(painters) do painter.scripts.OnUpdate(painter) end end
update()

local function anchor(fontString, point)
    local at = fontString and fontString.points and fontString.points[point]
    return at and at[1], at and at[2], at and at[3]
end

check("two painters wait on Blizzard's auction house", #painters == 2, #painters)
check("buy rows show the buyer's percentage", cheap.fontString and cheap.fontString.text == "<green>-30%</>", cheap.fontString and cheap.fontString.text)
check("dear rows show red", dear.fontString.text == "<red>+30%</>", dear.fontString.text)
check("a row without a buyout shows nothing", thin.fontString.text == "")
local to, toPoint, x = anchor(cheap.fontString, "RIGHT")
check("the item buy column ends the quantity column", to == cheap.cells[3] and toPoint == "RIGHT" and x == -4, tostring(toPoint) .. " " .. tostring(x))
check("no cell carries a percentage", cheap.cells[2].fontString == nil and cheap.cells[3].fontString == nil)
local header = AuctionHouseFrame.ItemBuyFrame.ItemList.HeaderContainer.fontString
to, toPoint, x = anchor(header, "RIGHT")
check("the item buy header sits over the column", header and header.text == "Relative" and to == AuctionHouseFrame.ItemBuyFrame.ItemList.HeaderContainer and toPoint == "LEFT" and x == 296, tostring(x))
check("a deal glows", cheap.texture ~= nil and cheap.texture.shown)
check("a dear row never glows", dear.texture == nil)
check("nothing is written to Blizzard's rows", rawget(cheap, "apRowData") == nil and rawget(cheap, "apDeal") == nil and rawget(cheap.cells[2], "apRelative") == nil)

to, toPoint, x = anchor(commodity.fontString, "LEFT")
check("the commodity column follows the price and its checkmark", commodity.fontString.text == "<green>-30%</>" and to == commodity.cells[1].MoneyDisplay and toPoint == "RIGHT" and x == 28, tostring(x))
to, toPoint, x = anchor(posted.fontString, "RIGHT")
check("sell lists show the seller's percentage before the seller column", posted.fontString.text == "<green>+30%</>" and to == posted.cells[3] and toPoint == "LEFT" and x == -16, posted.fontString.text)
check("sell lists never glow", posted.texture == nil)

-- Blizzard hands cells to other rows when it lays a list out again
cheap.cells, dear.cells = dear.cells, cheap.cells
update()
check("the column follows the row's new cells", anchor(cheap.fontString, "RIGHT") == cheap.cells[3] and cheap.fontString.text == "<green>-30%</>")

check("posting shows the seller's percentage", sellLabel and sellLabel.text == "<green>+10%</> <white>vs average</>", sellLabel and sellLabel.text)
sellPrice = 80
runNextFrame()
update()
check("posting follows the typed price", sellLabel.text == "<red>-20%</> <white>vs average</>", sellLabel.text)

-- ===== Tooltip colours follow the open view =====
check("posting views use the seller's colours", AP.Trend.Mode() == AP.Trend.UP_GREEN)
sellFrame.shown, AuctionatorSellingFrame.shown = false, false
check("buying views use the buyer's colours", AP.Trend.Mode() == AP.Trend.UP_RED)
local bidsTab = false
AuctionHouseFrame.AuctionsFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.AuctionsFrame.IsDisplayingBids = function() return bidsTab end
check("the player's own auctions use the seller's colours", AP.Trend.Mode() == AP.Trend.UP_GREEN)
bidsTab = true
check("the player's bids use the buyer's colours", AP.Trend.Mode() == AP.Trend.UP_RED)
AuctionHouseFrame.AuctionsFrame.shown = false
AuctionatorCancellingFrame = CreateFrame("Frame")
check("Auctionator's Cancelling tab uses the seller's colours", AP.Trend.Mode() == AP.Trend.UP_GREEN)
AuctionHouseFrame.shown = false
check("outside the Auction House the seller's colours apply", AP.Trend.Mode() == AP.Trend.UP_GREEN)

-- ===== Slash commands =====
local slash = SlashCmdList.AUCTIONATORMARKETVALUE
local openedBefore = #opened
capture(function() slash("") end)
check("bare /amv opens the settings and prints nothing", #opened == openedBefore + 1 and #printed == 0)
local helpLine = "<gold>[Auctionator Market Value]</>: Type /amv for the settings, /amv intro to see the welcome line and the tip again, or /amv help for this list."
capture(function() slash(" HELP ") end)
check("/amv help prints one line naming every command", #printed == 1 and printed[1] == helpLine, printed[1])
capture(function() slash("?") end)
check("/amv ? prints the same line", #printed == 1 and printed[1] == helpLine, printed[1])
openedBefore = #opened
capture(function() slash("frobnicate") end)
check("an unknown word prints the hint and opens nothing", #printed == 1 and printed[1] == "<gold>[Auctionator Market Value]</>: Unknown command. Type /amv help for the list." and #opened == openedBefore, printed[1])
capture(function() slash("intro") end)
check("/amv intro prints the welcome line again", #printed == 1 and printed[1] == welcome, printed[1])
check("/amv intro clears the tip flag", AP.DB().tipSeen == nil)
fullScan:Hide()
fullScan:Show()
check("the tip shows again at its next chance", tip.shown and tip.info ~= nil)

print(failures == 0 and "All checks passed." or (failures .. " checks failed."))
os.exit(failures == 0 and 0 or 1)
