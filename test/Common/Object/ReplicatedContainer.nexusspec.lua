--[[
TheNexusAvenger

Tests the ReplicatedContainer class.
--]]

local NexusUnitTesting = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedContainerTest = NexusUnitTesting.UnitTest:Extend()
local NexusReplication = nil
local ReplicatedContainer = nil



--[[
Sets up the test.
--]]
function ReplicatedContainerTest:Setup()
    NexusReplication = require(ReplicatedStorage:WaitForChild("NexusReplication"))
    ReplicatedContainer = NexusReplication:GetResource("Common.Object.ReplicatedContainer")

    local ObjectRegistry = {}
    NexusReplication:GetObjectReplicator().ObjectRegistry = ObjectRegistry
    self.CuT1 = ReplicatedContainer.new()
    self.CuT1.Id = -1
    ObjectRegistry[-1] = self.CuT1
    self.CuT2 = ReplicatedContainer.new()
    self.CuT2.Id = -2
    ObjectRegistry[-2] = self.CuT2
    self.CuT3 = ReplicatedContainer.new()
    self.CuT3.Id = -3
    ObjectRegistry[-3] = self.CuT3
    self.CuT4 = ReplicatedContainer.new()
    self.CuT4.Id = -4
end

--[[
Tears down the test.
--]]
function ReplicatedContainerTest:Teardown()
    self.CuT1:Destroy()
    self.CuT2:Destroy()
    self.CuT3:Destroy()
    NexusReplication:ClearInstances()
end

--[[
Tests the EncodeIds method.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedContainerTest.new("EncodeIds"):SetRun(function(self)
    --Test encoding non-tables.
    self:AssertEquals(ReplicatedContainer.EncodeIds(1),1)
    self:AssertEquals(ReplicatedContainer.EncodeIds("Test"),"Test")

    --Test encoding objects.
    self:AssertEquals(ReplicatedContainer.EncodeIds(self.CuT1),{__KeyToDecode=-1})
    self:AssertEquals(ReplicatedContainer.EncodeIds(self.CuT4),nil)

    --Test encoding tables.
    self:AssertEquals(ReplicatedContainer.EncodeIds({1,2,3}),{1,2,3})
    self:AssertEquals(ReplicatedContainer.EncodeIds({self.CuT1,self.CuT2}),{__KeysToDecode={1,2},Data={-1,-2}})
    self:AssertEquals(ReplicatedContainer.EncodeIds({self.CuT1,self.CuT2,self.CuT3,self.CuT4}),{__KeysToDecode={1,2,3},Data={-1,-2,-3}})
    self:AssertEquals(ReplicatedContainer.EncodeIds({{self.CuT1,self.CuT2},{self.CuT2,self.CuT3}}),{{__KeysToDecode={1,2},Data={-1,-2}},{__KeysToDecode={1,2},Data={-2,-3}}})
    self:AssertEquals(ReplicatedContainer.EncodeIds({Key1=self.CuT1,Key2=self.CuT2,Key3={self.CuT1,self.CuT3}}),{__KeysToDecode={"Key1","Key2"},Data={Key1=-1,Key2=-2,Key3={__KeysToDecode={1,2},Data={-1,-3}}}})
end))

--[[
Tests the DecodeIds method.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedContainerTest.new("DecodeIds"):SetRun(function(self)
    --Test decoding non-tables.
    self:AssertEquals(ReplicatedContainer.DecodeIds(1),1)
    self:AssertEquals(ReplicatedContainer.DecodeIds("Test"),"Test")

    --Test decoding objects.
    --Testing with id -4 will infinitely yield since it will wait for the object to exist.
    self:AssertEquals(ReplicatedContainer.DecodeIds({__KeyToDecode=-1}),self.CuT1)
    self:AssertEquals(ReplicatedContainer.DecodeIds({__KeyToDecode=-2}),self.CuT2)

    --Test decoding tables.
    self:AssertEquals(ReplicatedContainer.DecodeIds({1,2,3}),{1,2,3})
    self:AssertEquals(ReplicatedContainer.DecodeIds({__KeysToDecode={1,2},Data={-1,-2}}),{self.CuT1,self.CuT2})
    self:AssertEquals(ReplicatedContainer.DecodeIds({{__KeysToDecode={1,2},Data={-1,-2}},{__KeysToDecode={1,2},Data={-2,-3}}}),{{self.CuT1,self.CuT2},{self.CuT2,self.CuT3}})
    self:AssertEquals(ReplicatedContainer.DecodeIds({__KeysToDecode={"Key1","Key2"},Data={Key1=-1,Key2=-2,Key3={__KeysToDecode={1,2},Data={-1,-3}}}}),{Key1=self.CuT1,Key2=self.CuT2,Key3={self.CuT1,self.CuT3}})
end))

--[[
Tests the FromSerializedData method.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedContainerTest.new("FromSerializedData"):SetRun(function(self)
    --Deserialize the test object.
    local Object = ReplicatedContainer.FromSerializedData({
        __KeysToDecode = {"Parent"},
        Data = {
            Name = "TestName",
            Parent = -2,
            Children = {
                __KeysToDecode = {1,2},
                Data = {
                    -3,-1
                },
            },
            UnknownProperty = "Test",
        },
    },-5)

    --Create the test object.
    self:AssertEquals(Object.Name,"TestName")
    self:AssertEquals(Object.Parent,self.CuT2)
    self:AssertEquals(Object.Children[1],self.CuT3)
    self:AssertEquals(Object.Children[2],self.CuT1)
    self:AssertNil(Object.Children[3])
    self:AssertNil(Object.UnknownProperty)
end))

--[[
Tests the Serialize method.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedContainerTest.new("Serialize"):SetRun(function(self)
    --Assert the base objects serialize.
    self:AssertEquals(self.CuT1:Serialize(),{Children={},Name="ReplicatedContainer"})
    self:AssertEquals(self.CuT2:Serialize(),{Children={},Name="ReplicatedContainer"})
    self:AssertEquals(self.CuT3:Serialize(),{Children={},Name="ReplicatedContainer"})

    --Set the parents and assert the serialization is correct.
    self.CuT2.Parent = self.CuT1
    self.CuT3.Parent = self.CuT2
    self:AssertEquals(self.CuT1:Serialize(),{Children={__KeysToDecode={1},Data={-2}},Name="ReplicatedContainer"})
    self:AssertEquals(self.CuT2:Serialize(),{__KeysToDecode = {"Parent"},Data={Children={__KeysToDecode = {1},Data={-3}},Parent=-1,Name="ReplicatedContainer"}})
    self:AssertEquals(self.CuT3:Serialize(),{__KeysToDecode = {"Parent"},Data={Children={},Parent=-2,Name="ReplicatedContainer"}})
    self.CuT3.Parent = self.CuT1
    self:AssertEquals(self.CuT1:Serialize(),{Children={__KeysToDecode={1,2},Data={-2,-3}},Name="ReplicatedContainer"})
    self:AssertEquals(self.CuT2:Serialize(),{__KeysToDecode = {"Parent"},Data={Children={},Parent=-1,Name="ReplicatedContainer"}})
    self:AssertEquals(self.CuT3:Serialize(),{__KeysToDecode = {"Parent"},Data={Children={},Parent=-1,Name="ReplicatedContainer"}})
    self.CuT2.Parent = nil
    self:AssertEquals(self.CuT1:Serialize(),{Children={__KeysToDecode={1},Data={-3}},Name="ReplicatedContainer"})
    self:AssertEquals(self.CuT2:Serialize(),{Children={},Name="ReplicatedContainer"})
    self:AssertEquals(self.CuT3:Serialize(),{__KeysToDecode = {"Parent"},Data={Children={},Parent=-1,Name="ReplicatedContainer"}})

    --Add a raw property and assert the serialization is correct.
    self.CuT1:AddToSerialization("Name2")
    self.CuT2:AddToSerialization("Name2")
    self.CuT3:AddToSerialization("Name2")
    self.CuT2:AddToSerialization("TestTable")
    self.CuT1.Name2 = "Test1"
    self.CuT2.Name2 = "Test2"
    self.CuT2.TestTable = {self.CuT1,"Test",self.CuT3}
    self:AssertEquals(self.CuT1:Serialize(),{Children={__KeysToDecode={1},Data={-3}},Name="ReplicatedContainer",Name2="Test1"})
    self:AssertEquals(self.CuT2:Serialize(),{Children={},TestTable={__KeysToDecode={1,3},Data={-1,"Test",-3}},Name="ReplicatedContainer",Name2="Test2"})
    self:AssertEquals(self.CuT3:Serialize(),{__KeysToDecode = {"Parent"},Data={Children={},Parent=-1,Name="ReplicatedContainer"}})

    --Set the parent of a object not in the object registry and assert it isn't serialized.
    self.CuT4.Parent = self.CuT1
    self:AssertEquals(self.CuT1:Serialize(),{Children={__KeysToDecode={1},Data={-3}},Name="ReplicatedContainer",Name2="Test1"})
end))

--[[
Tests the FindFirstChildBy and WaitForChildBy methods.
--]]
NexusUnitTesting:RegisterUnitTest(ReplicatedContainerTest.new("FindFirstChildBy"):SetRun(function(self)
    --Prepapre the components under testing.
    self.CuT1.Name = "Test1"
    self.CuT2.Name = "Test2"
    self.CuT3.Name = "Test3"
    self.CuT2.Parent = self.CuT1
    self.CuT3.Parent = self.CuT1

    --Test FindFirstChildBy.
    self:AssertEquals(self.CuT1:FindFirstChildBy("Name","Test1"),nil)
    self:AssertEquals(self.CuT1:FindFirstChildBy("Name","Test2"),self.CuT2)
    self:AssertEquals(self.CuT1:FindFirstChildBy("Name","Test3"),self.CuT3)
    self:AssertEquals(self.CuT1:FindFirstChildBy("Name","Test4"),nil)
    self:AssertEquals(self.CuT1:FindFirstChildBy("UnknownProperty","Test4"),nil)

    --Test WaitForChildBy.
    coroutine.wrap(function()
        wait()
        self.CuT3.Name = "Test4"
    end)()
    self:AssertEquals(self.CuT1:WaitForChildBy("Name","Test2"),self.CuT2)
    self:AssertEquals(self.CuT1:WaitForChildBy("Name","Test4"),self.CuT3)
end))



return true