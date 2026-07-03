
local Library
local success, localLib = pcall(function()
    return loadstring(readfile("KnotLib.lua"))()
end)

if success and localLib then
    Library = localLib
else
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/whylovehurts/knotlib/refs/heads/main/KnotLib.lua"))()
end

local Wait = task.wait
local Notifs = game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Remotes"):WaitForChild("RemoteEvent")


local KnotHub = {
    Flags = {
        autoCollectChikara = false,
        autoCollectDragonBalls = false,
        autoCollectFruits = false
    },
    Cache = {
        boxesFolder = workspace:WaitForChild("Scriptable"):WaitForChild("ChikaraBoxes"),
        fruitsFolder = workspace:WaitForChild("Scriptable"):WaitForChild("Fruits"),
        mouseIgnore = workspace:WaitForChild("MouseIgnore")
    },
    LastBallNotify = 0
}



function KnotHub:Notify(msg, notifType)
    
    pcall(function()
        firesignal(Notifs.OnClientEvent, "Notify", { msg })
    end)
    
    
    if Library and Library.Notify then
        Library:Notify({
            Title = "KnotHub",
            Content = msg,
            Type = notifType or "info",
            Duration = 3
        })
    end
end

function KnotHub:CollectShards()
    local crates = self.Cache.boxesFolder:GetChildren()
    for _, crate in pairs(crates) do
        local detector = crate:FindFirstChild("ClickBox") and crate.ClickBox:FindFirstChild("ClickDetector")
        if detector then
            fireclickdetector(detector)
            return true
        end
    end
    return false
end

function KnotHub:CollectFruits()
    local fruits = self.Cache.fruitsFolder:GetChildren()
    for _, fruit in pairs(fruits) do
        local detector = fruit:FindFirstChild("ClickBox") and fruit.ClickBox:FindFirstChild("ClickDetector")
        if detector then
            fireclickdetector(detector)
            return true
        end
    end
    return false
end

function KnotHub:CollectDragonBalls()
    local foundAny = false
    for _, obj in pairs(self.Cache.mouseIgnore:GetChildren()) do
        if obj:FindFirstChild("Meshes/dragon balls_Sphere.001", true) then
            local detector = obj:FindFirstChildWhichIsA("ClickDetector", true)
            if detector then
                fireclickdetector(detector)
                foundAny = true
                task.wait(0.1)
            end
        end
    end

    if not foundAny then
        
        if tick() - self.LastBallNotify >= 5 then
            self.LastBallNotify = tick()
            self:Notify("Esferas coletadas. Aguardando próximas...", "warning")
        end
    end
end



task.spawn(function()
    while Wait(11) do
        if KnotHub.Flags.autoCollectChikara then
            KnotHub:CollectShards()
        end
    end
end)

task.spawn(function()
    while Wait(1.1) do
        if KnotHub.Flags.autoCollectFruits then
            KnotHub:CollectFruits()
        end
    end
end)

task.spawn(function()
    while Wait(0.1) do
        if KnotHub.Flags.autoCollectDragonBalls then
            KnotHub:CollectDragonBalls()
        end
    end
end)



local Window = Library:CreateWindow({
    HubName = "KnotHub Anime Fighting",
    Size = UDim2.fromOffset(780, 440),
    MinimizeKey = Enum.KeyCode.RightShift
})


local MainTab = Window:CreateTab({ Name = "Main" })
local ServerTab = Window:CreateTab({ Name = "Server / Players" })
local SettingsTab = Window:CreateTab({ Name = "Settings" })





local StartSection = MainTab:CreateSection({ Name = "Start Here! :)" })

StartSection:AddButton({
    Name = "Click Me =///=",
    Callback = function()
        KnotHub:Notify("Use a aba Settings para personalizar temas e configs.", "info")
        task.wait(1.66)
        KnotHub:Notify("Customize sua UI na aba de temas e configurações.", "info")
        task.wait(1.66)
        KnotHub:Notify("Com amor, por medeiros =D", "success")
    end
})

local CollectablesSection = MainTab:CreateSection({ Name = "Collectables" })

CollectablesSection:AddToggle({
    Name = "Auto Chikara Boxes",
    Flag = "MainSec_AutoChikara",
    Default = false,
    Callback = function(Value)
        KnotHub.Flags.autoCollectChikara = Value
        if Value then
            KnotHub:Notify("Auto Chikara Boxes Ativado!", "success")
        end
    end
})

CollectablesSection:AddToggle({
    Name = "Auto Fruits",
    Flag = "MainSec_AutoFruits",
    Default = false,
    Callback = function(Value)
        KnotHub.Flags.autoCollectFruits = Value
        if Value then
            KnotHub:Notify("Auto Fruits Ativado!", "success")
        end
    end
})

CollectablesSection:AddToggle({
    Name = "Auto Dragon Balls",
    Flag = "MainSec_AutoBalls",
    Default = false,
    Callback = function(Value)
        KnotHub.Flags.autoCollectDragonBalls = Value
        if Value then
            KnotHub:Notify("Auto Dragon Balls Ativado!", "success")
        end
    end
})


local ScannerSection = MainTab:CreateSection({ Name = "Dynamic Scanner (v3.2)" })

ScannerSection:AddDropdown({
    Name = "Frutas Ativas no Servidor",
    ValuesFunction = function()
        local list = {}
        local fruits = workspace:FindFirstChild("Scriptable") and workspace.Scriptable:FindFirstChild("Fruits")
        if fruits then
            for _, f in pairs(fruits:GetChildren()) do
                if not table.find(list, f.Name) then
                    table.insert(list, f.Name)
                end
            end
        end
        if #list == 0 then
            return {"Nenhuma fruta disponível"}
        end
        return list
    end,
    Callback = function(selected)
        if selected and selected ~= "Nenhuma fruta disponível" then
            KnotHub:Notify("Fruta selecionada no radar: " .. tostring(selected), "info")
        end
    end
})

local InfoSection = MainTab:CreateSection({ Name = "Info's" })

local ExecLabel = InfoSection:AddLabel({
    Text = "Exec Time: 00:00:00"
})

InfoSection:AddLabel({
    Text = "Note: Fruits spawn/despawn every 10 minutes!"
})

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

task.spawn(function()
    local startTime = tick()
    while Wait(1) do 
        local duration = math.floor(tick() - startTime)
        local formatted = "Exec Time: " .. formatTime(duration)
        
        if ExecLabel then
            if type(ExecLabel.SetText) == "function" then
                ExecLabel:SetText(formatted)
            elseif type(ExecLabel.Set) == "function" then
                ExecLabel:Set(formatted)
            elseif type(ExecLabel) == "table" and ExecLabel.Text ~= nil then
                ExecLabel.Text = formatted
            end
        end
    end
end)





local PlayersSection = ServerTab:CreateSection({ Name = "Lista de Jogadores & Teleporte" })


PlayersSection:AddPlayerList({
    Name = "Selecione um Jogador para Teleportar",
    Callback = function(player)
        local localPlayer = game:GetService("Players").LocalPlayer
        if player and player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local localChar = localPlayer.Character
            if localChar and localChar:FindFirstChild("HumanoidRootPart") then
                localChar.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                KnotHub:Notify("Teleportado para: " .. player.Name, "success")
            else
                KnotHub:Notify("Seu personagem não está pronto para o teleporte.", "error")
            end
        else
            KnotHub:Notify("Jogador inválido ou é você mesmo.", "warning")
        end
    end
})





local ThemeSection = SettingsTab:CreateSection({ Name = "Temas & Cores (v3.2)" })

ThemeSection:AddButton({
    Name = "Tema Roxo (KnotHub Padrão)",
    Callback = function()
        if Library.SetAccent then
            Library:SetAccent(Color3.fromRGB(138, 43, 226))
        end
        KnotHub:Notify("Tema alterado para Roxo Padrão!", "success")
    end
})

ThemeSection:AddButton({
    Name = "Tema Vermelho Carmesim",
    Callback = function()
        if Library.SetAccent then
            Library:SetAccent(Color3.fromRGB(220, 20, 60))
        end
        KnotHub:Notify("Tema alterado para Carmesim!", "success")
    end
})

ThemeSection:AddButton({
    Name = "Tema Azul Oceano",
    Callback = function()
        if Library.SetAccent then
            Library:SetAccent(Color3.fromRGB(0, 150, 255))
        end
        KnotHub:Notify("Tema alterado para Azul Oceano!", "success")
    end
})

ThemeSection:AddButton({
    Name = "Tema Verde Esmeralda",
    Callback = function()
        if Library.SetAccent then
            Library:SetAccent(Color3.fromRGB(46, 204, 113))
        end
        KnotHub:Notify("Tema alterado para Esmeralda!", "success")
    end
})

local MiscSection = SettingsTab:CreateSection({ Name = "Atalhos & Créditos" })

MiscSection:AddButton({
    Name = "Atalho da Interface: RightShift",
    Callback = function()
        KnotHub:Notify("Pressione RightShift para ocultar/abrir o menu.", "info")
    end
})

MiscSection:AddButton({
    Name = "Créditos do Script",
    Callback = function()
        KnotHub:Notify("KnotHub Anime Fighting - Por medeiros =D", "success")
    end
})


if game:IsLoaded() then
    KnotHub:Notify("KnotHub v3.2 Carregado e Pronto!", "success")
end