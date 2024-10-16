--Replicates objects on the client.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectReplication = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("ObjectReplication"))
local NexusInstance = require(script.Parent.Parent:WaitForChild("NexusInstance"))

local NexusReplicationEvents = ReplicatedStorage:WaitForChild("NexusReplicationEvents")
local ObjectCreated = NexusReplicationEvents:WaitForChild("ObjectCreated")
local SendSignal = NexusReplicationEvents:WaitForChild("SendSignal")
local GetObjects = NexusReplicationEvents:WaitForChild("GetObjects")

local ClientObjectReplication = {}
ClientObjectReplication.__index = ClientObjectReplication
setmetatable(ClientObjectReplication, ObjectReplication)

export type ClientObjectReplication = {
    InitialObjectsLoading: number,
    InitialIds: {[number]: boolean}?,
    QueuedSignals: {[number]: {any}},
    LoadingStarted: NexusInstance.TypedEvent<>?,
    ObjectLoaded: NexusInstance.TypedEvent<>,
} & typeof(setmetatable({}, ClientObjectReplication)) & ObjectReplication.ObjectReplication
export type NexusInstanceClientObjectReplication = NexusInstance.NexusInstance<ClientObjectReplication>



--[[
Loads the current objects from the server.
Can only be called on the client.
--]]
function ClientObjectReplication.LoadServerObjects(self: NexusInstanceClientObjectReplication): ()
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
        task.spawn(function()
            self:LoadObject(ObjectData)
            self.InitialObjectsLoading = self.InitialObjectsLoading - 1
            self.ObjectLoaded:Fire()
        end)
    end
    if self.LoadingStarted then
        self.LoadingStarted:Fire()
        self.LoadingStarted = nil
    end
end

--[[
Loads an object from serialization data.
Can only be called on the client.
--]]
function ClientObjectReplication.LoadObject(self: NexusInstanceClientObjectReplication, ObjectData: any): any
    --Create the object.
    local Object = self:GetClass(ObjectData.Type).FromSerializedData(ObjectData.Object,ObjectData.Id)

    --Run the queued signals.
    if self.QueuedSignals[ObjectData.Id] then
        for _,SignalData in self.QueuedSignals[ObjectData.Id] do
            Object:OnSignal(unpack(SignalData))
        end
        self.QueuedSignals[ObjectData.Id] = nil
    end

    --Return the object.
    return Object
end





return NexusInstance.ToInstance(ClientObjectReplication) :: NexusInstance.NexusInstanceClass<typeof(ClientObjectReplication), () -> (ClientObjectReplication)>