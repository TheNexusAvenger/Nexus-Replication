--[[
TheNexusAvenger

Replicates objects on the client.
--]]

local SERVER_TIME_SYNC_DELAY = 3
local SERVER_TIME_SAMPLES = 5
local SERVER_TIME_THRESHOLD = 0.1



local NexusReplication = require(script.Parent.Parent)

local ObjectCreated = NexusReplication:GetResource("NexusReplicationEvents.ObjectCreated")
local SendSignal = NexusReplication:GetResource("NexusReplicationEvents.SendSignal")
local GetObjects = NexusReplication:GetResource("NexusReplicationEvents.GetObjects")
local GetServerTime = NexusReplication:GetResource("NexusReplicationEvents.GetServerTime")
local NexusEventCreator = NexusReplication:GetResource("NexusInstance.Event.NexusEventCreator")

local ClientObjectReplication = NexusReplication:GetResource("Common.ObjectReplication"):Extend()
ClientObjectReplication:SetClassName("ClientObjectReplication")



--[[
Creates the object replicator.
--]]
function ClientObjectReplication:__new()
    self:InitializeSuper()

    --Set the id and incrementer for client-only objects.
    self.CurrentId = -1
    self.IdIncrementer = -1

    --Store the loading state.
    self.ObjectLoaded = NexusEventCreator:CreateEvent()
    self.InitialObjectsLoading = 0
    self.InitialIds = nil --Set in LoadServerObjects
    self.QueuedSignals = {}

    --Connect loading new objects.
    ObjectCreated.OnClientEvent:Connect(function(ObjectData)
        --Return if the object will be or has been created by the initial ids.
        --This is due to a race condition where this is invoked first.
        if not self.InitialIds then
            self:GetPropertyChangedSignal("InitialIds"):Wait()
        end
        if self.InitialIds[ObjectData.Id] then
            return
        end

        --Create the object.
        self:LoadObject(ObjectData)
    end)

    --Connect listening to events.
    SendSignal.OnClientEvent:Connect(function(Id,...)
        local Object = self.ObjectRegistry[Id] or self.DisposeObjectRegistry[Id]
        if Object then
            Object:OnSignal(...)
        elseif Id then
            if not self.QueuedSignals[Id] then
                self.QueuedSignals[Id] = {}
            end
            table.insert(self.QueuedSignals[Id],{...})
        end
    end)

    --Get the server time.
    self:UpdateServerTime()

    --Set up a loop update the server time until the time has stabilized.
    --Sometimes the server time is off when a player joins.
    local ServerTimeOffsets = {self.ServerTimeOffset}
    local CurrentIndex = 2
    for _ = 1,SERVER_TIME_SAMPLES - 1 do
        table.insert(ServerTimeOffsets,math.huge)
    end
    coroutine.wrap(function()
        while true do
            --Update the server time.
            wait(SERVER_TIME_SYNC_DELAY)
            self:UpdateServerTime()
            ServerTimeOffsets[CurrentIndex] = self.ServerTimeOffset
            CurrentIndex = (CurrentIndex % SERVER_TIME_SAMPLES) + 1

            --Break the loop if all the samples are "close" (stable).
            local ValuesClose = true
            for i = 2,SERVER_TIME_SAMPLES do
                if math.abs(ServerTimeOffsets[1] - ServerTimeOffsets[i]) > SERVER_TIME_THRESHOLD then
                    ValuesClose = false
                    break
                end
            end
            if ValuesClose then
                break
            end
        end
    end)()
end

--[[
Updates the server time.
--]]
function ClientObjectReplication:UpdateServerTime()
    local StartTime = tick()
    local ServerTime = GetServerTime:InvokeServer()
    local EndTime = tick()
    local AverageClientTime = StartTime + ((EndTime - StartTime)/2)
    self.ServerTimeOffset = ServerTime - AverageClientTime
end

--[[
Loads the current objects from the server.
Done seprately from the constructor due to a
cyclic dependency.
--]]
function ClientObjectReplication:LoadServerObjects()
    --Get the ids of the objects.
    --This is done before creating objects from ObjectCreated due to a race condition where it is invoked first.
    local InitialObjects = GetObjects:InvokeServer()
    local InitialIds = {}
    for _,ObjectData in pairs(InitialObjects) do
        InitialIds[ObjectData.Id] = true
    end
    self.InitialIds = InitialIds

    --Load to the objects.
    for _,ObjectData in pairs(InitialObjects) do
        self.InitialObjectsLoading = self.InitialObjectsLoading + 1
        coroutine.wrap(function()
            self:LoadObject(ObjectData)
            self.InitialObjectsLoading = self.InitialObjectsLoading - 1
            self.ObjectLoaded:Fire()
        end)()
    end
end

--[[
Loads an object from serialization data.
--]]
function ClientObjectReplication:LoadObject(ObjectData)
    --Create the object.
    local Object = self:GetClass(ObjectData.Type).FromSerializedData(ObjectData.Object,ObjectData.Id)

    --Run the queued signals.
    if self.QueuedSignals[ObjectData.Id] then
        for _,SignalData in pairs(self.QueuedSignals[ObjectData.Id]) do
            Object:OnSignal(unpack(SignalData))
        end
        self.QueuedSignals[ObjectData.Id] = nil
    end

    --Return the object.
    return Object
end

--[[
Yields for the initial objects to load.
--]]
function ClientObjectReplication:YieldForInitialLoad()
    while self.InitialObjectsLoading > 0 do
        self.ObjectLoaded:Wait()
    end
end

--[[
Returns the global replicated container.
If GetGlobalContainer is not called on the server,
this will yield indefinetly.
--]]
function ClientObjectReplication:GetGlobalContainer()
    self:YieldForInitialLoad()
    return self:GetObject(0)
end

--[[
Returns the current server time.
May not be completely accurate.
--]]
function ClientObjectReplication:GetServerTime()
    return tick() + self.ServerTimeOffset
end



return ClientObjectReplication