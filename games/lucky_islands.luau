--[[
    ══════════════════════════════════════════════════════════════════════════════════
    LUCKY ISLANDS (Place ID: 18134283205) — ULTIMATE UTILITY & HUB MODULE
    ══════════════════════════════════════════════════════════════════════════════════
    Target Game : Lucky Islands (Roblox ID: 18134283205)
    Platform    : Potassium Executor / RPC Suite
    Design      : Liquid Glass × Material Design 3 (MD3) + Headless Hub Bridge
    
    Architecture:
      • Dual-Mode:
        1. Standalone Execution: Spawns a full translucent acrylic GUI with animations.
        2. Hub Integration: Returns a modular API table (`LuckyIslands`) & sets
           `getgenv().LuckyIslands` so it can be mounted into any external hub tab.
      • Reversible Engine & Remote Endpoints:
        - NetworkUtility: ReplicatedStorage.Shared.Utilities.NetworkUtility
        - BlockUtility  : ReplicatedStorage.Shared.Utilities.BlockUtility
        - Drops System  : workspace.Drops
        - Islands Map   : workspace.Map.PlacedBlocks.Islands (Lucky Blocks & Purple Lucky Blocks)
        - Lava Level    : workspace.Map.Lava (Y ~44.8)
    ══════════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEAN EXISTING INSTANCE
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._LuckyIslandsInstance then
    pcall(function()
        getgenv()._LuckyIslandsInstance:Unload()
    end)
    getgenv()._LuckyIslandsInstance = nil
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
-- RESOLVE REVERSED MODULES & REMOTES
-- ─────────────────────────────────────────────────────────────────────────────
local NetworkUtility
pcall(function()
    NetworkUtility = require(ReplicatedStorage.Shared.Utilities.NetworkUtility)
end)

local BlockUtility
pcall(function()
    BlockUtility = require(ReplicatedStorage.Shared.Utilities.BlockUtility)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- LIQUID GLASS & MD3 THEME TOKENS
-- ─────────────────────────────────────────────────────────────────────────────
local Theme = {
    Surface = Color3.fromRGB(15, 17, 24),
    SurfaceTrans = 0.25,
    SurfaceContainer = Color3.fromRGB(24, 28, 40),
    SurfaceContainerTrans = 0.35,
    SurfaceHigh = Color3.fromRGB(34, 40, 58),
    SurfaceHighTrans = 0.40,
    
    Primary = Color3.fromRGB(120, 160, 255),
    PrimaryContainer = Color3.fromRGB(45, 68, 120),
    OnPrimary = Color3.fromRGB(10, 14, 26),
    
    RimLight = Color3.fromRGB(255, 255, 255),
    RimLightTrans = 0.82,
    BorderSubtle = Color3.fromRGB(255, 255, 255),
    BorderSubtleTrans = 0.90,
    
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
-- ENGINE CORE MODULE TABLE
-- ─────────────────────────────────────────────────────────────────────────────
local LuckyIslands = {
    Version = "2.1.0",
    PlaceId = 18134283205,
    Connections = {},
    DropESPObjects = {},
    PlayerESPObjects = {},
    LuckyBlockESPObjects = {},
    
    -- Config State
    Config = {
        -- Movement & Flight
        Fly = false,
        FlySpeed = 55,
        AntiVoid = true,
        AntiVoidThreshold = 52,

        -- Visuals
        DropESP = false,
        PlayerESP = false,
        LuckyBlockESP = false,
        PlayerChams = false,
        
        -- Automation
        AutoLuckyBlock = false,
        LuckyBlockRange = 25,
        AutoLoot = false,
        LootRange = 25,
        
        -- Combat
        KillAura = false,
        AuraRange = 16,
        AuraDelay = 0.25,
        CriticalHits = true,
        
        MaxDistance = 800
    },
    
    LastAuraAttack = 0,
    BreakingBlock = nil,
    FlyToggleRef = nil,
    Visible = true
}

-- ─────────────────────────────────────────────────────────────────────────────
-- UTILITY FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────
local function Tween(obj, info, props)
    local ok, tw = pcall(function()
        local t = TweenService:Create(obj, info, props)
        t:Play()
        return t
    end)
    return ok and tw or nil
end

local function MakeRounded(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function MakeStroke(instance, color, trans, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = color or Theme.RimLight
    stroke.Transparency = trans or Theme.RimLightTrans
    stroke.Thickness = thickness or 1
    stroke.Parent = instance
    return stroke
end

local function GetCharacterRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA & REWARD ACTIONS (REVERSED VIA NETWORK UTILITY)
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:GetData()
    if not NetworkUtility then return nil end
    local ok, res = pcall(function()
        return NetworkUtility.InvokeFunction("GetData")
    end)
    return ok and res or nil
end

function LuckyIslands:ClaimDaily()
    if not NetworkUtility then return false end
    local ok = pcall(function()
        NetworkUtility.FireEvent("DailyReward", "Claim")
    end)
    return ok
end

function LuckyIslands:ClaimGroup()
    if not NetworkUtility then return false end
    local ok = pcall(function()
        NetworkUtility.FireEvent("GroupReward", "Claim")
    end)
    return ok
end

-- ─────────────────────────────────────────────────────────────────────────────
-- FLIGHT & MOVEMENT SUBSYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:SetFly(enabled)
    if self.Config.Fly == enabled then return end
    self.Config.Fly = enabled
    if self.FlyToggleRef then
        self.FlyToggleRef.Set(enabled, true)
    end

    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    local hum = char and char:FindFirstChild("Humanoid")
    if not enabled and root then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if hum then
        hum.PlatformStand = false
    end
end

function LuckyIslands:UpdateFlight()
    if not self.Config.Fly then return end

    local char = LocalPlayer.Character
    local root = GetCharacterRoot(char)
    local hum = char and char:FindFirstChild("Humanoid")
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
end

function LuckyIslands:RunAntiVoid()
    if not self.Config.AntiVoid or self.Config.Fly then return end

    local hrp = GetCharacterRoot(LocalPlayer.Character)
    if not hrp then return end

    -- Check if falling past safe height towards Lava (Y ~ 44.8)
    if hrp.Position.Y < self.Config.AntiVoidThreshold and hrp.AssemblyLinearVelocity.Y < -5 then
        -- Cancel downward momentum & spring up
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 75, hrp.AssemblyLinearVelocity.Z)
        
        -- Recovery step
        if hrp.Position.Y < (self.Config.AntiVoidThreshold - 5) then
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 30, 0)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ESP & RADAR SUBSYSTEMS
-- ─────────────────────────────────────────────────────────────────────────────
local function GetLootColor(name)
    local n = name:lower()
    if n:find("lucky") then
        return Theme.Gold
    elseif n:find("diamond") or n:find("sword") or n:find("bow") then
        return Theme.Diamond
    elseif n:find("storm") or n:find("frost") or n:find("purple") or n:find("void") then
        return Theme.Purple
    elseif n:find("potion") or n:find("regen") or n:find("apple") then
        return Theme.Green
    elseif n:find("tnt") or n:find("lava") then
        return Theme.Danger
    end
    return Theme.Common
end

function LuckyIslands:CreateDropESP(drop)
    if not drop or not drop:IsA("BasePart") then return end
    if self.DropESPObjects[drop] then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = "DropTag"
    bill.Adornee = drop
    bill.Size = UDim2.fromOffset(130, 24)
    bill.AlwaysOnTop = true
    bill.ResetOnSpawn = false
    bill.MaxDistance = self.Config.MaxDistance
    bill.Parent = drop

    local tag = Instance.new("Frame")
    tag.Size = UDim2.fromScale(1, 1)
    tag.BackgroundColor3 = Theme.Surface
    tag.BackgroundTransparency = 0.25
    tag.Parent = bill
    MakeRounded(tag, 6)

    local col = GetLootColor(drop.Name)
    MakeStroke(tag, col, 0.4, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = drop.Name
    lbl.TextColor3 = col
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = tag

    self.DropESPObjects[drop] = bill
end

function LuckyIslands:ClearDropESP()
    for drop, bill in pairs(self.DropESPObjects) do
        if bill and bill.Parent then bill:Destroy() end
    end
    self.DropESPObjects = {}
end

function LuckyIslands:UpdateDropESP()
    local dropsFolder = workspace:FindFirstChild("Drops")
    if not dropsFolder or not self.Config.DropESP then
        self:ClearDropESP()
        return
    end

    local hrp = GetCharacterRoot(LocalPlayer.Character)
    for _, drop in ipairs(dropsFolder:GetChildren()) do
        if drop:IsA("BasePart") then
            if not self.DropESPObjects[drop] then
                self:CreateDropESP(drop)
            else
                local bill = self.DropESPObjects[drop]
                local lbl = bill:FindFirstChild("TextLabel", true)
                if lbl and hrp then
                    local dist = math.floor((hrp.Position - drop.Position).Magnitude)
                    lbl.Text = string.format("%s [%dm]", drop.Name, dist)
                end
            end
        end
    end
end

-- Lucky Block ESP
function LuckyIslands:CreateLuckyBlockESP(block)
    if not block or self.LuckyBlockESPObjects[block] then return end

    local part = block:IsA("BasePart") and block or block:FindFirstChildWhichIsA("BasePart", true)
    if not part then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = "LuckyTag"
    bill.Adornee = part
    bill.Size = UDim2.fromOffset(110, 22)
    bill.AlwaysOnTop = true
    bill.ResetOnSpawn = false
    bill.MaxDistance = self.Config.MaxDistance
    bill.Parent = part

    local tag = Instance.new("Frame")
    tag.Size = UDim2.fromScale(1, 1)
    tag.BackgroundColor3 = Theme.Surface
    tag.BackgroundTransparency = 0.25
    tag.Parent = bill
    MakeRounded(tag, 6)

    local isPurple = block.Name:find("Purple") ~= nil
    local col = isPurple and Theme.Purple or Theme.Gold
    MakeStroke(tag, col, 0.35, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = isPurple and "★ Purple Lucky" or "★ Lucky Block"
    lbl.TextColor3 = col
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = tag

    self.LuckyBlockESPObjects[block] = bill
end

function LuckyIslands:ClearLuckyBlockESP()
    for block, bill in pairs(self.LuckyBlockESPObjects) do
        if bill and bill.Parent then bill:Destroy() end
    end
    self.LuckyBlockESPObjects = {}
end

function LuckyIslands:UpdateLuckyBlockESP()
    if not self.Config.LuckyBlockESP then
        self:ClearLuckyBlockESP()
        return
    end

    local pb = workspace.Map:FindFirstChild("PlacedBlocks")
    if not pb then return end

    local hrp = GetCharacterRoot(LocalPlayer.Character)
    for _, block in ipairs(pb:GetDescendants()) do
        if block:IsA("Model") and block.Name:find("Lucky Block") then
            if not self.LuckyBlockESPObjects[block] then
                self:CreateLuckyBlockESP(block)
            else
                local bill = self.LuckyBlockESPObjects[block]
                local lbl = bill:FindFirstChild("TextLabel", true)
                if lbl and hrp then
                    local pivot = block:GetPivot().Position
                    local dist = math.floor((hrp.Position - pivot).Magnitude)
                    local isPurple = block.Name:find("Purple") ~= nil
                    lbl.Text = string.format("%s [%dm]", isPurple and "★ Purple" or "★ Lucky", dist)
                end
            end
        end
    end
end

-- Player ESP & Chams
function LuckyIslands:CreatePlayerESP(plr)
    if plr == LocalPlayer then return end
    if self.PlayerESPObjects[plr] then return end

    local function Attach(char)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        local hum = char:WaitForChild("Humanoid", 5)
        if not root or not hum then return end

        local bill = Instance.new("BillboardGui")
        bill.Name = "PlayerTag"
        bill.Adornee = root
        bill.Size = UDim2.fromOffset(130, 32)
        bill.AlwaysOnTop = true
        bill.MaxDistance = self.Config.MaxDistance
        bill.Parent = root

        local tag = Instance.new("Frame")
        tag.Size = UDim2.fromScale(1, 1)
        tag.BackgroundColor3 = Theme.Surface
        tag.BackgroundTransparency = 0.3
        tag.Parent = bill
        MakeRounded(tag, 6)
        MakeStroke(tag, Theme.Primary, 0.5, 1)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = plr.DisplayName or plr.Name
        nameLbl.TextColor3 = Theme.OnSurface
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 10
        nameLbl.Parent = tag

        local hpLbl = Instance.new("TextLabel")
        hpLbl.Size = UDim2.new(1, 0, 0.45, 0)
        hpLbl.Position = UDim2.new(0, 0, 0.55, 0)
        hpLbl.BackgroundTransparency = 1
        hpLbl.Text = string.format("%d HP", math.floor(hum.Health))
        hpLbl.TextColor3 = Theme.Green
        hpLbl.Font = Enum.Font.GothamMedium
        hpLbl.TextSize = 9
        hpLbl.Parent = tag

        -- Chams Highlight
        local hl = nil
        if self.Config.PlayerChams then
            hl = Instance.new("Highlight")
            hl.Name = "PlayerCham"
            hl.Adornee = char
            hl.FillColor = Theme.Primary
            hl.FillTransparency = 0.55
            hl.OutlineColor = Theme.RimLight
            hl.OutlineTransparency = 0.2
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end

        self.PlayerESPObjects[plr] = {
            Gui = bill,
            Hp = hpLbl,
            Root = root,
            Hum = hum,
            Highlight = hl
        }
    end

    if plr.Character then Attach(plr.Character) end
    plr.CharacterAdded:Connect(Attach)
end

function LuckyIslands:ClearPlayerESP()
    for plr, data in pairs(self.PlayerESPObjects) do
        if data.Gui and data.Gui.Parent then data.Gui:Destroy() end
        if data.Highlight and data.Highlight.Parent then data.Highlight:Destroy() end
    end
    self.PlayerESPObjects = {}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTOMATION: AUTO LUCKY BLOCK BREAKER
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:FindNearestLuckyBlock()
    local hrp = GetCharacterRoot(LocalPlayer.Character)
    if not hrp then return nil end

    local pb = workspace.Map:FindFirstChild("PlacedBlocks")
    if not pb then return nil end

    local closest, closestDist = nil, self.Config.LuckyBlockRange
    for _, block in ipairs(pb:GetDescendants()) do
        if block:IsA("Model") and block.Name:find("Lucky Block") then
            local pos = block:GetPivot().Position
            local d = (hrp.Position - pos).Magnitude
            if d < closestDist then
                closest = block
                closestDist = d
            end
        end
    end
    return closest
end

function LuckyIslands:BreakLuckyBlock(block)
    if not block or not NetworkUtility then return end
    if self.BreakingBlock == block then return end
    self.BreakingBlock = block

    task.spawn(function()
        pcall(function()
            -- 1. StartBreak event
            NetworkUtility.FireEvent("BlockAction", {
                Kind = "StartBreak",
                Block = block
            })

            -- 2. Wait authoritative break threshold (0.42s)
            task.wait(0.42)

            -- 3. Confirm Break event
            NetworkUtility.FireEvent("BlockAction", {
                Kind = "Break",
                Block = block
            })
        end)
        task.wait(0.1)
        self.BreakingBlock = nil
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTOMATION: AUTO LOOT (DROP VACUUM)
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:CollectNearbyDrops()
    local hrp = GetCharacterRoot(LocalPlayer.Character)
    if not hrp then return end

    local dropsFolder = workspace:FindFirstChild("Drops")
    if not dropsFolder then return end

    for _, drop in ipairs(dropsFolder:GetChildren()) do
        if drop:IsA("BasePart") then
            local dist = (hrp.Position - drop.Position).Magnitude
            if dist <= self.Config.LootRange then
                pcall(function()
                    firetouchinterest(hrp, drop, 0)
                    task.wait()
                    firetouchinterest(hrp, drop, 1)
                end)
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- COMBAT: PACKET KILL AURA
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:FindAuraTarget()
    local hrp = GetCharacterRoot(LocalPlayer.Character)
    if not hrp then return nil end

    local closest, closestDist = nil, self.Config.AuraRange
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local targetHrp = GetCharacterRoot(plr.Character)
            local hum = plr.Character:FindFirstChild("Humanoid")
            if targetHrp and hum and hum.Health > 0 then
                local dist = (hrp.Position - targetHrp.Position).Magnitude
                if dist < closestDist then
                    closest = plr
                    closestDist = dist
                end
            end
        end
    end
    return closest
end

function LuckyIslands:RunCombatAura()
    if not NetworkUtility or not self.Config.KillAura then return end
    if os.clock() - self.LastAuraAttack < self.Config.AuraDelay then return end

    local target = self:FindAuraTarget()
    if not target then return end

    self.LastAuraAttack = os.clock()

    local hrp = GetCharacterRoot(LocalPlayer.Character)
    local isMidAir = hrp and math.abs(hrp.AssemblyLinearVelocity.Y) > 1

    pcall(function()
        NetworkUtility.FireEvent("CombatAction", {
            Kind = "Attack",
            Target = target,
            Critical = self.Config.CriticalHits or isMidAir
        })
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MAIN LOOP BINDINGS
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:StartLoops()
    table.insert(self.Connections, RunService.RenderStepped:Connect(function()
        -- 3D Flight
        self:UpdateFlight()

        -- Anti-Void Protection
        self:RunAntiVoid()

        -- Visuals
        if self.Config.DropESP then
            self:UpdateDropESP()
        end
        if self.Config.LuckyBlockESP then
            self:UpdateLuckyBlockESP()
        end
        if self.Config.PlayerESP then
            local myHrp = GetCharacterRoot(LocalPlayer.Character)
            for plr, data in pairs(self.PlayerESPObjects) do
                if data.Root and data.Hum and myHrp and data.Gui.Parent then
                    local dist = math.floor((myHrp.Position - data.Root.Position).Magnitude)
                    local hp = math.floor(data.Hum.Health)
                    data.Hp.Text = string.format("%d HP • %dm", hp, dist)
                    data.Hp.TextColor3 = hp > 50 and Theme.Green or (hp > 25 and Theme.Gold or Theme.Danger)
                end
            end
        end

        -- Combat Aura
        self:RunCombatAura()
    end))

    -- Heartbeat for block breaking and loot vacuuming
    table.insert(self.Connections, RunService.Heartbeat:Connect(function()
        if self.Config.AutoLuckyBlock and not self.BreakingBlock then
            local nearest = self:FindNearestLuckyBlock()
            if nearest then
                self:BreakLuckyBlock(nearest)
            end
        end

        if self.Config.AutoLoot then
            self:CollectNearbyDrops()
        end
    end))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- STANDALONE UI BUILDER (LIQUID GLASS × MD3)
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:BuildStandaloneUI()
    local targetParent = LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LuckyIslands_Aether_" .. math.random(1000, 9999)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = targetParent
    self.ScreenGui = screenGui

    -- Ambient Drop Shadow
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

    -- Modal cursor unlocker
    local cursorModal = Instance.new("TextButton")
    cursorModal.Name = "CursorModalRelease"
    cursorModal.Size = UDim2.new(0, 0, 0, 0)
    cursorModal.BackgroundTransparency = 1
    cursorModal.Text = ""
    cursorModal.Modal = true
    cursorModal.Parent = main

    MakeRounded(main, 16)
    MakeStroke(main, Theme.RimLight, 0.78, 1.2)

    -- Specular Sheen Gradient
    local sheen = Instance.new("Frame")
    sheen.Size = UDim2.new(1, 0, 0, 110)
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

    -- Top Header
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
    badgeIcon.Text = "✈"
    badgeIcon.Font = Enum.Font.GothamBold
    badgeIcon.TextSize = 14
    badgeIcon.Parent = badge

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(52, 10)
    title.Size = UDim2.new(0, 260, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "LUCKY ISLANDS SUITE"
    title.TextColor3 = Theme.OnSurface
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Position = UDim2.fromOffset(52, 26)
    subtitle.Size = UDim2.new(0, 260, 0, 14)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Flight Edition • Liquid Glass • Hub Ready"
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
        self:Unload()
    end)

    -- Horizontal Divider
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, -32, 0, 1)
    div.Position = UDim2.fromOffset(16, 50)
    div.BackgroundColor3 = Theme.BorderSubtle
    div.BackgroundTransparency = Theme.BorderSubtleTrans
    div.BorderSizePixel = 0
    div.Parent = main

    -- Sidebar Tabs Container
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(0, 145, 1, -62)
    tabContainer.Position = UDim2.fromOffset(14, 56)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = main

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer

    -- Content Area Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -183, 1, -62)
    contentFrame.Position = UDim2.fromOffset(169, 56)
    contentFrame.BackgroundColor3 = Theme.SurfaceContainer
    contentFrame.BackgroundTransparency = Theme.SurfaceContainerTrans
    contentFrame.BorderSizePixel = 0
    contentFrame.ClipsDescendants = true
    contentFrame.Parent = main
    MakeRounded(contentFrame, 12)
    MakeStroke(contentFrame, Theme.BorderSubtle, 0.88, 1)

    local tabs = {}
    local function CreateTab(name, iconChar)
        local tab = {}
        tab.Name = name

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = Theme.SurfaceHigh
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = tabContainer
        MakeRounded(btn, 17)
        local stroke = MakeStroke(btn, Theme.Primary, 1, 1)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.fromOffset(20, 20)
        icon.Position = UDim2.fromOffset(10, 7)
        icon.BackgroundTransparency = 1
        icon.Text = iconChar or "•"
        icon.TextColor3 = Theme.OnSurfaceVariant
        icon.Font = Enum.Font.GothamMedium
        icon.TextSize = 13
        icon.Parent = btn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -38, 1, 0)
        lbl.Position = UDim2.fromOffset(34, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Theme.OnSurfaceVariant
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = btn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Theme.Primary
        page.ScrollBarImageTransparency = 0.5
        page.Visible = false
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.fromOffset(0, 0)
        page.Parent = contentFrame

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingBottom = UDim.new(0, 10)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = page

        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 8)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = page

        tab.Button = btn
        tab.Page = page
        tab.Label = lbl
        tab.Icon = icon
        tab.Stroke = stroke

        local function Activate()
            for _, t in ipairs(tabs) do
                t.Page.Visible = false
                Tween(t.Button, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, BackgroundTransparency = 1})
                Tween(t.Label, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurfaceVariant})
                Tween(t.Icon, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurfaceVariant})
                Tween(t.Stroke, TweenInfo.new(0.2), {Transparency = 1})
            end
            page.Visible = true
            Tween(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.PrimaryContainer, BackgroundTransparency = 0.3})
            Tween(lbl, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurface})
            Tween(icon, TweenInfo.new(0.2), {TextColor3 = Theme.Primary})
            Tween(stroke, TweenInfo.new(0.2), {Transparency = 0.6})
        end

        btn.MouseButton1Click:Connect(Activate)
        table.insert(tabs, tab)
        if #tabs == 1 then Activate() end

        function tab:AddCard(h)
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, h or 40)
            card.BackgroundColor3 = Theme.SurfaceHigh
            card.BackgroundTransparency = 0.55
            card.Parent = page
            MakeRounded(card, 10)
            MakeStroke(card, Theme.BorderSubtle, 0.90, 1)
            return card
        end

        function tab:AddInfoRow(labelText, initialVal)
            local card = tab:AddCard(34)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(0.5, -10, 1, 0)
            l.Position = UDim2.fromOffset(12, 0)
            l.BackgroundTransparency = 1
            l.Text = labelText
            l.TextColor3 = Theme.OnSurfaceVariant
            l.Font = Enum.Font.GothamMedium
            l.TextSize = 11
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = card

            local v = Instance.new("TextLabel")
            v.Size = UDim2.new(0.5, -10, 1, 0)
            v.Position = UDim2.new(0.5, 0, 0, 0)
            v.BackgroundTransparency = 1
            v.Text = tostring(initialVal or "—")
            v.TextColor3 = Theme.Primary
            v.Font = Enum.Font.GothamBold
            v.TextSize = 11
            v.TextXAlignment = Enum.TextXAlignment.Right
            v.Parent = card

            return {
                Set = function(newVal) v.Text = tostring(newVal) end
            }
        end

        function tab:AddToggle(labelText, default, callback)
            local state = default or false
            local card = tab:AddCard(38)

            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -64, 1, 0)
            l.Position = UDim2.fromOffset(12, 0)
            l.BackgroundTransparency = 1
            l.Text = labelText
            l.TextColor3 = Theme.OnSurface
            l.Font = Enum.Font.GothamMedium
            l.TextSize = 11
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = card

            local sw = Instance.new("TextButton")
            sw.Size = UDim2.fromOffset(36, 18)
            sw.Position = UDim2.new(1, -48, 0.5, -9)
            sw.BackgroundColor3 = state and Theme.Primary or Theme.SurfaceContainer
            sw.BackgroundTransparency = state and 0.1 or 0.3
            sw.Text = ""
            sw.AutoButtonColor = false
            sw.Parent = card
            MakeRounded(sw, 9)
            local swStroke = MakeStroke(sw, state and Theme.Primary or Theme.Outline, state and 0.5 or 0.7, 1)

            local th = Instance.new("Frame")
            th.Size = UDim2.fromOffset(12, 12)
            th.Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
            th.BackgroundColor3 = state and Theme.OnPrimary or Theme.OnSurfaceVariant
            th.BorderSizePixel = 0
            th.Parent = sw
            MakeRounded(th, 6)

            local function Set(val, silent)
                if state == val then return end
                state = val
                local pos = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
                Tween(th, TweenInfo.new(0.2), {Position = pos, BackgroundColor3 = state and Theme.OnPrimary or Theme.OnSurfaceVariant})
                Tween(sw, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.Primary or Theme.SurfaceContainer, BackgroundTransparency = state and 0.1 or 0.3})
                Tween(swStroke, TweenInfo.new(0.2), {Color = state and Theme.Primary or Theme.Outline})
                if not silent and callback then callback(state) end
            end

            sw.MouseButton1Click:Connect(function() Set(not state) end)
            return { Set = Set, Get = function() return state end }
        end

        function tab:AddButton(btnText, callback)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 34)
            b.BackgroundColor3 = Theme.SurfaceHigh
            b.BackgroundTransparency = 0.5
            b.Text = ""
            b.AutoButtonColor = false
            b.Parent = page
            MakeRounded(b, 10)
            local bStroke = MakeStroke(b, Theme.BorderSubtle, 0.88, 1)

            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, -24, 1, 0)
            t.Position = UDim2.fromOffset(12, 0)
            t.BackgroundTransparency = 1
            t.Text = btnText
            t.TextColor3 = Theme.OnSurface
            t.Font = Enum.Font.GothamMedium
            t.TextSize = 11
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.Parent = b

            local arr = Instance.new("TextLabel")
            arr.Size = UDim2.fromOffset(20, 20)
            arr.Position = UDim2.new(1, -28, 0.5, -10)
            arr.BackgroundTransparency = 1
            arr.Text = "→"
            arr.TextColor3 = Theme.OnSurfaceVariant
            arr.Font = Enum.Font.GothamBold
            arr.TextSize = 12
            arr.Parent = b

            b.MouseEnter:Connect(function()
                Tween(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, BackgroundTransparency = 0.2})
                Tween(bStroke, TweenInfo.new(0.2), {Transparency = 0.6, Color = Theme.Primary})
                Tween(arr, TweenInfo.new(0.2), {TextColor3 = Theme.Primary})
            end)
            b.MouseLeave:Connect(function()
                Tween(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, BackgroundTransparency = 0.5})
                Tween(bStroke, TweenInfo.new(0.2), {Transparency = 0.88, Color = Theme.BorderSubtle})
                Tween(arr, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurfaceVariant})
            end)
            b.MouseButton1Click:Connect(function()
                Tween(b, TweenInfo.new(0.08), {Size = UDim2.new(1, -4, 0, 32)})
                task.delay(0.08, function()
                    Tween(b, TweenInfo.new(0.12), {Size = UDim2.new(1, 0, 0, 34)})
                end)
                if callback then callback() end
            end)
            return b
        end

        return tab
    end

    -- ================================================================
    -- TAB 1: MOVEMENT & 3D FLIGHT
    -- ================================================================
    local tabMove = CreateTab("Movement", "🚀")

    self.FlyToggleRef = tabMove:AddToggle("3D Camera Flight [Key: F]", self.Config.Fly, function(v)
        self:SetFly(v)
        self:Notify("Flight", v and string.format("Flight ON (%d studs/s). [WASD + Space/Shift]", self.Config.FlySpeed) or "Flight OFF.", 2)
    end)

    local rowFlySpeed = tabMove:AddInfoRow("Current Flight Speed", tostring(self.Config.FlySpeed) .. " studs/s")

    tabMove:AddButton("Speed: Normal (55 studs/s)", function()
        self.Config.FlySpeed = 55
        rowFlySpeed.Set("55 studs/s")
        self:Notify("Flight Speed", "Set to 55 studs/s (standard cruise).", 2)
    end)

    tabMove:AddButton("Speed: Fast (85 studs/s)", function()
        self.Config.FlySpeed = 85
        rowFlySpeed.Set("85 studs/s")
        self:Notify("Flight Speed", "Set to 85 studs/s (rush).", 2)
    end)

    tabMove:AddButton("Speed: Hyper (125 studs/s)", function()
        self.Config.FlySpeed = 125
        rowFlySpeed.Set("125 studs/s")
        self:Notify("Flight Speed", "Set to 125 studs/s (hyper flight).", 2)
    end)

    tabMove:AddToggle("Smart Anti-Void (Lava Bounce)", self.Config.AntiVoid, function(v)
        self.Config.AntiVoid = v
        self:Notify("Anti-Void", v and ("Safe threshold active at Y=" .. self.Config.AntiVoidThreshold) or "Anti-Void disabled.", 2)
    end)

    -- ================================================================
    -- TAB 2: VISUALS (RADAR & ESP)
    -- ================================================================
    local tabVisuals = CreateTab("Visuals", "🔍")

    tabVisuals:AddToggle("Survivor Player ESP", self.Config.PlayerESP, function(v)
        self.Config.PlayerESP = v
        if not v then
            self:ClearPlayerESP()
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                self:CreatePlayerESP(plr)
            end
            self:Notify("Visuals", "Player ESP activated.", 2)
        end
    end)

    tabVisuals:AddToggle("Player Chams Highlight", self.Config.PlayerChams, function(v)
        self.Config.PlayerChams = v
        self:ClearPlayerESP()
        if self.Config.PlayerESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                self:CreatePlayerESP(plr)
            end
        end
    end)

    tabVisuals:AddToggle("Lucky Block ESP (Gold / Purple)", self.Config.LuckyBlockESP, function(v)
        self.Config.LuckyBlockESP = v
        if not v then
            self:ClearLuckyBlockESP()
        else
            self:Notify("Visuals", "Highlighting Lucky Blocks across islands.", 2)
        end
    end)

    tabVisuals:AddToggle("Dropped Loot Radar", self.Config.DropESP, function(v)
        self.Config.DropESP = v
        if not v then
            self:ClearDropESP()
        else
            self:Notify("Visuals", "Loot drop tracking active.", 2)
        end
    end)

    -- ================================================================
    -- TAB 3: AUTOMATION
    -- ================================================================
    local tabAuto = CreateTab("Auto", "⚡")

    tabAuto:AddToggle("Auto Break Lucky Blocks", self.Config.AutoLuckyBlock, function(v)
        self.Config.AutoLuckyBlock = v
        self:Notify("Automation", v and "Auto Lucky Block breaker active." or "Auto breaker disabled.", 2)
    end)

    tabAuto:AddToggle("Auto Loot / Drop Vacuum", self.Config.AutoLoot, function(v)
        self.Config.AutoLoot = v
        self:Notify("Automation", v and "Drop vacuum active." or "Drop vacuum disabled.", 2)
    end)

    tabAuto:AddButton("Break Nearest Lucky Block (Now)", function()
        local nearest = self:FindNearestLuckyBlock()
        if nearest then
            self:BreakLuckyBlock(nearest)
            self:Notify("Breaker", "Breaking block: " .. nearest.Name, 2)
        else
            self:Notify("Breaker", "No Lucky Block within range (" .. self.Config.LuckyBlockRange .. "m).", 2)
        end
    end)

    tabAuto:AddButton("Claim Daily & Group Rewards", function()
        self:ClaimDaily()
        self:ClaimGroup()
        self:Notify("Rewards", "Daily & Group claim events fired!", 3)
    end)

    -- ================================================================
    -- TAB 4: COMBAT
    -- ================================================================
    local tabCombat = CreateTab("Combat", "⚔")

    tabCombat:AddToggle("Packet Kill Aura", self.Config.KillAura, function(v)
        self.Config.KillAura = v
        self:Notify("Combat", v and "Combat Aura enabled." or "Combat Aura disabled.", 2)
    end)

    tabCombat:AddToggle("Always Critical Hits", self.Config.CriticalHits, function(v)
        self.Config.CriticalHits = v
    end)

    -- ================================================================
    -- TAB 5: HUB INTEGRATION & SETTINGS
    -- ================================================================
    local tabHub = CreateTab("Hub Bridge", "🔌")

    tabHub:AddButton("Print Integration Code to Console", function()
        print([[
-- Lucky Islands Hub Integration Example:
local Lucky = getgenv().LuckyIslands or loadstring(readfile("lucky_islands.luau"))()

-- In your Hub Tab creation:
myTab:AddToggle("Flight (3D Camera)", false, function(v) Lucky:SetFly(v) end)
myTab:AddToggle("Anti-Void Guard", true, function(v) Lucky.Config.AntiVoid = v end)
myTab:AddToggle("Player ESP", false, function(v) Lucky.Config.PlayerESP = v end)
myTab:AddToggle("Lucky Block ESP", false, function(v) Lucky.Config.LuckyBlockESP = v end)
myTab:AddToggle("Auto Lucky Blocks", false, function(v) Lucky.Config.AutoLuckyBlock = v end)
myTab:AddToggle("Kill Aura", false, function(v) Lucky.Config.KillAura = v end)
myTab:AddButton("Claim Daily & Group", function() 
    Lucky:ClaimDaily() 
    Lucky:ClaimGroup() 
end)
        ]])
        self:Notify("Hub Bridge", "Integration code printed to console!", 3)
    end)

    tabHub:AddButton("Unload & Remove Script", function()
        self:Unload()
    end)

    -- Keybind listeners
    table.insert(self.Connections, RunService.RenderStepped:Connect(function()
        if self.Visible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end))

    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
            self:Toggle()
        elseif input.KeyCode == Enum.KeyCode.F then
            self:SetFly(not self.Config.Fly)
            self:Notify("Flight", self.Config.Fly and string.format("Flight ON (%d studs/s).", self.Config.FlySpeed) or "Flight OFF.", 1.5)
        end
    end))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTIFICATION TOAST
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:Notify(titleText, msgText, duration)
    if not self.ScreenGui then return end
    duration = duration or 3

    local toast = Instance.new("Frame")
    toast.Size = UDim2.fromOffset(250, 50)
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, 280, 1, -20)
    toast.BackgroundColor3 = Theme.Surface
    toast.BackgroundTransparency = 0.2
    toast.BorderSizePixel = 0
    toast.Parent = self.ScreenGui
    MakeRounded(toast, 12)
    MakeStroke(toast, Theme.Primary, 0.7, 1)

    local tl = Instance.new("TextLabel")
    tl.Position = UDim2.fromOffset(12, 6)
    tl.Size = UDim2.new(1, -24, 0, 16)
    tl.BackgroundTransparency = 1
    tl.Text = titleText or "Notice"
    tl.TextColor3 = Theme.Primary
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 11
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = toast

    local ml = Instance.new("TextLabel")
    ml.Position = UDim2.fromOffset(12, 23)
    ml.Size = UDim2.new(1, -24, 0, 20)
    ml.BackgroundTransparency = 1
    ml.Text = msgText or ""
    ml.TextColor3 = Theme.OnSurface
    ml.Font = Enum.Font.Gotham
    ml.TextSize = 10
    ml.TextXAlignment = Enum.TextXAlignment.Left
    ml.TextTruncate = Enum.TextTruncate.AtEnd
    ml.Parent = toast

    Tween(toast, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -20, 1, -20)
    })

    task.delay(duration, function()
        if toast and toast.Parent then
            local tw = Tween(toast, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 280, 1, -20)
            })
            tw.Completed:Connect(function() toast:Destroy() end)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TOGGLE & UNLOAD
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:Toggle()
    if not self.Main or not self.Shadow then return end
    self.Visible = not self.Visible

    local targetPos = self.Visible and UDim2.fromScale(0.5, 0.5) or UDim2.new(0.5, 0, 0.5, 25)
    local targetTrans = self.Visible and 0.32 or 1

    if self.Visible then
        self.Main.Visible = true
        self.Shadow.Visible = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end

    Tween(self.Main, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = targetPos})
    Tween(self.Shadow, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = targetPos, ImageTransparency = targetTrans})

    if not self.Visible then
        task.delay(0.25, function()
            if not self.Visible then
                self.Main.Visible = false
                self.Shadow.Visible = false
            end
        end)
    end
end

function LuckyIslands:Unload()
    self:SetFly(false)

    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    self:ClearDropESP()
    self:ClearPlayerESP()
    self:ClearLuckyBlockESP()

    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end

    if getgenv then
        getgenv()._LuckyIslandsInstance = nil
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HUB INTEGRATION BRIDGE (MOUNT METHOD)
-- ─────────────────────────────────────────────────────────────────────────────
function LuckyIslands:Mount(customTab)
    if not customTab then return false end

    local function CallTab(methodName, ...)
        if type(customTab[methodName]) == "function" then
            return customTab[methodName](customTab, ...)
        end
        return nil
    end

    -- Flight & Movement
    CallTab("AddToggle", "3D Camera Flight [F]", self.Config.Fly, function(v)
        self:SetFly(v)
    end)

    CallTab("AddToggle", "Anti-Void Guard", self.Config.AntiVoid, function(v)
        self.Config.AntiVoid = v
    end)

    -- Visuals
    CallTab("AddToggle", "Player ESP", self.Config.PlayerESP, function(v)
        self.Config.PlayerESP = v
        if not v then self:ClearPlayerESP() else
            for _, plr in ipairs(Players:GetPlayers()) do self:CreatePlayerESP(plr) end
        end
    end)

    CallTab("AddToggle", "Lucky Block ESP", self.Config.LuckyBlockESP, function(v)
        self.Config.LuckyBlockESP = v
        if not v then self:ClearLuckyBlockESP() end
    end)

    CallTab("AddToggle", "Loot Drops ESP", self.Config.DropESP, function(v)
        self.Config.DropESP = v
        if not v then self:ClearDropESP() end
    end)

    -- Automation
    CallTab("AddToggle", "Auto Lucky Blocks", self.Config.AutoLuckyBlock, function(v)
        self.Config.AutoLuckyBlock = v
    end)

    CallTab("AddToggle", "Auto Loot / Vacuum", self.Config.AutoLoot, function(v)
        self.Config.AutoLoot = v
    end)

    -- Combat
    CallTab("AddToggle", "Kill Aura", self.Config.KillAura, function(v)
        self.Config.KillAura = v
    end)

    -- Actions
    CallTab("AddButton", "Claim Daily & Group Rewards", function()
        self:ClaimDaily()
        self:ClaimGroup()
    end)

    CallTab("AddButton", "Sweep Nearby Drops", function()
        self:CollectNearbyDrops()
    end)

    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- INITIALIZATION
-- ─────────────────────────────────────────────────────────────────────────────
LuckyIslands:StartLoops()
LuckyIslands:BuildStandaloneUI()

if getgenv then
    getgenv()._LuckyIslandsInstance = LuckyIslands
    getgenv().LuckyIslands = LuckyIslands
end

LuckyIslands:Notify("Lucky Islands Suite", "Loaded v2.1.0 [Flight Edition]. [F] to Fly, [RShift] to toggle GUI.", 4)

return LuckyIslands
