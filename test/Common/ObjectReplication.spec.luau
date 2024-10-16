--Tests ObjectReplication.
--!strict

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