--Manages a timer state.
--!strict

local NexusReplication = require(script.Parent.Parent)

local NexusInstance = require(script.Parent.Parent:WaitForChild("NexusInstance"))
local ObjectReplication = NexusReplication:GetObjectReplicator()
local ReplicatedContainer = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Object"):WaitForChild("ReplicatedContainer"))

local Timer = {}
Timer.__index = Timer
setmetatable(Timer, ReplicatedContainer)
NexusReplication:RegisterType("Timer", Timer)

export type TimerStatte = "STOPPED" | "ACTIVE" | "COMPLETE"
export type Timer = {
    State: TimerStatte,
    StartTime: number,
    RemainingTimeFromStart: number,
} & typeof(setmetatable({}, Timer)) & ReplicatedContainer.ReplicatedContainer
export type NexusInstanceTimer = NexusInstance.NexusInstance<Timer>



--[[
Creates the timer.
--]]
function Timer.__new(self: NexusInstanceTimer): ()
    ReplicatedContainer.__new(self :: any)
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
function Timer.SetDuration(self: NexusInstanceTimer, Duration: number): ()
    self.RemainingTimeFromStart = Duration
    if self.State == "COMPLETE" and Duration > 0 then
        self.State = "STOPPED"
    end
end

--[[
Starts the timer.
--]]
function Timer.Start(self: NexusInstanceTimer): ()
    if self.State ~= "STOPPED" then return end

    --Start the timer.
    local StartTime,RemainingTime = ObjectReplication:GetServerTime(),self.RemainingTimeFromStart
    self.StartTime = StartTime
    self.State = "ACTIVE"

    --Wait for the timer to finish.
    if NexusReplication:IsServer() then
        task.delay(RemainingTime, function()
            if (self.State :: TimerStatte) == "ACTIVE" and self.StartTime == StartTime and self.RemainingTimeFromStart == RemainingTime then
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
function Timer.Stop(self: NexusInstanceTimer): ()
    if self.State ~= "ACTIVE" then return end
    self.State = "STOPPED"
    self.RemainingTimeFromStart = math.max(0, self.RemainingTimeFromStart - (ObjectReplication:GetServerTime() - self.StartTime))
end

--[[
Completes the timer.
--]]
function Timer.Complete(self: NexusInstanceTimer): ()
    if self.State == "COMPLETE" then return end
    self.State = "COMPLETE"
    self.RemainingTimeFromStart = 0
end

--[[
Returns the remaining time of the timer.
--]]
function Timer.GetRemainingTime(self: NexusInstanceTimer): number
    if self.State == "ACTIVE" then
        return math.max(0, self.RemainingTimeFromStart - (ObjectReplication:GetServerTime() - self.StartTime))
    else
        return self.RemainingTimeFromStart
    end
end



return NexusInstance.ToInstance(Timer) :: NexusInstance.NexusInstanceClass<typeof(Timer), () -> (Timer)>