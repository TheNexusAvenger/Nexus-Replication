--Tests the ReplicatedContainer class.
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

    describe("A ReplicatedContainer instance", function()
        it("should register children.", function()
            local ChildAddedCalls = {}
            TestReplicatedContainer1.ChildAdded:Connect(function(Child)
                table.insert(ChildAddedCalls, Child)
            end)

            TestReplicatedContainer2.Parent = TestReplicatedContainer1
            task.wait()
            expect(#TestReplicatedContainer1.Children).to.equal(1)
            expect(TestReplicatedContainer1.Children[1]).to.equal(TestReplicatedContainer2)
            expect(#ChildAddedCalls).to.equal(1)
            expect(ChildAddedCalls[1]).to.equal(TestReplicatedContainer2)
        end)

        it("should register removed children.", function()
            local ChildAddedCalls = {}
            TestReplicatedContainer1.ChildRemoved:Connect(function(Child)
                table.insert(ChildAddedCalls, Child)
            end)

            TestReplicatedContainer2.Parent = TestReplicatedContainer1
            TestReplicatedContainer2.Parent = nil
            task.wait()
            expect(#TestReplicatedContainer1.Children).to.equal(0)
            expect(#ChildAddedCalls).to.equal(1)
            expect(ChildAddedCalls[1]).to.equal(TestReplicatedContainer2)
        end)

        it("should register destroyed children.", function()
            local ChildAddedCalls = {}
            TestReplicatedContainer1.ChildRemoved:Connect(function(Child)
                table.insert(ChildAddedCalls, Child)
            end)

            TestReplicatedContainer2.Parent = TestReplicatedContainer1
            TestReplicatedContainer2:Destroy()
            task.wait()
            expect(#TestReplicatedContainer1.Children).to.equal(0)
            expect(#ChildAddedCalls).to.equal(1)
            expect(ChildAddedCalls[1]).to.equal(TestReplicatedContainer2)
        end)

        it("should register changed parents.", function()
            local ChildAddedCalls = {}
            TestReplicatedContainer3.ChildAdded:Connect(function(Child)
                table.insert(ChildAddedCalls, Child)
            end)

            TestReplicatedContainer2.Parent = TestReplicatedContainer1
            TestReplicatedContainer2.Parent = TestReplicatedContainer3
            task.wait()
            expect(#TestReplicatedContainer1.Children).to.equal(0)
            expect(#TestReplicatedContainer3.Children).to.equal(1)
            expect(TestReplicatedContainer3.Children[1]).to.equal(TestReplicatedContainer2)
            expect(#ChildAddedCalls).to.equal(1)
            expect(ChildAddedCalls[1]).to.equal(TestReplicatedContainer2)
        end)

        it("should send signals.", function()
            local SentSignalName, SentSignalData = nil, nil
            TestReplicatedContainer1.ObjectReplicationIntegration = {
                SendSignal = function(_, Name, Data)
                    SentSignalName = Name
                    SentSignalData = Data
                end,
            } :: any

            TestReplicatedContainer1:SendSignal("TestName", "TestData")
            expect(SentSignalName).to.equal("TestName")
            expect(SentSignalData).to.equal("TestData")
        end)

        it("should listen to signals.", function()
            local SentSignalData = nil
            TestReplicatedContainer1:ListenToSignal("TestSignal", function(Data)
                SentSignalData = Data
            end)

            TestReplicatedContainer1:OnSignal("TestSignal", "TestData")
            expect(SentSignalData).to.equal("TestData")
        end)

        it("should find child elements by properties.", function()
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