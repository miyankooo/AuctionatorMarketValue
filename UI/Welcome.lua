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

function AP.PrintWelcome()
    AP.Print("Shows how every auction price compares to its 14-day average, in tooltips and auction lists. Open the "
        .. SurfaceLink(SETTINGS) .. " or type /amv to set when items to sell and deals glow green. Click Full Scan "
        .. "on Auctionator's Shopping tab first, so prices exist.")
end

-- The welcome line now, and the help tip again at its next chance
function AP.ReplayIntro()
    AP.PrintWelcome()
    AP.DB().tipSeen = nil
end

-- Another addon's link may be secret, so it is checked before the comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if AP.CanAccess(link) and link == LINK then AP.OpenSettings() end
end, AP)

EventUtil.ContinueOnPlayerLogin(function()
    if AP.firstRun then AP.PrintWelcome() end
end)
