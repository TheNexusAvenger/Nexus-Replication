--Base for replicating objects.
--!strict

local RunService = game:GetService("RunService")

local NexusInstance = require(script.Parent.Parent:WaitForChild("NexusInstance"))

local ObjectReplication = {
    Instance = nil :: NexusInstanceObjectReplication?,
}
ObjectReplication.__index = ObjectReplication
local NexusInstanceObjectReplication = NexusInstance.ToInstance(ObjectReplication) :: NexusInstance.NexusInstanceClass<typeof(ObjectReplication), (ReplicatorRole: ReplicatorRole?) -> (NexusInstanceObjectReplication)>

export type StubbedReplicatableInstanceClass = {
    new: () -> (StubbedReplicatableInstance),
    FromSerializedData: ((SerializationData: any, Id: number) -> ())?,
    [any]: any,
}
export type StubbedReplicatableInstance = {
    Type: string,
    Id: number,
    Serialize: ((self: StubbedReplicatableInstance) -> (any))?,
    SerializedProperties: {string}?,
    [any]: any,
}
export type ReplicatorRole = "Client" | "Server"
export type ObjectReplication = {
    ReplicatorRole: ReplicatorRole,
    CurrentId: number,
    IdIncrementer: number,
    TypeClasses: {[string]: any},
    TypeRegistered: NexusInstance.TypedEvent<>,
    ObjectRegistry: {[number]: StubbedReplicatableInstance},
    DisposeObjectRegistry: {[number]: StubbedReplicatableInstance},
    ObjectCreatedEvent: RemoteEvent,
    SendSignalEvent: RemoteEvent,
    GetObjectsFunction: RemoteFunction,
    Client: {
        InitialObjectsLoading: number,
        InitialIds: {[number]: boolean}?,
        QueuedSignals: {[number]: {any}},
        LoadingStarted: NexusInstance.TypedEvent<>?,
        ObjectLoaded: NexusInstance.TypedEvent<>,
    }?,
} & typeof(setmetatable({}, ObjectReplication))
export type NexusInstanceObjectReplication = NexusInstance.NexusInstance<ObjectReplication>



--[[
Creates the replicator.
--]]
function ObjectReplication.__new(self: NexusInstanceObjectReplication, ReplicatorRole: ReplicatorRole?): ()
    --Set up the state.
    self.CurrentId = 1
    self.IdIncrementer = 1
    self.TypeClasses = {}
    self.TypeRegistered = self:CreateEvent()
    self.ObjectRegistry = {} :: {StubbedReplicatableInstance}
    self.DisposeObjectRegistry = {}
    setmetatable(self.DisposeObjectRegistry, {__mode="v"})

    --Store or determine the replicator role.
    if ReplicatorRole ~= nil then
        self.ReplicatorRole = ReplicatorRole
    elseif RunService:IsServer() then
        self.ReplicatorRole = "Server"
    else
        self.ReplicatorRole = "Client"
    end

    --Add the client state.
    if self.ReplicatorRole == "Client" then
        self.CurrentId = -1
        self.IdIncrementer = -1
        self.Client = {
            InitialObjectsLoading = 0,
            InitialIds = nil, --Set in LoadServerObjects
            QueuedSignals = {},
            LoadingStarted = self:CreateEvent(),
            ObjectLoaded = self:CreateEvent(),
        }
    end
end

--[[
Returns an instance of the object replication.
--]]
function ObjectReplication.GetInstance(): NexusInstanceObjectReplication
    --Create the instance if it doesn't exist.
    if not ObjectReplication.Instance then
        local NewInstance = NexusInstanceObjectReplication.new()
        ObjectReplication.Instance = NewInstance
        NewInstance:ConnectReplication()
    end

    --Start loading the objects.
    local ObjectReplicationInstance = ObjectReplication.Instance :: NexusInstanceObjectReplication
    if ObjectReplicationInstance.ReplicatorRole == "Client" then
        ObjectReplicationInstance:LoadServerObjects()
    end

    --Return the instance.
    return ObjectReplicationInstance
end

--[[
Connects replication.
--]]
function ObjectReplication.ConnectReplication(self: NexusInstanceObjectReplication): ()
    --Prepare the replication.
    if not self.ObjectCreatedEvent or not self.SendSignalEvent or not self.GetObjectsFunction then
        if self.ReplicatorRole == "Server" then
            --Create the replication objects.
            local ObjectCreatedEvent = script:FindFirstChild("ObjectCreated") or Instance.new("RemoteEvent")
            ObjectCreatedEvent.Name = "ObjectCreated"
            ObjectCreatedEvent.Parent = script
            self.ObjectCreatedEvent = ObjectCreatedEvent

            local SendSignalEvent = script:FindFirstChild("SendSignal") or Instance.new("RemoteEvent")
            SendSignalEvent.Name = "SendSignal"
            SendSignalEvent.Parent = script
            self.SendSignalEvent = SendSignalEvent

            local GetObjectsFunction = script:FindFirstChild("GetObjects") or Instance.new("RemoteFunction")
            GetObjectsFunction.Name = "GetObjects"
            GetObjectsFunction.Parent = script
            self.GetObjectsFunction = GetObjectsFunction
        else
            --Wait for the replication objects.
            self.ObjectCreatedEvent = script:FindFirstChild("ObjectCreated")
            self.SendSignalEvent = script:FindFirstChild("SendSignal")
            self.GetObjectsFunction = script:FindFirstChild("GetObjects")
        end
    end

    --Set up the replication.
    if self.ReplicatorRole == "Server" then
        --Set up fetching all the objects.
        function self.GetObjectsFunction.OnServerInvoke()
            local Objects = {}
            for _, Object in self.ObjectRegistry do
                table.insert(Objects,{
                    Type = Object.Type,
                    Id = Object.Id,
                    Object = self:SerializeObjectData(Object),
                })
            end
            return Objects
        end
    else
        --Connect loading new objects.
        if not self.Client then
            error("Client state not loaded.")
        end
        self.ObjectCreatedEvent.OnClientEvent:Connect(function(ObjectData)
            --Return if the object will be or has been created by the initial ids.
            --This is due to a race condition where this is invoked first.
            if not self.Client.InitialIds then
                self:GetPropertyChangedSignal("InitialIds"):Wait()
            end
            if (self.Client.InitialIds :: {[number]: boolean})[ObjectData.Id] then
                return
            end

            --Create the object.
            self:LoadObject(ObjectData)
        end)

        --Connect listening to events.
        self.SendSignalEvent.OnClientEvent:Connect(function(Id, ...)
            local Object = self.ObjectRegistry[Id] or self.DisposeObjectRegistry[Id]
            if Object then
                Object:OnSignal(...)
            elseif Id then
                if not self.Client.QueuedSignals[Id] then
                    self.Client.QueuedSignals[Id] = {}
                end
                table.insert(self.Client.QueuedSignals[Id], table.pack(...))
            end
        end)
    end

    --Load the included types.
    self:RegisterType("ReplicatedContainer", require(script.Parent:WaitForChild("Object"):WaitForChild("ReplicatedContainer")))
    self:RegisterType("ReplicatedTable", require(script.Parent:WaitForChild("Object"):WaitForChild("ReplicatedTable")))
    self:RegisterType("Timer", require(script.Parent.Parent:WaitForChild("Example"):WaitForChild("Timer")))
end

--[[
Encodes a table's ids for serialization.
--]]
function ObjectReplication.EncodeIds(self: NexusInstanceObjectReplication, Table: any, CheckedValues: any): any
    CheckedValues = CheckedValues or {}

    --Return if the table is not a table.
    if Table == nil then return nil end
    if CheckedValues[Table] or type(Table) ~= "table" then
        CheckedValues[Table] = true
        return Table
    end
    CheckedValues[Table] = true

    --Return if the item is a replicated container.
    if Table.Id then
        if self.ObjectRegistry[Table.Id] then
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
        if type(Value) == "table" and Value.Id then
            if self.ObjectRegistry[Value.Id] then
                NewTable[Key] = Value.Id
                table.insert(KeysToDecode, Key)
                HasKeysToDecode = true
            end
        else
            NewTable[Key] = self:EncodeIds(Value, CheckedValues)
        end
    end

    --Return the table.
    return HasKeysToDecode and {__KeysToDecode = KeysToDecode, Data = NewTable} or NewTable
end

--[[
Encodes a table's ids for deserialization.
--]]
function ObjectReplication.DecodeIds(self: NexusInstanceObjectReplication, Table: any): any
    --Return if the table is not a table.
    if type(Table) ~= "table" then
        return Table
    end

    --Return if the table is an object.
    if Table.__KeyToDecode then
        return self:GetObject(Table.__KeyToDecode)
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
        NewTable[Key] = self:DecodeIds(NewTable[Key])
    end
    if Table.__KeysToDecode then
        for _,Key in Table.__KeysToDecode do
            NewTable[Key] = self:GetObject(NewTable[Key])
        end
    end

    --Return the table.
    return NewTable
end

--[[
Registers a class for a type.
--]]
function ObjectReplication.RegisterType(self: NexusInstanceObjectReplication, Type: string, Class: any): ()
    self.TypeClasses[Type] = Class
    self.TypeRegistered:Fire()
end

--[[
Returns the class for the given type.
--]]
function ObjectReplication.GetClass(self: NexusInstanceObjectReplication, Type: string): StubbedReplicatableInstanceClass
    --Wait for the type to exist.
    while not self.TypeClasses[Type] do
        self.TypeRegistered:Wait()
    end

    --Return the class.
    return self.TypeClasses[Type]
end

--[[
Serializes the data of an object.
--]]
function ObjectReplication.SerializeObjectData(self: NexusInstanceObjectReplication, Object: StubbedReplicatableInstance): any
    --Return the value of the serialize method.
    if Object.Serialize then
        return (Object :: any):Serialize()
    end

    --Serialize the properties.
    if Object.SerializedProperties then
        local Properties = {}
        for _, PropertyName in Object.SerializedProperties do
            Properties[PropertyName] = (Object :: any)[PropertyName]
        end
        return self:EncodeIds(Properties)
    end

    --Reutrn nil data.
    return nil
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
    Object.Id = Id :: number
    Object.Type = Type
    self.ObjectRegistry[Id :: number] = Object

    --Serialize the object and send it to the clients.
    if self.ReplicatorRole == "Server" then
        self.ObjectCreatedEvent:FireAllClients({
            Type = Type,
            Id = Object.Id,
            Object = self:SerializeObjectData(Object),
        })
    end

    --Return the object.
    return Object
end

--[[
Loads the current objects from the server.
Can only be called on the client.
--]]
function ObjectReplication.LoadServerObjects(self: NexusInstanceObjectReplication): ()
    --Throw an error if the client is not set up.
    if not self.Client then
        error("ObjectReplication::LoadServerObjects can only be called on the client.")
    end

    --Get the ids of the objects.
    --This is done before creating objects from ObjectCreated due to a race condition where it is invoked first.
    local InitialObjects = self.GetObjectsFunction:InvokeServer()
    local InitialIds = {}
    for _,ObjectData in InitialObjects do
        InitialIds[ObjectData.Id] = true
    end
    self.Client.InitialIds = InitialIds

    --Load to the objects.
    for _, ObjectData in InitialObjects do
        self.Client.InitialObjectsLoading = self.Client.InitialObjectsLoading + 1
        task.spawn(function()
            self:LoadObject(ObjectData)
            self.Client.InitialObjectsLoading = self.Client.InitialObjectsLoading - 1
            self.Client.ObjectLoaded:Fire()
        end)
    end
    if self.Client.LoadingStarted then
        self.Client.LoadingStarted:Fire()
        self.Client.LoadingStarted = nil
    end
end

--[[
Loads an object from serialization data.
Can only be called on the client.
--]]
function ObjectReplication.LoadObject(self: NexusInstanceObjectReplication, ObjectData: any): any
    --Throw an error if the client is not set up.
    if not self.Client then
        error("ObjectReplication::LoadServerObjects can only be called on the client.")
    end

    --Create the object.
    local Class = self:GetClass(ObjectData.Type)
    local Object = nil
    if Class.FromSerializedData then
        Object = Class.FromSerializedData(ObjectData.Object, ObjectData.Id)
    else
        Object = self:CreateObject(ObjectData.Type, ObjectData.Id)
        if Object.SerializedProperties then
            local Properties = self:DecodeIds(ObjectData.Object)
            for _, PropertyName in Object.SerializedProperties do
                (Object :: any)[PropertyName] = Properties[PropertyName]
            end
        end
    end

    --Run the queued signals.
    if self.Client.QueuedSignals[ObjectData.Id] then
        for _, SignalData in self.Client.QueuedSignals[ObjectData.Id] do
            Object:OnSignal(table.unpack(SignalData))
        end
        self.Client.QueuedSignals[ObjectData.Id] = nil
    end

    --Return the object.
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
    if self.ReplicatorRole ~= "Server" then
        error("ObjectReplication::SendSignal can only be called on the server.")
    end
    self.SendSignalEvent:FireAllClients(Object.Id, Name, ...)
end

--[[
Returns the global replicated container.
--]]
function ObjectReplication.GetGlobalContainer(self: NexusInstanceObjectReplication): any
    if self.ReplicatorRole == "Server" then
        --Create the container if it doesn't exist.
        if not self.ObjectRegistry[0] and not self.DisposeObjectRegistry[0] then
            local Object = self:CreateObject("ReplicatedContainer",0)
            Object.Name = "GlobalReplicatedContainer"
        end
    else
        --Wait for the initial load.
        self:YieldForInitialLoad()
    end

    --Return the container.
    return self:GetObject(0)
end

--[[
Yields for the initial objects to load.
Can only be called on the client.
--]]
function ObjectReplication.YieldForInitialLoad(self: NexusInstanceObjectReplication): ()
    if not self.Client then
        error("ObjectReplication::YieldForInitialLoad can only be called on the client.")
    end
    if self.Client.LoadingStarted then
        self.Client.LoadingStarted:Wait()
    end
    while self.Client.InitialObjectsLoading > 0 do
        self.Client.ObjectLoaded:Wait()
    end
end

--[[
Destroys the object replication.
--]]
function ObjectReplication.Destroy(self: NexusInstanceObjectReplication): ()
    self.ObjectCreatedEvent:Destroy()
    self.SendSignalEvent:Destroy()
    self.GetObjectsFunction:Destroy()
end



return NexusInstanceObjectReplication