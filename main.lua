--!nocheck
--[[
    main.lua — Frontend / Presentation Layer (Anime Limitless)
    ───────────────────────────────────────────────────────────
    Architecture: Separation of Concerns (SoC)
      • This script ONLY builds UI and delegates events to the Controller.
      • Business logic, state mutations, loops, and remote calls are FORBIDDEN here.
      • All callbacks update Controller.Flags and invoke Controller methods.

    Extensibility:
      • New features are added by: (1) adding a flag to Controller.Flags,
        (2) adding a method to the relevant Controller sub-service,
        (3) adding a UI component in main.lua that delegates to it.
      • The UI structure never needs to change to support new backend features.
--]]

print("[KnotHub Limitless] Initializing (SoC Architecture v3.2)...")

--------------------------------------------------------------------------------
-- Cleanup previous instances
--------------------------------------------------------------------------------
pcall(function()
    local p1 = gethui and gethui()
    local p2 = game:GetService("CoreGui")
    local p3 = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    local function wipe(parent)
        if parent then
            for _, g in ipairs(parent:GetChildren()) do
                if g:IsA("ScreenGui") and (g.Name == "KnotLib" or g.Name == "KnotHub" or g.Name:find("Knot")) then
                    g:Destroy()
                end
            end
        end
    end
    wipe(p1); wipe(p2); wipe(p3)
end)

--------------------------------------------------------------------------------
-- Load Library
--------------------------------------------------------------------------------
local Library
pcall(function()
    if isfile and isfile("KnotLib.lua") then
        local localScript = readfile("KnotLib.lua")
        if localScript and #localScript > 0 then
            Library = loadstring(localScript)()
            print("[KnotHub Limitless] Loaded KnotLib v3.2 from local file.")
        end
    end
end)
if not Library then
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/whylovehurts/knotlib/refs/heads/main/KnotLib.lua"))()
    end)
    if success and result then
        Library = result
    else
        warn("[KnotHub Limitless] Failed to load KnotLib v3.2: " .. tostring(result))
        return
    end
end
if not Library then warn("[KnotHub Limitless] KnotLib returned nil."); return end

pcall(function()
    Library:AddContact("Discord Support", "https://discord.gg/knothub")
    Library:AddContact("Telegram Channel", "https://t.me/knothub_updates")
    Library:AddContact("YouTube", "https://youtube.com/@KnotHub")
end)

--------------------------------------------------------------------------------
-- Load Controller (Backend)
--------------------------------------------------------------------------------
local Controller = loadstring(readfile("/src/controller.luau"))()

--------------------------------------------------------------------------------
-- Expose Library to Controller (for Unloaded checks)
--------------------------------------------------------------------------------
Controller._library = Library
Library._controller = Controller

--------------------------------------------------------------------------------
-- Helper: delegate flag toggle to Controller
--------------------------------------------------------------------------------
local function flagToggle(flagName: string)
    return function(state: boolean)
        Controller.Flags[flagName] = state
    end
end

local function flagSet(flagName: string)
    return function(value: any)
        Controller.Flags[flagName] = value
    end
end

--------------------------------------------------------------------------------
-- Build Window
--------------------------------------------------------------------------------
local Window = Library:CreateWindow({
    HubName = "KnotHub Limitless",
    Size = UDim2.fromOffset(780, 440),
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main" }),
    Combat = Window:AddTab({ Title = "Combat" }),
    Teleports = Window:AddTab({ Title = "Teleports" }),
    Players = Window:AddTab({ Title = "Players" }),
    Misc = Window:AddTab({ Title = "Misc" }),
    Settings = Window:AddTab({ Title = "Settings" }),
}

--------------------------------------------------------------------------------
-- TAB: Main
--------------------------------------------------------------------------------
do
    local FarmSection = Tabs.Main:AddSection({ Title = "Farm Control" })

    FarmSection:AddToggle({
        Flag = "AutoFarm",
        Title = "Enable Auto Farm Quest & Dungeon Boss",
        Default = false,
        Callback = function(state)
            flagToggle("autoFarm")(state)
            if state then
                Controller.Quests:abandonCurrentQuest()
                Library:Notify({ Title = "Auto Farm", Content = "Auto Farm started!", Type = "success", Duration = 3 })
            end
        end,
    })

    FarmSection:AddDropdown({
        Flag = "TargetMobOverride",
        Title = "Target Mob / Quest Override",
        ValuesFunction = function()
            return Controller.Quests:getMobList()
        end,
        Default = "Auto Best Quest",
        Callback = flagSet("targetMobOverride"),
    })

    FarmSection:AddToggle({
        Flag = "AutoCollectChests",
        Title = "Auto Collect All Chests (No TP)",
        Default = false,
        Callback = flagToggle("autoCollectChests"),
    })

    local HpSection = Tabs.Main:AddSection({ Title = "Farm HP" })

    HpSection:AddToggle({
        Flag = "AutoFarmHP",
        Title = "Auto Farm HP (Need Soul)",
        Default = false,
        Callback = function(state)
            Controller.Flags.autoFarmHP = state
            Controller.Misc:fireAutoFarmHP(state)
        end,
    })

    local WeaponSection = Tabs.Main:AddSection({ Title = "Combat Weapon Configuration" })

    local WeaponDropdown = WeaponSection:AddDropdown({
        Flag = "SelectedWeapon",
        Title = "Select Weapon",
        ValuesFunction = function()
            return Controller.Combat:getInventoryItems()
        end,
        Default = "Combat",
        Callback = flagSet("selectedWeapon"),
    })

    WeaponSection:AddButton({
        Title = "Refresh Weapons List",
        Callback = function()
            if WeaponDropdown.Refresh then
                WeaponDropdown:Refresh(Controller.Combat:getInventoryItems())
            elseif WeaponDropdown.SetValues then
                WeaponDropdown:SetValues(Controller.Combat:getInventoryItems())
            end
            Library:Notify({ Title = "Weapons", Content = "Weapons list refreshed!", Type = "success", Duration = 2 })
        end,
    })
end

--------------------------------------------------------------------------------
-- TAB: Combat
--------------------------------------------------------------------------------
do
    local InstakillSection = Tabs.Combat:AddSection({ Title = "Instant Kill Aura" })

    InstakillSection:AddToggle({
        Flag = "InstantKillAura",
        Title = "Enable Instant Kill Aura",
        Default = false,
        Callback = function(state)
            flagToggle("instantKillAura")(state)
            if state then
                Controller.Quests:abandonCurrentQuest()
                Library:Notify({ Title = "Kill Aura", Content = "Instant Kill Aura activated!", Type = "warning", Duration = 3 })
            end
        end,
    })

    InstakillSection:AddSlider({
        Flag = "InstantKillRange",
        Title = "Instakill Search Radius",
        Default = 80,
        Min = 15,
        Max = 150,
        Rounding = 0,
        Callback = flagSet("instantKillRange"),
    })

    local AuraSection = Tabs.Combat:AddSection({ Title = "Normal Kill Aura" })

    AuraSection:AddToggle({
        Flag = "StandaloneAura",
        Title = "Normal Kill Aura",
        Default = false,
        Callback = flagToggle("standaloneAura"),
    })

    AuraSection:AddSlider({
        Flag = "AuraRange",
        Title = "Kill Aura Search Radius",
        Default = 80,
        Min = 15,
        Max = 150,
        Rounding = 0,
        Callback = flagSet("auraRange"),
    })

    local AttackSection = Tabs.Combat:AddSection({ Title = "Super Fast Attack (Interleaved)" })

    AttackSection:AddSlider({
        Flag = "AttackSpeed",
        Title = "Interleave Delay (Rate Limit Bypass)",
        Default = 0.045,
        Min = 0.03,
        Max = 0.25,
        Rounding = 3,
        Callback = flagSet("attackSpeed"),
    })

    AttackSection:AddToggle({
        Flag = "FastAttackNormal",
        Title = "Fast Attack (Equipped Weapon Only)",
        Default = false,
        Callback = flagToggle("fastAttackNormal"),
    })

    AttackSection:AddToggle({
        Flag = "FastAttackAll",
        Title = "Super Fast Attack (Interleave All Weapons)",
        Default = false,
        Callback = flagToggle("fastAttackAll"),
    })

    AttackSection:AddToggle({
        Flag = "UltraFastSkillAttack",
        Title = "Ultra Fast Attack (SkillControl Bypass)",
        Default = false,
        Callback = flagToggle("ultraFastSkillAttack"),
    })
end

--------------------------------------------------------------------------------
-- TAB: Teleports
--------------------------------------------------------------------------------
do
    local TpSection = Tabs.Teleports:AddSection({ Title = "World & Chest Teleports" })

    TpSection:AddButton({
        Title = "Collect All Chests Immediately (No TP)",
        Callback = function()
            local count = Controller.Chests:collectAllImmediately()
            Library:Notify({
                Title = "Chests Collected",
                Content = "Pulled " .. tostring(count) .. " chest parts to root!",
                Type = "success",
                Duration = 4,
            })
        end,
    })

    TpSection:AddToggle({
        Flag = "ToggleGameTeleporter",
        Title = "Show In-Game Teleporter Menu",
        Default = false,
        Callback = function(state)
            local ok = Controller.Teleport:showInGameTeleporter(state)
            if ok then
                Library:Notify({
                    Title = "Teleporter",
                    Content = state and "In-game teleporter visible!" or "In-game teleporter hidden!",
                    Type = "success",
                    Duration = 2,
                })
            else
                Library:Notify({
                    Title = "Teleporter Error",
                    Content = "HUD Teleporter UI not found in PlayerGui.",
                    Type = "error",
                    Duration = 3,
                })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- TAB: Players
--------------------------------------------------------------------------------
do
    if Tabs.Players.AddPlayerList then
        Tabs.Players:AddPlayerList({
            Title = "Server Players Teleporter",
            Callback = function(selectedPlayerName)
                local targetPlayer = game:GetService("Players"):FindFirstChild(selectedPlayerName)
                if targetPlayer and targetPlayer ~= game:GetService("Players").LocalPlayer then
                    local ok = Controller.Teleport:toPlayer(targetPlayer)
                    if ok then
                        Library:Notify({
                            Title = "Teleport Success",
                            Content = "Teleported directly to " .. tostring(selectedPlayerName),
                            Type = "success",
                            Duration = 3,
                        })
                    else
                        Library:Notify({
                            Title = "Teleport Failed",
                            Content = "Player character or HumanoidRootPart not found!",
                            Type = "error",
                            Duration = 3,
                        })
                    end
                else
                    Library:Notify({
                        Title = "Teleport Failed",
                        Content = "Invalid target or cannot teleport to self!",
                        Type = "warning",
                        Duration = 3,
                    })
                end
            end,
        })
    else
        local PlayerSection = Tabs.Players:AddSection({ Title = "Player Teleporter" })
        PlayerSection:AddDropdown({
            Flag = "SelectedPlayerTP",
            Title = "Select Player",
            ValuesFunction = function()
                local names = {}
                for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                    if p ~= game:GetService("Players").LocalPlayer then
                        table.insert(names, p.Name)
                    end
                end
                if #names == 0 then table.insert(names, "No other players") end
                return names
            end,
            Default = "No other players",
        })
        PlayerSection:AddButton({
            Title = "Teleport to Selected Player",
            Callback = function()
                local sel = Library.Options.SelectedPlayerTP and Library.Options.SelectedPlayerTP.Value
                if sel and sel ~= "No other players" then
                    local targetPlayer = game:GetService("Players"):FindFirstChild(sel)
                    if targetPlayer then
                        local ok = Controller.Teleport:toPlayer(targetPlayer)
                        if ok then
                            Library:Notify({ Title = "Teleport Success", Content = "Teleported to " .. sel, Type = "success", Duration = 3 })
                        else
                            Library:Notify({ Title = "Teleport Failed", Content = "Target player has no active character!", Type = "error", Duration = 3 })
                        end
                    end
                else
                    Library:Notify({ Title = "Warning", Content = "Select a valid player first!", Type = "warning", Duration = 3 })
                end
            end,
        })
    end
end

--------------------------------------------------------------------------------
-- TAB: Misc
--------------------------------------------------------------------------------
do
    local MiscSection = Tabs.Misc:AddSection({ Title = "Item Duplication" })

    MiscSection:AddToggle({
        Flag = "DupeFruit",
        Title = "Dupe Fruit (Consume while this activated)",
        Default = false,
        Callback = function(state)
            flagToggle("dupeFruit")(state)
            if state then
                Library:Notify({ Title = "Dupe Fruit", Content = "Spamming StoreSoul for hand & inventory!", Type = "warning", Duration = 3 })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- TAB: Settings
--------------------------------------------------------------------------------
do
    local ThemeSection = Tabs.Settings:AddSection({ Title = "Theme Customization" })

    local accentColors = {
        ["Crimson Red"] = Color3.fromRGB(220, 40, 40),
        ["Neon Blue"] = Color3.fromRGB(40, 120, 255),
        ["Royal Purple"] = Color3.fromRGB(150, 60, 255),
        ["Emerald Green"] = Color3.fromRGB(40, 200, 80),
        ["Sunset Orange"] = Color3.fromRGB(255, 140, 30),
        ["Rose Pink"] = Color3.fromRGB(255, 80, 150),
        ["Ice Cyan"] = Color3.fromRGB(40, 220, 220),
        ["Monochrome White"] = Color3.fromRGB(240, 240, 240),
    }

    local colorNames = {}
    for name, _ in pairs(accentColors) do table.insert(colorNames, name) end
    table.sort(colorNames)

    ThemeSection:AddDropdown({
        Flag = "ThemeColorSelect",
        Title = "Select Accent Color",
        Values = colorNames,
        Default = "Neon Blue",
        Callback = function(selectedName)
            local col = accentColors[selectedName]
            if col and Library.SetAccent then
                pcall(function() Library:SetAccent(col) end)
                Library:Notify({
                    Title = "Theme Updated",
                    Content = "Applied accent theme: " .. selectedName,
                    Type = "success",
                    Duration = 2,
                })
            end
        end,
    })

    local KeybindSection = Tabs.Settings:AddSection({ Title = "Window Controls" })

    if ThemeSection.AddKeybind or KeybindSection.AddKeybind then
        KeybindSection:AddKeybind({
            Flag = "MinimizeKeybind",
            Title = "Minimize UI Keybind",
            Default = Enum.KeyCode.RightShift,
            Callback = function(key)
                Window.MinimizeKey = key
                Library:Notify({
                    Title = "Keybind Changed",
                    Content = "Minimize key bound to: " .. tostring(key),
                    Type = "success",
                    Duration = 3,
                })
            end,
        })
    else
        local keys = { "RightShift", "RightControl", "Insert", "F1", "F4", "Delete" }
        KeybindSection:AddDropdown({
            Flag = "MinimizeKeyDropdown",
            Title = "Minimize UI Keybind",
            Values = keys,
            Default = "RightShift",
            Callback = function(val)
                local kc = Enum.KeyCode[val]
                if kc then
                    Window.MinimizeKey = kc
                    Library:Notify({
                        Title = "Keybind Changed",
                        Content = "Minimize key set to: " .. val,
                        Type = "success",
                        Duration = 3,
                    })
                end
            end,
        })
    end

    local UISection = Tabs.Settings:AddSection({ Title = "System" })
    UISection:AddButton({
        Title = "Unload / Destroy UI",
        Callback = function()
            Controller:DisconnectAll()
            Library:Notify({ Title = "Unloading", Content = "Destroying KnotHub UI...", Type = "warning", Duration = 2 })
            task.wait(0.5)
            Library:Destroy()
        end,
    })
end

--------------------------------------------------------------------------------
-- Initialize Controller & Start Loops
--------------------------------------------------------------------------------
Controller:Init()
Controller:StartLoops()

Window:SelectTab(1)
print("[KnotHub Limitless] Initialized with SoC Architecture v3.2!")
Library:Notify({
    Title = "KnotHub Limitless",
    Content = "Universal VIP Ready (SoC v3.2)!",
    Type = "success",
    Duration = 5,
})
