local mq = require("mq")

local Logger = require("LootWatch.lib.Logger")

local function report(message, ...)
    Logger.Info("REPORT" .. string.format(message, ...))

    local lootChannel = "bc"
    local reportPrefix = '/%s \a-t]\ax\ayLootWatch\ax\a-t]\ax '
    local prefixWithChannel = reportPrefix:format(lootChannel)

    mq.cmdf(prefixWithChannel .. message, ...)
end

local function checkCursor()
    local currentItem = nil
    while mq.TLO.Cursor() do
        -- can't do anything if there's nowhere to put the item, either due to no free inventory space
        -- or no slot of appropriate size
        if mq.TLO.Me.FreeInventory() == 0 or mq.TLO.Cursor() == currentItem then
            Logger.Debug('Inventory full, item stuck on cursor')
            mq.cmd('/autoinv')
            return
        end
        currentItem = mq.TLO.Cursor()
        mq.cmd('/autoinv')
        mq.delay(100)
    end
end

Loot = {
  cantLootID = 0,
  cantLootList = {}
}
Loot.__index = Loot

function Loot:new(watchList, saveBagSlots)
    local loot = {}
    setmetatable(loot, Loot)

    loot.watchList = watchList
    loot.saveBagSlots = saveBagSlots

    return loot
end

function Loot:build(watchList, settings)
    local saveBagSlots = settings.SaveBagSlots

    local loot = Loot:new(watchList, saveBagSlots)

    return loot
end

function Loot:isCorpseLocked(spawnID)
    if not self.cantLootList[spawnID] then return false end
    if os.difftime(os.time(), self.cantLootList[spawnID]) > 60 then
        self.cantLootList[spawnID] = nil
        return false
    end
    return true
end

function Loot:lockCorpse(spawnID)
    self.cantLootList[spawnID] = os.time()
end

function Loot:corpse(corpse)
    Logger.Debug(string.format("Looting Corpse %s", corpse:name()))

    corpse:target()
    local corpseID = corpse:spawnID()

    if mq.TLO.Cursor() then checkCursor() end
    if mq.TLO.Me.FreeInventory() <= self.saveBagSlots then
        report('My bags are full, I can\'t loot anymore!')
    end
    for i=1,3 do
        mq.cmd('/loot')
        mq.delay(1000, function() return mq.TLO.Window('LootWnd').Open() end)
        if mq.TLO.Window('LootWnd').Open() then break end
    end
    mq.doevents('CantLoot')
    mq.delay(3000, function() return self.cantLootID > 0 or mq.TLO.Window('LootWnd').Open() end)
    if not mq.TLO.Window('LootWnd').Open() then
        Logger.Warn(('Can\'t loot %s right now'):format(mq.TLO.Target.CleanName()))
        self:lockCorpse(corpseID)
        return
    end
    mq.delay(1000, function() return (mq.TLO.Corpse.Items() or 0) > 0 end)
    local items = mq.TLO.Corpse.Items() or 0
    Logger.Debug(('Loot window open. Items: %s'):format(items))
    local corpseName = mq.TLO.Corpse.Name()
    if mq.TLO.Window('LootWnd').Open() and items > 0 then
        local noDropItems = {}
        local loreItems = {}
        for i=1,items do
            local freeSpace = mq.TLO.Me.FreeInventory()
            local corpseItem = mq.TLO.Corpse.Item(i)
            if corpseItem() then
                local itemName = corpseItem.Name()
                Logger.Debug("Checking Item:" .. itemName)

                local lootItem = self.watchList[itemName]

                if lootItem then
                    Logger.Info("Item found in watch list:" .. itemName)
                    local stackable = corpseItem.Stackable()
                    local freeStack = corpseItem.FreeStack()

                    if corpseItem.NoDrop() then
                        table.insert(noDropItems, corpseItem.ItemLink('CLICKABLE')())
                    elseif corpseItem.Lore() then
                        local haveItem = mq.TLO.FindItem(('=%s'):format(corpseItem.Name()))()
                        local haveItemBank = mq.TLO.FindItemBank(('=%s'):format(corpseItem.Name()))()
                        if haveItem or haveItemBank or freeSpace <= self.saveBagSlots then
                            table.insert(loreItems, corpseItem.ItemLink('CLICKABLE')())
                        else
                            self:corpseItemIndex(i)
                        end
                    elseif freeSpace > self.saveBagSlots or (stackable and freeStack > 0) then
                        self:corpseItemIndex(i)
                        -- lootItem(i, getRule(corpseItem), 'leftmouseup')
                    end
                end
            end
            if not mq.TLO.Window('LootWnd').Open() then break end
        end

        if self.reportLoot and #noDropItems > 0 or #loreItems > 0 then
            local skippedItems = '/%s Skipped loots (%s - %s) '
            for _,noDropItem in ipairs(noDropItems) do
                skippedItems = skippedItems .. ' ' .. noDropItem .. ' (nodrop) '
            end
            for _,loreItem in ipairs(loreItems) do
                skippedItems = skippedItems .. ' ' .. loreItem .. ' (lore) '
            end
            report(skippedItems, corpseName, corpseID)
        end
    end
    mq.cmd("/nomodkey /notify LootWnd LW_DoneButton leftmouseup")
    mq.delay(3000, function() return not mq.TLO.Window('LootWnd').Open() end)
    -- if the corpse doesn't poof after looting, there may have been something we weren't able to loot or ignored
    -- mark the corpse as not lootable for a bit so we don't keep trying
    if mq.TLO.Spawn(('corpse id %s'):format(corpseID))() then
        self.cantLootList[corpseID] = os.time()
    end
end

function Loot:corpseItemIndex(index)
    local button = "leftmouseup"

    local itemName = mq.TLO.Corpse.Item(index).Name()

    Logger.Info("Looting Corpse Item" .. itemName)

    mq.cmdf('/nomodkey /shift /itemnotify loot%s %s', index, button)

    mq.delay(5000, function() return mq.TLO.Cursor() ~= nil or not mq.TLO.Window('LootWnd').Open() end)
    mq.delay(1) -- force next frame

    if not mq.TLO.Window('LootWnd').Open() then return end

    mq.cmdf("/g Found %s", itemName)
    report('Looting \ay%s\ax', itemName)

    if mq.TLO.Cursor() then
        checkCursor()
    end
end

return Loot