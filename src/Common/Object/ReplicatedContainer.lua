--[[
TheNexusAvenger

Base class for an object that is replicated.
--]]

local NexusReplication = require(script.Parent.Parent.Parent)

local NexusInstance = NexusReplication:GetResource("NexusInstance.NexusInstance")
local NexusEventCreator = NexusReplication:GetResource("NexusInstance.Event.NexusEventCreator")
local ObjectReplication = NexusReplication:GetObjectReplicator()

local ReplicatedContainer = NexusInstance:Extend()
ReplicatedContainer:SetClassName("ReplicatedContainer")
ReplicatedContainer.SerializationMethods = {
    Raw = function(PropertyValue)
        return PropertyValue
    end,
    ObjectReference = function(PropertyValue)
        --Return the id if the object exists and isn't disposed.
        return PropertyValue and ObjectReplication.ObjectRegistry[PropertyValue.Id] and PropertyValue.Id
    end,
    ObjectTableReference = function(PropertyValue)
        local Ids = {}
        --Return the id if the object exists and isn't disposed.
        for _,Object in pairs(PropertyValue or {}) do
            if ObjectReplication.ObjectRegistry[Object.Id] then
                table.insert(Ids,Object.Id)
            end
        end
        return Ids
    end,
}
ReplicatedContainer.DeserializationMethods = {
    Raw = function(PropertyValue)
        return PropertyValue
    end,
    ObjectReference = function(PropertyValue)
        return PropertyValue and ObjectReplication:GetObject(PropertyValue)
    end,
    ObjectTableReference = function(PropertyValue)
        local Objects = {}
        for _,Id in pairs(PropertyValue) do
            table.insert(Objects,ObjectReplication:GetObject(Id))
        end
        return Objects
    end,
}
ObjectReplication:RegisterType("ReplicatedContainer",ReplicatedContainer)



--[[
Creates the container.
--]]
function ReplicatedContainer:__new()
    self:InitializeSuper()

    --Create the properties.
    self.SerializedProperties = {}
    self.SignalListeners = {}
    self.Children = {}
    self.Parent = nil
    self.LastParent = nil
    self.Name = self.ClassName
    self:AddToSerialization("Children","ObjectTableReference")
    self:AddToSerialization("Parent","ObjectReference")
    self:AddToSerialization("Name")

    --Connect parent changes.
    self:AddPropertyFinalizer("Parent",function(_,Parent)
        --Invoke the child being removed.
        if self.LastParent then
            self.LastParent:UnregisterChild(self.object)
        end
        self.LastParent = Parent

        --Invoke the child being added.
        if self.Parent then
            self.Parent:RegisterChild(self.object)
        end
    end)

    --Create the events.
    self.ChildAdded = NexusEventCreator:CreateEvent()
    self.ChildRemoved = NexusEventCreator:CreateEvent()

    --Connect destroying the object.
    if not NexusReplication:IsServer() then
        self:ListenToSignal("Destroy",function()
            self:Destroy()
        end)
    end
end

--[[
Adds a FromSerializeData method to the class.
--]]
function ReplicatedContainer:AddFromSerializeData(Type)
    function self.FromSerializedData(SerializationData,Id)
        --Create the object.
        local Object = ObjectReplication:CreateObject(Type,Id)

        --Deserialize the properties.
        --Done in coroutines to prevnet overriding changes replicated between deserializing and changing from the server.
        local RemainingProperties = 0
        local PropertyLoadedEvent = NexusEventCreator:CreateEvent()
        for PropertyName,PropertyType in pairs(Object.SerializedProperties) do
            RemainingProperties = RemainingProperties + 1
            coroutine.wrap(function()
                Object[PropertyName] = self.DeserializationMethods[PropertyType](SerializationData[PropertyName])
                RemainingProperties = RemainingProperties - 1
                PropertyLoadedEvent:Fire()
            end)()
        end

        --Wait for the properties to deserialize.
        while RemainingProperties > 0 do
            PropertyLoadedEvent:Wait()
        end
        PropertyLoadedEvent:Disconnect()

        --Return the object.
        return Object
    end
end
ReplicatedContainer:AddFromSerializeData("ReplicatedContainer")

--[[
Serializes the object.
--]]
function ReplicatedContainer:Serialize()
    --Serialize the properties.
    local Properties = {}
    for PropertyName,PropertyType in pairs(self.SerializedProperties) do
        Properties[PropertyName] = self.SerializationMethods[PropertyType](self[PropertyName])
    end

    --Return the properties.
    return Properties
end

--[[
Adds a property to serialize.
--]]
function ReplicatedContainer:AddToSerialization(PropertyName,SerializeType)
    --Store the property to serialize.
    SerializeType = SerializeType or "Raw"
    self.SerializedProperties[PropertyName] = SerializeType

    --Replicate changes from the server to the client.
    if NexusReplication:IsServer() then
        self:AddPropertyFinalizer(PropertyName,function(_,NewValue)
            self:SendSignal("Changed_"..PropertyName,self.SerializationMethods[SerializeType](NewValue))
        end)
    else
        self:ListenToSignal("Changed_"..PropertyName,function(NewValue)
            self[PropertyName] = self.DeserializationMethods[SerializeType](NewValue)
        end)
    end
end

--[[
Sends a signal to the clients.
--]]
function ReplicatedContainer:SendSignal(Name,...)
    ObjectReplication:SendSignal(self,Name,...)
end

--[[
Registers a signal listener.
--]]
function ReplicatedContainer:ListenToSignal(Name,Handler)
    if not self.SignalListeners[Name] then
        self.SignalListeners[Name] = {}
    end
    table.insert(self.SignalListeners[Name],Handler)
end

--[[
Invoked when a signal is invoked.
--]]
function ReplicatedContainer:OnSignal(Name,...)
    local Handlers = self.SignalListeners[Name]
    if Handlers then
        for _,Handler in pairs(Handlers) do
            Handler(...)
        end
    end
end

--[[
Registers a child being added.
--]]
function ReplicatedContainer:RegisterChild(Child)
    --Return if the child exists.
    for _,ExistingChild in pairs(self.Children) do
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
function ReplicatedContainer:UnregisterChild(Child)
    --Get the child index and return if it doesn't exist.
    local Index
    for i,ExistingChild in pairs(self.Children) do
        if ExistingChild == Child then
            Index = i
            break
        end
    end
    if not Index then
        return
    end

    --Remove the child.
    table.remove(self.Children,Index)
    self.ChildRemoved:Fire(Child)
end

--[[
Returns the first child matching a
property value.
--]]
function ReplicatedContainer:FindFirstChildBy(PropertyName,PropertyValue)
    for _,Child in pairs(self.Children) do
        if Child[PropertyName] == PropertyValue then
            return Child
        end
    end
end

--[[
Waits for a child to exist that matches
the property.
--]]
function ReplicatedContainer:WaitForChildBy(PropertyName,PropertyValue)
    local Result = self:FindFirstChildBy(PropertyName,PropertyValue)
    while not Result do
        Result = self:FindFirstChildBy(PropertyName,PropertyValue)
        wait()
    end
    return Result
end

--[[
Returns the children of the object.
--]]
function ReplicatedContainer:GetChildren()
    local Children = {}
    for _,Child in pairs(self.Children) do
        table.insert(Children,Child)
    end
    return Children
end

--[[
Disposes of the object.
--]]
function ReplicatedContainer:Dispose()
    --Unparent the object.
    self.Parent = nil

    --Disconnect the events.
    self.ChildAdded:Disconnect()
    self.ChildRemoved:Disconnect()

    --Destroy the children.
    for _,Child in pairs(self:GetChildren()) do
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
    self.object:Dispose()

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



return ReplicatedContainer