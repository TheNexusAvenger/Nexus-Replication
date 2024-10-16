--Base class for an object that is replicated.
--!strict

local RunService = game:GetService("RunService")

local NexusInstance = require(script.Parent.Parent.Parent:WaitForChild("NexusInstance"))

local ReplicatedContainer = {
    ObjectReplicationIntegration = nil :: {
        EncodeIds: (Value: any) -> (any),
        DecodeIds: (Value: any) -> (any),
        SendSignal: (Object: any, Name: string, ...any) -> (),
        DisposeObject: (Id: number) -> (),
    }?,
}
ReplicatedContainer.__index = ReplicatedContainer

export type ReplicatedContainer = {
    Type: string,
    Id: number,
    Name: string,
    SerializedProperties: {string},
    SignalListeners: {[string]: {(...any) -> ()}},
    Children: {NexusInstanceReplicatedContainer},
    Parent: NexusInstanceReplicatedContainer?,
    LastParent: NexusInstanceReplicatedContainer?,
    ChildAdded: NexusInstance.TypedEvent<NexusInstanceReplicatedContainer>,
    ChildRemoved: NexusInstance.TypedEvent<NexusInstanceReplicatedContainer>,
} & typeof(setmetatable({}, ReplicatedContainer))
export type NexusInstanceReplicatedContainer = NexusInstance.NexusInstance<ReplicatedContainer>



--[[
Creates the container.
--]]
function ReplicatedContainer.__new(self: NexusInstanceReplicatedContainer): ()
    --Create the properties.
    self.Name = "ReplicatedContainer"
    self.SerializedProperties = {} :: {string}
    self.SignalListeners = {} :: {[string]: {(...any) -> ()}}
    self.Children = {} :: {NexusInstanceReplicatedContainer}
    self.Parent = nil
    self.LastParent = nil
    self:AddToSerialization("Children")
    self:AddToSerialization("Parent")
    self:AddToSerialization("Name")

    --Connect parent changes.
    self:OnPropertyChanged("Parent", function(Parent: NexusInstanceReplicatedContainer)
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
    self.ChildAdded = self:CreateEvent() :: NexusInstance.TypedEvent<NexusInstanceReplicatedContainer>
    self.ChildRemoved = self:CreateEvent() :: NexusInstance.TypedEvent<NexusInstanceReplicatedContainer>

    --Connect destroying the object.
    if not RunService:IsServer() then
        self:ListenToSignal("Destroy", function()
            self:Destroy()
        end)
    end
end

--[[
Adds a property to serialize.
--]]
function ReplicatedContainer.AddToSerialization(self: NexusInstanceReplicatedContainer, PropertyName: string): ()
    --Store the property to serialize.
    table.insert(self.SerializedProperties, PropertyName)

    --Replicate changes from the server to the client.
    if RunService:IsServer() then
        self:OnPropertyChanged(PropertyName, function(_, NewValue: any)
            if not self.ObjectReplicationIntegration then return end
            self:SendSignal("Changed_"..PropertyName, self.ObjectReplicationIntegration.EncodeIds(NewValue))
        end)
    else
        self:ListenToSignal("Changed_"..PropertyName, function(NewValue: any)
            if not self.ObjectReplicationIntegration then return end
            (self :: any)[PropertyName] = self.ObjectReplicationIntegration.DecodeIds(NewValue)
        end)
    end
end

--[[
Sends a signal to the clients.
--]]
function ReplicatedContainer.SendSignal(self: NexusInstanceReplicatedContainer, Name: string, ...: any): ()
    if not self.ObjectReplicationIntegration then return end
    self.ObjectReplicationIntegration.SendSignal(self, Name, ...)
end

--[[
Registers a signal listener.
--]]
function ReplicatedContainer.ListenToSignal(self: NexusInstanceReplicatedContainer, Name: string, Handler: (...any) -> ()): ()
    if not self.SignalListeners[Name] then
        self.SignalListeners[Name] = {}
    end
    table.insert(self.SignalListeners[Name], Handler)
end

--[[
Invoked when a signal is invoked.
--]]
function ReplicatedContainer.OnSignal(self: NexusInstanceReplicatedContainer, Name: string, ...: any): ()
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
function ReplicatedContainer.RegisterChild(self: NexusInstanceReplicatedContainer, Child: NexusInstanceReplicatedContainer): ()
    --Return if the child exists.
    for _, ExistingChild in self.Children do
        if ExistingChild == Child then
            return
        end
    end

    --Add the child.
    table.insert(self.Children, Child)
    self.ChildAdded:Fire(Child)
end

--[[
Registers a child being removed.
--]]
function ReplicatedContainer.UnregisterChild(self: NexusInstanceReplicatedContainer, Child: NexusInstanceReplicatedContainer): ()
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
function ReplicatedContainer.FindFirstChildBy(self: NexusInstanceReplicatedContainer, PropertyName: string, PropertyValue: any): NexusInstanceReplicatedContainer?
    for _, Child in self.Children do
        if (Child :: any)[PropertyName] == PropertyValue then
            return Child :: NexusInstanceReplicatedContainer
        end
    end
    return nil
end

--[[
Waits for a child to exist that matches
the property.
--]]
function ReplicatedContainer.WaitForChildBy(self: NexusInstanceReplicatedContainer, PropertyName: string, PropertyValue: any): NexusInstanceReplicatedContainer
    local Result = self:FindFirstChildBy(PropertyName, PropertyValue)
    while not Result do
        Result = self:FindFirstChildBy(PropertyName, PropertyValue)
        task.wait()
    end
    return Result :: NexusInstanceReplicatedContainer
end

--[[
Returns the children of the object.
--]]
function ReplicatedContainer.GetChildren(self: NexusInstanceReplicatedContainer): {NexusInstanceReplicatedContainer}
    local Children = {}
    for _, Child in self.Children do
        table.insert(Children, Child)
    end
    return Children :: {NexusInstanceReplicatedContainer}
end

--[[
Disposes of the object.
--]]
function ReplicatedContainer.Dispose(self: NexusInstanceReplicatedContainer): ()
    --Unparent the object.
    self.Parent = nil

    --Destroy the children.
    for _, Child in self:GetChildren() do
        (Child :: NexusInstanceReplicatedContainer):Destroy()
    end
end

--[[
Destroys the object.
--]]
function ReplicatedContainer.Destroy(self: NexusInstanceReplicatedContainer)
    --Unregister the object.
    if RunService:IsServer() then
        self:SendSignal("Destroy")
    end
    if self.ObjectReplicationIntegration then
        self.ObjectReplicationIntegration.DisposeObject(self.Id)
    end

    --Clear the object.
    self:Dispose()
end

--[[
Returns the object as a string.
--]]
function ReplicatedContainer:__tostring()
    return self.Name
end



return NexusInstance.ToInstance(ReplicatedContainer) :: NexusInstance.NexusInstanceClass<typeof(ReplicatedContainer), () -> (ReplicatedContainer)>
