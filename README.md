<img src="https://raw.githubusercontent.com/miyankooo/SimpleMarketValue/main/.github/icon.png" width="64" height="64" alt="">

# Simple Market Value

A WoW Forever addon that shows every auction price as a percentage of its market value, so you see at a glance what is a deal and what sells well. The market value is the 14-day average of Auctionator's scans or, with the TSM desktop app, TSM's region sale average. It works in Auctionator and in Blizzard's Auction House. Needs Auctionator, which the CurseForge app installs with it. Works best with the TSM desktop app as well, for TSM's region sale prices and sale rates.

## Features

- Item tooltips show a Market Value section with a block per source. Auctionator: when it last saw a price, its List Average over 14 days and the last price's Market Value against it. TSM, with the TSM desktop app: when it last synced, the region Sale Average, Sale Rate and Daily Sold, and the same Market Value. The Sale Rate shows how easily the item sells: green from 80%, yellow from 60%, orange from 40%, red below.
- A timing verdict beside the Market Value heading: Strong Buy or Buy in green, Fair in yellow or Overpriced in red while you shop, Sell Now in green, Fair in yellow or Hold in red while you sell. It weighs the price against how much the item's price usually swings, how well it sells and where your auction house is heading. Under 7 days of prices it assumes a wide swing, so it only makes clear calls.
- A Relative column in Auctionator's Shopping and Selling tabs, on its buy screens for items and commodities, and in Blizzard's auction lists, where it sits beside the item name in search results.
- Every percentage is green for a good price, yellow for a fair one and red for a poor one, by your Deal Threshold while you shop and your Sell Threshold while you sell.
- Deals glow green in Blizzard's buy lists.
- Highlight Great Deals, beside Full Scan, makes only great deals glow green in every buy list, Blizzard's and Auctionator's: items at least 50% below their market value that TSM sees sell 80% of the time or more. Needs the TSM desktop app.
- Items worth selling glow green in Auctionator's Selling tab.
- Sale Scan refreshes the prices of everything in your bags with one click.
- A Full Scan button on Auctionator's Shopping tab refreshes every price on the Auction House, with its progress on the button.

## Usage

1. Open the Auction House and click Full Scan in Auctionator's Shopping tab, or Sale Scan in its Selling tab, so prices exist.
2. Hover an item to see its market value. A gray percentage rests on fewer than 3 days of prices. With the TSM desktop app, the TSM block appears on its own, even while the TradeSkillMaster addon is disabled. Keep TradeSkillMaster installed and log in with it enabled once per ruleset and faction, so the app knows which data to fetch. New data shows after a login or /reload.
3. Browse and shop as usual. Green rows are deals. Click Highlight Great Deals to light only the great ones, and again to see all deals. Sort by Relative to find the cheapest listings.
4. Type `/smv`, or pick Simple Market Value in the addon menu, to set the Sell Threshold and the Deal Threshold, which decide both the colours and the glows. `/smv help` lists the commands.
