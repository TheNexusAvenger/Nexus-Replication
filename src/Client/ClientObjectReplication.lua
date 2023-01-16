--[[
TheNexusAvenger

Replicates objects on the client.
--]]
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local NexusEvent = require(script.Parent.Parent:WaitForChild("NexusInstance"):WaitForChild("Event"):WaitForChild("NexusEvent"))
local ObjectReplication = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("ObjectReplication"))

local NexusReplicationEvents = ReplicatedStorage:WaitForChild("NexusReplicationEvents")
local ObjectCreated = NexusReplicationEvents:WaitForChild("ObjectCreated")
local SendSignal = NexusReplicationEvents:WaitForChild("SendSignal")
local GetObjects = NexusReplicationEvents:WaitForChild("GetObjects")

local ClientObjectReplication = ObjectReplication:Extend()
ClientObjectReplication:SetClassName("ClientObjectReplication")

export type ClientObjectReplication = {
    new: () -> (ClientObjectReplication),
    Extend: (self: ClientObjectReplication) -> (ClientObjectReplication),

    YieldForInitialLoad: (self: ClientObjectReplication) -> (),
} & Types.ObjectReplication



--[[
Creates the object replicator.
--]]
function ClientObjectReplication:__new(): ()
    ObjectReplication.__new(self)

    --Set the id and incrementer for client-only objects.
    self.CurrentId = -1
    self.IdIncrementer = -1

    --Store the loading state.
    self.ObjectLoaded = NexusEvent.new()
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
    SendSignal.OnClientEvent:Connect(function(Id, ...)
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
end

--[[
Loads the current objects from the server.
Done seprately from the constructor due to a
cyclic dependency.
--]]
function ClientObjectReplication:LoadServerObjects(): ()
    --Get the ids of the objects.
    --This is done before creating objects from ObjectCreated due to a race condition where it is invoked first.
    local InitialObjects = GetObjects:InvokeServer()
    local InitialIds = {}
    for _,ObjectData in InitialObjects do
        InitialIds[ObjectData.Id] = true
    end
    self.InitialIds = InitialIds

    --Load to the objects.
    for _, ObjectData in InitialObjects do
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
function ClientObjectReplication:LoadObject(ObjectData: any): Types.ReplicatedContainer
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
function ClientObjectReplication:YieldForInitialLoad(): ()
    while self.InitialObjectsLoading > 0 do
        self.ObjectLoaded:Wait()
    end
end

--[[
Returns the global replicated container.
If GetGlobalContainer is not called on the server,
this will yield indefinetly.
--]]
function ClientObjectReplication:GetGlobalContainer(): Types.ReplicatedContainer
    self:YieldForInitialLoad()
    return self:GetObject(0)
end



return (ClientObjectReplication :: any) :: ClientObjectReplication