--[[
TheNexusAvenger

Base class for an object that is replicated.
--]]
--!strict

local NexusReplication = require(script.Parent.Parent.Parent)

local Types = require(script.Parent.Parent.Parent:WaitForChild("Types"))
local NexusInstance = require(script.Parent.Parent.Parent:WaitForChild("NexusInstance"):WaitForChild("NexusInstance"))
local NexusEvent = require(script.Parent.Parent.Parent:WaitForChild("NexusInstance"):WaitForChild("Event"):WaitForChild("NexusEvent"))
local ObjectReplication = NexusReplication:GetObjectReplicator()

local ReplicatedContainer = NexusInstance:Extend()
ReplicatedContainer:SetClassName("ReplicatedContainer")
NexusReplication:RegisterType("ReplicatedContainer", ReplicatedContainer)

export type ReplicatedContainer = Types.ReplicatedContainer



--[[
Encodes a table's ids for serialization.
--]]
local function EncodeIds(Table: any, CheckedValues: any): any
    CheckedValues = CheckedValues or {}

    --Return if the table is not a table.
    if Table == nil then return nil end
    if CheckedValues[Table] or type(Table) ~= "table" then
        CheckedValues[Table] = true
        return Table
    end
    CheckedValues[Table] = true

    --Return if the item is a replicated container.
    if Table.Id and Table.IsA and Table:IsA("ReplicatedContainer") then
        if ObjectReplication.ObjectRegistry[Table.Id] then
            return {__KeyToDecode = Table.Id}
        end
        return nil
    end

    --Encode the ids of the table.
    local NewTable = {}
    local KeysToDecode = {}
    local HasKeysToDecode = false
    table.insert(CheckedValues,KeysToDecode)
    for Key, Value in Table do
        if type(Value) == "table" and Value.Id and Value.IsA and Value:IsA("ReplicatedContainer") then
            if ObjectReplication.ObjectRegistry[Value.Id] then
                NewTable[Key] = Value.Id
                table.insert(KeysToDecode, Key)
                HasKeysToDecode = true
            end
        else
            NewTable[Key] = EncodeIds(Value, CheckedValues)
        end
    end

    --Return the table.
    return HasKeysToDecode and {__KeysToDecode = KeysToDecode, Data = NewTable} or NewTable
end
ReplicatedContainer.EncodeIds = EncodeIds

--[[
Encodes a table's ids for deserialization.
--]]
local function DecodeIds(Table: any): any
    --Return if the table is not a table.
    if type(Table) ~= "table" then
        return Table
    end

    --Return if the table is an object.
    if Table.__KeyToDecode then
        return ObjectReplication:GetObject(Table.__KeyToDecode)
    end

    --Get the list of keys.
    local NewTable = Table
    if NewTable.__KeysToDecode then
        NewTable = NewTable.Data
    end
    local Keys = {}
    for Key, _ in NewTable do
        table.insert(Keys,Key)
    end

    --Decode the keys.
    for _,Key in Keys do
        NewTable[Key] = DecodeIds(NewTable[Key])
    end
    if Table.__KeysToDecode then
        for _,Key in Table.__KeysToDecode do
            NewTable[Key] = ObjectReplication:GetObject(NewTable[Key])
        end
    end

    --Return the table.
    return NewTable
end
ReplicatedContainer.DecodeIds = DecodeIds



--[[
Creates the container.
--]]
function ReplicatedContainer:__new(): ()
    NexusInstance.__new(self)

    --Create the properties.
    self.SerializedProperties = {}
    self.SignalListeners = {}
    self.Children = {}
    self.Parent = nil
    self.LastParent = nil
    self.Name = self.ClassName
    self:AddToSerialization("Children")
    self:AddToSerialization("Parent")
    self:AddToSerialization("Name")

    --Connect parent changes.
    self:AddPropertyFinalizer("Parent", function(_, Parent: ReplicatedContainer)
        --Invoke the child being removed.
        if self.LastParent then
            self.LastParent:UnregisterChild(self)
        end
        self.LastParent = Parent

        --Invoke the child being added.
        if self.Parent then
            self.Parent:RegisterChild(self)
        end
    end)

    --Create the events.
    self.ChildAdded = NexusEvent.new()
    self.ChildRemoved = NexusEvent.new()

    --Connect destroying the object.
    if not NexusReplication:IsServer() then
        self:ListenToSignal("Destroy", function()
            self:Destroy()
        end)
    end
end

--[[
Adds a FromSerializeData method to the class.
--]]
function ReplicatedContainer:AddFromSerializeData(Type: string): ()
    function self.FromSerializedData(SerializationData: any, Id: number): ReplicatedContainer
        --Create the object.
        local Object = ObjectReplication:CreateObject(Type, Id)

        --Deserialize the properties.
        local Properties = DecodeIds(SerializationData)
        for _, PropertyName in Object.SerializedProperties do
            Object[PropertyName] = Properties[PropertyName]
        end

        --Return the object.
        return Object
    end
end
ReplicatedContainer:AddFromSerializeData("ReplicatedContainer")

--[[
Serializes the object.
--]]
function ReplicatedContainer:Serialize(): any
    --Serialize the properties.
    local Properties = {}
    for _, PropertyName in self.SerializedProperties do
        Properties[PropertyName] = self[PropertyName]
    end

    --Return the properties.
    return EncodeIds(Properties)
end

--[[
Adds a property to serialize.
--]]
function ReplicatedContainer:AddToSerialization(PropertyName: string): ()
    --Store the property to serialize.
    table.insert(self.SerializedProperties,PropertyName)

    --Replicate changes from the server to the client.
    if NexusReplication:IsServer() then
        self:AddPropertyFinalizer(PropertyName, function(_, NewValue: any)
            self:SendSignal("Changed_"..PropertyName,EncodeIds(NewValue))
        end)
    else
        self:ListenToSignal("Changed_"..PropertyName, function(NewValue: any)
            self[PropertyName] = DecodeIds(NewValue)
        end)
    end
end

--[[
Sends a signal to the clients.
--]]
function ReplicatedContainer:SendSignal(Name: string, ...: any): ()
    ObjectReplication:SendSignal(self, Name, ...)
end

--[[
Registers a signal listener.
--]]
function ReplicatedContainer:ListenToSignal(Name: string, Handler: (...any) -> ()): ()
    if not self.SignalListeners[Name] then
        self.SignalListeners[Name] = {}
    end
    table.insert(self.SignalListeners[Name], Handler)
end

--[[
Invoked when a signal is invoked.
--]]
function ReplicatedContainer:OnSignal(Name: string, ...: any): ()
    local Handlers = self.SignalListeners[Name]
    if Handlers then
        for _,Handler in Handlers do
            Handler(...)
        end
    end
end

--[[
Registers a child being added.
--]]
function ReplicatedContainer:RegisterChild(Child: ReplicatedContainer): ()
    --Return if the child exists.
    for _, ExistingChild in self.Children do
        if ExistingChild == Child then
            return
        end
    end

    --Add the child.
    table.insert(self.Children,Child)
    self.ChildAdded:Fire(Child)
end

--[[
Registers a child being removed.
--]]
function ReplicatedContainer:UnregisterChild(Child: ReplicatedContainer): ()
    --Get the child index and return if it doesn't exist.
    local Index
    for i, ExistingChild in self.Children do
        if ExistingChild == Child then
            Index = i
            break
        end
    end
    if not Index then
        return
    end

    --Remove the child.
    table.remove(self.Children, Index)
    self.ChildRemoved:Fire(Child)
end

--[[
Returns the first child matching a
property value.
--]]
function ReplicatedContainer:FindFirstChildBy(PropertyName: string, PropertyValue: any): ReplicatedContainer?
    for _, Child in self.Children do
        if Child[PropertyName] == PropertyValue then
            return Child
        end
    end
    return nil
end

--[[
Waits for a child to exist that matches
the property.
--]]
function ReplicatedContainer:WaitForChildBy(PropertyName: string, PropertyValue: any): ReplicatedContainer
    local Result = self:FindFirstChildBy(PropertyName, PropertyValue)
    while not Result do
        Result = self:FindFirstChildBy(PropertyName, PropertyValue)
        task.wait()
    end
    return Result
end

--[[
Returns the children of the object.
--]]
function ReplicatedContainer:GetChildren(): {ReplicatedContainer}
    local Children = {}
    for _, Child in self.Children do
        table.insert(Children, Child)
    end
    return Children
end

--[[
Disposes of the object.
--]]
function ReplicatedContainer:Dispose(): ()
    --Unparent the object.
    self.Parent = nil

    --Disconnect the events.
    self.ChildAdded:Disconnect()
    self.ChildRemoved:Disconnect()

    --Destroy the children.
    for _, Child in self:GetChildren() do
        Child:Destroy()
    end
end

--[[
Destroys the object.
--]]
function ReplicatedContainer:Destroy()
    --Unregister the object.
    if NexusReplication:IsServer() then
        self:SendSignal("Destroy")
    end
    ObjectReplication:DisposeObject(self.Id)

    --Clear the object.
    self:Dispose()

    --Disconnect the events.
    --Done last to ensure Parent change events are invoked.
    NexusInstance.Destroy(self)
end

--[[
Returns the object as a string.
--]]
function ReplicatedContainer:__tostring()
    return self.Name
end



return (ReplicatedContainer :: any) :: ReplicatedContainer