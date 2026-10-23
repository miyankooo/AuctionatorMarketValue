# AuctionatorPlus

## Target

- WoW Forever 1.60.x only, `## Interface: 16001`. No client branches, no `WOW_PROJECT_*`, no compat layer.
- `main` holds the Forever version. `1.15.x-backup` keeps the dual-client 3.0.0 with all Classic code and stays untouched.
- Verify every API against Gethe `wow-ui-source` and Ketho `BlizzardInterfaceResources`, branch `forever`, using only the files the Forever client loads.
- Verify Auctionator internals against its mainline/camelot load set: `Source/`, `Source_Mainline/`, `Source_ModernAH/` and `Source_Forever/`.

## Rules

- `Modules/` holds one file per feature. A feature module owns its Auctionator hooks and the widgets it places in Auctionator's frames. `UI/` holds only `Settings.lua`.
- `Libs/` holds unedited copies of LibStub and LibNativeUI-1.0, loaded first in the toc. `Bootstrap` builds its list from every module at load, so it stays last.
- Auctionator's shopping search, its incremental scan and the Similar browse share one browse result set, since `Auctionator.AH.Queue` only throttles (`Source_ModernAH/AH/Wrappers.lua`). Two of them must never run at once. The replicate scan reads its own list and is exempt.
- The stat parser matches the client's own `ITEM_MOD_*` and `_SHORT` strings in long and short form, `%d` included, and skips inactive `(2) Set:` lines. The Stat Filter always lists all 25 stats and drops saved keys it does not list.
- Sale Scan records the cheapest buyout, not the first result's `buyoutAmount or bidAmount` that Auctionator's own sell search records.
- No TradeSkillMaster code until TSM ships a 16001 build. The last TSM code is in git history.
- The sale slot icon keeps its glow on purpose.
- `/ap` stays unused: Blizzard's commentator commands own it (`SLASH_COMMENTATOR_ASSIGNPLAYER3`).
- Dialogs use `UI.CreateDialog`. Escape closes the Stat Filter with the Auction House through `UISpecialFrames`. Never call `RegisterGameMenuEscHandler` from addon code: it sorts Blizzard's handler table from insecure code, which taints every Escape press and blocks the game menu in combat. The Stat Filter hides when the shopping tab hides.
- Settings rows that only matter while a checkbox is on are its children through `SetParentInitializer`.
- Buttons the addon places are 24 px `UI.CreateButton`. Sale Scan is a fixed 112, since its label changes during a scan. Filter is sized once for its longest label.
- Sizes and offsets are multiples of 4. Native template sizes come from `UI.Native`.
- Title Case for buttons, headings, setting names and menu entries. Sentence case ending with a period for tooltips and chat.
- Text uses 12 or 16 px Blizzard font objects only, never `SetFont`. Colours come from Blizzard colour objects such as `GREEN_FONT_COLOR`, `RED_FONT_COLOR` and `HIGHLIGHT_FONT_COLOR`, never literal `|cff` codes.
- The only chat line is "Opens after combat.", through `UI.Print`. Any new line uses the same prefix.
- The toc version stays 1.0.0 until the first CurseForge release.
- Licence: MIT (LICENSE).

## Checks

- Run `luac -p` on every Lua file and `lua Tests/Load.lua` after a change.
- Test in game with only Auctionator and AuctionatorPlus enabled, after `/console scriptErrors 1` and `/reload`.
