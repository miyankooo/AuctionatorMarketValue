-- The TSM desktop app's AppData.lua, listed next in this toc, hands each block to select(2, ...).LoadData, this
-- add-on's table. Simple Market Value reads the blocks, so the call goes on to it
select(2, ...).LoadData = SimpleMarketValue_LoadTSMData
