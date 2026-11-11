# Changelog

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
