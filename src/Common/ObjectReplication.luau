--Base for replicating objects.
--!strict

local TYPE_TO_PATH = {
    ReplicatedContainer = "Common.Object.ReplicatedContainer",
    ReplicatedTable = "Common.Object.ReplicatedTable",
    Timer = "Example.Timer",
}



local Workspace = game:GetService("Workspace")

local NexusReplication = require(script.Parent.Parent)
local NexusInstance = require(script.Parent.Parent:WaitForChild("NexusInstance"))

local ObjectReplication = {}
ObjectReplication.__index = ObjectReplication

export type StubbedReplicatedContainer = {
    Type: string,
    Id: number,
    Serialize: (self: StubbedReplicatedContainer) -> (any),
    [any]: any,
}
export type ObjectReplication = {
    CurrentId: number,
    IdIncrementer: number,
    TypeClasses: {[string]: any},
    ObjectRegistry: {[number]: StubbedReplicatedContainer},
    DisposeObjectRegistry: {[number]: StubbedReplicatedContainer},
} & typeof(setmetatable({}, ObjectReplication))
export type NexusInstanceObjectReplication = NexusInstance.NexusInstance<ObjectReplication>



--[[
Creates the replicator.
--]]
function ObjectReplication:__new(): ()
    self.CurrentId = 1
    self.IdIncrementer = 1
    self.TypeClasses = {}
    self.ObjectRegistry = {}
    self.DisposeObjectRegistry = {}
    setmetatable(self.DisposeObjectRegistry, {__mode="v"})
end

--[[
Registers a class for a type.
--]]
function ObjectReplication.RegisterType(self: NexusInstanceObjectReplication, Type: string, Class: any): ()
    if Class.AddFromSerializeData then
        Class:AddFromSerializeData(Type)
    end
    self.TypeClasses[Type] = Class
end

--[[
Returns the class for the given type.
--]]
function ObjectReplication.GetClass(self: NexusInstanceObjectReplication, Type: string): any
    --Load the type.
    if not self.TypeClasses[Type] then
        local Path = TYPE_TO_PATH[Type]
        if Path then
            NexusReplication:GetResource(Path)
        end
    end

    --Wait for the type to exist.
    while not self.TypeClasses[Type] do
        task.wait()
    end

    --Return the class.
    return self.TypeClasses[Type]
end

--[[
Creates an object of a given type.
Yields if the constructor doesn't exist.
--]]
function ObjectReplication.CreateObject(self: NexusInstanceObjectReplication, Type: string, Id: number?): any
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
    self.ObjectRegistry[Id :: number] = Object
    return Object
end

--[[
Returns the object for an id.
Yields if the id doesn't exist.
--]]
function ObjectReplication.GetObject(self: NexusInstanceObjectReplication, Id: number): any
    --Wait for the id to exist.
    while not self.ObjectRegistry[Id] and not self.DisposeObjectRegistry[Id] do
        task.wait()
    end

    --Create and store the object.
    return self.ObjectRegistry[Id] or self.DisposeObjectRegistry[Id]
end

--[[
Disposes of a given object id.
--]]
function ObjectReplication.DisposeObject(self: NexusInstanceObjectReplication, Id: number): ()
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
function ObjectReplication.SendSignal(self: NexusInstanceObjectReplication, Object: any, Name: string, ...: any): ()
    error("Not implemented in the given context.")
end

--[[
Returns the global replicated container.
--]]
function ObjectReplication.GetGlobalContainer(self: NexusInstanceObjectReplication): any
    error("Not implemented in the given context.")
end

--[[
Returns the current server time.
--]]
function ObjectReplication.GetServerTime(self: NexusInstanceObjectReplication): number
    return Workspace:GetServerTimeNow()
end



return NexusInstance.ToInstance(ObjectReplication) :: NexusInstance.NexusInstanceClass<typeof(ObjectReplication), () -> (NexusInstanceObjectReplication)>