--[[
TheNexusAvenger

Base for replicating objects.
--]]
--!strict

local TYPE_TO_PATH = {
    ReplicatedContainer = "Common.Object.ReplicatedContainer",
    ReplicatedTable = "Common.Object.ReplicatedTable",
    Timer = "Example.Timer",
}



local Workspace = game:GetService("Workspace")

local NexusReplication = require(script.Parent.Parent)
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local NexusInstance = require(script.Parent.Parent:WaitForChild("NexusInstance"):WaitForChild("NexusInstance"))

local ObjectReplication = NexusInstance:Extend()
ObjectReplication:SetClassName("ObjectReplication")

export type ObjectReplication = Types.ObjectReplication



--[[
Creates the replicator.
--]]
function ObjectReplication:__new(): ()
    NexusInstance.__new(self)

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
function ObjectReplication:RegisterType(Type: string, Class: Types.ReplicatedContainer): ()
    if Class.AddFromSerializeData then
        Class:AddFromSerializeData(Type)
    end
    self.TypeClasses[Type] = Class
end

--[[
Returns the class for the given type.
--]]
function ObjectReplication:GetClass(Type: string): Types.ReplicatedContainer
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
function ObjectReplication:CreateObject(Type: string, Id: number?): Types.ReplicatedContainer
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
        self.CurrentId += self.IdIncrementer
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
function ObjectReplication:GetObject(Id: number): Types.ReplicatedContainer
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
function ObjectReplication:DisposeObject(Id: number): ()
    if not Id or not self.ObjectRegistry[Id] then return end

    --Move the object to a weak table.
    --This allows getting the object by id if it destroyed
    --but still in use (and isn't garbage collected).
    self.DisposeObjectRegistry[Id] = self.ObjectRegistry[Id]
    self.ObjectRegistry[Id] = nil
end

--[[
Sends a signal for an object.
--]]
function ObjectReplication:SendSignal(Object: Types.ReplicatedContainer, Name: string, ...: any): ()
    error("Not implemented in the given context.")
end

--[[
Returns the global replicated container.
--]]
function ObjectReplication:GetGlobalContainer(): Types.ReplicatedContainer
    error("Not implemented in the given context.")
end

--[[
Returns the current server time.
--]]
function ObjectReplication:GetServerTime(): number
    return Workspace:GetServerTimeNow()
end



return (ObjectReplication :: any) :: ObjectReplication