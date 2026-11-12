local addonName, AP = ...

-- The first load on an account says what the addon does and links to its settings, once. The line waits for login,
-- when the settings exist and the client's own load lines are already in chat.

-- Blizzard reserves the addon link type for addons and hands every click on one to all of them through one
-- EventRegistry event (ItemRefHandlersShared.lua). Gold is the colour of Blizzard's own action links in chat, such as
-- club invites (ItemRef.lua).
local LINK = LinkTypes.AddOn .. ":" .. addonName

local function SurfaceLink(label)
    return NORMAL_FONT_COLOR:WrapTextInColorCode(LinkUtil.FormatLink(LinkTypes.AddOn, "[" .. label .. "]", addonName))
end

-- Auctionator is a toc dependency, so the client only runs this with it, and everything works on its scans alone.
-- Without the TSM desktop app's data the line ends with what the app would add, as an extra, never a need
local TSM_HINT = "Optional: the TSM desktop app adds TSM's sale prices, sale rates and price trend to the tooltip."

function AP.PrintWelcome()
    local line = "Shows how every auction price compares to its market value, in tooltips and auction lists. Open the "
        .. SurfaceLink(SETTINGS) .. " or type /smv to set when items to sell and deals glow green. Click Full Scan "
        .. "on Auctionator's Shopping tab first, so prices exist."
    if not AP.TSM.HasSaleRates() then line = line .. " " .. TSM_HINT end
    AP.Print(line)
end

-- The welcome line now, and the help tip again: at once while Full Scan shows, otherwise at its next show
function AP.ReplayIntro()
    AP.PrintWelcome()
    AP.DB().tipSeen = nil
    AP.FullScanButton.ShowTip()
end

-- Another addon's link may be secret, so it is checked before the comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if AP.CanAccess(link) and link == LINK then AP.OpenSettings() end
end, AP)

EventUtil.ContinueOnPlayerLogin(function()
    if AP.firstRun then AP.PrintWelcome() end
end)
