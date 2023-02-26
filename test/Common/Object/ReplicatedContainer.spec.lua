--[[
TheNexusAvenger

Tests the ReplicatedContainer class.
--]]
--!strict
--$NexusUnitTestExtensions

local NexusReplicationModule = game:GetService("ReplicatedStorage"):WaitForChild("NexusReplication")
local NexusReplication = require(NexusReplicationModule)
local ReplicatedContainer = require(NexusReplicationModule:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedContainer"))

return function()
    local TestReplicatedContainer1, TestReplicatedContainer2, TestReplicatedContainer3, TestReplicatedContainer4 = nil, nil, nil, nil
    beforeEach(function()
        local ObjectRegistry = {}
        NexusReplication:GetObjectReplicator().ObjectRegistry = ObjectRegistry
        TestReplicatedContainer1 = ReplicatedContainer.new()
        TestReplicatedContainer1.Id = -1
        ObjectRegistry[-1] = TestReplicatedContainer1
        TestReplicatedContainer2 = ReplicatedContainer.new()
        TestReplicatedContainer2.Id = -2
        ObjectRegistry[-2] = TestReplicatedContainer2
        TestReplicatedContainer3 = ReplicatedContainer.new()
        TestReplicatedContainer3.Id = -3
        ObjectRegistry[-3] = TestReplicatedContainer3
        TestReplicatedContainer4 = ReplicatedContainer.new()
        TestReplicatedContainer4.Id = -4
    end)
    afterEach(function()
        TestReplicatedContainer1:Destroy()
        TestReplicatedContainer2:Destroy()
        TestReplicatedContainer3:Destroy()
        TestReplicatedContainer4:Destroy()
    end)
    afterAll(function()
        NexusReplication:ClearInstances()
    end)

    describe("The ReplicatedContainer helper functions", function()
        it("should encode ids.", function()
            --Test encoding non-tables.
            expect(ReplicatedContainer.EncodeIds(1)).to.equal(1)
            expect(ReplicatedContainer.EncodeIds("Test")).to.equal("Test")

            --Test encoding objects.
            expect(ReplicatedContainer.EncodeIds(TestReplicatedContainer1)).to.deepEqual({__KeyToDecode = -1})
            expect(ReplicatedContainer.EncodeIds(TestReplicatedContainer4)).to.equal(nil)

            --Test encoding tables.
            expect(ReplicatedContainer.EncodeIds({1, 2, 3})).to.deepEqual({1, 2, 3})
            expect(ReplicatedContainer.EncodeIds({TestReplicatedContainer1, TestReplicatedContainer2})).to.deepEqual({__KeysToDecode = {1, 2}, Data = {-1, -2}})
            expect(ReplicatedContainer.EncodeIds({TestReplicatedContainer1, TestReplicatedContainer2, TestReplicatedContainer3, TestReplicatedContainer4})).to.deepEqual({__KeysToDecode={1, 2, 3}, Data={-1, -2, -3}})
            expect(ReplicatedContainer.EncodeIds({{TestReplicatedContainer1, TestReplicatedContainer2}, {TestReplicatedContainer2, TestReplicatedContainer3}})).to.deepEqual({{__KeysToDecode={1, 2}, Data = {-1, -2}}, {__KeysToDecode = {1, 2}, Data={-2, -3}}})
            expect(ReplicatedContainer.EncodeIds({Key1=TestReplicatedContainer1, Key2 = TestReplicatedContainer2, Key3 = {TestReplicatedContainer1, TestReplicatedContainer3}})).to.deepEqual({__KeysToDecode = {"Key1", "Key2"}, Data = {Key1 = -1, Key2 = -2, Key3 = {__KeysToDecode = {1, 2}, Data={-1, -3}}}})
        end)

        it("should decode ids.", function()
            --Test decoding non-tables.
            expect(ReplicatedContainer.DecodeIds(1)).to.equal(1)
            expect(ReplicatedContainer.DecodeIds("Test")).to.equal("Test")

            --Test decoding objects.
            --Testing with id -4 will infinitely yield since it will wait for the object to exist.
            expect(ReplicatedContainer.DecodeIds({__KeyToDecode = -1})).to.equal(TestReplicatedContainer1)
            expect(ReplicatedContainer.DecodeIds({__KeyToDecode = -2})).to.equal(TestReplicatedContainer2)

            --Test decoding tables.
            expect(ReplicatedContainer.DecodeIds({1, 2, 3})).to.deepEqual({1, 2, 3})
            expect(ReplicatedContainer.DecodeIds({__KeysToDecode = {1, 2}, Data = {-1, -2}})).to.deepEqual({TestReplicatedContainer1, TestReplicatedContainer2})
            expect(ReplicatedContainer.DecodeIds({{__KeysToDecode={1, 2}, Data={-1, -2}}, {__KeysToDecode = {1, 2}, Data = {-2, -3}}})).to.deepEqual({{TestReplicatedContainer1, TestReplicatedContainer2}, {TestReplicatedContainer2, TestReplicatedContainer3}})
            expect(ReplicatedContainer.DecodeIds({__KeysToDecode={"Key1", "Key2"}, Data = {Key1 = -1, Key2 = -2, Key3 = {__KeysToDecode={1, 2}, Data={-1, -3}}}})).to.deepEqual({Key1 = TestReplicatedContainer1, Key2 = TestReplicatedContainer2,Key3 = {TestReplicatedContainer1, TestReplicatedContainer3}})
        end)

        it("should create an instance from serialization data.", function()
            --Deserialize the test object.
            local Object = ReplicatedContainer.FromSerializedData({
                __KeysToDecode = {"Parent"},
                Data = {
                    Name = "TestName",
                    Parent = -2,
                    Children = {
                        __KeysToDecode = {1, 2},
                        Data = {
                            -3, -1
                        },
                    },
                    UnknownProperty = "Test",
                },
            },-5)

            --Create the test object.
            expect(Object.Name).to.equal("TestName")
            expect(Object.Parent).to.equal(TestReplicatedContainer2)
            expect((Object :: any).Children[1]).to.equal(TestReplicatedContainer3)
            expect((Object :: any).Children[2]).to.equal(TestReplicatedContainer1)
            expect((Object :: any).Children[3]).to.equal(nil)
            expect(Object.UnknownProperty).to.equal(nil)
        end)
    end)

    describe("A ReplicatedContainer instance", function()
        it("shoiuld serialize the object.", function()
            --Assert the base objects serialize.
            expect(TestReplicatedContainer1:Serialize()).to.deepEqual({Children = {}, Name="ReplicatedContainer"})
            expect(TestReplicatedContainer2:Serialize()).to.deepEqual({Children = {}, Name="ReplicatedContainer"})
            expect(TestReplicatedContainer3:Serialize()).to.deepEqual({Children = {}, Name="ReplicatedContainer"})

            --Set the parents and assert the serialization is correct.
            TestReplicatedContainer2.Parent = TestReplicatedContainer1
            TestReplicatedContainer3.Parent = TestReplicatedContainer2
            expect(TestReplicatedContainer1:Serialize()).to.deepEqual({Children = {__KeysToDecode = {1}, Data = {-2}}, Name = "ReplicatedContainer"})
            expect(TestReplicatedContainer2:Serialize()).to.deepEqual({__KeysToDecode = {"Parent"}, Data = {Children = {__KeysToDecode = {1}, Data = {-3}}, Parent = -1, Name = "ReplicatedContainer"}})
            expect(TestReplicatedContainer3:Serialize()).to.deepEqual({__KeysToDecode = {"Parent"}, Data = {Children = {}, Parent = -2, Name = "ReplicatedContainer"}})
            TestReplicatedContainer3.Parent = TestReplicatedContainer1
            expect(TestReplicatedContainer1:Serialize()).to.deepEqual({Children = {__KeysToDecode = {1, 2}, Data={-2, -3}}, Name = "ReplicatedContainer"})
            expect(TestReplicatedContainer2:Serialize()).to.deepEqual({__KeysToDecode = {"Parent"}, Data = {Children = {}, Parent = -1, Name = "ReplicatedContainer"}})
            expect(TestReplicatedContainer3:Serialize()).to.deepEqual({__KeysToDecode = {"Parent"}, Data = {Children = {}, Parent = -1, Name = "ReplicatedContainer"}})
            TestReplicatedContainer2.Parent = nil
            expect(TestReplicatedContainer1:Serialize()).to.deepEqual({Children = {__KeysToDecode = {1}, Data = {-3}}, Name = "ReplicatedContainer"})
            expect(TestReplicatedContainer2:Serialize()).to.deepEqual({Children = {}, Name = "ReplicatedContainer"})
            expect(TestReplicatedContainer3:Serialize()).to.deepEqual({__KeysToDecode = {"Parent"}, Data = {Children = {}, Parent = -1, Name = "ReplicatedContainer"}})

            --Add a raw property and assert the serialization is correct.
            TestReplicatedContainer1:AddToSerialization("Name2")
            TestReplicatedContainer2:AddToSerialization("Name2")
            TestReplicatedContainer3:AddToSerialization("Name2")
            TestReplicatedContainer2:AddToSerialization("TestTable")
            TestReplicatedContainer1.Name2 = "Test1"
            TestReplicatedContainer2.Name2 = "Test2"
            TestReplicatedContainer2.TestTable = {TestReplicatedContainer1, "Test", TestReplicatedContainer3} :: {any}
            expect(TestReplicatedContainer1:Serialize()).to.deepEqual({Children = {__KeysToDecode = {1}, Data = {-3}}, Name = "ReplicatedContainer", Name2 = "Test1"})
            expect(TestReplicatedContainer2:Serialize()).to.deepEqual({Children = {}, TestTable = {__KeysToDecode = {1, 3}, Data = {-1, "Test", -3} :: {any}}, Name = "ReplicatedContainer", Name2 = "Test2"})
            expect(TestReplicatedContainer3:Serialize()).to.deepEqual({__KeysToDecode = {"Parent"}, Data = {Children = {}, Parent = -1, Name = "ReplicatedContainer"}})


            --Set the parent of a object not in the object registry and assert it isn't serialized.
            TestReplicatedContainer4.Parent = TestReplicatedContainer1
            expect(TestReplicatedContainer1:Serialize()).to.deepEqual({Children = {__KeysToDecode = {1}, Data = {-3}}, Name = "ReplicatedContainer", Name2 = "Test1"})
        end)

        it("should find child elements.", function()
            --Prepapre the test replicated containers.
            TestReplicatedContainer1.Name = "Test1"
            TestReplicatedContainer2.Name = "Test2"
            TestReplicatedContainer3.Name = "Test3"
            TestReplicatedContainer2.Parent = TestReplicatedContainer1
            TestReplicatedContainer3.Parent = TestReplicatedContainer1

            --Test FindFirstChildBy.
            expect(TestReplicatedContainer1:FindFirstChildBy("Name", "Test1")).to.equal(nil)
            expect(TestReplicatedContainer1:FindFirstChildBy("Name", "Test2")).to.equal(TestReplicatedContainer2)
            expect(TestReplicatedContainer1:FindFirstChildBy("Name", "Test3")).to.equal(TestReplicatedContainer3)
            expect(TestReplicatedContainer1:FindFirstChildBy("Name", "Test4")).to.equal(nil)
            expect(TestReplicatedContainer1:FindFirstChildBy("UnknownProperty", "Test4")).to.equal(nil)

            --Test WaitForChildBy.
            task.spawn(function()
                task.wait()
                TestReplicatedContainer3.Name = "Test4"
            end)
            expect(TestReplicatedContainer1:WaitForChildBy("Name", "Test2")).to.equal(TestReplicatedContainer2)
            expect(TestReplicatedContainer1:WaitForChildBy("Name", "Test4")).to.equal(TestReplicatedContainer3)
        end)
    end)
end