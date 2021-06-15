--[[
TheNexusAvenger

Initializes Nexus Replication.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NexusProject = require(script:WaitForChild("NexusProject"))
local NexusReplication = NexusProject.new(script)
NexusReplication.SingletonInstanceLoaded = NexusReplication:GetResource("NexusInstance.Event.NexusEventCreator"):CreateEvent()
NexusReplication.LoadingSingletonInstances = {}
NexusReplication.SingletonInstances = {}
NexusReplication.ReplicationLoadStarted = false



--Set up the replication.
local NexusReplicationEvents
if RunService:IsServer() and not ReplicatedStorage:FindFirstChild("NexusReplicationEvents") then
    NexusReplicationEvents = Instance.new("Folder")
    NexusReplicationEvents.Name = "NexusReplicationEvents"
    NexusReplicationEvents.Parent = ReplicatedStorage

    local ObjectCreated = Instance.new("RemoteEvent")
    ObjectCreated.Name = "ObjectCreated"
    ObjectCreated.Parent = NexusReplicationEvents

    local SendSignal = Instance.new("RemoteEvent")
    SendSignal.Name = "SendSignal"
    SendSignal.Parent = NexusReplicationEvents

    local GetObjects = Instance.new("RemoteFunction")
    GetObjects.Name = "GetObjects"
    GetObjects.Parent = NexusReplicationEvents

    local GetServerTime = Instance.new("RemoteFunction")
    GetServerTime.Name = "GetServerTime"
    GetServerTime.Parent = NexusReplicationEvents

    function GetServerTime.OnServerInvoke()
        return tick()
    end
else
    NexusReplicationEvents = ReplicatedStorage:WaitForChild("NexusReplicationEvents")
end
NexusReplication:SetResource("NexusReplicationEvents",NexusReplicationEvents)
NexusReplication:SetResource("NexusReplicationEvents.ObjectCreated",NexusReplicationEvents:WaitForChild("ObjectCreated"))
NexusReplication:SetResource("NexusReplicationEvents.SendSignal",NexusReplicationEvents:WaitForChild("SendSignal"))
NexusReplication:SetResource("NexusReplicationEvents.GetObjects",NexusReplicationEvents:WaitForChild("GetObjects"))
NexusReplication:SetResource("NexusReplicationEvents.GetServerTime",NexusReplicationEvents:WaitForChild("GetServerTime"))



--[[
Returns if the system is on the server.
--]]
function NexusReplication:IsServer()
    return RunService:IsServer()
end

--[[
Returns a static instance of a class.
Intended for objects that can only have
1 instance.
--]]
function NexusReplication:GetInstance(Path)
    --Wait for the instance to load if it is loading.
    while NexusReplication.LoadingSingletonInstances[Path] do
        NexusReplication.SingletonInstanceLoaded:Wait()
    end

    --Create the singleton instance if non exists.
    if not NexusReplication.SingletonInstances[Path] then
        NexusReplication.LoadingSingletonInstances[Path] = true
        NexusReplication.SingletonInstances[Path] = NexusReplication:GetResource(Path).new()
        NexusReplication.SingletonInstanceLoaded:Fire()
        NexusReplication.LoadingSingletonInstances[Path] = nil
    end

    --Return the singleton instance.
    return NexusReplication.SingletonInstances[Path]
end

--[[
Clears the static instances. Only
intended for use at the end of tests.
--]]
function NexusReplication:ClearInstances()
    for _,Ins in pairs(NexusReplication.SingletonInstances) do
        if Ins.Destroy then
            Ins:Destroy()
        end
    end
    NexusReplication.SingletonInstances = {}
    NexusReplicationEvents:Destroy()
end

--[[
Returns the static object replicator.
--]]
function NexusReplication:GetObjectReplicator()
    if self:IsServer() then
        return self:GetInstance("Server.ServerObjectReplication")
    else
        local Replication = self:GetInstance("Client.ClientObjectReplication")
        if not NexusReplication.ReplicationLoadStarted then
            NexusReplication.ReplicationLoadStarted = true
            Replication:LoadServerObjects()
        end
        return self:GetInstance("Client.ClientObjectReplication")
    end
end



return NexusReplication