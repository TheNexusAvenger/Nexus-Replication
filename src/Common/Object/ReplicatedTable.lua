--Table that is replicated with additions and deletions.
--Does not work well with ReplicatedContainer objects.
--!strict

local NexusReplication = require(script.Parent.Parent.Parent)

local NexusInstance = require(script.Parent.Parent.Parent:WaitForChild("NexusInstance"))
local ReplicatedContainer = require(script.Parent.Parent.Parent:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedContainer"))

local ReplicatedTable = {}
ReplicatedTable.__index = ReplicatedTable
setmetatable(ReplicatedTable, ReplicatedContainer)

export type ReplicatedTable<T> = {
    Table: {[any]: T},
    ItemAdded: NexusInstance.TypedEvent<T>,
    ItemRemoved: NexusInstance.TypedEvent<T>,
    ItemChanged: NexusInstance.TypedEvent<T>,
} & typeof(setmetatable({}, ReplicatedTable)) & ReplicatedContainer.ReplicatedContainer
export type NexusInstanceReplicatedTable<T> = NexusInstance.NexusInstance<ReplicatedTable<T>>



--[[
Creates the replicated table.
--]]
function ReplicatedTable.__new<T>(self: NexusInstanceReplicatedTable<T>): ()
    ReplicatedContainer.__new(self :: any)
    self.Name = "ReplicatedTable"

    --Set up the state.
    self.Table = {}
    self:AddToSerialization("Table")

    --Create the events.
    self.ItemAdded = self:CreateEvent() :: NexusInstance.TypedEvent<T>
    self.ItemRemoved = self:CreateEvent() :: NexusInstance.TypedEvent<T>
    self.ItemChanged = self:CreateEvent() :: NexusInstance.TypedEvent<T>

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
function ReplicatedTable.Add<T>(self: NexusInstanceReplicatedTable<T>, Value: T, Index: any): ()
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
function ReplicatedTable.RemoveAt<T>(self: NexusInstanceReplicatedTable<T>, Index: number): ()
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
function ReplicatedTable.Remove<T>(self: NexusInstanceReplicatedTable<T>, Value: T): ()
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
function ReplicatedTable.Set<T>(self: NexusInstanceReplicatedTable<T>, Index: any, Value: T): ()
    self.Table[Index] = Value
    self.ItemChanged:Fire(Index)
    if NexusReplication:IsServer() then
        self:SendSignal("Set",self.Table,Index)
    end
end

--[[
Returns the value at a given index.
--]]
function ReplicatedTable.Get<T>(self: NexusInstanceReplicatedTable<T>, Index: any): T
    return self.Table[Index]
end

--[[
Returns all the values that pass a given function.
If no function is given, all values are returned.
--]]
function ReplicatedTable.GetAll<T>(self: NexusInstanceReplicatedTable<T>, ConditionFunction: (T) -> (boolean)?): {T}
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
function ReplicatedTable.Find<T>(self: NexusInstanceReplicatedTable<T>, Value: T): any
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
function ReplicatedTable.Contains<T>(self: NexusInstanceReplicatedTable<T>, Value: T): boolean
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
function ReplicatedTable.Dispose<T>(self: NexusInstanceReplicatedTable<T>): ()
    ReplicatedContainer.Dispose(self :: any)

    --Clear the table.
    self.Table = {}
end



return NexusInstance.ToInstance(ReplicatedTable) :: NexusInstance.NexusInstanceClass<typeof(ReplicatedTable), <T>() -> (ReplicatedTable<T>)>
