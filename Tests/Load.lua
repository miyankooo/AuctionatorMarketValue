-- Offline smoke test: loads every file in toc order against stubs of the WoW API, Auctionator and the TSM app's data,
-- logs in and opens the Auction House once, and checks the welcome line, the settings page, the tooltip rows, the
-- Full Scan button and its help tip, Sale Scan, the relative columns in Auctionator's and Blizzard's auction lists,
-- the TSM app data reader, the market value with and without TSM, and the slash commands.
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
function frameMethods:LockHighlight() self.highlightLocked = true end
function frameMethods:UnlockHighlight() self.highlightLocked = false end
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
    -- HelpTipTemplate as HelpTip.lua runs it: it starts hidden, Init leaves `acknowledged` as it was and only Reset
    -- clears it, the close button acknowledges, and hiding with its parent closes it, which runs the acknowledge
    -- callback only when the tip was acknowledged
    if template == "HelpTipTemplate" then
        frame.shown, frame.acknowledged, frame.inits = false, false, 0
        frame.Init = function(self, _, info, relativeRegion)
            self.info, self.relativeRegion, self.inits = info, relativeRegion, self.inits + 1
        end
        frame.Reset = function(self) self.info, self.acknowledged = nil, false end
        frame.Close = function(self)
            local info = self.info
            if info then
                self.info = nil
                if self.acknowledged then info.onAcknowledgeCallback() end
            end
            self.shown = false
        end
        frame.Acknowledge = function(self)
            self.acknowledged = true
            self:Close()
        end
        frame.CloseButton = CreateFrame("Button", nil, frame)
        frame.CloseButton:SetScript("OnClick", function() frame:Acknowledge() end)
        parent:HookScript("OnHide", function() if frame.shown then frame:Close() end end)
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
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Title" and "Simple Market Value" or nil end }
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

-- Both forms: (table, "method", hook) and ("globalFunction", hook)
function hooksecurefunc(target, method, hook)
    if type(target) == "string" then target, method, hook = _G, target, method end
    local original = target[method]
    target[method] = function(...) local a, b, c = original(...) hook(...) return a, b, c end
end

local function color(name)
    -- GetRGB answers the name, so a test reads which colour a text took
    return { WrapTextInColorCode = function(_, text) return "<" .. name .. ">" .. text .. "</>" end, GetRGB = function() return name end }
end
HIGHLIGHT_FONT_COLOR, GREEN_FONT_COLOR, RED_FONT_COLOR = color("white"), color("green"), color("red")
GRAY_FONT_COLOR, YELLOW_FONT_COLOR, NORMAL_FONT_COLOR, WARNING_FONT_COLOR = color("gray"), color("yellow"), color("gold"), color("warn")
ORANGE_FONT_COLOR = color("orange")
ITEM_QUALITY_COLORS = { [2] = { color = color("uncommon") } }


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
-- An indented row reads "> label=value", a sub-heading's grey age "label=<gray>age</>"
function GameTooltip_AddColoredDoubleLine(_, left, right, _, rightColor, _, leftOffset)
    if rightColor ~= HIGHLIGHT_FONT_COLOR then right = rightColor:WrapTextInColorCode(right) end
    tooltipLines[#tooltipLines + 1] = (leftOffset and "> " or "") .. left .. "=" .. right
end
function GameTooltip_AddNormalLine(_, text) tooltipLines[#tooltipLines + 1] = "# " .. text end
function GameTooltip_SetTitle() end
function GameTooltip_AddHighlightLine(_, text) tooltipLines[#tooltipLines + 1] = text end
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
function GetMoneyString(amount) return amount .. "c" end
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
local historyAge = 0
-- Daily minimums newest first, 100 each when unset
local historyPrices

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
-- Auctionator's commodity buy list: its price, quantity and hidden sellers columns
local commodityLayout = {
    { headerText = "Buyout Price", cellTemplate = "AuctionatorPriceCellTemplate", width = 145 },
    { headerText = "Available", cellTemplate = "AuctionatorStringCellTemplate" },
    { headerText = "Sellers", cellTemplate = "AuctionatorTooltipStringCellTemplate", defaultHide = true },
}
AuctionatorBuyCommodityDataProviderMixin = provider()
AuctionatorBuyCommodityDataProviderMixin.GetTableLayout = function() return commodityLayout end
AuctionatorGroupsViewItemMixin = { SetItemInfo = function() end }

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
    DatabaseMixin = { SetPrice = function() end },
    Database = {
        SetPrice = function() end,
        GetFirstPrice = function() return 120 end,
        GetPriceAge = function() return historyDays > 0 and historyAge or nil end,
        GetPriceHistory = function()
            historyBuilds = historyBuilds + 1
            local today = math.floor(os.time() / 86400)
            local rows = {}
            for day = 0, historyDays - 1 do rows[#rows + 1] = { rawDay = today - historyAge - day, minSeen = historyPrices and historyPrices[day + 1] or 100 } end
            return rows
        end,
    },
    Config = { Get = function(key) return config[key] end, Options = { REPLICATE_SCAN = "replicate_scan_3" } },
    State = {
        CurrentRealm = "Forever",
        IncrementalScanFrameRef = { InitiateScan = function() scansStarted.incremental = scansStarted.incremental + 1 end },
        FullScanFrameRef = { InitiateScan = function() scansStarted.replicate = scansStarted.replicate + 1 end },
    },
    AH = { Events = events("ItemSearchResultsReady", "CommoditySearchResultsReady") },
    Selling = { Events = events("SellSearchStart", "ClearBagItem", "PriceSelected") },
    Shopping = { Tab = { Events = events("SearchStart", "SearchEnd") } },
    IncrementalScan = { Events = events("ScanStart", "ScanProgress", "ScanComplete", "ScanFailed") },
    FullScan = { Events = { ScanStart = "replicate_scan_start", ScanProgress = "replicate_scan_progress", ScanComplete = "replicate_scan_complete", ScanFailed = "replicate_scan_failed" } },
}

-- ===== TSM desktop app data =====
-- The app's AppData.lua as the app writes it: one LoadData call per block, every value packed in base 32. Item 25
-- carries the region sale average 140 copper, a sale rate of 0.779 and 34.89 sold a day (both in thousandths), and the
-- auction house's market value 130 and long-run price 125. Another region's and another faction's blocks, an empty
-- commodity block and a block of unread fields ride along and must be ignored
function GetCurrentRegionName() return "EU" end
local tsmValues = { regionSale = 140, regionSalePercent = 779, regionSoldPerDay = 34890, marketValue = 130, historical = 125 }
local DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
local function base32(n)
    local text = ""
    repeat
        local digit = math.floor(n % 32)
        text = DIGITS:sub(digit + 1, digit + 1) .. text
        n = math.floor(n / 32)
    until n == 0
    return text
end
-- Values of 2^30 and more are written as two halves, the lower one padded to 6 digits
local function packed(n)
    if n < 2 ^ 30 then return base32(n) end
    local low = base32(n % 2 ^ 30)
    return base32(math.floor(n / 2 ^ 30)) .. ("0"):rep(6 - #low) .. low
end
local BIG = 2 ^ 30 + 5
local function appData(values)
    local function block(tag, key, fields, rows)
        return ('select(2, ...).LoadData("%s","%s",[[return {downloadTime=1794182799,fields={"itemString","%s"},data={%s}}]])')
            :format(tag, key, table.concat(fields, '","'), rows)
    end
    local function row(fields)
        local cells = {}
        for index, field in ipairs(fields) do cells[index] = packed(values[field] or 0) end
        return "{25," .. table.concat(cells, ",") .. "}"
    end
    local SALE = { "regionSale", "regionSoldPerDay", "regionSalePercent" }
    return table.concat({
        block("AUCTIONDB_COMMODITY_HISTORICAL", "Forever-EU", { "historical" }, ""),
        block("AUCTIONDB_REGION_SALE", "Forever-US", SALE, "{25,1,1,1}"),
        block("AUCTIONDB_REGION_SALE", "Forever-EU", SALE, "{24,5,5,5}," .. row(SALE) .. ',{"i:259891::i1",' .. packed(BIG) .. ",0,0}"),
        ('select(2, ...).LoadData("APP_INFO","Global",[[return {version="1.0.9",lastSync=%d,message={id=0,msg=""},news={}}]])')
            :format(os.time() - 15 * 60),
        block("AUCTIONDB_NON_COMMODITY_HISTORICAL", "PvP-Horde", { "historical" }, "{25,1}"),
        block("AUCTIONDB_NON_COMMODITY_HISTORICAL", "PvP-Alliance", { "historical" }, row({ "historical" })),
        block("AUCTIONDB_NON_COMMODITY_SCAN_STAT", "PvP-Alliance", { "marketValue" }, row({ "marketValue" })),
        block("AUCTIONDB_NON_COMMODITY_DATA", "PvP-Alliance", { "minBuyout", "numAuctions", "marketValueRecent" }, "{25,1,1,1}"),
    }, "\n")
end

-- ===== Load in toc order =====
local function loadAddon(ns)
    for line in io.lines("SimpleMarketValue.toc") do
        if line == "..\\TradeSkillMaster_AppHelper\\AppData.lua" then
            -- The app's file in the AppHelper folder, run with this addon's name and table as the client does
            assert(load(appData(tsmValues)))("SimpleMarketValue", ns)
        elseif line:match("%.lua$") and not line:match("^#") then
            local path = line:gsub("\\", "/")
            assert(loadfile(path))("SimpleMarketValue", ns)
        end
    end
end
local AP = {}
loadAddon(AP)
check("files load in toc order", true)

-- Reloads the TSM module over the app's data as it would read after a /reload; nil means the app never synced
local function setAppData(values)
    assert(loadfile("Modules/TSM.lua"))("SimpleMarketValue", AP)
    if values then assert(load(appData(values)))("SimpleMarketValue", AP) end
end

-- ===== TSM app data =====
check("the app's last sync is read from its info block", AP.TSM.SyncTime() == os.time() - 15 * 60, AP.TSM.SyncTime())
check("this region's sale block is read, rate and daily sales in thousandths",
    AP.TSM.SaleAverage("item:25") == 140 and AP.TSM.SaleRate("item:25") == 0.779 and AP.TSM.DailySold("item:25") == 34.89,
    tostring(AP.TSM.SaleAverage("item:25")) .. " " .. tostring(AP.TSM.SaleRate("item:25")))
check("this ruleset and faction's house blocks are read, not another faction's",
    AP.TSM.HouseAverage("item:25") == 130 and AP.TSM.HouseHistorical("item:25") == 125, AP.TSM.HouseHistorical("item:25"))
check("an auction item key finds the same row", AP.TSM.SaleAverage({ itemID = 25 }) == 140)
check("a variant's row answers for its base item, a value of 2^30 or more joined from its halves",
    AP.TSM.SaleAverage("item:259891:0:0") == BIG, AP.TSM.SaleAverage("item:259891:0:0"))
check("a zero is no figure", AP.TSM.DailySold("item:259891") == nil)
check("an item without a row has no figure", AP.TSM.SaleAverage("item:26") == nil)
local gameRules = C_GameRules.IsGameRuleActive
C_GameRules.IsGameRuleActive = function(rule) return rule == Enum.GameRule.HardcoreRuleset end
setAppData(tsmValues)
check("another ruleset reads none of these blocks", AP.TSM.SaleAverage("item:25") == nil and AP.TSM.HouseAverage("item:25") == nil)
C_GameRules.IsGameRuleActive = gameRules
setAppData(nil)
check("without the app's data every figure is nil", AP.TSM.SyncTime() == nil and AP.TSM.SaleAverage("item:25") == nil)
setAppData(tsmValues)

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
capture(runAll(addonLoaded.SimpleMarketValue))
check("the first load marks the first run and prints nothing", AP.firstRun == true and #printed == 0 and type(SimpleMarketValueDB) == "table", #printed)
capture(runAll(loggedIn))
local welcome = printed[1] or ""
check("login prints exactly one welcome line", #printed == 1, #printed)
check("the welcome line opens with the gold title", welcome:find("<gold>[Simple Market Value]</>: Shows how every auction price compares to its market value", 1, true) == 1, welcome)
check("the welcome line links the settings and names /smv", welcome:find("Open the <gold>|Haddon:SimpleMarketValue|h[Settings]|h</> or type /smv to", 1, true) ~= nil, welcome)

local onItemRef = itemRefHandlers[AP]
onItemRef("addon:SimpleMarketValue", "[Settings]", "LeftButton")
check("a click on the link opens the settings", #opened == 1 and opened[1] == "Simple Market Value", #opened)
onItemRef("addon:OtherAddon", "[Other]", "LeftButton")
onItemRef(SECRET, "[Settings]", "LeftButton")
check("another addon's link or a secret one opens nothing", #opened == 1, #opened)

-- A later login on the same account, in a fresh load of the addon's onboarding
do
    local later = {}
    addonLoaded.SimpleMarketValue = {}
    SimpleMarketValueDB.seenTimes = { Forever = { old = os.time() - 15 * 86400, recent = os.time() - 86400 } }
    local loginCallbacks = #loggedIn
    for _, path in ipairs({ "Modules/Init.lua", "Modules/Bridge.lua", "UI/Welcome.lua" }) do assert(loadfile(path))("SimpleMarketValue", later) end
    capture(runAll(addonLoaded.SimpleMarketValue))
    capture(function() for index = loginCallbacks + 1, #loggedIn do loggedIn[index]() end end)
    check("a later login prints nothing", later.firstRun == false and #printed == 0, #printed)
    local times = SimpleMarketValueDB.seenTimes.Forever
    check("price times past the 14-day window are dropped at load", times.old == nil and times.recent ~= nil)
end

-- ===== Settings =====
-- The page is built at login, as its own canvas with Blizzard's settings slider on each row
local sliders = templated.MinimalSliderWithSteppersTemplate or {}
local sliderFor, labels, headers = {}, {}, {}
for _, slider in ipairs(sliders) do sliderFor[slider.owner.label.text] = slider end
for _, slider in ipairs(sliders) do labels[#labels + 1] = slider.owner.label.text end
for _, text in ipairs(templated.GameFontHighlightLarge or {}) do headers[#headers + 1] = text.text end
local function at(frame, point)
    local anchor = frame.points and frame.points[point] or {}
    return anchor[1], anchor[2], anchor[3], anchor[4]
end

check("the page is its own canvas named after the toc Title", canvas.frame ~= nil and canvas.name == "Simple Market Value", canvas.name)
check("an intro opens the page", canvas.frame and canvas.frame.intro.text:find("^Shows every auction price as a percentage of its market value") ~= nil)
check("two sliders and no checkbox", #sliders == 2 and templated.SettingsCheckboxTemplate == nil, #sliders)
check("settings names in Title Case", table.concat(labels, ", ") == "Sell Threshold, Deal Threshold", table.concat(labels, ", "))
check("Blizzard's section headers head the groups", table.concat(headers, ", ") == "Selling, Buying", table.concat(headers, ", "))
local header = templated.GameFontHighlightLarge[1]
local headerX, headerY = at(header, "TOPLEFT")
check("a header is a 45 px slot with its title at 7, -16", header.owner.height == 45 and headerX == 7 and headerY == -16)
check("the first header hangs under the intro", select(1, at(header.owner, "TOPLEFT")) == canvas.frame.intro)
local relativeTo, relativePoint, x, y = at(sliderFor["Sell Threshold"], "LEFT")
check("a slider starts at the row's CENTER -40, 3 up", relativeTo == sliderFor["Sell Threshold"].owner and relativePoint == "CENTER" and x == -40 and y == 3, tostring(x) .. " " .. tostring(y))
check("labels start at 37", at(sliderFor["Deal Threshold"].owner.label, "LEFT") == 37)
check("sliders start at the defaults with a step count", sliderFor["Sell Threshold"].value == 15 and sliderFor["Deal Threshold"].steps == 95, sliderFor["Deal Threshold"].steps)
check("the label shows the value", sliderFor["Deal Threshold"].formatters[MinimalSliderWithSteppersMixin.Label.Right](20) == "-20%")
check("every row and slider has a tooltip", sliderFor["Deal Threshold"].owner.scripts.OnEnter ~= nil and sliderFor["Deal Threshold"].Slider.scripts.OnEnter ~= nil)

local repaint, repaints = AP.BagGlow.Repaint, 0
AP.BagGlow.Repaint = function() repaints = repaints + 1 end
sliderFor["Sell Threshold"]:SetValue(30)
sliderFor["Deal Threshold"]:SetValue(40)
check("a slider saves its value", AP.DB().sellThresholdPct == 30 and AP.DB().dealThresholdPct == 40)
check("only the sell threshold repaints the bag glow", repaints == 1, repaints)

local defaults
for _, button in ipairs(templated.UIPanelButtonTemplate or {}) do
    if button.text == "Defaults" then defaults = button end
end
repaints = 0
defaults:Click()
check("Defaults restores every setting", AP.DB().sellThresholdPct == 15 and AP.DB().dealThresholdPct == 20 and sliderFor["Sell Threshold"].value == 15 and sliderFor["Deal Threshold"].value == 20)
check("Defaults repaints the bag glow", repaints > 0)
AP.BagGlow.Repaint = repaint

-- ===== Chat =====
-- Every line goes through the one helper: the bracketed title in gold, the message uncoloured
InCombatLockdown = function() return true end
capture(AP.OpenSettings)
InCombatLockdown = function() return false end
check("an open in combat prints one gold-prefixed line", #printed == 1 and printed[1] == "<gold>[Simple Market Value]</>: Opens after combat.", printed[1])

-- ===== AH open =====
check("Sale Scan ensure", AP.SaleScan.Ensure())
check("Full Scan ensure", AP.FullScanButton.Ensure())

-- ===== Tooltip rows =====
-- Auctionator's last price 120 against its 14-day average 100, and against TSM's region sale average 140 at a sale
-- rate of 0.779 and 34.89 sold a day; outside the Auction House in the seller's colours
local function tooltipText()
    tooltipLines = {}
    runNextFrame()
    tooltipPostCall(GameTooltip)
    return table.concat(tooltipLines, " | ")
end
local AUCTIONATOR_ROWS = "> List Average=100c | > Market Value=<green>+20%</>"
local TSM_BLOCK = "TSM=<gray>15 minutes ago</> | > Sale Average=140c | > Sale Rate=<yellow>78%</> | > Daily Sold=35 | > Market Value=<yellow>-14%</>"
-- 120 sits one swing under 140 in a rising market, a dip to hold; 3 days of prices assume the wide 15% swing
local text = tooltipText()
check("the tooltip heads Market Value and its verdict over an Auctionator block, then a TSM block",
    text == " | Market Value=<red>Hold</> | Auctionator=<gray>today</> | " .. AUCTIONATOR_ROWS .. " | " .. TSM_BLOCK, text)
historyAge = 3
text = tooltipText()
check("Auctionator's age falls back to its whole scan days", text:find("Auctionator=<gray>3 days ago</>", 1, true) ~= nil, text)
historyAge = 0
Auctionator.Database:SetPrice("25", 100)
text = tooltipText()
check("a price the addon saw recorded shows its age to the minute", text:find("Auctionator=<gray>1 minute ago</>", 1, true) ~= nil, text)
for _, case in ipairs({ { 5 * 3600, "5 hours ago" }, { 3600, "1 hour ago" }, { 2 * 86400, "2 days ago" } }) do
    time = function() return os.time() - case[1] end
    Auctionator.Database:SetPrice("25", 100)
    time = os.time
    text = tooltipText()
    check("an age of " .. case[2] .. " picks its unit", text:find("Auctionator=<gray>" .. case[2] .. "</>", 1, true) ~= nil, text)
end
historyDays = 1
text = tooltipText()
check("thin history greys the Auctionator percentage", text:find("> Market Value=<gray>+20%</>", 1, true) ~= nil, text)
historyDays = 0
text = tooltipText()
check("without Auctionator history the TSM block stands alone", text == " | Market Value=<red>Hold</> | " .. TSM_BLOCK, text)
tsmValues.regionSale, tsmValues.regionSoldPerDay = nil, 400
setAppData(tsmValues)
text = tooltipText()
check("TSM shows whatever figures it has, daily sales rounded, and no market value means no verdict",
    text == " | # Market Value | TSM=<gray>15 minutes ago</> | > Sale Rate=<yellow>78%</> | > Daily Sold=0", text)
tsmValues.regionSale, tsmValues.regionSoldPerDay = 140, 34890
historyDays = 3
-- Launch day on a fresh realm: the TSM app has not synced yet
setAppData(nil)
text = tooltipText()
check("TSM without the app's data leaves the Auctionator block alone", text:find("TSM", 1, true) == nil and text:find("> List Average=100c", 1, true) ~= nil, text)
historyDays = 0
text = tooltipText()
check("no section without any figure", text == "", text)
setAppData(tsmValues)
historyDays = 3

-- TSM's sale rate in the colour of how easily the item sells
local rateColors = {}
for _, percent in ipairs({ 800, 794, 600, 594, 400, 394 }) do
    tsmValues.regionSalePercent = percent
    setAppData(tsmValues)
    rateColors[#rateColors + 1] = tooltipText():match("> Sale Rate=([^|]+) |")
end
tsmValues.regionSalePercent = 779
setAppData(tsmValues)
local rateScale = table.concat(rateColors, " ")
check("the sale rate is green from 80%, yellow from 60%, orange from 40%, red below",
    rateScale == "<green>80%</> <yellow>79%</> <yellow>60%</> <orange>59%</> <orange>40%</> <red>39%</>", rateScale)

-- ===== Market value =====
-- A price of 70: -50% against TSM's 140, -30% against Auctionator's 100
local function relative(price)
    runNextFrame()
    local _, pct, trusted = AP.Trend.Relative(price, "item:25")
    return pct, trusted
end
local pct, trusted = relative(70)
check("the market value is TSM's where TSM has one", pct == -50 and trusted, pct)
setAppData(nil)
pct, trusted = relative(70)
check("without TSM it is Auctionator's 14-day average", pct == -30 and trusted, pct)
historyDays = 2
pct, trusted = relative(70)
check("thin Auctionator history moves no glow", pct == -30 and not trusted, pct)
historyDays = 3
text = tooltipText()
check("without TSM the tooltip shows the Auctionator block alone", text:find("TSM", 1, true) == nil and text:find("> List Average=100c", 1, true) ~= nil, text)
setAppData(tsmValues)

-- ===== Colour scale =====
-- Green from the glow threshold on the good side (Deal Threshold 20 for a buyer, Sell Threshold 15 for a seller), red
-- as far on the bad side, yellow in between, grey on thin history
local function scale(pct, mode, days) return AP.Trend.Colorize(pct, mode, days) end
local buyer, seller = AP.Trend.UP_RED, AP.Trend.UP_GREEN
local buyerScale = table.concat({ scale(-20, buyer), scale(-19, buyer), scale(0, buyer), scale(19, buyer), scale(20, buyer) }, " ")
check("a buyer's scale: green from the Deal Threshold under, red as far over, yellow between",
    buyerScale == "<green>-20%</> <yellow>-19%</> <yellow>0%</> <yellow>+19%</> <red>+20%</>", buyerScale)
local sellerScale = table.concat({ scale(15, seller), scale(14, seller), scale(-14, seller), scale(-15, seller) }, " ")
check("a seller's scale: green from the Sell Threshold over, red as far under, yellow between",
    sellerScale == "<green>+15%</> <yellow>+14%</> <yellow>-14%</> <red>-15%</>", sellerScale)
check("thin history stays grey", scale(-50, buyer, 2) == "<gray>-50%</>", scale(-50, buyer, 2))
AP.DB().dealThresholdPct = 5
check("the scale follows the threshold setting", scale(-7, buyer) == "<green>-7%</>" and scale(7, buyer) == "<red>+7%</>", scale(-7, buyer))
AP.DB().dealThresholdPct = 20

-- ===== Timing verdict =====
-- Eight days of steady prices (a swing at its 5% floor) against TSM's sale average 140, on an auction house trending
-- up 4% (130 against 125) where 78% of auctions sell
local function verdict(price, mode)
    runNextFrame()
    local label, color = AP.Timing.Verdict(price, "item:25", mode)
    return label and color:WrapTextInColorCode(label)
end
local BUY, SELL = AP.Trend.UP_RED, AP.Trend.UP_GREEN
historyDays = 8
check("two swings under in a rising market is a strong buy", verdict(125, BUY) == "<green>Strong Buy</>", verdict(125, BUY))
check("one swing under is a buy", verdict(132, BUY) == "<green>Buy</>", verdict(132, BUY))
check("within a swing is fair", verdict(135, BUY) == "<yellow>Fair</>", verdict(135, BUY))
check("one swing over is overpriced", verdict(150, BUY) == "<red>Overpriced</>", verdict(150, BUY))
check("one swing over sells now", verdict(150, SELL) == "<green>Sell Now</>", verdict(150, SELL))
check("a fair price on an item that mostly sells sells now", verdict(138, SELL) == "<green>Sell Now</>", verdict(138, SELL))
check("a dip in a rising market is a hold", verdict(125, SELL) == "<red>Hold</>", verdict(125, SELL))
tsmValues.marketValue = 110
setAppData(tsmValues)
check("in a falling market a deep cut is only a buy", verdict(125, BUY) == "<green>Buy</>", verdict(125, BUY))
check("and a dip no reason to hold", verdict(125, SELL) == "<yellow>Fair</>", verdict(125, SELL))
tsmValues.marketValue, tsmValues.regionSalePercent = 130, 200
setAppData(tsmValues)
check("an item that rarely sells is no strong buy", verdict(125, BUY) == "<green>Buy</>", verdict(125, BUY))
check("nor a quick sale at a fair price", verdict(138, SELL) == "<yellow>Fair</>", verdict(138, SELL))
tsmValues.regionSalePercent = 779
setAppData(tsmValues)
historyPrices = { 70, 130, 70, 130, 70, 130, 70, 130 }
check("on a jumpy item the same cut is noise", verdict(125, BUY) == "<yellow>Fair</>", verdict(125, BUY))
historyPrices = nil
historyDays = 3
check("thin history assumes a wide swing, so the same cut is only fair, still in colour", verdict(125, BUY) == "<yellow>Fair</>", verdict(125, BUY))
historyDays = 8
local getItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function() return "Worn Sword", "item:25", 2, 1, 1, "Weapon", "Sword", 1, "INVTYPE_WEAPON", 0, 200 end
check("below the vendor price is a strong buy, whatever the market", verdict(150, BUY) == "<green>Strong Buy</>", verdict(150, BUY))
C_Item.GetItemInfo = getItemInfo
setAppData(nil)
check("without TSM the verdict measures against Auctionator's average", verdict(80, BUY) == "<green>Strong Buy</>" and verdict(100, SELL) == "<yellow>Fair</>", verdict(80, BUY))
setAppData(tsmValues)
check("no verdict without a price", verdict(nil, BUY) == nil)
historyDays = 3

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

-- ===== Auctionator's Relative column =====
-- A row priced 70: -50% against TSM's 140, -30% against Auctionator's 100 where TSM has no figure
local entries = { { itemKey = { itemID = 25 }, minPrice = 70 } }
runNextFrame()
AuctionatorShoppingTabDataProviderMixin.PrettifyData(nil, entries)
check("Auctionator's column shows TSM's percentage", entries[1].apTrendText == "<green>-50%</>" and entries[1].apTrendValue == -50, entries[1].apTrendText)
tsmValues.regionSale = nil
setAppData(tsmValues)
entries = { { itemKey = { itemID = 25 }, minPrice = 70 } }
runNextFrame()
AuctionatorShoppingTabDataProviderMixin.PrettifyData(nil, entries)
check("an item without a TSM figure shows Auctionator's", entries[1].apTrendText == "<green>-30%</>" and entries[1].apTrendValue == -30, entries[1].apTrendText)
tsmValues.regionSale = 140
setAppData(tsmValues)
-- Auctionator alone, then the TSM app's data without a sale average for the item
local function shoppingColumn()
    entries = { { itemKey = { itemID = 25 }, minPrice = 70 } }
    runNextFrame()
    AuctionatorShoppingTabDataProviderMixin.PrettifyData(nil, entries)
    return entries[1].apTrendText, entries[1].apTrendValue
end
setAppData(nil)
local columnText, columnValue = shoppingColumn()
check("with Auctionator alone the column shows Auctionator's percentage", columnText == "<green>-30%</>" and columnValue == -30, columnText)
setAppData(tsmValues)
tsmValues.regionSale = nil
setAppData(tsmValues)
columnText, columnValue = shoppingColumn()
check("TSM without a sale average leaves the column on Auctionator's", columnText == "<green>-30%</>" and columnValue == -30, columnText)
tsmValues.regionSale = 140
setAppData(tsmValues)
columnText, columnValue = shoppingColumn()
check("with TSM set up the column is back on TSM's", columnText == "<green>-50%</>" and columnValue == -50, columnText)

-- Auctionator's commodity buy list: the column follows a narrower price column, and its rows, which carry only a unit
-- price, take the item from the frame holding the provider
local commodityProvider = setmetatable({
    GetParent = function() return { expectedItemID = 25 } end,
    SetDirty = function() end,
}, { __index = AuctionatorBuyCommodityDataProviderMixin })
local layout = commodityProvider:GetTableLayout()
check("the commodity buy column follows a narrower price column",
    #layout == 4 and layout[1].width == 120 and layout[1].headerText == "Buyout Price" and layout[2].headerText == "Relative"
        and layout[3].headerText == "Available" and layout[4].headerText == "Sellers",
    #layout .. " " .. tostring(layout[1].width) .. " " .. tostring(layout[2].headerText))
check("Auctionator's own commodity layout stays untouched", #commodityLayout == 3 and commodityLayout[1].width == 145)
local commodityRows = { { price = 70, rowIndex = 2 }, { price = 70, rowIndex = 1 }, { price = 130, rowIndex = 3 } }
commodityProvider:AppendEntries(commodityRows, true)
check("commodity buy rows show TSM's percentage in the buyer's colours",
    commodityRows[1].apTrendText == "<green>-50%</>" and commodityRows[3].apTrendText == "<yellow>-7%</>" and commodityRows[1].apTrendValue == -50,
    commodityRows[1].apTrendText)
commodityProvider.results = commodityRows
commodityProvider:Sort("apTrendValue", Auctionator.Constants.SORT.ASCENDING)
local sortedRows = commodityProvider.results
check("sorting by the column keeps equal rows in price order",
    sortedRows[1].rowIndex == 1 and sortedRows[2].rowIndex == 2 and sortedRows[3].rowIndex == 3,
    sortedRows[1].rowIndex .. sortedRows[2].rowIndex .. sortedRows[3].rowIndex)

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
-- The last price 120 sits 14% below TSM's 140 but 20% above Auctionator's 100, so only TSM's absence lights it
runNextFrame()
AuctionatorGroupsViewItemMixin.SetItemInfo(bagButton, { itemLink = "item:25" })
check("TSM's market value comes first for the bag glow", bagButton.texture == nil)
setAppData(nil)
runNextFrame()
AuctionatorGroupsViewItemMixin.SetItemInfo(bagButton, { itemLink = "item:25" })
setAppData(tsmValues)
local bagGlow = bagButton.texture
check("a favourable bag item glows green", bagGlow and bagGlow.shown and bagGlow.atlas == "bags-glow-green")
check("the glow is kept off Auctionator's button", rawget(bagButton, "addonGlow") == nil)
AuctionatorGroupsViewItemMixin.SetItemInfo(bagButton, {})
check("an emptied bag slot drops the glow", bagGlow and not bagGlow.shown)

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
local browsed = row({ itemKey = { itemID = 25 }, minPrice = 70 })

-- Real frames answer nil for a missing key, the stand-ins a function, so the lists and windows not under test are false
AuctionHouseFrame = CreateFrame("Frame")
AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.AuctionsFrame = false, false
AuctionHouseFrame.BrowseResultsFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.BrowseResultsFrame.ItemList = list({ browsed })
AuctionHouseFrame.CommoditiesBuyFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.CommoditiesBuyFrame.ItemList = list({ commodity })
AuctionHouseFrame.CommoditiesSellList = list({ posted })
AuctionHouseFrame.ItemBuyFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.ItemBuyFrame.ItemList = list({ cheap, dear, thin })
AuctionHouseFrame.ItemSellList = list({})
AuctionHouseFrame.ItemSellList.shown = false
AuctionatorSellingFrame.SaleItemFrame.shown = false

-- Blizzard's item sell window, open, so the views read as posting
local sellFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
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

check("one painter waits on Blizzard's auction house", #painters == 1, #painters)
check("buy rows show TSM's percentage in the buyer's colours", cheap.fontString and cheap.fontString.text == "<green>-50%</>", cheap.fontString and cheap.fontString.text)
check("a row nearer the market value shows its smaller cut", dear.fontString.text == "<yellow>-7%</>", dear.fontString.text)
check("a row without a buyout shows nothing", thin.fontString.text == "")
local to, toPoint, x = anchor(cheap.fontString, "RIGHT")
check("the item buy column ends the quantity column", to == cheap.cells[3] and toPoint == "RIGHT" and x == -4, tostring(toPoint) .. " " .. tostring(x))
check("no cell carries a percentage", cheap.cells[2].fontString == nil and cheap.cells[3].fontString == nil)
local header = AuctionHouseFrame.ItemBuyFrame.ItemList.HeaderContainer.fontString
to, toPoint, x = anchor(header, "RIGHT")
check("the item buy header sits over the column", header and header.text == "Relative" and to == AuctionHouseFrame.ItemBuyFrame.ItemList.HeaderContainer and toPoint == "LEFT" and x == 296, tostring(x))
check("a deal by TSM's percentage glows", cheap.texture ~= nil and cheap.texture.shown)
check("a row above the deal threshold by TSM never glows", dear.texture == nil)
check("nothing is written to Blizzard's rows", rawget(cheap, "apRowData") == nil and rawget(cheap, "apDeal") == nil and rawget(cheap.cells[2], "apRelative") == nil)

-- Auctionator alone: the same rows, handed fresh results, measure against Auctionator's 100
do
    local cheapData, dearData = cheap.rowData, dear.rowData
    setAppData(nil)
    cheap.rowData, dear.rowData = { itemKey = { itemID = 25 }, buyoutAmount = 70 }, { itemKey = { itemID = 25 }, buyoutAmount = 130 }
    runNextFrame()
    update()
    check("with Auctionator alone Blizzard's buy rows show Auctionator's percentage", cheap.fontString.text == "<green>-30%</>" and dear.fontString.text == "<red>+30%</>", cheap.fontString.text .. " " .. dear.fontString.text)
    check("and a deal by Auctionator's percentage glows", cheap.texture.shown)
    setAppData(tsmValues)
    cheap.rowData, dear.rowData = cheapData, dearData
    runNextFrame()
    update()
    check("with TSM back the rows return to TSM's percentage", cheap.fontString.text == "<green>-50%</>" and dear.fontString.text == "<yellow>-7%</>", cheap.fontString.text .. " " .. dear.fontString.text)
end

to, toPoint, x = anchor(commodity.fontString, "LEFT")
check("the commodity column follows the price and its checkmark", commodity.fontString.text == "<green>-50%</>" and to == commodity.cells[1].MoneyDisplay and toPoint == "RIGHT" and x == 28, tostring(x))
to, toPoint, x = anchor(posted.fontString, "RIGHT")
check("sell lists show the seller's colours before the seller column", posted.fontString.text == "<yellow>-7%</>" and to == posted.cells[3] and toPoint == "LEFT" and x == -16, posted.fontString.text)
check("sell lists never glow", posted.texture == nil)

to, toPoint, x = anchor(browsed.fontString, "RIGHT")
check("the browse column ends the name column, clear of the price", browsed.fontString.text == "<green>-50%</>" and to == browsed.cells[2] and toPoint == "RIGHT" and x == -4, tostring(x))
header = AuctionHouseFrame.BrowseResultsFrame.ItemList.HeaderContainer.fontString
to, toPoint, x = anchor(header, "RIGHT")
check("the browse header sits over the column", header and header.text == "Relative" and toPoint == "LEFT" and x == 196, tostring(x))

-- Blizzard hands cells to other rows when it lays a list out again
cheap.cells, dear.cells = dear.cells, cheap.cells
update()
check("the column follows the row's new cells", anchor(cheap.fontString, "RIGHT") == cheap.cells[3] and cheap.fontString.text == "<green>-50%</>")

-- ===== Highlight Great Deals =====
-- An Auctionator listing stand-in: rows on a ScrollBox under ScrollArea, as AuctionatorResultsListingTemplate has them
local function listing(rows)
    local frame = CreateFrame("Frame")
    frame.ScrollArea = { ScrollBox = { ForEachFrame = function(_, fn) for _, r in ipairs(rows) do fn(r) end end } }
    return frame
end
local shoppingRows = { row({ apGreatDeal = true }), row({}) }
AuctionatorShoppingFrame.ResultsListing = listing(shoppingRows)
local listingPainters = {}
CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent, template)
    if parent == AuctionatorShoppingFrame.ResultsListing then listingPainters[#listingPainters + 1] = frame end
    return frame
end
local ready = AP.GreatDeals.Ensure()
CreateFrame = createFrame
local function paintShopping() for _, p in ipairs(listingPainters) do p.scripts.OnUpdate(p) end end

local greatButton = upvalue(AP.GreatDeals.Ensure, "button")
local left = greatButton and greatButton.points.LEFT
check("Highlight Great Deals sits right of Full Scan", greatButton and greatButton.text == "Highlight Great Deals"
    and left[1] == fullScan and left[2] == "RIGHT" and left[3] == 8)
check("it waits for Auctionator's buy screens, with a painter on the shopping results", not ready and #listingPainters == 1)
check("it starts off and enabled with TSM's sale rates", not AP.GreatDeals.IsOn() and greatButton:IsEnabled() and not greatButton.highlightLocked)
local instruction, errorLine
local addInstruction, addError = GameTooltip_AddInstructionLine, GameTooltip_AddErrorLine
GameTooltip_AddInstructionLine = function(_, text) instruction = text end
GameTooltip_AddErrorLine = function(_, text) errorLine = text end
greatButton.scripts.OnEnter(greatButton)
check("its tooltip says what a click does", instruction == "Click to turn it on." and errorLine == nil, instruction)
paintShopping()
check("off, Auctionator's rows never glow", shoppingRows[1].texture == nil)

greatButton:Click()
check("a click turns it on, saved, with the button held lit", AP.DB().greatDeals == true and AP.GreatDeals.IsOn() and greatButton.highlightLocked)
greatButton.scripts.OnEnter(greatButton)
check("then the tooltip offers to turn it off", instruction == "Click to turn it off.", instruction)
update()
check("on, a cheap item TSM sees sell 78% of the time stops glowing in Blizzard's lists", not cheap.texture.shown)

-- The same price on an item that sells 80% of the time
tsmValues.regionSalePercent = 800
setAppData(tsmValues)
cheap.rowData = { itemKey = { itemID = 25 }, buyoutAmount = 70 }
update()
check("half price and an 80% sale rate glows in Blizzard's lists", cheap.texture.shown and dear.texture == nil)
local shopped = { { itemKey = { itemID = 25 }, minPrice = 70 }, { itemKey = { itemID = 25 }, minPrice = 100 } }
runNextFrame()
AuctionatorShoppingTabDataProviderMixin.PrettifyData(nil, shopped)
check("Auctionator's shopping rows mark only great deals", shopped[1].apGreatDeal == true and not shopped[2].apGreatDeal)
local sold = { { itemKey = { itemID = 25 }, price = 70 } }
AuctionatorSearchDataProviderMixin.AppendEntries(nil, sold)
check("a seller's list marks none", sold[1].apGreatDeal == nil)
paintShopping()
check("on, a great deal glows in Auctionator's results with Blizzard's row highlight",
    shoppingRows[1].texture and shoppingRows[1].texture.shown and shoppingRows[1].texture.atlas == "auctionhouse-ui-row-highlight" and shoppingRows[2].texture == nil)

AuctionatorBuyItemFrame = CreateFrame("Frame")
AuctionatorBuyItemFrame.ResultsListing = listing({})
AuctionatorBuyCommodityFrame = CreateFrame("Frame")
AuctionatorBuyCommodityFrame.ResultsListing = listing({})
check("ready once Auctionator's buy screens exist", AP.GreatDeals.Ensure() == true)

setAppData(nil)
check("without TSM's sale rates it reads off", not AP.GreatDeals.IsOn())
greatButton.scripts.OnEnter(greatButton)
check("and the tooltip says what it needs", errorLine == "Needs the sale rates of the TSM desktop app.", errorLine)
update()
check("Blizzard's lists then glow by the Deal Threshold", cheap.texture.shown)
setAppData(tsmValues)

greatButton:Click()
check("a second click turns it off", AP.DB().greatDeals == false and not greatButton.highlightLocked)
paintShopping()
check("off again, Auctionator's glow goes", not shoppingRows[1].texture.shown)
update()
check("and Blizzard's lists glow by the Deal Threshold again", cheap.texture.shown)
GameTooltip_AddInstructionLine, GameTooltip_AddErrorLine = addInstruction, addError
tsmValues.regionSalePercent = 779
setAppData(tsmValues)

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
local slash = SlashCmdList.SIMPLEMARKETVALUE
local openedBefore = #opened
capture(function() slash("") end)
check("bare /smv opens the settings and prints nothing", #opened == openedBefore + 1 and #printed == 0)
local helpLine = "<gold>[Simple Market Value]</>: Type /smv for the settings, /smv intro to see the welcome line and the tip again, or /smv help for this list."
capture(function() slash(" HELP ") end)
check("/smv help prints one line naming every command", #printed == 1 and printed[1] == helpLine, printed[1])
capture(function() slash("?") end)
check("/smv ? prints the same line", #printed == 1 and printed[1] == helpLine, printed[1])
openedBefore = #opened
capture(function() slash("frobnicate") end)
check("an unknown word prints the hint and opens nothing", #printed == 1 and printed[1] == "<gold>[Simple Market Value]</>: Unknown command. Type /smv help for the list." and #opened == openedBefore, printed[1])
capture(function() slash("intro") end)
check("/smv intro prints the welcome line again", #printed == 1 and printed[1] == welcome, printed[1])
check("/smv intro brings the tip back at once while Full Scan shows", AP.DB().tipSeen == nil and tip.shown and tip.info ~= nil)
local inits = tip.inits
fullScan:Show()
check("an open tip is not set up again", tip.inits == inits)
-- The tip was acknowledged once, by the Full Scan click; brought back, it must count as fresh
fullScan:Hide()
check("a tip brought back by /smv intro is not marked seen when Full Scan hides", AP.DB().tipSeen == nil and not tip.shown)
fullScan:Show()
check("it shows again at Full Scan's next show", tip.shown and tip.info ~= nil)
tip.CloseButton:Click()
check("its close button retires it for good", AP.DB().tipSeen == true and not tip.shown)
AP.DB().tipSeen = nil
fullScan:Hide()
check("Full Scan hidden: /smv intro waits for its next show", (function()
    capture(function() slash("intro") end)
    return not tip.shown
end)())
fullScan:Show()
check("then the tip shows", tip.shown)

print(failures == 0 and "All checks passed." or (failures .. " checks failed."))
os.exit(failures == 0 and 0 or 1)
