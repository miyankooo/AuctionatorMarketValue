<img src="https://raw.githubusercontent.com/miyankooo/SimpleMarketValue/main/.github/icon.png" width="64" height="64" alt="">

# Simple Market Value

A WoW Forever addon that shows every auction price as a percentage of its market value, so you see at a glance what is a deal and what sells well. The market value is the 14-day average of Auctionator's scans or, with the TSM desktop app, TSM's region sale average. It works in Auctionator and in Blizzard's Auction House. Needs Auctionator, which the CurseForge app installs with it. Works best with the TSM desktop app as well, for TSM's region sale prices and sale rates.

## Features

- Item tooltips show one Market Value block with every price of the item: the Vendor price, then a block per source. Auctionator: when it last saw a price, its Min Buyout, its 14-Day Average and the Relative percentage of the one against the other. TSM, with the TSM desktop app: how old its last scan of your auction house is, that scan's Min Buyout, the region Sale Average, their Relative percentage, the Sale Rate and Daily Sold. The Sale Rate shows how easily the item sells: green from 80%, yellow from 60%, orange from 40%, red below.
- Auctionator's own Vendor and Auction tooltip lines move into that block, so the prices sit in one place. Hold Shift over a stack and every price in the block is for the whole stack, as Auctionator's stack price option sets.
- A Relative column in Auctionator's Shopping and Selling tabs, on its buy screens for items and commodities, and in Blizzard's auction lists, where it sits beside the item name in search results.
- Every percentage is green for a good price, yellow for a fair one and red for a poor one, by your Deal Threshold while you shop and your Sell Threshold while you sell.
- Deals glow green in Blizzard's buy lists.
- Highlight Deals, a checkbox beside Full Scan, makes only great deals glow green in every buy list, Blizzard's and Auctionator's: items priced at least 50% below both TSM's Sale Average and Auctionator's 14-Day Average, so cheap for the region and for your own auction house, that TSM sees sell 80% of the time or more. Needs the TSM desktop app.
- Items worth selling glow green in Auctionator's Selling tab.
- Sale Scan refreshes the prices of everything in your bags with one click.
- A Full Scan button on Auctionator's Shopping tab refreshes every price on the Auction House, with its progress on the button.

## Usage

1. Open the Auction House and click Full Scan in Auctionator's Shopping tab, or Sale Scan in its Selling tab, so prices exist.
2. Hover an item to see its market value. A gray percentage rests on fewer than 3 days of prices. With the TSM desktop app, the TSM block appears on its own, even while the TradeSkillMaster addon is disabled. Keep TradeSkillMaster installed and log in with it enabled once per ruleset and faction, so the app knows which data to fetch. New data shows after a login or /reload.
3. Browse and shop as usual. Green rows are deals. Tick Highlight Deals to light only the great ones, and untick it to see all deals. Sort by Relative to find the cheapest listings.
4. Type `/smv`, or pick Simple Market Value in the addon menu, to set the Sell Threshold and the Deal Threshold, which decide both the colours and the glows. `/smv help` lists the commands.
