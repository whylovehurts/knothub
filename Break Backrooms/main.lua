

print("[KnotHub] Initializing script for Break Backrooms (v3.2)...")




pcall(function()
    local p1 = gethui and gethui()
    local p2 = game:GetService("CoreGui")
    local p3 = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")

    local function wipe(parent)
        if parent then
            for _, g in ipairs(parent:GetChildren()) do
                if g:IsA("ScreenGui") and (g.Name == "KnotLib" or g.Name == "KnotHub") then
                    g:Destroy()
                end
            end
        end
    end
    wipe(p1); wipe(p2); wipe(p3)
end)




local Library
local loadSuccess, libOrErr = pcall(function()
    if type(isfile) == "function" and isfile("KnotLib.lua") then
        local content = readfile("KnotLib.lua")
        return loadstring(content)()
    end
    local url = "https://raw.githubusercontent.com/whylovehurts/knotlib/refs/heads/main/KnotLib.lua"
    return loadstring(game:HttpGet(url))()
end)

if not loadSuccess or type(libOrErr) ~= "table" then
    warn("[KnotHub] Failed to load KnotLib v3.2: " .. tostring(libOrErr))
    return
end
Library = libOrErr

if Library.AddContact then
    Library:AddContact("Discord Support", "https://discord.gg/knothub")
    Library:AddContact("Telegram Channel", "https://t.me/knothub_updates")
    Library:AddContact("YouTube", "https://youtube.com/@KnotHub")
end




local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)




local KnotHub = {
    Flags = {
        autoWin = false,
        fastAttack = true,
        autoTrain = false,
        autoRebirth = false,
        walkSpeed = 16,
        jumpPower = 50,
        noclip = false,
        espEnabled = false,
        espColor = Color3.fromRGB(255, 0, 50)
    },
    StagesOrder = {
        "Cardboard", "Carpet", "Paper", "Leather", "Rubber", 
        "Grass", "Wood", "Glass", "Brick", "Concrete", 
        "Marble", "Granite", "Iron", "Magma", "Void"
    }
}

local isUnloaded = false


task.spawn(function()
    pcall(function()
        if Remotes and Remotes:FindFirstChild("GroupReward") then Remotes.GroupReward:FireServer() end
        if Remotes and Remotes:FindFirstChild("Onboarding") then Remotes.Onboarding:FireServer() end
    end)
end)


local activeTargetWall = nil

RunService.Heartbeat:Connect(function()
    if isUnloaded or (Library and Library.Unloaded) then return end
    if KnotHub.Flags.autoWin and KnotHub.Flags.fastAttack and activeTargetWall and Remotes and Remotes:FindFirstChild("Punch") then
        pcall(function()
            Remotes.Punch:FireServer("RightHand")
            Remotes.Punch:FireServer("LeftHand")
        end)
    end
end)

task.spawn(function()
    while not isUnloaded and not (Library and Library.Unloaded) do
        if KnotHub.Flags.autoWin and KnotHub.Flags.fastAttack and activeTargetWall and Remotes and Remotes:FindFirstChild("Punch") then
            pcall(function()
                Remotes.Punch:FireServer("RightHand")
                Remotes.Punch:FireServer("LeftHand")
            end)
            task.wait()
        else
            task.wait(0.05)
        end
    end
end)


task.spawn(function()
    while not isUnloaded and not (Library and Library.Unloaded) do
        RunService.Heartbeat:Wait()
        if KnotHub.Flags.autoWin and Remotes and Remotes:FindFirstChild("Punch") then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp then return end

                LocalPlayer:SetAttribute("State", "Punching")
                
                if hum and KnotHub.Flags.fastAttack then
                    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                        if track.Animation and track.Animation.AnimationId:find("Punch") then
                            track:Stop()
                        end
                    end
                end

                local stagesFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Stages")
                if not stagesFolder then return end

                for _, stageName in ipairs(KnotHub.StagesOrder) do
                    if isUnloaded or (Library and Library.Unloaded) or not KnotHub.Flags.autoWin then break end
                    local stage = stagesFolder:FindFirstChild(stageName)
                    
                    if stage and stage:FindFirstChild("WallFolder") then
                        local walls = {}
                        for _, w in ipairs(stage.WallFolder:GetChildren()) do
                            if w:IsA("BasePart") then table.insert(walls, w) end
                        end
                        table.sort(walls, function(a, b) return a.Position.Z > b.Position.Z end)

                        for _, wall in ipairs(walls) do
                            if isUnloaded or (Library and Library.Unloaded) or not KnotHub.Flags.autoWin then break end
                            local sg = wall:FindFirstChild("SurfaceGui")
                            local lifeLabel = sg and sg:FindFirstChild("LifeNumber")

                            if lifeLabel and not lifeLabel.Text:match("^0/") then
                                local targetPos = Vector3.new(wall.Position.X, wall.Position.Y, wall.Position.Z + 4)
                                hrp.CFrame = CFrame.lookAt(targetPos, wall.Position)
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                
                                activeTargetWall = wall

                                while not isUnloaded and not (Library and Library.Unloaded) and KnotHub.Flags.autoWin and lifeLabel and not lifeLabel.Text:match("^0/") do
                                    if not KnotHub.Flags.fastAttack then
                                        Remotes.Punch:FireServer("RightHand")
                                        Remotes.Punch:FireServer("LeftHand")
                                        task.wait(0.15)
                                    else
                                        hrp.CFrame = CFrame.lookAt(targetPos, wall.Position)
                                        hrp.AssemblyLinearVelocity = Vector3.zero
                                        RunService.Heartbeat:Wait()
                                    end
                                end
                                activeTargetWall = nil
                            end
                        end

                        activeTargetWall = nil
                        local winPad = stage:FindFirstChild("WinPad")
                        if winPad then
                            local target = winPad:FindFirstChild("Part") or winPad:GetChildren()[1]
                            if target and target:IsA("BasePart") then
                                hrp.CFrame = target.CFrame + Vector3.new(0, 1, 0)
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                if firetouchinterest then
                                    firetouchinterest(hrp, target, 0)
                                    firetouchinterest(hrp, target, 1)
                                end
                                RunService.Heartbeat:Wait()
                            end
                        end
                    end
                end
            end)
        end
    end
end)


task.spawn(function()
    while not isUnloaded and not (Library and Library.Unloaded) do
        task.wait()
        if KnotHub.Flags.autoTrain and Remotes and Remotes:FindFirstChild("Train") then
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if hum and backpack then
                    for _, tool in ipairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and (tool.Name:find("Dumbbell") or tool.Name:find("Weight")) then
                            hum:EquipTool(tool)
                        end
                    end
                end

                Remotes.Train:FireServer()
            end)
        end
    end
end)


task.spawn(function()
    while not isUnloaded and not (Library and Library.Unloaded) do
        task.wait(1)
        if KnotHub.Flags.autoRebirth and Remotes and Remotes:FindFirstChild("Rebirth") then
            pcall(function() Remotes.Rebirth:FireServer() end)
            pcall(function() Remotes.Rebirth:InvokeServer() end)
        end
    end
end)


RunService.Stepped:Connect(function()
    if isUnloaded or (Library and Library.Unloaded) then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if KnotHub.Flags.walkSpeed ~= 16 then
                hum.WalkSpeed = KnotHub.Flags.walkSpeed
            end
            if KnotHub.Flags.jumpPower ~= 50 then
                hum.UseJumpPower = true
                hum.JumpPower = KnotHub.Flags.jumpPower
            end
        end
        if KnotHub.Flags.noclip then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end)


local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local hl = char:FindFirstChild("KnotHub_ESP")
                if KnotHub.Flags.espEnabled then
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "KnotHub_ESP"
                        hl.FillTransparency = 0.5
                        hl.OutlineTransparency = 0
                        hl.Adornee = char
                        hl.Parent = char
                    end
                    hl.FillColor = KnotHub.Flags.espColor
                    hl.OutlineColor = KnotHub.Flags.espColor
                    hl.Enabled = true
                else
                    if hl then
                        hl:Destroy()
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while not isUnloaded and not (Library and Library.Unloaded) do
        task.wait(1)
        if KnotHub.Flags.espEnabled then
            updateESP()
        end
    end
end)




local Window = Library:CreateWindow({
    HubName = "KnotHub Backrooms",
    Title = "Break Backrooms",
    Version = "v3.2",
    Size = UDim2.fromOffset(780, 440),
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main" }),
    Character = Window:AddTab({ Title = "Character" }),
    Players = Window:AddTab({ Title = "Players" }),
    Settings = Window:AddTab({ Title = "Settings" })
}




do
    local StartSection = Tabs.Main:AddSection({ Title = "Rewards & Onboarding" })

    StartSection:AddButton({
        Title = "Claim Group & Onboarding Rewards",
        Callback = function()
            local success = pcall(function()
                if Remotes and Remotes:FindFirstChild("GroupReward") then Remotes.GroupReward:FireServer() end
                if Remotes and Remotes:FindFirstChild("Onboarding") then Remotes.Onboarding:FireServer() end
            end)
            if success then
                Library:Notify({
                    Title = "Rewards Claimed",
                    Content = "Group and onboarding rewards claimed successfully!",
                    Type = "success",
                    Duration = 3
                })
            else
                Library:Notify({
                    Title = "Claim Error",
                    Content = "Failed to communicate with reward remotes.",
                    Type = "error",
                    Duration = 3
                })
            end
        end
    })

    local AutoSection = Tabs.Main:AddSection({ Title = "Automation" })

    AutoSection:AddToggle({
        Flag = "AutoWin",
        Title = "Auto Win (Rush Stages)",
        Default = false,
        Callback = function(state)
            KnotHub.Flags.autoWin = state
            if not state then activeTargetWall = nil end
            Library:Notify({
                Title = "Auto Win",
                Content = state and "Auto Win Enabled - Rushing barriers!" or "Auto Win Disabled.",
                Type = state and "success" or "warning",
                Duration = 3
            })
        end
    })

    AutoSection:AddToggle({
        Flag = "FastAttack",
        Title = "Fast Attack (Bypass Client Cooldowns)",
        Default = true,
        Callback = function(state)
            KnotHub.Flags.fastAttack = state
            Library:Notify({
                Title = "Fast Attack",
                Content = "Supreme Engine: " .. (state and "ACTIVE" or "DISABLED"),
                Type = state and "success" or "warning",
                Duration = 2
            })
        end
    })

    AutoSection:AddToggle({
        Flag = "AutoTrain",
        Title = "Auto Train (Max Speed & Auto-Equip)",
        Default = false,
        Callback = function(state)
            KnotHub.Flags.autoTrain = state
            Library:Notify({
                Title = "Auto Train",
                Content = state and "Training auto-equip started." or "Auto Train paused.",
                Type = state and "success" or "warning",
                Duration = 2
            })
        end
    })

    AutoSection:AddToggle({
        Flag = "AutoRebirth",
        Title = "Auto Rebirth",
        Default = false,
        Callback = function(state)
            KnotHub.Flags.autoRebirth = state
            Library:Notify({
                Title = "Auto Rebirth",
                Content = state and "Auto Rebirth enabled." or "Auto Rebirth disabled.",
                Type = state and "success" or "warning",
                Duration = 2
            })
        end
    })
end




do
    local MoveSection = Tabs.Character:AddSection({ Title = "Movement Modifiers" })

    MoveSection:AddSlider({
        Title = "WalkSpeed",
        Min = 16,
        Max = 250,
        Default = 16,
        Increment = 1,
        Flag = "WalkSpeedSlider",
        Callback = function(val)
            KnotHub.Flags.walkSpeed = val
        end
    })

    MoveSection:AddSlider({
        Title = "JumpPower",
        Min = 50,
        Max = 300,
        Default = 50,
        Increment = 5,
        Flag = "JumpPowerSlider",
        Callback = function(val)
            KnotHub.Flags.jumpPower = val
        end
    })

    MoveSection:AddToggle({
        Title = "Noclip (Walk Through Walls)",
        Default = false,
        Flag = "NoclipToggle",
        Callback = function(state)
            KnotHub.Flags.noclip = state
            Library:Notify({
                Title = "Noclip",
                Content = state and "Noclip enabled." or "Noclip disabled.",
                Type = state and "success" or "warning",
                Duration = 2
            })
        end
    })
end




do
    local PlayersSection = Tabs.Players:AddSection({ Title = "Player Teleport & Control" })

    PlayersSection:AddPlayerList({
        Title = "Select Target Player",
        Flag = "TargetPlayerList",
        Callback = function(selected)
            local targetPlayer = nil
            if typeof(selected) == "Instance" and selected:IsA("Player") then
                targetPlayer = selected
            elseif type(selected) == "string" then
                targetPlayer = Players:FindFirstChild(selected)
            elseif type(selected) == "table" and selected.Name then
                targetPlayer = Players:FindFirstChild(selected.Name)
            end

            if not targetPlayer then
                Library:Notify({
                    Title = "Teleport Error",
                    Content = "Selected player could not be found!",
                    Type = "error",
                    Duration = 3
                })
                return
            end

            if targetPlayer == LocalPlayer then
                Library:Notify({
                    Title = "Teleport Warning",
                    Content = "You cannot teleport to yourself!",
                    Type = "warning",
                    Duration = 3
                })
                return
            end

            local targetChar = targetPlayer.Character
            local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local myChar = LocalPlayer.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

            if targetHRP and myHRP then
                myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
                myHRP.AssemblyLinearVelocity = Vector3.zero
                Library:Notify({
                    Title = "Teleport Success",
                    Content = "Successfully teleported to " .. targetPlayer.Name,
                    Type = "success",
                    Duration = 3
                })
            else
                Library:Notify({
                    Title = "Teleport Error",
                    Content = "Character or HumanoidRootPart missing!",
                    Type = "error",
                    Duration = 3
                })
            end
        end
    })

    local ESPSection = Tabs.Players:AddSection({ Title = "Player Visuals (ESP)" })

    ESPSection:AddToggle({
        Title = "Enable Player ESP Highlights",
        Default = false,
        Flag = "ESPEnabledToggle",
        Callback = function(state)
            KnotHub.Flags.espEnabled = state
            if not state then
                for _, player in ipairs(Players:GetPlayers()) do
                    local char = player.Character
                    if char and char:FindFirstChild("KnotHub_ESP") then
                        char.KnotHub_ESP:Destroy()
                    end
                end
                Library:Notify({
                    Title = "ESP Visuals",
                    Content = "Player ESP highlights disabled.",
                    Type = "warning",
                    Duration = 2
                })
            else
                updateESP()
                Library:Notify({
                    Title = "ESP Visuals",
                    Content = "Player ESP highlights enabled.",
                    Type = "success",
                    Duration = 2
                })
            end
        end
    })

    ESPSection:AddColorPicker({
        Title = "ESP Highlight Color",
        Default = Color3.fromRGB(255, 0, 50),
        Flag = "ESPColorPicker",
        Callback = function(color)
            KnotHub.Flags.espColor = color
            if KnotHub.Flags.espEnabled then
                updateESP()
            end
        end
    })
end




do
    local ThemeSection = Tabs.Settings:AddSection({ Title = "Theme & Accent Colors" })

    ThemeSection:AddColorPicker({
        Title = "Custom Accent Color",
        Default = Color3.fromRGB(0, 170, 255),
        Flag = "AccentColorPicker",
        Callback = function(color)
            if Library.SetAccent then
                Library:SetAccent(color)
            end
            Library:Notify({
                Title = "Theme Updated",
                Content = "Custom accent color applied.",
                Type = "success",
                Duration = 2
            })
        end
    })

    local presetColors = {
        { Name = "Knot Blue", Color = Color3.fromRGB(0, 170, 255) },
        { Name = "Emerald Green", Color = Color3.fromRGB(46, 204, 113) },
        { Name = "Crimson Red", Color = Color3.fromRGB(231, 76, 60) },
        { Name = "Amethyst Purple", Color = Color3.fromRGB(155, 89, 182) },
        { Name = "Golden Yellow", Color = Color3.fromRGB(241, 196, 15) }
    }

    for _, preset in ipairs(presetColors) do
        ThemeSection:AddButton({
            Title = "Theme Preset: " .. preset.Name,
            Callback = function()
                if Library.SetAccent then
                    Library:SetAccent(preset.Color)
                end
                Library:Notify({
                    Title = "Theme Preset Applied",
                    Content = "Switched to " .. preset.Name,
                    Type = "success",
                    Duration = 2
                })
            end
        end)
    end

    local SystemSection = Tabs.Settings:AddSection({ Title = "System Control" })

    SystemSection:AddButton({
        Title = "Unload Script / Destroy UI",
        Callback = function()
            isUnloaded = true
            Library:Notify({
                Title = "System",
                Content = "Unloading KnotHub UI and cleaning threads...",
                Type = "warning",
                Duration = 2
            })
            task.wait(0.5)
            if Library.Destroy then
                Library:Destroy()
            elseif Library.Unload then
                Library:Unload()
            end
        end
    })
end

if Window.SelectTab then
    Window:SelectTab(1)
end

print("[KnotHub] Break Backrooms successfully initialized with KnotLib v3.2 standards!")
Library:Notify({
    Title = "KnotHub v3.2 Ready",
    Content = "Break Backrooms script loaded successfully!",
    Type = "success",
    Duration = 5
})
