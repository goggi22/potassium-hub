--[[
    ══════════════════════════════════════════════════════════════════════
    [🍀] TOWERS OF FORTUNE - FORTUNE HUB v2.8 (STREAMLINED EDITION)
    ══════════════════════════════════════════════════════════════════════
    Streamlined & Pure Architecture:
      • 100% Anti-Knockback: Weapons, Crits, Wind Charges, Explosions
      • InstaBreak: Instant block & lucky block destruction (0.02s)
      • Drop Vacuum / Auto-Loot: Sweeps nearby dropped items
      • Smart Dynamic Anti-Void: Safe recovery at Y < 45 (Lava Y = 4.3)
      • Engine 3D Flight: Developer Flying attribute bypass
      • Server Packet Kill Aura: Direct server attacks with crits
      • SafeWalk (EdgeGuard)
      • Player ESP & Chams: Health, distance, wallhack
      • Cmdr Developer Console: [F2]
      • Clean Unload System
    Toggle Menu: [RightShift] | Cmdr Console: [F2]
    ══════════════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Unload Handler
if getgenv().FortuneUnload then
    pcall(getgenv().FortuneUnload)
end
if Workspace.CurrentCamera:FindFirstChild("FortuneTracers") then
    pcall(function() Workspace.CurrentCamera.FortuneTracers:Destroy() end)
end

-- ──────────────────────────────────────────────────────────────────────
-- ENGINE RESOLUTION
-- ──────────────────────────────────────────────────────────────────────
local MCRemotes = ReplicatedStorage:WaitForChild("MCRemotes", 5)
local ActionRemote = MCRemotes and MCRemotes:FindFirstChild("Action")
local MotionRemote = MCRemotes and MCRemotes:FindFirstChild("Motion")
local CmdrClientMod = ReplicatedStorage:FindFirstChild("CmdrClient")
local CmdrClient = CmdrClientMod and require(CmdrClientMod)

local PoFClient = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PoFClient", 5)
local MovementMod = PoFClient and PoFClient:FindFirstChild("Movement") and require(PoFClient.Movement)
local SettingsMod = PoFClient and PoFClient:FindFirstChild("Settings") and require(PoFClient.Settings)

local MCFolder = ReplicatedStorage:FindFirstChild("MC")
local ConfigMod = MCFolder and MCFolder:FindFirstChild("Config") and require(MCFolder.Config)
local PhysicsMod = MCFolder and MCFolder:FindFirstChild("Physics") and require(MCFolder.Physics)

local SharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local PlayerPhysicsMod = SharedFolder and SharedFolder:FindFirstChild("Physics") and SharedFolder.Physics:FindFirstChild("PlayerPhysics") and require(SharedFolder.Physics.PlayerPhysics)

local BlocksMod = PoFClient and PoFClient:FindFirstChild("Blocks") and require(PoFClient.Blocks)
local HudMod = PoFClient and PoFClient:FindFirstChild("Hud") and require(PoFClient.Hud)
local TouchMod = PoFClient and PoFClient:FindFirstChild("Touch") and require(PoFClient.Touch)
local CollisionMod = MCFolder and MCFolder:FindFirstChild("Collision") and require(MCFolder.Collision)

local BLOCK = 3 -- 3 studs per Minecraft block

-- ──────────────────────────────────────────────────────────────────────
-- HUB CONFIGURATION
-- ──────────────────────────────────────────────────────────────────────
getgenv().FortuneConfig = getgenv().FortuneConfig or {
    AntiKnockback = true,
    PacketKillAura = false,
    BowAimbot = false,
    AuraRange = 20,
    AuraDelay = 0.15,

    AntiVoid = true,
    Fly = false,
    FlySpeed = 55,
    EdgeGuard = true,
    Scaffold = false,

    InstaBreak = true,
    ProjectileTracer = true,
    AutoLoot = false,
    LootRange = 25,
    PlayerESP = true,
}

local Config = getgenv().FortuneConfig
Config.AntiKnockback = (Config.AntiKnockback ~= false)
Config.AntiVoid = (Config.AntiVoid ~= false)
Config.InstaBreak = (Config.InstaBreak ~= false)
Config.EdgeGuard = (Config.EdgeGuard ~= false)
Config.ProjectileTracer = (Config.ProjectileTracer ~= false)
Config.AuraRange = Config.AuraRange or 20
Config.FlySpeed = Config.FlySpeed or 55
Config.LootRange = Config.LootRange or 25

local Connections = {}
local MotionQueueRef = nil
local EmergencyPlatform = nil
local LastSafeCFrame = nil
local LastAuraTick = 0
local LastLootTick = 0
local isVacuuming = false

local function trackConn(conn)
    table.insert(Connections, conn)
    return conn
end

-- ──────────────────────────────────────────────────────────────────────
-- 1. INSTABREAK (FAST MINING & PRE-DIG NUKER)
-- ──────────────────────────────────────────────────────────────────────
local LastHoveredCell = nil
local HoverStartTick = 0

local function setupInstaBreak()
    if ConfigMod and hookfunction then
        pcall(function()
            if ConfigMod.breakTime and not ConfigMod._FortuneBreakHooked then
                ConfigMod._FortuneBreakHooked = true
                local oldBreak
                oldBreak = hookfunction(ConfigMod.breakTime, function(blockId, tool)
                    if Config.InstaBreak then
                        local normalTime = oldBreak(blockId, tool)
                        -- The server rejects breaks under ~0.28-0.30s (server anti-cheat)
                        -- math.max(0.28, normalTime * 0.5) hits the maximum safe server speed limit
                        return math.max(0.28, normalTime * 0.5)
                    end
                    return oldBreak(blockId, tool)
                end)
            end
        end)
    end

    -- Pre-Dig / Hover Nuker:
    -- When crosshair points at a breakable block, send 'dig' immediately in background.
    -- Once hovered for >= 0.28s, clicking breaks it in exactly 1 frame!
    trackConn(RunService.Heartbeat:Connect(function()
        if not Config.InstaBreak then return end
        if not BlocksMod then return end
        local target = BlocksMod.target
        if target and target.cell and target.part and target.part:GetAttribute("Breakable") == true then
            local cell = target.cell
            if cell ~= LastHoveredCell then
                LastHoveredCell = cell
                HoverStartTick = os.clock()
                pcall(function()
                    if ActionRemote then
                        ActionRemote:FireServer("dig", cell)
                    end
                end)
            end
        else
            LastHoveredCell = nil
        end
    end))

    -- 1-Frame Click Break:
    trackConn(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.InstaBreak and BlocksMod then
            local target = BlocksMod.target
            if target and target.cell and target.part and target.part:GetAttribute("Breakable") == true then
                local cell = target.cell
                if os.clock() - HoverStartTick >= 0.28 then
                    pcall(function()
                        if ActionRemote then
                            ActionRemote:FireServer("break", cell)
                        end
                        if BlocksMod.finishDig then
                            BlocksMod.finishDig(target.part, cell)
                        end
                    end)
                end
            end
        end
    end))
end

-- ──────────────────────────────────────────────────────────────────────
-- 2. DROP VACUUM / AUTO-LOOT
-- ──────────────────────────────────────────────────────────────────────
local function setupAutoLoot()
    trackConn(RunService.Heartbeat:Connect(function()
        if not Config.AutoLoot or isVacuuming then return end
        if os.clock() - LastLootTick < 0.35 then return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local dropsFolder = Workspace:FindFirstChild("Drops")
        if not dropsFolder or #dropsFolder:GetChildren() == 0 then return end

        local myPos = root.Position
        local targetDrop = nil
        local closestDist = Config.LootRange

        for _, drop in ipairs(dropsFolder:GetChildren()) do
            if drop:IsA("BasePart") then
                local dist = (drop.Position - myPos).Magnitude
                if dist <= closestDist then
                    closestDist = dist
                    targetDrop = drop
                end
            end
        end

        if targetDrop and targetDrop.Parent then
            isVacuuming = true
            LastLootTick = os.clock()

            local savedCF = root.CFrame
            local dropPos = targetDrop.Position + Vector3.new(0, 1.2, 0)

            root.CFrame = CFrame.new(dropPos)
            if MovementMod and MovementMod.teleportLocal then
                pcall(function()
                    MovementMod.teleportLocal(
                        math.floor(dropPos.X / BLOCK),
                        math.floor(dropPos.Y / BLOCK),
                        math.floor(dropPos.Z / BLOCK)
                    )
                end)
            end

            task.delay(0.12, function()
                if root and root.Parent then
                    root.CFrame = savedCF
                    if MovementMod and MovementMod.teleportLocal then
                        pcall(function()
                            MovementMod.teleportLocal(
                                math.floor(savedCF.Position.X / BLOCK),
                                math.floor(savedCF.Position.Y / BLOCK),
                                math.floor(savedCF.Position.Z / BLOCK)
                            )
                        end)
                    end
                end
                isVacuuming = false
            end)
        end
    end))
end

-- ──────────────────────────────────────────────────────────────────────
-- 3. COMPLETE ANTI-KNOCKBACK
-- ──────────────────────────────────────────────────────────────────────
local function setupAntiKnockback()
    if MotionRemote and getconnections then
        pcall(function()
            local conns = getconnections(MotionRemote.OnClientEvent)
            for _, c in ipairs(conns) do
                if c.Function then
                    local ups = getupvalues(c.Function)
                    for idx, val in pairs(ups) do
                        if type(val) == "table" and idx == 3 then
                            MotionQueueRef = val
                            break
                        end
                    end
                end
            end
        end)
    end

    if PlayerPhysicsMod and hookfunction then
        pcall(function()
            if PlayerPhysicsMod.addMotion and not PlayerPhysicsMod._FortuneAddHooked then
                PlayerPhysicsMod._FortuneAddHooked = true
                local oldAdd
                oldAdd = hookfunction(PlayerPhysicsMod.addMotion, function(state, motionVec)
                    if Config.AntiKnockback then return end
                    return oldAdd(state, motionVec)
                end)
            end
        end)
    end

    if PhysicsMod and hookfunction then
        pcall(function()
            if PhysicsMod.knockback and not PhysicsMod._FortuneKbHooked then
                PhysicsMod._FortuneKbHooked = true
                local oldKb
                oldKb = hookfunction(PhysicsMod.knockback, function(curMotion, onGround, p20, p21, p22, p23)
                    if Config.AntiKnockback then return curMotion end
                    return oldKb(curMotion, onGround, p20, p21, p22, p23)
                end)
            end

            if PhysicsMod.explosionPush and not PhysicsMod._FortuneExpHooked then
                PhysicsMod._FortuneExpHooked = true
                local oldPush
                oldPush = hookfunction(PhysicsMod.explosionPush, function(pos, entPos, mot, ...)
                    if Config.AntiKnockback then return mot end
                    return oldPush(pos, entPos, mot, ...)
                end)
            end

            if PhysicsMod.smashKnockback and not PhysicsMod._FortuneSmashHooked then
                PhysicsMod._FortuneSmashHooked = true
                local oldSmash
                oldSmash = hookfunction(PhysicsMod.smashKnockback, function(mot, ...)
                    if Config.AntiKnockback then return mot end
                    return oldSmash(mot, ...)
                end)
            end
        end)
    end

    trackConn(RunService.Heartbeat:Connect(function()
        if not Config.AntiKnockback then return end

        if MotionQueueRef and type(MotionQueueRef) == "table" and #MotionQueueRef > 0 then
            table.clear(MotionQueueRef)
        end

        if not Config.Fly and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local vel = root.AssemblyLinearVelocity
                if math.abs(vel.X) > 35 or math.abs(vel.Z) > 35 or vel.Y > 40 then
                    root.AssemblyLinearVelocity = Vector3.new(
                        math.clamp(vel.X, -22, 22),
                        math.clamp(vel.Y, -25, 12),
                        math.clamp(vel.Z, -22, 22)
                    )
                end
            end
        end
    end))
end

-- ──────────────────────────────────────────────────────────────────────
-- 4. SMART DYNAMIC ANTI-VOID
-- ──────────────────────────────────────────────────────────────────────
local function recoverPlayer()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local targetCF = LastSafeCFrame or CFrame.new(0, 95, 0)

    if not EmergencyPlatform or not EmergencyPlatform.Parent then
        EmergencyPlatform = Instance.new("Part")
        EmergencyPlatform.Name = "FortuneAntiVoidPad"
        EmergencyPlatform.Size = Vector3.new(12, 1, 12)
        EmergencyPlatform.Transparency = 1
        EmergencyPlatform.Anchored = true
        EmergencyPlatform.CanCollide = true
        EmergencyPlatform.Parent = Workspace
    end
    EmergencyPlatform.CFrame = targetCF * CFrame.new(0, -2.5, 0)

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = targetCF * CFrame.new(0, 3, 0)

    if MovementMod and MovementMod.teleportLocal then
        pcall(function()
            local bx = math.floor(targetCF.Position.X / BLOCK)
            local by = math.floor((targetCF.Position.Y + 3) / BLOCK)
            local bz = math.floor(targetCF.Position.Z / BLOCK)
            MovementMod.teleportLocal(bx, by, bz)
        end)
    end

    task.delay(1.5, function()
        if EmergencyPlatform and EmergencyPlatform.Parent then
            EmergencyPlatform:Destroy()
            EmergencyPlatform = nil
        end
    end)
end

local function setupAntiVoid()
    trackConn(RunService.Heartbeat:Connect(function()
        if not Config.AntiVoid then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return end

        local curY = root.Position.Y

        if curY > 55 and hum.FloorMaterial ~= Enum.Material.Air then
            LastSafeCFrame = root.CFrame
        end

        -- Safe trigger height 45 (Lava begins at 4.3)
        if curY < 45 then
            recoverPlayer()
        end
    end))
end

-- ──────────────────────────────────────────────────────────────────────
-- 5. NATIVE 3D FLIGHT
-- ──────────────────────────────────────────────────────────────────────
local flyConn = nil
local function toggleFlight(enable)
    Config.Fly = enable
    LocalPlayer:SetAttribute("Flying", enable)

    if flyConn then
        flyConn:Disconnect()
        flyConn = nil
    end

    if enable then
        flyConn = RunService.RenderStepped:Connect(function(dt)
            if not Config.Fly then return end
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

            if moveDir.Magnitude > 0 then
                root.AssemblyLinearVelocity = moveDir.Unit * Config.FlySpeed
            else
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end)
        trackConn(flyConn)
    else
        LocalPlayer:SetAttribute("Flying", false)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- 6. SERVER PACKET KILL AURA (WITH AUTOMATIC CRITICALS)
-- ──────────────────────────────────────────────────────────────────────
local function setupPacketKillAura()
    trackConn(RunService.Heartbeat:Connect(function()
        if not Config.PacketKillAura or not ActionRemote then return end
        if os.clock() - LastAuraTick < Config.AuraDelay then return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local myPos = root.Position
        local targetChar = nil
        local closestDist = Config.AuraRange

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local enemyHum = player.Character:FindFirstChildOfClass("Humanoid")
                local eid = player.Character:GetAttribute("Eid")

                if enemyRoot and enemyHum and enemyHum.Health > 0 and eid then
                    local dist = (enemyRoot.Position - myPos).Magnitude
                    if dist <= closestDist then
                        closestDist = dist
                        targetChar = player.Character
                    end
                end
            end
        end

        if targetChar then
            local eid = targetChar:GetAttribute("Eid")
            local enemyRoot = targetChar:FindFirstChild("HumanoidRootPart")
            if eid and enemyRoot then
                local attackDir = (enemyRoot.Position - myPos).Unit
                ActionRemote:FireServer("attack", eid, attackDir, true)
                LastAuraTick = os.clock()
            end
        end
    end))
end

-- ──────────────────────────────────────────────────────────────────────
-- 7. AUTO-PARKOUR (DAILY LOBBY CLAIM)
-- ──────────────────────────────────────────────────────────────────────
local function runAutoParkour()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local origCF = root.CFrame
    local startPadPos = Vector3.new(-52.5, 89.5, 55.5)
    local finishPadPos = Vector3.new(55.5, 149.5, 49.5)

    root.CFrame = CFrame.new(startPadPos)
    if MovementMod and MovementMod.teleportLocal then
        pcall(function()
            MovementMod.teleportLocal(
                math.floor(startPadPos.X / BLOCK),
                math.floor(startPadPos.Y / BLOCK),
                math.floor(startPadPos.Z / BLOCK)
            )
        end)
    end

    task.wait(0.6)
    root.CFrame = CFrame.new(finishPadPos)
    if MovementMod and MovementMod.teleportLocal then
        pcall(function()
            MovementMod.teleportLocal(
                math.floor(finishPadPos.X / BLOCK),
                math.floor(finishPadPos.Y / BLOCK),
                math.floor(finishPadPos.Z / BLOCK)
            )
        end)
    end

    task.wait(0.6)
    root.CFrame = origCF
end

-- ──────────────────────────────────────────────────────────────────────
-- 8. CMDR DEVELOPER CONSOLE INTEGRATION
-- ──────────────────────────────────────────────────────────────────────
local function setupCmdrConsole()
    if CmdrClient then
        pcall(function()
            CmdrClient:SetEnabled(true)
            CmdrClient:SetActivationKeys({ Enum.KeyCode.F2 })
            CmdrClient:SetActivationUnlocksMouse(true)
        end)
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- 9. EDGEGUARD (SAFEWALK)
-- ──────────────────────────────────────────────────────────────────────
local function syncSettingsHooks()
    if SettingsMod and SettingsMod.data then
        SettingsMod.data.edgeGuard = Config.EdgeGuard
    end
end

trackConn(RunService.Heartbeat:Connect(syncSettingsHooks))

-- ──────────────────────────────────────────────────────────────────────
-- 10. FULL PLAYER ESP & CHAMS
-- ──────────────────────────────────────────────────────────────────────
local function applyESP(player)
    if player == LocalPlayer then return end

    local function onChar(char)
        task.wait(0.2)
        if not char:IsDescendantOf(Workspace) then return end

        local hl = char:FindFirstChild("FortuneHighlight") or Instance.new("Highlight")
        hl.Name = "FortuneHighlight"
        hl.FillColor = Color3.fromRGB(240, 70, 70)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0.1
        hl.Enabled = Config.PlayerESP
        hl.Parent = char

        local head = char:WaitForChild("Head", 5)
        if head then
            local bb = head:FindFirstChild("FortuneBillboard") or Instance.new("BillboardGui")
            bb.Name = "FortuneBillboard"
            bb.Size = UDim2.new(0, 160, 0, 46)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true
            bb.Enabled = Config.PlayerESP
            bb.Parent = head

            local nameLbl = bb:FindFirstChild("NameLbl") or Instance.new("TextLabel")
            nameLbl.Name = "NameLbl"
            nameLbl.Size = UDim2.new(1, 0, 0, 16)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 12
            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLbl.TextStrokeTransparency = 0.2
            nameLbl.Text = player.DisplayName
            nameLbl.Parent = bb

            local infoLbl = bb:FindFirstChild("InfoLbl") or Instance.new("TextLabel")
            infoLbl.Name = "InfoLbl"
            infoLbl.Size = UDim2.new(1, 0, 0, 14)
            infoLbl.Position = UDim2.new(0, 0, 0, 16)
            infoLbl.BackgroundTransparency = 1
            infoLbl.Font = Enum.Font.GothamMedium
            infoLbl.TextSize = 11
            infoLbl.TextColor3 = Color3.fromRGB(0, 230, 153)
            infoLbl.TextStrokeTransparency = 0.2
            infoLbl.Text = "HP: 100% | 0m"
            infoLbl.Parent = bb
        end
    end

    if player.Character then onChar(player.Character) end
    trackConn(player.CharacterAdded:Connect(onChar))
end

for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
trackConn(Players.PlayerAdded:Connect(applyESP))

trackConn(RunService.RenderStepped:Connect(function()
    if not Config.PlayerESP then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local root = p.Character:FindFirstChild("HumanoidRootPart")

            if head then
                local bb = head:FindFirstChild("FortuneBillboard")
                if bb then
                    local infoLbl = bb:FindFirstChild("InfoLbl")
                    if infoLbl and myRoot and root and hum then
                        local dist = math.floor((root.Position - myRoot.Position).Magnitude)
                        local hp = math.floor(hum.Health)
                        infoLbl.Text = string.format("HP: %d | %dm", hp, dist)
                    end
                end
            end
        end
    end
end))

-- ──────────────────────────────────────────────────────────────────────
-- 11. CLEAN UNLOAD IMPLEMENTATION
-- ──────────────────────────────────────────────────────────────────────
local ScreenGui = nil

local function unloadHub()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)

    Config.Fly = false
    Config.PacketKillAura = false
    Config.AntiKnockback = false
    Config.AutoLoot = false
    LocalPlayer:SetAttribute("Flying", false)

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("FortuneHighlight")
            if hl then hl:Destroy() end
            local head = p.Character:FindFirstChild("Head")
            if head then
                local bb = head:FindFirstChild("FortuneBillboard")
                if bb then bb:Destroy() end
            end
        end
    end

    if EmergencyPlatform and EmergencyPlatform.Parent then
        EmergencyPlatform:Destroy()
        EmergencyPlatform = nil
    end

    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
        ScreenGui = nil
    end

    getgenv().FortuneUnload = nil
end

getgenv().FortuneUnload = unloadHub

-- ──────────────────────────────────────────────────────────────────────
-- ──────────────────────────────────────────────────────────────────────
-- 8. SCAFFOLD (TRUE AUTO-BRIDGE)
-- ──────────────────────────────────────────────────────────────────────
local LastScaffoldPlaceTick = 0

local function getPlaceableBlockSlot()
    local hudState = HudMod and HudMod.state
    if not hudState or not hudState.inv then return nil end
    for slot = 1, 9 do
        local item = hudState.inv[slot]
        if item and item.id then
            local def = ConfigMod and ConfigMod.Items and ConfigMod.Items[item.id]
            if def and def.kind == "block" and not def.passable and not def.web then
                return slot, item.id
            end
        end
    end
    return nil
end

local function setupScaffold()
    trackConn(RunService.Heartbeat:Connect(function()
        if not Config.Scaffold then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if os.clock() - LastScaffoldPlaceTick < 0.04 then return end

        local vel = root.AssemblyLinearVelocity
        local flatVel = Vector3.new(vel.X, 0, vel.Z)
        local isMoving = (flatVel.Magnitude > 0.3)
        local moveDir = isMoving and flatVel.Unit or Vector3.new(0, 0, 0)

        local isSpaceDown = UserInputService:IsKeyDown(Enum.KeyCode.Space)
        local feetPos = root.Position - Vector3.new(0, 2.6, 0)
        
        -- Lead ahead in direction of movement
        local lead = isMoving and (moveDir * 1.5) or Vector3.new(0, 0, 0)
        local targetPos = feetPos + lead

        local cellX = math.floor(targetPos.X / BLOCK)
        local cellY = math.floor((feetPos.Y - 0.2) / BLOCK)
        local cellZ = math.floor(targetPos.Z / BLOCK)

        if isSpaceDown then
            -- Tower up mode
            cellY = math.floor((feetPos.Y + 0.5) / BLOCK) - 1
            root.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y, 28), vel.Z)
        end

        local targetCell = Vector3.new(cellX, cellY, cellZ)

        local isSolid = false
        if CollisionMod and CollisionMod.cellSolid then
            isSolid = CollisionMod.cellSolid(cellX, cellY, cellZ)
        end

        if not isSolid then
            local slot, blockId = getPlaceableBlockSlot()
            if slot or (BlocksMod and BlocksMod.placeCell) then
                LastScaffoldPlaceTick = os.clock()
                pcall(function()
                    local feet = MovementMod and MovementMod.feet and MovementMod.feet() or (root.Position / BLOCK)
                    if ActionRemote then
                        ActionRemote:FireServer("place", targetCell, feet)
                    end
                    if BlocksMod and BlocksMod.placeCell then
                        BlocksMod.placeCell(targetCell)
                    end
                end)
            end
        end
    end))
end

-- ──────────────────────────────────────────────────────────────────────
-- 9. BOW & PROJECTILE AIMBOT
-- ──────────────────────────────────────────────────────────────────────
local function getBestAimbotTarget(maxDist)
    maxDist = maxDist or 150
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local cam = Workspace.CurrentCamera
    local camPos = cam.CFrame.Position
    local camLook = cam.CFrame.LookVector

    local bestTarget = nil
    local bestScore = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local tRoot = p.Character.HumanoidRootPart
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if (not hum or hum.Health > 0) and p.Character:GetAttribute("Dead") ~= true then
                local delta = tRoot.Position - camPos
                local dist = delta.Magnitude
                if dist <= maxDist and dist > 2 then
                    local dir = delta.Unit
                    local dot = camLook:Dot(dir)
                    if dot > 0.15 then
                        local score = dist * (1.5 - dot)
                        if score < bestScore then
                            bestScore = score
                            bestTarget = p.Character
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

local function solveBallisticAim(targetChar, projKind)
    local cam = Workspace.CurrentCamera
    local eye = cam.CFrame.Position
    local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return nil end

    local targetPos = tRoot.Position + Vector3.new(0, 0.5, 0)
    local targetVel = tRoot.AssemblyLinearVelocity

    -- Physics properties for projectile
    local speed = 25 * BLOCK -- arrow default ~75 studs/s
    local g = 0.05 * BLOCK   -- 0.15 studs/tick^2
    if projKind == "wind_charge" then
        speed = 36 * BLOCK   -- ~108 studs/s
        g = 0
    elseif projKind == "ender_pearl" or projKind == "snowball" or projKind == "egg" then
        speed = 15 * BLOCK   -- ~45 studs/s
        g = 0.03 * BLOCK
    end

    local delta = targetPos - eye
    local dist = delta.Magnitude
    local timeOfFlight = dist / speed

    -- Predict target movement
    local predictedPos = targetPos + (Vector3.new(targetVel.X, 0, targetVel.Z) * timeOfFlight)

    -- Compensate for gravity drop
    local drop = 0.5 * g * (timeOfFlight * 20)^2 * 0.0025
    local aimTarget = predictedPos + Vector3.new(0, drop, 0)

    return (aimTarget - eye).Unit
end

local function setupProjectileAimbot()
    if ActionRemote and hookfunction then
        pcall(function()
            if not ActionRemote._FortuneAimHooked then
                ActionRemote._FortuneAimHooked = true
                local oldFireServer
                oldFireServer = hookfunction(ActionRemote.FireServer, function(self, action, arg1, arg2, arg3)
                    if Config.BowAimbot and self == ActionRemote then
                        if action == "useStop" and typeof(arg1) == "Vector3" then
                            -- Bow release
                            local target = getBestAimbotTarget(160)
                            if target then
                                local solvedDir = solveBallisticAim(target, "arrow")
                                if solvedDir then
                                    arg1 = solvedDir
                                end
                            end
                        elseif action == "use" and typeof(arg1) == "Vector3" then
                            -- Wind Charge, Pearl, Snowball
                            local hudState = HudMod and HudMod.state
                            local heldId = hudState and hudState.inv and hudState.selected and hudState.inv[hudState.selected] and hudState.inv[hudState.selected].id
                            if heldId == "wind_charge" or heldId == "ender_pearl" or heldId == "snowball" or heldId == "egg" then
                                local target = getBestAimbotTarget(130)
                                if target then
                                    local solvedDir = solveBallisticAim(target, heldId)
                                    if solvedDir then
                                        arg1 = solvedDir
                                    end
                                end
                            end
                        end
                    end
                    return oldFireServer(self, action, arg1, arg2, arg3)
                end)
            end
        end)
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- 10. PROJECTILE TRAJECTORY TRACER (PEARL / CHARGE / BOW)
-- ──────────────────────────────────────────────────────────────────────
local TracerFolder = nil

local function getTracerFolder()
    if not TracerFolder or not TracerFolder.Parent then
        TracerFolder = Instance.new("Folder")
        TracerFolder.Name = "FortuneTracers"
        TracerFolder.Parent = Workspace.CurrentCamera
    end
    return TracerFolder
end

local function clearTracers()
    if TracerFolder and TracerFolder.Parent then
        TracerFolder:ClearAllChildren()
    end
end

local function drawTracerPath(points, hitPos, hitNormal, color)
    local folder = getTracerFolder()
    folder:ClearAllChildren()

    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i+1]
        local dist = (p2 - p1).Magnitude
        if dist > 0.05 then
            local seg = Instance.new("Part")
            seg.Name = "ArcSeg"
            seg.Anchored = true
            seg.CanCollide = false
            seg.CanQuery = false
            seg.CanTouch = false
            seg.Material = Enum.Material.Neon
            seg.Color = color
            seg.Size = Vector3.new(0.08, 0.08, dist)
            seg.CFrame = CFrame.lookAt(p1:Lerp(p2, 0.5), p2)
            seg.Parent = folder
        end
    end

    if hitPos then
        local marker = Instance.new("Part")
        marker.Name = "ImpactMarker"
        marker.Anchored = true
        marker.CanCollide = false
        marker.CanQuery = false
        marker.CanTouch = false
        marker.Shape = Enum.PartType.Cylinder
        marker.Material = Enum.Material.Neon
        marker.Color = color
        marker.Size = Vector3.new(0.08, 1.8, 1.8)
        local normal = hitNormal or Vector3.new(0, 1, 0)
        marker.CFrame = CFrame.lookAt(hitPos + normal * 0.05, hitPos + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
        marker.Parent = folder
    end
end

local function setupProjectileTracer()
    trackConn(RunService.RenderStepped:Connect(function()
        if not Config.ProjectileTracer then
            clearTracers()
            return
        end

        local hudState = HudMod and HudMod.state
        if not hudState or not hudState.inv or not hudState.selected then
            clearTracers()
            return
        end

        local slotItem = hudState.inv[hudState.selected]
        if not slotItem or not slotItem.id then
            clearTracers()
            return
        end

        local id = slotItem.id
        local itemDef = ConfigMod and ConfigMod.Items and ConfigMod.Items[id]

        local isProjectile = false
        local projKind = nil
        local speed = 15 * BLOCK
        local g = 0.03 * BLOCK
        local drag = 0.99
        local color = Color3.fromRGB(180, 80, 255) -- Purple for Pearl

        if id == "ender_pearl" or id == "pearl" then
            isProjectile = true
            projKind = "pearl"
            speed = 15 * BLOCK
            g = 0.03 * BLOCK
            color = Color3.fromRGB(190, 80, 255)
        elseif id == "wind_charge" then
            isProjectile = true
            projKind = "wind_charge"
            speed = 36 * BLOCK
            g = 0
            drag = 1.0
            color = Color3.fromRGB(80, 220, 255)
        elseif itemDef and itemDef.kind == "bow" then
            isProjectile = true
            projKind = "bow"
            speed = 25 * BLOCK
            g = 0.05 * BLOCK
            color = Color3.fromRGB(255, 215, 0)
        elseif id == "snowball" or id == "egg" then
            isProjectile = true
            projKind = "snowball"
            speed = 15 * BLOCK
            g = 0.03 * BLOCK
            color = Color3.fromRGB(240, 240, 255)
        end

        if not isProjectile then
            clearTracers()
            return
        end

        local cam = Workspace.CurrentCamera
        local origin = cam.CFrame.Position
        local look = cam.CFrame.LookVector
        local vel = look * speed

        local points = { origin }
        local cur = origin
        local hitPos, hitNormal = nil, nil

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local exclude = { getTracerFolder() }
        if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
        rayParams.FilterDescendantsInstances = exclude

        for step = 1, 35 do
            local t = step * 0.7
            local nextPos
            if drag >= 0.9999 then
                nextPos = origin + vel * (t * 0.05) - Vector3.new(0, g, 0) * ((t * (t - 1)) / 2 * 0.05)
            else
                local S = (1 - (drag ^ t)) / (1 - drag)
                nextPos = origin + vel * (S * 0.05) - Vector3.new(0, g, 0) * (((t - S) / (1 - drag)) * 0.05)
            end

            local ray = Workspace:Raycast(cur, nextPos - cur, rayParams)
            if ray then
                table.insert(points, ray.Position)
                hitPos = ray.Position
                hitNormal = ray.Normal
                break
            else
                table.insert(points, nextPos)
                cur = nextPos
            end
        end

        drawTracerPath(points, hitPos, hitNormal, color)
    end))
end

-- 12. STREAMLINED OBSIDIAN GUI (3 CRISP TABS)
-- ──────────────────────────────────────────────────────────────────────
local GUI_NAME = "FortuneEngineHub"

pcall(function()
    if gethui then
        local old = gethui():FindFirstChild(GUI_NAME)
        if old then old:Destroy() end
    elseif game:GetService("CoreGui"):FindFirstChild(GUI_NAME) then
        game:GetService("CoreGui")[GUI_NAME]:Destroy()
    end
    if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(GUI_NAME) then
        LocalPlayer.PlayerGui[GUI_NAME]:Destroy()
    end
end)

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false

pcall(function()
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game:GetService("CoreGui")
    else
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 540, 0, 380)
MainFrame.Position = UDim2.new(0.5, -270, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(38, 43, 58)
MainStroke.Thickness = 1.4
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = MainFrame

local AccentLine = Instance.new("Frame")
AccentLine.Name = "AccentLine"
AccentLine.Size = UDim2.new(1, 0, 0, 2)
AccentLine.BackgroundColor3 = Color3.fromRGB(0, 230, 153)
AccentLine.BorderSizePixel = 0
AccentLine.Parent = MainFrame

local AccentGradient = Instance.new("UIGradient")
AccentGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 153)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 230, 153)),
})
AccentGradient.Parent = AccentLine

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Color3.fromRGB(19, 22, 30)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderStroke = Instance.new("UIStroke")
HeaderStroke.Color = Color3.fromRGB(30, 34, 46)
HeaderStroke.Thickness = 1
HeaderStroke.Parent = Header

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(0, 24, 0, 24)
LogoIcon.Position = UDim2.new(0, 16, 0.5, -12)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "🍀"
LogoIcon.TextSize = 18
LogoIcon.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 160, 0, 24)
TitleLabel.Position = UDim2.new(0, 46, 0.5, -12)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "FORTUNE HUB"
TitleLabel.TextColor3 = Color3.fromRGB(245, 247, 250)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local VersionBadge = Instance.new("Frame")
VersionBadge.Size = UDim2.new(0, 36, 0, 18)
VersionBadge.Position = UDim2.new(0, 164, 0.5, -9)
VersionBadge.BackgroundColor3 = Color3.fromRGB(25, 40, 35)
VersionBadge.BorderSizePixel = 0
VersionBadge.Parent = Header

local VBCorner = Instance.new("UICorner")
VBCorner.CornerRadius = UDim.new(0, 4)
VBCorner.Parent = VersionBadge

local VBLabel = Instance.new("TextLabel")
VBLabel.Size = UDim2.new(1, 0, 1, 0)
VBLabel.BackgroundTransparency = 1
VBLabel.Text = "v2.8"
VBLabel.TextColor3 = Color3.fromRGB(0, 230, 153)
VBLabel.Font = Enum.Font.GothamBold
VBLabel.TextSize = 10
VBLabel.Parent = VersionBadge

-- Unload Button in Header
local UnloadHeaderBtn = Instance.new("TextButton")
UnloadHeaderBtn.Size = UDim2.new(0, 68, 0, 22)
UnloadHeaderBtn.Position = UDim2.new(1, -240, 0.5, -11)
UnloadHeaderBtn.BackgroundColor3 = Color3.fromRGB(45, 24, 28)
UnloadHeaderBtn.BorderSizePixel = 0
UnloadHeaderBtn.Text = "Unload"
UnloadHeaderBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
UnloadHeaderBtn.Font = Enum.Font.GothamBold
UnloadHeaderBtn.TextSize = 11
UnloadHeaderBtn.AutoButtonColor = false
UnloadHeaderBtn.Parent = Header

local UHBStroke = Instance.new("UIStroke")
UHBStroke.Color = Color3.fromRGB(150, 40, 40)
UHBStroke.Thickness = 1
UHBStroke.Parent = UnloadHeaderBtn

local UHBCorner = Instance.new("UICorner")
UHBCorner.CornerRadius = UDim.new(0, 6)
UHBCorner.Parent = UnloadHeaderBtn

UnloadHeaderBtn.MouseButton1Click:Connect(unloadHub)

local KeybindBadge = Instance.new("Frame")
KeybindBadge.Size = UDim2.new(0, 84, 0, 22)
KeybindBadge.Position = UDim2.new(1, -160, 0.5, -11)
KeybindBadge.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
KeybindBadge.BorderSizePixel = 0
KeybindBadge.Parent = Header

local KBCorner = Instance.new("UICorner")
KBCorner.CornerRadius = UDim.new(0, 6)
KBCorner.Parent = KeybindBadge

local KBLabel = Instance.new("TextLabel")
KBLabel.Size = UDim2.new(1, 0, 1, 0)
KBLabel.BackgroundTransparency = 1
KBLabel.Text = "[RightShift]"
KBLabel.TextColor3 = Color3.fromRGB(150, 158, 175)
KBLabel.Font = Enum.Font.GothamMedium
KBLabel.TextSize = 11
KBLabel.Parent = KeybindBadge

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(180, 188, 205)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.AutoButtonColor = false
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 25, 28)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = isMinimized and UDim2.new(0, 540, 0, 48) or UDim2.new(0, 540, 0, 380)
    }):Play()
end)

-- Dragging Mechanics
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

trackConn(UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end))

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 140, 1, -48)
Sidebar.Position = UDim2.new(0, 0, 0, 48)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarStroke = Instance.new("UIStroke")
SidebarStroke.Color = Color3.fromRGB(30, 34, 46)
SidebarStroke.Thickness = 1
SidebarStroke.Parent = Sidebar

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 14)
SidebarPadding.PaddingLeft = UDim.new(0, 8)
SidebarPadding.PaddingRight = UDim.new(0, 8)
SidebarPadding.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -140, 1, -48)
ContentArea.Position = UDim2.new(0, 140, 0, 48)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame

local Tabs = {}
local TabButtons = {}

local function createTab(tabId, tabName, tabIcon)
    local page = Instance.new("ScrollingFrame")
    page.Name = tabId .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(55, 60, 80)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = ContentArea

    local pageList = Instance.new("UIListLayout")
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Padding = UDim.new(0, 8)
    pageList.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingTop = UDim.new(0, 12)
    pagePad.PaddingBottom = UDim.new(0, 12)
    pagePad.PaddingLeft = UDim.new(0, 14)
    pagePad.PaddingRight = UDim.new(0, 14)
    pagePad.Parent = page

    Tabs[tabId] = page

    local btn = Instance.new("TextButton")
    btn.Name = tabId .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local activeBar = Instance.new("Frame")
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(0, 3, 0.6, 0)
    activeBar.Position = UDim2.new(0, 0, 0.2, 0)
    activeBar.BackgroundColor3 = Color3.fromRGB(0, 230, 153)
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.Parent = btn

    local activeBarCorner = Instance.new("UICorner")
    activeBarCorner.CornerRadius = UDim.new(1, 0)
    activeBarCorner.Parent = activeBar

    local btnLabel = Instance.new("TextLabel")
    btnLabel.Name = "BtnLabel"
    btnLabel.Size = UDim2.new(1, -20, 1, 0)
    btnLabel.Position = UDim2.new(0, 16, 0, 0)
    btnLabel.BackgroundTransparency = 1
    btnLabel.Text = tabIcon .. "  " .. tabName
    btnLabel.TextColor3 = Color3.fromRGB(150, 158, 175)
    btnLabel.Font = Enum.Font.GothamMedium
    btnLabel.TextSize = 13
    btnLabel.TextXAlignment = Enum.TextXAlignment.Left
    btnLabel.Parent = btn

    TabButtons[tabId] = { Button = btn, Label = btnLabel, Bar = activeBar }

    btn.MouseButton1Click:Connect(function()
        for id, tPage in pairs(Tabs) do
            tPage.Visible = (id == tabId)
            local tData = TabButtons[id]
            if tData then
                local isActive = (id == tabId)
                tData.Bar.Visible = isActive
                TweenService:Create(tData.Button, TweenInfo.new(0.2), {
                    BackgroundColor3 = isActive and Color3.fromRGB(28, 33, 46) or Color3.fromRGB(22, 25, 34)
                }):Play()
                TweenService:Create(tData.Label, TweenInfo.new(0.2), {
                    TextColor3 = isActive and Color3.fromRGB(245, 247, 250) or Color3.fromRGB(150, 158, 175)
                }):Play()
            end
        end
    end)

    return page
end

-- 3 Clean Streamlined Tabs
local CombatTab = createTab("Combat", "Combat", "⚔️")
local MovementTab = createTab("Movement", "Movement", "🏃")
local WorldTab = createTab("World", "World & Loot", "⛏️")

-- ──────────────────────────────────────────────────────────────────────
-- UI BUILDER FUNCTIONS
-- ──────────────────────────────────────────────────────────────────────
local function createToggleCard(parent, title, subtitle, defaultState, callback)
    local state = defaultState

    local card = Instance.new("TextButton")
    card.Size = UDim2.new(1, 0, 0, 52)
    card.BackgroundColor3 = state and Color3.fromRGB(24, 30, 42) or Color3.fromRGB(22, 25, 34)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(32, 36, 48)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -70, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = Color3.fromRGB(240, 243, 248)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -70, 0, 16)
    subLbl.Position = UDim2.new(0, 14, 0, 26)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = subtitle or ""
    subLbl.TextColor3 = Color3.fromRGB(125, 133, 150)
    subLbl.Font = Enum.Font.GothamMedium
    subLbl.TextSize = 11
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.Parent = card

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 44, 0, 24)
    pill.Position = UDim2.new(1, -58, 0.5, -12)
    pill.BackgroundColor3 = state and Color3.fromRGB(0, 230, 153) or Color3.fromRGB(40, 44, 58)
    pill.BorderSizePixel = 0
    pill.Parent = card

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(1, 0)
    pillCorner.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = pill

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function updateVisuals()
        local targetColor = state and Color3.fromRGB(0, 230, 153) or Color3.fromRGB(40, 44, 58)
        local targetPos = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        TweenService:Create(pill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = targetColor }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
        TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = state and Color3.fromRGB(24, 30, 42) or Color3.fromRGB(22, 25, 34) }):Play()
    end

    card.MouseButton1Click:Connect(function()
        state = not state
        pcall(callback, state)
        pcall(updateVisuals)
    end)
end

local function createSliderCard(parent, title, subtitle, minVal, maxVal, defaultVal, suffix, callback)
    local curVal = defaultVal or minVal

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 68)
    card.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(32, 36, 48)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = Color3.fromRGB(240, 243, 248)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 60, 0, 18)
    valLbl.Position = UDim2.new(1, -74, 0, 8)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(curVal) .. (suffix or "")
    valLbl.TextColor3 = Color3.fromRGB(0, 230, 153)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = card

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -28, 0, 8)
    track.Position = UDim2.new(0, 14, 0, 42)
    track.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = card

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    local ratio = math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1)
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 230, 153)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local sliding = false
    local function updateSlider(input)
        local posX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        curVal = math.floor(minVal + (maxVal - minVal) * posX)
        fill.Size = UDim2.new(posX, 0, 1, 0)
        valLbl.Text = tostring(curVal) .. (suffix or "")
        callback(curVal)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateSlider(input)
        end
    end)

    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end))
end

local function createActionButton(parent, text, subtext, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0, 230, 153)
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.5
    btnStroke.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 18)
    lbl.Position = UDim2.new(0, 14, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(245, 247, 250)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -20, 0, 14)
    sub.Position = UDim2.new(0, 14, 0, 24)
    sub.BackgroundTransparency = 1
    sub.Text = subtext or ""
    sub.TextColor3 = Color3.fromRGB(130, 140, 160)
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 11
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = btn

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 45, 60) }):Play()
        task.delay(0.1, function()
            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(24, 30, 42) }):Play()
        end)
        callback()
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- POPULATE CLEAN TABS
-- ──────────────────────────────────────────────────────────────────────

-- 1. COMBAT
createToggleCard(CombatTab, "🛡️ Anti-Knockback (No KB)", "Zero velocity on weapon attacks, crits & explosions", Config.AntiKnockback, function(v)
    Config.AntiKnockback = v
end)

createToggleCard(CombatTab, "⚔️ Packet Kill Aura", "Direct server attack packets with guaranteed critical hits", Config.PacketKillAura, function(v)
    Config.PacketKillAura = v
end)

createToggleCard(CombatTab, "🎯 Bow & Wind Charge Aimbot", "Ballistic predictive aim with gravity and velocity lead compensation", Config.BowAimbot, function(v)
    Config.BowAimbot = v
end)

createSliderCard(CombatTab, "Aura Range", "Maximum target radius in studs", 10, 30, Config.AuraRange, " studs", function(v)
    Config.AuraRange = v
end)

-- 2. MOVEMENT
createToggleCard(MovementTab, "🛡️ Dynamic Anti-Void", "Safe tower recovery before touching lava", Config.AntiVoid, function(v)
    Config.AntiVoid = v
end)

createToggleCard(MovementTab, "🚀 Engine 3D Flight", "Developer Flying attribute bypass with WASD + Space/Shift", Config.Fly, function(v)
    toggleFlight(v)
end)

createSliderCard(MovementTab, "Flight Speed", "Movement speed during 3D flight", 25, 120, Config.FlySpeed, " studs/s", function(v)
    Config.FlySpeed = v
end)

createToggleCard(MovementTab, "🚧 SafeWalk (EdgeGuard)", "Engine block-lock preventing falling off platform edges", Config.EdgeGuard, function(v)
    Config.EdgeGuard = v
    syncSettingsHooks()
end)

createToggleCard(MovementTab, "🧱 Scaffold (Auto-Bridge)", "Automatically places blocks beneath feet while sprinting over air", Config.Scaffold, function(v)
    Config.Scaffold = v
end)

-- 3. WORLD & LOOT
createToggleCard(WorldTab, "⚡ InstaBreak (Fast Mining)", "Pre-digs hovered blocks & breaks at server speed limit 0.28s without desync", Config.InstaBreak, function(v)
    Config.InstaBreak = v
end)

createToggleCard(WorldTab, "🔮 Projectile Trajectory Tracer", "3D predictive landing beam for Ender Pearls, Wind Charges & Bows", Config.ProjectileTracer, function(v)
    Config.ProjectileTracer = v
    if not v then clearTracers() end
end)

createToggleCard(WorldTab, "🧲 Drop Vacuum / Auto-Loot", "Sweeps nearby dropped items directly into inventory", Config.AutoLoot, function(v)
    Config.AutoLoot = v
end)

createSliderCard(WorldTab, "Loot Radius", "Maximum sweep radius for dropped items", 10, 60, Config.LootRange, " studs", function(v)
    Config.LootRange = v
end)

createToggleCard(WorldTab, "👁️ Player ESP & Chams", "Wallhack highlight with player health and distance", Config.PlayerESP, function(v)
    Config.PlayerESP = v
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("FortuneHighlight")
            if hl then hl.Enabled = v end
            local head = p.Character:FindFirstChild("Head")
            if head then
                local bb = head:FindFirstChild("FortuneBillboard")
                if bb then bb.Enabled = v end
            end
        end
    end
end)

createActionButton(WorldTab, "🏃 Auto-Parkour (Daily Claim)", "Instantly teleports to Start and Finish to grab lobby prize", function()
    task.spawn(runAutoParkour)
end)

createActionButton(WorldTab, "💻 Toggle Cmdr Developer Console", "Opens/Closes the official Cmdr terminal (or press F2)", function()
    if CmdrClient then
        CmdrClient:Toggle()
    end
end)

-- Open first tab by default
Tabs["Combat"].Visible = true
TabButtons["Combat"].Bar.Visible = true
TabButtons["Combat"].Button.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
TabButtons["Combat"].Label.TextColor3 = Color3.fromRGB(245, 247, 250)

-- Keybinds
trackConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        if MainFrame and MainFrame.Parent then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end))

-- Initialize All Systems
setupAntiKnockback()
setupInstaBreak()
setupScaffold()
setupProjectileAimbot()
setupProjectileTracer()
setupAutoLoot()
setupAntiVoid()
setupPacketKillAura()
setupCmdrConsole()
syncSettingsHooks()

print("[Potassium] Fortune Engine Hub v2.8 loaded! Menu: [RightShift] | Cmdr: [F2]")
