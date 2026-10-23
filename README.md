# Auctionator Plus

Adds price history, a relative value column, a stat filter and similar-item pricing to Auctionator in WoW Forever.

## Features

- Item tooltips show the 14-day average price from Auctionator's scans and how the last price compares to it.
- A Relative column in Shopping results, the Selling tab's current prices and the buy screen shows how far each price sits from the average. Green is the good side for the view you are in.
- A Filter button in the Shopping tab narrows equipment to the stats you tick, such as Strength, Spell Power or Critical Strike. Consumables and trade goods always stay.
- With gear or a bag in the sale slot, auctions of comparable items join the current prices, marked Similar. Comparable means the same slot and type, a similar required level and the same stats within a range you set.
- Bag items in the Selling tab glow green when their last price beats the average by your threshold.
- Sale Scan runs a live price search for every item in your bag panel, so the Relative column and the glow use current prices.

## Installation

1. Install it with the CurseForge app under WoW Forever, or copy the `AuctionatorPlus` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
2. Restart the game or type `/reload`.
3. Enable Auctionator Plus in the AddOns list.

## Usage

1. Open the Auction House and click Sale Scan in the Selling tab, or run Auctionator's Full Scan, so prices exist.
2. Hover any item to see its 14-day average and how its last price compares.
3. In Shopping, sort by Relative to find cheap listings, or click Filter and tick the stats you want.
4. In Selling, click Sale Scan with an empty sale slot to refresh the prices of everything in your bags.
5. Put gear in the sale slot. Similar auctions appear in the current prices within a few seconds. Click one to undercut its price.

## Commands

| Command | Does |
| --- | --- |
| `/auctionatorplus` | Opens the settings |
| `/aplus` | Short form of `/auctionatorplus` |

## Settings

Open them with `/aplus`, from the addon menu at the minimap or under Options, AddOns. The range settings grey out while Show Similar Items is off.

| Setting | Default | Does |
| --- | --- | --- |
| Sell Threshold | +15% | How far above the average a last price must sit before a bag item glows |
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
