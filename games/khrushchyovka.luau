--[[
    ═══════════════════════════════════════════════════════════════════════════
    KHRUSHCHYOVKA [HORROR] // ULTIMATE SURVIVAL & AUTOMATION SUITE
    Target Place: Хрущёвка 🎃 [Ужасы] (Place ID: 82115753075808)
    Built for: Potassium Executor
    ═══════════════════════════════════════════════════════════════════════════
]]

if _G.KhrushchyovkaHub then
    pcall(function() _G.KhrushchyovkaHub:Unload() end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- Safely require Client Controllers
local MovementController
pcall(function()
    MovementController = require(LocalPlayer.PlayerScripts.Client.MovementController)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- GLOBAL STATE & SETTINGS
-- ─────────────────────────────────────────────────────────────────────────────
local Hub = {
    Connections = {},
    ESPObjects = {},
    OriginalLighting = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        ClockTime = Lighting.ClockTime,
    },
    CameraLight = nil,
    RushBanner = nil,
    UI = nil,
    ActiveTab = "Visuals",
    IsMinimized = false,
    Visible = true,
}
_G.KhrushchyovkaHub = Hub

local Config = {
    Visuals = {
        MonsterESP = true,
        ItemESP = true,
        DoorESP = true,
        HidingESP = false,
        LootESP = true,
        Fullbright = true,
    },
    Movement = {
        InfiniteStamina = true,
        SpeedMultiplier = 1.5,
        Noclip = false,
        DoorNoclip = true,
        AntiStun = true,
    },
    Survival = {
        RushWarning = true,
        PioneerFreeze = true,
        InstantPrompts = true,
        AutoGrabItems = true,
        AutoSolveMinigames = true,
        AutoHideOnRush = false,
    }
}

-- ─────────────────────────────────────────────────────────────────────────────
-- UTILITY FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────
local function createESP(target, text, color, isModel)
    if not target or not target.Parent then return nil end
    local adornmentPart = isModel and (target.PrimaryPart or target:FindFirstChild("Core") or target:FindFirstChild("Handle") or target:FindFirstChildWhichIsA("BasePart")) or target
    if not adornmentPart or not adornmentPart:IsA("BasePart") then return nil end

    -- Billboard Text
    local bb = Instance.new("BillboardGui")
    bb.Name = "Khrush_ESP"
    bb.Adornee = adornmentPart
    bb.Size = UDim2.new(0, 140, 0, 35)
    bb.StudsOffset = Vector3.new(0, 2.4, 0)
    bb.AlwaysOnTop = true

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = bb

    -- Highlight Box
    local hl = Instance.new("Highlight")
    hl.Name = "Khrush_HL"
    hl.Adornee = target
    hl.FillColor = color
    hl.FillTransparency = 0.65
    hl.OutlineColor = color
    hl.OutlineTransparency = 0.1
    hl.Parent = target

    bb.Parent = CoreGui
    return { Gui = bb, Highlight = hl, Label = label, Part = adornmentPart, BaseText = text }
end

local function cleanESP(key)
    if Hub.ESPObjects[key] then
        pcall(function()
            if Hub.ESPObjects[key].Gui then Hub.ESPObjects[key].Gui:Destroy() end
            if Hub.ESPObjects[key].Highlight then Hub.ESPObjects[key].Highlight:Destroy() end
        end)
        Hub.ESPObjects[key] = nil
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- VISUALS: FULLBRIGHT & AMBIENT ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
local function applyFullbright(enabled)
    if enabled then
        Lighting.Ambient = Color3.fromRGB(240, 240, 240)
        Lighting.OutdoorAmbient = Color3.fromRGB(240, 240, 240)
        Lighting.Brightness = 2.4
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.ClockTime = 14

        -- Disable dark atmosphere effects
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            elseif effect:IsA("Atmosphere") then
                effect.Density = 0
            end
        end

        -- Camera lantern
        if not Hub.CameraLight or not Hub.CameraLight.Parent then
            local light = Instance.new("PointLight")
            light.Name = "Khrush_CameraLantern"
            light.Color = Color3.fromRGB(255, 255, 240)
            light.Range = 80
            light.Brightness = 2.0
            light.Shadows = false
            light.Parent = Camera
            Hub.CameraLight = light
        end
    else
        Lighting.Ambient = Hub.OriginalLighting.Ambient
        Lighting.OutdoorAmbient = Hub.OriginalLighting.OutdoorAmbient
        Lighting.Brightness = Hub.OriginalLighting.Brightness
        Lighting.FogEnd = Hub.OriginalLighting.FogEnd
        Lighting.GlobalShadows = Hub.OriginalLighting.GlobalShadows
        Lighting.ClockTime = Hub.OriginalLighting.ClockTime

        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = true
            elseif effect:IsA("Atmosphere") then
                effect.Density = 0.35
            end
        end

        if Hub.CameraLight then
            Hub.CameraLight:Destroy()
            Hub.CameraLight = nil
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ESP TICK & SCANNER
-- ─────────────────────────────────────────────────────────────────────────────
local function updateESP()
    local myChar = LocalPlayer.Character
    local root = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = root and root.Position or Vector3.zero

    -- 1. Monster ESP (workspace.FX walkers + CollectionService Watchables)
    if Config.Visuals.MonsterESP then
        -- Walkers in workspace.FX
        local fxFolder = workspace:FindFirstChild("FX")
        if fxFolder then
            for _, monster in ipairs(fxFolder:GetChildren()) do
                if monster:IsA("Model") and monster.Name ~= "EyeAdaptation" and monster.Name ~= "SoundAnchor" then
                    local id = "Monster_" .. monster:GetDebugId()
                    if not Hub.ESPObjects[id] then
                        Hub.ESPObjects[id] = createESP(monster, monster.Name .. " [MONSTER]", Color3.fromRGB(255, 50, 70), true)
                    end
                end
            end
        end

        -- Plaster Pioneer / Statues
        for _, statue in ipairs(CollectionService:GetTagged("Watchable")) do
            if statue:IsA("Model") and statue:IsDescendantOf(workspace) then
                local id = "Statue_" .. statue:GetDebugId()
                if not Hub.ESPObjects[id] then
                    Hub.ESPObjects[id] = createESP(statue, "Pioneer [STATUE]", Color3.fromRGB(255, 170, 0), true)
                end
            end
        end
    else
        for k, v in pairs(Hub.ESPObjects) do
            if k:sub(1, 8) == "Monster_" or k:sub(1, 7) == "Statue_" then
                cleanESP(k)
            end
        end
    end

    -- 2. Items & Keys ESP
    if Config.Visuals.ItemESP then
        local runFolder = workspace:FindFirstChild("Run")
        local searchRoots = runFolder and { runFolder } or { workspace }
        for _, rootObj in ipairs(searchRoots) do
            for _, item in ipairs(rootObj:GetDescendants()) do
                if item:IsA("Model") and (item.Name:sub(1, 7) == "Pickup_" or item:GetAttribute("Item")) then
                    local id = "Item_" .. item:GetDebugId()
                    if not Hub.ESPObjects[id] then
                        local itemName = item:GetAttribute("Item") or item.Name:gsub("^Pickup_", "")
                        local color = itemName:find("Key") and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(60, 230, 140)
                        Hub.ESPObjects[id] = createESP(item, itemName, color, true)
                    end
                end
            end
        end
    else
        for k, v in pairs(Hub.ESPObjects) do
            if k:sub(1, 5) == "Item_" then cleanESP(k) end
        end
    end

    -- 3. Doors ESP
    if Config.Visuals.DoorESP then
        for _, door in ipairs(CollectionService:GetTagged("Door")) do
            if door:IsDescendantOf(workspace) then
                local id = "Door_" .. door:GetDebugId()
                if not Hub.ESPObjects[id] then
                    local num = door:GetAttribute("Number") or "?"
                    local locked = door:GetAttribute("Locked")
                    local text = string.format("Door #%s%s", tostring(num), locked and " [LOCKED]" or "")
                    local color = locked and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(80, 200, 255)
                    Hub.ESPObjects[id] = createESP(door, text, color, true)
                end
            end
        end
    else
        for k, v in pairs(Hub.ESPObjects) do
            if k:sub(1, 5) == "Door_" then cleanESP(k) end
        end
    end

    -- 4. Hiding Spots ESP
    if Config.Visuals.HidingESP then
        for _, spot in ipairs(CollectionService:GetTagged("HidingSpot")) do
            if spot:IsDescendantOf(workspace) then
                local id = "Hide_" .. spot:GetDebugId()
                if not Hub.ESPObjects[id] then
                    local hideType = spot:GetAttribute("HideType") or spot.Name
                    Hub.ESPObjects[id] = createESP(spot, hideType .. " [HIDE]", Color3.fromRGB(160, 100, 255), true)
                end
            end
        end
    else
        for k, v in pairs(Hub.ESPObjects) do
            if k:sub(1, 5) == "Hide_" then cleanESP(k) end
        end
    end

    -- 5. Loot Container ESP
    if Config.Visuals.LootESP then
        for _, cont in ipairs(CollectionService:GetTagged("LootContainer")) do
            if cont:IsDescendantOf(workspace) then
                local id = "Loot_" .. cont:GetDebugId()
                if not Hub.ESPObjects[id] then
                    Hub.ESPObjects[id] = createESP(cont, cont.Name, Color3.fromRGB(255, 160, 60), true)
                end
            end
        end
    else
        for k, v in pairs(Hub.ESPObjects) do
            if k:sub(1, 5) == "Loot_" then cleanESP(k) end
        end
    end

    -- Update Distances and Purge Destroyed Objects
    for id, data in pairs(Hub.ESPObjects) do
        if not data.Part or not data.Part.Parent then
            cleanESP(id)
        else
            local dist = math.floor((data.Part.Position - myPos).Magnitude)
            data.Label.Text = string.format("%s\n[%d m]", data.BaseText, dist)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SURVIVAL & AUTOMATION ENGINE
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Rush Early Warning Banner UI
local function showRushWarning(warnTime)
    if not Config.Survival.RushWarning then return end
    if Hub.RushBanner then Hub.RushBanner:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Khrush_RushWarning"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 9999

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 480, 0, 75)
    frame.Position = UDim2.new(0.5, -240, 0.08, 0)
    frame.BackgroundColor3 = Color3.fromRGB(180, 20, 30)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 10)
    uic.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 230, 50)
    stroke.Thickness = 2.5
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚠️ RUSH INCOMING! HIDE NOW! ⚠️"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 19
    title.Parent = frame

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0.45, 0)
    sub.Position = UDim2.new(0, 0, 0.55, 0)
    sub.BackgroundTransparency = 1
    sub.Text = string.format("Approaching fast! Remaining: %.1fs", warnTime or 4.5)
    sub.TextColor3 = Color3.fromRGB(255, 220, 200)
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 14
    sub.Parent = frame

    sg.Parent = CoreGui
    Hub.RushBanner = sg

    -- Audible Alert Beep
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9069609200"
    sound.Volume = 1.0
    sound.Parent = Camera
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)

    -- Auto Hide trigger if enabled
    if Config.Survival.AutoHideOnRush then
        task.spawn(function()
            local spots = CollectionService:GetTagged("HidingSpot")
            local myChar = LocalPlayer.Character
            local root = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if root and #spots > 0 then
                local bestSpot, bestDist = nil, math.huge
                for _, s in ipairs(spots) do
                    local dist = (s:GetPivot().Position - root.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestSpot = s
                    end
                end
                if bestSpot then
                    root.CFrame = bestSpot:GetPivot() * CFrame.new(0, 1, 0)
                    task.wait(0.1)
                    for _, p in ipairs(bestSpot:GetDescendants()) do
                        if p:IsA("ProximityPrompt") then
                            fireproximityprompt(p, 0)
                            break
                        end
                    end
                end
            end
        end)
    end

    -- Flash Banner
    task.spawn(function()
        local t0 = os.clock()
        local dur = warnTime or 4.5
        while os.clock() - t0 < dur and Hub.RushBanner == sg do
            local rem = math.max(0, dur - (os.clock() - t0))
            sub.Text = string.format("Approaching fast! Remaining: %.1fs", rem)
            frame.BackgroundColor3 = (math.floor((os.clock() - t0) * 5) % 2 == 0) and Color3.fromRGB(180, 20, 30) or Color3.fromRGB(60, 10, 15)
            task.wait(0.1)
        end
        if Hub.RushBanner == sg then
            sg:Destroy()
            Hub.RushBanner = nil
        end
    end)
end

-- Listen to Monster Rush Warnings
if Remotes and Remotes:FindFirstChild("MonsterEvent") then
    table.insert(Hub.Connections, Remotes.MonsterEvent.OnClientEvent:Connect(function(event, data)
        if event == "RushWarn" or event == "Rush" then
            local dur = (data and typeof(data) == "table" and data.warn) or 4.5
            showRushWarning(dur)
        end
    end))
end

-- 2. Pioneer Auto-Freeze Loop
local function freezePioneerStatues()
    if not Config.Survival.PioneerFreeze or not Remotes or not Remotes:FindFirstChild("Sight") then return end
    local watchables = CollectionService:GetTagged("Watchable")
    if #watchables == 0 then return end

    local payload = {}
    for _, statue in ipairs(watchables) do
        local monsterId = statue:GetAttribute("MonsterId")
        if monsterId then
            payload[monsterId] = true
        end
    end

    if next(payload) ~= nil then
        Remotes.Sight:FireServer(payload)
    end
end

-- 3. Auto-Solve Minigames
if Remotes and Remotes:FindFirstChild("Minigame") then
    table.insert(Hub.Connections, Remotes.Minigame.OnClientEvent:Connect(function(action, id, gameType, opts)
        if action == "Start" and Config.Survival.AutoSolveMinigames then
            task.delay(0.2, function()
                Remotes.Minigame:FireServer("Done", id)
            end)
        end
    end))
end

-- 4. Instant Prompts & Auto-Grab Items
local function processPromptsAndItems()
    local myChar = LocalPlayer.Character
    local root = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = root and root.Position

    -- Zero hold duration on all Prompts
    if Config.Survival.InstantPrompts then
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                p.HoldDuration = 0
                if p.MaxActivationDistance < 22 then
                    p.MaxActivationDistance = 22
                end
            end
        end
    end

    -- Auto-grab loose items nearby
    if Config.Survival.AutoGrabItems and myPos then
        local run = workspace:FindFirstChild("Run")
        local container = run or workspace
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:sub(1, 7) == "Pickup_" or obj:GetAttribute("Item")) then
                local pivot = obj:GetPivot().Position
                if (pivot - myPos).Magnitude <= 16 then
                    for _, p in ipairs(obj:GetDescendants()) do
                        if p:IsA("ProximityPrompt") then
                            fireproximityprompt(p, 0)
                            break
                        end
                    end
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MOVEMENT & PLAYER ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
local function processMovement()
    if not MovementController then return end

    -- Infinite Stamina
    if Config.Movement.InfiniteStamina then
        MovementController.adrenaline = true
        MovementController.stamina = MovementController.maxStamina and MovementController.maxStamina() or 100
        MovementController.exhausted = false
        MovementController.noSprint = false
    else
        MovementController.adrenaline = false
    end

    -- Speed Multiplier
    MovementController.speedMul = Config.Movement.SpeedMultiplier

    -- Anti-Stun
    if Config.Movement.AntiStun then
        MovementController.stunUntil = 0
        MovementController.locked = false
    end

    -- Door Noclip (disables collisions on door leaf parts)
    if Config.Movement.DoorNoclip then
        for _, door in ipairs(CollectionService:GetTagged("Door")) do
            local leaf = door:FindFirstChild("Leaf")
            if leaf then
                for _, part in ipairs(leaf:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end
end

-- Player Noclip in Stepped
table.insert(Hub.Connections, RunService.Stepped:Connect(function()
    if Config.Movement.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end
end))

-- Heartbeat Master Loop
table.insert(Hub.Connections, RunService.Heartbeat:Connect(function()
    processMovement()
    freezePioneerStatues()
end))

-- RenderStepped Visuals & Prompts Loop (throttled to ~10hz for prompts)
local lastPromptScan = 0
table.insert(Hub.Connections, RunService.RenderStepped:Connect(function()
    updateESP()
    if os.clock() - lastPromptScan > 0.25 then
        lastPromptScan = os.clock()
        processPromptsAndItems()
    end
end))

-- ─────────────────────────────────────────────────────────────────────────────
-- OBSIDIAN MODERN UI SYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
local function buildUI()
    if Hub.UI then Hub.UI:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "KhrushchyovkaHubUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Container Window
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = UDim2.new(0, 530, 0, 420)
    main.Position = UDim2.new(0.5, -265, 0.5, -210)
    main.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = sg

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(38, 44, 58)
    mainStroke.Thickness = 1.5
    mainStroke.Parent = main

    -- Top Header / Drag Bar
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 46)
    header.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
    header.BorderSizePixel = 0
    header.Parent = main

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    -- Fix bottom corners of header
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 10)
    headerFix.Position = UDim2.new(0, 0, 1, -10)
    headerFix.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 260, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "KHRUSHCHYOVKA // HUB"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 95, 0, 20)
    badge.Position = UDim2.new(0, 205, 0.5, -10)
    badge.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    badge.BackgroundTransparency = 0.8
    badge.Text = "PHANTOM v1.0"
    badge.TextColor3 = Color3.fromRGB(0, 210, 255)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 10
    badge.Parent = header

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 4)
    badgeCorner.Parent = badge

    -- Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -74, 0.5, -15)
    minBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.Parent = header

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    -- Close / Unload Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(48, 24, 28)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 120)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    -- Drag Handling
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Minimize Handling
    minBtn.MouseButton1Click:Connect(function()
        Hub.IsMinimized = not Hub.IsMinimized
        if Hub.IsMinimized then
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 530, 0, 46)
            }):Play()
            minBtn.Text = "□"
        else
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 530, 0, 420)
            }):Play()
            minBtn.Text = "—"
        end
    end)

    -- Unload Handling
    closeBtn.MouseButton1Click:Connect(function()
        Hub:Unload()
    end)

    -- Left Navigation Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 145, 1, -46)
    sidebar.Position = UDim2.new(0, 0, 0, 46)
    sidebar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local sideList = Instance.new("UIListLayout")
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.Padding = UDim.new(0, 6)
    sideList.Parent = sidebar

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 12)
    sidePad.PaddingLeft = UDim.new(0, 10)
    sidePad.PaddingRight = UDim.new(0, 10)
    sidePad.Parent = sidebar

    -- Right Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -155, 1, -56)
    contentArea.Position = UDim2.new(0, 150, 0, 51)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = main

    local tabs = {}
    local tabButtons = {}

    local function switchTab(name)
        Hub.ActiveTab = name
        for tName, page in pairs(tabs) do
            page.Visible = (tName == name)
        end
        for tName, btn in pairs(tabButtons) do
            if tName == name then
                btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
                btn.TextColor3 = Color3.fromRGB(160, 170, 190)
            end
        end
    end

    local tabDefs = {
        { Id = "Visuals", Label = "👁 Visuals & ESP" },
        { Id = "Movement", Label = "⚡ Movement" },
        { Id = "Survival", Label = "🛡 Survival" }
    }

    for order, def in ipairs(tabDefs) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. def.Id
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
        btn.Text = def.Label
        btn.TextColor3 = Color3.fromRGB(160, 170, 190)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.LayoutOrder = order
        btn.Parent = sidebar

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn

        tabButtons[def.Id] = btn

        -- Page Frame
        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. def.Id
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 90)
        page.Visible = (order == 1)
        page.Parent = contentArea

        local pageList = Instance.new("UIListLayout")
        pageList.SortOrder = Enum.SortOrder.LayoutOrder
        pageList.Padding = UDim.new(0, 8)
        pageList.Parent = page

        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 4)
        pagePad.PaddingRight = UDim.new(0, 8)
        pagePad.Parent = page

        tabs[def.Id] = page

        btn.MouseButton1Click:Connect(function()
            switchTab(def.Id)
        end)
    end

    -- UI Component Helpers
    local function addToggle(page, labelText, descText, initialValue, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
        frame.BorderSizePixel = 0
        frame.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local titleL = Instance.new("TextLabel")
        titleL.Size = UDim2.new(1, -70, 0, 22)
        titleL.Position = UDim2.new(0, 12, 0, 6)
        titleL.BackgroundTransparency = 1
        titleL.Text = labelText
        titleL.TextColor3 = Color3.fromRGB(230, 235, 245)
        titleL.Font = Enum.Font.GothamBold
        titleL.TextSize = 13
        titleL.TextXAlignment = Enum.TextXAlignment.Left
        titleL.Parent = frame

        local descL = Instance.new("TextLabel")
        descL.Size = UDim2.new(1, -70, 0, 16)
        descL.Position = UDim2.new(0, 12, 0, 28)
        descL.BackgroundTransparency = 1
        descL.Text = descText
        descL.TextColor3 = Color3.fromRGB(140, 150, 170)
        descL.Font = Enum.Font.Gotham
        descL.TextSize = 11
        descL.TextXAlignment = Enum.TextXAlignment.Left
        descL.Parent = frame

        local switchBtn = Instance.new("TextButton")
        switchBtn.Size = UDim2.new(0, 44, 0, 24)
        switchBtn.Position = UDim2.new(1, -54, 0.5, -12)
        switchBtn.BackgroundColor3 = initialValue and Color3.fromRGB(0, 190, 140) or Color3.fromRGB(36, 40, 52)
        switchBtn.Text = ""
        switchBtn.Parent = frame

        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1, 0)
        switchCorner.Parent = switchBtn

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 18, 0, 18)
        dot.Position = initialValue and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.BorderSizePixel = 0
        dot.Parent = switchBtn

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        local state = initialValue
        switchBtn.MouseButton1Click:Connect(function()
            state = not state
            callback(state)
            TweenService:Create(switchBtn, TweenInfo.new(0.2), {
                BackgroundColor3 = state and Color3.fromRGB(0, 190, 140) or Color3.fromRGB(36, 40, 52)
            }):Play()
            TweenService:Create(dot, TweenInfo.new(0.2), {
                Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            }):Play()
        end)
    end

    local function addSlider(page, labelText, minVal, maxVal, initialVal, step, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 58)
        frame.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
        frame.BorderSizePixel = 0
        frame.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local titleL = Instance.new("TextLabel")
        titleL.Size = UDim2.new(1, -80, 0, 20)
        titleL.Position = UDim2.new(0, 12, 0, 8)
        titleL.BackgroundTransparency = 1
        titleL.Text = labelText
        titleL.TextColor3 = Color3.fromRGB(230, 235, 245)
        titleL.Font = Enum.Font.GothamBold
        titleL.TextSize = 13
        titleL.TextXAlignment = Enum.TextXAlignment.Left
        titleL.Parent = frame

        local valL = Instance.new("TextLabel")
        valL.Size = UDim2.new(0, 60, 0, 20)
        valL.Position = UDim2.new(1, -72, 0, 8)
        valL.BackgroundTransparency = 1
        valL.Text = string.format("%.1fx", initialVal)
        valL.TextColor3 = Color3.fromRGB(0, 200, 255)
        valL.Font = Enum.Font.GothamBold
        valL.TextSize = 13
        valL.TextXAlignment = Enum.TextXAlignment.Right
        valL.Parent = frame

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -24, 0, 6)
        barBg.Position = UDim2.new(0, 12, 0, 38)
        barBg.BackgroundColor3 = Color3.fromRGB(36, 42, 56)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = barBg

        local fillRatio = math.clamp((initialVal - minVal) / (maxVal - minVal), 0, 1)
        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(fillRatio, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(0, 190, 255)
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = barFill

        local activeDrag = false
        local function updateSlider(xPos)
            local relX = math.clamp((xPos - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            local rawVal = minVal + (maxVal - minVal) * relX
            local snapped = math.floor(rawVal / step + 0.5) * step
            barFill.Size = UDim2.new(relX, 0, 1, 0)
            valL.Text = string.format("%.1fx", snapped)
            callback(snapped)
        end

        barBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeDrag = true
                updateSlider(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeDrag = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(input.Position.X)
            end
        end)
    end

    -- ═════════════════════════════════════════════════════════════════════════
    -- POPULATE TABS
    -- ═════════════════════════════════════════════════════════════════════════

    -- TAB 1: VISUALS
    addToggle(tabs.Visuals, "Monster & Statue ESP", "Highlights active Walkers, Janitor, Neighbor, and Pioneer.", Config.Visuals.MonsterESP, function(v)
        Config.Visuals.MonsterESP = v
    end)
    addToggle(tabs.Visuals, "Items & Keys ESP", "Highlights all keys, tools, batteries, and collectibles.", Config.Visuals.ItemESP, function(v)
        Config.Visuals.ItemESP = v
    end)
    addToggle(tabs.Visuals, "Doors ESP", "Shows all room doors, door numbers, and locked states.", Config.Visuals.DoorESP, function(v)
        Config.Visuals.DoorESP = v
    end)
    addToggle(tabs.Visuals, "Loot Containers ESP", "Highlights drawers, cabinets, mailboxes, and safes.", Config.Visuals.LootESP, function(v)
        Config.Visuals.LootESP = v
    end)
    addToggle(tabs.Visuals, "Hiding Spots ESP", "Highlights wardrobes, under-beds, and tables.", Config.Visuals.HidingESP, function(v)
        Config.Visuals.HidingESP = v
    end)
    addToggle(tabs.Visuals, "Fullbright & Clear Fog", "Crystal clear illumination in the dark Soviet apartments.", Config.Visuals.Fullbright, function(v)
        Config.Visuals.Fullbright = v
        applyFullbright(v)
    end)

    -- TAB 2: MOVEMENT
    addToggle(tabs.Movement, "Infinite Stamina", "Adrenaline lock bypasses stamina drain completely.", Config.Movement.InfiniteStamina, function(v)
        Config.Movement.InfiniteStamina = v
    end)
    addSlider(tabs.Movement, "Sprint Speed Multiplier", 1.0, 3.0, Config.Movement.SpeedMultiplier, 0.1, function(v)
        Config.Movement.SpeedMultiplier = v
    end)
    addToggle(tabs.Movement, "Door Noclip", "Walk through all closed and locked doors naturally.", Config.Movement.DoorNoclip, function(v)
        Config.Movement.DoorNoclip = v
    end)
    addToggle(tabs.Movement, "Player Noclip", "Pass through any wall, obstacle, or barricade.", Config.Movement.Noclip, function(v)
        Config.Movement.Noclip = v
    end)
    addToggle(tabs.Movement, "Anti-Stun / Anti-Lock", "Prevents movement locks, stuns, and slow debuffs.", Config.Movement.AntiStun, function(v)
        Config.Movement.AntiStun = v
    end)

    -- TAB 3: SURVIVAL
    addToggle(tabs.Survival, "Rush Warning & Siren", "On-screen alert banner with timer whenever Rush triggers.", Config.Survival.RushWarning, function(v)
        Config.Survival.RushWarning = v
    end)
    addToggle(tabs.Survival, "Pioneer Auto-Freeze", "Spoofs sight rays so the Pioneer statue NEVER moves.", Config.Survival.PioneerFreeze, function(v)
        Config.Survival.PioneerFreeze = v
    end)
    addToggle(tabs.Survival, "Instant Proximity Prompts", "Removes hold time on all doors, items, and drawers.", Config.Survival.InstantPrompts, function(v)
        Config.Survival.InstantPrompts = v
    end)
    addToggle(tabs.Survival, "Auto-Grab Nearby Items", "Automatically grabs nearby keys and supplies.", Config.Survival.AutoGrabItems, function(v)
        Config.Survival.AutoGrabItems = v
    end)
    addToggle(tabs.Survival, "Auto-Solve Minigames", "Instantly completes keypads, lockpicks, and fuse boxes.", Config.Survival.AutoSolveMinigames, function(v)
        Config.Survival.AutoSolveMinigames = v
    end)
    addToggle(tabs.Survival, "Auto-Hide on Rush", "Automatically enters nearest wardrobe when Rush is near.", Config.Survival.AutoHideOnRush, function(v)
        Config.Survival.AutoHideOnRush = v
    end)

    switchTab("Visuals")
    applyFullbright(Config.Visuals.Fullbright)

    -- Keybind Toggle (RightShift or Insert)
    table.insert(Hub.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert) then
            Hub.Visible = not Hub.Visible
            main.Visible = Hub.Visible
        end
    end))

    sg.Parent = CoreGui
    Hub.UI = sg
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UNLOAD CLEANUP
-- ─────────────────────────────────────────────────────────────────────────────
function Hub:Unload()
    for _, conn in ipairs(Hub.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Hub.Connections = {}

    for id, _ in pairs(Hub.ESPObjects) do
        cleanESP(id)
    end
    Hub.ESPObjects = {}

    applyFullbright(false)

    if MovementController then
        pcall(function()
            MovementController.speedMul = 1.0
            MovementController.adrenaline = false
        end)
    end

    if Hub.RushBanner then
        pcall(function() Hub.RushBanner:Destroy() end)
    end

    if Hub.UI then
        pcall(function() Hub.UI:Destroy() end)
    end

    _G.KhrushchyovkaHub = nil
    print("[+] Khrushchyovka Hub completely unloaded.")
end

-- Launch
buildUI()
print("[+] Khrushchyovka [Horror] Suite initialized! Press RightShift or Insert to toggle GUI.")
