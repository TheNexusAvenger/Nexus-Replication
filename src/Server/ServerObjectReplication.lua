--Replicates objects on the server.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectReplication = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("ObjectReplication"))
local NexusInstance = require(script.Parent.Parent:WaitForChild("NexusInstance"))

local NexusReplicationEvents = ReplicatedStorage:WaitForChild("NexusReplicationEvents")
local ObjectCreated = NexusReplicationEvents:WaitForChild("ObjectCreated")
local SendSignal = NexusReplicationEvents:WaitForChild("SendSignal")
local GetObjects = NexusReplicationEvents:WaitForChild("GetObjects")

local ServerObjectReplication = {}
ServerObjectReplication.__index = ServerObjectReplication
setmetatable(ServerObjectReplication, ObjectReplication)

export type ServerObjectReplication = typeof(setmetatable({}, ServerObjectReplication)) & ObjectReplication.ObjectReplication
export type NexusInstanceServerObjectReplication = NexusInstance.NexusInstance<ServerObjectReplication>


--[[
Creates the object replicator.
--]]
function ServerObjectReplication.__new(self: NexusInstanceServerObjectReplication): ()
    ObjectReplication.__new(self)

    --Set up fetching all the objects.
    function GetObjects.OnServerInvoke()
        local Objects = {}
        for _, Object in self.ObjectRegistry :: {ObjectReplication.StubbedReplicatedContainer} do
            table.insert(Objects,{
                Type = Object.Type,
                Id = Object.Id,
                Object = Object:Serialize(),
            })
        end
        return Objects
    end
end

--[[
Creates an object of a given type.
Yields if the constructor doesn't exist.
--]]
function ServerObjectReplication.CreateObject(self: NexusInstanceServerObjectReplication, Type: string, Id: number?): any
    local Object = ObjectReplication.CreateObject(self, Type, Id)
    ObjectCreated:FireAllClients({
        Type = Type,
        Id = Object.Id,
        Object = Object:Serialize(),
    })
    return Object
end

--[[
Sends a signal for an object.
--]]
function ServerObjectReplication.SendSignal(self: NexusInstanceServerObjectReplication, Object: any, Name: string, ...: any): ()
    SendSignal:FireAllClients(Object.Id, Name, ...)
end

--[[
Returns the global replicated container.
--]]
function ServerObjectReplication.GetGlobalContainer(self: NexusInstanceServerObjectReplication): any
    --Create the container if it doesn't exist.
    if not (self :: any).ObjectRegistry[0] and not (self :: any).DisposeObjectRegistry[0] then
        local Object = self:CreateObject("ReplicatedContainer",0)
        Object.Name = "GlobalReplicatedContainer"
    end

    --Return the container.
    return self:GetObject(0)
end



return NexusInstance.ToInstance(ServerObjectReplication) :: NexusInstance.NexusInstanceClass<typeof(ServerObjectReplication), () -> (ServerObjectReplication)>