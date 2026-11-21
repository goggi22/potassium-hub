--[[
    ══════════════════════════════════════════════════════════════════════
    POTASSIUM HUB — UNIVERSAL ENGINE (LIQUID GLASS × MD3 EDITION)
    ══════════════════════════════════════════════════════════════════════
    Platform    : Potassium Executor / Luau Environment
    Design      : Liquid Glass × Material Design 3 (Native Framework)
    Scope       : Universal (Runs across any Roblox experience)
    
    Features:
      • Movement:
        - 3D Physics Flight (WASD + Space/LeftShift)
        - Noclip (All parts collision bypass)
        - Custom WalkSpeed & JumpPower
        - Infinite Air Jump
        - Dynamic Anti-Void (Auto-Rescue)
        - Ctrl + Click Teleport
      • Visuals & Intelligence:
        - Player ESP (3D Highlights, Billboards, Distance, Health)
        - Fullbright / Ambient Illuminator
        - Custom Camera Field of View (FOV)
      • Automation & Quality of Life:
        - Anti-AFK / Anti-Idle (20-minute kick bypass)
        - Rejoin Server / Server Hop
        - Copy Game Info (PlaceId, JobId, UniverseId)
      • Configuration:
        - Integrated JSON Save / Load Manager via writefile/readfile
        - Panic Unload Hook [End]
    ══════════════════════════════════════════════════════════════════════
]]

local BaseURL = "https://raw.githubusercontent.com/goggi22/potassium-hub/main/"
local function CacheBust(url)
    local sep = url:find("%?") and "&" or "?"
    return url .. sep .. "t=" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

local LiquidGlass = getgenv().LiquidGlass
if not LiquidGlass then
    local src = game:HttpGet(CacheBust(BaseURL .. "src/ui/liquid_glass.luau"))
    LiquidGlass = loadstring(src)()
    getgenv().LiquidGlass = LiquidGlass
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Fly = false,
    FlySpeed = 65,
    Noclip = false,
    
    ModifySpeed = false,
    WalkSpeed = 50,
    ModifyJump = false,
    JumpPower = 100,
    InfiniteJump = false,
    
    ClickTP = false,
    AntiVoid = true,
    AntiVoidY = -60,
    
    PlayerESP = false,
    Fullbright = false,
    CustomFOV = false,
    FOVValue = 90,
    
    AntiAFK = true,
}

local Connections = {}
local ESPObjects = {}
local OriginalLighting = {}
local LastSafeCFrame = nil

local function GetCharacterRoot(char)
    char = char or LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local Hub = LiquidGlass.new({
    Title = "POTASSIUM",
    Subtitle = "Universal Experience Suite • MD3",
    Keybind = Enum.KeyCode.RightControl,
    PanicKey = Enum.KeyCode.End,
    ConfigFolder = "Universal",
    Size = UDim2.fromOffset(600, 410)
})

-- ──────────────────────────────────────────────────────────────────────
-- TAB 1: MOVEMENT
-- ──────────────────────────────────────────────────────────────────────
local MoveTab = Hub:CreateTab("Movement", "🚀")
MoveTab:AddSection("Flight & Noclip")

MoveTab:AddToggle("3D Physics Flight (WASD + Space/Shift)", Config.Fly, function(val)
    Config.Fly = val
    local root = GetCharacterRoot()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not val and root then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if hum then
        hum.PlatformStand = val
    end
end, "FlyToggle")

MoveTab:AddSlider("Flight Speed", 20, 200, Config.FlySpeed, function(val)
    Config.FlySpeed = val
end, "FlySpeedSlider")

MoveTab:AddToggle("Noclip (Walk Through Walls)", Config.Noclip, function(val)
    Config.Noclip = val
end, "NoclipToggle")

MoveTab:AddSection("Character Speed & Jump")

MoveTab:AddToggle("Custom WalkSpeed", Config.ModifySpeed, function(val)
    Config.ModifySpeed = val
    if not val and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end, "SpeedToggle")

MoveTab:AddSlider("WalkSpeed Value", 16, 250, Config.WalkSpeed, function(val)
    Config.WalkSpeed = val
end, "SpeedSlider")

MoveTab:AddToggle("Custom JumpPower", Config.ModifyJump, function(val)
    Config.ModifyJump = val
    if not val and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = 50 end
    end
end, "JumpToggle")

MoveTab:AddSlider("JumpPower Value", 50, 350, Config.JumpPower, function(val)
    Config.JumpPower = val
end, "JumpSlider")

MoveTab:AddToggle("Infinite Air Jump", Config.InfiniteJump, function(val)
    Config.InfiniteJump = val
end, "InfJumpToggle")

MoveTab:AddSection("Safety & Teleport")

MoveTab:AddToggle("Anti-Void Fall Saver", Config.AntiVoid, function(val)
    Config.AntiVoid = val
end, "AntiVoidToggle")

MoveTab:AddToggle("Ctrl + Click Teleport", Config.ClickTP, function(val)
    Config.ClickTP = val
end, "ClickTPToggle")

-- ──────────────────────────────────────────────────────────────────────
-- TAB 2: VISUALS
-- ──────────────────────────────────────────────────────────────────────
local VisualTab = Hub:CreateTab("Visuals", "👁️")
VisualTab:AddSection("Player Intelligence")

local function ClearPlayerESP(p)
    local entry = ESPObjects[p]
    if entry then
        if entry.Highlight then entry.Highlight:Destroy() end
        if entry.Billboard then entry.Billboard:Destroy() end
        ESPObjects[p] = nil
    end
end

local function CreatePlayerESP(p)
    if p == LocalPlayer or ESPObjects[p] then return end
    local function applyChar(char)
        if not char then return end
        local root = char:WaitForChild("HumanoidRootPart", 4)
        local hum = char:WaitForChild("Humanoid", 4)
        if not root or not hum then return end

        local hl = Instance.new("Highlight")
        hl.Name = "UniversalHighlight"
        hl.Adornee = char
        hl.FillColor = Color3.fromRGB(0, 215, 255)
        hl.FillTransparency = 0.6
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.OutlineTransparency = 0.2
        hl.Parent = CoreGui

        local bb = Instance.new("BillboardGui")
        bb.Name = "UniversalTag"
        bb.Adornee = root
        bb.Size = UDim2.new(0, 160, 0, 40)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop = true
        bb.Parent = CoreGui

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = p.DisplayName .. " (@" .. p.Name .. ")"
        nameLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
        nameLabel.TextSize = 12
        nameLabel.TextStrokeTransparency = 0.4
        nameLabel.Parent = bb

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Position = UDim2.new(0, 0, 0, 18)
        infoLabel.Size = UDim2.new(1, 0, 0, 16)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Font = Enum.Font.GothamMedium
        infoLabel.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. " HP • 0m"
        infoLabel.TextColor3 = Color3.fromRGB(0, 215, 255)
        infoLabel.TextSize = 11
        infoLabel.TextStrokeTransparency = 0.4
        infoLabel.Parent = bb

        ESPObjects[p] = {
            Highlight = hl,
            Billboard = bb,
            InfoLabel = infoLabel,
            Root = root,
            Hum = hum
        }
    end
    if p.Character then task.spawn(applyChar, p.Character) end
    p.CharacterAdded:Connect(applyChar)
end

VisualTab:AddToggle("Player 3D Highlight & Tag ESP", Config.PlayerESP, function(val)
    Config.PlayerESP = val
    if not val then
        for p, _ in pairs(ESPObjects) do
            ClearPlayerESP(p)
        end
    end
end, "PlayerESPToggle")

VisualTab:AddSection("World Lighting & Camera")

local function SetFullbright(val)
    Config.Fullbright = val
    if val then
        OriginalLighting = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
        }
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    else
        if OriginalLighting.Ambient then
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
        end
    end
end

VisualTab:AddToggle("Fullbright / NightVision", Config.Fullbright, function(val)
    SetFullbright(val)
end, "FullbrightToggle")

VisualTab:AddToggle("Custom Camera FOV", Config.CustomFOV, function(val)
    Config.CustomFOV = val
    if val then Camera.FieldOfView = Config.FOVValue else Camera.FieldOfView = 70 end
end, "FOVToggle")

VisualTab:AddSlider("Field Of View", 70, 120, Config.FOVValue, function(val)
    Config.FOVValue = val
    if Config.CustomFOV then Camera.FieldOfView = val end
end, "FOVSlider")

-- ──────────────────────────────────────────────────────────────────────
-- TAB 3: UTILITIES
-- ──────────────────────────────────────────────────────────────────────
local UtilTab = Hub:CreateTab("Utils", "⚙")
UtilTab:AddSection("Anti-Disconnect & Server")

UtilTab:AddToggle("Anti-AFK (20-Minute Kick Bypass)", Config.AntiAFK, function(val)
    Config.AntiAFK = val
end, "AntiAFKToggle")

UtilTab:AddButton("🔄 Rejoin Current Server", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

UtilTab:AddButton("🌐 Server Hop (Public Instances)", function()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
        local res = game:HttpGet(url)
        local data = HttpService:JSONDecode(res)
        if data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    break
                end
            end
        end
    end)
end)

UtilTab:AddButton("📋 Copy Experience & Session Info", function()
    local info = string.format("PlaceId: %s | JobId: %s | UniverseId: %s | Players: %d", tostring(game.PlaceId), tostring(game.JobId), tostring(game.GameId), #Players:GetPlayers())
    if typeof(setclipboard) == "function" then
        setclipboard(info)
        Hub:Notify("Copied", "Session details copied to clipboard.", 2)
    end
end)

-- ──────────────────────────────────────────────────────────────────────
-- TAB 4: PRESETS & CONFIG
-- ──────────────────────────────────────────────────────────────────────
local ConfigTab = Hub:CreateTab("Config", "💾")
ConfigTab:AddSection("Preset Management")

ConfigTab:AddButton("💾 Save Default Preset", function()
    Hub:SaveConfig("default")
end)

ConfigTab:AddButton("📂 Load Default Preset", function()
    Hub:LoadConfig("default")
end)

ConfigTab:AddButton("⚡ Toggle AutoSave (10s)", function()
    Hub:AutoSave(true, 10)
    Hub:Notify("AutoSave", "Settings will auto-save every 10 seconds.", 2.5)
end)

ConfigTab:AddSection("Session Panic")
ConfigTab:AddButton("🚨 Emergency Panic Unload [End]", function()
    Hub:Unload()
end)

-- ──────────────────────────────────────────────────────────────────────
-- RUNNERS & LOOPS
-- ──────────────────────────────────────────────────────────────────────
-- 1. Flight Runner
local renderConn = RunService.RenderStepped:Connect(function()
    if Config.Fly then
        local root = GetCharacterRoot()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if root and hum then
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
                root.AssemblyLinearVelocity = moveDir.Unit * Config.FlySpeed
            else
                root.AssemblyLinearVelocity = Vector3.zero
            end
            hum.PlatformStand = true
        end
    end

    if Config.Noclip and LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end
end)
table.insert(Connections, renderConn)

-- 2. Humanoid & AntiVoid Runner
local hbConn = RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = GetCharacterRoot(char)

    if hum then
        if Config.ModifySpeed and hum.WalkSpeed ~= Config.WalkSpeed then
            hum.WalkSpeed = Config.WalkSpeed
        end
        if Config.ModifyJump then
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpPower
        end
    end

    if root then
        if root.Position.Y > Config.AntiVoidY + 10 then
            LastSafeCFrame = root.CFrame
        elseif Config.AntiVoid and root.Position.Y < Config.AntiVoidY then
            root.AssemblyLinearVelocity = Vector3.zero
            if LastSafeCFrame then
                root.CFrame = LastSafeCFrame + Vector3.new(0, 5, 0)
            else
                root.CFrame = CFrame.new(root.Position.X, 25, root.Position.Z)
            end
        end
    end
end)
table.insert(Connections, hbConn)

-- 3. Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
table.insert(Connections, jumpConn)

-- 4. Ctrl + Click Teleport
local clickTPConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if Config.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local mouse = LocalPlayer:GetMouse()
        local root = GetCharacterRoot()
        if root and mouse.Hit then
            root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3.5, 0))
        end
    end
end)
table.insert(Connections, clickTPConn)

-- 5. Anti-AFK
local idledConn = LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        local VirtualUser = game:GetService("VirtualUser")
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end
    end
end)
table.insert(Connections, idledConn)

-- 6. ESP Worker
local espTask = task.spawn(function()
    while true do
        if Config.PlayerESP then
            pcall(function()
                local myRoot = GetCharacterRoot()
                local myPos = myRoot and myRoot.Position or Vector3.zero
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        if not ESPObjects[p] then
                            CreatePlayerESP(p)
                        else
                            local entry = ESPObjects[p]
                            if entry.Root and entry.Root.Parent and entry.Hum and entry.Hum.Parent then
                                local dist = math.floor((entry.Root.Position - myPos).Magnitude)
                                entry.InfoLabel.Text = math.floor(entry.Hum.Health) .. "/" .. math.floor(entry.Hum.MaxHealth) .. " HP • " .. dist .. "m"
                            else
                                ClearPlayerESP(p)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- ──────────────────────────────────────────────────────────────────────
-- UNLOAD HOOK
-- ──────────────────────────────────────────────────────────────────────
Hub:OnUnload(function()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    pcall(task.cancel, espTask)

    for p, _ in pairs(ESPObjects) do
        ClearPlayerESP(p)
    end
    ESPObjects = {}

    SetFullbright(false)

    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
        hum.PlatformStand = false
    end
    Camera.FieldOfView = 70

    print("[Universal] Suite unloaded cleanly.")
end)

Hub:Notify("Universal Loaded", "Press [RightControl] to toggle • [End] to panic unload.", 4)

return Hub
