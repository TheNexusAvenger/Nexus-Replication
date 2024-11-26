--Loads a command in Nexus Admin to view the dumped objects.
--Must be called on the client and server.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ObjectReplicator = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("ObjectReplication"))
local ObjectReplicatorInstance = ObjectReplicator.GetInstance()
local ObjectRegistry = ObjectReplicatorInstance.ObjectRegistry
local DisposeObjectRegistry = ObjectReplicatorInstance.DisposeObjectRegistry



--[[
Dumps an object's information.
--]]
local function DumpObject(Object: ObjectReplicator.StubbedReplicatableInstance, AddPrint: (string) -> (), AddWarning: (string) -> (), AddIgnore: (string) -> ()): ()
    --Output the name.
    AddPrint(`     Object {Object.Id} ({Object.Type})`)

    --Output the properties.
    for _, PropertyName in Object.SerializedProperties or {} :: {string} do
        local Value = (Object :: any)[PropertyName]
        if typeof(Value) == "table" and Value.Id and Value.SerializedProperties then
            local Id = Value.Id
            if ObjectRegistry[Id] then
                AddPrint(`         {PropertyName} (ReplicatedContainer): {Id}`)
            elseif DisposeObjectRegistry[Id] then
                AddWarning(`         {PropertyName} (ReplicatedContainer): {Id} (Disposed but not garbage collected)`)
            else
                AddWarning(`         {PropertyName} (ReplicatedContainer): {Id} (Garbage collected)`)
            end
        else
            if typeof(Value) == "table" then
                AddPrint(`         {PropertyName} (Table):`)
                for Index, SubObject in Value do
                    if typeof(SubObject) == "table" and SubObject.Id and SubObject.SerializedProperties then
                        local Id = SubObject.Id
                        if ObjectRegistry[Id] then
                            AddPrint(`           {Index} (ReplicatedContainer): {Id}`)
                        elseif DisposeObjectRegistry[Id] then
                            AddWarning(`           {Index} (ReplicatedContainer): {Id} (Disposed but not garbage collected)`)
                        else
                            AddWarning(`           {Index} (ReplicatedContainer): {Id} (Garbage collected)`)
                        end
                    else
                        AddIgnore(`           {Index} (Other): {SubObject or "nil"}`)
                    end
                end
            else
                AddIgnore(`         {PropertyName} (Other): {Value or "nil"}`)
            end
        end
    end
end

--[[
Dumps a table of objects.
--]]
local function DumpObjectTable(Objects: {ObjectReplicator.StubbedReplicatableInstance}, AddPrint: (string) -> (), AddWarning: (string) -> (), AddIgnore: (string) -> ()): ()
    --Sort the objects by id.
    local SortedObjects = {}
    for _, Object in Objects do
        table.insert(SortedObjects, Object)
    end
    table.sort(SortedObjects,function(a: any, b: any)
        return a.Id < b.Id
    end)

    --Dump the objects.
    for _, Object in SortedObjects do
        DumpObject(Object, AddPrint, AddWarning, AddIgnore)
    end
end

--[[
Builds the output for the object jump.
--]]
local function BuildObjectDump(): {{[string]: any}}
    --Build and return the object dump.
    local Lines = {} :: {{[string]: any}}
    local function AddPrint(Line)
        table.insert(Lines,{Text=Line,Type="Print"})
    end
    local function WarnPrint(Line)
        table.insert(Lines,{Text=Line,Type="Warn"})
    end
    local function AddIgnore(Line)
        table.insert(Lines,{Text=Line,Type="Ignore"})
    end
    AddPrint(`OBJECT DUMP ({Players.LocalPlayer and Players.LocalPlayer.Name or "Server"})`)
    AddPrint("   Object Registry (kept until manually destroyed):")
    DumpObjectTable(ObjectRegistry, AddPrint, WarnPrint, AddIgnore)

    --Dump the disposed objects.
    local DisposedObjectsExist = false
    for _, _ in DisposeObjectRegistry do
        DisposedObjectsExist = true
        break
    end
    if DisposedObjectsExist then
        WarnPrint("   Disposed Object Registry (kept until de-referenced):")
        DumpObjectTable(DisposeObjectRegistry, AddPrint, WarnPrint, AddIgnore)
    end
    return Lines
end

--[[
Loads the command in Nexus Admin.
--]]
local function LoadNexusAdminCommand(NexusAdminModule: any): ()
    --Load Nexus Admin.
    local NexusAdmin = require(NexusAdminModule) :: any
    if RunService:IsServer() then
        while not NexusAdmin:GetAdminLoaded() do
            task.wait()
        end
    end

    --Get or create the RemoteFunction.
    local CommandRun = function() end
    if RunService:IsClient() then
        local GetObjectDump = NexusAdmin.EventContainer:WaitForChild("NexusReplicationGetObjectDump")
        CommandRun = function(_: any, _: any, TargetPlayer: {Player}?)
            --Display the text window.
            local Window = NexusAdmin.Window:CreateWindow(`Object Dump - {TargetPlayer and TargetPlayer[1].Name or "Server"}`)
            local TextList = Window:AddTextList()
            TextList:EnableSearching()

            local function UpdateText()
                local Lines = {}
                for _, Line in GetObjectDump:InvokeServer(TargetPlayer and TargetPlayer[1]) :: {{[string]: any}} do
                    table.insert(Lines, {Text = Line.Text, TextColor3 = ((Line.Type == "Warn" and Color3.fromRGB(255, 153, 0)) or (Line.Type == "Ignore" and Color3.fromRGB(178, 178, 178)) or Color3.fromRGB(255, 255, 255))})
                end
                TextList:SetLines(Lines)
            end

            task.spawn(UpdateText)
            Window:EnableRefreshing(UpdateText)
            Window:EnableClosing()
            Window:EnableResizing()
            Window:Show()
        end

        GetObjectDump.OnClientInvoke = function()
            return BuildObjectDump()
        end
    else
        local GetObjectDump = Instance.new("RemoteFunction")
        GetObjectDump.Name = "NexusReplicationGetObjectDump"
        GetObjectDump.Parent = NexusAdmin.EventContainer

        GetObjectDump.OnServerInvoke = function(Player: Player, TargetPlayer: Player?)
            if not NexusAdmin.Authorization:IsPlayerAuthorized(Player, 0) then
                return {Text = "Unauthorized", Type = "Warn"}
            end
            if TargetPlayer then
                return GetObjectDump:InvokeClient(TargetPlayer)
            else
                return BuildObjectDump()
            end
        end
    end

    --Add the command to the registry.
    NexusAdmin.Registry:LoadCommand({
        Keyword = "dumpobjects",
        Prefix = NexusAdmin.Configuration.CommandPrefix,
        Category = "NexusReplicationDebug",
        Description = "Dumps the replicated objects of Nexus Replication.",
        AdminLevel = 0,
        Arguments = {
            {
                Type = "nexusAdminPlayers",
                Name = "Player",
                Description = "Optional players to view the object dump of. The server is shown if no player is specified.",
                Optional = true,
            },
        },
        Run = CommandRun,
    } :: any)
end

--[[
Sets up the command with Nexus Admin.
--]]
return function(): ()
    task.spawn(function()
        local Service = (RunService:IsClient() and ReplicatedStorage or ServerScriptService)
        local ModuleName = (RunService:IsClient() and "NexusAdminClient" or "NexusAdmin")
        LoadNexusAdminCommand(Service:WaitForChild(ModuleName))
    end)
end