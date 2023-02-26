--[[
TheNexusAvenger

Table that is replicated with additions and deletions.
Does not work well ReplicatedContainer objects.
--]]
--!strict

local NexusReplication = require(script.Parent.Parent.Parent)

local Types = require(script.Parent.Parent.Parent:WaitForChild("Types"))
local NexusEvent = require(script.Parent.Parent.Parent:WaitForChild("NexusInstance"):WaitForChild("Event"):WaitForChild("NexusEvent"))
local ReplicatedContainer = require(script.Parent.Parent.Parent:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedContainer"))

local ReplicatedTable = ReplicatedContainer:Extend()
ReplicatedTable:SetClassName("ReplicatedTable")
NexusReplication:RegisterType("ReplicatedTable",ReplicatedTable)

export type ReplicatedTable<T> = {
    new: () -> (ReplicatedTable<T>),
    Extend: (self: ReplicatedTable<T>) -> (ReplicatedTable<T>),
    
    ItemAdded: NexusEvent.NexusEvent<T>,
    ItemRemoved: NexusEvent.NexusEvent<T>,
    ItemChanged: NexusEvent.NexusEvent<T>,
    Add: <T>(Value: T, Index: any) -> (),
    RemoveAt: (Index: number) -> (),
    Remove: <T>(Value: T) -> (),
    Set: <T>(Index: any, Value: T) -> (),
    Get: <T>(Index: any) -> (T),
    GetAll: <T>(ConditionFunction: (T) -> (boolean)?) -> ({T}),
    Find: <T>(Value: T) -> (any),
    Contains: <T>(Value: T) -> (boolean),
} & Types.ReplicatedContainer



--[[
Creates the replicated table.
--]]
function ReplicatedTable:__new(): ()
    ReplicatedContainer.__new(self)
    self.Name = "ReplicatedTable"

    --Set up the state.
    self.Table = {}
    self:AddToSerialization("Table")

    --Create the events.
    self.ItemAdded = NexusEvent.new()
    self.ItemRemoved = NexusEvent.new()
    self.ItemChanged = NexusEvent.new()

    --Connect the replication.
    if not NexusReplication:IsServer() then
        self:ListenToSignal("Add", function(NewTable: {any}, Value: any): ()
            self.Table = NewTable
            self.ItemAdded:Fire(Value)
        end)
        self:ListenToSignal("RemoveAt", function(NewTable: {any}, Value: any): ()
            self.Table = NewTable
            self.ItemRemoved:Fire(Value)
        end)
        self:ListenToSignal("Set", function(NewTable: {any}, Index: any): ()
            self.Table = NewTable
            self.ItemChanged:Fire(Index)
        end)
    end
end

--[[
Adds an item to the table.
--]]
function ReplicatedTable:Add<T>(Value: T, Index: any): ()
    if Index then
        table.insert(self.Table, Index, Value)
    else
        table.insert(self.Table, Value)
    end
    self.ItemAdded:Fire(Value)
    if NexusReplication:IsServer() then
        self:SendSignal("Add", self.Table, Value, Index)
    end
end

--[[
Removes an item from the table at the given index.
--]]
function ReplicatedTable:RemoveAt(Index: number): ()
    local Value = self.Table[Index]
    table.remove(self.Table,Index)
    self.ItemRemoved:Fire(Value)
    if NexusReplication:IsServer() then
        self:SendSignal("RemoveAt",self.Table,Value)
    end
end

--[[
Removes an item from the table.
--]]
function ReplicatedTable:Remove<T>(Value: T): ()
    for i, Object in self.Table do
        if Object == Value then
            self:RemoveAt(i)
            return
        end
    end
end

--[[
Sets the value at a given index.
--]]
function ReplicatedTable:Set<T>(Index: any, Value: T): ()
    self.Table[Index] = Value
    self.ItemChanged:Fire(Index)
    if NexusReplication:IsServer() then
        self:SendSignal("Set",self.Table,Index)
    end
end

--[[
Returns the value at a given index.
--]]
function ReplicatedTable:Get<T>(Index: any): T
    return self.Table[Index]
end

--[[
Returns all the values that pass a given function.
If no function is given, all values are returned.
--]]
function ReplicatedTable:GetAll<T>(ConditionFunction: (T) -> (boolean)?): {T}
    local Values = {}
    for _, Value in self.Table do
        if not ConditionFunction or ConditionFunction(Value) then
            table.insert(Values, Value)
        end
    end
    return Values
end

--[[
Returns the index at a given value.
--]]
function ReplicatedTable:Find<T>(Value: T): any
    for i, OtherValue in self.Table do
        if Value == OtherValue then
            return i
        end
    end
    return nil
end

--[[
Returns if the table contains the given value.
--]]
function ReplicatedTable:Contains<T>(Value: T): boolean
    for _, OtherValue in self.Table do
        if Value == OtherValue then
            return true
        end
    end
    return false
end

--[[
Disposes of the object.
--]]
function ReplicatedTable:Dispose(): ()
    ReplicatedContainer.Dispose(self)

    --Clear the table.
    self.Table = {}

    --Disconnect the events.
    self.ItemAdded:Disconnect()
    self.ItemRemoved:Disconnect()
    self.ItemChanged:Disconnect()
end



return (ReplicatedTable :: any) :: ReplicatedTable<any>