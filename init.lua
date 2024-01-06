local mq = require("mq")

local Settings = require("LootWatch.lib.Settings")
local WatchList = require("LootWatch.lib.WatchList")
local Logger = require("LootWatch.lib.Logger")
local Corpse = require("LootWatch.lib.Corpse")
local Loot = require("LootWatch.lib.Loot")

-- Constants
local spawnSearch = '%s radius %d zradius 50'
IniFilePath = mq.configDir .. '/LootWatch.ini'
WatchListFilePath = mq.configDir .. "/LootWatch_Items.ini"

local settings = {}
local function loadSettings()
    Logger.Debug("Loading settings")
    settings = Settings.get(IniFilePath)

    Logger.Info("Settings loaded")
    Settings.print(settings)
end

local watchList = {}
local function loadWatchList()
    Logger.Debug("Loading watch items")
    watchList = WatchList.get(WatchListFilePath)

    Logger.Info("WatchList loaded")
    WatchList.print(watchList)
end

local function lootMobs(loot, limit)
    limit = limit or 10

    Logger.Debug("Enter lootMobs")
    local deadCount = mq.TLO.SpawnCount(spawnSearch:format('npccorpse', settings.CorpseRadius))()
    Logger.Debug(string.format('There are %s corpses in range.', deadCount))
    local corpseList = {}
    for i=1,math.min(deadCount, limit) do
        local spawn = mq.TLO.NearestSpawn(('%d,'..spawnSearch):format(i, 'npccorpse', settings.CorpseRadius))
        local corpse = Corpse:build(spawn)
        if not loot:isCorpseLocked(corpse:spawnID()) then
            table.insert(corpseList, corpse)
        end
    end

    if #corpseList == 0 then
        Logger.Debug("No corpses found")
        return false
    end

    local didLoot = false
    Logger.Debug(string.format('Trying to loot %d corpses.', #corpseList))

    if settings.DisableChaseOnLoot then
        mq.cmd("/chase off")
    end

    for i=1,#corpseList do
        local corpse = corpseList[i]
        local corpseID = corpse:spawnID()

        local tryLoot = corpseID and corpseID > 0
        tryLoot = tryLoot and not loot:isCorpseLocked(corpseID)

        if tryLoot then
            Logger.Debug('Moving to corpse ID='..tostring(corpseID))
            corpse:navTo()

            loot:corpse(corpse)

            didLoot = true
            mq.doevents("InventoryFull")
        end
    end

    if settings.DisableChaseOnLoot then
        mq.cmd("/chase on")
    end

    Logger.Debug('Done with corpse list.')
    return didLoot
end

-- binds

local function print_usage()
    Logger.Info("\agAvailable Commands -")
    Logger.Info("\a-g/loot_watch on|off\a-t - Toggle loot_watch on/off")
    Logger.Info("\a-g/loot_watch items\a-t - List loot_watch items")
end

local function bind_loot_watch(cmd)
    if cmd == nil then
        print_usage()
        return
    end

    if cmd == "on" then
        settings.Enabled = true
        Logger.Info("\ayLoot Watch enabled.")
    elseif cmd == "off" then
        settings.Enabled = false
        Logger.Info("\ayLoot Watch disabled.")
    end

    if cmd == "items" then
        WatchList.print(watchList)
    end
end


local lootCount = {}
local function handleLooted(line, itemName, ...)
    -- Logger.Info(string.format("Looted %s", itemName))

    if lootCount[itemName] == nil then
        lootCount[itemName] = 0
    end

    lootCount[itemName] = lootCount[itemName] + 1

    mq.cmdf("/g %d %s AH AH AH.. ", lootCount[itemName], itemName)

    Logger.Info(string.format("%s, Total Item: %d", itemName, lootCount[itemName]))
end

local function initialize()
    loadSettings()
    loadWatchList()

    -- register binds
    mq.bind('/loot_watch', bind_loot_watch)

    mq.event("looted", "--You have looted a #1#.--", handleLooted)
end

local function in_game() return mq.TLO.MacroQuest.GameState() == "INGAME" end


local function start(loot)
    Logger.Debug("Starting")

    local last_time = os.time()

    while true do
        if in_game() and settings.Enabled then
            if os.difftime(os.time(), last_time) >= 1 then
                local inCombat = mq.TLO.Me.CombatState() == "COMBAT"
                local canLoot = settings.CombatLooting or not inCombat

                local mobsNearby = mq.TLO.SpawnCount(spawnSearch:format('xtarhater', settings.MobsTooClose))()

                if mobsNearby > 0 and not settings.CombatLooting then
                    Logger.Debug(string.format("Cannot loot - %d mobs nearby (distance: %d)", mobsNearby, settings.MobsTooClose))
                    canLoot = false
                end

                if canLoot then
                    local batchSize = 20
                    lootMobs(loot, batchSize)
                end

                last_time = os.time()
            end
            mq.doevents()
        end

        mq.delay(100)
    end
end

initialize()

Logger.loglevel = "info"

if (WatchList.isEmpty(watchList)) then
    Logger.Fatal("Not Watching Items. Exiting")
    os.exit()
else
    local loot = Loot:build(watchList, settings)
    local eventCantLoot = function()
        loot.cantLootID = mq.TLO.Target.ID()
    end
    mq.event("CantLoot", "#*#may not loot this corpse#*#", eventCantLoot)

    start(loot)
end
