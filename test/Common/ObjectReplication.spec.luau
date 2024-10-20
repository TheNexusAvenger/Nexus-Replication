--Tests ObjectReplication.
--!strict
--$NexusUnitTestExtensions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local TestService = game:GetService("TestService")

local ObjectReplication = require(ReplicatedStorage:WaitForChild("NexusReplication"):WaitForChild("Common"):WaitForChild("ObjectReplication"))

return function()
    afterEach(function()
        for _, Ins in CollectionService:GetTagged("NexusReplicationReferencedInstance") do
            if not Ins:IsDescendantOf(TestService) then continue end
            Ins:Destroy()
        end
    end)
    
    describe("An ObjectReplication instance on the server", function()
        local TestObjectReplication = nil
        beforeEach(function()
            TestObjectReplication = ObjectReplication.new("Server")
        end)

        afterEach(function()
            TestObjectReplication:Destroy()
        end)

        it("should be initialized for the server.", function()
            expect(TestObjectReplication.CurrentId).to.equal(1)
            expect(TestObjectReplication.IdIncrementer).to.equal(1)
            expect(TestObjectReplication.ReplicatorRole).to.equal("Server")
            expect(TestObjectReplication.Client).to.equal(nil)
        end)

        it("should register types.", function()
            local TestClass = {
                new = function()
                    return nil :: any
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)
            expect(TestObjectReplication:GetClass("TestClass")).to.equal(TestClass)
        end)

        it("should wait for registered types.", function()
            local TestClass = {
                new = function()
                    return {}
                end,
            }
            task.spawn(function()
                TestObjectReplication:RegisterType("TestClass", TestClass)
            end)
            expect(TestObjectReplication:GetClass("TestClass")).to.equal(TestClass)
        end)

        it("should create objects with unknown ids.", function()
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            local FiredData = nil
            TestObjectReplication.ObjectCreatedEvent = {
                FireAllClients = function(_, Data)
                    FiredData = Data
                end,
            } :: any

            local TestObject = TestObjectReplication:CreateObject("TestClass")
            expect(TestObject.Id).to.equal(1)
            expect(TestObject.Type).to.equal("TestClass")
            expect(FiredData.Id).to.equal(1)
            expect(FiredData.Type).to.equal("TestClass")
            expect(FiredData.Object).to.equal("TestData")
            expect(TestObjectReplication:GetObject(1)).to.equal(TestObject)
            expect(TestObjectReplication.ObjectRegistry[1]).to.equal(TestObject)
            expect(TestObjectReplication.DisposeObjectRegistry[1]).to.equal(nil)
        end)

        it("should serialize objects with a Serialize method.", function()
            local Data = TestObjectReplication:SerializeObjectData({
                Serialize = function()
                    return "TestData"
                end,
            } :: any)

            expect(Data).to.equal("TestData")
        end)

        it("should serialize objects with SerializedProperties.", function()
            local Data = TestObjectReplication:SerializeObjectData({
                Property1 = "TestValue1",
                Property2 = "TestValue2",
                Property3 = "TestValue3",
                SerializedProperties = {"Property1", "Property2"},
            } :: any)

            expect(Data.Property1).to.equal("TestValue1")
            expect(Data.Property2).to.equal("TestValue2")
            expect(Data.Property3).to.equal(nil)
        end)

        it("should create objects with given ids.", function()
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            local FiredData = nil
            TestObjectReplication.ObjectCreatedEvent = {
                FireAllClients = function(_, Data)
                    FiredData = Data
                end,
            } :: any

            local TestObject = TestObjectReplication:CreateObject("TestClass", 5)
            expect(TestObject.Id).to.equal(5)
            expect(TestObject.Type).to.equal("TestClass")
            expect(FiredData.Id).to.equal(5)
            expect(FiredData.Type).to.equal("TestClass")
            expect(FiredData.Object).to.equal("TestData")
            expect(TestObjectReplication:GetObject(5)).to.equal(TestObject)
            expect(TestObjectReplication.ObjectRegistry[5]).to.equal(TestObject)
            expect(TestObjectReplication.DisposeObjectRegistry[5]).to.equal(nil)
        end)

        it("should wait for objects to be created.", function()
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            TestObjectReplication.ObjectCreatedEvent = {
                FireAllClients = function(_, Data) end,
            } :: any
            task.spawn(function()
                TestObjectReplication:CreateObject("TestClass")
            end)

            local TestObject = TestObjectReplication:GetObject(1)
            expect(TestObject.Id).to.equal(1)
            expect(TestObject.Type).to.equal("TestClass")
            expect(TestObjectReplication.ObjectRegistry[1]).to.equal(TestObject)
            expect(TestObjectReplication.DisposeObjectRegistry[1]).to.equal(nil)
        end)

        it("should dispose objects.", function()
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            TestObjectReplication.ObjectCreatedEvent = {
                FireAllClients = function(_, Data) end,
            } :: any
            TestObjectReplication:CreateObject("TestClass")
            TestObjectReplication:DisposeObject(1)

            local TestObject = TestObjectReplication:GetObject(1)
            expect(TestObject.Id).to.equal(1)
            expect(TestObject.Type).to.equal("TestClass")
            expect(TestObjectReplication.ObjectRegistry[1]).to.equal(nil)
            expect(TestObjectReplication.DisposeObjectRegistry[1]).to.equal(TestObject)
        end)

        it("should send signals.", function()
            local FiredIndex, FiredData = nil, nil
            TestObjectReplication.SendSignalEvent = {
                FireAllClients = function(_, Index, Data)
                    FiredIndex = Index
                    FiredData = Data
                end,
            } :: any

            TestObjectReplication:SendSignal({Id = 1}, "TestData")
            expect(FiredIndex).to.equal(1)
            expect(FiredData).to.equal("TestData")
        end)

        it("should return a global container.", function()
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("ReplicatedContainer", TestClass)

            local FiredData = nil
            TestObjectReplication.ObjectCreatedEvent = {
                FireAllClients = function(_, Data)
                    FiredData = Data
                end,
            } :: any

            local TestObject = TestObjectReplication:GetGlobalContainer()
            expect(TestObject.Id).to.equal(0)
            expect(TestObject.Type).to.equal("ReplicatedContainer")
            expect(FiredData.Id).to.equal(0)
            expect(FiredData.Type).to.equal("ReplicatedContainer")
            expect(FiredData.Object).to.equal("TestData")
            expect(TestObjectReplication:GetObject(0)).to.equal(TestObject)
        end)
    end)

    describe("An ObjectReplication instance on the server with stored instances", function()
        local TestObjectReplication = nil
        local TestReplicatedContainer1, TestReplicatedContainer2, TestReplicatedContainer3, TestReplicatedContainer4 = nil, nil, nil, nil
        beforeEach(function()
            TestObjectReplication = ObjectReplication.new("Server")

            TestReplicatedContainer1 = {
                Id = -1,
            } :: any
            TestObjectReplication.ObjectRegistry[-1] = TestReplicatedContainer1
            TestReplicatedContainer2 = {
                Id = -2,
            } :: any
            TestObjectReplication.ObjectRegistry[-2] = TestReplicatedContainer2
            TestReplicatedContainer3 = {
                Id = -3,
            } :: any
            TestObjectReplication.ObjectRegistry[-3] = TestReplicatedContainer3
            TestReplicatedContainer4 = {
                Id = -4,
            } :: any
        end)

        afterEach(function()
            TestObjectReplication:Destroy()
        end)

        it("should encode ids.", function()
            --Test encoding non-tables.
            expect(TestObjectReplication:EncodeIds(1)).to.equal(1)
            expect(TestObjectReplication:EncodeIds("Test")).to.equal("Test")

            --Test encoding objects.
            expect(TestObjectReplication:EncodeIds(TestReplicatedContainer1)).to.deepEqual({__KeyToDecode = -1})
            expect(TestObjectReplication:EncodeIds(TestReplicatedContainer4)).to.equal(nil)

            --Test encoding tables.
            expect(TestObjectReplication:EncodeIds({1, 2, 3})).to.deepEqual({1, 2, 3})
            expect(TestObjectReplication:EncodeIds({TestReplicatedContainer1, TestReplicatedContainer2})).to.deepEqual({__KeysToDecode = {1, 2}, Data = {-1, -2}})
            expect(TestObjectReplication:EncodeIds({TestReplicatedContainer1, TestReplicatedContainer2, TestReplicatedContainer3, TestReplicatedContainer4})).to.deepEqual({__KeysToDecode={1, 2, 3}, Data={-1, -2, -3}})
            expect(TestObjectReplication:EncodeIds({{TestReplicatedContainer1, TestReplicatedContainer2}, {TestReplicatedContainer2, TestReplicatedContainer3}})).to.deepEqual({{__KeysToDecode={1, 2}, Data = {-1, -2}}, {__KeysToDecode = {1, 2}, Data={-2, -3}}})
            expect(TestObjectReplication:EncodeIds({Key1=TestReplicatedContainer1, Key2 = TestReplicatedContainer2, Key3 = {TestReplicatedContainer1, TestReplicatedContainer3}})).to.deepEqual({__KeysToDecode = {"Key1", "Key2"}, Data = {Key1 = -1, Key2 = -2, Key3 = {__KeysToDecode = {1, 2}, Data={-1, -3}}}})
        end)

        it("should encode instances directly.", function()
            local TestPart = Instance.new("Part")
            local EncodedIds = TestObjectReplication:EncodeIds(TestPart)
            expect(EncodedIds.__InstanceReferenceId).to.equal(TestPart:GetAttribute("NexusReplicationInstanceId"))
            expect(EncodedIds.__Instance).to.equal(TestPart)
            expect(TestPart:HasTag("NexusReplicationReferencedInstance")).to.equal(true)
        end)

        it("should encode instances in tables.", function()
            local TestPart1 = Instance.new("Part")
            TestPart1:SetAttribute("NexusReplicationInstanceId", "TestId1")
            local TestPart2 = Instance.new("Part")
            TestPart2:SetAttribute("NexusReplicationInstanceId", "TestId2")
            local EncodedIds = TestObjectReplication:EncodeIds({TestPart1, TestPart2, "Test" :: any})
            expect(EncodedIds[1].__InstanceReferenceId).to.equal("TestId1")
            expect(EncodedIds[1].__Instance).to.equal(TestPart1)
            expect(EncodedIds[2].__InstanceReferenceId).to.equal("TestId2")
            expect(EncodedIds[2].__Instance).to.equal(TestPart2)
            expect(EncodedIds[3]).to.equal("Test")
            expect(TestPart1:HasTag("NexusReplicationReferencedInstance")).to.equal(true)
            expect(TestPart2:HasTag("NexusReplicationReferencedInstance")).to.equal(true)
        end)

        it("should decode ids.", function()
            --Test decoding non-tables.
            expect(TestObjectReplication:DecodeIds(1)).to.equal(1)
            expect(TestObjectReplication:DecodeIds("Test")).to.equal("Test")

            --Test decoding objects.
            --Testing with id -4 will infinitely yield since it will wait for the object to exist.
            expect(TestObjectReplication:DecodeIds({__KeyToDecode = -1})).to.equal(TestReplicatedContainer1)
            expect(TestObjectReplication:DecodeIds({__KeyToDecode = -2})).to.equal(TestReplicatedContainer2)

            --Test decoding tables.
            expect(TestObjectReplication:DecodeIds({1, 2, 3})).to.deepEqual({1, 2, 3})
            expect(TestObjectReplication:DecodeIds({__KeysToDecode = {1, 2}, Data = {-1, -2}})).to.deepEqual({TestReplicatedContainer1, TestReplicatedContainer2})
            expect(TestObjectReplication:DecodeIds({{__KeysToDecode = {1, 2}, Data = {-1, -2}}, {__KeysToDecode = {1, 2}, Data = {-2, -3}}})).to.deepEqual({{TestReplicatedContainer1, TestReplicatedContainer2}, {TestReplicatedContainer2, TestReplicatedContainer3}})
            expect(TestObjectReplication:DecodeIds({__KeysToDecode={"Key1", "Key2"}, Data = {Key1 = -1, Key2 = -2, Key3 = {__KeysToDecode={1, 2}, Data={-1, -3}}}})).to.deepEqual({Key1 = TestReplicatedContainer1, Key2 = TestReplicatedContainer2,Key3 = {TestReplicatedContainer1, TestReplicatedContainer3}})
        end)

        it("should decode instances directly.", function()
            local TestPart = Instance.new("Part")
            expect(TestObjectReplication:DecodeIds({__InstanceReferenceId = "TestId", __Instance = TestPart})).to.equal(TestPart)
        end)

        it("should decode instances in tables.", function()
            local TestPart1 = Instance.new("Part")
            TestPart1:SetAttribute("NexusReplicationInstanceId", "TestId1")
            local TestPart2 = Instance.new("Part")
            TestPart2:SetAttribute("NexusReplicationInstanceId", "TestId2")
            local DecodedIds = TestObjectReplication:DecodeIds({
                {__InstanceReferenceId = "TestId1", __Instance = TestPart1}, 
                {__InstanceReferenceId = "TestId2", __Instance = TestPart2},
                "Test" :: any
            })
            expect(DecodedIds[1]).to.equal(TestPart1)
            expect(DecodedIds[2]).to.equal(TestPart2)
            expect(DecodedIds[3]).to.equal("Test")
        end)

        it("should decode loaded instances with missing references.", function()
            local TestId = HttpService:GenerateGUID()
            local TestPart = Instance.new("Part")
            TestPart:AddTag("NexusReplicationReferencedInstance")
            TestPart:SetAttribute("NexusReplicationInstanceId", TestId)
            TestPart.Parent = TestService
            expect(TestObjectReplication:DecodeIds({__InstanceReferenceId = TestId})).to.equal(TestPart)
        end)
    end)

    describe("An ObjectReplication instance on the client", function()
        local TestObjectReplication = nil
        beforeEach(function()
            TestObjectReplication = ObjectReplication.new("Client")
        end)

        afterEach(function()
            TestObjectReplication:Destroy()
        end)

        it("should be initialized for the server.", function()
            expect(TestObjectReplication.CurrentId).to.equal(-1)
            expect(TestObjectReplication.IdIncrementer).to.equal(-1)
            expect(TestObjectReplication.ReplicatorRole).to.equal("Client")
            local Client = (TestObjectReplication.Client :: any)
            expect(Client.InitialObjectsLoading).to.equal(0)
            expect(Client.InitialIds).to.equal(nil)
            expect(Client.LoadingStarted).to.never.equal(nil)
            expect(Client.ObjectLoaded).to.never.equal(nil)
        end)

        it("should load objects with FromSerializedData.", function()
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
                FromSerializedData = function(Data: any, Id: number)
                    return {
                        Id = Id,
                        Data = Data,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            local TestObject = TestObjectReplication:LoadObject({
                Type = "TestClass",
                Id = 5,
                Object = "Data",
            })
            expect(TestObject.Id).to.equal(5)
            expect(TestObject.Data).to.equal("Data")
        end)

        it("should load objects without FromSerializedData.", function()
            local TestClass = {
                new = function()
                    return {
                        SerializedProperties = {"TestProperty1", "TestProperty2"},
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            local TestInstance = Instance.new("Part")
            TestInstance:AddTag("NexusReplicationReferencedInstance")
            TestInstance:SetAttribute("NexusReplicationInstanceId", "TestId")
            local TestObject = TestObjectReplication:LoadObject({
                Type = "TestClass",
                Id = 5,
                Object = {
                    TestProperty1 = "TestValue",
                    TestProperty2 = {__InstanceReferenceId = "TestId", __Instance = TestInstance},
                },
            })
            expect(TestObject.Id).to.equal(5)
            expect(TestObject.Type).to.equal("TestClass")
            expect(TestObject.TestProperty1).to.equal("TestValue")
            expect(TestObject.TestProperty2).to.equal(TestInstance)
        end)

        it("should load objects without FromSerializedData and unloaded instances.", function()
            local TestClass = {
                new = function()
                    return {
                        SerializedProperties = {"TestProperty1", "TestProperty2"},
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            local TestId = HttpService:GenerateGUID()
            local TestInstance = Instance.new("Part")
            TestInstance:AddTag("NexusReplicationReferencedInstance")
            TestInstance:SetAttribute("NexusReplicationInstanceId", TestId)

            local TestObject = TestObjectReplication:LoadObject({
                Type = "TestClass",
                Id = 5,
                Object = {
                    TestProperty1 = "TestValue",
                    TestProperty2 = {__InstanceReferenceId = TestId},
                },
            })
            expect(TestObject.Id).to.equal(5)
            expect(TestObject.Type).to.equal("TestClass")
            expect(TestObject.TestProperty1).to.equal("TestValue")
            expect(TestObject.TestProperty2).to.equal(nil)
            TestInstance.Parent = TestService
            task.wait()
            expect(TestObject.TestProperty2).to.equal(TestInstance)
        end)

        it("should load objects with queued signals.", function()
            local FiredSignals = {}
            local TestClass = {
                new = function()
                    return {
                        Serialize = function()
                            return "TestData"
                        end,
                    }
                end,
                FromSerializedData = function(Data: any, Id: number)
                    return {
                        Id = Id,
                        Data = Data,
                        OnSignal = function(_, Data)
                            table.insert(FiredSignals, Data)
                        end,
                    }
                end,
            }
            TestObjectReplication:RegisterType("TestClass", TestClass)

            local Client = (TestObjectReplication.Client :: any)
            Client.QueuedSignals[5] = {
                {"TestData1"},
                {"TestData2"},
            }
            local TestObject = TestObjectReplication:LoadObject({
                Type = "TestClass",
                Id = 5,
                Object = "Data",
            })
            expect(TestObject.Id).to.equal(5)
            expect(TestObject.Data).to.equal("Data")
            expect(FiredSignals[1]).to.equal("TestData1")
            expect(FiredSignals[2]).to.equal("TestData2")
            expect(Client.QueuedSignals[5]).to.equal(nil)
        end)
    end)
end