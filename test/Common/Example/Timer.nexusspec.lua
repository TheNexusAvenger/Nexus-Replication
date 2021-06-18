--[[
TheNexusAvenger

Tests the Timer class.
--]]

local NexusUnitTesting = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimerTest = NexusUnitTesting.UnitTest:Extend()
local NexusReplication = require(ReplicatedStorage:WaitForChild("NexusReplication"))
local Timer = NexusReplication:GetResource("Example.Timer")



--[[
Sets up the test.
--]]
function TimerTest:Setup()
    self.MockTime = 0
    self.CuT = Timer.new()
    NexusReplication:GetObjectReplicator().GetServerTime(function()
        return self.MockTime
    end)
end

--[[
Tears down the test.
--]]
function TimerTest:Teardown()
    self.CuT:Destroy()
    NexusReplication:ClearInstances()
end

--[[
Tests the Start method.
--]]
NexusUnitTesting:RegisterUnitTest(TimerTest.new("Start"):SetRun(function(self)
    self.CuT:SetDuration(0.2)
    self:AssertEquals(self.CuT.State,"STOPPED")
    self:AssertClose(self.CuT:GetRemainingTime(),0.2,0.025)
    self.CuT:Start()
    self:AssertEquals(self.CuT.State,"ACTIVE")
    self:AssertClose(self.CuT:GetRemainingTime(),0.2,0.025)
    wait(0.1)
    self:AssertEquals(self.CuT.State,"ACTIVE")
    self:AssertClose(self.CuT:GetRemainingTime(),0.1,0.025)
    self.CuT:Start()
    wait(0.15)
    self:AssertClose(self.CuT:GetRemainingTime(),0,0.025)
    self:AssertEquals(self.CuT.State,"COMPLETE")
    self.CuT:Start()
    self:AssertEquals(self.CuT.State,"COMPLETE")
end))

--[[
Tests the Stop method.
--]]
NexusUnitTesting:RegisterUnitTest(TimerTest.new("Stop"):SetRun(function(self)
    self.CuT:SetDuration(0.2)
    self:AssertEquals(self.CuT.State,"STOPPED")
    self:AssertClose(self.CuT:GetRemainingTime(),0.2,0.025)
    self.CuT:Start()
    self:AssertEquals(self.CuT.State,"ACTIVE")
    self:AssertClose(self.CuT:GetRemainingTime(),0.2,0.025)
    wait(0.1)
    self.CuT:Stop()
    self:AssertEquals(self.CuT.State,"STOPPED")
    self:AssertClose(self.CuT:GetRemainingTime(),0.1,0.025)
    wait(0.1)
    self.CuT:Start()
    self:AssertEquals(self.CuT.State,"ACTIVE")
    self:AssertClose(self.CuT:GetRemainingTime(),0.1,0.025)
    wait(0.05)
    self:AssertEquals(self.CuT.State,"ACTIVE")
    self:AssertClose(self.CuT:GetRemainingTime(),0.05,0.025)
    wait(0.1)
    self:AssertEquals(self.CuT.State,"COMPLETE")
    self:AssertClose(self.CuT:GetRemainingTime(),0,0.025)
    self.CuT:Start()
    self:AssertEquals(self.CuT.State,"COMPLETE")
    self.CuT:Stop()
    self:AssertEquals(self.CuT.State,"COMPLETE")
    self:AssertClose(self.CuT:GetRemainingTime(),0,0.025)
end))

--[[
Tests the Complete method.
--]]
NexusUnitTesting:RegisterUnitTest(TimerTest.new("Complete"):SetRun(function(self)
    self.CuT:SetDuration(0.2)
    self:AssertEquals(self.CuT.State,"STOPPED")
    self.CuT:Start()
    wait(0.1)
    self.CuT:Complete()
    self:AssertEquals(self.CuT.State,"COMPLETE")
    self:AssertClose(self.CuT:GetRemainingTime(),0,0.025)
    wait(0.15)
    self:AssertEquals(self.CuT.State,"COMPLETE")
    self:AssertClose(self.CuT:GetRemainingTime(),0,0.025)
end))



return true