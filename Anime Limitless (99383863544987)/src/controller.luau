--!nocheck
--[[
    Controller.luau — Backend / Service Layer (Anime Limitless)
    ───────────────────────────────────────────────────────────
    Architecture: Separation of Concerns (SoC)
      • This module owns ALL game logic, state, loops, and remote calls.
      • The UI (main.lua) must ONLY delegate — never execute business rules.

    Memory Optimization: Flyweight + Lazy Loading
      • SharedUtils: immutable Flyweight table for pure functions (no closures).
      • Sub-services: created lazily via __index on first access.
      • Metatables: prototype pattern for method sharing.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local _HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Flyweight: Shared Pure Functions (zero allocation overhead)
--------------------------------------------------------------------------------
local SharedUtils = {
    matchesMobName = function(instanceName: string?, targetName: string?): boolean
        if not instanceName or not targetName or targetName == "" then return false end
        if instanceName == targetName then return true end
        if string.find(instanceName, targetName) then
            if targetName == "Bandit" and string.find(instanceName, "Boss") then return false end
            if targetName == "Gorilla" and string.find(instanceName, "King") then return false end
            return true
        end
        return false
    end,

    isBossQuest = function(quest: {[string]: any}?): boolean
        if not quest then return false end
        local name = quest.WorkspaceName or quest.Target or ""
        local target = quest.Target or ""
        local bossKeywords = {"Boss", "King", "Arlog", "Gaaro", "Narudo", "17", "Veguta", "Megumo", "Sukuna", "Enel", "Kaidou", "Madara", "Aizen"}
        for _, kw in ipairs(bossKeywords) do
            if string.find(name, kw) or string.find(target, kw) then return true end
        end
        local bossFolder = workspace:FindFirstChild("Boss")
        if bossFolder then
            for _, child in ipairs(bossFolder:GetChildren()) do
                if SharedUtils.matchesMobName(child.Name, name) or SharedUtils.matchesMobName(child.Name, target) then
                    return true
                end
            end
        end
        return false
    end,

    isIgnoredChest = function(obj: Instance?): boolean
        if not obj then return true end
        local keywords = {
            "vip", "time", "gift", "claim", "free", "group", "reward",
            "daily", "lobby", "rank", "stand", "pass", "guild", "community"
        }
        local curr = obj
        while curr and curr ~= workspace do
            local n = string.lower(curr.Name)
            for _, kw in ipairs(keywords) do
                if string.find(n, kw) then return true end
            end
            curr = curr.Parent
        end
        local container = obj
        while container and container.Parent and container.Parent ~= workspace do
            container = container.Parent
        end
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if item:IsA("ProximityPrompt") then
                    local txt = string.lower((item.ActionText or "") .. " " .. (item.ObjectText or "") .. " " .. item.Name)
                    for _, kw in ipairs(keywords) do
                        if string.find(txt, kw) then return true end
                    end
                elseif item:IsA("TextLabel") or item:IsA("TextButton") then
                    local txt = string.lower(item.Text or "" .. " " .. item.Name)
                    for _, kw in ipairs(keywords) do
                        if string.find(txt, kw) then return true end
                    end
                end
            end
        end
        return false
    end,

    getEnemyFolders = function(): {Instance}
        local list = {}
        local f1 = workspace:FindFirstChild("NPC's") or workspace:FindFirstChild("NPCs")
        local f2 = workspace:FindFirstChild("Boss")
        local f3 = workspace:FindFirstChild("WaveEnemies")
        if f1 then table.insert(list, f1) end
        if f2 then table.insert(list, f2) end
        if f3 then table.insert(list, f3) end
        return list
    end,

    SafeTeleport = function(rootPart: BasePart?, cframe: CFrame)
        if rootPart then
            local targetPos = cframe.Position
            if targetPos.Y > -500 then
                rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Lazy-loaded Sub-Services (created on first access via __index)
--------------------------------------------------------------------------------
local QuestsService = {} :: {[string]: any}
QuestsService.__index = QuestsService

local FarmService = {} :: {[string]: any}
FarmService.__index = FarmService

local CombatService = {} :: {[string]: any}
CombatService.__index = CombatService

local TeleportService = {} :: {[string]: any}
TeleportService.__index = TeleportService

local ChestService = {} :: {[string]: any}
ChestService.__index = ChestService

local MiscService = {} :: {[string]: any}
MiscService.__index = MiscService

--------------------------------------------------------------------------------
-- Controller (Root)
--------------------------------------------------------------------------------
local Controller = {} :: {[string]: any}
Controller.__index = Controller

-- State (flags)
Controller.Flags = {
    autoFarm = false,
    instantKillAura = false,
    standaloneAura = false,
    fastAttackNormal = false,
    fastAttackAll = false,
    ultraFastSkillAttack = false,
    autoCollectChests = false,
    autoFarmHP = false,
    dupeFruit = false,
    selectedWeapon = "Combat",
    targetMobOverride = "Auto Best Quest",
    attackSpeed = 0.045,
    instantKillRange = 80,
    auraRange = 80,
}

-- Remotes (resolved lazily)
Controller._serverHandler = nil
Controller._remotesReady = false

-- Connections registry
Controller._connections = {}
Controller._loops = {}

-- Quest cache
Controller._fallbackQuests = {
    { NPC = "Dawn Quests", Target = "Bandits", WorkspaceName = "Bandit", MinLvl = 1 },
    { NPC = "Dawn Quests", Target = "Bandit Boss", WorkspaceName = "Bandit Boss", MinLvl = 11 },
    { NPC = "Monkey Quests", Target = "Monkeys", WorkspaceName = "Monkey", MinLvl = 21 },
    { NPC = "Monkey Quests", Target = "Gorillas", WorkspaceName = "Gorilla", MinLvl = 41 },
    { NPC = "Monkey Quests", Target = "Gorilla King", WorkspaceName = "Gorilla King", MinLvl = 61 },
    { NPC = "Fishman Quests", Target = "Fishman Guards", WorkspaceName = "Fishman Guard", MinLvl = 81 },
    { NPC = "Fishman Quests", Target = "Fishman Fighters", WorkspaceName = "Fishman Fighter", MinLvl = 101 },
    { NPC = "Fishman Quests", Target = "Arlog", WorkspaceName = "Arlog", MinLvl = 131 },
    { NPC = "Desert Quests", Target = "Sand Genins", WorkspaceName = "Sand Genin", MinLvl = 151 },
    { NPC = "Desert Quests", Target = "Sand Chunins", WorkspaceName = "Sand Chunin", MinLvl = 201 },
    { NPC = "Desert Quests", Target = "Gaaro", WorkspaceName = "Gaaro", MinLvl = 231 },
    { NPC = "Leaf Quests", Target = "Leaf Chunins", WorkspaceName = "Leaf Chunin", MinLvl = 251 },
    { NPC = "Leaf Quests", Target = "Leaf Jonins", WorkspaceName = "Leaf Jonin", MinLvl = 281 },
    { NPC = "Leaf Quests", Target = "Hakage Narudo", WorkspaceName = "Hakage Narudo", MinLvl = 301 },
    { NPC = "WestCity Quests", Target = "Saiyons", WorkspaceName = "Saiyon", MinLvl = 351 },
    { NPC = "WestCity Quests", Target = "Android 23s", WorkspaceName = "Android 23", MinLvl = 371 },
    { NPC = "WestCity Quests", Target = "Super 17", WorkspaceName = "Super 17", MinLvl = 401 },
    { NPC = "Truffle Quests", Target = "Truffle Minions", WorkspaceName = "Truffle Minion", MinLvl = 421 },
    { NPC = "Truffle Quests", Target = "Truffle Elites", WorkspaceName = "Truffle Elite", MinLvl = 441 },
    { NPC = "Truffle Quests", Target = "Baby Veguta", WorkspaceName = "Baby Veguta", MinLvl = 461 },
    { NPC = "JJK Quests", Target = "Grade2 Sorceres", WorkspaceName = "Grade2 Sorcere", MinLvl = 471 },
    { NPC = "JJK Quests", Target = "Grade1 Sorceres", WorkspaceName = "Grade1 Sorcere", MinLvl = 481 },
    { NPC = "JJK Quests", Target = "Megumo", WorkspaceName = "Megumo", MinLvl = 491 },
}
Controller._cachedQuests = nil

--------------------------------------------------------------------------------
-- Lazy Service Resolution via __index
--------------------------------------------------------------------------------
function Controller.__index(tbl, key)
    -- First check raw table
    local raw = rawget(tbl, key)
    if raw ~= nil then return raw end

    -- Lazy-create sub-services
    if key == "Quests" then
        local svc = setmetatable({_controller = tbl}, QuestsService)
        rawset(tbl, key, svc)
        return svc
    elseif key == "Farm" then
        local svc = setmetatable({_controller = tbl}, FarmService)
        rawset(tbl, key, svc)
        return svc
    elseif key == "Combat" then
        local svc = setmetatable({_controller = tbl}, CombatService)
        rawset(tbl, key, svc)
        return svc
    elseif key == "Teleport" then
        local svc = setmetatable({_controller = tbl}, TeleportService)
        rawset(tbl, key, svc)
        return svc
    elseif key == "Chests" then
        local svc = setmetatable({_controller = tbl}, ChestService)
        rawset(tbl, key, svc)
        return svc
    elseif key == "Misc" then
        local svc = setmetatable({_controller = tbl}, MiscService)
        rawset(tbl, key, svc)
        return svc
    end

    return nil
end

--------------------------------------------------------------------------------
-- Controller Init
--------------------------------------------------------------------------------
function Controller:Init()
    self:_resolveRemotes()
    self.Quests:_initCache()
    self:_startAutoHPListener()
end

function Controller:_resolveRemotes()
    local GameFolder = ReplicatedStorage:WaitForChild("Game", 10)
    local RemotesFolder = GameFolder and GameFolder:WaitForChild("Remotes", 10)
    self._serverHandler = RemotesFolder and RemotesFolder:WaitForChild("ServerHandler", 10)
    self._remotesReady = self._serverHandler ~= nil
end

function Controller:_startAutoHPListener()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        if self.Flags.autoFarmHP then
            pcall(function()
                local ev = ReplicatedStorage:FindFirstChild("RemoteEvent")
                if ev then ev:FireServer(true) end
            end)
        end
    end)
end

function Controller:FireRemote(name: string, ...: any)
    if not self._serverHandler then return end
    local args = table.pack(...)
    pcall(function()
        self._serverHandler:FireServer(name, table.unpack(args, 1, args.n))
    end)
end

function Controller:DisconnectAll()
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}
    for _, loop in ipairs(self._loops) do
        task.cancel(loop)
    end
    self._loops = {}
end

function Controller:AddConnection(conn)
    table.insert(self._connections, conn)
    return conn
end

function Controller:AddLoop(fn)
    local thread = task.spawn(fn)
    table.insert(self._loops, thread)
    return thread
end

--------------------------------------------------------------------------------
-- Quests Service
--------------------------------------------------------------------------------
function QuestsService:_initCache()
    if self._controller._cachedQuests then return end
    self._controller._cachedQuests = {}
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and rawget(v, 1) and type(rawget(v, 1)) == "table" and rawget(v[1], "LvlReq") then
                local req = tonumber(v[1].LvlReq) or 1
                local target = tostring(rawget(v, 4) or rawget(v, "Target") or "")
                local giver = tostring(rawget(v, 5) or rawget(v, "NPC") or "")
                if target ~= "" and giver ~= "" then
                    local mobName = target
                    if mobName:sub(-1) == "s" and not mobName:find("Boss") then
                        mobName = mobName:sub(1, -2)
                    end
                    table.insert(self._controller._cachedQuests, {
                        MinLvl = req, NPC = giver, Target = target, WorkspaceName = mobName
                    })
                end
            end
        end
        table.sort(self._controller._cachedQuests, function(a, b) return a.MinLvl < b.MinLvl end)
    end)
    if not self._controller._cachedQuests or #self._controller._cachedQuests == 0 then
        self._controller._cachedQuests = self._controller._fallbackQuests
    end
end

function QuestsService:getBestQuest()
    local playerLvl = 1
    pcall(function() playerLvl = LocalPlayer.Data.Level.Value end)
    local list = (self._controller._cachedQuests and #self._controller._cachedQuests > 0)
        and self._controller._cachedQuests or self._controller._fallbackQuests
    local best = list[1]
    local bestIdx = 1
    for i, q in ipairs(list) do
        if playerLvl >= q.MinLvl then best = q; bestIdx = i else break end
    end
    if SharedUtils.isBossQuest(best) and not self:isMobAlive(best.WorkspaceName) then
        for i = bestIdx - 1, 1, -1 do
            local q = list[i]
            if q.NPC == best.NPC and not SharedUtils.isBossQuest(q) then return q end
        end
    end
    return best
end

function QuestsService:isMobAlive(workspaceName: string?): boolean
    if not workspaceName or workspaceName == "" then return false end
    local folders = SharedUtils.getEnemyFolders()
    table.insert(folders, workspace)
    for _, folder in ipairs(folders) do
        for _, mob in ipairs(folder:GetChildren()) do
            if SharedUtils.matchesMobName(mob.Name, workspaceName) then
                local hum = mob:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then return true end
            end
        end
    end
    return false
end

function QuestsService:abandonCurrentQuest()
    pcall(function()
        local cur = nil
        pcall(function() cur = LocalPlayer.Data.CurrentQuest.Value end)
        if cur ~= nil and cur ~= "" then
            pcall(function() LocalPlayer.Data.CurrentQuest.Value = "" end)
            local sh = self._controller._serverHandler
            if sh then
                pcall(function() sh:FireServer("InteractControl", "Abandon") end)
                pcall(function() sh:FireServer("InteractControl", "AbandonQuest") end)
                pcall(function() sh:FireServer("InteractControl", cur, "Abandon") end)
                pcall(function() sh:FireServer("InteractControl", "Abandon", cur) end)
                pcall(function() sh:FireServer("QuestControl", "Abandon") end)
                pcall(function() sh:FireServer("QuestControl", "AbandonQuest") end)
                pcall(function() sh:FireServer("AbandonQuest") end)
                pcall(function() sh:FireServer("Abandon") end)
            end
            pcall(function()
                for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                    if v:IsA("RemoteEvent") and (string.find(string.lower(v.Name), "abandon") or string.find(string.lower(v.Name), "cancel")) then
                        v:FireServer()
                    end
                end
            end)
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                if pg then
                    for _, desc in ipairs(pg:GetDescendants()) do
                        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                            local txt = string.lower((desc:IsA("TextButton") and desc.Text or "") .. " " .. desc.Name)
                            if string.find(txt, "abandon") or string.find(txt, "cancel") or string.find(txt, "desistir") or string.find(txt, "drop") then
                                if firesignal then
                                    pcall(function() firesignal(desc.Activated) end)
                                    pcall(function() firesignal(desc.MouseButton1Click) end)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

function QuestsService:resolveMobName(override: string?, activeQuestValue: string?): string?
    if override and override ~= "Auto Best Quest" then return override end
    local bestQ = self:getBestQuest()
    if activeQuestValue and activeQuestValue ~= "" then
        local list = (self._controller._cachedQuests and #self._controller._cachedQuests > 0)
            and self._controller._cachedQuests or self._controller._fallbackQuests
        for _, q in ipairs(list) do
            if activeQuestValue == q.Target or activeQuestValue == q.WorkspaceName
                or string.find(activeQuestValue, q.Target)
                or string.find(activeQuestValue, q.WorkspaceName) then
                return q.WorkspaceName
            end
        end
        if string.sub(activeQuestValue, -1) == "s" and not string.find(activeQuestValue, "Boss") then
            return string.sub(activeQuestValue, 1, -2)
        end
        return activeQuestValue
    end
    if bestQ then return bestQ.WorkspaceName end
    return nil
end

function QuestsService:getMobList(): {string}
    return { "Auto Best Quest", "Fast Farm" }
end

--------------------------------------------------------------------------------
-- Combat Service
--------------------------------------------------------------------------------
function CombatService:getInventoryItems(): {string}
    local validWeapons = {}
    local knownWeapons = { "Combat" }
    pcall(function()
        local ti = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("ToolsInfo")
        if ti then
            for _, catName in ipairs({ "Melee", "Meele", "Sword", "Gun", "Soul" }) do
                local cat = ti:FindFirstChild(catName)
                if cat then
                    for _, item in ipairs(cat:GetChildren()) do
                        table.insert(knownWeapons, item.Name)
                    end
                end
            end
        end
    end)
    pcall(function()
        local function scan(f)
            if f then
                for _, i in ipairs(f:GetChildren()) do
                    if i:IsA("Tool") and table.find(knownWeapons, i.Name) then
                        if not table.find(validWeapons, i.Name) then
                            table.insert(validWeapons, i.Name)
                        end
                    end
                end
            end
        end
        scan(LocalPlayer:FindFirstChild("Backpack"))
        scan(LocalPlayer.Character)
    end)
    if #validWeapons == 0 then table.insert(validWeapons, "Combat") end
    return validWeapons
end

function CombatService:doCombatHit(defaultTool: string)
    local sh = self._controller._serverHandler
    if not sh then return end
    if self._controller.Flags.fastAttackAll then
        local inv = self:getInventoryItems()
        if #inv > 0 then
            local idx = self._toolIndex or 1
            if idx > #inv then idx = 1 end
            sh:FireServer("CombatControl", inv[idx], 1, false)
            self._toolIndex = idx + 1
        end
    else
        sh:FireServer("CombatControl", defaultTool, 1, false)
    end
end

function CombatService:getCombatDelay(): number
    local f = self._controller.Flags
    if f.fastAttackNormal or f.fastAttackAll then
        return tonumber(f.attackSpeed) or 0.045
    end
    return 0.045
end

function CombatService:fireUltraFastSkill()
    local sh = self._controller._serverHandler
    if not sh then return end
    local weapon = self._controller.Flags.selectedWeapon or "Combat"
    pcall(function()
        for _ = 1, 3 do
            sh:FireServer("SkillControl", weapon, 1, false)
            sh:FireServer("SkillControl", weapon, 2, false)
            sh:FireServer("SkillControl", weapon, 3, false)
            sh:FireServer("SkillControl", weapon, 4, false)
            sh:FireServer("SkillControl", weapon, "M1", false)
            sh:FireServer("SkillControl", weapon, "C", false)
            sh:FireServer("CombatControl", weapon, 1, false)
            sh:FireServer("CombatControl", weapon, 2, false)
            sh:FireServer("CombatControl", weapon, 3, false)
            sh:FireServer("CombatControl", weapon, 4, false)
        end
    end)
end

function CombatService:runStandaloneAttackLoop()
    self._toolIndex = 1
    while not self._controller._library.Unloaded do
        local f = self._controller.Flags
        local sh = self._controller._serverHandler
        local doingAttack = f.standaloneAura or f.fastAttackNormal or f.fastAttackAll
        local doingAuraOrFarm = f.autoFarm or f.instantKillAura
        if doingAttack and not doingAuraOrFarm and sh then
            pcall(function()
                if f.fastAttackAll then
                    local inv = self:getInventoryItems()
                    if #inv > 0 then
                        if self._toolIndex > #inv then self._toolIndex = 1 end
                        sh:FireServer("CombatControl", inv[self._toolIndex], 1, false)
                        self._toolIndex = self._toolIndex + 1
                    end
                    task.wait(f.attackSpeed or 0.045)
                else
                    sh:FireServer("CombatControl", f.selectedWeapon or "Combat", 1, false)
                    task.wait(f.attackSpeed or 0.045)
                end
            end)
        else
            task.wait(0.2)
        end
    end
end

--------------------------------------------------------------------------------
-- Farm Service
--------------------------------------------------------------------------------
function FarmService:_getMegumo()
    local folders = SharedUtils.getEnemyFolders()
    table.insert(folders, workspace)
    for _, f in ipairs(folders) do
        for _, mob in ipairs(f:GetChildren()) do
            if SharedUtils.matchesMobName(mob.Name, "Megumo") and mob:IsA("Model") then
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local mHRP = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                if hum and hum.Health > 0 and mHRP then return mob, hum, mHRP end
            end
        end
    end
    return nil
end

function FarmService:_findMobSpawnCFrame(mobName: string?): CFrame?
    if not mobName or mobName == "" then return nil end
    local spawnFolders = {
        workspace:FindFirstChild("NPCSpawns"), workspace:FindFirstChild("MobSpawns"),
        workspace:FindFirstChild("Spawns"), workspace:FindFirstChild("EnemySpawns"),
        workspace:FindFirstChild("SpawnPoints"),
    }
    local possibleNames = {
        mobName .. "Spawn", mobName .. " Spawn", mobName .. "Spawns",
        mobName .. " Spawns", mobName, mobName .. "s",
    }
    for _, folder in ipairs(spawnFolders) do
        if folder then
            for _, nameVariant in ipairs(possibleNames) do
                local child = folder:FindFirstChild(nameVariant)
                if child then
                    if child:IsA("BasePart") then return child.CFrame
                    elseif child:IsA("Model") then return child:GetPivot()
                    elseif child:IsA("Folder") then
                        for _, desc in ipairs(child:GetDescendants()) do
                            if desc:IsA("BasePart") then return desc.CFrame
                            elseif desc:IsA("Model") and desc.PrimaryPart then return desc:GetPivot() end
                        end
                    end
                end
            end
        end
    end
    for _, folder in ipairs(SharedUtils.getEnemyFolders()) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if SharedUtils.matchesMobName(obj.Name, mobName) then
                    if obj:IsA("BasePart") then return obj.CFrame
                    elseif obj:IsA("Model") then
                        local p = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
                        if p then return p.CFrame end
                    end
                end
            end
        end
    end
    return nil
end

function FarmService:_getIslandWaitingPoint(mobName: string?, questNPC: string?): Vector3
    local islands = {
        { name = "Dawn Island", point = Vector3.new(11, 73, 133), keys = {"Dawn Quests", "Bandit Boss", "Bandit"} },
        { name = "Monkey Island", point = Vector3.new(1291, 31, -890), keys = {"Monkey Quests", "Gorilla King", "Gorilla", "Monkey"} },
        { name = "Arlong Park", point = Vector3.new(-987, 20, -533), keys = {"Fishman Quests", "Fishman Guard", "Fishman Fighter", "Arlog", "Fishman"} },
        { name = "Desert Island", point = Vector3.new(-788, -5, 709), keys = {"Desert Quests", "Sand Genin", "Sand Chunin", "Gaaro", "Desert", "Sand"} },
        { name = "Hidden Village", point = Vector3.new(902, 53, 867), keys = {"Leaf Quests", "Leaf Chunin", "Leaf Jonin", "Hakage Narudo", "Leaf", "Narudo"} },
        { name = "West City", point = Vector3.new(1827, 85, -1850), keys = {"WestCity Quests", "Saiyon", "Android 23", "Super 17", "WestCity"} },
        { name = "Truffle Island", point = Vector3.new(-51, 80, -1704), keys = {"Truffle Quests", "Truffle Minion", "Truffle Elite", "Baby Veguta", "Truffle", "Veguta"} },
        { name = "JJK Island", point = Vector3.new(2568, 34, 211), keys = {"JJK Quests", "Grade2 Sorcere", "Grade1 Sorcere", "Megumo", "JJK"} },
        { name = "Summer Island", point = Vector3.new(502, 15, -419), keys = {"Summer Quests", "Summer"} },
    }
    local searchStr = string.lower(tostring(mobName or "") .. " " .. tostring(questNPC or ""))
    for _, isl in ipairs(islands) do
        for _, k in ipairs(isl.keys) do
            if string.find(searchStr, string.lower(k)) then return isl.point end
        end
    end
    local refPos = Vector3.new(0, 0, 0)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then refPos = hrp.Position end
    if questNPC and workspace:FindFirstChild("InteractNPCS") and workspace.InteractNPCS:FindFirstChild("QuestNPCS") then
        local giverModel = workspace.InteractNPCS.QuestNPCS:FindFirstChild(questNPC)
        if giverModel then
            refPos = giverModel:IsA("Model") and giverModel:GetPivot().Position or giverModel.Position
        end
    end
    local closestPoint = islands[1].point
    local minDist = math.huge
    for _, isl in ipairs(islands) do
        local d = (isl.point - refPos).Magnitude
        if d < minDist then minDist = d; closestPoint = isl.point end
    end
    return closestPoint
end

function FarmService:executeAutoFarm()
    local opts = self._controller.Flags
    local sh = self._controller._serverHandler
    if not sh then return end

    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local bossFolder = workspace:FindFirstChild("Boss")
    local waveFolder = workspace:FindFirstChild("WaveEnemies")
    local inDungeon = (bossFolder and #bossFolder:GetChildren() > 0) or (waveFolder and #waveFolder:GetChildren() > 0)

    local override = opts.targetMobOverride
    local activeQuestValue = nil
    pcall(function() activeQuestValue = LocalPlayer.Data.CurrentQuest.Value end)

    if override == "Fast Farm" then
        self:_handleFastFarm(rootPart, char, activeQuestValue, opts)
    else
        self:_handleStandardFarm(rootPart, char, override, activeQuestValue, opts, inDungeon, bossFolder, waveFolder)
    end
end

function FarmService:_handleFastFarm(rootPart, char, activeQuestValue, opts)
    local megumoMob, megumoHum, megumoHRP = self:_getMegumo()
    local quests = self._controller.Quests
    local sh = self._controller._serverHandler

    if megumoMob then
        if not activeQuestValue or not string.find(tostring(activeQuestValue), "Megumo") then
            if activeQuestValue ~= nil and activeQuestValue ~= "" and not string.find(tostring(activeQuestValue), "Megumo") then
                quests:abandonCurrentQuest()
                task.wait(0.2)
            end
            repeat
                if self._controller._library.Unloaded or not opts.autoFarm or not self:_getMegumo() then break end
                if activeQuestValue ~= nil and activeQuestValue ~= "" and not string.find(tostring(activeQuestValue), "Megumo") then
                    quests:abandonCurrentQuest(); task.wait(0.2)
                end
                SharedUtils.SafeTeleport(rootPart, CFrame.new(2628, 13, 82))
                sh:FireServer("InteractControl", "JJK Quests", "Megumo")
                task.wait(0.3)
                pcall(function() activeQuestValue = LocalPlayer.Data.CurrentQuest.Value end)
            until activeQuestValue and string.find(tostring(activeQuestValue), "Megumo")
        else
            local dist = (megumoHRP.Position - rootPart.Position).Magnitude
            if dist <= 80 then
                local mobPos = megumoHRP.Position
                local flatDir = Vector3.new(rootPart.Position.X - mobPos.X, 0, rootPart.Position.Z - mobPos.Z)
                if flatDir.Magnitude == 0 then flatDir = Vector3.new(0, 0, 1) else flatDir = flatDir.Unit end
                rootPart.CFrame = CFrame.lookAt(mobPos + flatDir * 3, mobPos)
                rootPart.AssemblyLinearVelocity = Vector3.zero

                task.wait(0.3)
                local toolToUse = opts.selectedWeapon or "Combat"
                local targetHealth = megumoHum.MaxHealth * 0.94
                while megumoHum and megumoHum.Parent and megumoHum.Health > targetHealth do
                    if self._controller._library.Unloaded or not opts.autoFarm then break end
                    self._controller.Combat:doCombatHit(toolToUse)
                    task.wait(self._controller.Combat:getCombatDelay())
                end
                if megumoHum and megumoHum.Health > 0 then
                    megumoHum.Health = 0
                    task.wait(0.2)
                    if megumoHum and megumoHum.Health > 0 then
                        sh:FireServer("CombatControl", toolToUse, 1, false)
                        megumoHum.Health = 0
                    end
                end
            end
        end
    else
        if not activeQuestValue or not string.find(tostring(activeQuestValue), "Grade2 Sorcere") then
            if activeQuestValue ~= nil and activeQuestValue ~= "" and not string.find(tostring(activeQuestValue), "Grade2 Sorcere") then
                quests:abandonCurrentQuest(); task.wait(0.2)
            end
            repeat
                if self._controller._library.Unloaded or not opts.autoFarm or self:_getMegumo() then break end
                SharedUtils.SafeTeleport(rootPart, CFrame.new(2427, 12, 164))
                sh:FireServer("InteractControl", "JJK Quests", "Grade2 Sorcerers")
                task.wait(0.3)
                pcall(function() activeQuestValue = LocalPlayer.Data.CurrentQuest.Value end)
            until activeQuestValue and string.find(tostring(activeQuestValue), "Grade2 Sorcere")
        end
    end
end

function FarmService:_handleStandardFarm(rootPart, char, override, activeQuestValue, opts, inDungeon, bossFolder, waveFolder)
    local quests = self._controller.Quests
    local sh = self._controller._serverHandler
    local toolToUse = opts.selectedWeapon or "Combat"

    local mobName = quests:resolveMobName(override, activeQuestValue)

    if inDungeon or (mobName and mobName ~= "") then
        for _, folder in ipairs(SharedUtils.getEnemyFolders()) do
            for _, mob in ipairs(folder:GetChildren()) do
                if self._controller._library.Unloaded or not opts.autoFarm then break end
                if (inDungeon or SharedUtils.matchesMobName(mob.Name, mobName)) and mob:IsA("Model") and mob ~= char then
                    local hum = mob:FindFirstChildOfClass("Humanoid")
                    local mHRP = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                    if hum and hum.Health > 0 and mHRP then
                        local dist = (mHRP.Position - rootPart.Position).Magnitude
                        if dist <= 80 then
                            local mobPos = mHRP.Position
                            local dir = (rootPart.Position - mobPos).Unit
                            if dir.Magnitude == 0 or dir ~= dir then dir = Vector3.new(0, 0, 1) end
                            rootPart.CFrame = CFrame.lookAt(mobPos + dir * 2.8, mobPos)

                            task.wait(0.3)
                            local targetHealth = hum.MaxHealth * 0.94
                            while hum and hum.Parent and hum.Health > targetHealth do
                                if self._controller._library.Unloaded or not opts.autoFarm then break end
                                self._controller.Combat:doCombatHit(toolToUse)
                                task.wait(self._controller.Combat:getCombatDelay())
                            end
                            if hum and hum.Health > 0 then
                                hum.Health = 0; task.wait(0.2)
                                if hum and hum.Health > 0 then
                                    sh:FireServer("CombatControl", toolToUse, 1, false)
                                    hum.Health = 0
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function FarmService:executeInstantKillAura()
    local opts = self._controller.Flags
    local sh = self._controller._serverHandler
    if not sh then return end

    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local maxRadius = opts.instantKillRange or 80
    local toolToUse = opts.selectedWeapon or "Combat"

    for _, folder in ipairs(SharedUtils.getEnemyFolders()) do
        for _, mob in ipairs(folder:GetChildren()) do
            if self._controller._library.Unloaded or not opts.instantKillAura then break end
            if mob:IsA("Model") and mob ~= char then
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local mHRP = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                if hum and hum.Health > 0 and mHRP then
                    local dist = (mHRP.Position - rootPart.Position).Magnitude
                    if dist <= maxRadius then
                        local mobPos = mHRP.Position
                        local dir = (rootPart.Position - mobPos).Unit
                        if dir.Magnitude == 0 or dir ~= dir then dir = Vector3.new(0, 0, 1) end
                        rootPart.CFrame = CFrame.lookAt(mobPos + dir * 2.8, mobPos)

                        task.wait(0.3)
                        local targetHealth = hum.MaxHealth * 0.94
                        while hum and hum.Parent and hum.Health > targetHealth do
                            if self._controller._library.Unloaded or not opts.instantKillAura then break end
                            self._controller.Combat:doCombatHit(toolToUse)
                            task.wait(self._controller.Combat:getCombatDelay())
                        end
                        if hum and hum.Health > 0 then
                            hum.Health = 0; task.wait(0.2)
                            if hum and hum.Health > 0 then
                                sh:FireServer("CombatControl", toolToUse, 1, false)
                                hum.Health = 0
                            end
                        end
                    end
                end
            end
        end
    end
end

function FarmService:executeStandaloneAura()
    local opts = self._controller.Flags
    local sh = self._controller._serverHandler
    if not sh then return end

    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local maxRadius = opts.auraRange or 80
    local toolToUse = opts.selectedWeapon or "Combat"

    for _, folder in ipairs(SharedUtils.getEnemyFolders()) do
        for _, mob in ipairs(folder:GetChildren()) do
            if self._controller._library.Unloaded or not opts.standaloneAura then break end
            if mob:IsA("Model") and mob ~= char then
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local mHRP = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                if hum and hum.Health > 0 and mHRP then
                    local dist = (mHRP.Position - rootPart.Position).Magnitude
                    if dist <= maxRadius then
                        local t0 = os.clock()
                        while hum and hum.Parent and hum.Health > 0 and (os.clock() - t0) < 10 do
                            if self._controller._library.Unloaded or not opts.standaloneAura then break end
                            local oldCF = rootPart.CFrame
                            local cam = workspace.CurrentCamera
                            local camCF = cam.CFrame
                            local camSub = cam.CameraSubject
                            cam.CameraType = Enum.CameraType.Scriptable
                            cam.CFrame = camCF

                            rootPart.CFrame = CFrame.new(mHRP.Position + Vector3.new(0, 0, 2.5))
                            task.wait(0.03)
                            sh:FireServer("CombatControl", toolToUse, 1, false)
                            task.wait(0.03)
                            rootPart.CFrame = oldCF
                            cam.CameraType = Enum.CameraType.Custom
                            cam.CameraSubject = camSub
                            task.wait(self._controller.Combat:getCombatDelay())
                        end
                    end
                end
            end
        end
    end
end

function FarmService:steppedTick()
    local opts = self._controller.Flags
    local sh = self._controller._serverHandler
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local doingFarm = opts.autoFarm
    local doingAura = opts.standaloneAura
    if not doingFarm and not doingAura then return end

    if doingFarm and sh then
        self:executeAutoFarm()
    end
end

function FarmService:getBestQuestMob(): {Mob: Model, Dist: number, HRP: BasePart}?
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local validMobs = {}
    local bossFolder = workspace:FindFirstChild("Boss")
    local waveFolder = workspace:FindFirstChild("WaveEnemies")
    local inDungeon = (bossFolder and #bossFolder:GetChildren() > 0) or (waveFolder and #waveFolder:GetChildren() > 0)
    local _opts = self._controller.Flags

    if inDungeon then
        for _, f in ipairs({bossFolder, waveFolder}) do
            if f then
                for _, mob in ipairs(f:GetChildren()) do
                    if mob:IsA("Model") and mob ~= char then
                        local hum = mob:FindFirstChildOfClass("Humanoid")
                        local mHRP = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                        if hum and hum.Health > 0 and mHRP then
                            table.insert(validMobs, {Mob = mob, Dist = (mHRP.Position - rootPart.Position).Magnitude, HRP = mHRP})
                        end
                    end
                end
            end
        end
    end

    table.sort(validMobs, function(a, b) return a.Dist < b.Dist end)
    if #validMobs > 0 then return validMobs[1] end
    return nil
end

--------------------------------------------------------------------------------
-- Teleport Service
--------------------------------------------------------------------------------
function TeleportService:toPlayer(targetPlayer: Player)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and hrp then
        SharedUtils.SafeTeleport(hrp, targetPlayer.Character.HumanoidRootPart.CFrame)
        return true
    end
    return false
end

function TeleportService:collectAllChests()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end

    local count = 0
    local function collectFolder(f)
        if root and f then
            for _, chest in ipairs(f:GetChildren()) do
                if not SharedUtils.isIgnoredChest(chest) then
                    if chest:IsA("BasePart") then
                        if firetouchinterest then
                            firetouchinterest(root, chest, 0)
                            firetouchinterest(root, chest, 1)
                        end
                        chest.CFrame = root.CFrame
                        count = count + 1
                    else
                        for _, part in ipairs(chest:GetDescendants()) do
                            if not SharedUtils.isIgnoredChest(part) and part:IsA("BasePart") then
                                if firetouchinterest then
                                    firetouchinterest(root, part, 0)
                                    firetouchinterest(root, part, 1)
                                end
                                part.CFrame = root.CFrame
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end
    collectFolder(workspace:FindFirstChild("Chests"))
    collectFolder(workspace:FindFirstChild("Chest"))
    return count
end

function TeleportService:showInGameTeleporter(show: boolean)
    local ok = pcall(function()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        local hud = gui and gui:FindFirstChild("HUD")
        local tpMenu = hud and hud:FindFirstChild("Teleporter")
        if tpMenu then
            tpMenu.Visible = show
        end
    end)
    return ok
end

function TeleportService:chestAutoCollectLoop()
    while not self._controller._library.Unloaded do
        local opts = self._controller.Flags
        if opts.autoCollectChests then
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local targets = {}
                local cf1 = workspace:FindFirstChild("Chests")
                if cf1 then for _, c in ipairs(cf1:GetChildren()) do table.insert(targets, c) end end
                local cf2 = workspace:FindFirstChild("Chest")
                if cf2 then
                    if cf2:IsA("Folder") or cf2:IsA("Model") then
                        for _, c in ipairs(cf2:GetChildren()) do table.insert(targets, c) end
                    end
                    table.insert(targets, cf2)
                end
                for _, c in ipairs(workspace:GetChildren()) do
                    if (c.Name == "Chest" or c.Name:find("Drop")) and c ~= cf1 and c ~= cf2 then
                        table.insert(targets, c)
                    end
                end
                for _, chest in ipairs(targets) do
                    if not SharedUtils.isIgnoredChest(chest) then
                        if chest:IsA("BasePart") then
                            if firetouchinterest then
                                firetouchinterest(root, chest, 0)
                                firetouchinterest(root, chest, 1)
                            end
                            chest.CFrame = root.CFrame
                        else
                            for _, part in ipairs(chest:GetDescendants()) do
                                if not SharedUtils.isIgnoredChest(part) and part:IsA("BasePart") then
                                    if firetouchinterest then
                                        firetouchinterest(root, part, 0)
                                        firetouchinterest(root, part, 1)
                                    end
                                    part.CFrame = root.CFrame
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.5)
        else
            task.wait(1.0)
        end
    end
end

--------------------------------------------------------------------------------
-- Chest Service
--------------------------------------------------------------------------------
function ChestService:collectAllImmediately(): number
    return self._controller.Teleport:collectAllChests()
end

--------------------------------------------------------------------------------
-- Misc Service (Dupe Fruit, etc.)
--------------------------------------------------------------------------------
function MiscService:dupeFruitLoop()
    while not self._controller._library.Unloaded do
        local opts = self._controller.Flags
        if opts.dupeFruit and self._controller._serverHandler then
            pcall(function()
                local function checkAndFire(item)
                    if item:IsA("Tool") then
                        self._controller:FireRemote("StoreSoul", item)
                        if string.find(string.lower(item.Name), "soul") or string.find(string.lower(item.Name), "fruit") then
                            self._controller:FireRemote("StoreSoul", item.Name)
                        end
                    end
                end
                local char = LocalPlayer.Character
                if char then for _, item in ipairs(char:GetChildren()) do checkAndFire(item) end end
                local bp = LocalPlayer:FindFirstChild("Backpack")
                if bp then for _, item in ipairs(bp:GetChildren()) do checkAndFire(item) end end
            end)
            task.wait()
        else
            task.wait(0.25)
        end
    end
end

function MiscService:fireAutoFarmHP(state: boolean)
    pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("RemoteEvent")
        if ev then ev:FireServer(state) end
    end)
end

--------------------------------------------------------------------------------
-- Start All Loops (called after UI is ready)
--------------------------------------------------------------------------------
function Controller:StartLoops()
    -- Instant Kill Aura
    self:AddLoop(function()
        while not self._library.Unloaded do
            if self.Flags.instantKillAura then
                pcall(function() self.Farm:executeInstantKillAura() end)
                task.wait(0.1)
            else
                task.wait(0.25)
            end
        end
    end)

    -- Standalone Aura
    self:AddLoop(function()
        while not self._library.Unloaded do
            if self.Flags.standaloneAura then
                pcall(function() self.Farm:executeStandaloneAura() end)
                task.wait(0.1)
            else
                task.wait(0.25)
            end
        end
    end)

    -- Auto Farm Main Loop
    self:AddLoop(function()
        while not self._library.Unloaded do
            if self.Flags.autoFarm and self._serverHandler then
                pcall(function() self.Farm:executeAutoFarm() end)
                task.wait(0.1)
            else
                task.wait(0.25)
            end
        end
    end)

    -- Chest Auto Collect
    self:AddLoop(function()
        self.Teleport:chestAutoCollectLoop()
    end)

    -- Auto Chests (no TP)
    self:AddLoop(function()
        while not self._library.Unloaded do
            if self.Flags.autoCollectChests then
                pcall(function()
                    self.Teleport:collectAllChests()
                end)
                task.wait(0.5)
            else
                task.wait(1.0)
            end
        end
    end)

    -- Stepped (Farm + Aura positioning)
    self:AddConnection(RunService.Stepped:Connect(function()
        if self._library.Unloaded then return end
        pcall(function() self.Farm:steppedTick() end)
    end))

    -- Fast Attack Standalone Loop
    self:AddLoop(function()
        self.Combat:runStandaloneAttackLoop()
    end)

    -- Ultra Fast Skill (Heartbeat)
    self:AddConnection(RunService.Heartbeat:Connect(function()
        if self._library.Unloaded then return end
        if self.Flags.ultraFastSkillAttack then
            self.Combat:fireUltraFastSkill()
        end
    end))

    -- Dupe Fruit Loop
    self:AddLoop(function()
        self.Misc:dupeFruitLoop()
    end)
end

setmetatable(Controller, Controller)
return Controller
