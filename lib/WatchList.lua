local mq = require("mq")
local Logger = require("LootWatch.lib.Logger")

local WatchList = {}

WatchList.read = function(iniFile)
    local watchList = {}

    local iniItems = iniFile.Section('Items')

    local keyCount = iniItems.Key.Count()

    for i=1,keyCount do
        local key = iniItems.Key.KeyAtIndex(i)()
        local value = iniItems.Key(key).Value()

        local loot = value == "true" and true or false
        watchList[key] = loot
    end

    return watchList
end

WatchList.write = function(filePath, watchList)
    for itemName, loot in pairs(watchList) do
        Logger.Debug(string.format("Writing Watch List Item %s", itemName))

        mq.cmdf('/ini "%s" "%s" "%s" "%s"', filePath, 'Items', itemName, loot)
    end
end

WatchList.get = function(filePath)
    local iniFile = mq.TLO.Ini.File(filePath)

    local watchList = {}

    if (iniFile.Exists()) then
        Logger.Debug(string.format("Items file found - Path=%s", filePath))

        watchList = WatchList.read(iniFile)
    else
        Logger.Info(string.format("Updating items File=%s", filePath))
        WatchList.write(filePath, {["Some Item"]= true})
    end

    return watchList
end

WatchList.isEmpty = function(watchList)
    local items = {}
    for item, loot in pairs(watchList) do
        if loot then
            table.insert(items, item)
        end
    end

    return next(items) == nil
end

WatchList.print = function(watchList)
    Logger.Info("Watching Items:")

    if WatchList.isEmpty(watchList) then
        Logger.Info("No items")
    else
        for item, loot in pairs(watchList) do
            if loot then
                Logger.Info(item)
            end
        end
    end
end

return WatchList