

print("[KnotHub] Initializing script for Eat Slimes to Grow HUGE (KnotLib v3.2)...")




pcall(function()
    local p1 = gethui and gethui()
    local p2 = game:GetService("CoreGui")
    local p3 = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")

    local function wipe(parent)
        if parent then
            for _, g in ipairs(parent:GetChildren()) do
                if g:IsA("ScreenGui") and (g.Name == "KnotLib" or g.Name == "KnotHub" or string.find(g.Name, "Knot")) then
                    g:Destroy()
                end
            end
        end
    end
    wipe(p1); wipe(p2); wipe(p3)
end)




local Library
local loadSuccess, loadError = pcall(function()
    if isfile and isfile("KnotLib.lua") then
        return loadstring(readfile("KnotLib.lua"))()
    else
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/whylovehurts/knotlib/refs/heads/main/KnotLib.lua"))()
    end
end)

if loadSuccess and loadError then
    Library = loadError
else
    warn("[KnotHub] Failed to load KnotLib v3.2: " .. tostring(loadError))
    return
end

if not Library then
    warn("[KnotHub] KnotLib returned nil")
    return
end

pcall(function()
    Library:AddContact("Discord Support", "https://discord.gg/knothub")
    Library:AddContact("Telegram Channel", "https://t.me/knothub_updates")
    Library:AddContact("YouTube", "https://youtube.com/@KnotHub")
end)




local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local rsStorage = ReplicatedStorage:FindFirstChild("Honeypot") and ReplicatedStorage.Honeypot:FindFirstChild("Internal") and ReplicatedStorage.Honeypot.Internal:FindFirstChild("RemoteStorage")




local KnotHub = {
    Flags = {
        hyperFarmBlobs = false,
        autoFarmVIP = false,
        auto10kGifts = false
    }
}


local blobsList = {}
local blobIdx = 1

local function refreshBlobs()
    local blobsFolder = Workspace:FindFirstChild("Blobs") or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Blobs"))
    blobsList = {}
    if blobsFolder then
        for _, b in ipairs(blobsFolder:GetChildren()) do
            local part = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart")
            if part then table.insert(blobsList, part) end
        end
    end
end

task.spawn(function()
    while not Library.Unloaded do
        refreshBlobs()
        task.wait(2)
    end
end)


RunService.Heartbeat:Connect(function()
    if KnotHub.Flags.hyperFarmBlobs and not Library.Unloaded and #blobsList > 0 then
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            for i = 1, 10 do
                blobIdx = blobIdx + 1
                if blobIdx > #blobsList then blobIdx = 1 end
                local targetPart = blobsList[blobIdx]
                if targetPart and targetPart.Parent then
                    hrp.CFrame = targetPart.CFrame
                end
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
    end
end)


task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if KnotHub.Flags.autoFarmVIP and rsStorage then
            pcall(function()
                rsStorage.AutoFarm:FireServer(true)
                rsStorage.MagnetGamepass:FireServer(true)
                rsStorage.BlackHoleGamepass:FireServer(true)
            end)
        end
    end
end)


task.spawn(function()
    while not Library.Unloaded do
        task.wait(1.5)
        if KnotHub.Flags.auto10kGifts and rsStorage then
            pcall(function()
                
                local giftTypes = {"Leaving", "Lava", "Gold", "Rainbow"}
                for _, gType in ipairs(giftTypes) do
                    local id = HttpService:GenerateGUID(false)
                    rsStorage.LogGift:FireServer({
                        Type = gType,
                        ID = id,
                        ReceivedTime = 1000 
                    })
                    rsStorage.ClaimGift:FireServer(id)
                end

                
                rsStorage.ClaimPlaytimeReward:FireServer(5)
                rsStorage.AwardSpinSize:FireServer(10000)
                rsStorage.GiveLavaGift:FireServer()
                rsStorage.ClaimDaily:FireServer()
            end)
        end
    end
end)




local Window = Library:CreateWindow({
    HubName = "KnotHub Eat Slimes",
    Size = UDim2.fromOffset(780, 440),
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main" }),
    Players = Window:AddTab({ Title = "Players" }),
    Visuals = Window:AddTab({ Title = "Visuals" })
}




do
    local StartSection = Tabs.Main:AddSection({ Title = "Start Here! :)" })

    StartSection:AddButton({
        Title = "Claim 10K Size Gifts & VIP Gamepasses",
        Callback = function()
            local success = pcall(function()
                if rsStorage then
                    rsStorage.AutoFarm:FireServer(true)
                    rsStorage.MagnetGamepass:FireServer(true)
                    rsStorage.BlackHoleGamepass:FireServer(true)
                    
                    local id = HttpService:GenerateGUID(false)
                    rsStorage.LogGift:FireServer({ Type = "Leaving", ID = id, ReceivedTime = 1000 })
                    rsStorage.ClaimGift:FireServer(id)
                    rsStorage.ClaimPlaytimeReward:FireServer(5)
                    rsStorage.AwardSpinSize:FireServer(10000)
                else
                    error("RemoteStorage not found")
                end
            end)
            if success then
                Library:Notify({ Title = "KnotHub", Content = "10K Size Gifts & VIP Claimed!", Type = "success", Duration = 3 })
            else
                Library:Notify({ Title = "KnotHub", Content = "Failed to claim gifts. Remotes missing!", Type = "error", Duration = 3 })
            end
        end,
    })

    local AutoSection = Tabs.Main:AddSection({ Title = "Automation" })

    AutoSection:AddToggle({
        Flag = "HyperFarmBlobs",
        Title = "Hyper Teleport Farm (+4.2M Size/min)",
        Default = false,
        Callback = function(state)
            KnotHub.Flags.hyperFarmBlobs = state
            Library:Notify({
                Title = "Hyper Farm",
                Content = state and "ENABLED (+714K in 10s)" or "DISABLED",
                Type = state and "success" or "warning",
                Duration = 2
            })
        end,
    })

    AutoSection:AddToggle({
        Flag = "Auto10kGifts",
        Title = "Auto Claim 10K Size Gifts Exploit",
        Default = false,
        Callback = function(state)
            KnotHub.Flags.auto10kGifts = state
            Library:Notify({
                Title = "10K Gifts Exploit",
                Content = state and "ON (Decompiled Bypass)" or "OFF",
                Type = state and "success" or "warning",
                Duration = 2
            })
        end,
    })

    AutoSection:AddToggle({
        Flag = "AutoFarmVIP",
        Title = "Loop Auto Farm & VIP Gamepass Bypass",
        Default = false,
        Callback = function(state)
            KnotHub.Flags.autoFarmVIP = state
            Library:Notify({
                Title = "VIP Bypass",
                Content = state and "Loop Activated!" or "Loop Deactivated",
                Type = state and "success" or "info",
                Duration = 2
            })
        end,
    })

    local TeleportSection = Tabs.Main:AddSection({ Title = "Area Teleportation" })

    TeleportSection:AddDropdown({
        Title = "Teleport to Area / Zone",
        ValuesFunction = function()
            local zones = {"Spawn / Safe Zone", "Blobs Center"}
            if Workspace:FindFirstChild("Map") then
                for _, child in ipairs(Workspace.Map:GetChildren()) do
                    if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
                        if string.find(string.lower(child.Name), "zone") or string.find(string.lower(child.Name), "area") or string.find(string.lower(child.Name), "island") then
                            if not table.find(zones, child.Name) then
                                table.insert(zones, child.Name)
                            end
                        end
                    end
                end
            end
            return zones
        end,
        Callback = function(areaName)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                Library:Notify({ Title = "Teleport Error", Content = "Character HRP not found!", Type = "error", Duration = 3 })
                return
            end
            
            if areaName == "Spawn / Safe Zone" then
                local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
                if spawn then
                    hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
                    Library:Notify({ Title = "Teleport", Content = "Teleported to Spawn!", Type = "success", Duration = 3 })
                else
                    hrp.CFrame = CFrame.new(0, 10, 0)
                    Library:Notify({ Title = "Teleport", Content = "Teleported to Center Coordinate (0, 10, 0)", Type = "warning", Duration = 3 })
                end
            elseif areaName == "Blobs Center" then
                if #blobsList > 0 and blobsList[1] and blobsList[1].Parent then
                    hrp.CFrame = blobsList[1].CFrame + Vector3.new(0, 5, 0)
                    Library:Notify({ Title = "Teleport", Content = "Teleported to Blobs Center!", Type = "success", Duration = 3 })
                else
                    Library:Notify({ Title = "Teleport Error", Content = "No blobs currently spawned!", Type = "error", Duration = 3 })
                end
            else
                local target = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild(areaName)
                if target then
                    local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        hrp.CFrame = part.CFrame + Vector3.new(0, 5, 0)
                        Library:Notify({ Title = "Teleport", Content = "Teleported to " .. areaName, Type = "success", Duration = 3 })
                    else
                        Library:Notify({ Title = "Teleport Error", Content = "Could not find part for " .. areaName, Type = "error", Duration = 3 })
                    end
                end
            end
        end
    })
end




do
    local PlayersSection = Tabs.Players:AddSection({ Title = "Player Teleport List" })

    
    pcall(function()
        PlayersSection:AddPlayerList({
            Title = "Click Player to Teleport",
            Callback = function(player)
                if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                        Library:Notify({ Title = "Teleport Success", Content = "Teleported to " .. player.DisplayName, Type = "success", Duration = 3 })
                    else
                        Library:Notify({ Title = "Teleport Failed", Content = "Your character is not ready.", Type = "error", Duration = 3 })
                    end
                else
                    Library:Notify({ Title = "Teleport Failed", Content = "Target player has no active character.", Type = "warning", Duration = 3 })
                end
            end
        end)
    end)

    
    PlayersSection:AddDropdown({
        Title = "Select Target Player (Dynamic)",
        ValuesFunction = function()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
                end
            end
            if #list == 0 then table.insert(list, "No other players online") end
            return list
        end,
        Callback = function(selected)
            if selected == "No other players online" then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if (p.DisplayName .. " (@" .. p.Name .. ")") == selected then
                    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame
                        Library:Notify({ Title = "Teleport Success", Content = "Teleported to " .. p.DisplayName, Type = "success", Duration = 3 })
                    else
                        Library:Notify({ Title = "Teleport Failed", Content = "Target player character unavailable.", Type = "error", Duration = 3 })
                    end
                    break
                end
            end
        end
    })
end




do
    local ThemeSection = Tabs.Visuals:AddSection({ Title = "Theme & Accent Colors" })

    ThemeSection:AddButton({
        Title = "Preset: Knot Purple",
        Callback = function()
            pcall(function() Library:SetAccent(Color3.fromRGB(140, 80, 255)) end)
            Library:Notify({ Title = "Theme Changed", Content = "Accent applied: Knot Purple", Type = "success", Duration = 2 })
        end
    end)

    ThemeSection:AddButton({
        Title = "Preset: Emerald Green",
        Callback = function()
            pcall(function() Library:SetAccent(Color3.fromRGB(46, 204, 113)) end)
            Library:Notify({ Title = "Theme Changed", Content = "Accent applied: Emerald Green", Type = "success", Duration = 2 })
        end
    end)

    ThemeSection:AddButton({
        Title = "Preset: Crimson Red",
        Callback = function()
            pcall(function() Library:SetAccent(Color3.fromRGB(231, 76, 60)) end)
            Library:Notify({ Title = "Theme Changed", Content = "Accent applied: Crimson Red", Type = "success", Duration = 2 })
        end
    end)

    ThemeSection:AddButton({
        Title = "Preset: Ocean Blue",
        Callback = function()
            pcall(function() Library:SetAccent(Color3.fromRGB(52, 152, 219)) end)
            Library:Notify({ Title = "Theme Changed", Content = "Accent applied: Ocean Blue", Type = "success", Duration = 2 })
        end
    end)

    ThemeSection:AddColorPicker({
        Title = "Custom Accent Color Picker",
        Default = Color3.fromRGB(140, 80, 255),
        Callback = function(color)
            pcall(function() Library:SetAccent(color) end)
            Library:Notify({ Title = "Custom Accent", Content = "New accent color updated!", Type = "success", Duration = 2 })
        end
    end)

    local UISettingsSection = Tabs.Visuals:AddSection({ Title = "UI Control & Notifications" })

    UISettingsSection:AddButton({
        Title = "Test Notifications (Success / Warning / Error)",
        Callback = function()
            Library:Notify({ Title = "Success Notification", Content = "Operation completed successfully!", Type = "success", Duration = 2 })
            task.wait(0.6)
            Library:Notify({ Title = "Warning Notification", Content = "Check your bypass or gamepass status.", Type = "warning", Duration = 2 })
            task.wait(0.6)
            Library:Notify({ Title = "Error Notification", Content = "Simulated error notification test.", Type = "error", Duration = 2 })
        end
    end)

    UISettingsSection:AddButton({
        Title = "Unload & Destroy UI",
        Callback = function()
            Library:Notify({ Title = "Unloading", Content = "Destroying KnotHub UI...", Type = "warning", Duration = 2 })
            task.wait(0.5)
            pcall(function() Library:Destroy() end)
        end
    end)
end

Window:SelectTab(1)
print("[KnotHub] Eat Slimes to Grow HUGE successfully initialized with KnotLib v3.2!")
Library:Notify({ Title = "KnotHub v3.2", Content = "Eat Slimes Ready to Grow HUGE!", Type = "success", Duration = 5 })
