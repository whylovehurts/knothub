




local url = "https://raw.githubusercontent.com/whylovehurts/knotlib/refs/heads/main/KnotLib.lua"

local Library
if url ~= "" then
    local s, code = pcall(function() return game:HttpGet(url) end)
    if s and code then
        local loader = loadstring(code)
        if loader then Library = loader() end
    end
end


if not Library and type(readfile) == "function" and pcall(readfile, "KnotLib.lua") then
    local loader = loadstring(readfile("KnotLib.lua"))
    if loader then Library = loader() end
end

if not Library then
    warn("[KnotHub] Falha ao carregar KnotLib! Verifique a conexão ou o arquivo local.")
    return
end




local Window = Library:CreateWindow({
    HubName = "KnotHub Limitless", 
    Size = UDim2.fromOffset(780, 440),
    MinimizeKey = Enum.KeyCode.RightShift
})

Library:Notify({
    Title = "KnotLib v3.2 Loaded!",
    Content = "Pressione RightShift para ocultar/abrir a UI. Você pode redimensionar no canto inferior direito!",
    Type = "success",
    Duration = 6
})




local CombatTab = Window:AddTab("Combat")
local FarmSection = CombatTab:AddSection("Auto Farm Options")

FarmSection:AddToggle({
    Flag = "AutoAttack",
    Title = "Auto Attack Enemies",
    Description = "Ataca continuamente os alvos próximos do seu alcance.",
    Default = false,
    Callback = function(state)
        Library:Notify({
            Title = "Auto Attack",
            Content = state and "Ativado com sucesso!" or "Desativado.",
            Type = state and "success" or "warning",
            Duration = 2
        })
    end
})


FarmSection:AddDropdown({
    Flag = "SelectedTarget",
    Title = "Select Target (Auto-Update)",
    Description = "Esta lista atualiza sozinha toda vez que você clica para abrir!",
    Values = {"Bandit Lvl 1", "Goblin Scout", "Orc Warrior"},
    ValuesFunction = function()
        
        local mobs = {"Bandit Lvl 1", "Goblin Scout", "Orc Warrior"}
        if math.random() > 0.4 then table.insert(mobs, "Shadow Boss [RARE]") end
        if math.random() > 0.7 then table.insert(mobs, "Ancient Dragon [BOSS]") end
        return mobs
    end,
    Default = "Bandit Lvl 1",
    Callback = function(selected)
        print("[Combat] Novo alvo selecionado:", selected)
    end
})

FarmSection:AddSeparator()

FarmSection:AddSlider({
    Flag = "AttackRange",
    Title = "Attack Range (Studs)",
    Min = 5, Max = 50, Default = 15,
    Callback = function(val) print("[Combat] Alcance:", val) end
})

FarmSection:AddSlider({
    Flag = "AttackSpeed",
    Title = "Attack Cooldown (ms)",
    Min = 50, Max = 1000, Default = 200,
    Callback = function(val) print("[Combat] Cooldown:", val, "ms") end
})




local PlayerTab = Window:AddTab("Player")
local MoveSection = PlayerTab:AddSection("Movement Modifiers")

MoveSection:AddSlider({
    Flag = "WalkSpeed",
    Title = "Walk Speed",
    Min = 16, Max = 150, Default = 16,
    Callback = function(speed)
        local char = game:GetService("Players").LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = speed
        end
    end
})

MoveSection:AddSlider({
    Flag = "JumpPower",
    Title = "Jump Power",
    Min = 50, Max = 300, Default = 50,
    Callback = function(power)
        local char = game:GetService("Players").LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = power
        end
    end
})

MoveSection:AddToggle({
    Flag = "InfiniteJump",
    Title = "Infinite Jump",
    Description = "Permite pular continuamente sem tocar no chão.",
    Default = false
})

MoveSection:AddSeparator()

local TpSection = PlayerTab:AddSection("Quick Teleport")

TpSection:AddTextbox({
    Flag = "TargetPlayerName",
    Title = "Player Nickname / DisplayName",
    Placeholder = "Digite parte do nome...",
    Callback = function(text) print("[TP] Alvo digitado:", text) end
})

TpSection:AddButton({
    Title = "Teleport to Player",
    Description = "Busca o jogador no servidor e teleporta instantaneamente.",
    Callback = function()
        local inputName = Library.Options.TargetPlayerName:GetValue():lower()
        if inputName == "" then
            Library:Notify({ Title = "Erro", Content = "Digite o nome de um jogador no campo acima!", Type = "error", Duration = 3 })
            return
        end
        local target = nil
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.Name:lower():sub(1, #inputName) == inputName or p.DisplayName:lower():sub(1, #inputName) == inputName then
                target = p
                break
            end
        end
        if target then
            if target == game:GetService("Players").LocalPlayer then
                Library:Notify({ Title = "Aviso", Content = "Você não pode teleportar para si mesmo!", Type = "warning", Duration = 3 })
                return
            end
            local pChar = target.Character
            local lChar = game:GetService("Players").LocalPlayer.Character
            if pChar and pChar:FindFirstChild("HumanoidRootPart") and lChar and lChar:FindFirstChild("HumanoidRootPart") then
                lChar.HumanoidRootPart.CFrame = pChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                Library:Notify({ Title = "Sucesso!", Content = "Teleportado para: " .. target.DisplayName, Type = "success", Duration = 3 })
            else
                Library:Notify({ Title = "Erro", Content = "O personagem do alvo não está spawned!", Type = "error", Duration = 3 })
            end
        else
            Library:Notify({ Title = "Erro", Content = "Jogador não encontrado no servidor!", Type = "error", Duration = 3 })
        end
    end
})




local ServerTab = Window:AddTab("Server")
local ListSection = ServerTab:AddSection("Online Players")

ListSection:AddParagraph({
    Title = "Clique para Teleportar",
    Content = "A lista abaixo sincroniza automaticamente quando jogadores entram ou saem do servidor. Clique em qualquer jogador para dar TP instantâneo."
})

ListSection:AddPlayerList({
    Title = "Server Players List",
    MaxVisible = 6, 
    Callback = function(player)
        if player == game:GetService("Players").LocalPlayer then
            Library:Notify({ Title = "Aviso", Content = "Você selecionou a si mesmo na lista!", Type = "warning", Duration = 3 })
            return
        end
        local pChar = player.Character
        local lChar = game:GetService("Players").LocalPlayer.Character
        if pChar and pChar:FindFirstChild("HumanoidRootPart") and lChar and lChar:FindFirstChild("HumanoidRootPart") then
            lChar.HumanoidRootPart.CFrame = pChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
            Library:Notify({ Title = "Teleport", Content = "TP executado para: " .. player.DisplayName, Type = "success", Duration = 3 })
        else
            Library:Notify({ Title = "Erro", Content = "O jogador selecionado não está vivo no momento!", Type = "error", Duration = 3 })
        end
    end
})




local VisualTab = Window:AddTab("Visuals")
local EspSection = VisualTab:AddSection("ESP Highlights")

EspSection:AddToggle({
    Flag = "EnableESP",
    Title = "Enable Player ESP",
    Description = "Destaca os jogadores através das paredes.",
    Default = false
})


EspSection:AddColorPicker({
    Flag = "ESPColor",
    Title = "ESP Highlight Color",
    Default = Color3.fromRGB(99, 102, 241),
    Callback = function(color)
        print("[Visuals] Nova cor do ESP:", color)
    end
})




local SettingsTab = Window:AddTab("Settings")
local ThemeSection = SettingsTab:AddSection("UI Accent Customization")

ThemeSection:AddLabel("Troque a cor principal (Accent) da interface em tempo real:")

ThemeSection:AddDropdown({
    Flag = "ThemeSelect",
    Title = "Select Theme Preset",
    Values = {"Electric Indigo", "Cyber Neon", "Crimson Rose", "Emerald Green", "Amber Gold"},
    Default = "Electric Indigo",
    Callback = function(themeName)
        if themeName == "Electric Indigo" then
            Library:SetAccent(Color3.fromRGB(99, 102, 241))
        elseif themeName == "Cyber Neon" then
            Library:SetAccent(Color3.fromRGB(6, 182, 212))
        elseif themeName == "Crimson Rose" then
            Library:SetAccent(Color3.fromRGB(244, 63, 94))
        elseif themeName == "Emerald Green" then
            Library:SetAccent(Color3.fromRGB(16, 185, 129))
        elseif themeName == "Amber Gold" then
            Library:SetAccent(Color3.fromRGB(245, 158, 11))
        end
        Library:Notify({ Title = "Tema Alterado", Content = "Aplicado o tema: " .. themeName, Type = "success", Duration = 2 })
    end
})

local KeybindSection = SettingsTab:AddSection("Keybinds & Controls")

KeybindSection:AddKeybind({
    Flag = "MinimizeKeybind",
    Title = "Toggle UI Visibility Key",
    Default = Enum.KeyCode.RightShift,
    Callback = function(newKey)
        Window._minimizeKey = newKey
        Library:Notify({ Title = "Atalho Atualizado", Content = "Nova tecla para ocultar/abrir: " .. newKey.Name, Type = "success", Duration = 3 })
    end
})

local TestSection = SettingsTab:AddSection("Notification System Tests")

TestSection:AddButton({
    Title = "Test Success Notification",
    Callback = function()
        Library:Notify({ Title = "Operação Concluída", Content = "Todos os dados foram sincronizados com sucesso.", Type = "success", Duration = 3 })
    end
})

TestSection:AddButton({
    Title = "Test Error Notification",
    Callback = function()
        Library:Notify({ Title = "Falha na Conexão", Content = "Não foi possível conectar ao servidor de destino.", Type = "error", Duration = 3 })
    end
})

TestSection:AddButton({
    Title = "Test Warning Notification",
    Callback = function()
        Library:Notify({ Title = "Aviso de Segurança", Content = "Essa funcionalidade pode ser detectada em servidores públicos.", Type = "warning", Duration = 3 })
    end
})

print("[KnotHub Limitless] Script carregado com sucesso!")
