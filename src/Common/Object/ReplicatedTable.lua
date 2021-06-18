--[[
TheNexusAvenger

Table that is replicated with additions and deletions.
Does not work well ReplicatedContainer objects.
--]]

local NexusReplication = require(script.Parent.Parent.Parent)

local NexusEventCreator = NexusReplication:GetResource("NexusInstance.Event.NexusEventCreator")

local ReplicatedTable = NexusReplication:GetResource("Common.Object.ReplicatedContainer"):Extend()
ReplicatedTable:SetClassName("ReplicatedTable")
NexusReplication:GetObjectReplicator():RegisterType("ReplicatedTable",ReplicatedTable)



--[[
Creates the replicated table.
--]]
function ReplicatedTable:__new()
    self:InitializeSuper()
    self.Name = "ReplicatedTable"

    --Set up the state.
    self.Table = {}
    self:AddToSerialization("Table")

    --Create the events.
    self.ItemAdded = NexusEventCreator:CreateEvent()
    self.ItemRemoved = NexusEventCreator:CreateEvent()
    self.ItemChanged = NexusEventCreator:CreateEvent()

    --Connect the replication.
    if not NexusReplication:IsServer() then
        self:ListenToSignal("Add",function(NewTable,Value)
            self.Table = NewTable
            self.ItemAdded:Fire(Value)
        end)
        self:ListenToSignal("RemoveAt",function(NewTable,Value)
            self.Table = NewTable
            self.ItemRemoved:Fire(Value)
        end)
        self:ListenToSignal("Set",function(NewTable,Index)
            self.Table = NewTable
            self.ItemChanged:Fire(Index)
        end)
    end
end

--[[
Adds an item to the table.
--]]
function ReplicatedTable:Add(Value,Index)
    if Index then
        table.insert(self.Table,Index,Value)
    else
        table.insert(self.Table,Value)
    end
    self.ItemAdded:Fire(Value)
    if NexusReplication:IsServer() then
        self:SendSignal("Add",self.Table,Value,Index)
    end
end

--[[
Removes an item from the table at the given index.
--]]
function ReplicatedTable:RemoveAt(Index)
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
function ReplicatedTable:Remove(Value)
    for i,Object in pairs(self.Table) do
        if Object == Value then
            self:RemoveAt(i)
            return
        end
    end
end

--[[
Sets the value at a given index.
--]]
function ReplicatedTable:Set(Index,Value)
    self.Table[Index] = Value
    self.ItemChanged:Fire(Index)
    if NexusReplication:IsServer() then
        self:SendSignal("Set",self.Table,Index)
    end
end

--[[
Returns the value at a given index.
--]]
function ReplicatedTable:Get(Index)
    return self.Table[Index]
end

--[[
Returns all the values that pass a given function.
If no function is given, all values are returned.
--]]
function ReplicatedTable:GetAll(ConditionFunction)
    local Values = {}
    for _,Value in pairs(self.Table) do
        if not ConditionFunction or ConditionFunction(Value) then
            table.insert(Values,Value)
        end
    end
    return Values
end

--[[
Returns the index at a given value.
--]]
function ReplicatedTable:Find(Value)
    for i,OtherValue in pairs(self.Table) do
        if Value == OtherValue then
            return i
        end
    end
end

--[[
Returns if the table contains the given value.
--]]
function ReplicatedTable:Contains(Value)
    for _,OtherValue in pairs(self.Table) do
        if Value == OtherValue then
            return true
        end
    end
    return false
end

--[[
Disposes of the object.
--]]
function ReplicatedTable:Dispose()
    self.super:Dispose()

    --Clear the table.
    self.Table = {}

    --Disconnect the events.
    self.ItemAdded:Disconnect()
    self.ItemRemoved:Disconnect()
    self.ItemChanged:Disconnect()
end



return ReplicatedTable