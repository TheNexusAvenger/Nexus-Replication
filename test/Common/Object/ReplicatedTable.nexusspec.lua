--[[
TheNexusAvenger

Tests the ReplicatedTable class.
--]]

local NexusUnitTesting = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedTableTest = NexusUnitTesting.UnitTest:Extend()
local NexusReplication = require(ReplicatedStorage:WaitForChild("NexusReplication"))
local ReplicatedTable = NexusReplication:GetResource("Common.Object.ReplicatedTable")



--[[
Sets up the test.
--]]
function ReplicatedTableTest:Setup()
    self.CuT = ReplicatedTable.new()
end

--[[
Tears down the test.
--]]
function ReplicatedTableTest:Teardown()
    self.CuT:Destroy()
    NexusReplication:ClearInstances()
end

--[[
Tests adding and removing values.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedTableTest.new("AddAndRemove"):SetRun(function(self)
    --Add several keys.
    self.CuT:Add("Test1")
    self:AssertEquals(self.CuT.Table,{"Test1"})
    self.CuT:Add("Test2")
    self:AssertEquals(self.CuT.Table,{"Test1","Test2"})
    self.CuT:Add("Test4")
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test4"})
    self.CuT:Add("Test3",3)
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test3","Test4"})

    --Test setting values.
    self.CuT:Set(3,"Test5")
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test5","Test4"})
    self.CuT:Set(5,"Test6")
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test5","Test4","Test6"})

    --Test removing values.
    self.CuT:Remove("Test5")
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test4","Test6"})
    self.CuT:Remove("Test5")
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test4","Test6"})
    self.CuT:RemoveAt(3)
    self:AssertEquals(self.CuT.Table,{"Test1","Test2","Test6"})
    self.CuT:RemoveAt(3)
    self:AssertEquals(self.CuT.Table,{"Test1","Test2"})
    self.CuT:RemoveAt(3)
    self:AssertEquals(self.CuT.Table,{"Test1","Test2"})
end))

--[[
Tests getting value.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedTableTest.new("Get"):SetRun(function(self)
    --Add several keys.
    self.CuT:Add("Test1")
    self.CuT:Add("Test2")
    self.CuT:Add("Test3")
    self.CuT:Add("Test4")

    --Test getting values.
    self:AssertEquals(self.CuT:Get(1),"Test1")
    self:AssertEquals(self.CuT:Get(2),"Test2")
    self:AssertEquals(self.CuT:Get(3),"Test3")
    self:AssertEquals(self.CuT:Get(4),"Test4")
    self:AssertNil(self.CuT:Get(5))
    self:AssertNil(self.CuT:Get(0))

    --Test getting all values.
    self:AssertEquals(self.CuT:GetAll(),{"Test1","Test2","Test3","Test4"})
    self:AssertEquals(self.CuT:GetAll(function(Value)
        return Value == "Test2" or Value == "Test3"
    end),{"Test2","Test3"})
end))

--[[
Tests finding values.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedTableTest.new("Find"):SetRun(function(self)
    --Add several keys.
    self.CuT:Add("Test1")
    self.CuT:Add("Test2")
    self.CuT:Add("Test3")
    self.CuT:Add("Test4")

    --Test finding values.
    self:AssertEquals(self.CuT:Find("Test1"),1)
    self:AssertEquals(self.CuT:Find("Test3"),3)
    self:AssertNil(self.CuT:Find("Test5"))
    self:AssertNil(self.CuT:Find(nil))

    --Test checking for contained values.
    self:AssertTrue(self.CuT:Contains("Test1"))
    self:AssertTrue(self.CuT:Contains("Test3"))
    self:AssertFalse(self.CuT:Contains("Test5"))
    self:AssertFalse(self.CuT:Contains(nil))
end))



return true