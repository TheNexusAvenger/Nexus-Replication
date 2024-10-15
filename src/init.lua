--Initializes Nexus Replication.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TypedEvent = require(script:WaitForChild("NexusInstance"):WaitForChild("Event"):WaitForChild("TypedEvent"))

local NexusReplication = {}
NexusReplication.SingletonInstanceLoaded = TypedEvent.new()
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
else
    NexusReplicationEvents = ReplicatedStorage:WaitForChild("NexusReplicationEvents")
end


--[[
Returns if the system is on the server.
--]]
function NexusReplication:IsServer(): boolean
    return RunService:IsServer()
end

--[[
Returns a static instance of a class.
Intended for objects that can only have
1 instance.
--]]
function NexusReplication:GetInstance(Path: string): any
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
Returns a resource for a path.
Legacy from Nexus Project.
--]]
function NexusReplication:GetResource(Path: string): any
    local ModuleScript = script
    for _, PathPart in string.split(Path, ".") do
        ModuleScript = (ModuleScript :: any)[PathPart]
    end
    return require(ModuleScript :: ModuleScript) :: any
end

--[[
Clears the static instances. Only
intended for use at the end of tests.
--]]
function NexusReplication:ClearInstances(): ()
    for _, Ins in NexusReplication.SingletonInstances :: {any} do
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
function NexusReplication:GetObjectReplicator(): any
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

--[[
Registers a class for a type.
--]]
function NexusReplication:RegisterType(Type: string, Class: any): ()
    self:GetObjectReplicator():RegisterType(Type, Class)
end

--[[
Returns the object for an id.
Yields if the id doesn't exist.
--]]
function NexusReplication:GetObject(Id: number): any
    return self:GetObjectReplicator():GetObject(Id)
end

--[[
Returns the global replicated container.
--]]
function NexusReplication:GetGlobalContainer(): any
    return self:GetObjectReplicator():GetGlobalContainer()
end

--[[
Returns the current server time.
--]]
function NexusReplication:GetServerTime(): number
    return self:GetObjectReplicator():GetServerTime()
end

--[[
Creates an object of a given type.
Yields if the constructor doesn't exist.
--]]
function NexusReplication:CreateObject(Type: string, Id: number?): any
    return self:GetObjectReplicator():CreateObject(Type, Id)
end

--[[
Loads the Nexus Admin debug commands.
--]]
function NexusReplication:LoadNexusAdminDebugCommands(): ()
    require(script:WaitForChild("NexusAdmin"):WaitForChild("DumpObjectsCommand"))()
end



return NexusReplication
