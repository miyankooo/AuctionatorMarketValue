# Changelog

## [2.4.0](https://github.com/miyankooo/SimpleMarketValue/compare/v2.3.1...v2.4.0) (2026-11-13)


### Features

* item tooltips keep Auctionator's own Vendor and Auction lines and add only a few rows under them: Auctionator's Min. Buyout Average with the percentage against it, and with TSM its Sale Average, the percentage against it and the Sale Rate ([167711b](https://github.com/miyankooo/SimpleMarketValue/commit/167711bae42608cf02f0012cc50d22700a9b5548))
* Sale Assist and TSM's Market Value are gone from item tooltips, and each section shows its age in brackets after its name, such as Auctionator (13m) ([28fdaba](https://github.com/miyankooo/SimpleMarketValue/commit/28fdabad6dc648c907f19bd0f471e7c17c1e3338))


### Bug Fixes

* the tooltip rows always sit right under Auctionator's Vendor and Auction lines, also when other addons such as Questie or RestedXP add their own lines ([b8b079f](https://github.com/miyankooo/SimpleMarketValue/commit/b8b079f8fb5349eac17cf7f7e54454d86f31d5ce))

## [2.3.1](https://github.com/miyankooo/SimpleMarketValue/compare/v2.3.0...v2.3.1) (2026-11-12)


### Bug Fixes

* players without TSM no longer get a Lua warning at login: the TSM desktop app's data now loads through a small helper, Simple Market Value TSM, only when TSM's AppHelper folder is installed ([9ed3f3d](https://github.com/miyankooo/SimpleMarketValue/commit/9ed3f3d65d48964277b3ab29214f65be8991fb3d))

## [2.3.0](https://github.com/miyankooo/SimpleMarketValue/compare/v2.2.1...v2.3.0) (2026-11-12)


### Features

* a TSM Sales section at the end of the Market Value block holds the Sale Rate and Daily Sold ([fe57b62](https://github.com/miyankooo/SimpleMarketValue/commit/fe57b624244ab517b5747a081d2b9889b709482d))
* Auctionator's Average Price is the median of its daily lowest prices over the last 14 days, and the TSM section shows TSM's Sale Average and Market Value, each with the percentage of the Min Buyout against it ([ddbf1e0](https://github.com/miyankooo/SimpleMarketValue/commit/ddbf1e0381f927ba65fa1d297d22e84de5dc7ec6))
* everything works with Auctionator alone, and the TSM desktop app only adds to it: Highlight Deals now also works without TSM and lights items 50% below their Average Price ([ff5ef73](https://github.com/miyankooo/SimpleMarketValue/commit/ff5ef73ef45d7a8644b3e6008ce35c0144f0c4d4))
* item tooltips show one Market Value block with every price: Vendor, then Auctionator's Min Buyout and Average Price, then TSM's figures, each average followed by the percentage of the Min Buyout against it, and Auctionator's own Vendor and Auction lines move into it ([e98d62c](https://github.com/miyankooo/SimpleMarketValue/commit/e98d62cd49a166409981e4c56f41f05b4fe51541))
* Sale Assist, the first line of the Market Value block while you sell, says where to sell an item: Auction, Auction maybe when today's price is low, or Vendor, weighing the vendor price against the expected auction proceeds after the 5% cut and the deposits lost on unsold listings ([bb96186](https://github.com/miyankooo/SimpleMarketValue/commit/bb961861ba1874e5cd05d5578fae11bedfefd985))
* the timing verdict, such as Strong Buy, Sell Now or Hold, is gone from item tooltips, so the prices speak for themselves ([e98d62c](https://github.com/miyankooo/SimpleMarketValue/commit/e98d62cd49a166409981e4c56f41f05b4fe51541))


### Bug Fixes

* the Deals button is now the Highlight Deals checkbox beside Full Scan, so its tick shows at a glance whether only great deals glow ([688b887](https://github.com/miyankooo/SimpleMarketValue/commit/688b8873fc0072c92cf7bb1c6de84971b781791c))
* the TSM heading in item tooltips shows how old TSM's figures are, not when the TSM app last synced ([06b4e2a](https://github.com/miyankooo/SimpleMarketValue/commit/06b4e2a0f02c692036b0eb13b8eef63ad49ce0b0))
* with the TSM desktop app, Highlight Deals lights only prices at least 50% below both TSM's Sale Average and Auctionator's Average Price, at a TSM Sale Rate of 80% or more, so a price that is normal on your own auction house no longer counts as a great deal ([06b4e2a](https://github.com/miyankooo/SimpleMarketValue/commit/06b4e2a0f02c692036b0eb13b8eef63ad49ce0b0))

## [2.2.1](https://github.com/miyankooo/SimpleMarketValue/compare/v2.2.0...v2.2.1) (2026-11-11)


### Bug Fixes

* the great deals button beside Full Scan is now called Deals, a shorter name for the crowded Shopping tab row ([cef9ffb](https://github.com/miyankooo/SimpleMarketValue/commit/cef9ffbb23ba88290c2e1be3baecdd93b8e8d719))

## [2.2.0](https://github.com/miyankooo/SimpleMarketValue/compare/v2.1.0...v2.2.0) (2026-11-11)


### Features

* Auctionator's commodity buy screen shows a Relative column beside the price, sortable like the others ([4a5ccee](https://github.com/miyankooo/SimpleMarketValue/commit/4a5cceede2e9337dfb3abc7b22f68362de0af07b))
* Highlight Great Deals beside Full Scan makes only great deals glow green in every buy list, items at least 50% below their market value that TSM sees sell 80% of the time or more ([2b104ea](https://github.com/miyankooo/SimpleMarketValue/commit/2b104ea619efbbe922c8727b909cd0a809384b54))
* the first-login welcome line recommends the TSM desktop app when its prices are missing ([7cfd3c9](https://github.com/miyankooo/SimpleMarketValue/commit/7cfd3c9b3a1363b1de1d420fcfaa3e7e3f4324dc))
* TSM's Sale Rate in item tooltips shows green from 80%, yellow from 60%, orange from 40% and red below, so you see at a glance how easily an item sells ([7ceee10](https://github.com/miyankooo/SimpleMarketValue/commit/7ceee10c6268ea41f2c4eb848438f1d975c22a7a))


### Bug Fixes

* the Relative percentage in Blizzard's search results moves from the cramped price column to the end of the name column, under its own header ([fc25eee](https://github.com/miyankooo/SimpleMarketValue/commit/fc25eeeee2eb1300e33bd02c7b6e7e1b744523e2))

## [2.1.0](https://github.com/miyankooo/SimpleMarketValue/compare/v2.0.0...v2.1.0) (2026-11-09)


### Features

* item tooltips show a buy or sell timing verdict beside Market Value ([280265c](https://github.com/miyankooo/SimpleMarketValue/commit/280265c1c6ab99fb6a8f9306b663815ecc646584))
* percentages and the timing verdict show green for a good price, yellow for a fair one and red for a poor one, by your Deal and Sell Thresholds ([a4764bf](https://github.com/miyankooo/SimpleMarketValue/commit/a4764bf1db7147a1869dd4b8f912616b55814572))
* TSM figures come straight from the TSM desktop app's data, so the TradeSkillMaster addon can stay disabled ([7784238](https://github.com/miyankooo/SimpleMarketValue/commit/77842380674e6eccc208985838c26293d7e4f0fc))

## [2.0.0](https://github.com/miyankooo/SimpleMarketValue/compare/v1.0.0...v2.0.0) (2026-11-09)


### ⚠ BREAKING CHANGES

* settings saved under Auctionator Market Value start over at their defaults, and /amv no longer works.

### Features

* rename the addon to Simple Market Value ([5721153](https://github.com/miyankooo/SimpleMarketValue/commit/5721153ab0879a058c4bb4e6f683d300d195b264))
* item tooltips show a Market Value section with an Auctionator block and a TSM block, each headed by the age of its data: Auctionator's List Average and Market Value, and TSM's Sale Average, Sale Rate, Daily Sold and Market Value ([f029484](https://github.com/miyankooo/SimpleMarketValue/commit/f029484338d50f203479d9a1d43309ef303606b5))
* the Relative column, the deal glow and the bag glow measure against TSM's region sale average wherever TradeSkillMaster has one ([28929b2](https://github.com/miyankooo/SimpleMarketValue/commit/28929b2276eda1eabf666c38ce96082c26071958))
* remove Similar Items from selling ([4eef8a4](https://github.com/miyankooo/SimpleMarketValue/commit/4eef8a4be8f80918256bbae8b829eefb0d0f1974))
* remove the percentage beside the price in Blizzard's and Auctionator's sell windows ([28929b2](https://github.com/miyankooo/SimpleMarketValue/commit/28929b2276eda1eabf666c38ce96082c26071958))

## 1.0.0 (2026-11-08)


### Features

* /amv opens the settings, /amv help lists the commands and /amv intro shows the welcome line and tip again ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* a Full Scan button on Auctionator's Shopping tab refreshes every price, with its progress on the button ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* a price you type to sell shows its percentage before you post ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* a Relative column in Auctionator's Shopping and Selling tabs and in Blizzard's auction lists ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* a welcome line and a help tip at Full Scan show new players where to start ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* auction lists show each price as a percentage of the average, and deals glow green ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* compare every auction price to its market value in Auctionator and Blizzard's Auction House ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* Sale Scan refreshes the prices of everything in your bags with one click ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* similar auctions help you price gear and bags ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* tooltips show an item's 14-day average from Auctionator and how its last price compares ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
* TradeSkillMaster support: tooltips also show TSM's market value, from the TSM addon or from the TSM desktop app's data ([4cb30ea](https://github.com/miyankooo/AuctionatorMarketValue/commit/4cb30ea297073865ddba480f104f7e542a3af7ef))
