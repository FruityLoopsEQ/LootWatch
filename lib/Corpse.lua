local mq = require("mq")

local Logger = require("LootWatch.lib.Logger")

Corpse = {}
Corpse.__index = Corpse

function Corpse:new(spawn)
    local corpse = {}
    setmetatable(corpse, Corpse)

    corpse.spawn = spawn

    return corpse
end

function Corpse:build(spawn)
    local corpse = Corpse:new(spawn)

    return corpse
end

function Corpse:navTo()
    local spawnID = self:spawnID()

    mq.cmdf('/nav id %d log=off', spawnID)
    mq.delay(50)
    if mq.TLO.Navigation.Active() then
        local startTime = os.time()
        while mq.TLO.Navigation.Active() do
            mq.delay(100)
            if os.difftime(os.time(), startTime) > 5 then
                break
            end
        end
    end
end

function Corpse:spawnID() 
    return self.spawn.ID()
end

function Corpse:name()
    return self.spawn.Name()
end

function Corpse:target()
    self.spawn.DoTarget()
end


return Corpse