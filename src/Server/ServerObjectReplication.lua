--[[
TheNexusAvenger

Replicates objects on the server.
--]]
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local ObjectReplication = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("ObjectReplication"))

local NexusReplicationEvents = ReplicatedStorage:WaitForChild("NexusReplicationEvents")
local ObjectCreated = NexusReplicationEvents:WaitForChild("ObjectCreated")
local SendSignal = NexusReplicationEvents:WaitForChild("SendSignal")
local GetObjects = NexusReplicationEvents:WaitForChild("GetObjects")

local ServerObjectReplication = ObjectReplication:Extend()
ServerObjectReplication:SetClassName("ServerObjectReplication")

export type ServerObjectReplication = {
    new: () -> (ServerObjectReplication),
    Extend: (self: ServerObjectReplication) -> (ServerObjectReplication),
} & Types.ObjectReplication



--[[
Creates the object replicator.
--]]
function ServerObjectReplication:__new(): ()
    ObjectReplication.__new(self)

    --Set up fetching all the objects.
    function GetObjects.OnServerInvoke()
        local Objects = {}
        for _,Object in self.ObjectRegistry do
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
function ServerObjectReplication:CreateObject(Type: string, Id: number?): Types.ReplicatedContainer
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
function ServerObjectReplication:SendSignal(Object: Types.ReplicatedContainer, Name: string, ...: any): ()
    SendSignal:FireAllClients(Object.Id, Name, ...)
end

--[[
Returns the global replicated container.
--]]
function ServerObjectReplication:GetGlobalContainer(): Types.ReplicatedContainer
    --Create the container if it doesn't exist.
    if not (self :: any).ObjectRegistry[0] and not (self :: any).DisposeObjectRegistry[0] then
        local Object = self:CreateObject("ReplicatedContainer",0)
        Object.Name = "GlobalReplicatedContainer"
    end

    --Return the container.
    return self:GetObject(0)
end



return (ServerObjectReplication :: any) :: ServerObjectReplication