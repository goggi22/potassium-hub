--[[
    ═══════════════════════════════════════════════════════════════════════════════
    TEXAS GRANNY — ULTIMATE SURVIVAL SUITE & HUB MODULE
    ═══════════════════════════════════════════════════════════════════════════════
    Game        : Texas Granny (Place ID: 99507719593544 / Match: 128897979987102)
    Platform    : Potassium Executor / RPC Suite
    Design      : Liquid Glass × Material Design 3 (MD3) + Headless Hub Bridge
    
    Features:
      • Movement: 3D Flight ([F]), Variable Speed, Noclip, Speed Multiplier, Anti-Slow
      • ESP & Visuals: Killer ESP & Alert Banner, Teammates (with Chair/Trap status),
        Spawned Keys, Objectives (Fusebox, Shovel, Radio, Dirt), Toolboxes, Doors & Exits
      • Lighting & Filter: Fullbright daylight override, Remove Screen Fade, Remove Fog/Blur
      • Automation: Instant Self-Untie, Auto-Disarm Wire Trap, Instant Proximity Prompts
      • Hub Bridge: Native :Mount(tab) method + standalone translucent acrylic GUI
    ═══════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEANUP EXISTING RUNTIME INSTANCE
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._TexasGrannyInstance then
    pcall(function()
        getgenv()._TexasGrannyInstance:Unload()
    end)
    getgenv()._TexasGrannyInstance = nil
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────────────────────
-- CAPABILITY-SAFE TWEEN & GUI PARENTING
-- ─────────────────────────────────────────────────────────────────────────────
local function safeTween(instance, tweenInfo, goals)
    if not instance then return nil end
    local success, tween = pcall(function()
        return TweenService:Create(instance, tweenInfo, goals)
    end)
    if success and tween then
        pcall(function() tween:Play() end)
        return tween
    end
    return nil
end

local function SafeParent(gui, preferTopmost)
    local target
    if preferTopmost then
        if typeof(gethui) == "function" then
            pcall(function() target = gethui() end)
        end
        if not target then
            pcall(function() target = game:GetService("CoreGui") end)
        end
    end
    if not target then
        target = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    end
    if target then
        gui.Parent = target
    else
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
end

local function GetCharacterRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char.PrimaryPart
end

-- ─────────────────────────────────────────────────────────────────────────────
-- THEME TOKENS: BLOOD RUST & LIQUID GLASS
-- ─────────────────────────────────────────────────────────────────────────────
local Theme = {
    Surface = Color3.fromRGB(18, 14, 16),
    SurfaceTrans = 0.22,
    SurfaceContainer = Color3.fromRGB(28, 20, 24),
    SurfaceContainerTrans = 0.32,
    SurfaceHigh = Color3.fromRGB(42, 30, 36),
    SurfaceHighTrans = 0.40,
    
    Primary = Color3.fromRGB(245, 75, 75),       -- Blood Crimson
    PrimaryContainer = Color3.fromRGB(115, 25, 35),
    OnPrimary = Color3.fromRGB(255, 255, 255),
    
    RimLight = Color3.fromRGB(255, 255, 255),
    RimLightTrans = 0.82,
    BorderSubtle = Color3.fromRGB(255, 120, 120),
    BorderSubtleTrans = 0.88,
    
    OnSurface = Color3.fromRGB(245, 240, 242),
    OnSurfaceVariant = Color3.fromRGB(175, 160, 165),
    Outline = Color3.fromRGB(95, 75, 82),
    
    Killer = Color3.fromRGB(255, 45, 55),        -- Bold Red
    Survivor = Color3.fromRGB(65, 225, 155),     -- Mint Green
    Tied = Color3.fromRGB(255, 160, 30),         -- Warning Orange
    Key = Color3.fromRGB(255, 215, 60),          -- Golden Yellow
    Objective = Color3.fromRGB(80, 200, 255),    -- Cyan Blue
    Toolbox = Color3.fromRGB(200, 130, 255),     -- Amethyst Purple
    Door = Color3.fromRGB(255, 185, 95),         -- Warm Amber
    Trap = Color3.fromRGB(255, 90, 40)           -- Rust Orange
}

-- ─────────────────────────────────────────────────────────────────────────────
-- TEXAS GRANNY CORE OBJECT
-- ─────────────────────────────────────────────────────────────────────────────
local TexasGranny = {
    Version = "1.0.0",
    Active = true,
    Connections = {},
    ESPObjects = {},
    
    -- Config State
    Config = {
        -- Movement
        Fly = false,
        FlySpeed = 45,
        Noclip = false,
        SpeedBoost = false,
        WalkSpeed = 26,
        JumpPowerBoost = false,
        JumpPower = 65,
        AntiSlow = true,
        
        -- ESP
        KillerESP = true,
        KillerTrackerHUD = true,
        SurvivorESP = true,
        KeyESP = true,
        ObjectiveESP = true,
        ToolboxESP = true,
        DoorESP = true,
        TrapESP = true,
        
        -- Lighting
        Fullbright = true,
        NoScreenFade = true,
        NoFog = true,
        
        -- Automation
        AutoUntieChair = true,
        AutoDisarmTrap = true,
        InstantPrompts = true,
    },
    
    OriginalLighting = nil,
    ClosestKillerDist = 9999,
    ClosestKillerName = "None"
}

-- ─────────────────────────────────────────────────────────────────────────────
-- REVERSED REMOTES & MAP BINDINGS
-- ─────────────────────────────────────────────────────────────────────────────
local Remotes = {
    RemoveWireTrapRequest = ReplicatedStorage:FindFirstChild("RemoveWireTrapRequest"),
    ChairRescueRemote = ReplicatedStorage:FindFirstChild("ChairRescueRemote"),
    WorldPickupDropRequest = ReplicatedStorage:FindFirstChild("WorldPickupDropRequest"),
    CrawlspaceInteract = ReplicatedStorage:FindFirstChild("CrawlspaceInteract"),
    ToolboxGather = ReplicatedStorage:FindFirstChild("ToolboxGather")
}

local function GetActiveMap()
    return workspace:FindFirstChild("ActiveMap")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UTILITY: KILLER & SURVIVOR DISCOVERY
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:IsKiller(model)
    if not model or not model:IsA("Model") then return false end
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if model:GetAttribute("IsKillerNPC") == true then return true end
    local name = model.Name:lower()
    if name:find("killer") or name:find("johnny") or name:find("leatherface") or name:find("nancy") or name:find("forbidden") then
        return true
    end
    return false
end

function TexasGranny:GetKillers()
    local killers = {}
    local am = GetActiveMap()
    local searchRoots = am and { am, workspace } or { workspace }
    for _, root in ipairs(searchRoots) do
        for _, child in ipairs(root:GetChildren()) do
            if self:IsKiller(child) and not table.find(killers, child) then
                table.insert(killers, child)
            end
        end
    end
    return killers
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MOVEMENT SUBSYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:SetFly(enabled)
    if self.Config.Fly == enabled then return end
    self.Config.Fly = enabled
    if self.FlyToggleRef then
        self.FlyToggleRef.Set(enabled, true)
    end
    
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not enabled and root then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if hum then
        hum.PlatformStand = false
    end
end

function TexasGranny:UpdateFlight()
    if not self.Config.Fly then return end
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
    hum.PlatformStand = true
    local moveDir = Vector3.zero
    local camCF = Camera.CFrame
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        moveDir = moveDir - Vector3.yAxis
    end
    
    if moveDir.Magnitude > 0 then
        root.AssemblyLinearVelocity = moveDir.Unit * self.Config.FlySpeed
    else
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

function TexasGranny:UpdateNoclip()
    if not self.Config.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

function TexasGranny:UpdateCharacterModifiers()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if self.Config.SpeedBoost then
        hum.WalkSpeed = self.Config.WalkSpeed
    end
    if self.Config.JumpPowerBoost then
        hum.UseJumpPower = true
        hum.JumpPower = self.Config.JumpPower
    end
    if self.Config.AntiSlow then
        if char:GetAttribute("Mod_Speed") and char:GetAttribute("Mod_Speed") < 1 then
            pcall(function() char:SetAttribute("Mod_Speed", 1) end)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- LIGHTING & VISUAL FILTERS
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:ApplyLightingOverrides()
    if not self.OriginalLighting then
        self.OriginalLighting = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows
        }
    end
    
    if self.Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(240, 240, 240)
        Lighting.OutdoorAmbient = Color3.fromRGB(240, 240, 240)
        Lighting.Brightness = 2.4
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000000
        Lighting.GlobalShadows = false
    end
    
    if self.Config.NoFog then
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("Atmosphere") then
                if effect:GetAttribute("OrigDensity") == nil then
                    effect:SetAttribute("OrigDensity", effect.Density)
                end
                effect.Density = 0
            elseif effect:IsA("PostProcessEffect") then
                if effect:GetAttribute("OrigEnabled") == nil then
                    effect:SetAttribute("OrigEnabled", effect.Enabled)
                end
                effect.Enabled = false
            end
        end
    end
    
    if self.Config.NoScreenFade then
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local sf = pg:FindFirstChild("ScreenFadeGui")
            if sf and sf:IsA("ScreenGui") and sf.Enabled then
                sf.Enabled = false
            end
            local tr = pg:FindFirstChild("TerrorRadiusGui")
            if tr and tr:IsA("ScreenGui") and tr.Enabled then
                tr.Enabled = false
            end
        end
    end
end

function TexasGranny:RestoreLighting()
    if self.OriginalLighting then
        Lighting.Ambient = self.OriginalLighting.Ambient
        Lighting.OutdoorAmbient = self.OriginalLighting.OutdoorAmbient
        Lighting.Brightness = self.OriginalLighting.Brightness
        Lighting.ClockTime = self.OriginalLighting.ClockTime
        Lighting.FogEnd = self.OriginalLighting.FogEnd
        Lighting.GlobalShadows = self.OriginalLighting.GlobalShadows
    end
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("Atmosphere") then
            local orig = effect:GetAttribute("OrigDensity")
            if orig ~= nil then effect.Density = orig end
        elseif effect:IsA("PostProcessEffect") then
            local orig = effect:GetAttribute("OrigEnabled")
            if orig ~= nil then effect.Enabled = orig end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTOMATION & SURVIVAL ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:ProcessAutomation()
    local char = LocalPlayer.Character
    if not char then return end
    
    -- 1. Auto-disarm Wire Traps
    if self.Config.AutoDisarmTrap then
        if char:GetAttribute("HasWireTrapDebuff") == true then
            if Remotes.RemoveWireTrapRequest then
                Remotes.RemoveWireTrapRequest:FireServer()
            end
        end
    end
    
    -- 2. Auto-untie / Chair Escape
    if self.Config.AutoUntieChair then
        if Remotes.ChairRescueRemote then
            local am = GetActiveMap()
            local chairs = am and am:FindFirstChild("Chairs")
            if chairs then
                local myRoot = GetCharacterRoot(char)
                if myRoot then
                    for _, chair in ipairs(chairs:GetChildren()) do
                        local cp = chair:GetPivot()
                        local dist = (cp.Position - myRoot.Position).Magnitude
                        if dist <= 14 then
                            Remotes.ChairRescueRemote:FireServer("Done")
                            for _, prompt in ipairs(chair:GetDescendants()) do
                                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                                    pcall(function() fireproximityprompt(prompt, 0, true) end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ESP MANAGEMENT SUBSYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:ClearESP(category)
    if category then
        if self.ESPObjects[category] then
            for inst, tag in pairs(self.ESPObjects[category]) do
                pcall(function() tag:Destroy() end)
            end
            self.ESPObjects[category] = {}
        end
    else
        for cat, list in pairs(self.ESPObjects) do
            for inst, tag in pairs(list) do
                pcall(function() tag:Destroy() end)
            end
        end
        self.ESPObjects = {}
    end
end

function TexasGranny:CreateESPBillboard(targetPart, text, color, offset)
    local bb = Instance.new("BillboardGui")
    bb.Name = "TG_ESP_" .. math.random(1000, 9999)
    bb.Adornee = targetPart
    bb.Size = UDim2.new(0, 160, 0, 32)
    bb.StudsOffset = offset or Vector3.new(0, 2.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 500
    bb.ResetOnSpawn = false
    
    local container = Instance.new("Frame")
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundColor3 = Color3.fromRGB(15, 12, 14)
    container.BackgroundTransparency = 0.35
    container.BorderSizePixel = 0
    container.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = container
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = 0.3
    stroke.Thickness = 1.2
    stroke.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = color
    label.Text = text
    label.Parent = container
    
    SafeParent(bb)
    return bb
end

function TexasGranny:CreateHighlight(targetModel, outlineColor, fillColor)
    local hl = Instance.new("Highlight")
    hl.Name = "TG_HL_" .. math.random(1000, 9999)
    hl.Adornee = targetModel
    hl.OutlineColor = outlineColor or Theme.Primary
    hl.FillColor = fillColor or outlineColor or Theme.Primary
    hl.OutlineTransparency = 0.1
    hl.FillTransparency = 0.75
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    SafeParent(hl)
    return hl
end

function TexasGranny:UpdateESP()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    local myPos = myRoot and myRoot.Position or (Camera and Camera.CFrame.Position) or Vector3.zero
    local am = GetActiveMap()
    
    -- 1. KILLER ESP & PROXIMITY TRACKER
    if not self.ESPObjects.Killer then self.ESPObjects.Killer = {} end
    local killers = self:GetKillers()
    local activeKillers = {}
    local minKillerDist = 9999
    local minKillerName = "None"
    
    for _, killer in ipairs(killers) do
        activeKillers[killer] = true
        local kRoot = GetCharacterRoot(killer)
        if kRoot then
            local dist = math.floor((kRoot.Position - myPos).Magnitude)
            if dist < minKillerDist then
                minKillerDist = dist
                minKillerName = killer.Name:gsub(" Forbidden", "")
            end
            
            if self.Config.KillerESP then
                local hum = killer:FindFirstChildOfClass("Humanoid")
                local hp = hum and math.floor(hum.Health) or 100
                local espTag = self.ESPObjects.Killer[killer]
                if not espTag or not espTag.Billboard or not espTag.Billboard.Parent then
                    local bb = self:CreateESPBillboard(kRoot, "", Theme.Killer, Vector3.new(0, 3.2, 0))
                    local hl = self:CreateHighlight(killer, Theme.Killer, Theme.Killer)
                    espTag = { Billboard = bb, Highlight = hl }
                    self.ESPObjects.Killer[killer] = espTag
                end
                local label = espTag.Billboard:FindFirstChild("Frame") and espTag.Billboard.Frame:FindFirstChild("Text")
                if label then
                    label.Text = string.format("[KILLER] %s\n%dm • HP: %d", minKillerName, dist, hp)
                end
            end
        end
    end
    
    self.ClosestKillerDist = minKillerDist
    self.ClosestKillerName = minKillerName
    
    -- Cleanup dead/removed killers
    for killer, tag in pairs(self.ESPObjects.Killer) do
        if not activeKillers[killer] or not self.Config.KillerESP then
            pcall(function() tag.Billboard:Destroy() end)
            pcall(function() tag.Highlight:Destroy() end)
            self.ESPObjects.Killer[killer] = nil
        end
    end
    
    -- Update Radar HUD Banner
    if self.KillerRadarLabel then
        if self.Config.KillerTrackerHUD and minKillerDist < 9000 then
            self.KillerRadarBanner.Visible = true
            local isPanic = minKillerDist <= 55
            self.KillerRadarLabel.Text = string.format("KILLER: %s  |  DIST: %dm  |  %s", 
                minKillerName:upper(), minKillerDist, isPanic and "⚠ DANGER: NEARBY" or "TRACKING")
            self.KillerRadarLabel.TextColor3 = isPanic and Theme.Killer or Theme.OnSurface
            self.KillerRadarStroke.Color = isPanic and Theme.Killer or Theme.Outline
        else
            self.KillerRadarBanner.Visible = false
        end
    end
    
    -- 2. SURVIVOR ESP
    if not self.ESPObjects.Survivor then self.ESPObjects.Survivor = {} end
    local activeSurvivors = {}
    if self.Config.SurvivorESP then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                local sRoot = GetCharacterRoot(char)
                if sRoot then
                    activeSurvivors[char] = true
                    local dist = math.floor((sRoot.Position - myPos).Magnitude)
                    local isTied = false
                    local isTrapped = char:GetAttribute("HasWireTrapDebuff") == true
                    
                    local tag = self.ESPObjects.Survivor[char]
                    if not tag or not tag.Billboard or not tag.Billboard.Parent then
                        local bb = self:CreateESPBillboard(sRoot, "", Theme.Survivor, Vector3.new(0, 2.5, 0))
                        local hl = self:CreateHighlight(char, Theme.Survivor, Theme.Survivor)
                        tag = { Billboard = bb, Highlight = hl }
                        self.ESPObjects.Survivor[char] = tag
                    end
                    
                    local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                    if label then
                        local stateStr = isTrapped and " [TRAPPED]" or (isTied and " [TIED]" or "")
                        label.Text = string.format("%s%s\n%dm", player.DisplayName, stateStr, dist)
                        label.TextColor3 = (isTrapped or isTied) and Theme.Tied or Theme.Survivor
                    end
                end
            end
        end
    end
    for char, tag in pairs(self.ESPObjects.Survivor) do
        if not activeSurvivors[char] or not self.Config.SurvivorESP then
            pcall(function() tag.Billboard:Destroy() end)
            pcall(function() tag.Highlight:Destroy() end)
            self.ESPObjects.Survivor[char] = nil
        end
    end
    
    if not am then return end
    
    -- 3. SPAWNED KEYS ESP
    if not self.ESPObjects.Keys then self.ESPObjects.Keys = {} end
    local activeKeys = {}
    local keysFolder = am:FindFirstChild("SpawnedKeys")
    if keysFolder and self.Config.KeyESP then
        for _, key in ipairs(keysFolder:GetChildren()) do
            local kPart = key:IsA("BasePart") and key or (key:IsA("Model") and (key.PrimaryPart or key:FindFirstChildWhichIsA("BasePart")))
            if kPart then
                activeKeys[key] = true
                local dist = math.floor((kPart.Position - myPos).Magnitude)
                local tag = self.ESPObjects.Keys[key]
                if not tag or not tag.Billboard or not tag.Billboard.Parent then
                    local bb = self:CreateESPBillboard(kPart, "", Theme.Key, Vector3.new(0, 1.2, 0))
                    tag = { Billboard = bb }
                    self.ESPObjects.Keys[key] = tag
                end
                local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                if label then
                    label.Text = string.format("🔑 %s\n%dm", key.Name, dist)
                end
            end
        end
    end
    for key, tag in pairs(self.ESPObjects.Keys) do
        if not activeKeys[key] or not self.Config.KeyESP then
            pcall(function() tag.Billboard:Destroy() end)
            self.ESPObjects.Keys[key] = nil
        end
    end
    
    -- 4. OBJECTIVES ESP (Fusebox, Shovel, Radio, DirtPile)
    if not self.ESPObjects.Objectives then self.ESPObjects.Objectives = {} end
    local activeObjs = {}
    local setPieces = am:FindFirstChild("SpawnedSetPieces")
    local objProps = am:FindFirstChild("SpawnedObjectiveProps")
    local objCrates = am:FindFirstChild("SpawnedObjectiveCrates")
    
    local objFolders = { setPieces, objProps, objCrates }
    if self.Config.ObjectiveESP then
        for _, folder in ipairs(objFolders) do
            if folder then
                for _, obj in ipairs(folder:GetChildren()) do
                    local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
                    if part then
                        activeObjs[obj] = true
                        local dist = math.floor((part.Position - myPos).Magnitude)
                        local tag = self.ESPObjects.Objectives[obj]
                        if not tag or not tag.Billboard or not tag.Billboard.Parent then
                            local bb = self:CreateESPBillboard(part, "", Theme.Objective, Vector3.new(0, 1.5, 0))
                            tag = { Billboard = bb }
                            self.ESPObjects.Objectives[obj] = tag
                        end
                        local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                        if label then
                            label.Text = string.format("⚡ %s\n%dm", obj.Name, dist)
                        end
                    end
                end
            end
        end
    end
    for obj, tag in pairs(self.ESPObjects.Objectives) do
        if not activeObjs[obj] or not self.Config.ObjectiveESP then
            pcall(function() tag.Billboard:Destroy() end)
            self.ESPObjects.Objectives[obj] = nil
        end
    end
    
    -- 5. TOOLBOXES ESP
    if not self.ESPObjects.Toolboxes then self.ESPObjects.Toolboxes = {} end
    local activeToolboxes = {}
    local toolboxesFolder = am:FindFirstChild("SpawnedToolboxes")
    if toolboxesFolder and self.Config.ToolboxESP then
        for _, box in ipairs(toolboxesFolder:GetChildren()) do
            local part = box:IsA("BasePart") and box or (box:IsA("Model") and (box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart")))
            if part then
                activeToolboxes[box] = true
                local dist = math.floor((part.Position - myPos).Magnitude)
                local tag = self.ESPObjects.Toolboxes[box]
                if not tag or not tag.Billboard or not tag.Billboard.Parent then
                    local bb = self:CreateESPBillboard(part, "", Theme.Toolbox, Vector3.new(0, 1.2, 0))
                    tag = { Billboard = bb }
                    self.ESPObjects.Toolboxes[box] = tag
                end
                local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                if label then
                    label.Text = string.format("🧰 Toolbox\n%dm", dist)
                end
            end
        end
    end
    for box, tag in pairs(self.ESPObjects.Toolboxes) do
        if not activeToolboxes[box] or not self.Config.ToolboxESP then
            pcall(function() tag.Billboard:Destroy() end)
            self.ESPObjects.Toolboxes[box] = nil
        end
    end
    
    -- 6. DOORS & CHAIRS ESP
    if not self.ESPObjects.Doors then self.ESPObjects.Doors = {} end
    local activeDoors = {}
    local doorsFolder = am:FindFirstChild("Doors")
    local chairsFolder = am:FindFirstChild("Chairs")
    
    if self.Config.DoorESP and doorsFolder then
        for _, door in ipairs(doorsFolder:GetChildren()) do
            local part = door:IsA("BasePart") and door or (door:IsA("Model") and (door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart")))
            if part then
                activeDoors[door] = true
                local dist = math.floor((part.Position - myPos).Magnitude)
                local tag = self.ESPObjects.Doors[door]
                if not tag or not tag.Billboard or not tag.Billboard.Parent then
                    local bb = self:CreateESPBillboard(part, "", Theme.Door, Vector3.new(0, 1.5, 0))
                    tag = { Billboard = bb }
                    self.ESPObjects.Doors[door] = tag
                end
                local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                if label then
                    label.Text = string.format("🚪 %s\n%dm", door.Name:gsub("Door_NH", ""), dist)
                end
            end
        end
    end
    if self.Config.DoorESP and chairsFolder then
        for _, chair in ipairs(chairsFolder:GetChildren()) do
            local part = chair:IsA("BasePart") and chair or (chair:IsA("Model") and (chair.PrimaryPart or chair:FindFirstChildWhichIsA("BasePart")))
            if part then
                activeDoors[chair] = true
                local dist = math.floor((part.Position - myPos).Magnitude)
                local tag = self.ESPObjects.Doors[chair]
                if not tag or not tag.Billboard or not tag.Billboard.Parent then
                    local bb = self:CreateESPBillboard(part, "", Theme.Tied, Vector3.new(0, 1.2, 0))
                    tag = { Billboard = bb }
                    self.ESPObjects.Doors[chair] = tag
                end
                local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                if label then
                    label.Text = string.format("🪑 Chair\n%dm", dist)
                end
            end
        end
    end
    for d, tag in pairs(self.ESPObjects.Doors) do
        if not activeDoors[d] or not self.Config.DoorESP then
            pcall(function() tag.Billboard:Destroy() end)
            self.ESPObjects.Doors[d] = nil
        end
    end
    
    -- 7. CRAWLSPACES & WIRE TRAPS ESP
    if not self.ESPObjects.Traps then self.ESPObjects.Traps = {} end
    local activeTraps = {}
    local crawlFolder = am:FindFirstChild("Crawlspaces")
    if self.Config.TrapESP and crawlFolder then
        for _, crawl in ipairs(crawlFolder:GetChildren()) do
            local part = crawl:IsA("BasePart") and crawl or (crawl:IsA("Model") and (crawl.PrimaryPart or crawl:FindFirstChildWhichIsA("BasePart")))
            if part then
                activeTraps[crawl] = true
                local dist = math.floor((part.Position - myPos).Magnitude)
                local tag = self.ESPObjects.Traps[crawl]
                if not tag or not tag.Billboard or not tag.Billboard.Parent then
                    local bb = self:CreateESPBillboard(part, "", Theme.Trap, Vector3.new(0, 1.5, 0))
                    tag = { Billboard = bb }
                    self.ESPObjects.Traps[crawl] = tag
                end
                local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                if label then
                    label.Text = string.format("🕳 Crawlspace\n%dm", dist)
                end
            end
        end
    end
    for t, tag in pairs(self.ESPObjects.Traps) do
        if not activeTraps[t] or not self.Config.TrapESP then
            pcall(function() tag.Billboard:Destroy() end)
            self.ESPObjects.Traps[t] = nil
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TOP KILLER RADAR BANNER HUD
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:CreateRadarBanner()
    local sg = Instance.new("ScreenGui")
    sg.Name = "TG_RadarBanner"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 2147483646
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local banner = Instance.new("Frame")
    banner.Name = "Banner"
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0, 14)
    banner.Size = UDim2.new(0, 360, 0, 30)
    banner.BackgroundColor3 = Color3.fromRGB(20, 14, 18)
    banner.BackgroundTransparency = 0.25
    banner.BorderSizePixel = 0
    banner.Visible = false
    banner.Parent = sg
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = banner
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Outline
    stroke.Transparency = 0.4
    stroke.Thickness = 1.2
    stroke.Parent = banner
    
    local label = Instance.new("TextLabel")
    label.Name = "RadarLabel"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Theme.OnSurface
    label.Text = "KILLER RADAR: TRACKING..."
    label.Parent = banner
    
    SafeParent(sg, true)
    self.RadarScreenGui = sg
    self.KillerRadarBanner = banner
    self.KillerRadarLabel = label
    self.KillerRadarStroke = stroke
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HUB INTEGRATION BRIDGE: TexasGranny:Mount(tab)
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:Mount(tab)
    if not tab then return end
    
    -- Movement Section
    if tab.AddSection then tab:AddSection("Movement & Navigation") end
    
    if tab.AddToggle then
        self.FlyToggleRef = tab:AddToggle({
            Name = "3D Flight ([F])",
            Default = self.Config.Fly,
            Callback = function(v) self:SetFly(v) end
        })
    end
    
    if tab.AddSlider then
        tab:AddSlider({
            Name = "Flight Speed",
            Min = 15, Max = 150, Default = self.Config.FlySpeed,
            Callback = function(v) self.Config.FlySpeed = v end
        })
    end
    
    if tab.AddToggle then
        tab:AddToggle({
            Name = "Noclip (Wall Bypass)",
            Default = self.Config.Noclip,
            Callback = function(v) self.Config.Noclip = v end
        })
        tab:AddToggle({
            Name = "Speed Multiplier Boost",
            Default = self.Config.SpeedBoost,
            Callback = function(v) self.Config.SpeedBoost = v end
        })
    end
    
    if tab.AddSlider then
        tab:AddSlider({
            Name = "WalkSpeed Override",
            Min = 16, Max = 55, Default = self.Config.WalkSpeed,
            Callback = function(v) self.Config.WalkSpeed = v end
        })
    end
    
    if tab.AddToggle then
        tab:AddToggle({
            Name = "Anti-Slow / Debuff Lock",
            Default = self.Config.AntiSlow,
            Callback = function(v) self.Config.AntiSlow = v end
        })
    end
    
    -- Visuals / ESP Section
    if tab.AddSection then tab:AddSection("Visuals & ESP") end
    
    if tab.AddToggle then
        tab:AddToggle({
            Name = "Killer ESP (Red Highlight & Dist)",
            Default = self.Config.KillerESP,
            Callback = function(v)
                self.Config.KillerESP = v
                if not v then self:ClearESP("Killer") end
            end
        })
        tab:AddToggle({
            Name = "Killer Radar HUD Banner",
            Default = self.Config.KillerTrackerHUD,
            Callback = function(v) self.Config.KillerTrackerHUD = v end
        })
        tab:AddToggle({
            Name = "Survivor ESP (With Chair/Trap Tags)",
            Default = self.Config.SurvivorESP,
            Callback = function(v)
                self.Config.SurvivorESP = v
                if not v then self:ClearESP("Survivor") end
            end
        })
        tab:AddToggle({
            Name = "Keys ESP (Bone Keys)",
            Default = self.Config.KeyESP,
            Callback = function(v)
                self.Config.KeyESP = v
                if not v then self:ClearESP("Keys") end
            end
        })
        tab:AddToggle({
            Name = "Objectives ESP (Fusebox, Shovel, Radio)",
            Default = self.Config.ObjectiveESP,
            Callback = function(v)
                self.Config.ObjectiveESP = v
                if not v then self:ClearESP("Objectives") end
            end
        })
        tab:AddToggle({
            Name = "Toolboxes ESP",
            Default = self.Config.ToolboxESP,
            Callback = function(v)
                self.Config.ToolboxESP = v
                if not v then self:ClearESP("Toolboxes") end
            end
        })
        tab:AddToggle({
            Name = "Doors & Chairs ESP",
            Default = self.Config.DoorESP,
            Callback = function(v)
                self.Config.DoorESP = v
                if not v then self:ClearESP("Doors") end
            end
        })
        tab:AddToggle({
            Name = "Traps & Crawlspaces ESP",
            Default = self.Config.TrapESP,
            Callback = function(v)
                self.Config.TrapESP = v
                if not v then self:ClearESP("Traps") end
            end
        })
    end
    
    -- Lighting Section
    if tab.AddSection then tab:AddSection("Horror Lighting & Filter") end
    
    if tab.AddToggle then
        tab:AddToggle({
            Name = "Fullbright (Daylight Override)",
            Default = self.Config.Fullbright,
            Callback = function(v)
                self.Config.Fullbright = v
                if not v then self:RestoreLighting() end
            end
        })
        tab:AddToggle({
            Name = "Remove Screen Fade / Darkness",
            Default = self.Config.NoScreenFade,
            Callback = function(v) self.Config.NoScreenFade = v end
        })
        tab:AddToggle({
            Name = "Remove Fog / Atmosphere / Blur",
            Default = self.Config.NoFog,
            Callback = function(v)
                self.Config.NoFog = v
                if not v then self:RestoreLighting() end
            end
        })
    end
    
    -- Automation Section
    if tab.AddSection then tab:AddSection("Automation & Fast Action") end
    
    if tab.AddToggle then
        tab:AddToggle({
            Name = "Auto-Untie / Escape Chair",
            Default = self.Config.AutoUntieChair,
            Callback = function(v) self.Config.AutoUntieChair = v end
        })
        tab:AddToggle({
            Name = "Auto-Disarm Wire Trap",
            Default = self.Config.AutoDisarmTrap,
            Callback = function(v) self.Config.AutoDisarmTrap = v end
        })
        tab:AddToggle({
            Name = "Instant Proximity Prompts (0s Hold)",
            Default = self.Config.InstantPrompts,
            Callback = function(v) self.Config.InstantPrompts = v end
        })
    end
    
    if tab.AddButton then
        tab:AddButton({
            Name = "Trigger Instant Chair Escape Now",
            Callback = function()
                if Remotes.ChairRescueRemote then
                    Remotes.ChairRescueRemote:FireServer("Done")
                end
            end
        })
        tab:AddButton({
            Name = "Disarm All Wire Traps Now",
            Callback = function()
                if Remotes.RemoveWireTrapRequest then
                    Remotes.RemoveWireTrapRequest:FireServer()
                end
            end
        })
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- STANDALONE LIQUID GLASS UI BUILDER
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:SetMenuVisible(visible)
    if not self.MainFrame then return end
    self.MainFrame.Visible = visible
    if visible then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end

function TexasGranny:BuildStandaloneUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "TG_StandaloneSuite"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 2147483647
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(0, 560, 0, 390)
    main.BackgroundColor3 = Theme.Surface
    main.BackgroundTransparency = Theme.SurfaceTrans
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = sg
    
    -- Modal cursor unlocker: forces Roblox engine to free mouse cursor when GUI is visible
    local cursorModal = Instance.new("TextButton")
    cursorModal.Name = "CursorModalRelease"
    cursorModal.Size = UDim2.new(0, 0, 0, 0)
    cursorModal.BackgroundTransparency = 1
    cursorModal.Text = ""
    cursorModal.Modal = true
    cursorModal.Parent = main
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = main
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.BorderSubtle
    stroke.Transparency = Theme.BorderSubtleTrans
    stroke.Thickness = 1.2
    stroke.Parent = main
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 48)
    titleBar.BackgroundColor3 = Theme.SurfaceContainer
    titleBar.BackgroundTransparency = Theme.SurfaceContainerTrans
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 14)
    titleCorner.Parent = titleBar
    
    local titleFix = Instance.new("Frame")
    titleFix.Position = UDim2.new(0, 0, 0.6, 0)
    titleFix.Size = UDim2.new(1, 0, 0.4, 0)
    titleFix.BackgroundColor3 = Theme.SurfaceContainer
    titleFix.BackgroundTransparency = Theme.SurfaceContainerTrans
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Position = UDim2.new(0, 18, 0, 0)
    titleLabel.Size = UDim2.new(0, 340, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Theme.OnSurface
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "TEXAS GRANNY  //  SURVIVAL SUITE"
    titleLabel.Parent = titleBar
    
    local badge = Instance.new("TextLabel")
    badge.Position = UDim2.new(0, 310, 0.5, -9)
    badge.Size = UDim2.new(0, 48, 0, 18)
    badge.BackgroundColor3 = Theme.PrimaryContainer
    badge.BackgroundTransparency = 0.2
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 10
    badge.TextColor3 = Theme.Primary
    badge.Text = "v" .. self.Version
    badge.Parent = titleBar
    
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 5)
    badgeCorner.Parent = badge
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.BackgroundColor3 = Theme.SurfaceHigh
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Theme.OnSurfaceVariant
    closeBtn.Text = "✕"
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        self:SetMenuVisible(false)
    end)
    
    -- Dragging Support
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
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
    
    -- Tab Bar (Left Pane)
    local tabBar = Instance.new("Frame")
    tabBar.Position = UDim2.new(0, 0, 0, 48)
    tabBar.Size = UDim2.new(0, 130, 1, -48)
    tabBar.BackgroundColor3 = Theme.SurfaceContainer
    tabBar.BackgroundTransparency = 0.55
    tabBar.BorderSizePixel = 0
    tabBar.Parent = main
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.Parent = tabBar
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 10)
    tabPadding.Parent = tabBar
    
    -- Content Pane (Right)
    local contentPane = Instance.new("Frame")
    contentPane.Position = UDim2.new(0, 130, 0, 48)
    contentPane.Size = UDim2.new(1, -130, 1, -48)
    contentPane.BackgroundTransparency = 1
    contentPane.Parent = main
    
    local tabs = {}
    local tabBtns = {}
    local tabNames = { "Movement", "Visuals", "Lighting", "Auto", "Hub Bridge" }
    
    local function selectTab(name)
        for tName, page in pairs(tabs) do
            page.Visible = (tName == name)
        end
        for tName, btn in pairs(tabBtns) do
            local isSel = (tName == name)
            btn.BackgroundColor3 = isSel and Theme.PrimaryContainer or Theme.SurfaceHigh
            btn.BackgroundTransparency = isSel and 0.2 or 0.7
            btn.TextColor3 = isSel and Theme.Primary or Theme.OnSurfaceVariant
        end
    end
    
    for _, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 114, 0, 32)
        btn.BackgroundColor3 = Theme.SurfaceHigh
        btn.BackgroundTransparency = 0.7
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextColor3 = Theme.OnSurfaceVariant
        btn.Text = name
        btn.Parent = tabBar
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            selectTab(name)
        end)
        tabBtns[name] = btn
        
        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "Page"
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Theme.Primary
        page.Visible = false
        page.Parent = contentPane
        
        local pLayout = Instance.new("UIListLayout")
        pLayout.Padding = UDim.new(0, 8)
        pLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pLayout.Parent = page
        
        local pPadding = Instance.new("UIPadding")
        pPadding.PaddingTop = UDim.new(0, 12)
        pPadding.PaddingLeft = UDim.new(0, 14)
        pPadding.PaddingRight = UDim.new(0, 14)
        pPadding.PaddingBottom = UDim.new(0, 12)
        pPadding.Parent = page
        
        tabs[name] = page
    end
    
    -- Helper UI Builders
    local function createToggle(parent, title, initialVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 36)
        frame.BackgroundColor3 = Theme.SurfaceContainer
        frame.BackgroundTransparency = 0.4
        frame.BorderSizePixel = 0
        frame.Parent = parent
        
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 6)
        fCorner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, 12, 0, 0)
        label.Size = UDim2.new(1, -60, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextColor3 = Theme.OnSurface
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = title
        label.Parent = frame
        
        local tBtn = Instance.new("TextButton")
        tBtn.Position = UDim2.new(1, -44, 0.5, -11)
        tBtn.Size = UDim2.new(0, 34, 0, 22)
        tBtn.BackgroundColor3 = initialVal and Theme.Primary or Theme.SurfaceHigh
        tBtn.BorderSizePixel = 0
        tBtn.Font = Enum.Font.GothamBold
        tBtn.TextSize = 10
        tBtn.TextColor3 = initialVal and Theme.OnPrimary or Theme.OnSurfaceVariant
        tBtn.Text = initialVal and "ON" or "OFF"
        tBtn.Parent = frame
        
        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(0, 5)
        tCorner.Parent = tBtn
        
        local current = initialVal
        local function setVal(v, silent)
            current = v
            tBtn.BackgroundColor3 = current and Theme.Primary or Theme.SurfaceHigh
            tBtn.TextColor3 = current and Theme.OnPrimary or Theme.OnSurfaceVariant
            tBtn.Text = current and "ON" or "OFF"
            if not silent and callback then
                callback(current)
            end
        end
        
        tBtn.MouseButton1Click:Connect(function()
            setVal(not current)
        end)
        
        return { Set = setVal }
    end
    
    local function createSlider(parent, title, minVal, maxVal, initialVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 48)
        frame.BackgroundColor3 = Theme.SurfaceContainer
        frame.BackgroundTransparency = 0.4
        frame.BorderSizePixel = 0
        frame.Parent = parent
        
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 6)
        fCorner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, 12, 0, 6)
        label.Size = UDim2.new(1, -70, 0, 18)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextColor3 = Theme.OnSurface
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = title
        label.Parent = frame
        
        local valLabel = Instance.new("TextLabel")
        valLabel.Position = UDim2.new(1, -50, 0, 6)
        valLabel.Size = UDim2.new(0, 40, 0, 18)
        valLabel.BackgroundTransparency = 1
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextSize = 11
        valLabel.TextColor3 = Theme.Primary
        valLabel.Text = tostring(initialVal)
        valLabel.Parent = frame
        
        local bar = Instance.new("Frame")
        bar.Position = UDim2.new(0, 12, 0, 30)
        bar.Size = UDim2.new(1, -24, 0, 6)
        bar.BackgroundColor3 = Theme.SurfaceHigh
        bar.BorderSizePixel = 0
        bar.Parent = frame
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 3)
        bCorner.Parent = bar
        
        local fill = Instance.new("Frame")
        local pct = math.clamp((initialVal - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = Theme.Primary
        fill.BorderSizePixel = 0
        fill.Parent = bar
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 3)
        fillCorner.Parent = fill
        
        local draggingSlider = false
        local function update(input)
            local posX = input.Position.X
            local barAbsPos = bar.AbsolutePosition.X
            local barAbsSize = bar.AbsoluteSize.X
            local rawPct = math.clamp((posX - barAbsPos) / barAbsSize, 0, 1)
            local val = math.floor(minVal + (maxVal - minVal) * rawPct)
            fill.Size = UDim2.new(rawPct, 0, 1, 0)
            valLabel.Text = tostring(val)
            if callback then callback(val) end
        end
        
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
    end
    
    local function createButton(parent, text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = color or Theme.PrimaryContainer
        btn.BackgroundTransparency = 0.25
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Theme.OnSurface
        btn.Text = text
        btn.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
    end
    
    -- POPULATE TABS
    
    -- 1. Movement Page
    self.FlyToggleRef = createToggle(tabs["Movement"], "3D Camera Flight ([F])", self.Config.Fly, function(v)
        self:SetFly(v)
    end)
    createSlider(tabs["Movement"], "Flight Speed", 15, 150, self.Config.FlySpeed, function(v)
        self.Config.FlySpeed = v
    end)
    self.NoclipToggleRef = createToggle(tabs["Movement"], "Noclip (Phase Through Walls) [N]", self.Config.Noclip, function(v)
        self.Config.Noclip = v
    end)
    createToggle(tabs["Movement"], "Speed Multiplier Boost", self.Config.SpeedBoost, function(v)
        self.Config.SpeedBoost = v
    end)
    createSlider(tabs["Movement"], "WalkSpeed Override", 16, 55, self.Config.WalkSpeed, function(v)
        self.Config.WalkSpeed = v
    end)
    createToggle(tabs["Movement"], "Anti-Slow / Debuff Preventer", self.Config.AntiSlow, function(v)
        self.Config.AntiSlow = v
    end)
    
    -- 2. Visuals Page
    createToggle(tabs["Visuals"], "Killer ESP (Crimson Highlight & Dist)", self.Config.KillerESP, function(v)
        self.Config.KillerESP = v
        if not v then self:ClearESP("Killer") end
    end)
    createToggle(tabs["Visuals"], "Killer Radar HUD Banner (Top Alert)", self.Config.KillerTrackerHUD, function(v)
        self.Config.KillerTrackerHUD = v
    end)
    createToggle(tabs["Visuals"], "Survivor ESP (With Chair/Trap Badges)", self.Config.SurvivorESP, function(v)
        self.Config.SurvivorESP = v
        if not v then self:ClearESP("Survivor") end
    end)
    createToggle(tabs["Visuals"], "Keys ESP (Bone Keys)", self.Config.KeyESP, function(v)
        self.Config.KeyESP = v
        if not v then self:ClearESP("Keys") end
    end)
    createToggle(tabs["Visuals"], "Objectives ESP (Fusebox, Shovel, Radio)", self.Config.ObjectiveESP, function(v)
        self.Config.ObjectiveESP = v
        if not v then self:ClearESP("Objectives") end
    end)
    createToggle(tabs["Visuals"], "Toolboxes ESP", self.Config.ToolboxESP, function(v)
        self.Config.ToolboxESP = v
        if not v then self:ClearESP("Toolboxes") end
    end)
    createToggle(tabs["Visuals"], "Doors & Chairs ESP", self.Config.DoorESP, function(v)
        self.Config.DoorESP = v
        if not v then self:ClearESP("Doors") end
    end)
    createToggle(tabs["Visuals"], "Traps & Crawlspaces ESP", self.Config.TrapESP, function(v)
        self.Config.TrapESP = v
        if not v then self:ClearESP("Traps") end
    end)
    
    -- 3. Lighting Page
    createToggle(tabs["Lighting"], "Fullbright (Daylight Override)", self.Config.Fullbright, function(v)
        self.Config.Fullbright = v
        if not v then self:RestoreLighting() end
    end)
    createToggle(tabs["Lighting"], "Remove Screen Fade / Darkness", self.Config.NoScreenFade, function(v)
        self.Config.NoScreenFade = v
    end)
    createToggle(tabs["Lighting"], "Remove Atmosphere / Fog / Blur", self.Config.NoFog, function(v)
        self.Config.NoFog = v
        if not v then self:RestoreLighting() end
    end)
    
    -- 4. Auto Page
    createToggle(tabs["Auto"], "Auto-Untie / Escape from Chair", self.Config.AutoUntieChair, function(v)
        self.Config.AutoUntieChair = v
    end)
    createToggle(tabs["Auto"], "Auto-Disarm Wire Trap", self.Config.AutoDisarmTrap, function(v)
        self.Config.AutoDisarmTrap = v
    end)
    createToggle(tabs["Auto"], "Instant Proximity Prompts (0s Hold)", self.Config.InstantPrompts, function(v)
        self.Config.InstantPrompts = v
    end)
    createButton(tabs["Auto"], "Trigger Instant Chair Escape Now", Theme.PrimaryContainer, function()
        if Remotes.ChairRescueRemote then
            Remotes.ChairRescueRemote:FireServer("Done")
        end
    end)
    createButton(tabs["Auto"], "Disarm Wire Traps Immediately", Theme.PrimaryContainer, function()
        if Remotes.RemoveWireTrapRequest then
            Remotes.RemoveWireTrapRequest:FireServer()
        end
    end)
    
    -- 5. Hub Bridge Page
    local hubNote = Instance.new("TextLabel")
    hubNote.Size = UDim2.new(1, 0, 0, 90)
    hubNote.BackgroundColor3 = Theme.SurfaceContainer
    hubNote.BackgroundTransparency = 0.4
    hubNote.Font = Enum.Font.Gotham
    hubNote.TextSize = 11
    hubNote.TextColor3 = Theme.OnSurfaceVariant
    hubNote.TextWrapped = true
    hubNote.Text = "HUB INTEGRATION BRIDGE ACTIVE:\nTo mount this suite inside your external master hub tab, call:\ngetgenv().TexasGranny:Mount(tab)\n\nPress [RightControl] to toggle this GUI, or [F] to toggle Flight."
    hubNote.Parent = tabs["Hub Bridge"]
    
    local hubNoteCorner = Instance.new("UICorner")
    hubNoteCorner.CornerRadius = UDim.new(0, 6)
    hubNoteCorner.Parent = hubNote
    
    createButton(tabs["Hub Bridge"], "Unload & Clean All Modules", Theme.PrimaryContainer, function()
        self:Unload()
    end)
    
    selectTab("Movement")
    SafeParent(sg, true)
    self.StandaloneScreenGui = sg
    self.MainFrame = main
end

-- ─────────────────────────────────────────────────────────────────────────────
-- LIFECYCLE & EVENT LOOP
-- ─────────────────────────────────────────────────────────────────────────────
function TexasGranny:Init()
    -- Create Top Radar Banner
    self:CreateRadarBanner()
    
    -- Build Standalone UI
    self:BuildStandaloneUI()
    
    -- Bind Heartbeat & Stepped Loops (Ultra-lightweight)
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not self.Active then return end
        self:UpdateFlight()
        self:UpdateCharacterModifiers()
    end)
    table.insert(self.Connections, heartbeatConn)
    
    local steppedConn = RunService.Stepped:Connect(function()
        if not self.Active then return end
        self:UpdateNoclip()
    end)
    table.insert(self.Connections, steppedConn)
    
    -- Fast Automation Loop (Every 0.1s instead of every frame)
    task.spawn(function()
        while self.Active do
            pcall(function() self:ProcessAutomation() end)
            task.wait(0.1)
        end
    end)
    
    -- Lighting Sync Loop (Every 2s instead of every frame)
    task.spawn(function()
        while self.Active do
            if self.Config.Fullbright or self.Config.NoFog or self.Config.NoScreenFade then
                pcall(function() self:ApplyLightingOverrides() end)
            end
            task.wait(2)
        end
    end)
    
    -- Instant Proximity Prompts: Event-driven (0 CPU load)
    local ProximityPromptService = game:GetService("ProximityPromptService")
    local promptShownConn = ProximityPromptService.PromptShown:Connect(function(prompt)
        if self.Config.InstantPrompts then
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            if prompt.MaxActivationDistance < 22 then
                prompt.MaxActivationDistance = 22
            end
        end
    end)
    table.insert(self.Connections, promptShownConn)
    
    -- Prime existing active prompts once without blocking
    task.spawn(function()
        local am = GetActiveMap()
        if am then
            for _, d in ipairs(am:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    d.HoldDuration = 0
                    d.RequiresLineOfSight = false
                end
            end
        end
    end)
    
    -- Cursor Release Loop: guarantees mouse freedom whenever menu is open
    local renderConn = RunService.RenderStepped:Connect(function()
        if not self.Active then return end
        if self.MainFrame and self.MainFrame.Visible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)
    table.insert(self.Connections, renderConn)
    
    local GuiService = game:GetService("GuiService")
    local menuOpenConn = GuiService.MenuOpened:Connect(function()
        if not self.Active then return end
        if self.MainFrame and self.MainFrame.Visible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)
    table.insert(self.Connections, menuOpenConn)
    
    -- ESP Timer Loop (Every 0.25s)
    task.spawn(function()
        while self.Active do
            pcall(function() self:UpdateESP() end)
            task.wait(0.25)
        end
    end)
    
    -- Keyboard Shortcuts: [F] for Flight, [N] for Noclip, [RightControl] for GUI Toggle
    local inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            self:SetFly(not self.Config.Fly)
        elseif input.KeyCode == Enum.KeyCode.N then
            self.Config.Noclip = not self.Config.Noclip
            if self.NoclipToggleRef then
                self.NoclipToggleRef.Set(self.Config.Noclip, true)
            end
        elseif input.KeyCode == Enum.KeyCode.RightControl then
            if self.MainFrame then
                self:SetMenuVisible(not self.MainFrame.Visible)
            end
        end
    end)
    table.insert(self.Connections, inputConn)
    
    -- Listen to Map Respawn
    local mapConn = workspace.ChildAdded:Connect(function(child)
        if child.Name == "ActiveMap" then
            task.wait(1)
            self:ClearESP()
        end
    end)
    table.insert(self.Connections, mapConn)
    
    print("[TexasGranny] Survival Suite initialized successfully.")
end

function TexasGranny:Unload()
    self.Active = false
    self.Config.Fly = false
    
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}
    
    self:ClearESP()
    self:RestoreLighting()
    
    if self.StandaloneScreenGui then
        pcall(function() self.StandaloneScreenGui:Destroy() end)
        self.StandaloneScreenGui = nil
    end
    if self.RadarScreenGui then
        pcall(function() self.RadarScreenGui:Destroy() end)
        self.RadarScreenGui = nil
    end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    
    print("[TexasGranny] Unloaded successfully.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- GLOBAL REGISTRATION & EXECUTION
-- ─────────────────────────────────────────────────────────────────────────────
getgenv()._TexasGrannyInstance = TexasGranny
getgenv().TexasGranny = TexasGranny

TexasGranny:Init()
return TexasGranny
