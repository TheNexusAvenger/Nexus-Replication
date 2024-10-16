--Initializes Nexus Replication.
--!strict

local NexusInstance = require(script:WaitForChild("NexusInstance"))
local ObjectReplication = require(script:WaitForChild("Common"):WaitForChild("ObjectReplication"))
local ReplicatedContainer = require(script:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedContainer"))
local ReplicatedTable = require(script:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedTable"))
local Timer = require(script:WaitForChild("Example"):WaitForChild("Timer"))

local NexusReplication = {}
NexusReplication.ReplicatedContainer = ReplicatedContainer
NexusReplication.ReplicatedTable = ReplicatedTable
NexusReplication.Timer = Timer
NexusReplication.ToInstance = NexusInstance.ToInstance

export type TypedEvent<T...> = NexusInstance.TypedEvent<T...>
export type NexusInstanceClass<TClass, TConstructor> = NexusInstance.NexusInstanceClass<TClass, TConstructor>
export type NexusInstance<TObject> = NexusInstance.NexusInstance<TObject>

export type NexusInstanceReplicatedContainer = ReplicatedContainer.NexusInstanceReplicatedContainer
export type NexusInstanceReplicatedTable<T> = ReplicatedTable.NexusInstanceReplicatedTable<T>
export type NexusInstanceTimer = Timer.NexusInstanceTimer



--[[
Returns the static object replicator.
--]]
function NexusReplication:GetObjectReplicator(): any
    return ObjectReplication.GetInstance()
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
