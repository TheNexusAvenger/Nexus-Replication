--[[
TheNexusAvenger

Replicates objects on the server.
--]]

local NexusReplication = require(script.Parent.Parent)

local ObjectCreated = NexusReplication:GetResource("NexusReplicationEvents.ObjectCreated")
local SendSignal = NexusReplication:GetResource("NexusReplicationEvents.SendSignal")
local GetObjects = NexusReplication:GetResource("NexusReplicationEvents.GetObjects")
local ObjectReplication = NexusReplication:GetResource("Common.ObjectReplication")

local ServerObjectReplication = ObjectReplication:Extend()
ServerObjectReplication:SetClassName("ServerObjectReplication")



--[[
Creates the object replicator.
--]]
function ServerObjectReplication:__new()
    ObjectReplication.__new(self)

    --Set up fetching all the objects.
    function GetObjects.OnServerInvoke()
        local Objects = {}
        for _,Object in pairs(self.ObjectRegistry) do
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
function ServerObjectReplication:CreateObject(Type,Id)
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
function ServerObjectReplication:SendSignal(Object,Name,...)
    SendSignal:FireAllClients(Object.Id,Name,...)
end

--[[
Returns the global replicated container.
--]]
function ServerObjectReplication:GetGlobalContainer()
    --Create the container if it doesn't exist.
    if not self.ObjectRegistry[0] and not self.DisposeObjectRegistry[0] then
        local Object = self:CreateObject("ReplicatedContainer",0)
        Object.Name = "GlobalReplicatedContainer"
    end

    --Return the container.
    return self:GetObject(0)
end



return ServerObjectReplication