# Auctionator Market Value

Shows how every price compares to its 14-day market value, in Auctionator and in Blizzard's own Auction House, so buy and sell decisions take one glance.

## Features

- Blizzard's browse, buy and sell lists show each price's percentage against the 14-day average. Buy rows that sit at least your deal threshold below it glow green.
- Typing a price in Blizzard's sell window or Auctionator's sale slot shows at once how it compares to the average.
- Item tooltips show the 14-day average, how many days of history back it, and how the last price compares. With TradeSkillMaster installed they also show its market value and the last price against it.
- A percentage backed by fewer than 3 days of history shows in grey, since it says little yet.
- A Relative column in Shopping results, the Selling tab's current prices and the buy screen shows how far each price sits from the average. Green is the good side for the view you are in.
- A Filter button in the Shopping tab narrows equipment to the stats you tick, such as Strength, Spell Power or Critical Strike. Consumables and trade goods always stay.
- With gear or a bag in the sale slot, auctions of comparable items join the current prices, marked Similar. Comparable means the same slot and type, a similar required level and the same stats within a range you set.
- Bag items in the Selling tab glow green when their last price beats the average by your threshold.
- Sale Scan runs a live price search for every item in your bag panel, so the Relative column and the glow use current prices.

## Installation

1. Install it with the CurseForge app under WoW Forever, or copy the `AuctionatorMarketValue` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Restart the game or type `/reload`.
3. Enable Auctionator Market Value in the AddOns list.

## Usage

1. Open the Auction House and click Sale Scan in the Selling tab, or run Auctionator's Full Scan, so prices exist.
2. Hover any item to see its 14-day average and how its last price compares.
3. Browse or search in Blizzard's Auction House: each price shows its percentage, and green rows are deals.
4. In Shopping, sort by Relative to find cheap listings, or click Filter and tick the stats you want.
5. In Selling, click Sale Scan with an empty sale slot to refresh the prices of everything in your bags.
6. Type a price in either sell window and read its percentage next to it before you post.
7. Put gear in the sale slot. Similar auctions appear in the current prices within a few seconds. Click one to undercut its price.

## Commands

| Command | Does |
| --- | --- |
| `/auctionatormarketvalue` | Opens the settings |
| `/amv` | Short form of `/auctionatormarketvalue` |

## Settings

Open them with `/amv`, from the addon menu at the minimap or under Options, AddOns. The range settings grey out while Show Similar Items is off.

| Setting | Default | Does |
| --- | --- | --- |
| Sell Threshold | +15% | How far above the average a last price must sit before a bag item glows |
| Deal Threshold | -20% | How far below the average a buy row must sit before it glows |
| Show Similar Items | On | Lists comparable auctions for gear and bags in the sale slot |
| Level Range | ±2 levels | How far a comparable's required level may differ |
| Weapon DPS Range | ±20% | How far a comparable weapon's damage per second may differ |
| Stat Value Range | ±30% | How far each stat of a comparable may differ |
| Stat Count Range | ±0 | How many more or fewer stats a comparable may carry |

## Requirements

WoW Forever 1.60.x (Interface `16001`) and [Auctionator](https://www.curseforge.com/wow/addons/auctionator).

## Restrictions

Price history comes from the data Auctionator collects. Run a Full Scan or a Sale Scan before you trust the Relative column.

The stat filter and similar items read the English item text. Other client languages match only in part.

The similar-items search waits while an Auctionator shopping search or full scan runs, and starts once it ends.

## Development

Run `lua Tests/Load.lua` from the addon folder. It loads every file against stubs of the game and Auctionator and checks the tooltip rows, the stat filter, Sale Scan and the stat parser.

## License

MIT. See [LICENSE](LICENSE).
