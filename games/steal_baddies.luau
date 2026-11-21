--[[
    ══════════════════════════════════════════════════════════════════════════════════
    JUMP TO STEAL BADDIES! (Place ID: 121362092826008) — ULTIMATE SUITE
    ══════════════════════════════════════════════════════════════════════════════════
    Target Experience : Jump To Steal Baddies! (Roblox ID: 121362092826008)
    Platform          : Potassium Executor / Luau Runtime
    Design Language   : Liquid Glass × Material Design 3 (MD3) + Headless Hub Hook
    
    Features:
      • Automation Pipeline:
        - Auto Collect Earnings (Plot harvest remote loop)
        - Auto Buy Speed / Jump Upgrades
        - Auto Upgrade Carry Limit
        - Auto Rebirth when requirements met
        - Auto Claim Daily / Offline / Group Rewards
        - Instant Sell All Slimes
      • Auto Steal / Baddies Harvester:
        - Scans Workspace.Map.Gameplay.Live.WorldBaddies
        - Rarity priority filtering (Slime God, Cosmic, Rainbow, Secret, Mythic, Legendary...)
        - Smooth noclip glide approach & proximity trigger
        - Auto return to Local Player Plot base
      • Movement & Obby Bypass:
        - 3D Physics Flight (WASD + Space/Shift)
        - Noclip through all collisions
        - Laser Immunity (disables CanTouch on all plot & world lasers)
        - Invisible Wall & VIP Door Piercer (dissolves barriers)
        - Custom WalkSpeed & JumpPower
        - Anti-Void Fall-Catcher (saves character at Y < -20)
      • Visuals & Intelligence:
        - Rarity-coded Highlights & Billboard ESP for World Baddies
        - Plot & Player ESP
        - Live distance calculation
      • Obby Tier Teleports:
        - Quick transport to Base, Hub, and all 9 Obby Tiers up to Infinity (Y: 7590)
    ══════════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEANUP PREVIOUS INSTANCES
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv().StealBaddiesInstance and typeof(getgenv().StealBaddiesInstance.Destroy) == "function" then
    pcall(function()
        getgenv().StealBaddiesInstance:Destroy()
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVICES & CONSTANTS
-- ─────────────────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────────────────────
-- PALETTE & MD3 THEME
-- ─────────────────────────────────────────────────────────────────────────────
local Theme = {
    SurfaceDark      = Color3.fromRGB(13, 16, 24),
    SurfaceElevated  = Color3.fromRGB(22, 27, 40),
    SurfaceCard      = Color3.fromRGB(29, 36, 54),
    SurfaceInput     = Color3.fromRGB(18, 22, 33),
    
    Primary          = Color3.fromRGB(0, 215, 255),    -- Neon Cyan
    PrimaryHover     = Color3.fromRGB(60, 230, 255),
    Secondary        = Color3.fromRGB(140, 95, 255),   -- Vibrant Purple
    AccentGold       = Color3.fromRGB(255, 205, 50),   -- Gold
    AccentGreen      = Color3.fromRGB(65, 225, 135),   -- Success
    AccentDanger     = Color3.fromRGB(255, 75, 95),    -- Danger Red
    
    TextPrimary      = Color3.fromRGB(245, 248, 255),
    TextSecondary    = Color3.fromRGB(155, 168, 195),
    TextMuted        = Color3.fromRGB(95, 108, 135),
    
    StrokeSubtle     = Color3.fromRGB(45, 58, 85),
    StrokeActive     = Color3.fromRGB(0, 215, 255),
    
    GlassAlpha       = 0.18,
    CardAlpha        = 0.28,
}

local RarityColors = {
    ["Slime God Lucky Block"]  = Color3.fromRGB(0, 255, 230),
    ["Cosmic Lucky Block"]     = Color3.fromRGB(175, 90, 255),
    ["Rainbow Lucky Block"]    = Color3.fromRGB(255, 110, 220),
    ["Champions Lucky Block"]  = Color3.fromRGB(255, 220, 60),
    ["Secret Lucky Block"]     = Color3.fromRGB(255, 45, 75),
    ["Ghost Lucky Block"]      = Color3.fromRGB(200, 240, 255),
    ["Poison Lucky Block"]     = Color3.fromRGB(100, 255, 70),
    ["Mythic Lucky Block"]     = Color3.fromRGB(220, 50, 255),
    ["Legendary Lucky Block"]  = Color3.fromRGB(255, 180, 20),
    ["Epic Lucky Block"]       = Color3.fromRGB(170, 60, 240),
    ["Rare Lucky Block"]       = Color3.fromRGB(30, 144, 255),
    ["Common Lucky Block"]     = Color3.fromRGB(140, 200, 160),
    ["Water Lucky Block"]      = Color3.fromRGB(50, 180, 255),
}

-- ─────────────────────────────────────────────────────────────────────────────
-- ENGINE CORE MODULE TABLE
-- ─────────────────────────────────────────────────────────────────────────────
local StealBaddies = {
    Version = "1.0.0",
    PlaceId = 121362092826008,
    Connections = {},
    ESPObjects = {},
    PlotESPObjects = {},
    
    Config = {
        -- Automation
        AutoCollect = false,
        CollectInterval = 1.0,
        AutoCarryUpgrade = false,
        AutoSpeedUpgrade = false,
        AutoRebirth = false,
        
        -- Auto Steal
        AutoSteal = false,
        StealSpeed = 85,
        ReturnAfterSteal = true,
        RarityWhitelist = {
            ["Slime God Lucky Block"] = true,
            ["Cosmic Lucky Block"] = true,
            ["Rainbow Lucky Block"] = true,
            ["Champions Lucky Block"] = true,
            ["Secret Lucky Block"] = true,
            ["Ghost Lucky Block"] = true,
            ["Poison Lucky Block"] = true,
            ["Mythic Lucky Block"] = true,
            ["Legendary Lucky Block"] = true,
            ["Epic Lucky Block"] = false,
            ["Rare Lucky Block"] = false,
            ["Common Lucky Block"] = false,
            ["Water Lucky Block"] = false,
        },
        
        -- Movement & Obby Bypass
        Fly = false,
        FlySpeed = 70,
        Noclip = false,
        AntiLasers = true,
        RemoveInvisibleWalls = true,
        CustomWalkSpeed = 54,
        CustomJumpPower = 100,
        ModifySpeed = false,
        ModifyJump = false,
        AntiVoid = true,
        AntiVoidY = -20,
        
        -- Visuals
        BaddiesESP = false,
        BaddiesTracers = false,
        PlotESP = false,
        MaxESPDistance = 1500,
    },
    
    State = {
        IsStealing = false,
        MyPlot = nil,
        MyPlotBasePos = Vector3.new(318.2, -0.2, 338.6),
        LastCollectTick = 0,
        LastUpgradeTick = 0,
    }
}

-- ─────────────────────────────────────────────────────────────────────────────
-- NETWORK & REMOTES RESOLUTION
-- ─────────────────────────────────────────────────────────────────────────────
local RemotesFolder = nil
pcall(function()
    RemotesFolder = ReplicatedStorage:WaitForChild("SharedModules", 5):WaitForChild("Network", 5):WaitForChild("Remotes", 5)
end)

local function GetRemote(name)
    if RemotesFolder then
        return RemotesFolder:FindFirstChild(name)
    end
    return nil
end

local function FireGameRemote(name, ...)
    local r = GetRemote(name)
    if r and r:IsA("RemoteEvent") then
        r:FireServer(...)
        return true
    elseif r and r:IsA("RemoteFunction") then
        local res = nil
        pcall(function(...)
            res = r:InvokeServer(...)
        end, ...)
        return res
    end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CHARACTER & PLOT HELPERS
-- ─────────────────────────────────────────────────────────────────────────────
local function GetCharacterRoot(char)
    char = char or LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function ResolveMyPlot()
    local plots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Plots")
    if plots then
        for _, p in ipairs(plots:GetChildren()) do
            local owner = p:FindFirstChild("owner")
            if owner and owner.Value == LocalPlayer.Name then
                StealBaddies.State.MyPlot = p
                local base = p:FindFirstChild("Base")
                if base then
                    StealBaddies.State.MyPlotBasePos = base.Position + Vector3.new(0, 3, 0)
                end
                return p
            end
        end
    end
    
    local anchor = Workspace:FindFirstChild("LocalYourPlotAnchor")
    if anchor and anchor:IsA("BasePart") then
        StealBaddies.State.MyPlotBasePos = anchor.Position + Vector3.new(0, 3, 0)
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BARRIER & LASER DISSOLVER
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:ApplyBypasses()
    if self.Config.AntiLasers then
        -- Disable CanTouch on all plot lasers and world hazards
        local map = Workspace:FindFirstChild("Map")
        if map then
            for _, inst in ipairs(map:GetDescendants()) do
                if inst:IsA("BasePart") then
                    local name = inst.Name:lower()
                    if name:find("laser") or name:find("kill") or name:find("hazard") then
                        inst.CanTouch = false
                    end
                end
            end
        end
    end
    
    if self.Config.RemoveInvisibleWalls then
        local invisibleWalls = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("InvisibleWalls")
        if invisibleWalls then
            for _, p in ipairs(invisibleWalls:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
        end
        local vipDoors = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("VIPDoors")
        if vipDoors then
            for _, p in ipairs(vipDoors:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MOVEMENT, FLIGHT & NOCLIP
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:SetFly(enabled)
    self.Config.Fly = enabled
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not enabled and root then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if hum then
        hum.PlatformStand = enabled
    end
end

function StealBaddies:UpdateFlight()
    if not self.Config.Fly then return end
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
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
    hum.PlatformStand = true
end

function StealBaddies:UpdateNoclip()
    if not self.Config.Noclip and not self.State.IsStealing then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

function StealBaddies:UpdateHumanoidStats()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if self.Config.ModifySpeed then
        hum.WalkSpeed = self.Config.CustomWalkSpeed
    end
    if self.Config.ModifyJump then
        hum.UseJumpPower = true
        hum.JumpPower = self.Config.CustomJumpPower
    end
end

function StealBaddies:CheckAntiVoid()
    if not self.Config.AntiVoid then return end
    local root = GetCharacterRoot()
    if root and root.Position.Y < self.Config.AntiVoidY then
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.new(self.State.MyPlotBasePos + Vector3.new(0, 4, 0))
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SMOOTH GLIDE TRANSPORT (DELTA-SAFE)
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:SmoothGlide(targetPos, speed, callback)
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    if not root then return end
    
    speed = speed or self.Config.StealSpeed
    local startPos = root.Position
    local dist = (targetPos - startPos).Magnitude
    local duration = math.clamp(dist / speed, 0.4, 8)
    local steps = math.clamp(math.ceil(duration / 0.03), 10, 120)
    
    task.spawn(function()
        for i = 1, steps do
            if not char or not root.Parent then break end
            local alpha = i / steps
            local currentTarget = startPos:Lerp(targetPos, alpha)
            root.CFrame = CFrame.new(currentTarget)
            root.AssemblyLinearVelocity = (targetPos - startPos).Unit * math.min(speed, 50)
            task.wait(0.03)
        end
        if root and root.Parent then
            root.CFrame = CFrame.new(targetPos)
            root.AssemblyLinearVelocity = Vector3.zero
        end
        if callback then
            callback()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTO STEAL & PROXIMITY TRIGGER
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:FindBestTargetBaddie()
    local baddiesFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Live") and Workspace.Map.Gameplay.Live:FindFirstChild("WorldBaddies")
    if not baddiesFolder then return nil end
    
    local root = GetCharacterRoot()
    local myPos = root and root.Position or self.State.MyPlotBasePos
    
    local candidates = {}
    for _, b in ipairs(baddiesFolder:GetChildren()) do
        if self.Config.RarityWhitelist[b.Name] then
            local bRoot = b:FindFirstChild("RootPart") or b.PrimaryPart
            if bRoot then
                local dist = (bRoot.Position - myPos).Magnitude
                table.insert(candidates, {
                    model = b,
                    root = bRoot,
                    name = b.Name,
                    dist = dist
                })
            end
        end
    end
    
    if #candidates == 0 then return nil end
    
    -- Priority ordering: Secret > Slime God > Cosmic > Champions > Rainbow > Mythic > Legendary > Epic > Rare > Common
    local priorityMap = {
        ["Slime God Lucky Block"] = 100,
        ["Cosmic Lucky Block"] = 95,
        ["Champions Lucky Block"] = 90,
        ["Rainbow Lucky Block"] = 85,
        ["Secret Lucky Block"] = 80,
        ["Ghost Lucky Block"] = 75,
        ["Poison Lucky Block"] = 70,
        ["Mythic Lucky Block"] = 60,
        ["Legendary Lucky Block"] = 50,
        ["Epic Lucky Block"] = 40,
        ["Rare Lucky Block"] = 30,
        ["Common Lucky Block"] = 20,
        ["Water Lucky Block"] = 25,
    }
    
    table.sort(candidates, function(a, b)
        local prioA = priorityMap[a.name] or 0
        local prioB = priorityMap[b.name] or 0
        if prioA ~= prioB then
            return prioA > prioB
        end
        return a.dist < b.dist
    end)
    
    return candidates[1]
end

function StealBaddies:TriggerGrab(targetModel)
    local prompt = targetModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if typeof(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, prompt, 0)
        end
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

function StealBaddies:ExecuteStealCycle()
    if self.State.IsStealing or not self.Config.AutoSteal then return end
    
    local target = self:FindBestTargetBaddie()
    if not target or not target.model.Parent then return end
    
    self.State.IsStealing = true
    local targetPos = target.root.Position + Vector3.new(0, 2.5, 0)
    
    self:SmoothGlide(targetPos, self.Config.StealSpeed, function()
        task.wait(0.15)
        if target.model and target.model.Parent then
            self:TriggerGrab(target.model)
        end
        task.wait(0.35)
        
        if self.Config.ReturnAfterSteal then
            local plotReturnPos = self.State.MyPlotBasePos + Vector3.new(0, 3, 0)
            self:SmoothGlide(plotReturnPos, self.Config.StealSpeed, function()
                self.State.IsStealing = false
            end)
        else
            self.State.IsStealing = false
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTOMATION TICK (EARNINGS, UPGRADES, REBIRTH)
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:UpdateAutomation()
    local now = os.clock()
    
    -- Auto Collect Earnings
    if self.Config.AutoCollect and now - self.State.LastCollectTick >= self.Config.CollectInterval then
        self.State.LastCollectTick = now
        FireGameRemote("Collect Earnings")
    end
    
    -- Auto Upgrades
    if now - self.State.LastUpgradeTick >= 2.0 then
        self.State.LastUpgradeTick = now
        
        if self.Config.AutoCarryUpgrade then
            FireGameRemote("Upgrade Carry Limit")
        end
        if self.Config.AutoSpeedUpgrade then
            FireGameRemote("Buy Speed Upgrade", 1)
        end
        if self.Config.AutoRebirth then
            FireGameRemote("Rebirth")
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- VISUALS: ESP & HIGHLIGHTS
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:CreateBaddieESP(model)
    if self.ESPObjects[model] then return end
    
    local root = model:FindFirstChild("RootPart") or model.PrimaryPart
    if not root then return end
    
    local color = RarityColors[model.Name] or Theme.Primary
    
    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "BaddieHighlight"
    hl.Adornee = model
    hl.FillColor = color
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.OutlineTransparency = 0.2
    hl.Parent = CoreGui
    
    -- BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name = "BaddieTag"
    bb.Adornee = root
    bb.Size = UDim2.new(0, 160, 0, 38)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = CoreGui
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = model.Name:gsub(" Lucky Block", "")
    title.TextColor3 = color
    title.TextSize = 13
    title.TextStrokeTransparency = 0.3
    title.Parent = bb
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Dist"
    distLabel.Position = UDim2.new(0, 0, 0, 18)
    distLabel.Size = UDim2.new(1, 0, 0, 16)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.GothamMedium
    distLabel.Text = "0m"
    distLabel.TextColor3 = Theme.TextSecondary
    distLabel.TextSize = 11
    distLabel.TextStrokeTransparency = 0.4
    distLabel.Parent = bb
    
    self.ESPObjects[model] = {
        Highlight = hl,
        Billboard = bb,
        DistLabel = distLabel,
        Root = root
    }
end

function StealBaddies:ClearBaddieESP(model)
    local entry = self.ESPObjects[model]
    if entry then
        if entry.Highlight then entry.Highlight:Destroy() end
        if entry.Billboard then entry.Billboard:Destroy() end
        self.ESPObjects[model] = nil
    end
end

function StealBaddies:UpdateESP()
    if not self.Config.BaddiesESP then
        for model, _ in pairs(self.ESPObjects) do
            self:ClearBaddieESP(model)
        end
        return
    end
    
    local baddiesFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Live") and Workspace.Map.Gameplay.Live:FindFirstChild("WorldBaddies")
    if not baddiesFolder then return end
    
    local myRoot = GetCharacterRoot()
    local myPos = myRoot and myRoot.Position or Vector3.zero
    
    local currentSet = {}
    for _, b in ipairs(baddiesFolder:GetChildren()) do
        currentSet[b] = true
        if not self.ESPObjects[b] then
            self:CreateBaddieESP(b)
        else
            local entry = self.ESPObjects[b]
            if entry.Root and entry.Root.Parent then
                local dist = math.floor((entry.Root.Position - myPos).Magnitude)
                entry.DistLabel.Text = dist .. " studs"
                entry.Billboard.Enabled = dist <= self.Config.MaxESPDistance
                entry.Highlight.Enabled = dist <= self.Config.MaxESPDistance
            else
                self:ClearBaddieESP(b)
            end
        end
    end
    
    for model, _ in pairs(self.ESPObjects) do
        if not currentSet[model] or not model.Parent then
            self:ClearBaddieESP(model)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TELEPORT PRESETS (OBBY TIERS)
-- ─────────────────────────────────────────────────────────────────────────────
local TeleportLocations = {
    { Name = "🏠 My Plot Base",      Pos = function() return StealBaddies.State.MyPlotBasePos end },
    { Name = "🌟 Spawn Location",    Pos = Vector3.new(195.4, 3.0, 288.6) },
    { Name = "⚡ Slime God (Y: 560)",  Pos = Vector3.new(198.0, 560.0, -700.0) },
    { Name = "👑 OG Tier (Y: 830)",    Pos = Vector3.new(198.0, 830.0, -850.0) },
    { Name = "🏆 Champions (Y: 1200)", Pos = Vector3.new(198.0, 1200.0, -1030.0) },
    { Name = "🇪🇸 Spain Tier (Y: 1790)", Pos = Vector3.new(198.0, 1790.0, -1220.0) },
    { Name = "🔥 Icons Tier (Y: 2530)", Pos = Vector3.new(198.0, 2530.0, -1410.0) },
    { Name = "🌸 Japan Tier (Y: 3660)", Pos = Vector3.new(198.0, 3660.0, -1600.0) },
    { Name = "🌌 Galaxy (Y: 4970)",    Pos = Vector3.new(195.4, 4970.0, -1790.0) },
    { Name = "🕳️ Void Tier (Y: 6280)",  Pos = Vector3.new(192.8, 6280.0, -1985.0) },
    { Name = "♾️ Infinity (Y: 7590)",  Pos = Vector3.new(190.1, 7590.0, -2178.0) },
}

function StealBaddies:TeleportTo(pos)
    local root = GetCharacterRoot()
    if not root then return end
    
    local target = typeof(pos) == "function" and pos() or pos
    self:SmoothGlide(target + Vector3.new(0, 3.5, 0), 120)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MATERIAL DESIGN 3 / LIQUID GLASS GUI CONSTRUCTION
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:BuildInterface()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StealBaddiesMD3"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = CoreGui
    self.ScreenGui = ScreenGui

    -- Main Floating Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 620, 0, 480)
    MainFrame.Position = UDim2.new(0.5, -310, 0.5, -240)
    MainFrame.BackgroundColor3 = Theme.SurfaceDark
    MainFrame.BackgroundTransparency = Theme.GlassAlpha
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    self.MainFrame = MainFrame

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Theme.StrokeSubtle
    MainStroke.Thickness = 1.2
    MainStroke.Transparency = 0.35
    MainStroke.Parent = MainFrame

    -- Header / Title Bar
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 52)
    Header.BackgroundColor3 = Theme.SurfaceElevated
    Header.BackgroundTransparency = 0.25
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame

    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 14)
    HeaderCorner.Parent = Header

    -- Header Glow Line
    local GlowLine = Instance.new("Frame")
    GlowLine.Name = "GlowLine"
    GlowLine.Size = UDim2.new(1, 0, 0, 2)
    GlowLine.Position = UDim2.new(0, 0, 1, -2)
    GlowLine.BackgroundColor3 = Theme.Primary
    GlowLine.BorderSizePixel = 0
    GlowLine.Parent = Header

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Position = UDim2.new(0, 18, 0, 8)
    TitleLabel.Size = UDim2.new(0, 320, 0, 22)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "JUMP TO STEAL BADDIES!"
    TitleLabel.TextColor3 = Theme.TextPrimary
    TitleLabel.TextSize = 16
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Header

    local SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Name = "Subtitle"
    SubtitleLabel.Position = UDim2.new(0, 18, 0, 28)
    SubtitleLabel.Size = UDim2.new(0, 320, 0, 16)
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.Text = "Potassium RPC Suite • Liquid Glass × MD3"
    SubtitleLabel.TextColor3 = Theme.Primary
    SubtitleLabel.TextSize = 11
    SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLabel.Parent = Header

    -- Close / Hide Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 32, 0, 32)
    CloseBtn.Position = UDim2.new(1, -42, 0, 10)
    CloseBtn.BackgroundColor3 = Theme.SurfaceCard
    CloseBtn.BackgroundTransparency = 0.3
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Theme.TextSecondary
    CloseBtn.TextSize = 14
    CloseBtn.Parent = Header

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        self.PillButton.Visible = true
    end)

    -- Sidebar / Tab Selector
    local TabBar = Instance.new("Frame")
    TabBar.Name = "TabBar"
    TabBar.Size = UDim2.new(0, 140, 1, -52)
    TabBar.Position = UDim2.new(0, 0, 0, 52)
    TabBar.BackgroundColor3 = Theme.SurfaceElevated
    TabBar.BackgroundTransparency = 0.4
    TabBar.BorderSizePixel = 0
    TabBar.Parent = MainFrame

    local TabList = Instance.new("UIListLayout")
    TabList.Padding = UDim.new(0, 6)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Parent = TabBar

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 12)
    TabPadding.Parent = TabBar

    -- Content Container
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Size = UDim2.new(1, -150, 1, -62)
    ContentContainer.Position = UDim2.new(0, 145, 0, 57)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Tab Pages Dictionary
    local Pages = {}
    local TabButtons = {}

    local TabNames = {
        { Id = "Farm",     Icon = "⚡", Name = "Авто-Фарм" },
        { Id = "Steal",    Icon = "🥷", Name = "Воровство" },
        { Id = "Movement", Icon = "🚀", Name = "Движение" },
        { Id = "Visuals",  Icon = "👁️", Name = "ВХ / ESP" },
        { Id = "Teleport", Icon = "📍", Name = "Телепорты" },
    }

    local function SwitchTab(targetId)
        for id, page in pairs(Pages) do
            page.Visible = (id == targetId)
        end
        for id, btn in pairs(TabButtons) do
            local active = (id == targetId)
            btn.BackgroundColor3 = active and Theme.Primary or Theme.SurfaceCard
            btn.TextColor3 = active and Theme.SurfaceDark or Theme.TextSecondary
            btn.Font = active and Enum.Font.GothamBold or Enum.Font.Gotham
        end
    end

    for idx, tabInfo in ipairs(TabNames) do
        -- Button
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. tabInfo.Id
        btn.Size = UDim2.new(0, 122, 0, 36)
        btn.BackgroundColor3 = Theme.SurfaceCard
        btn.BackgroundTransparency = 0.25
        btn.Font = Enum.Font.Gotham
        btn.Text = tabInfo.Icon .. "  " .. tabInfo.Name
        btn.TextColor3 = Theme.TextSecondary
        btn.TextSize = 12
        btn.LayoutOrder = idx
        btn.Parent = TabBar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            SwitchTab(tabInfo.Id)
        end)

        TabButtons[tabInfo.Id] = btn

        -- Page Frame (Scrolling)
        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. tabInfo.Id
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Theme.StrokeSubtle
        page.Visible = false
        page.Parent = ContentContainer

        local pageList = Instance.new("UIListLayout")
        pageList.Padding = UDim.new(0, 8)
        pageList.SortOrder = Enum.SortOrder.LayoutOrder
        pageList.Parent = page

        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 4)
        pagePad.PaddingBottom = UDim.new(0, 12)
        pagePad.PaddingLeft = UDim.new(0, 4)
        pagePad.PaddingRight = UDim.new(0, 8)
        pagePad.Parent = page

        Pages[tabInfo.Id] = page
    end

    -- UI Element Builders
    local function CreateCard(parent, titleText, height)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, height or 48)
        card.BackgroundColor3 = Theme.SurfaceCard
        card.BackgroundTransparency = Theme.CardAlpha
        card.BorderSizePixel = 0
        card.Parent = parent

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = Theme.StrokeSubtle
        cStroke.Thickness = 1
        cStroke.Transparency = 0.5
        cStroke.Parent = card

        if titleText then
            local label = Instance.new("TextLabel")
            label.Position = UDim2.new(0, 12, 0, 0)
            label.Size = UDim2.new(1, -70, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.Text = titleText
            label.TextColor3 = Theme.TextPrimary
            label.TextSize = 13
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = card
        end

        return card
    end

    local function CreateToggle(parent, titleText, initialVal, onToggle)
        local card = CreateCard(parent, titleText, 44)
        
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 46, 0, 24)
        toggleBtn.Position = UDim2.new(1, -56, 0.5, -12)
        toggleBtn.BackgroundColor3 = initialVal and Theme.Primary or Theme.SurfaceInput
        toggleBtn.Text = ""
        toggleBtn.Parent = card

        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(1, 0)
        tCorner.Parent = toggleBtn

        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 18, 0, 18)
        pill.Position = initialVal and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        pill.BackgroundColor3 = initialVal and Theme.SurfaceDark or Theme.TextSecondary
        pill.BorderSizePixel = 0
        pill.Parent = toggleBtn

        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(1, 0)
        pCorner.Parent = pill

        local state = initialVal
        toggleBtn.MouseButton1Click:Connect(function()
            state = not state
            toggleBtn.BackgroundColor3 = state and Theme.Primary or Theme.SurfaceInput
            pill.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            pill.BackgroundColor3 = state and Theme.SurfaceDark or Theme.TextSecondary
            onToggle(state)
        end)

        return card
    end

    local function CreateButton(parent, text, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = color or Theme.SurfaceCard
        btn.BackgroundTransparency = 0.2
        btn.Font = Enum.Font.GothamBold
        btn.Text = text
        btn.TextColor3 = (color == Theme.Primary) and Theme.SurfaceDark or Theme.TextPrimary
        btn.TextSize = 13
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.StrokeSubtle
        stroke.Thickness = 1
        stroke.Transparency = 0.4
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    local function CreateSlider(parent, titleText, minVal, maxVal, currentVal, onSlide)
        local card = CreateCard(parent, nil, 60)
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, 12, 0, 8)
        label.Size = UDim2.new(1, -80, 0, 18)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = titleText
        label.TextColor3 = Theme.TextPrimary
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = card

        local valLabel = Instance.new("TextLabel")
        valLabel.Position = UDim2.new(1, -65, 0, 8)
        valLabel.Size = UDim2.new(0, 55, 0, 18)
        valLabel.BackgroundTransparency = 1
        valLabel.Font = Enum.Font.GothamBold
        valLabel.Text = tostring(currentVal)
        valLabel.TextColor3 = Theme.Primary
        valLabel.TextSize = 12
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = card

        local barBg = Instance.new("Frame")
        barBg.Position = UDim2.new(0, 12, 0, 36)
        barBg.Size = UDim2.new(1, -24, 0, 8)
        barBg.BackgroundColor3 = Theme.SurfaceInput
        barBg.BorderSizePixel = 0
        barBg.Parent = card

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = barBg

        local fill = Instance.new("Frame")
        local pct = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = Theme.Primary
        fill.BorderSizePixel = 0
        fill.Parent = barBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill

        local dragging = false
        barBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                local conn
                conn = RunService.RenderStepped:Connect(function()
                    if not dragging then conn:Disconnect() return end
                    local mousePos = UserInputService:GetMouseLocation().X
                    local rel = math.clamp((mousePos - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                    local calculated = math.floor(minVal + (maxVal - minVal) * rel)
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    valLabel.Text = tostring(calculated)
                    onSlide(calculated)
                end)
                UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
            end
        end)

        return card
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- POPULATE TAB 1: AUTO FARM & HARVEST
    -- ─────────────────────────────────────────────────────────────────────────
    local farmPage = Pages["Farm"]
    CreateToggle(farmPage, "💰 Auto Collect Earnings (Сбор прибыли базы)", self.Config.AutoCollect, function(val)
        self.Config.AutoCollect = val
    end)
    CreateToggle(farmPage, "🎒 Auto Upgrade Carry Limit (Вместимость)", self.Config.AutoCarryUpgrade, function(val)
        self.Config.AutoCarryUpgrade = val
    end)
    CreateToggle(farmPage, "⚡ Auto Speed Upgrade (Скорость / Прыжок)", self.Config.AutoSpeedUpgrade, function(val)
        self.Config.AutoSpeedUpgrade = val
    end)
    CreateToggle(farmPage, "🔄 Auto Rebirth (Авто-Перерождение)", self.Config.AutoRebirth, function(val)
        self.Config.AutoRebirth = val
    end)
    CreateButton(farmPage, "🎁 Claim Daily & Group Rewards", Theme.Secondary, function()
        FireGameRemote("Claim Daily Reward")
        FireGameRemote("Claim Group Reward")
        FireGameRemote("Claim Offline Reward")
    end)
    CreateButton(farmPage, "💎 Instant Sell All Slimes ($$$)", Theme.AccentGold, function()
        FireGameRemote("Sell All Slimes")
    end)

    -- ─────────────────────────────────────────────────────────────────────────
    -- POPULATE TAB 2: AUTO STEAL BADDIES
    -- ─────────────────────────────────────────────────────────────────────────
    local stealPage = Pages["Steal"]
    CreateToggle(stealPage, "🥷 Auto Steal Baddies (Авто-Воровство)", self.Config.AutoSteal, function(val)
        self.Config.AutoSteal = val
    end)
    CreateToggle(stealPage, "🏠 Return to Plot After Steal (Возврат на базу)", self.Config.ReturnAfterSteal, function(val)
        self.Config.ReturnAfterSteal = val
    end)
    CreateSlider(stealPage, "Approach Glide Speed", 40, 160, self.Config.StealSpeed, function(val)
        self.Config.StealSpeed = val
    end)
    CreateButton(stealPage, "🎯 Steal Nearest Best Baddie NOW", Theme.Primary, function()
        self:ExecuteStealCycle()
    end)
    CreateButton(stealPage, "🏡 Return To My Base Position", Theme.SurfaceCard, function()
        self:SmoothGlide(self.State.MyPlotBasePos + Vector3.new(0, 3, 0), 120)
    end)

    -- Rarity Whitelist Section
    local catHeader = Instance.new("TextLabel")
    catHeader.Size = UDim2.new(1, 0, 0, 24)
    catHeader.BackgroundTransparency = 1
    catHeader.Font = Enum.Font.GothamBold
    catHeader.Text = "Фильтр Редкостей для Воровства:"
    catHeader.TextColor3 = Theme.TextPrimary
    catHeader.TextSize = 12
    catHeader.TextXAlignment = Enum.TextXAlignment.Left
    catHeader.Parent = stealPage

    for rarityName, isEnabled in pairs(self.Config.RarityWhitelist) do
        local cleanName = rarityName:gsub(" Lucky Block", "")
        CreateToggle(stealPage, "  • " .. cleanName, isEnabled, function(val)
            self.Config.RarityWhitelist[rarityName] = val
        end)
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- POPULATE TAB 3: MOVEMENT & BYPASSES
    -- ─────────────────────────────────────────────────────────────────────────
    local movePage = Pages["Movement"]
    CreateToggle(movePage, "🛸 3D Fly (Полёт WASD + Space/Shift)", self.Config.Fly, function(val)
        self:SetFly(val)
    end)
    CreateSlider(movePage, "Fly Speed", 30, 250, self.Config.FlySpeed, function(val)
        self.Config.FlySpeed = val
    end)
    CreateToggle(movePage, "👻 Noclip (Прохождение сквозь стены)", self.Config.Noclip, function(val)
        self.Config.Noclip = val
    end)
    CreateToggle(movePage, "🛡️ Anti-Lasers (Иммунитет к лазерам)", self.Config.AntiLasers, function(val)
        self.Config.AntiLasers = val
        self:ApplyBypasses()
    end)
    CreateToggle(movePage, "🚪 Pierce Invisible Walls & VIP Doors", self.Config.RemoveInvisibleWalls, function(val)
        self.Config.RemoveInvisibleWalls = val
        self:ApplyBypasses()
    end)
    CreateToggle(movePage, "🕳️ Anti-Void Fall Saver (Защита от бездны)", self.Config.AntiVoid, function(val)
        self.Config.AntiVoid = val
    end)
    CreateToggle(movePage, "⚡ Custom WalkSpeed", self.Config.ModifySpeed, function(val)
        self.Config.ModifySpeed = val
    end)
    CreateSlider(movePage, "WalkSpeed Value", 16, 200, self.Config.CustomWalkSpeed, function(val)
        self.Config.CustomWalkSpeed = val
    end)
    CreateToggle(movePage, "🦘 Custom JumpPower", self.Config.ModifyJump, function(val)
        self.Config.ModifyJump = val
    end)
    CreateSlider(movePage, "JumpPower Value", 50, 300, self.Config.CustomJumpPower, function(val)
        self.Config.CustomJumpPower = val
    end)

    -- ─────────────────────────────────────────────────────────────────────────
    -- POPULATE TAB 4: VISUALS & ESP
    -- ─────────────────────────────────────────────────────────────────────────
    local visPage = Pages["Visuals"]
    CreateToggle(visPage, "👁️ Baddies Highlight & Name ESP", self.Config.BaddiesESP, function(val)
        self.Config.BaddiesESP = val
        self:UpdateESP()
    end)
    CreateSlider(visPage, "Max ESP Distance (Studs)", 200, 3000, self.Config.MaxESPDistance, function(val)
        self.Config.MaxESPDistance = val
    end)

    -- ─────────────────────────────────────────────────────────────────────────
    -- POPULATE TAB 5: TELEPORTS (OBBY TIERS)
    -- ─────────────────────────────────────────────────────────────────────────
    local tpPage = Pages["Teleport"]
    for _, tp in ipairs(TeleportLocations) do
        CreateButton(tpPage, tp.Name, Theme.SurfaceCard, function()
            self:TeleportTo(tp.Pos)
        end)
    end

    -- Floating Restore Pill Button (When minimized)
    local Pill = Instance.new("TextButton")
    Pill.Name = "StealBaddiesPill"
    Pill.Size = UDim2.new(0, 160, 0, 36)
    Pill.Position = UDim2.new(0.5, -80, 0, 14)
    Pill.BackgroundColor3 = Theme.SurfaceElevated
    Pill.BackgroundTransparency = 0.2
    Pill.Font = Enum.Font.GothamBold
    Pill.Text = "⚡ BADDIES SUITE"
    Pill.TextColor3 = Theme.Primary
    Pill.TextSize = 12
    Pill.Visible = false
    Pill.Parent = ScreenGui
    self.PillButton = Pill

    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(1, 0)
    PillCorner.Parent = Pill

    local PillStroke = Instance.new("UIStroke")
    PillStroke.Color = Theme.StrokeActive
    PillStroke.Thickness = 1.2
    PillStroke.Transparency = 0.3
    PillStroke.Parent = Pill

    Pill.MouseButton1Click:Connect(function()
        Pill.Visible = false
        MainFrame.Visible = true
    end)

    -- Keyboard Toggle (V or RightShift)
    local inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.End then self:Destroy() return end
        if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.V then
            MainFrame.Visible = not MainFrame.Visible
            Pill.Visible = not MainFrame.Visible
        end
    end)
    table.insert(self.Connections, inputConn)

    -- Set Default Tab
    SwitchTab("Farm")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- LIFECYCLE & BACKGROUND RUNNERS
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- CONFIG / SAVE MANAGER
-- ─────────────────────────────────────────────────────────────────────────────
function StealBaddies:SaveConfig(name)
    name = name or "default"
    if typeof(writefile) == "function" and typeof(makefolder) == "function" and typeof(isfolder) == "function" then
        pcall(function()
            if not isfolder("potassium_hub") then makefolder("potassium_hub") end
            if not isfolder("potassium_hub/configs") then makefolder("potassium_hub/configs") end
            if not isfolder("potassium_hub/configs/StealBaddies") then makefolder("potassium_hub/configs/StealBaddies") end
            local enc = HttpService:JSONEncode(self.Config)
            writefile("potassium_hub/configs/StealBaddies/" .. name .. ".json", enc)
        end)
        return true
    end
    return false
end

function StealBaddies:LoadConfig(name)
    name = name or "default"
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        local p = "potassium_hub/configs/StealBaddies/" .. name .. ".json"
        if isfile(p) then
            local ok, content = pcall(readfile, p)
            if ok and content then
                local dOk, data = pcall(function() return HttpService:JSONDecode(content) end)
                if dOk and typeof(data) == "table" then
                    for k, v in pairs(data) do
                        if typeof(self.Config[k]) == typeof(v) then
                            self.Config[k] = v
                        end
                    end
                    return true
                end
            end
        end
    end
    return false
end

function StealBaddies:Init()
    pcall(function() self:LoadConfig("default") end)
    ResolveMyPlot()
    self:BuildInterface()
    self:ApplyBypasses()

    -- RenderStepped Loop (Flight & Noclip)
    local renderConn = RunService.RenderStepped:Connect(function()
        self:UpdateFlight()
        self:UpdateNoclip()
    end)
    table.insert(self.Connections, renderConn)

    -- Heartbeat Loop (AntiVoid & Stat enforcement)
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        self:CheckAntiVoid()
        self:UpdateHumanoidStats()
    end)
    table.insert(self.Connections, heartbeatConn)

    -- Stepped Loop (Bypasses & Noclip collision flag clear)
    local steppedConn = RunService.Stepped:Connect(function()
        if self.Config.Noclip or self.State.IsStealing then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
    table.insert(self.Connections, steppedConn)

    -- Automation & ESP Worker (1 Hz / 0.5 Hz)
    local autoTask = task.spawn(function()
        while true do
            pcall(function()
                self:UpdateAutomation()
                self:UpdateESP()
                if self.Config.AutoSteal and not self.State.IsStealing then
                    self:ExecuteStealCycle()
                end
            end)
            task.wait(0.5)
        end
    end)
    self.AutoTask = autoTask

    getgenv().StealBaddiesInstance = self
    print("[StealBaddies] Jump To Steal Baddies Suite v" .. self.Version .. " loaded successfully!")
end

function StealBaddies:Destroy()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    if self.AutoTask then
        pcall(task.cancel, self.AutoTask)
        self.AutoTask = nil
    end

    for model, _ in pairs(self.ESPObjects) do
        self:ClearBaddieESP(model)
    end
    self.ESPObjects = {}

    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end

    getgenv().StealBaddiesInstance = nil
    print("[StealBaddies] Suite destroyed cleanly.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTO-START
-- ─────────────────────────────────────────────────────────────────────────────
StealBaddies:Init()

return StealBaddies
