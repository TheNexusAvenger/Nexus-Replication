--Initializes Nexus Replication.
--!strict

local RunService = game:GetService("RunService")

local NexusReplication = {}



--[[
Returns if the system is on the server.
--]]
function NexusReplication:IsServer(): boolean
    return RunService:IsServer()
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
Returns the static object replicator.
--]]
function NexusReplication:GetObjectReplicator(): any
    return require(script:WaitForChild("Common"):WaitForChild("ObjectReplication")).GetInstance()
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
