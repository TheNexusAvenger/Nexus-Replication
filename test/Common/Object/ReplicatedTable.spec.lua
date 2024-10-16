--Tests the ReplicatedTable class.
--!strict
--$NexusUnitTestExtensions

local NexusReplicationModule = game:GetService("ReplicatedStorage"):WaitForChild("NexusReplication")
local ReplicatedTable = require(NexusReplicationModule:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedTable"))

return function()
    local TestReplicatedTable = nil
    beforeEach(function()
        TestReplicatedTable = ReplicatedTable.new()
    end)
    afterEach(function()
        TestReplicatedTable:Destroy()
    end)

    describe("A ReplicatedTable instance", function()
        it("should add and remove values.", function()
            --Add several keys.
            TestReplicatedTable:Add("Test1")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1"})
            TestReplicatedTable:Add("Test2")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2"})
            TestReplicatedTable:Add("Test4")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test4"})
            TestReplicatedTable:Add("Test3", 3)
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test3", "Test4"})

            --Test setting values.
            TestReplicatedTable:Set(3,"Test5")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test5", "Test4"})
            TestReplicatedTable:Set(5,"Test6")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test5", "Test4", "Test6"})

            --Test removing values.
            TestReplicatedTable:Remove("Test5")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test4", "Test6"})
            TestReplicatedTable:Remove("Test5")
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test4", "Test6"})
            TestReplicatedTable:RemoveAt(3)
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2", "Test6"})
            TestReplicatedTable:RemoveAt(3)
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2"})
            TestReplicatedTable:RemoveAt(3)
            expect(TestReplicatedTable.Table).to.deepEqual({"Test1", "Test2"})
        end)

        it("should get values.", function()
            --Add several keys.
            TestReplicatedTable:Add("Test1")
            TestReplicatedTable:Add("Test2")
            TestReplicatedTable:Add("Test3")
            TestReplicatedTable:Add("Test4")

            --Test getting values.
            expect(TestReplicatedTable:Get(1)).to.equal("Test1")
            expect(TestReplicatedTable:Get(2)).to.equal("Test2")
            expect(TestReplicatedTable:Get(3)).to.equal("Test3")
            expect(TestReplicatedTable:Get(4)).to.equal("Test4")
            expect(TestReplicatedTable:Get(5)).to.equal(nil)
            expect(TestReplicatedTable:Get(0)).to.equal(nil)

            --Test getting all values.
            expect(TestReplicatedTable:GetAll()).to.deepEqual({"Test1", "Test2", "Test3", "Test4"})
            expect(TestReplicatedTable:GetAll(function(Value)
                return Value == "Test2" or Value == "Test3"
            end)).to.deepEqual({"Test2", "Test3"})
        end)

        it("should find values.", function()
            --Add several keys.
            TestReplicatedTable:Add("Test1")
            TestReplicatedTable:Add("Test2")
            TestReplicatedTable:Add("Test3")
            TestReplicatedTable:Add("Test4")

            --Test finding values.
            expect(TestReplicatedTable:Find("Test1")).to.equal(1)
            expect(TestReplicatedTable:Find("Test3")).to.equal(3)
            expect(TestReplicatedTable:Find("Test5")).to.equal(nil)
            expect(TestReplicatedTable:Find(nil)).to.equal(nil)

            --Test checking for contained values.
            expect(TestReplicatedTable:Contains("Test1")).to.equal(true)
            expect(TestReplicatedTable:Contains("Test3")).to.equal(true)
            expect(TestReplicatedTable:Contains("Test5")).to.equal(false)
            expect(TestReplicatedTable:Contains(nil)).to.equal(false)
        end)
    end)
end