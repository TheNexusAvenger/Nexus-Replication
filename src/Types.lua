--[[
TheNexusAvenger

Types used by Nexus Replication required in multiple modules.
--]]
--!strict

local NexusInstance = require(script.Parent:WaitForChild("NexusInstance"):WaitForChild("NexusInstance"))
local NexusEvent = require(script.Parent:WaitForChild("NexusInstance"):WaitForChild("Event"):WaitForChild("NexusEvent"))

export type ObjectReplication = {
    new: () -> (ObjectReplication),
    Extend: (self: ObjectReplication) -> (ObjectReplication),

    CurrentId: number,
    IdIncrementer: number,
    TypeClasses: {[string]: ReplicatedContainer},
    ObjectRegistry: {[number]: ReplicatedContainer},
    DisposeObjectRegistry: {[number]: ReplicatedContainer},
    RegisterType: (self: ObjectReplication, Type: string, Class: ReplicatedContainer) -> (),
    GetClass: (self: ObjectReplication, Type: string) -> (ReplicatedContainer),
    CreateObject: (self: ObjectReplication, Type: string,  Id: number?) -> (ReplicatedContainer),
    GetObject: (self: ObjectReplication, Id: number) -> (ReplicatedContainer),
    DisposeObject: (self: ObjectReplication, Id: number) -> (ReplicatedContainer),
    SendSignal: (self: ObjectReplication, Object: ReplicatedContainer, Name: string, ...any) -> (),
    GetGlobalContainer: (self: ObjectReplication) -> (ReplicatedContainer),
    GetServerTime: (self: ObjectReplication) -> (number),
} & NexusInstance.NexusInstance

export type ReplicatedContainer = {
    new: () -> (ReplicatedContainer),
    Extend: (self: ReplicatedContainer) -> (ReplicatedContainer),
    FromSerializedData: (SerializationData: any, Id: number) -> (ReplicatedContainer),
    AddFromSerializeData: (self: ReplicatedContainer, Type: string) -> (),

    Children: {ReplicatedContainer},
    Parent: {ReplicatedContainer},
    Name: string,
    ChildAdded: NexusEvent.NexusEvent<ReplicatedContainer>,
    ChildRemoved: NexusEvent.NexusEvent<ReplicatedContainer>,
    Serialize: (self: ReplicatedContainer) -> (any),
    AddToSerialization: (self: ReplicatedContainer, PropertyName: string) -> (),
    SendSignal: (self: ReplicatedContainer, Name: string, ...any) -> (),
    ListenToSignal: (self: ReplicatedContainer, Name: string, Handler: (...any) -> ()) -> (),
    OnSignal: (self: ReplicatedContainer, Name: string, ...any) -> (),
    RegisterChild: (self: ReplicatedContainer, Child: ReplicatedContainer) -> (),
    UnregisterChild: (self: ReplicatedContainer, Child: ReplicatedContainer) -> (),
    FindFirstChildBy: (self: ReplicatedContainer, PropertyName: string, PropertyValue: any) -> (ReplicatedContainer?),
    WaitForChildBy: (self: ReplicatedContainer, PropertyName: string, PropertyValue: any) -> (ReplicatedContainer),
    GetChildren: (self: ReplicatedContainer) -> ({ReplicatedContainer}),
    Dispose: (self: ReplicatedContainer) -> (),
} & NexusInstance.NexusInstance

return true