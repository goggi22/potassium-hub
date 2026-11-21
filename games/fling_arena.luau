--[[
    ═══════════════════════════════════════════════════════════════════════════════
    FLING ARENA 💥 — ULTIMATE UTILITY & COMBAT SUITE
    ═══════════════════════════════════════════════════════════════════════════════
    Game        : Fling Arena 💥 (Place ID: 117273975798730 / Universe: 10772462583)
    Platform    : Potassium Executor / RPC Suite
    Design      : Liquid Glass × Material Design 3 (MD3) + High-Res Lucide Icons
    
    Features:
      • Combat: Fling Aura / Yeet Aura ([V]), Auto-Aim Silent Throw ([T]), Auto Grab Nearest Prop ([G]), Physics Touch Shockwave
      • Defense: QTE God / 100% Auto Break-Free, Anti-Ragdoll Fast Recovery
      • Movement: 3D Flight ([F]), Noclip ([N]), WalkSpeed & Jump Boost, Anti-Void Fall Saver
      • Visuals: Player ESP, Bot ESP, Grabbable High-Damage Props ESP, Visual Neon Aura Ring, Snaplines
      • Rewards: 1-Click Redeem All Codes (+13,000 Coins), Auto Claim Daily & Group Rewards
      • Hub Bridge: Native :Mount(tab) method + Topmost ScreenGui (renders above Escape menu)
    ═══════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEANUP EXISTING INSTANCE
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._FlingArenaInstance then
    pcall(function()
        getgenv()._FlingArenaInstance:Unload()
    end)
    getgenv()._FlingArenaInstance = nil
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────────────────────
-- CAPABILITY-SAFE TWEEN & TOPMOST GUI PARENTING
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
-- LUCIDE VECTOR ICONS & THEME TOKENS
-- ─────────────────────────────────────────────────────────────────────────────
local Icons = {
    Movement  = "rbxassetid://10723407389", -- Plane / Flight
    Combat    = "rbxassetid://10709791437", -- Crosshair / Aim
    Defense   = "rbxassetid://10734950309", -- Shield / Protection
    Visuals   = "rbxassetid://10723415760", -- Eye / ESP
    Rewards   = "rbxassetid://10723396107", -- Gift / Trophy
    Settings  = "rbxassetid://10734975486", -- Sliders / Hub
    Zap       = "rbxassetid://10709775267", -- Speed / Energy
    Close     = "rbxassetid://10747384394", -- X / Close
}

local Theme = {
    Surface = Color3.fromRGB(15, 13, 22),
    SurfaceTrans = 0.20,
    SurfaceContainer = Color3.fromRGB(24, 20, 36),
    SurfaceContainerTrans = 0.30,
    SurfaceHigh = Color3.fromRGB(38, 30, 56),
    SurfaceHighTrans = 0.40,
    
    Primary = Color3.fromRGB(175, 110, 255),       -- Electric Neon Violet
    PrimaryContainer = Color3.fromRGB(80, 35, 140),
    OnPrimary = Color3.fromRGB(255, 255, 255),
    
    Accent = Color3.fromRGB(255, 85, 160),         -- Neon Pink / Coral
    AccentContainer = Color3.fromRGB(130, 30, 75),
    
    RimLight = Color3.fromRGB(255, 255, 255),
    RimLightTrans = 0.82,
    BorderSubtle = Color3.fromRGB(210, 160, 255),
    BorderSubtleTrans = 0.86,
    
    OnSurface = Color3.fromRGB(245, 240, 255),
    OnSurfaceVariant = Color3.fromRGB(175, 165, 195),
    Outline = Color3.fromRGB(95, 80, 120),
    
    Player = Color3.fromRGB(255, 80, 90),          -- Red / Enemy
    Bot = Color3.fromRGB(80, 220, 255),            -- Cyan / Bot
    Prop = Color3.fromRGB(255, 215, 60),           -- Golden / Grabbable
    Safe = Color3.fromRGB(80, 245, 140)            -- Emerald / Green
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE ENGINE OBJECT
-- ─────────────────────────────────────────────────────────────────────────────
local FlingArena = {
    Version = "1.0.0",
    Active = true,
    Connections = {},
    ESPObjects = {},
    
    -- Config State
    Config = {
        -- Movement
        Fly = false,
        FlySpeed = 55,
        Noclip = false,
        SpeedBoost = false,
        WalkSpeed = 28,
        JumpPowerBoost = false,
        JumpPower = 70,
        AntiVoid = true,
        AntiVoidHeight = 110,
        
        -- Combat & Fling
        AutoAimThrow = true,
        AutoQTE = true,
        FastRecovery = true,
        ThrowMultiplier = 1.0,
        
        -- Fling Aura ("Бросать вещи и людей")
        FlingAura = false,
        FlingAuraRadius = 35,
        FlingAuraMode = "Scatter", -- "Scatter", "Sky", "Void"
        FlingAuraPlayers = true,
        FlingAuraBots = true,
        FlingAuraProps = true,
        FlingAuraDelay = 0.08,
        FlingAuraVisual = true,
        PhysicsShockwave = false,
        
        -- Visuals
        PlayerESP = true,
        BotESP = true,
        PropESP = true,
        
        -- Rewards
        AutoRespawn = true,
    },
    
    LastSafePosition = Vector3.new(0, 220, 250)
}

-- ─────────────────────────────────────────────────────────────────────────────
-- REVERSED REMOTES
-- ─────────────────────────────────────────────────────────────────────────────
local FlingRemotes = ReplicatedStorage:WaitForChild("Fling"):WaitForChild("Remotes")
local Remotes = {
    Grab = FlingRemotes:WaitForChild("Grab"),
    Release = FlingRemotes:WaitForChild("Release"),
    Throw = FlingRemotes:WaitForChild("Throw"),
    GrabState = FlingRemotes:WaitForChild("GrabState"),
    QTE = FlingRemotes:WaitForChild("QTE"),
    QTEResult = FlingRemotes:WaitForChild("QTEResult"),
    UseAbility = FlingRemotes:WaitForChild("UseAbility"),
    Redeem = FlingRemotes:WaitForChild("Redeem"),
    ClaimDaily = FlingRemotes:WaitForChild("ClaimDaily"),
    ClaimGroupReward = FlingRemotes:WaitForChild("ClaimGroupReward"),
    ClaimPass = FlingRemotes:WaitForChild("ClaimPass"),
    ClaimQuest = FlingRemotes:WaitForChild("ClaimQuest"),
    Respawn = FlingRemotes:WaitForChild("Respawn")
}

-- ─────────────────────────────────────────────────────────────────────────────
-- COMBAT & TARGETING SUBSYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:GetClosestEnemy()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot then return nil, 9999 end
    local closest, minDistance = nil, 9999
    
    -- 1. Check alive enemy players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local pRoot = GetCharacterRoot(player.Character)
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if pRoot and hum and hum.Health > 0 then
                local dist = (pRoot.Position - myRoot.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closest = pRoot
                end
            end
        end
    end
    
    -- 2. Check alive bots
    for _, bot in ipairs(CollectionService:GetTagged("Bot")) do
        if bot:IsDescendantOf(workspace) and bot:GetAttribute("BotAlive") == true then
            local bRoot = GetCharacterRoot(bot)
            if bRoot then
                local dist = (bRoot.Position - myRoot.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closest = bRoot
                end
            end
        end
    end
    
    return closest, minDistance
end

function FlingArena:AutoThrow()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot then return end
    
    local target, dist = self:GetClosestEnemy()
    local dir
    if target then
        -- Lead target slightly upwards for optimal parabolic impact
        dir = (target.Position + Vector3.new(0, 1.8, 0) - myRoot.Position).Unit
    else
        dir = Camera.CFrame.LookVector
    end
    
    Remotes.Throw:FireServer(dir)
end

function FlingArena:GrabClosestProp()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot then return end
    
    local closestProp, minDistance = nil, 65
    for _, g in ipairs(CollectionService:GetTagged("Grabbable")) do
        if g:IsDescendantOf(workspace) and g.PrimaryPart then
            local dist = (g.PrimaryPart.Position - myRoot.Position).Magnitude
            if dist < minDistance then
                minDistance = dist
                closestProp = g.PrimaryPart
            end
        end
    end
    
    if closestProp then
        Remotes.Grab:FireServer(closestProp, closestProp.Position)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- FLING AURA SUBSYSTEM ("БРОСАТЬ ВЕЩИ И ЛЮДЕЙ")
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:SetFlingAura(enabled)
    self.Config.FlingAura = enabled
    if self.FlingAuraToggleRef then
        self.FlingAuraToggleRef.Set(enabled, true)
    end
    self:UpdateAuraVisual()
end

function FlingArena:UpdateAuraVisual()
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    if not root then return end
    
    local ring = root:FindFirstChild("FA_AuraRing")
    if not (self.Active and self.Config.FlingAura and self.Config.FlingAuraVisual) then
        if ring then ring.Visible = false end
        return
    end
    
    if not ring then
        ring = Instance.new("CylinderHandleAdornment")
        ring.Name = "FA_AuraRing"
        ring.Adornee = root
        ring.AlwaysOnTop = false
        ring.Color3 = Theme.Accent
        ring.Transparency = 0.65
        ring.Height = 0.08
        ring.Radius = self.Config.FlingAuraRadius or 35
        ring.CFrame = CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, 0, -2.7)
        ring.Parent = root
    else
        ring.Radius = self.Config.FlingAuraRadius or 35
        ring.Visible = true
    end
end

function FlingArena:CreateZapBeam(fromPos, toPos)
    if not self.Config.FlingAuraVisual then return end
    task.spawn(function()
        local part = Instance.new("Part")
        part.Name = "FA_ZapLine"
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.Material = Enum.Material.Neon
        part.Color = Theme.Accent
        part.Transparency = 0.2
        part.CastShadow = false
        
        local dist = (toPos - fromPos).Magnitude
        part.Size = Vector3.new(0.25, 0.25, dist)
        part.CFrame = CFrame.lookAt((fromPos + toPos) / 2, toPos)
        part.Parent = workspace.Terrain
        
        local tween = safeTween(part, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Size = Vector3.new(0.02, 0.02, dist)
        })
        if tween then
            tween.Completed:Wait()
        else
            task.wait(0.18)
        end
        pcall(function() part:Destroy() end)
    end)
end

function FlingArena:GetAuraTargets()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot then return {} end
    
    local targets = {}
    local radius = self.Config.FlingAuraRadius or 35
    local myPos = myRoot.Position
    
    -- 1. Players
    if self.Config.FlingAuraPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local pRoot = GetCharacterRoot(player.Character)
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if pRoot and hum and hum.Health > 0 then
                    local dist = (pRoot.Position - myPos).Magnitude
                    if dist <= radius then
                        table.insert(targets, { Part = pRoot, Dist = dist, Type = "Player", Model = player.Character })
                    end
                end
            end
        end
    end
    
    -- 2. Bots & Dummies
    if self.Config.FlingAuraBots then
        for _, bot in ipairs(CollectionService:GetTagged("Bot")) do
            if bot:IsDescendantOf(workspace) and bot:GetAttribute("BotAlive") ~= false then
                local bRoot = GetCharacterRoot(bot)
                if bRoot then
                    local dist = (bRoot.Position - myPos).Magnitude
                    if dist <= radius then
                        table.insert(targets, { Part = bRoot, Dist = dist, Type = "Bot", Model = bot })
                    end
                end
            end
        end
        for _, dummy in ipairs(CollectionService:GetTagged("TestDummy")) do
            if dummy:IsDescendantOf(workspace) and not dummy:GetAttribute("NoGrab") then
                local dRoot = GetCharacterRoot(dummy)
                if dRoot then
                    local dist = (dRoot.Position - myPos).Magnitude
                    if dist <= radius then
                        table.insert(targets, { Part = dRoot, Dist = dist, Type = "Dummy", Model = dummy })
                    end
                end
            end
        end
    end
    
    -- 3. Heavy Props
    if self.Config.FlingAuraProps then
        for _, prop in ipairs(CollectionService:GetTagged("Grabbable")) do
            if prop:IsDescendantOf(workspace) and prop.PrimaryPart then
                local dist = (prop.PrimaryPart.Position - myPos).Magnitude
                if dist <= radius then
                    table.insert(targets, { Part = prop.PrimaryPart, Dist = dist, Type = "Prop", Model = prop })
                end
            end
        end
    end
    
    table.sort(targets, function(a, b) return a.Dist < b.Dist end)
    return targets
end

function FlingArena:FlingTarget(target)
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot or not target or not target.Part then return end
    
    local targetPos = target.Part.Position
    local myPos = myRoot.Position
    local dir
    
    if self.Config.FlingAuraMode == "Sky" then
        dir = Vector3.new(0, 1, 0)
    elseif self.Config.FlingAuraMode == "Void" then
        local horiz = (targetPos - Vector3.new(0, targetPos.Y, 250))
        if horiz.Magnitude < 0.2 then
            dir = Vector3.new(0, -1, 0)
        else
            dir = (horiz.Unit + Vector3.new(0, 0.4, 0)).Unit
        end
    else -- "Scatter" / Radial 360 degree explosion away from player
        local horiz = (targetPos - myPos) * Vector3.new(1, 0, 1)
        if horiz.Magnitude < 0.2 then
            dir = Vector3.new(0, 1, 0)
        else
            dir = (horiz.Unit + Vector3.new(0, 1.35, 0)).Unit
        end
    end
    
    -- If currently holding an item, discard/throw first
    if LocalPlayer:GetAttribute("FlingHolding") == true then
        Remotes.Throw:FireServer(dir)
        task.wait(0.02)
    end
    
    Remotes.Grab:FireServer(target.Part, targetPos)
    task.wait(0.04)
    Remotes.Throw:FireServer(dir)
    
    self:CreateZapBeam(myPos, targetPos)
end

function FlingArena:ProcessFlingAura()
    if not self.Config.FlingAura then return end
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot then return end
    
    local targets = self:GetAuraTargets()
    if #targets > 0 then
        -- Fling the nearest 1-2 targets per tick
        local count = math.min(#targets, 2)
        for i = 1, count do
            self:FlingTarget(targets[i])
            if i < count then
                task.wait(0.03)
            end
        end
    end
end

function FlingArena:PulseShockwaveOnce()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    if not myRoot then return end
    
    local targets = self:GetAuraTargets()
    for _, t in ipairs(targets) do
        self:FlingTarget(t)
        task.wait(0.025)
    end
end

function FlingArena:UpdatePhysicsShockwave()
    if not self.Config.PhysicsShockwave then return end
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    if root then
        root.AssemblyAngularVelocity = Vector3.new(0, 350000, 0)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MOVEMENT & ANTI-VOID SUBSYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:SetFly(enabled)
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

function FlingArena:UpdateFlight()
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

function FlingArena:UpdateNoclip()
    if not self.Config.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

function FlingArena:UpdateCharacter()
    local char = LocalPlayer.Character
    if not char then return end
    local root = GetCharacterRoot(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
    -- Track safe on-ground coordinates
    if root.Position.Y > 180 and (not hum.FloorMaterial or hum.FloorMaterial ~= Enum.Material.Air) then
        self.LastSafePosition = root.Position + Vector3.new(0, 3, 0)
    end
    
    -- Anti-Void Fall Saver
    if self.Config.AntiVoid and root.Position.Y < self.Config.AntiVoidHeight then
        root.AssemblyLinearVelocity = Vector3.new(0, 80, 0)
        root.CFrame = CFrame.new(self.LastSafePosition)
    end
    
    -- Speed & Jump Boosts
    if self.Config.SpeedBoost then
        hum.WalkSpeed = self.Config.WalkSpeed
    end
    if self.Config.JumpPowerBoost then
        hum.UseJumpPower = true
        hum.JumpPower = self.Config.JumpPower
    end
    
    -- Fast Recovery / Anti-Ragdoll
    if self.Config.FastRecovery then
        if char:GetAttribute("Ragdolled") or char:GetAttribute("KnockedOut") then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ESP MANAGEMENT SUBSYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:ClearESP(category)
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

function FlingArena:CreateESPBillboard(targetPart, text, color, offset)
    local bb = Instance.new("BillboardGui")
    bb.Name = "FA_ESP_" .. math.random(1000, 9999)
    bb.Adornee = targetPart
    bb.Size = UDim2.new(0, 150, 0, 30)
    bb.StudsOffset = offset or Vector3.new(0, 2.4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 600
    bb.ResetOnSpawn = false
    
    local container = Instance.new("Frame")
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
    container.BackgroundTransparency = 0.35
    container.BorderSizePixel = 0
    container.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = container
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = 0.35
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
    
    SafeParent(bb, true)
    return bb
end

function FlingArena:CreateHighlight(targetModel, outlineColor, fillColor)
    local hl = Instance.new("Highlight")
    hl.Name = "FA_HL_" .. math.random(1000, 9999)
    hl.Adornee = targetModel
    hl.OutlineColor = outlineColor or Theme.Primary
    hl.FillColor = fillColor or outlineColor or Theme.Primary
    hl.OutlineTransparency = 0.1
    hl.FillTransparency = 0.75
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    SafeParent(hl, true)
    return hl
end

function FlingArena:UpdateESP()
    local myChar = LocalPlayer.Character
    local myRoot = GetCharacterRoot(myChar)
    local myPos = myRoot and myRoot.Position or (Camera and Camera.CFrame.Position) or Vector3.zero
    
    -- 1. PLAYERS ESP
    if not self.ESPObjects.Players then self.ESPObjects.Players = {} end
    local activePlayers = {}
    if self.Config.PlayerESP then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                local pRoot = GetCharacterRoot(char)
                if pRoot then
                    activePlayers[char] = true
                    local dist = math.floor((pRoot.Position - myPos).Magnitude)
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hp = hum and math.floor(hum.Health) or 100
                    
                    local tag = self.ESPObjects.Players[char]
                    if not tag or not tag.Billboard or not tag.Billboard.Parent then
                        local bb = self:CreateESPBillboard(pRoot, "", Theme.Player, Vector3.new(0, 2.6, 0))
                        local hl = self:CreateHighlight(char, Theme.Player, Theme.Player)
                        tag = { Billboard = bb, Highlight = hl }
                        self.ESPObjects.Players[char] = tag
                    end
                    
                    local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                    if label then
                        label.Text = string.format("👤 %s\n%dm • %d HP", player.DisplayName, dist, hp)
                    end
                end
            end
        end
    end
    for char, tag in pairs(self.ESPObjects.Players) do
        if not activePlayers[char] or not self.Config.PlayerESP then
            pcall(function() tag.Billboard:Destroy() end)
            pcall(function() tag.Highlight:Destroy() end)
            self.ESPObjects.Players[char] = nil
        end
    end
    
    -- 2. BOTS ESP
    if not self.ESPObjects.Bots then self.ESPObjects.Bots = {} end
    local activeBots = {}
    if self.Config.BotESP then
        for _, bot in ipairs(CollectionService:GetTagged("Bot")) do
            if bot:IsDescendantOf(workspace) and bot:GetAttribute("BotAlive") == true then
                local bRoot = GetCharacterRoot(bot)
                if bRoot then
                    activeBots[bot] = true
                    local dist = math.floor((bRoot.Position - myPos).Magnitude)
                    
                    local tag = self.ESPObjects.Bots[bot]
                    if not tag or not tag.Billboard or not tag.Billboard.Parent then
                        local bb = self:CreateESPBillboard(bRoot, "", Theme.Bot, Vector3.new(0, 2.6, 0))
                        local hl = self:CreateHighlight(bot, Theme.Bot, Theme.Bot)
                        tag = { Billboard = bb, Highlight = hl }
                        self.ESPObjects.Bots[bot] = tag
                    end
                    
                    local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                    if label then
                        label.Text = string.format("🤖 [BOT] %s\n%dm", bot.Name, dist)
                    end
                end
            end
        end
    end
    for bot, tag in pairs(self.ESPObjects.Bots) do
        if not activeBots[bot] or not self.Config.BotESP then
            pcall(function() tag.Billboard:Destroy() end)
            pcall(function() tag.Highlight:Destroy() end)
            self.ESPObjects.Bots[bot] = nil
        end
    end
    
    -- 3. GRABBABLE PROPS ESP
    if not self.ESPObjects.Props then self.ESPObjects.Props = {} end
    local activeProps = {}
    if self.Config.PropESP then
        for _, prop in ipairs(CollectionService:GetTagged("Grabbable")) do
            if prop:IsDescendantOf(workspace) and prop.PrimaryPart then
                local pPart = prop.PrimaryPart
                local dist = math.floor((pPart.Position - myPos).Magnitude)
                if dist <= 180 then
                    activeProps[prop] = true
                    local tag = self.ESPObjects.Props[prop]
                    if not tag or not tag.Billboard or not tag.Billboard.Parent then
                        local bb = self:CreateESPBillboard(pPart, "", Theme.Prop, Vector3.new(0, 1.2, 0))
                        tag = { Billboard = bb }
                        self.ESPObjects.Props[prop] = tag
                    end
                    
                    local label = tag.Billboard:FindFirstChild("Frame") and tag.Billboard.Frame:FindFirstChild("Text")
                    if label then
                        label.Text = string.format("📦 %s\n%dm", prop.Name, dist)
                    end
                end
            end
        end
    end
    for prop, tag in pairs(self.ESPObjects.Props) do
        if not activeProps[prop] or not self.Config.PropESP then
            pcall(function() tag.Billboard:Destroy() end)
            self.ESPObjects.Props[prop] = nil
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTOMATION & REWARDS
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:RedeemAllCodes()
    local codes = { "HAPPY", "RELEASE", "SCHOOL", "SPEEDRUN" }
    for _, code in ipairs(codes) do
        pcall(function() Remotes.Redeem:FireServer(code) end)
        task.wait(0.1)
    end
end

function FlingArena:ClaimAllRewards()
    pcall(function() Remotes.ClaimDaily:FireServer() end)
    pcall(function() Remotes.ClaimGroupReward:InvokeServer() end)
    pcall(function() Remotes.ClaimForever:FireServer() end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- STANDALONE LIQUID GLASS UI (TOPMOST RENDER OVER ESCAPE MENU)
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:SetMenuVisible(visible)
    if not self.MainFrame then return end
    self.MainFrame.Visible = visible
    if visible then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end

function FlingArena:BuildStandaloneUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FA_StandaloneSuite"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 2147483647 -- Highest 32-bit integer: Renders above Escape Menu & Pause Screens
    sg.IgnoreGuiInset = true     -- Full viewport coordinates
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SafeParent(sg, true)
    
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(0, 580, 0, 410)
    main.BackgroundColor3 = Theme.Surface
    main.BackgroundTransparency = Theme.SurfaceTrans
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = sg
    
    -- Modal cursor unlocker
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
    titleLabel.Size = UDim2.new(0, 360, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Theme.OnSurface
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "FLING ARENA 💥  //  COMBAT & UTILITY"
    titleLabel.Parent = titleBar
    
    local badge = Instance.new("TextLabel")
    badge.Position = UDim2.new(0, 375, 0.5, -9)
    badge.Size = UDim2.new(0, 50, 0, 18)
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
    
    -- Dragging
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
    tabBar.Size = UDim2.new(0, 145, 1, -48)
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
    contentPane.Position = UDim2.new(0, 145, 0, 48)
    contentPane.Size = UDim2.new(1, -145, 1, -48)
    contentPane.BackgroundTransparency = 1
    contentPane.Parent = main
    
    local tabs = {}
    local tabBtns = {}
    local tabDefs = {
        { name = "Movement", icon = Icons.Movement },
        { name = "Combat",   icon = Icons.Combat },
        { name = "Visuals",  icon = Icons.Visuals },
        { name = "Rewards",  icon = Icons.Rewards },
        { name = "Bridge",   icon = Icons.Settings }
    }
    
    local function selectTab(name)
        for tName, page in pairs(tabs) do
            page.Visible = (tName == name)
        end
        for tName, item in pairs(tabBtns) do
            local isSel = (tName == name)
            item.btn.BackgroundColor3 = isSel and Theme.PrimaryContainer or Theme.SurfaceHigh
            item.btn.BackgroundTransparency = isSel and 0.25 or 0.75
            item.label.TextColor3 = isSel and Theme.Primary or Theme.OnSurfaceVariant
            item.icon.ImageColor3 = isSel and Theme.Primary or Theme.OnSurfaceVariant
        end
    end
    
    for _, def in ipairs(tabDefs) do
        local name = def.name
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 128, 0, 36)
        btn.BackgroundColor3 = Theme.SurfaceHigh
        btn.BackgroundTransparency = 0.75
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.Parent = tabBar
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0, 10, 0.5, -9)
        icon.BackgroundTransparency = 1
        icon.Image = def.icon
        icon.ImageColor3 = Theme.OnSurfaceVariant
        icon.Parent = btn
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, 36, 0, 0)
        label.Size = UDim2.new(1, -40, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Theme.OnSurfaceVariant
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = name
        label.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            selectTab(name)
        end)
        tabBtns[name] = { btn = btn, label = label, icon = icon }
        
        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "Page"
        page.Size = UDim2.fromScale(1, 1)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
    
    -- Helper UI Components
    local function createToggle(parent, title, iconId, initialVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 38)
        frame.BackgroundColor3 = Theme.SurfaceContainer
        frame.BackgroundTransparency = 0.45
        frame.BorderSizePixel = 0
        frame.Parent = parent
        
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 7)
        fCorner.Parent = frame
        
        if iconId then
            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 16, 0, 16)
            icon.Position = UDim2.new(0, 10, 0.5, -8)
            icon.BackgroundTransparency = 1
            icon.Image = iconId
            icon.ImageColor3 = Theme.Primary
            icon.Parent = frame
        end
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, iconId and 34 or 12, 0, 0)
        label.Size = UDim2.new(1, iconId and -90 or -70, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextColor3 = Theme.OnSurface
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = title
        label.Parent = frame
        
        local tBtn = Instance.new("TextButton")
        tBtn.Position = UDim2.new(1, -46, 0.5, -11)
        tBtn.Size = UDim2.new(0, 36, 0, 22)
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
        frame.BackgroundTransparency = 0.45
        frame.BorderSizePixel = 0
        frame.Parent = parent
        
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 7)
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
    
    local function createButton(parent, text, iconId, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = color or Theme.PrimaryContainer
        btn.BackgroundTransparency = 0.25
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = btn
        
        if iconId then
            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 18, 0, 18)
            icon.Position = UDim2.new(0, 14, 0.5, -9)
            icon.BackgroundTransparency = 1
            icon.Image = iconId
            icon.ImageColor3 = Theme.OnSurface
            icon.Parent = btn
        end
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, iconId and 40 or 12, 0, 0)
        label.Size = UDim2.new(1, iconId and -45 or -24, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Theme.OnSurface
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text
        label.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
    end
    
    local function createSelector(parent, title, options, initialIdx, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 38)
        frame.BackgroundColor3 = Theme.SurfaceContainer
        frame.BackgroundTransparency = 0.45
        frame.BorderSizePixel = 0
        frame.Parent = parent
        
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 7)
        fCorner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, 12, 0, 0)
        label.Size = UDim2.new(1, -150, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextColor3 = Theme.OnSurface
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = title
        label.Parent = frame
        
        local idx = initialIdx or 1
        local cycleBtn = Instance.new("TextButton")
        cycleBtn.Position = UDim2.new(1, -135, 0.5, -12)
        cycleBtn.Size = UDim2.new(0, 125, 0, 24)
        cycleBtn.BackgroundColor3 = Theme.SurfaceHigh
        cycleBtn.BorderSizePixel = 0
        cycleBtn.Font = Enum.Font.GothamBold
        cycleBtn.TextSize = 10
        cycleBtn.TextColor3 = Theme.Primary
        cycleBtn.Text = options[idx] or "Mode"
        cycleBtn.Parent = frame
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 5)
        bCorner.Parent = cycleBtn
        
        cycleBtn.MouseButton1Click:Connect(function()
            idx = idx + 1
            if idx > #options then idx = 1 end
            cycleBtn.Text = options[idx]
            if callback then callback(options[idx], idx) end
        end)
        
        return {
            Set = function(newIdx)
                idx = newIdx
                cycleBtn.Text = options[idx]
            end
        }
    end
    
    -- 1. Movement Page
    self.FlyToggleRef = createToggle(tabs["Movement"], "3D Camera Flight ([F])", Icons.Movement, self.Config.Fly, function(v)
        self:SetFly(v)
    end)
    createSlider(tabs["Movement"], "Flight Speed", 15, 160, self.Config.FlySpeed, function(v)
        self.Config.FlySpeed = v
    end)
    self.NoclipToggleRef = createToggle(tabs["Movement"], "Noclip (Phase Walls) [N]", Icons.Zap, self.Config.Noclip, function(v)
        self.Config.Noclip = v
    end)
    createToggle(tabs["Movement"], "Anti-Void Fall Saver", Icons.Defense, self.Config.AntiVoid, function(v)
        self.Config.AntiVoid = v
    end)
    createToggle(tabs["Movement"], "Speed Multiplier Boost", Icons.Zap, self.Config.SpeedBoost, function(v)
        self.Config.SpeedBoost = v
    end)
    createSlider(tabs["Movement"], "WalkSpeed Override", 16, 65, self.Config.WalkSpeed, function(v)
        self.Config.WalkSpeed = v
    end)
    createToggle(tabs["Movement"], "High Jump Boost", Icons.Movement, self.Config.JumpPowerBoost, function(v)
        self.Config.JumpPowerBoost = v
    end)
    createSlider(tabs["Movement"], "JumpPower Override", 50, 140, self.Config.JumpPower, function(v)
        self.Config.JumpPower = v
    end)
    
    -- 2. Combat Page & Fling Aura ("Бросать вещи и людей")
    self.FlingAuraToggleRef = createToggle(tabs["Combat"], "Fling Aura / Yeet Aura ([V])", Icons.Zap, self.Config.FlingAura, function(v)
        self:SetFlingAura(v)
    end)
    createSlider(tabs["Combat"], "Aura Radius (Studs)", 15, 70, self.Config.FlingAuraRadius, function(v)
        self.Config.FlingAuraRadius = v
        self:UpdateAuraVisual()
    end)
    createSelector(tabs["Combat"], "Aura Trajectory", { "Scatter 360°", "Sky Orbit", "Void Pit" }, 1, function(opt)
        if opt:find("Sky") then
            self.Config.FlingAuraMode = "Sky"
        elseif opt:find("Void") then
            self.Config.FlingAuraMode = "Void"
        else
            self.Config.FlingAuraMode = "Scatter"
        end
    end)
    createToggle(tabs["Combat"], "Target Enemy Players", Icons.Combat, self.Config.FlingAuraPlayers, function(v)
        self.Config.FlingAuraPlayers = v
    end)
    createToggle(tabs["Combat"], "Target Arena Bots", Icons.Combat, self.Config.FlingAuraBots, function(v)
        self.Config.FlingAuraBots = v
    end)
    createToggle(tabs["Combat"], "Target Heavy Props", Icons.Zap, self.Config.FlingAuraProps, function(v)
        self.Config.FlingAuraProps = v
    end)
    createToggle(tabs["Combat"], "Visual Aura Circle (Neon Ring)", Icons.Visuals, self.Config.FlingAuraVisual, function(v)
        self.Config.FlingAuraVisual = v
        self:UpdateAuraVisual()
    end)
    createToggle(tabs["Combat"], "Physics Touch Shockwave", Icons.Zap, self.Config.PhysicsShockwave, function(v)
        self.Config.PhysicsShockwave = v
        if not v then
            local char = LocalPlayer.Character
            local root = GetCharacterRoot(char)
            if root then root.AssemblyAngularVelocity = Vector3.zero end
        end
    end)
    createButton(tabs["Combat"], "Instant 360° Shockwave Pulse", Icons.Zap, Theme.AccentContainer, function()
        self:PulseShockwaveOnce()
    end)
    createToggle(tabs["Combat"], "Auto-Aim Silent Throw ([T])", Icons.Combat, self.Config.AutoAimThrow, function(v)
        self.Config.AutoAimThrow = v
    end)
    createToggle(tabs["Combat"], "QTE God / 100% Break-Free", Icons.Defense, self.Config.AutoQTE, function(v)
        self.Config.AutoQTE = v
    end)
    createToggle(tabs["Combat"], "Fast Recovery (Anti-Ragdoll)", Icons.Defense, self.Config.FastRecovery, function(v)
        self.Config.FastRecovery = v
    end)
    createButton(tabs["Combat"], "Aim & Fling at Nearest Target ([T])", Icons.Combat, Theme.PrimaryContainer, function()
        self:AutoThrow()
    end)
    createButton(tabs["Combat"], "Quick-Grab Nearest Prop ([G])", Icons.Zap, Theme.PrimaryContainer, function()
        self:GrabClosestProp()
    end)
    createButton(tabs["Combat"], "Trigger Equipped Ability", Icons.Zap, Theme.PrimaryContainer, function()
        Remotes.UseAbility:FireServer()
    end)
    
    -- 3. Visuals Page
    createToggle(tabs["Visuals"], "Player ESP (Health & Box)", Icons.Visuals, self.Config.PlayerESP, function(v)
        self.Config.PlayerESP = v
        if not v then self:ClearESP("Players") end
    end)
    createToggle(tabs["Visuals"], "Bot ESP (Cyan Highlights)", Icons.Visuals, self.Config.BotESP, function(v)
        self.Config.BotESP = v
        if not v then self:ClearESP("Bots") end
    end)
    createToggle(tabs["Visuals"], "Grabbable Props ESP", Icons.Visuals, self.Config.PropESP, function(v)
        self.Config.PropESP = v
        if not v then self:ClearESP("Props") end
    end)
    
    -- 4. Rewards Page
    createButton(tabs["Rewards"], "Redeem All Codes (+13,000 Coins)", Icons.Rewards, Theme.PrimaryContainer, function()
        self:RedeemAllCodes()
    end)
    createButton(tabs["Rewards"], "Claim Daily & Group Rewards", Icons.Rewards, Theme.AccentContainer, function()
        self:ClaimAllRewards()
    end)
    createToggle(tabs["Rewards"], "Instant Auto-Respawn", Icons.Zap, self.Config.AutoRespawn, function(v)
        self.Config.AutoRespawn = v
    end)
    
    -- 5. Bridge Page
    local bridgeNote = Instance.new("TextLabel")
    bridgeNote.Size = UDim2.new(1, 0, 0, 95)
    bridgeNote.BackgroundColor3 = Theme.SurfaceContainer
    bridgeNote.BackgroundTransparency = 0.4
    bridgeNote.Font = Enum.Font.Gotham
    bridgeNote.TextSize = 11
    bridgeNote.TextColor3 = Theme.OnSurfaceVariant
    bridgeNote.TextWrapped = true
    bridgeNote.Text = "FLING ARENA HUB INTEGRATION:\nMount this module directly into your master hub tab with:\ngetgenv().FlingArena:Mount(tab)\n\nControls: [RightControl] toggle GUI, [F] Flight, [N] Noclip, [T] Aim-Throw, [G] Grab Prop."
    bridgeNote.Parent = tabs["Bridge"]
    
    local noteCorner = Instance.new("UICorner")
    noteCorner.CornerRadius = UDim.new(0, 7)
    noteCorner.Parent = bridgeNote
    
    createButton(tabs["Bridge"], "Unload & Clean All Modules", Icons.Close, Theme.AccentContainer, function()
        self:Unload()
    end)
    
    selectTab("Movement")
    self.StandaloneScreenGui = sg
    self.MainFrame = main
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HUB INTEGRATION BRIDGE: FlingArena:Mount(tab)
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:Mount(tab)
    if not tab then return end
    
    if tab.AddSection then tab:AddSection("Movement & Flight") end
    if tab.AddToggle then
        self.FlyToggleRef = tab:AddToggle({
            Name = "3D Camera Flight ([F])",
            Default = self.Config.Fly,
            Callback = function(v) self:SetFly(v) end
        })
        self.NoclipToggleRef = tab:AddToggle({
            Name = "Noclip ([N])",
            Default = self.Config.Noclip,
            Callback = function(v) self.Config.Noclip = v end
        })
        tab:AddToggle({
            Name = "Anti-Void Fall Saver",
            Default = self.Config.AntiVoid,
            Callback = function(v) self.Config.AntiVoid = v end
        })
    end
    
    if tab.AddSection then tab:AddSection("Combat & Fling") end
    if tab.AddToggle then
        self.FlingAuraToggleRef = tab:AddToggle({
            Name = "Fling Aura / Yeet Aura ([V])",
            Default = self.Config.FlingAura,
            Callback = function(v) self:SetFlingAura(v) end
        })
        tab:AddToggle({
            Name = "Physics Touch Shockwave",
            Default = self.Config.PhysicsShockwave,
            Callback = function(v) self.Config.PhysicsShockwave = v end
        })
        tab:AddToggle({
            Name = "Auto-Aim Silent Throw ([T])",
            Default = self.Config.AutoAimThrow,
            Callback = function(v) self.Config.AutoAimThrow = v end
        })
        tab:AddToggle({
            Name = "QTE God (100% Break-Free)",
            Default = self.Config.AutoQTE,
            Callback = function(v) self.Config.AutoQTE = v end
        })
        tab:AddToggle({
            Name = "Fast Recovery (Anti-Ragdoll)",
            Default = self.Config.FastRecovery,
            Callback = function(v) self.Config.FastRecovery = v end
        })
    end
    
    if tab.AddSlider then
        tab:AddSlider({
            Name = "Aura Radius (Studs)",
            Min = 15,
            Max = 70,
            Default = self.Config.FlingAuraRadius,
            Callback = function(v) self.Config.FlingAuraRadius = v; self:UpdateAuraVisual() end
        })
    end
    
    if tab.AddButton then
        tab:AddButton({
            Name = "Instant 360° Shockwave Pulse",
            Callback = function() self:PulseShockwaveOnce() end
        })
        tab:AddButton({
            Name = "Aim & Fling Nearest Target ([T])",
            Callback = function() self:AutoThrow() end
        })
        tab:AddButton({
            Name = "Redeem All Codes (+13,000 Coins)",
            Callback = function() self:RedeemAllCodes() end
        })
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- LIFECYCLE & EVENT LOOP
-- ─────────────────────────────────────────────────────────────────────────────
function FlingArena:Init()
    -- Build Standalone UI
    self:BuildStandaloneUI()
    
    -- Movement Heartbeat Loop (Ultra-lightweight)
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not self.Active then return end
        self:UpdateFlight()
        self:UpdateCharacter()
        self:UpdatePhysicsShockwave()
    end)
    table.insert(self.Connections, heartbeatConn)
    
    -- Noclip Stepped Loop
    local steppedConn = RunService.Stepped:Connect(function()
        if not self.Active then return end
        self:UpdateNoclip()
    end)
    table.insert(self.Connections, steppedConn)
    
    -- Fling Aura Task Loop ("Бросать вещи и людей")
    task.spawn(function()
        while self.Active do
            if self.Config.FlingAura then
                pcall(function() self:ProcessFlingAura() end)
            end
            task.wait(self.Config.FlingAuraDelay or 0.08)
        end
    end)
    
    -- Character Added Listener (Re-attaches Aura visuals)
    local charAddedConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        self:UpdateAuraVisual()
    end)
    table.insert(self.Connections, charAddedConn)
    
    -- QTE God Listener (100% Instant Break-Free)
    local qteConn = Remotes.QTE.OnClientEvent:Connect(function(action, token)
        if not self.Active or not self.Config.AutoQTE then return end
        if action == "Start" then
            task.wait(0.12)
            Remotes.QTEResult:FireServer(token, true)
        end
    end)
    table.insert(self.Connections, qteConn)
    
    -- Auto-Respawn Listener
    local charDiedConn = LocalPlayer.CharacterAdded:Connect(function(char)
        if not self.Active or not self.Config.AutoRespawn then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                task.wait(0.5)
                Remotes.Respawn:FireServer()
            end)
        end
    end)
    table.insert(self.Connections, charDiedConn)
    
    -- Cursor Liberation Loop: guarantees mouse freedom whenever menu is open
    local renderConn = RunService.RenderStepped:Connect(function()
        if not self.Active then return end
        if self.MainFrame and self.MainFrame.Visible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)
    table.insert(self.Connections, renderConn)
    
    -- Escape Menu Listener
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
    
    -- Keyboard Shortcuts
    local inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            self:SetFly(not self.Config.Fly)
        elseif input.KeyCode == Enum.KeyCode.N then
            self.Config.Noclip = not self.Config.Noclip
            if self.NoclipToggleRef then
                self.NoclipToggleRef.Set(self.Config.Noclip, true)
            end
        elseif input.KeyCode == Enum.KeyCode.V then
            self:SetFlingAura(not self.Config.FlingAura)
        elseif input.KeyCode == Enum.KeyCode.T then
            self:AutoThrow()
        elseif input.KeyCode == Enum.KeyCode.G then
            self:GrabClosestProp()
        elseif input.KeyCode == Enum.KeyCode.RightControl then
            if self.MainFrame then
                self:SetMenuVisible(not self.MainFrame.Visible)
            end
        end
    end)
    table.insert(self.Connections, inputConn)
    
    print("[FlingArena] Suite initialized successfully.")
end

function FlingArena:Unload()
    self.Active = false
    self.Config.Fly = false
    self.Config.FlingAura = false
    self.Config.PhysicsShockwave = false
    self:UpdateAuraVisual()
    
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}
    
    self:ClearESP()
    
    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    if root then
        local ring = root:FindFirstChild("FA_AuraRing")
        if ring then pcall(function() ring:Destroy() end) end
        pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
    end
    
    if self.StandaloneScreenGui then
        pcall(function() self.StandaloneScreenGui:Destroy() end)
        self.StandaloneScreenGui = nil
    end
    
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    
    print("[FlingArena] Unloaded successfully.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- GLOBAL REGISTRATION & EXECUTION
-- ─────────────────────────────────────────────────────────────────────────────
getgenv()._FlingArenaInstance = FlingArena
getgenv().FlingArena = FlingArena

FlingArena:Init()
return FlingArena
