local mq = require("mq")
local Logger = require("LootWatch.lib.Logger")

local defaults = {
    Enabled = true,
    CorpseRadius = 200,
    MobsTooClose = 10,
    LootChannel = "bc",
    ReportLoot = true,
    SaveBagSlots = 1,
    CombatLooting = false,
    DisableChaseOnLoot = false
}

local Settings = {}

Settings.read = function(iniFile)
    local settings = {}

    local iniSettings = iniFile.Section('Settings')

    local keyCount = iniSettings.Key.Count()

    for i=1,keyCount do
        local key = iniSettings.Key.KeyAtIndex(i)()
        local value = iniSettings.Key(key).Value()

        Logger.Debug(string.format("Reading Setting %s=%s", key, value))

        if value == 'true' or value == 'false' then
            settings[key] = value == 'true' and true or false
        elseif tonumber(value) then
            settings[key] = tonumber(value)
        else
            settings[key] = value
        end
    end

    return settings
end

Settings.print = function(settings) 
    for option,value in pairs(settings) do
        Logger.Info(string.format("Setting %s=%s", option, value))
    end
end

local saveOptionTypes = {string=true,number=true,boolean=true}

Settings.write = function(filePath, settings) 
    for option, value in pairs(settings) do
        local valueType = type(value)
        settings[option] = value

        local saveSetting = saveOptionTypes[valueType]

        if saveSetting == nil then
            Logger.Error(string.format("Unknown setting type %s", valueType))
        end

        if saveSetting then
            Logger.Debug(string.format("Writing Setting %s=%s", option, value))

            mq.cmdf('/ini "%s" "%s" "%s" "%s"', filePath, 'Settings', option, value)
        end
    end
end

Settings.get = function(filePath)
    local iniFile = mq.TLO.Ini.File(filePath)

    local settings = defaults

    if (iniFile.Exists()) then
        Logger.Debug(string.format("Settings file found - Path=%s", filePath))

        local loadedSettings = Settings.read(iniFile)

        for option, value in pairs(loadedSettings) do
            settings[option] = value
        end
    end

    Logger.Info(string.format("Updating settings File=%s", filePath))
    Settings.write(filePath, settings)

    return settings
end

return Settings