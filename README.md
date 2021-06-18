# Nexus Replication
Nexus Replication provides a method for replicating custom
instances with custom properties. The system was initally
developed for round objects in
[Nexus Battles](https://github.com/thenexusAvenger/nexus-battles).

## Example
Using Nexus Battles as example, creating a round is a good
example of using Nexus Replication. The steps to use the system
include:
- Defining the custom class. For a round, containing a timer and
  table of players makes sense. A state may also make sense.
- Creating the round and parenting it somewhere so it can be
  accessed. Similar to `game`, Nexus Replication has a global
  container to store objects.
- Referencing the round on the client.

Creating the class is similar to Nexus Instance, although some
extra steps are required.

```lua
--ModuleScript: ReplicatedStorage.DemoRound
local NexusReplication = require(game:GetService("ReplicatedStorage"):WaitForChild("NexusReplication"))

local DemoRound = NexusReplication:GetResource("Common.Object.ReplicatedContainer"):Extend()
DemoRound:SetClassName("DemoRound")
NexusReplication:RegisterType("DemoRound",DemoRound)

--[[
Creates the round.
--]]
function DemoRound:__new()
    self:InitializeSuper()
    self.Name = "DemoRound"

    --Create the state.
    --For a module loaded on the client and server, this should only be done on the server.
    --Note that RegisterType allows any class, so it can be server-specific or client-specific.
    if NexusReplication:IsServer() then
        --For tables, ReplicatedTable is recommended to track changes.
        self.Players = NexusReplication:CreateObject("ReplicatedTable")
        --Timer is a built-in example class and can freely be used.
        self.Timer = NexusReplication:CreateObject("Timer")
        self.Timer:SetDuration(5)
    end
    self.State = "NOT_STARTED"

    --Add the objects to serialize.
    self:AddToSerialization("State")
    self:AddToSerialization("Players")
    self:AddToSerialization("Timer")

    --Connect the timer ending.
    if NexusReplication:IsServer() then
        self.Timer:GetPropertyChangedSignal("State"):Connect(function()
            if self.Timer.State == "COMPLETE" then
                self.State = "ENDED"
                print("Round ended!")
            end
        end)
    end
end

--[[
Starts the round.
--]]
function DemoRound:Start()
    if self.State ~= "NOT_STARTED" then return end
    self.State = "ACTIVE"
    self.Timer:Start()
    for _,Player in pairs(self.Players:GetAll()) do
        print("Round player: "..Player.DisplayName)
    end
end

return DemoRound
```

Creating the object is a bit more complicated compared to
Nexus Instance, but is similar to Roblox's `Instance`.
```lua
--Script: ServerScriptService.CreateRound

--Any classes that register themself must be done before
--creating them. This can be done anywhere, and is recommended
--to be centralized with a wrapper.
require(game:GetService("ReplicatedStorage"):WaitForChild("DemoRound"))

--Create the round.
local NexusReplication = require(game:GetService("ReplicatedStorage"):WaitForChild("NexusReplication"))
local Round = NexusReplication:CreateObject("DemoRound")
Round.Name = "MyRound"
Round.Parent = NexusReplication:GetGlobalContainer()

--Add and start the round after a player enters.
game:GetService("Players").PlayerAdded:Connect(function(Player)
    wait(5)
    Round.Players:Add(Player)
    Round:Start()
end)
```

And lastly, listening to the round on the client can be done
with the following:
```lua
--LocalScript: StarterPlayer.StarterPlayerScripts.RoundListener

--Any classes that register themself must be done before
--creating them. This can be done anywhere, and is recommended
--to be centralized with a wrapper.
require(game:GetService("ReplicatedStorage"):WaitForChild("DemoRound"))

--Get the round.
local NexusReplication = require(game:GetService("ReplicatedStorage"):WaitForChild("NexusReplication"))
local Round = NexusReplication:GetGlobalContainer():WaitForChildBy("Name","MyRound")

--Connect being added to the round.
Round.Players.ItemAdded:Connect(function(Player)
    print("Now in round: "..Player.DisplayName)
end)

--Connect the state changing.
Round:GetPropertyChangedSignal("State"):Connect(function()
    print("New round state: "..Round.State)
end)
print("Round state: "..Round.State)
```

The output for the code above should be similar to the following:
```
[Client] 00:00: Round state: NOT_STARTED
[Player] 00:05: Round player: Nexus
[Client] 00:05: Now in round: Nexus
[Client] 00:05: New round state: ACTIVE
[Client] 00:10: Round ended!
[Client] 00:10: New round state: ENDED
```

[`ReplicatedContainer`](src/Common/Object/ReplicatedContainer.lua) and
[`ReplicatedTable`](src/Common/Object/ReplicatedTable.lua) are the main
base classes that should be used with the system.
[`Timer`](src/Example/Timer.lua) also exists as an example and is used
in Nexus Battles.

## Contributing
Both issues and pull requests are accepted for this project.

## License
Nexus Button is available under the terms of the MIT 
Licence. See [LICENSE](LICENSE) for details.