--Tests ObjectReplication.
--!strict
--$NexusUnitTestExtensions

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectReplication = require(ReplicatedStorage:WaitForChild("NexusReplication"):WaitForChild("Common"):WaitForChild("ObjectReplication"))

return function()
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
            }

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
            }

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
            }
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
            }
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
            }

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
            }

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
            }
            TestObjectReplication.ObjectRegistry[-1] = TestReplicatedContainer1
            TestReplicatedContainer2 = {
                Id = -2,
            }
            TestObjectReplication.ObjectRegistry[-2] = TestReplicatedContainer2
            TestReplicatedContainer3 = {
                Id = -3,
            }
            TestObjectReplication.ObjectRegistry[-3] = TestReplicatedContainer3
            TestReplicatedContainer4 = {
                Id = -4,
            }
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
            expect(TestObjectReplication:DecodeIds({{__KeysToDecode={1, 2}, Data={-1, -2}}, {__KeysToDecode = {1, 2}, Data = {-2, -3}}})).to.deepEqual({{TestReplicatedContainer1, TestReplicatedContainer2}, {TestReplicatedContainer2, TestReplicatedContainer3}})
            expect(TestObjectReplication:DecodeIds({__KeysToDecode={"Key1", "Key2"}, Data = {Key1 = -1, Key2 = -2, Key3 = {__KeysToDecode={1, 2}, Data={-1, -3}}}})).to.deepEqual({Key1 = TestReplicatedContainer1, Key2 = TestReplicatedContainer2,Key3 = {TestReplicatedContainer1, TestReplicatedContainer3}})
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
            expect(TestObjectReplication.Client.InitialObjectsLoading).to.equal(0)
            expect(TestObjectReplication.Client.InitialIds).to.equal(nil)
            expect(TestObjectReplication.Client.LoadingStarted).to.never.equal(nil)
            expect(TestObjectReplication.Client.ObjectLoaded).to.never.equal(nil)
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
                        Serialize = function()
                            return "TestData"
                        end,
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

            TestObjectReplication.Client.QueuedSignals[5] = {
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
            expect(TestObjectReplication.Client.QueuedSignals[5]).to.equal(nil)
        end)
    end)
end