<img src="https://raw.githubusercontent.com/miyankooo/SimpleMarketValue/main/.github/icon.png" width="64" height="64" alt="">

# Simple Market Value

A WoW Forever addon that shows every auction price as a percentage of its market value, the 14-day average of Auctionator's scans, so you see at a glance what is a deal and what is worth selling. It works in Auctionator and in Blizzard's Auction House. It needs only Auctionator, which the CurseForge app installs with it. If you also run the TSM desktop app, it adds TSM's sale data on top.

## Features

- A Relative column in Auctionator's Shopping and Selling tabs, on its buy screens for items and commodities, and in Blizzard's auction lists, where it sits beside the item name in search results.
- Every percentage is green for a good price, yellow for a fair one and red for a poor one, by your Deal Threshold while you shop and your Sell Threshold while you sell.
- Item tooltips show one Market Value block with every price of the item: the Vendor price, then Auctionator's section with when it last saw a price, its Min Buyout, its 14-Day Average and the Relative percentage of the one against the other.
- Sale Assist, the first line of that block while you are on the selling side, says where to sell the item: Auction in green, Auction maybe in yellow when today's price is low and waiting may pay more, or Vendor in white. It weighs what a vendor pays against what an auction is expected to bring after the auction house's 5% cut and the deposits lost on listings that do not sell. It learns the real deposits from the game as you post through Auctionator, and it stays silent where the answer depends on how well the item sells and nobody knows.
- Auctionator's own Vendor and Auction tooltip lines move into that block, so the prices sit in one place. Hold Shift over a stack and every price in the block is for the whole stack, as Auctionator's stack price option sets.
- Deals glow green in Blizzard's buy lists.
- Highlight Deals, a checkbox beside Full Scan, makes only great deals glow green in every buy list, Blizzard's and Auctionator's: items priced at least 50% below their 14-Day Average.
- Items worth selling glow green in Auctionator's Selling tab.
- Sale Scan refreshes the prices of everything in your bags with one click.
- A Full Scan button on Auctionator's Shopping tab refreshes every price on the Auction House, with its progress on the button.
- Optional, with the TSM desktop app: the tooltip adds a TSM section with the region Sale Average, a TSM Sales section with the Sale Rate (green from 80%, yellow from 60%, orange from 40%, red below) and Daily Sold, and a TSM Trend section with TSM's Recent Average, Historical Average and the Trend between them. Sale Assist then reckons with the item's real Sale Rate, great deals must also sit 50% below TSM's Sale Average and sell 80% of the time, and TSM's Sale Average fills in where Auctionator has too few days of prices.

## Usage

1. Open the Auction House and click Full Scan in Auctionator's Shopping tab, or Sale Scan in its Selling tab, so prices exist.
2. Hover an item to see its market value. A gray percentage rests on fewer than 3 days of prices.
3. Browse and shop as usual. Green rows are deals. Tick Highlight Deals to light only the great ones, and untick it to see all deals. Sort by Relative to find the cheapest listings.
4. Type `/smv`, or pick Simple Market Value in the addon menu, to set the Sell Threshold and the Deal Threshold, which decide both the colours and the glows. `/smv help` lists the commands.

- For the TSM sections, install the TSM desktop app and the TradeSkillMaster addon, and log in with the addon enabled once per ruleset and faction, so the app knows which data to fetch. After that the sections show even while the TradeSkillMaster addon is disabled. New data shows after a login or /reload.
