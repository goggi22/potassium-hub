--[[
    ══════════════════════════════════════════════════════════════════════════════════
    [⚔️] 1.8 KIT PVP (Place ID: 72393956865647) — ULTIMATE COMBAT & UTILITY SUITE
    ══════════════════════════════════════════════════════════════════════════════════
    Target Game : [⚔️] 1.8 KIT PVP (Roblox ID: 72393956865647)
    Platform    : Potassium Executor / Luau Environment
    Design      : Liquid Glass × Material Design 3 (MD3) Acrylic GUI
    Author      : PHANTOM END
    
    Reversed Engine Architecture:
      • Physics & Combat: Custom Minecraft 1.8 simulation engine in Luau
      • Networking: Custom packet protocol over ReplicatedStorage.Shared.Network
      • Entity System: ReplicatedStorage.Client.Controller_4.EntityRenderer
      • Combat Controller: ReplicatedStorage.Client.Controller_4.CombatController_4
      • Movement Controller: ReplicatedStorage.Client.Controller_4.MovementController_4
      • Camera System: ReplicatedStorage.Client.Controller_4.CameraController
    ══════════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEAN EXISTING INSTANCE
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._KitPvPInstance then
    pcall(function()
        getgenv()._KitPvPInstance:Unload()
    end)
    getgenv()._KitPvPInstance = nil
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────────────────────
-- REVERSED MODULES & CONTROLLERS
-- ─────────────────────────────────────────────────────────────────────────────
local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)
local MovementPhysics = require(ReplicatedStorage.Shared.MovementPhysics)
local LookSweep = require(ReplicatedStorage.Shared.LookSweep)
local ItemLookup = require(ReplicatedStorage.Shared.ItemLookup)

local ControllerFolder = ReplicatedStorage.Client:WaitForChild("Controller_4")
local CombatController = require(ControllerFolder:WaitForChild("CombatController_4"))
local MovementController = require(ControllerFolder:WaitForChild("MovementController_4"))
local EntityRenderer = require(ControllerFolder:WaitForChild("EntityRenderer"))
local CameraController = require(ControllerFolder:WaitForChild("CameraController"))
local ViewmodelController = require(ControllerFolder:WaitForChild("ViewmodelController"))
local InventoryController = require(ControllerFolder:WaitForChild("InventoryController"))
local AimTargeting = require(ControllerFolder:WaitForChild("AimTargeting"))

-- Extract internal combat functions from upvalues
local AttackFunction = nil
local HitEntityFunction = nil
pcall(function()
    local startUvs = getupvalues(CombatController.start)
    local updateLoop = startUvs[2]
    AttackFunction = getupvalues(updateLoop)[2]
    local attackUvs = getupvalues(AttackFunction)
    HitEntityFunction = attackUvs[9]
end)

-- Original functions to restore on unload
local OriginalApplyAttackSlowdown = MovementController.applyAttackSlowdown
local OriginalReach = CombatController.getReach()

-- ─────────────────────────────────────────────────────────────────────────────
-- LIQUID GLASS & MD3 THEME TOKENS
-- ─────────────────────────────────────────────────────────────────────────────
local Theme = {
    Surface = Color3.fromRGB(15, 17, 24),
    SurfaceTrans = 0.22,
    SurfaceContainer = Color3.fromRGB(24, 28, 40),
    SurfaceContainerTrans = 0.35,
    SurfaceHigh = Color3.fromRGB(34, 40, 58),
    SurfaceHighTrans = 0.40,
    
    Primary = Color3.fromRGB(120, 160, 255),
    PrimaryContainer = Color3.fromRGB(45, 68, 120),
    OnPrimary = Color3.fromRGB(10, 14, 26),
    
    RimLight = Color3.fromRGB(255, 255, 255),
    RimLightTrans = 0.80,
    BorderSubtle = Color3.fromRGB(255, 255, 255),
    BorderSubtleTrans = 0.88,
    
    OnSurface = Color3.fromRGB(240, 243, 255),
    OnSurfaceVariant = Color3.fromRGB(150, 160, 185),
    Outline = Color3.fromRGB(80, 90, 115),
    
    Gold = Color3.fromRGB(255, 215, 60),
    Diamond = Color3.fromRGB(70, 230, 240),
    Purple = Color3.fromRGB(200, 120, 255),
    Green = Color3.fromRGB(100, 240, 150),
    Common = Color3.fromRGB(180, 190, 210),
    Danger = Color3.fromRGB(255, 95, 105)
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE ENGINE TABLE
-- ─────────────────────────────────────────────────────────────────────────────
local KitPvP = {
    Version = "3.0.0",
    PlaceId = 72393956865647,
    Connections = {},
    Highlights = {},
    ESPObjects = {},
    
    -- Local State
    LocalHealth = 20,
    LocalMaxHealth = 20,
    InPvPArea = false,
    LastAuraAttack = 0,
    LastAutoClick = 0,
    LastAutoEat = 0,
    
    -- Config State
    Config = {
        -- Combat
        KillAura = false,
        AuraRange = 4.5, -- in blocks (default reach = 3)
        AuraCPS = 12,
        AuraTargetMode = "Distance", -- "Distance", "LowestHP"
        SilentAim = true,
        SnapAim = false,
        
        Reach = true,
        CustomReach = 4.5,
        
        NoSlow = true,
        AutoClicker = false,
        AutoClickerCPS = 14,
        
        -- Movement
        AntiKnockback = true,
        VelocityHorizontal = 0, -- 0% = no knockback
        VelocityVertical = 0,
        
        AutoSprint = true,
        Speed = false,
        SpeedMultiplier = 1.3,
        
        Fly = false,
        FlySpeed = 35,
        
        -- Visuals
        ESPBoxes = true,
        ESPHealth = true,
        ESPNames = true,
        ESPTracers = false,
        Chams = true,
        PvPAlert = true,
        
        -- Utility
        AutoEat = false,
        EatThreshold = 10,
    }
}

-- ─────────────────────────────────────────────────────────────────────────────
-- VELOCITY / KNOCKBACK SCALING HOOK
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:HookVelocitySignals()
    pcall(function()
        local getSignal = getupvalues(Network.Connect)[1]
        local signals = getupvalues(getSignal)[1]
        
        -- 1. server_velocity_4 hook
        local velSig = signals["server_velocity_4"]
        if velSig and velSig.connections and #velSig.connections > 0 then
            self.OriginalVelCallback = velSig.connections[1]
            velSig.connections[1] = function(vec, ...)
                if KitPvP.Config.AntiKnockback and typeof(vec) == "Vector3" then
                    local h = KitPvP.Config.VelocityHorizontal / 100
                    local v = KitPvP.Config.VelocityVertical / 100
                    vec = Vector3.new(vec.X * h, vec.Y * v, vec.Z * h)
                end
                return KitPvP.OriginalVelCallback(vec, ...)
            end
        end
        
        -- 2. server_push hook
        local pushSig = signals["server_push"]
        if pushSig and pushSig.connections and #pushSig.connections > 0 then
            self.OriginalPushCallback = pushSig.connections[1]
            pushSig.connections[1] = function(vec, ...)
                if KitPvP.Config.AntiKnockback and typeof(vec) == "Vector3" then
                    local h = KitPvP.Config.VelocityHorizontal / 100
                    local v = KitPvP.Config.VelocityVertical / 100
                    vec = Vector3.new(vec.X * h, vec.Y * v, vec.Z * h)
                end
                return KitPvP.OriginalPushCallback(vec, ...)
            end
        end
    end)
end

function KitPvP:UnhookVelocitySignals()
    pcall(function()
        local getSignal = getupvalues(Network.Connect)[1]
        local signals = getupvalues(getSignal)[1]
        
        if signals["server_velocity_4"] and self.OriginalVelCallback then
            signals["server_velocity_4"].connections[1] = self.OriginalVelCallback
        end
        if signals["server_push"] and self.OriginalPushCallback then
            signals["server_push"].connections[1] = self.OriginalPushCallback
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NOSLOW (ATTACK SLOWDOWN ELIMINATOR)
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:ApplyNoSlowHook()
    if self.Config.NoSlow then
        MovementController.applyAttackSlowdown = function()
            -- no-op: horizontal velocity is never reduced by 40% and sprint is preserved
        end
    else
        MovementController.applyAttackSlowdown = OriginalApplyAttackSlowdown
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- COMBAT SUBSYSTEM: TARGET DISCOVERY & ATTACK
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:GetValidTargets()
    local myPos = MovementController.getPosition()
    if not myPos then return {} end
    
    local list = EntityRenderer.getEntityViewList_4()
    local targets = {}
    
    for _, ent in ipairs(list) do
        if ent.player and ent.player ~= LocalPlayer and ent.health and ent.health > 0 then
            if CombatController.canFight_4(ent) then
                local dist = (ent.position - myPos).Magnitude
                if dist <= self.Config.AuraRange then
                    table.insert(targets, {
                        entity = ent,
                        distance = dist,
                        health = ent.health
                    })
                end
            end
        end
    end
    
    if self.Config.AuraTargetMode == "LowestHP" then
        table.sort(targets, function(a, b) return a.health < b.health end)
    else
        table.sort(targets, function(a, b) return a.distance < b.distance end)
    end
    
    return targets
end

function KitPvP:FaceTarget(targetPos)
    local myEye = MovementController.getEyePosition_4()
    if not myEye then return end
    
    local dir = (targetPos - myEye).Unit
    local yaw = math.atan2(-dir.X, -dir.Z)
    local pitch = math.atan2(dir.Y, Vector3.new(dir.X, 0, dir.Z).Magnitude)
    CameraController.setLook(yaw, pitch)
end

function KitPvP:ExecuteAuraAttack(target)
    if not target or not target.id then return end
    
    -- Visual Swing
    pcall(function()
        ViewmodelController.swing_4()
    end)
    
    local myPos = MovementController.getPosition()
    local targetPos = target.position
    local hitPoint = targetPos + Vector3.new(0, 1.0, 0)
    local lookDir = (hitPoint - (MovementController.getEyePosition_4() or myPos)).Unit
    
    -- Optional Snap Aim
    if self.Config.SnapAim then
        self:FaceTarget(hitPoint)
    end
    
    -- Method 1: Internal extracted hitEntity
    if HitEntityFunction then
        local lookOverride = self.Config.SilentAim and lookDir or nil
        pcall(function()
            HitEntityFunction(target, hitPoint, lookOverride)
        end)
    else
        -- Method 2: Direct Network.Fire packet
        pcall(function()
            local lastTick = EntityRenderer.getLastUpdateTick()
            local lookTurn = self.Config.SilentAim and LookSweep.ANY_TURN or CameraController.getLookTurn()
            Network.Fire(
                "client_request_attack_4",
                target.id,
                Vector3.new(0, 1.0, 0),
                lastTick,
                targetPos,
                lookTurn,
                target.fromUpdateTick
            )
        end)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MOVEMENT SUBSYSTEM: FLIGHT, AUTOSPRINT, SPEED
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:UpdateFlight()
    if not self.Config.Fly then return end
    
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
    
    local flyVel
    if moveDir.Magnitude > 0 then
        flyVel = moveDir.Unit * (self.Config.FlySpeed / 10)
    else
        flyVel = Vector3.zero
    end
    
    pcall(function()
        setupvalue(MovementController.getVelocity, 1, flyVel)
    end)
end

function KitPvP:UpdateMovementMods()
    -- Auto Sprint
    if self.Config.AutoSprint then
        pcall(function()
            setupvalue(MovementController.applyAttackSlowdown, 1, true)
        end)
    end
    
    -- Speed / Bhop Boost
    if self.Config.Speed and not self.Config.Fly then
        pcall(function()
            local currentVel = MovementController.getVelocity()
            if currentVel and (math.abs(currentVel.X) > 0.05 or math.abs(currentVel.Z) > 0.05) then
                local mult = self.Config.SpeedMultiplier
                local newVel = Vector3.new(currentVel.X * mult, currentVel.Y, currentVel.Z * mult)
                setupvalue(MovementController.getVelocity, 1, newVel)
            end
        end)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- VISUALS: CHAMS & ESP
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:UpdateChams()
    local list = EntityRenderer.getEntityViewList_4()
    local activeIds = {}
    
    for _, ent in ipairs(list) do
        if ent.player and ent.player ~= LocalPlayer and ent.highlightAdornee then
            activeIds[ent.id] = true
            
            if self.Config.Chams then
                local hl = self.Highlights[ent.id]
                if not hl or hl.Parent ~= ent.highlightAdornee then
                    if hl then hl:Destroy() end
                    hl = Instance.new("Highlight")
                    hl.Name = "KitPvP_Chams"
                    hl.Adornee = ent.highlightAdornee
                    hl.FillTransparency = 0.45
                    hl.OutlineTransparency = 0.1
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = ent.highlightAdornee
                    self.Highlights[ent.id] = hl
                end
                
                local canFight = CombatController.canFight_4(ent)
                if canFight then
                    hl.FillColor = Theme.Danger
                    hl.OutlineColor = Theme.Gold
                else
                    hl.FillColor = Theme.Primary
                    hl.OutlineColor = Theme.Diamond
                end
            end
        end
    end
    
    -- Cleanup despawned highlights
    for id, hl in pairs(self.Highlights) do
        if not activeIds[id] or not self.Config.Chams then
            pcall(function() hl:Destroy() end)
            self.Highlights[id] = nil
        end
    end
end

function KitPvP:UpdateESP()
    local list = EntityRenderer.getEntityViewList_4()
    local myPos = MovementController.getPosition()
    local activeIds = {}
    
    for _, ent in ipairs(list) do
        if ent.player and ent.player ~= LocalPlayer and ent.health and ent.health > 0 then
            local id = ent.id
            activeIds[id] = true
            
            local drawPos = EntityRenderer.getEntityDrawPosition(id)
            if not drawPos and ent.position then
                drawPos = ent.position * Config.studsPerBlock
            end
            
            if drawPos then
                local screenPos, onScreen = Camera:WorldToViewportPoint(drawPos)
                local headPos, headOnScreen = Camera:WorldToViewportPoint(drawPos + Vector3.new(0, 5.4, 0))
                
                local espObj = self.ESPObjects[id]
                if not espObj then
                    espObj = self:CreateESPDrawing()
                    self.ESPObjects[id] = espObj
                end
                
                if onScreen and headOnScreen then
                    local boxHeight = math.abs(headPos.Y - screenPos.Y)
                    local boxWidth = boxHeight * 0.55
                    local topLeft = Vector2.new(screenPos.X - boxWidth / 2, headPos.Y)
                    
                    local dist = myPos and math.floor((ent.position - myPos).Magnitude) or 0
                    local hp = ent.health or 20
                    local hpPercent = math.clamp(hp / 20, 0, 1)
                    local hpColor = hp > 13 and Theme.Green or (hp > 6 and Theme.Gold or Theme.Danger)
                    
                    -- Box
                    if self.Config.ESPBoxes and espObj.Box then
                        espObj.Box.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
                        espObj.Box.Size = UDim2.fromOffset(boxWidth, boxHeight)
                        espObj.Box.Visible = true
                    elseif espObj.Box then
                        espObj.Box.Visible = false
                    end
                    
                    -- Health Bar
                    if self.Config.ESPHealth and espObj.HpBarContainer then
                        espObj.HpBarContainer.Position = UDim2.fromOffset(topLeft.X - 5, topLeft.Y)
                        espObj.HpBarContainer.Size = UDim2.fromOffset(3, boxHeight)
                        espObj.HpBarFill.Size = UDim2.new(1, 0, hpPercent, 0)
                        espObj.HpBarFill.Position = UDim2.new(0, 0, 1 - hpPercent, 0)
                        espObj.HpBarFill.BackgroundColor3 = hpColor
                        espObj.HpBarContainer.Visible = true
                    elseif espObj.HpBarContainer then
                        espObj.HpBarContainer.Visible = false
                    end
                    
                    -- Name Tag
                    if self.Config.ESPNames and espObj.NameTag then
                        espObj.NameTag.Position = UDim2.fromOffset(topLeft.X + boxWidth / 2, topLeft.Y - 14)
                        espObj.NameTag.Text = string.format("%s [%dm] (%.1f HP)", ent.player.DisplayName or ent.player.Name, dist, hp)
                        espObj.NameTag.Visible = true
                    elseif espObj.NameTag then
                        espObj.NameTag.Visible = false
                    end
                    
                    -- Tracers
                    if self.Config.ESPTracers and espObj.Tracer then
                        local screenBottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        local targetPt = Vector2.new(screenPos.X, screenPos.Y)
                        local tracerDelta = targetPt - screenBottom
                        local tracerDist = tracerDelta.Magnitude
                        local tracerAngle = math.atan2(tracerDelta.Y, tracerDelta.X)
                        
                        espObj.Tracer.Position = UDim2.fromOffset(screenBottom.X, screenBottom.Y)
                        espObj.Tracer.Size = UDim2.fromOffset(tracerDist, 1.5)
                        espObj.Tracer.Rotation = math.deg(tracerAngle)
                        espObj.Tracer.Visible = true
                    elseif espObj.Tracer then
                        espObj.Tracer.Visible = false
                    end
                else
                    self:HideESPObject(espObj)
                end
            end
        end
    end
    
    -- Cleanup inactive ESP items
    for id, obj in pairs(self.ESPObjects) do
        if not activeIds[id] then
            self:DestroyESPObject(obj)
            self.ESPObjects[id] = nil
        end
    end
end

function KitPvP:CreateESPDrawing()
    local container = self.ESPContainer
    if not container then return {} end
    
    -- Box Frame
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = container
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Primary
    stroke.Transparency = 0.2
    stroke.Thickness = 1.2
    stroke.Parent = box
    
    -- Health Bar Frame
    local hpContainer = Instance.new("Frame")
    hpContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpContainer.BackgroundTransparency = 0.3
    hpContainer.BorderSizePixel = 0
    hpContainer.Visible = false
    hpContainer.Parent = container
    
    local hpFill = Instance.new("Frame")
    hpFill.BackgroundColor3 = Theme.Green
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpContainer
    
    -- Name Label
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.TextColor3 = Theme.OnSurface
    name.Font = Enum.Font.GothamBold
    name.TextSize = 11
    name.TextStrokeTransparency = 0.4
    name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    name.AnchorPoint = Vector2.new(0.5, 0.5)
    name.Visible = false
    name.Parent = container
    
    -- Tracer Frame
    local tracer = Instance.new("Frame")
    tracer.AnchorPoint = Vector2.new(0, 0.5)
    tracer.BackgroundColor3 = Theme.Primary
    tracer.BackgroundTransparency = 0.4
    tracer.BorderSizePixel = 0
    tracer.Visible = false
    tracer.Parent = container
    
    return {
        Box = box,
        HpBarContainer = hpContainer,
        HpBarFill = hpFill,
        NameTag = name,
        Tracer = tracer
    }
end

function KitPvP:HideESPObject(obj)
    if not obj then return end
    if obj.Box then obj.Box.Visible = false end
    if obj.HpBarContainer then obj.HpBarContainer.Visible = false end
    if obj.NameTag then obj.NameTag.Visible = false end
    if obj.Tracer then obj.Tracer.Visible = false end
end

function KitPvP:DestroyESPObject(obj)
    if not obj then return end
    if obj.Box then pcall(function() obj.Box:Destroy() end) end
    if obj.HpBarContainer then pcall(function() obj.HpBarContainer:Destroy() end) end
    if obj.NameTag then pcall(function() obj.NameTag:Destroy() end) end
    if obj.Tracer then pcall(function() obj.Tracer:Destroy() end) end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UTILITY: AUTO POT / AUTO SOUP
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:CheckAutoEat()
    if not self.Config.AutoEat then return end
    if os.clock() - self.LastAutoEat < 1.0 then return end
    
    -- Check if local player is below health threshold
    if self.LocalHealth > self.Config.EatThreshold then return end
    
    -- Search hotbar for consumable items
    for slot = 1, 9 do
        local stack = InventoryController.getSelectedItemInfo(slot)
        if stack and stack.id then
            local id = tostring(stack.id):lower()
            if id:find("apple") or id:find("soup") or id:find("potion") or id:find("steak") or id:find("bread") then
                self.LastAutoEat = os.clock()
                local prevSlot = InventoryController.getSelectedSlot()
                InventoryController.selectSlot(slot)
                task.delay(0.4, function()
                    InventoryController.selectSlot(prevSlot)
                end)
                break
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MAIN LOOPS
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:StartLoops()
    -- RenderStepped Loop: Visuals, Flight, Aim
    table.insert(self.Connections, RunService.RenderStepped:Connect(function()
        self:UpdateFlight()
        self:UpdateMovementMods()
        self:UpdateChams()
        self:UpdateESP()
        
        -- PvP Alert Status
        local myPos = MovementController.getPosition()
        if myPos and self.PvPAlertBadge then
            local inPvP = myPos.Y <= Config.combat.pvpMaxHeight
            self.InPvPArea = inPvP
            if inPvP then
                self.PvPAlertBadge.Text = "⚔️ PVP ZONE (ACTIVE)"
                self.PvPAlertBadge.TextColor3 = Theme.Danger
            else
                self.PvPAlertBadge.Text = "🛡️ SPAWN SAFE (PASSIVE)"
                self.PvPAlertBadge.TextColor3 = Theme.Green
            end
        end
    end))
    
    -- Heartbeat Loop: KillAura & AutoClicker
    table.insert(self.Connections, RunService.Heartbeat:Connect(function()
        local now = os.clock()
        
        -- KillAura
        if self.Config.KillAura then
            local auraInterval = 1 / math.max(1, self.Config.AuraCPS)
            if now - self.LastAuraAttack >= auraInterval then
                local targets = self:GetValidTargets()
                if #targets > 0 then
                    self.LastAuraAttack = now
                    self:ExecuteAuraAttack(targets[1].entity)
                end
            end
        end
        
        -- AutoClicker
        if self.Config.AutoClicker and AttackFunction then
            local clickInterval = 1 / math.max(1, self.Config.AutoClickerCPS)
            if now - self.LastAutoClick >= clickInterval then
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    self.LastAutoClick = now
                    pcall(function()
                        AttackFunction(nil)
                    end)
                end
            end
        end
        
        -- AutoEat / Potion
        self:CheckAutoEat()
    end))
    
    -- Health Tracker via Network
    pcall(function()
        table.insert(self.Connections, Network.Connect("server_health", function(hp, absorption, maxHp)
            if type(hp) == "number" then
                self.LocalHealth = hp
            end
            if type(maxHp) == "number" then
                self.LocalMaxHealth = maxHp
            end
        end))
    end)
    
    -- Keyboard Hotkeys (RightShift to toggle GUI, F for Fly)
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
            self:ToggleUI()
        elseif input.KeyCode == Enum.KeyCode.F then
            self.Config.Fly = not self.Config.Fly
            if self.FlyToggleRef then
                self.FlyToggleRef.Set(self.Config.Fly, true)
            end
        end
    end))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- STANDALONE UI BUILDER (LIQUID GLASS × MD3)
-- ─────────────────────────────────────────────────────────────────────────────
local function MakeRounded(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = obj
    return corner
end

local function MakeStroke(obj, color, trans, thick)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = trans or 0.8
    stroke.Thickness = thick or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = obj
    return stroke
end

function KitPvP:BuildUI()
    local targetParent = LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KitPvP_Suite_" .. math.random(1000, 9999)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = targetParent
    self.ScreenGui = screenGui

    -- ESP Overlay Container
    local espContainer = Instance.new("Frame")
    espContainer.Name = "ESPContainer"
    espContainer.Size = UDim2.fromScale(1, 1)
    espContainer.BackgroundTransparency = 1
    espContainer.Parent = screenGui
    self.ESPContainer = espContainer

    -- HUD PvP Badge
    local pvpBadge = Instance.new("TextLabel")
    pvpBadge.Name = "PvPZoneBadge"
    pvpBadge.Position = UDim2.new(0.5, 0, 0, 18)
    pvpBadge.AnchorPoint = Vector2.new(0.5, 0)
    pvpBadge.Size = UDim2.fromOffset(210, 26)
    pvpBadge.BackgroundColor3 = Theme.Surface
    pvpBadge.BackgroundTransparency = 0.35
    pvpBadge.TextColor3 = Theme.Green
    pvpBadge.Font = Enum.Font.GothamBold
    pvpBadge.TextSize = 12
    pvpBadge.Text = "🛡️ SPAWN SAFE (PASSIVE)"
    pvpBadge.Parent = screenGui
    MakeRounded(pvpBadge, 8)
    MakeStroke(pvpBadge, Theme.BorderSubtle, 0.85, 1)
    self.PvPAlertBadge = pvpBadge

    -- Main Shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = UDim2.fromOffset(680, 440)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 8)
    shadow.ImageTransparency = 0.32
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Parent = screenGui
    self.Shadow = shadow

    -- Main Translucent Acrylic Frame
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = UDim2.fromOffset(620, 380)
    main.BackgroundColor3 = Theme.Surface
    main.BackgroundTransparency = Theme.SurfaceTrans
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    self.Main = main

    MakeRounded(main, 16)
    MakeStroke(main, Theme.RimLight, 0.78, 1.2)

    -- Specular Sheen Gradient
    local sheen = Instance.new("Frame")
    sheen.Size = UDim2.new(1, 0, 0, 100)
    sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheen.BackgroundTransparency = 0.93
    sheen.BorderSizePixel = 0
    sheen.Parent = main
    MakeRounded(sheen, 16)

    local sheenGrad = Instance.new("UIGradient")
    sheenGrad.Rotation = 90
    sheenGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 1)
    })
    sheenGrad.Parent = sheen

    -- Dragging Handler
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input)
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

    main.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            main.Position = newPos
            shadow.Position = newPos
        end
    end)

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundTransparency = 1
    header.Parent = main

    local badge = Instance.new("Frame")
    badge.Size = UDim2.fromOffset(28, 28)
    badge.Position = UDim2.fromOffset(16, 11)
    badge.BackgroundColor3 = Theme.Primary
    badge.BackgroundTransparency = 0.15
    badge.Parent = header
    MakeRounded(badge, 8)

    local badgeIcon = Instance.new("TextLabel")
    badgeIcon.Size = UDim2.fromScale(1, 1)
    badgeIcon.BackgroundTransparency = 1
    badgeIcon.Text = "⚔"
    badgeIcon.Font = Enum.Font.GothamBold
    badgeIcon.TextSize = 14
    badgeIcon.Parent = badge

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(52, 10)
    title.Size = UDim2.new(0, 260, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "1.8 KIT PVP SUITE"
    title.TextColor3 = Theme.OnSurface
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Position = UDim2.fromOffset(52, 26)
    subtitle.Size = UDim2.new(0, 260, 0, 14)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Potassium Engine • Liquid Glass • v" .. self.Version
    subtitle.TextColor3 = Theme.OnSurfaceVariant
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(26, 26)
    closeBtn.Position = UDim2.new(1, -38, 0, 12)
    closeBtn.BackgroundColor3 = Theme.SurfaceHigh
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Theme.OnSurfaceVariant
    closeBtn.Font = Enum.Font.GothamMedium
    closeBtn.TextSize = 11
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    MakeRounded(closeBtn, 8)
    MakeStroke(closeBtn, Theme.BorderSubtle, 0.85, 1)

    closeBtn.MouseButton1Click:Connect(function()
        self:ToggleUI()
    end)

    -- Divider
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, -32, 0, 1)
    div.Position = UDim2.fromOffset(16, 50)
    div.BackgroundColor3 = Theme.BorderSubtle
    div.BackgroundTransparency = Theme.BorderSubtleTrans
    div.BorderSizePixel = 0
    div.Parent = main

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 140, 1, -62)
    sidebar.Position = UDim2.fromOffset(14, 56)
    sidebar.BackgroundTransparency = 1
    sidebar.Parent = main

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 6)
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar

    -- Content Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -178, 1, -62)
    contentFrame.Position = UDim2.fromOffset(164, 56)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = main

    self.TabFrames = {}
    self.TabButtons = {}

    local tabs = {
        { id = "Combat", name = "Combat (Бой)", icon = "⚔" },
        { id = "Movement", name = "Movement", icon = "⚡" },
        { id = "Visuals", name = "Visuals (ESP)", icon = "👁" },
        { id = "Utility", name = "Utility & Kits", icon = "🍎" },
    }

    for i, t in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(1, 0, 0, 34)
        tabBtn.BackgroundColor3 = i == 1 and Theme.Primary or Theme.SurfaceHigh
        tabBtn.BackgroundTransparency = i == 1 and 0.2 or 0.6
        tabBtn.Text = "  " .. t.icon .. "  " .. t.name
        tabBtn.TextColor3 = i == 1 and Theme.OnPrimary or Theme.OnSurfaceVariant
        tabBtn.Font = Enum.Font.GothamMedium
        tabBtn.TextSize = 11
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = sidebar
        MakeRounded(tabBtn, 8)
        MakeStroke(tabBtn, Theme.BorderSubtle, 0.88, 1)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Theme.Primary
        page.CanvasSize = UDim2.fromScale(0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = (i == 1)
        page.Parent = contentFrame

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 4)
        pagePad.PaddingBottom = UDim.new(0, 10)
        pagePad.PaddingRight = UDim.new(0, 8)
        pagePad.Parent = page

        self.TabFrames[t.id] = page
        self.TabButtons[t.id] = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            for id, p in pairs(self.TabFrames) do
                p.Visible = (id == t.id)
            end
            for id, b in pairs(self.TabButtons) do
                local active = (id == t.id)
                b.BackgroundColor3 = active and Theme.Primary or Theme.SurfaceHigh
                b.BackgroundTransparency = active and 0.2 or 0.6
                b.TextColor3 = active and Theme.OnPrimary or Theme.OnSurfaceVariant
            end
        end)
    end

    self:PopulateCombatTab(self.TabFrames["Combat"])
    self:PopulateMovementTab(self.TabFrames["Movement"])
    self:PopulateVisualsTab(self.TabFrames["Visuals"])
    self:PopulateUtilityTab(self.TabFrames["Utility"])
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UI COMPONENTS: TOGGLE & SLIDER HELPERS
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:AddToggle(parent, labelText, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Theme.SurfaceContainer
    frame.BackgroundTransparency = Theme.SurfaceContainerTrans
    frame.BorderSizePixel = 0
    frame.Parent = parent
    MakeRounded(frame, 8)
    MakeStroke(frame, Theme.BorderSubtle, 0.90, 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -55, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.OnSurface
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.fromOffset(40, 20)
    switch.Position = UDim2.new(1, -48, 0.5, -10)
    switch.BackgroundColor3 = defaultVal and Theme.Primary or Theme.SurfaceHigh
    switch.BackgroundTransparency = defaultVal and 0.2 or 0.5
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = frame
    MakeRounded(switch, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = defaultVal and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Theme.OnSurface
    knob.BorderSizePixel = 0
    knob.Parent = switch
    MakeRounded(knob, 8)

    local state = defaultVal
    local function set(newState, skipCallback)
        state = newState
        TweenService:Create(switch, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Theme.Primary or Theme.SurfaceHigh,
            BackgroundTransparency = state and 0.2 or 0.5
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
        }):Play()
        if not skipCallback then
            callback(state)
        end
    end

    switch.MouseButton1Click:Connect(function()
        set(not state)
    end)

    return { Set = set }
end

function KitPvP:AddSlider(parent, labelText, minVal, maxVal, defaultVal, suffix, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.BackgroundColor3 = Theme.SurfaceContainer
    frame.BackgroundTransparency = Theme.SurfaceContainerTrans
    frame.BorderSizePixel = 0
    frame.Parent = parent
    MakeRounded(frame, 8)
    MakeStroke(frame, Theme.BorderSubtle, 0.90, 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 0, 22)
    label.Position = UDim2.fromOffset(12, 4)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.OnSurface
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.fromOffset(60, 22)
    valLabel.Position = UDim2.new(1, -68, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = string.format("%.1f%s", defaultVal, suffix or "")
    valLabel.TextColor3 = Theme.Primary
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 11
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = frame

    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size = UDim2.new(1, -24, 0, 5)
    sliderTrack.Position = UDim2.fromOffset(12, 32)
    sliderTrack.BackgroundColor3 = Theme.SurfaceHigh
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Parent = frame
    MakeRounded(sliderTrack, 3)

    local percent = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.fromScale(percent, 1)
    sliderFill.BackgroundColor3 = Theme.Primary
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack
    MakeRounded(sliderFill, 3)

    local sliding = false
    local function updateFromInput(input)
        local posX = math.clamp(input.Position.X - sliderTrack.AbsolutePosition.X, 0, sliderTrack.AbsoluteSize.X)
        local frac = posX / sliderTrack.AbsoluteSize.X
        local val = minVal + frac * (maxVal - minVal)
        val = math.floor(val * 10) / 10
        sliderFill.Size = UDim2.fromScale(frac, 1)
        valLabel.Text = string.format("%.1f%s", val, suffix or "")
        callback(val)
    end

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)
end

function KitPvP:AddButton(parent, labelText, btnText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Theme.SurfaceContainer
    frame.BackgroundTransparency = Theme.SurfaceContainerTrans
    frame.BorderSizePixel = 0
    frame.Parent = parent
    MakeRounded(frame, 8)
    MakeStroke(frame, Theme.BorderSubtle, 0.90, 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -110, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.OnSurface
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(90, 24)
    btn.Position = UDim2.new(1, -98, 0.5, -12)
    btn.BackgroundColor3 = Theme.Primary
    btn.BackgroundTransparency = 0.25
    btn.TextColor3 = Theme.OnPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Text = btnText
    btn.AutoButtonColor = false
    btn.Parent = frame
    MakeRounded(btn, 6)

    btn.MouseButton1Click:Connect(callback)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- POPULATE TABS
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:PopulateCombatTab(page)
    self:AddToggle(page, "KillAura (Авто-атака)", self.Config.KillAura, function(v)
        self.Config.KillAura = v
    end)

    self:AddSlider(page, "Aura Reach (Дистанция)", 3.0, 12.0, self.Config.AuraRange, " blocks", function(v)
        self.Config.AuraRange = v
    end)

    self:AddSlider(page, "Aura CPS (Скорость ударов)", 4, 20, self.Config.AuraCPS, " CPS", function(v)
        self.Config.AuraCPS = v
    end)

    self:AddToggle(page, "Silent Aim (Невидимый поворот)", self.Config.SilentAim, function(v)
        self.Config.SilentAim = v
    end)

    self:AddToggle(page, "Snap Aim (Поворот камеры)", self.Config.SnapAim, function(v)
        self.Config.SnapAim = v
    end)

    self:AddToggle(page, "Reach Expander (Радиус клика)", self.Config.Reach, function(v)
        self.Config.Reach = v
        CombatController.setReach(v and self.Config.CustomReach or OriginalReach)
    end)

    self:AddSlider(page, "Custom Reach (Блоки)", 3.0, 10.0, self.Config.CustomReach, " blocks", function(v)
        self.Config.CustomReach = v
        if self.Config.Reach then
            CombatController.setReach(v)
        end
    end)

    self:AddToggle(page, "Sprint Keep / NoSlow (Без замедления)", self.Config.NoSlow, function(v)
        self.Config.NoSlow = v
        self:ApplyNoSlowHook()
    end)

    self:AddToggle(page, "AutoClicker (При зажатии ЛКМ)", self.Config.AutoClicker, function(v)
        self.Config.AutoClicker = v
    end)

    self:AddSlider(page, "AutoClicker CPS", 6, 20, self.Config.AutoClickerCPS, " CPS", function(v)
        self.Config.AutoClickerCPS = v
    end)
end

function KitPvP:PopulateMovementTab(page)
    self:AddToggle(page, "Anti-Knockback (Velocity / Нулевая отдача)", self.Config.AntiKnockback, function(v)
        self.Config.AntiKnockback = v
    end)

    self:AddSlider(page, "Horizontal Knockback", 0, 100, self.Config.VelocityHorizontal, "%", function(v)
        self.Config.VelocityHorizontal = v
    end)

    self:AddSlider(page, "Vertical Knockback", 0, 100, self.Config.VelocityVertical, "%", function(v)
        self.Config.VelocityVertical = v
    end)

    self:AddToggle(page, "Auto Sprint (Постоянный бег)", self.Config.AutoSprint, function(v)
        self.Config.AutoSprint = v
    end)

    self:AddToggle(page, "Speed / Bhop Boost", self.Config.Speed, function(v)
        self.Config.Speed = v
    end)

    self:AddSlider(page, "Speed Multiplier", 1.0, 2.5, self.Config.SpeedMultiplier, "x", function(v)
        self.Config.SpeedMultiplier = v
    end)

    self.FlyToggleRef = self:AddToggle(page, "3D Flight (Полет) [Hotkey: F]", self.Config.Fly, function(v)
        self.Config.Fly = v
    end)

    self:AddSlider(page, "Flight Speed", 10, 80, self.Config.FlySpeed, "", function(v)
        self.Config.FlySpeed = v
    end)
end

function KitPvP:PopulateVisualsTab(page)
    self:AddToggle(page, "Player 2D Boxes (ESP)", self.Config.ESPBoxes, function(v)
        self.Config.ESPBoxes = v
    end)

    self:AddToggle(page, "Health Bars & HP (ESP)", self.Config.ESPHealth, function(v)
        self.Config.ESPHealth = v
    end)

    self:AddToggle(page, "Name & Distance Tags", self.Config.ESPNames, function(v)
        self.Config.ESPNames = v
    end)

    self:AddToggle(page, "Tracers (Трейсеры)", self.Config.ESPTracers, function(v)
        self.Config.ESPTracers = v
    end)

    self:AddToggle(page, "Chams / Acrylic Glow", self.Config.Chams, function(v)
        self.Config.Chams = v
        if not v then
            for _, hl in pairs(self.Highlights) do
                pcall(function() hl:Destroy() end)
            end
            self.Highlights = {}
        end
    end)
end

function KitPvP:PopulateUtilityTab(page)
    self:AddToggle(page, "Auto Golden Apple / Pot", self.Config.AutoEat, function(v)
        self.Config.AutoEat = v
    end)

    self:AddSlider(page, "AutoEat HP Threshold", 4, 18, self.Config.EatThreshold, " HP", function(v)
        self.Config.EatThreshold = v
    end)

    self:AddButton(page, "Select Hotbar Slot 1 (Sword)", "Slot 1", function()
        InventoryController.selectSlot(1)
    end)

    self:AddButton(page, "Select Hotbar Slot 2 (Apples/Pots)", "Slot 2", function()
        InventoryController.selectSlot(2)
    end)

    self:AddButton(page, "Unload Script (Полная выгрузка)", "UNLOAD", function()
        self:Unload()
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TOGGLE & UNLOAD LIFECYCLE
-- ─────────────────────────────────────────────────────────────────────────────
function KitPvP:ToggleUI()
    if not self.Main then return end
    self.Main.Visible = not self.Main.Visible
    if self.Shadow then
        self.Shadow.Visible = self.Main.Visible
    end
end

function KitPvP:Unload()
    -- Disconnect loops
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    -- Restore reach
    pcall(function()
        CombatController.setReach(OriginalReach)
    end)

    -- Restore NoSlow
    pcall(function()
        MovementController.applyAttackSlowdown = OriginalApplyAttackSlowdown
    end)

    -- Restore Velocity Signals
    self:UnhookVelocitySignals()

    -- Remove Highlights
    for _, hl in pairs(self.Highlights) do
        pcall(function() hl:Destroy() end)
    end
    self.Highlights = {}

    -- Remove ESP drawings
    for _, obj in pairs(self.ESPObjects) do
        self:DestroyESPObject(obj)
    end
    self.ESPObjects = {}

    -- Remove UI
    if self.ScreenGui then
        pcall(function() self.ScreenGui:Destroy() end)
        self.ScreenGui = nil
    end

    if getgenv and getgenv()._KitPvPInstance == self then
        getgenv()._KitPvPInstance = nil
    end

    print("[1.8 KIT PVP] Suite successfully unloaded.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- INITIALIZE & MOUNT
-- ─────────────────────────────────────────────────────────────────────────────
KitPvP:HookVelocitySignals()
KitPvP:ApplyNoSlowHook()
if KitPvP.Config.Reach then
    CombatController.setReach(KitPvP.Config.CustomReach)
end

KitPvP:BuildUI()
KitPvP:StartLoops()

if getgenv then
    getgenv()._KitPvPInstance = KitPvP
end

print(string.format("[1.8 KIT PVP] Suite v%s initialized! Menu: [RightShift] | Fly: [F]", KitPvP.Version))
return KitPvP
