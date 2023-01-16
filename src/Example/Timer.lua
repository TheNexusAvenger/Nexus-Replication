--[[
TheNexusAvenger

Manages a timer state.
--]]
--!strict

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local NexusReplication = require(script.Parent.Parent)
local ObjectReplication = NexusReplication:GetObjectReplicator()
local ReplicatedContainer = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedContainer"))

local Timer = ReplicatedContainer:Extend()
Timer:SetClassName("Timer")
NexusReplication:RegisterType("Timer", Timer)

export type Timer = {
    new: () -> (Timer),
    Extend: (self: Timer) -> (Timer),

    State: string,
    SetDuration: (self: Timer, Duration: number) -> (),
    Start: (self: Timer) -> (),
    Stop: (self: Timer) -> (),
    Complete: (self: Timer) -> (),
    GetRemainingTime: (self: Timer) -> (number),
} & Types.ReplicatedContainer



--[[
Creates the timer.
--]]
function Timer:__new(): ()
    ReplicatedContainer.__new(self)
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
function Timer:SetDuration(Duration: number): ()
    self.RemainingTimeFromStart = Duration
    if self.State == "COMPLETE" and Duration > 0 then
        self.State = "STOPPED"
    end
end

--[[
Starts the timer.
--]]
function Timer:Start(): ()
    if self.State ~= "STOPPED" then return end

    --Start the timer.
    local StartTime,RemainingTime = ObjectReplication:GetServerTime(),self.RemainingTimeFromStart
    self.StartTime = StartTime
    self.State = "ACTIVE"

    --Wait for the timer to finish.
    if NexusReplication:IsServer() then
        task.delay(RemainingTime, function()
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
function Timer:Stop(): ()
    if self.State ~= "ACTIVE" then return end
    self.State = "STOPPED"
    self.RemainingTimeFromStart = math.max(0,self.RemainingTimeFromStart - (ObjectReplication:GetServerTime() - self.StartTime))
end

--[[
Completes the timer.
--]]
function Timer:Complete(): ()
    if self.State == "COMPLETE" then return end
    self.State = "COMPLETE"
    self.RemainingTimeFromStart = 0
end

--[[
Returns the remaining time of the timer.
--]]
function Timer:GetRemainingTime(): number
    if self.State == "ACTIVE" then
        return math.max(0,self.RemainingTimeFromStart - (ObjectReplication:GetServerTime() - self.StartTime))
    else
        return self.RemainingTimeFromStart
    end
end



return (Timer :: any) :: Timer