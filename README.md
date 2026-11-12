<img src="https://raw.githubusercontent.com/miyankooo/SimpleMarketValue/main/.github/icon.png" width="64" height="64" alt="">

# Simple Market Value

A WoW Forever addon that shows every auction price as a percentage of its market value, so you see at a glance what is a deal and what is worth selling. The market value is Auctionator's Average Price, the middle of its daily lowest prices over the last 14 days. It works in Auctionator and in Blizzard's Auction House. It needs only Auctionator, which the CurseForge app installs with it. If you also run the TSM desktop app, it adds TSM's sale data on top and measures against TSM's region Sale Average.

## Features

- A Relative column in Auctionator's Shopping and Selling tabs, on its buy screens for items and commodities, and in Blizzard's auction lists, where it sits beside the item name in search results.
- Every percentage is green for a good price, yellow for a fair one and red for a poor one, by your Deal Threshold while you shop and your Sell Threshold while you sell.
- Item tooltips show one Market Value block with every price of the item: the Vendor price, then Auctionator's section with when it last saw a price, its Min Buyout, its Average Price over 14 days and vs Average Price, the percentage of the Min Buyout against it.
- Sale Assist, the first line of that block while you are on the selling side, says where to sell the item: Auction in green, Auction maybe in yellow when today's price is low and waiting may pay more, or Vendor in white. It weighs what a vendor pays against what an auction is expected to bring after the auction house's 5% cut and the deposits lost on listings that do not sell. It asks the game itself for the deposit of the item, and it stays silent where the answer depends on how well the item sells and nobody knows.
- Auctionator's own Vendor and Auction tooltip lines move into that block, so the prices sit in one place. Hold Shift over a stack and every price in the block is for the whole stack, as Auctionator's stack price option sets.
- Deals glow green in Blizzard's buy lists.
- Highlight Deals, a checkbox beside Full Scan, makes only great deals glow green in every buy list, Blizzard's and Auctionator's: items priced at least 50% below their Average Price.
- Items worth selling glow green in Auctionator's Selling tab.
- Sale Scan refreshes the prices of everything in your bags with one click.
- A Full Scan button on Auctionator's Shopping tab refreshes every price on the Auction House, with its progress on the button.
- Optional, with the TSM desktop app: the tooltip adds a TSM section with the region Sale Average, what the item actually sold for, and TSM's Market Value, what it is listed for on your auction house, each followed by the percentage of the same Min Buyout against it, and a TSM Sales section at the end with the Sale Rate (green from 80%, yellow from 60%, orange from 40%, red below) and Daily Sold. Sale Assist then reckons with the item's real Sale Rate, great deals must also sit 50% below TSM's Sale Average and sell 80% of the time, and the Relative column in the auction lists measures against TSM's Sale Average wherever TSM has one.

## Usage

1. Open the Auction House and click Full Scan in Auctionator's Shopping tab, or Sale Scan in its Selling tab, so prices exist.
2. Hover an item to see its market value. A gray percentage rests on fewer than 3 days of prices.
3. Browse and shop as usual. Green rows are deals. Tick Highlight Deals to light only the great ones, and untick it to see all deals. Sort by Relative to find the cheapest listings.
4. Type `/smv`, or pick Simple Market Value in the addon menu, to set the Sell Threshold and the Deal Threshold, which decide both the colours and the glows. `/smv help` lists the commands.

- For the TSM sections, install the TSM desktop app and the TradeSkillMaster addon, and log in with the addon enabled once per ruleset and faction, so the app knows which data to fetch. After that the sections show even while the TradeSkillMaster addon is disabled. New data shows after a login or /reload.
- The download includes Simple Market Value TSM, a small helper that reads the TSM app's data. It loads only when TSM is installed, so without TSM it does nothing.
