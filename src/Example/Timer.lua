--[[
TheNexusAvenger

Manages a timer state.
--]]

local NexusReplication = require(script.Parent.Parent)

local ObjectReplication = NexusReplication:GetObjectReplicator()

local Timer = NexusReplication:GetResource("Common.Object.ReplicatedContainer"):Extend()
Timer:SetClassName("Timer")
Timer:AddFromSerializeData("Timer")
NexusReplication:GetObjectReplicator():RegisterType("Timer",Timer)



--[[
Creates the timer.
--]]
function Timer:__new()
    self:InitializeSuper()
    self.Name = "Timer"

    --Set up the state.
    self.State = "STOPPED"
    self.StartTime = 0
    self.RemainingTimeFromStart = 0
    self:AddToSerialization("State")
    self:AddToSerialization("StartTime")
    self:AddToSerialization("RemainingTimeFromStart")
end

--[[
Sets the timer duration.
--]]
function Timer:SetDuration(Duration)
    self.RemainingTimeFromStart = Duration
    if self.State == "COMPLETE" and Duration > 0 then
        self.State = "STOPPED"
    end
end

--[[
Starts the timer.
--]]
function Timer:Start()
    if self.State ~= "STOPPED" then return end

    --Start the timer.
    local StartTime,RemainingTime = ObjectReplication:GetServerTime(),self.RemainingTimeFromStart
    self.StartTime = StartTime
    self.State = "ACTIVE"

    --Wait for the timer to finish.
    if NexusReplication:IsServer() then
        delay(RemainingTime,function()
            if self.State == "ACTIVE" and self.StartTime == StartTime and self.RemainingTimeFromStart == RemainingTime then
                self.StartTime = ObjectReplication:GetServerTime()
                self.RemainingTimeFromStart = 0
                self.State = "COMPLETE"
            end
        end)
    end
end

--[[
Stops the timer.
--]]
function Timer:Stop()
    if self.State ~= "ACTIVE" then return end
    self.State = "STOPPED"
    self.RemainingTimeFromStart = math.max(0,self.RemainingTimeFromStart - (ObjectReplication:GetServerTime() - self.StartTime))
end

--[[
Completes the timer.
--]]
function Timer:Complete()
    if self.State == "COMPLETE" then return end
    self.State = "COMPLETE"
    self.RemainingTimeFromStart = 0
end

--[[
Returns the remaining time of the timer.
--]]
function Timer:GetRemainingTime()
    if self.State == "ACTIVE" then
        return math.max(0,self.RemainingTimeFromStart - (ObjectReplication:GetServerTime() - self.StartTime))
    else
        return self.RemainingTimeFromStart
    end
end



return Timer