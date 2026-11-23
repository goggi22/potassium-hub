--[[
    ══════════════════════════════════════════════════════════════════════════════════
    [⚔️] KIT PVP FFA (1.21 COMBAT) — ULTIMATE COMBAT & UTILITY SUITE
    ══════════════════════════════════════════════════════════════════════════════════
    Target Game : [⚔️] Kit PVP FFA (Roblox PlaceId: 75260404327641, Universe: 10774244015)
    Platform    : Potassium Executor / Luau Environment
    Design      : Liquid Glass × Material Design 3 (MD3) Translucent Framework
    Author      : PHANTOM END
    
    Reversed Engine Architecture:
      • Physics & Combat: Minecraft 1.21 simulation engine (Mace, Spear, Shields, Knockback)
      • Networking: ReplicatedStorage.VoxelCombat (Attack, Block, Sprint, Feedback, KnockbackAck)
      • Geometry & Hitboxes: ReplicatedStorage.VoxelMeleeGeometry (Margin, Box, Hit)
      • Weapon Engine: ReplicatedStorage.VoxelWeapons (Stats, Held, Strength, ReachBlocks)
      • Knockback Controller: ReplicatedStorage.VoxelKnockbackMotion (Built-in Register callback)
      • Combat Client: Players.LocalPlayer.PlayerScripts.VoxelCombatClient (performAttack engine func)
      • Classes & Kits: ReplicatedStorage.Remotes.GameAction ("EquipClass")
    ══════════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEAN EXISTING INSTANCE
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._KitPvPFFAInstance then
    pcall(function()
        getgenv()._KitPvPFFAInstance:Unload()
    end)
    getgenv()._KitPvPFFAInstance = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVICES & REFS
-- ─────────────────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────────────────────
-- IMPORT LIQUID GLASS UI FRAMEWORK
-- ─────────────────────────────────────────────────────────────────────────────
local BaseURL = "https://raw.githubusercontent.com/goggi22/potassium-hub/main/"
local function CacheBust(url)
    local sep = url:find("%?") and "&" or "?"
    return url .. sep .. "nocache=" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

local LiquidGlass = getgenv and getgenv().LiquidGlass
if not LiquidGlass then
    local ok, res = pcall(function()
        return game:HttpGet(CacheBust(BaseURL .. "src/ui/liquid_glass.luau"))
    end)
    if ok and res and #res > 0 then
        local fn = loadstring(res)
        if fn then
            LiquidGlass = fn()
            if getgenv then getgenv().LiquidGlass = LiquidGlass end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- REVERSED MODULES & REMOTES
-- ─────────────────────────────────────────────────────────────────────────────
local VoxelCombat = ReplicatedStorage:WaitForChild("VoxelCombat", 10)
local AttackRemote = VoxelCombat and VoxelCombat:WaitForChild("Attack", 5)
local BlockRemote = VoxelCombat and VoxelCombat:WaitForChild("Block", 5)

local VoxelWeapons = require(ReplicatedStorage:WaitForChild("VoxelWeapons", 10))
local VoxelMeleeGeometry = require(ReplicatedStorage:WaitForChild("VoxelMeleeGeometry", 10))
local VoxelKnockbackMotion = require(ReplicatedStorage:WaitForChild("VoxelKnockbackMotion", 10))
local MeleeHitVisuals = require(ReplicatedStorage:WaitForChild("MeleeHitVisuals", 10))

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local GameAction = RemotesFolder and RemotesFolder:WaitForChild("GameAction", 5)
local EatGoldenApple = ReplicatedStorage:FindFirstChild("EatGoldenApple")

-- Extract internal performAttack closure from VoxelCombatClient
local performAttack = nil
pcall(function()
    for _, f in ipairs(getgc(false)) do
        if typeof(f) == "function" and islclosure(f) then
            local info = debug.getinfo(f)
            if info.name == "performAttack" or (info.source and info.source:find("VoxelCombatClient") and info.currentline == 375) then
                performAttack = f
                break
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SUITE CONFIGURATION & STATE
-- ─────────────────────────────────────────────────────────────────────────────
local Config = {
    -- Combat
    Killaura = false,
    KillauraRange = 16,
    KillauraDelay = 0.12,
    ReachExpander = true,
    CustomReachBlocks = 6, -- 6 blocks * 3.2 = 19.2 studs
    HitboxMargin = 3.5,    -- Expands VoxelMeleeGeometry.Margin
    AlwaysCrit = true,     -- 100% Guaranteed Minecraft 1.21 Critical Hits
    InstantStrength = true,-- No attack cooldown (100% full attack gauge)
    AntiKnockback = true,  -- Zero knockback via built-in VoxelKnockbackMotion callback
    MaceSmashMultiplier = 15,
    AutoShield = false,
    AutoGoldenApple = false,
    GAppleHealthThreshold = 40,
    AutoTotem = false,

    -- Visuals (ESP)
    ESP_Enabled = true,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Tracers = false,

    -- Movement
    SpeedBoost = false,
    WalkSpeed = 24,
    InfiniteJump = false,
    Noclip = false,
    Flight = false,
    FlightSpeed = 45,
    AntiAFK = true,
}

local Suite = {
    Version = "2.1.0",
    Config = Config,
    Connections = {},
    ESPObjects = {},
    OriginalFunctions = {},
    KnockbackUnhook = nil,
    Seq = 1,
    LastAttackTime = 0,
    LastGAppleTime = 0,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE COMBAT HELPERS
-- ─────────────────────────────────────────────────────────────────────────────
local function getCharacter(player)
    player = player or LocalPlayer
    return player.Character
end

local function getRootPart(player)
    local char = getCharacter(player)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local char = getCharacter(player)
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Find optimal living enemy target
local function GetClosestTarget(maxRange)
    local myChar = getCharacter()
    local myRoot = getRootPart()
    if not myChar or not myRoot then return nil, math.huge end

    local closestPlayer = nil
    local closestDist = maxRange or Config.KillauraRange

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyChar = player.Character
            local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
            local enemyHum = enemyChar:FindFirstChildOfClass("Humanoid")

            if enemyRoot and enemyHum and enemyHum.Health > 0 then
                -- Check if enemy is in safe zone or spawn
                local inSpawn = enemyChar:GetAttribute("SpawnProtected") or enemyChar:GetAttribute("InLobby")
                if not inSpawn then
                    local dist = (enemyRoot.Position - myRoot.Position).Magnitude
                    if dist <= closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end
            end
        end
    end

    return closestPlayer, closestDist
end

-- Direct Raw Attack Construction (fallback if performAttack is unavailable)
local function ExecuteRawAttack(targetModel, aimVector)
    local char = getCharacter()
    local hrp = getRootPart()
    if not char or not hrp or not AttackRemote then return end

    local eyePos = VoxelMeleeGeometry.Eye(hrp.Position, char:GetAttribute("Sneaking"))
    local targetHrp = targetModel:FindFirstChild("HumanoidRootPart")
    local hitPart = targetModel:FindFirstChild("Head") or targetHrp

    Suite.Seq = Suite.Seq + 1
    local fallVal = Config.AlwaysCrit and 10 or (char:GetAttribute("LocalFallDistance") or 0)

    local packet = {
        version = 2,
        character = char,
        seq = Suite.Seq,
        sentAt = workspace:GetServerTimeNow(),
        eye = eyePos,
        targetRoot = targetHrp and targetHrp.Position or nil,
        hitPart = hitPart,
        slow = false,
        fall = fallVal > 0 and fallVal or nil,
        pierce = nil,
        swap = nil
    }

    if MeleeHitVisuals and MeleeHitVisuals.Predict then
        pcall(MeleeHitVisuals.Predict, targetModel)
    end

    local reachDist = (Config.CustomReachBlocks or 6) * 3.2
    local hitPos = eyePos + aimVector * reachDist
    AttackRemote:FireServer(targetModel, hitPos, aimVector, nil, packet)
end

-- Unified Attack Dispatcher
local function AttackTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local myChar = getCharacter()
    local myRoot = getRootPart()
    local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myChar or not myRoot or not targetHrp then return end

    local eyePos = VoxelMeleeGeometry.Eye(myRoot.Position, myChar:GetAttribute("Sneaking"))
    local aimVector = (targetHrp.Position - eyePos).Unit

    -- 1. Apply 100% Critical Hit Attribute on character
    if Config.AlwaysCrit then
        local fall = (VoxelWeapons.Held(myChar).type == "mace" and Config.MaceSmashMultiplier) or 10
        myChar:SetAttribute("LocalFallDistance", fall)
    end

    -- 2. Execute via native performAttack engine closure
    if performAttack then
        pcall(performAttack, aimVector)
    else
        ExecuteRawAttack(targetPlayer.Character, aimVector)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HOOKS & ENGINE OVERRIDES
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:ApplyEngineHooks()
    -- Hook 1: Instant Attack Cooldown (Always 100% Strength)
    if VoxelWeapons and VoxelWeapons.Strength then
        self.OriginalFunctions.Strength = VoxelWeapons.Strength
        VoxelWeapons.Strength = function(p33, p34)
            if Config.InstantStrength then
                return 1.0
            end
            return self.OriginalFunctions.Strength(p33, p34)
        end
    end

    -- Hook 2: Reach & Hitbox Geometry Margin Expander
    if VoxelMeleeGeometry then
        self.OriginalFunctions.Margin = VoxelMeleeGeometry.Margin
        if Config.ReachExpander then
            VoxelMeleeGeometry.Margin = Config.HitboxMargin
        end
    end

    -- Hook 3: Anti-Knockback (Built-in VoxelKnockbackMotion Callback)
    self:ApplyAntiKnockback(Config.AntiKnockback)

    -- Hook 4: Weapon Reach Modifier on Held Tool
    local function patchTool(tool)
        if tool and tool:IsA("Tool") and tool:GetAttribute("VoxelWeapon") then
            if Config.ReachExpander then
                tool:SetAttribute("ReachBlocks", Config.CustomReachBlocks)
            end
        end
    end

    local char = getCharacter()
    if char then
        for _, t in ipairs(char:GetChildren()) do patchTool(t) end
        for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do patchTool(t) end
    end

    local conn = LocalPlayer.Backpack.ChildAdded:Connect(patchTool)
    table.insert(self.Connections, conn)
end

function Suite:ApplyAntiKnockback(enable)
    if self.KnockbackUnhook then
        pcall(self.KnockbackUnhook)
        self.KnockbackUnhook = nil
    end

    if enable and VoxelKnockbackMotion and VoxelKnockbackMotion.Register then
        local char = getCharacter()
        if char then
            self.KnockbackUnhook = VoxelKnockbackMotion.Register(char, function(...)
                return Config.AntiKnockback
            end)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTOMATION & TICK LOOPS
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:StartCombatLoop()
    local combatConn = RunService.Heartbeat:Connect(function()
        local char = getCharacter()
        local hum = getHumanoid()
        if not char or not hum or hum.Health <= 0 then return end

        local now = os.clock()

        -- Maintain Critical Hit Attribute
        if Config.AlwaysCrit then
            char:SetAttribute("LocalFallDistance", 10)
        end

        -- Killaura execution
        if Config.Killaura and (now - self.LastAttackTime >= Config.KillauraDelay) then
            local target, dist = GetClosestTarget(Config.KillauraRange)
            if target then
                self.LastAttackTime = now
                AttackTarget(target)
            end
        end

        -- Auto Golden Apple defense
        if Config.AutoGoldenApple and EatGoldenApple and (now - self.LastGAppleTime >= 2.0) then
            local healthPercent = (hum.Health / hum.MaxHealth) * 100
            if healthPercent <= Config.GAppleHealthThreshold then
                self.LastGAppleTime = now
                pcall(function()
                    EatGoldenApple:FireServer("Begin")
                end)
            end
        end

        -- Auto Shield Assist
        if Config.AutoShield and BlockRemote then
            local enemy, dist = GetClosestTarget(12)
            local shouldBlock = (enemy ~= nil and dist <= 10)
            pcall(function()
                BlockRemote:FireServer(shouldBlock)
            end)
        end
    end)
    table.insert(self.Connections, combatConn)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HIGH-PERFORMANCE 2D DRAWING ESP
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:CreateESP(player)
    if player == LocalPlayer then return end

    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1.4
    box.Filled = false
    box.Color = Color3.fromRGB(0, 255, 120)

    local boxOutline = Drawing.new("Square")
    boxOutline.Visible = false
    boxOutline.Thickness = 3
    boxOutline.Filled = false
    boxOutline.Color = Color3.fromRGB(0, 0, 0)

    local name = Drawing.new("Text")
    name.Visible = false
    name.Center = true
    name.Outline = true
    name.Size = 13
    name.Color = Color3.fromRGB(240, 245, 255)

    local healthBar = Drawing.new("Line")
    healthBar.Visible = false
    healthBar.Thickness = 2.2
    healthBar.Color = Color3.fromRGB(0, 255, 120)

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1
    tracer.Color = Color3.fromRGB(0, 215, 255)

    self.ESPObjects[player] = {
        Box = box,
        BoxOutline = boxOutline,
        Name = name,
        HealthBar = healthBar,
        Tracer = tracer,
    }
end

function Suite:RemoveESP(player)
    local esp = self.ESPObjects[player]
    if esp then
        pcall(function() esp.Box:Remove() end)
        pcall(function() esp.BoxOutline:Remove() end)
        pcall(function() esp.Name:Remove() end)
        pcall(function() esp.HealthBar:Remove() end)
        pcall(function() esp.Tracer:Remove() end)
        self.ESPObjects[player] = nil
    end
end

function Suite:StartESPLoop()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then self:CreateESP(p) end
    end
    table.insert(self.Connections, Players.PlayerAdded:Connect(function(p) self:CreateESP(p) end))
    table.insert(self.Connections, Players.PlayerRemoving:Connect(function(p) self:RemoveESP(p) end))

    local espConn = RunService.RenderStepped:Connect(function()
        if not Config.ESP_Enabled then
            for _, esp in pairs(self.ESPObjects) do
                esp.Box.Visible = false
                esp.BoxOutline.Visible = false
                esp.Name.Visible = false
                esp.HealthBar.Visible = false
                esp.Tracer.Visible = false
            end
            return
        end

        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

        for player, esp in pairs(self.ESPObjects) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char and hrp and hum and hum.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

                if onScreen and pos.Z > 0 then
                    local headPos = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.6, 0))
                    local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height * 0.65
                    local boxPos = Vector2.new(pos.X - width / 2, pos.Y - height / 2)

                    -- Box
                    if Config.ESP_Boxes then
                        esp.BoxOutline.Size = Vector2.new(width, height)
                        esp.BoxOutline.Position = boxPos
                        esp.BoxOutline.Visible = true

                        esp.Box.Size = Vector2.new(width, height)
                        esp.Box.Position = boxPos
                        esp.Box.Visible = true
                    else
                        esp.Box.Visible = false
                        esp.BoxOutline.Visible = false
                    end

                    -- Name & Distance
                    if Config.ESP_Names then
                        local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                        esp.Name.Text = string.format("%s [%dm]", player.DisplayName or player.Name, dist)
                        esp.Name.Position = Vector2.new(pos.X, boxPos.Y - 16)
                        esp.Name.Visible = true
                    else
                        esp.Name.Visible = false
                    end

                    -- Health Bar
                    if Config.ESP_Health then
                        local hpRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        local barHeight = height * hpRatio
                        esp.HealthBar.From = Vector2.new(boxPos.X - 5, boxPos.Y + height)
                        esp.HealthBar.To = Vector2.new(boxPos.X - 5, boxPos.Y + height - barHeight)
                        esp.HealthBar.Color = Color3.fromHSV(hpRatio * 0.33, 0.9, 1)
                        esp.HealthBar.Visible = true
                    else
                        esp.HealthBar.Visible = false
                    end

                    -- Tracer
                    if Config.ESP_Tracers then
                        esp.Tracer.From = screenCenter
                        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
                        esp.Tracer.Visible = true
                    else
                        esp.Tracer.Visible = false
                    end
                else
                    esp.Box.Visible = false
                    esp.BoxOutline.Visible = false
                    esp.Name.Visible = false
                    esp.HealthBar.Visible = false
                    esp.Tracer.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.BoxOutline.Visible = false
                esp.Name.Visible = false
                esp.HealthBar.Visible = false
                esp.Tracer.Visible = false
            end
        end
    end)
    table.insert(self.Connections, espConn)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MOVEMENT & PLAYER PHYSICS
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:StartMovementLoops()
    -- Infinite Jump
    local jumpConn = UserInputService.JumpRequest:Connect(function()
        if Config.InfiniteJump then
            local hum = getHumanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
    table.insert(self.Connections, jumpConn)

    -- Noclip & Speed
    local moveConn = RunService.Stepped:Connect(function()
        local char = getCharacter()
        local hrp = getRootPart()
        local hum = getHumanoid()
        if not char or not hrp or not hum then return end

        if Config.Noclip then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end

        if Config.SpeedBoost and hum.MoveDirection.Magnitude > 0 then
            local currentVel = hrp.AssemblyLinearVelocity
            local targetSpeed = Config.WalkSpeed
            local flatDir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z).Unit
            hrp.AssemblyLinearVelocity = Vector3.new(flatDir.X * targetSpeed, currentVel.Y, flatDir.Z * targetSpeed)
        end
    end)
    table.insert(self.Connections, moveConn)

    -- Flight Mode (Smooth 3D Linear Velocity)
    local flyAttachment, flyLinearVel, flyOrientation = nil, nil, nil
    local function cleanupFlight()
        if flyLinearVel then pcall(function() flyLinearVel:Destroy() end); flyLinearVel = nil end
        if flyOrientation then pcall(function() flyOrientation:Destroy() end); flyOrientation = nil end
        if flyAttachment then pcall(function() flyAttachment:Destroy() end); flyAttachment = nil end
    end

    local flyConn = RunService.RenderStepped:Connect(function()
        local char = getCharacter()
        local hrp = getRootPart()
        if not char or not hrp then cleanupFlight(); return end

        if Config.Flight then
            if not flyAttachment or flyAttachment.Parent ~= hrp then
                cleanupFlight()
                flyAttachment = Instance.new("Attachment")
                flyAttachment.Name = "PFFAFlightAttachment"
                flyAttachment.Parent = hrp

                flyLinearVel = Instance.new("LinearVelocity")
                flyLinearVel.Attachment0 = flyAttachment
                flyLinearVel.MaxForce = math.huge
                flyLinearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
                flyLinearVel.RelativeTo = Enum.ActuatorRelativeTo.World
                flyLinearVel.Parent = flyAttachment

                flyOrientation = Instance.new("AlignOrientation")
                flyOrientation.Attachment0 = flyAttachment
                flyOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
                flyOrientation.RigidityEnabled = true
                flyOrientation.Parent = flyAttachment
            end

            local camCF = Camera.CFrame
            local moveVec = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - Vector3.new(0, 1, 0) end

            flyOrientation.CFrame = camCF
            if moveVec.Magnitude > 0 then
                flyLinearVel.VectorVelocity = moveVec.Unit * Config.FlightSpeed
            else
                flyLinearVel.VectorVelocity = Vector3.zero
            end
        else
            cleanupFlight()
        end
    end)
    table.insert(self.Connections, flyConn)

    -- Anti-AFK (20 min idle kick defense)
    if getconnections then
        for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
            if conn.Disable then conn:Disable() end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- KIT SELECTOR / ARENA ACTIONS
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:EquipKit(kitId)
    if not GameAction then return false end
    local ok, res = pcall(function()
        return GameAction:InvokeServer("EquipClass", kitId)
    end)
    return ok and res and res.ok == true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UNLOAD LIFECYCLE HOOK
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:Unload()
    -- Restore original functions
    if self.OriginalFunctions.Strength and VoxelWeapons then
        VoxelWeapons.Strength = self.OriginalFunctions.Strength
    end
    if self.OriginalFunctions.Margin and VoxelMeleeGeometry then
        VoxelMeleeGeometry.Margin = self.OriginalFunctions.Margin
    end

    -- Unhook anti-knockback
    if self.KnockbackUnhook then
        pcall(self.KnockbackUnhook)
        self.KnockbackUnhook = nil
    end

    -- Clean connections
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    -- Clean ESP
    for p, _ in pairs(self.ESPObjects) do
        self:RemoveESP(p)
    end
    self.ESPObjects = {}

    -- Destroy UI
    if self.Hub and self.Hub.Destroy then
        pcall(function() self.Hub:Destroy() end)
    end

    if getgenv and getgenv()._KitPvPFFAInstance == self then
        getgenv()._KitPvPFFAInstance = nil
    end

    print("[Kit PVP FFA] Suite successfully unloaded.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BUILD LIQUID GLASS × MD3 UI
-- ─────────────────────────────────────────────────────────────────────────────
function Suite:BuildUI()
    if not LiquidGlass then
        warn("[Kit PVP FFA] LiquidGlass UI framework not available; running headless.")
        return
    end

    local Hub = LiquidGlass.new({
        Title = "KIT PVP FFA [1.21]",
        Subtitle = "Liquid Glass • Material Design 3",
        Keybind = Enum.KeyCode.RightShift,
        PanicKey = Enum.KeyCode.End,
        ConfigFolder = "KitPvPFFA",
        Size = UDim2.fromOffset(630, 420)
    })
    self.Hub = Hub

    -- TAB 1: ⚔️ COMBAT
    local tabCombat = Hub:CreateTab("Combat", "⚔️")
    tabCombat:AddSection("Killaura & Combat Assist")
    tabCombat:AddToggle("Killaura (Auto Attack Target)", Config.Killaura, function(v)
        Config.Killaura = v
    end, "KillauraToggle")

    tabCombat:AddSlider("Killaura Range (Studs)", 8, 28, Config.KillauraRange, function(val)
        Config.KillauraRange = val
    end, "KillauraRangeSlider")

    tabCombat:AddSlider("Attack Delay (Seconds)", 0.05, 0.4, Config.KillauraDelay, function(val)
        Config.KillauraDelay = val
    end, "KillauraDelaySlider")

    tabCombat:AddSection("Reach & Mechanics")
    tabCombat:AddToggle("Reach Expander (19.2 Studs)", Config.ReachExpander, function(v)
        Config.ReachExpander = v
        if VoxelMeleeGeometry then
            VoxelMeleeGeometry.Margin = v and Config.HitboxMargin or Suite.OriginalFunctions.Margin
        end
    end, "ReachToggle")

    tabCombat:AddSlider("Reach Blocks (0 - 6)", 3, 6, Config.CustomReachBlocks, function(val)
        Config.CustomReachBlocks = val
    end, "ReachBlocksSlider")

    tabCombat:AddToggle("100% Guaranteed Critical Hits", Config.AlwaysCrit, function(v)
        Config.AlwaysCrit = v
    end, "AlwaysCritToggle")

    tabCombat:AddToggle("Instant Strength (No Attack Cooldown)", Config.InstantStrength, function(v)
        Config.InstantStrength = v
    end, "InstantStrengthToggle")

    tabCombat:AddToggle("100% Clean Anti-Knockback", Config.AntiKnockback, function(v)
        Config.AntiKnockback = v
        Suite:ApplyAntiKnockback(v)
    end, "AntiKBToggle")

    tabCombat:AddSection("Mace & Defensive Automation")
    tabCombat:AddSlider("Mace Smash Overdrive (Fall Mult)", 5, 30, Config.MaceSmashMultiplier, function(val)
        Config.MaceSmashMultiplier = val
    end, "MaceSmashSlider")

    tabCombat:AddToggle("Auto Shield / Block Assist", Config.AutoShield, function(v)
        Config.AutoShield = v
    end, "AutoShieldToggle")

    tabCombat:AddToggle("Auto Golden Apple", Config.AutoGoldenApple, function(v)
        Config.AutoGoldenApple = v
    end, "AutoGAppleToggle")

    tabCombat:AddSlider("GApple HP Threshold (%)", 20, 80, Config.GAppleHealthThreshold, function(val)
        Config.GAppleHealthThreshold = val
    end, "GAppleSlider")

    -- TAB 2: 👁️ VISUALS
    local tabVisuals = Hub:CreateTab("Visuals", "👁️")
    tabVisuals:AddSection("Player ESP")
    tabVisuals:AddToggle("Master ESP Enabled", Config.ESP_Enabled, function(v)
        Config.ESP_Enabled = v
    end, "MasterESPToggle")

    tabVisuals:AddToggle("Show 2D Bounding Boxes", Config.ESP_Boxes, function(v)
        Config.ESP_Boxes = v
    end, "BoxesESPToggle")

    tabVisuals:AddToggle("Show Player Names & Distance", Config.ESP_Names, function(v)
        Config.ESP_Names = v
    end, "NamesESPToggle")

    tabVisuals:AddToggle("Show Dynamic Health Bar", Config.ESP_Health, function(v)
        Config.ESP_Health = v
    end, "HealthESPToggle")

    tabVisuals:AddToggle("Show Viewport Tracers", Config.ESP_Tracers, function(v)
        Config.ESP_Tracers = v
    end, "TracersESPToggle")

    -- TAB 3: ⚡ MOVEMENT
    local tabMovement = Hub:CreateTab("Movement", "⚡")
    tabMovement:AddSection("Locomotion")
    tabMovement:AddToggle("Speed Boost", Config.SpeedBoost, function(v)
        Config.SpeedBoost = v
    end, "SpeedToggle")

    tabMovement:AddSlider("Custom WalkSpeed", 16, 50, Config.WalkSpeed, function(val)
        Config.WalkSpeed = val
    end, "WalkSpeedSlider")

    tabMovement:AddToggle("Infinite Jump", Config.InfiniteJump, function(v)
        Config.InfiniteJump = v
    end, "InfJumpToggle")

    tabMovement:AddToggle("Noclip", Config.Noclip, function(v)
        Config.Noclip = v
    end, "NoclipToggle")

    tabMovement:AddSection("3D Flight")
    tabMovement:AddToggle("Enable 3D Flight (WASD + Space/Shift)", Config.Flight, function(v)
        Config.Flight = v
    end, "FlightToggle")

    tabMovement:AddSlider("Flight Speed", 20, 100, Config.FlightSpeed, function(val)
        Config.FlightSpeed = val
    end, "FlightSpeedSlider")

    -- TAB 4: 🎒 KITS
    local tabKits = Hub:CreateTab("Kits", "🎒")
    tabKits:AddSection("One-Click 1.21 Kit Switcher")
    local kitList = {
        { id = "sword", name = "🗡️ Sword Kit (Netherite Sword + Totems)" },
        { id = "mace", name = "🔨 Mace Kit (Devastating Fall-Smash)" },
        { id = "spearmace", name = "🔱 Mace & Spear Kit (Reach + Smash)" },
        { id = "elytra", name = "🪽 Elytra & Rockets Kit (Aerial Combat)" },
        { id = "crystal", name = "💎 End Crystals Kit (Anchor / Crystal PvP)" },
        { id = "tnt", name = "💣 TNT Kit (Explosive Traps)" },
        { id = "archer", name = "🏹 Archer Kit (Bow & Crossbow)" },
        { id = "orbital", name = "⚡ Orbital Strike Kit" },
        { id = "axe", name = "🪓 Axe Kit (Shield Breaker)" },
        { id = "god", name = "👑 God Kit" },
    }

    for _, kit in ipairs(kitList) do
        tabKits:AddButton(kit.name, function()
            local success = Suite:EquipKit(kit.id)
            if success then
                Hub:Notify("Kit Equipped", kit.name .. " successfully applied!", 2.5)
            else
                Hub:Notify("Kit Error", "Could not equip " .. kit.id .. " (Check level or in-match)", 3)
            end
        end)
    end

    -- TAB 5: 📍 TELEPORTS
    local tabTeleports = Hub:CreateTab("Teleports", "📍")
    local function TeleportTo(cf, label)
        local root = getRootPart()
        if root then
            root.CFrame = cf
            Hub:Notify("Teleported", "Moved to " .. label, 2)
        end
    end

    tabTeleports:AddSection("Lobby & Arena")
    tabTeleports:AddButton("Safe Zone: SkySpawn Lobby", function()
        TeleportTo(CFrame.new(384.8, 138.5, -0.8), "SkySpawn Lobby")
    end)

    tabTeleports:AddButton("Arena Drop: Center", function()
        TeleportTo(CFrame.new(384.8, 25.0, 0.0), "Arena Center")
    end)

    tabTeleports:AddButton("Arena Drop: North", function()
        TeleportTo(CFrame.new(384.8, 25.0, -80.0), "Arena North")
    end)

    tabTeleports:AddButton("Arena Drop: South", function()
        TeleportTo(CFrame.new(384.8, 25.0, 80.0), "Arena South")
    end)

    tabTeleports:AddButton("Arena Drop: East", function()
        TeleportTo(CFrame.new(464.8, 25.0, 0.0), "Arena East")
    end)

    tabTeleports:AddButton("Arena Drop: West", function()
        TeleportTo(CFrame.new(304.8, 25.0, 0.0), "Arena West")
    end)

    tabTeleports:AddSection("Player Target")
    tabTeleports:AddButton("Teleport to Closest Enemy", function()
        local target = GetClosestTarget(500)
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            TeleportTo(target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, -3), target.DisplayName or target.Name)
        else
            Hub:Notify("Teleport", "No valid enemy found nearby.", 2.5)
        end
    end)

    -- TAB 6: ⚙️ SETTINGS
    local tabSettings = Hub:CreateTab("Settings", "⚙️")
    tabSettings:AddSection("Configuration Presets")
    tabSettings:AddButton("💾 Save Current Config", function()
        Hub:SaveConfig("default")
    end)

    tabSettings:AddButton("📂 Load Saved Config", function()
        Hub:LoadConfig("default")
    end)

    tabSettings:AddButton("⚡ Toggle AutoSave (10s)", function()
        Hub:AutoSave(true, 10)
        Hub:Notify("AutoSave", "Config auto-saving every 10 seconds.", 2.5)
    end)

    tabSettings:AddSection("Panic & Clean")
    tabSettings:AddButton("🛑 Emergency Unload [End]", function()
        Suite:Unload()
    end)

    -- Register Unload Callback
    Hub:OnUnload(function()
        Suite:Unload()
    end)

    Hub:Notify("Kit PVP FFA Ready", "Press [RightShift] for menu • [End] to panic unload.", 4)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- INITIALIZATION
-- ─────────────────────────────────────────────────────────────────────────────
Suite:ApplyEngineHooks()
Suite:StartCombatLoop()
Suite:StartESPLoop()
Suite:StartMovementLoops()
Suite:BuildUI()

if getgenv then
    getgenv()._KitPvPFFAInstance = Suite
end

print(string.format("[Kit PVP FFA] Suite v%s initialized! Menu: [RightShift] | Panic: [End]", Suite.Version))
return Suite
