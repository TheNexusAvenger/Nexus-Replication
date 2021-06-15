--[[
TheNexusAvenger

Base for replicating objects.
--]]

local TYPE_TO_PATH = {
    ReplicatedContainer = "Common.Object.ReplicatedContainer",
    ReplicatedTable = "Common.Object.ReplicatedTable",
    Timer = "Example.Timer",
}



local NexusReplication = require(script.Parent.Parent)

local ObjectReplication = NexusReplication:GetResource("NexusInstance.NexusInstance"):Extend()
ObjectReplication:SetClassName("ObjectReplication")



--[[
Creates the replicator.
--]]
function ObjectReplication:__new()
    self:InitializeSuper()

    self.CurrentId = 1
    self.IdIncrementer = 1
    self.TypeClasses = {}
    self.ObjectRegistry = {}
    self.DisposeObjectRegistry = {}
    setmetatable(self.DisposeObjectRegistry,{__mode="v"})
end

--[[
Registers a class for a type.
--]]
function ObjectReplication:RegisterType(Type,Class)
    self.TypeClasses[Type] = Class
end

--[[
Returns the class for the given type.
--]]
function ObjectReplication:GetClass(Type)
    --Load the type.
    if not self.TypeClasses[Type] then
        local Path = TYPE_TO_PATH[Type]
        if Path then
            NexusReplication:GetResource(Path)
        end
    end

    --Wait for the type to exist.
    while not self.TypeClasses[Type] do
        wait()
    end

    --Return the class.
    return self.TypeClasses[Type]
end

--[[
Creates an object of a given type.
Yields if the constructor doesn't exist.
--]]
function ObjectReplication:CreateObject(Type,Id)
    --Create the object.
    --Must be done before picking an id in case the constructor creates objects.
    local Class = self:GetClass(Type)
    local Object = Class.new()

    --Increment the id until an unused one is found.
    if not Id then
        while self.ObjectRegistry[self.CurrentId] do
            self.CurrentId = self.CurrentId + self.IdIncrementer
        end
        Id = self.CurrentId
    end

    --Store the object.
    Object.Id = Id
    Object.Type = Type
    self.ObjectRegistry[Id] = Object
    return Object
end

--[[
Returns the object for an id.
Yields if the id doesn't exist.
--]]
function ObjectReplication:GetObject(Id)
    --Wait for the id to exist.
    while not self.ObjectRegistry[Id] and not self.DisposeObjectRegistry[Id] do
        wait()
    end

    --Create and store the object.
    return self.ObjectRegistry[Id] or self.DisposeObjectRegistry[Id]
end

--[[
Disposes of a given object id.
--]]
function ObjectReplication:DisposeObject(Id)
    --Move the object to a weak table.
    --This allows getting the object by id if it destroyed
    --but still in use (and isn't garbage collected).
    self.DisposeObjectRegistry[Id] = self.ObjectRegistry[Id]
    self.ObjectRegistry[Id] = nil
end

--[[
Sends a signal for an object.
--]]
function ObjectReplication:SendSignal(Object,Name,...)
    error("Not implemented in the given context.")
end

--[[
Returns the global replicated container.
--]]
function ObjectReplication:GetGlobalContainer()
    error("Not implemented in the given context.")
end

--[[
Returns the current server time.
--]]
function ObjectReplication:GetServerTime()
    return tick()
end



return ObjectReplication