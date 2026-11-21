--[[
    ══════════════════════════════════════════════════════════════════════
    STRAFEX [SPEAR MACE!] COMBAT SUITE — LIQUID GLASS × MD3 EDITION
    ══════════════════════════════════════════════════════════════════════
    Target Game : STRAFEX [SPEAR MACE!] (Place ID: 129861507977954)
    Platform    : Potassium Executor / Luau Environment
    Design      : Liquid Glass × Material Design 3 (Native UI Framework)
    Architecture:
      • Zero External CDN Dependencies (No Rayfield / No Sirius)
      • Built-in Config Manager & Unload Hook
      • Universal Combat Assist (Reach, Fall-Smash Assist, Anti-KB, Clicker)
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
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Settings State
local Config = {
    ReachEnabled = true,
    HitboxSize = 14,
    AutoMaceCrit = true,
    AutoClicker = false,
    CPSValue = 16,
    AntiKnockback = true,
    SpeedBoost = false,
    SpeedValue = 24,
    InfJump = false,
    ESPEnabled = true,
}

local Connections = {}
local Highlights = {}

local Hub = LiquidGlass.new({
    Title = "STRAFEX",
    Subtitle = "Spear Mace Combat Suite • MD3",
    Keybind = Enum.KeyCode.RightShift,
    PanicKey = Enum.KeyCode.End,
    ConfigFolder = "Strafex",
    Size = UDim2.fromOffset(590, 400)
})

-- ──────────────────────────────────────────────────────────────────────
-- TAB 1: COMBAT
-- ──────────────────────────────────────────────────────────────────────
local CombatTab = Hub:CreateTab("Combat", "⚔️")
CombatTab:AddSection("Hitbox Expansion & Reach")

CombatTab:AddToggle("Hitbox Expander (Reach)", Config.ReachEnabled, function(val)
    Config.ReachEnabled = val
    if not val then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                end
            end
        end
    end
end, "ReachToggle")

CombatTab:AddSlider("Reach Distance (Studs)", 4, 30, Config.HitboxSize, function(val)
    Config.HitboxSize = val
end, "ReachSlider")

CombatTab:AddSection("Mace & Clicker Assist")

CombatTab:AddToggle("Auto Mace Fall-Smash Assist", Config.AutoMaceCrit, function(val)
    Config.AutoMaceCrit = val
end, "MaceCritToggle")

CombatTab:AddToggle("Fast Auto Clicker (Hold LMB)", Config.AutoClicker, function(val)
    Config.AutoClicker = val
end, "ClickerToggle")

CombatTab:AddSlider("Clicker CPS Rate", 6, 25, Config.CPSValue, function(val)
    Config.CPSValue = val
end, "CPSSlider")

CombatTab:AddToggle("Anti-Knockback (Dampen Velocity)", Config.AntiKnockback, function(val)
    Config.AntiKnockback = val
end, "AntiKBToggle")

-- ──────────────────────────────────────────────────────────────────────
-- TAB 2: MOVEMENT
-- ──────────────────────────────────────────────────────────────────────
local MoveTab = Hub:CreateTab("Movement", "🚀")
MoveTab:AddSection("Locomotion")

MoveTab:AddToggle("Speed Booster", Config.SpeedBoost, function(val)
    Config.SpeedBoost = val
    if not val and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end, "SpeedToggle")

MoveTab:AddSlider("WalkSpeed Value", 16, 50, Config.SpeedValue, function(val)
    Config.SpeedValue = val
end, "SpeedSlider")

MoveTab:AddToggle("Infinite Air Jump", Config.InfJump, function(val)
    Config.InfJump = val
end, "InfJumpToggle")

-- ──────────────────────────────────────────────────────────────────────
-- TAB 3: VISUALS
-- ──────────────────────────────────────────────────────────────────────
local VisualTab = Hub:CreateTab("Visuals", "👁️")
VisualTab:AddSection("Intelligence")

VisualTab:AddToggle("Player ESP / Chams", Config.ESPEnabled, function(val)
    Config.ESPEnabled = val
    for _, hl in pairs(Highlights) do
        if hl and hl.Parent then
            hl.Enabled = val
        end
    end
end, "ESPToggle")

-- ──────────────────────────────────────────────────────────────────────
-- TAB 4: PRESETS & CONFIG
-- ──────────────────────────────────────────────────────────────────────
local ConfigTab = Hub:CreateTab("Settings", "⚙")
ConfigTab:AddSection("Preset Profiles")

ConfigTab:AddButton("💾 Save Default Config", function()
    Hub:SaveConfig("default")
end)

ConfigTab:AddButton("📂 Load Default Config", function()
    Hub:LoadConfig("default")
end)

ConfigTab:AddButton("⚡ Toggle AutoSave (10s)", function()
    Hub:AutoSave(true, 10)
    Hub:Notify("AutoSave", "Config auto-saving every 10 seconds.", 2.5)
end)

ConfigTab:AddSection("Session")
ConfigTab:AddButton("🚨 Emergency Panic Unload [End]", function()
    Hub:Unload()
end)

-- ──────────────────────────────────────────────────────────────────────
-- ENGINE RUNNERS & HOOKS
-- ──────────────────────────────────────────────────────────────────────
-- 1. Reach Runner
local reachConn = RunService.RenderStepped:Connect(function()
    if Config.ReachEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    hrp.Transparency = 0.75
                    hrp.CanCollide = false
                    hrp.Material = Enum.Material.ForceField
                end
            end
        end
    end
end)
table.insert(Connections, reachConn)

-- 2. Mace Fall-Smash Assist
local maceConn = RunService.Heartbeat:Connect(function()
    if Config.AutoMaceCrit and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.AssemblyLinearVelocity.Y < -15 then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local targetHRP = p.Character:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        local dist = (hrp.Position - targetHRP.Position).Magnitude
                        if dist <= Config.HitboxSize + 4 and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
                                task.wait(0.01)
                                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
                            end)
                        end
                    end
                end
            end
        end
    end
end)
table.insert(Connections, maceConn)

-- 3. Auto Clicker Loop
local clickerTask = task.spawn(function()
    while true do
        if Config.AutoClicker and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
            end)
            task.wait(1 / math.clamp(Config.CPSValue, 5, 30))
        else
            task.wait(0.05)
        end
    end
end)

-- 4. Anti-Knockback
local kbConn = RunService.Heartbeat:Connect(function()
    if Config.AntiKnockback and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            if math.abs(v.Y) > 30 or math.abs(v.X) > 35 or math.abs(v.Z) > 35 then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    math.clamp(v.X, -18, 18),
                    math.clamp(v.Y, -15, 15),
                    math.clamp(v.Z, -18, 18)
                )
            end
        end
    end
end)
table.insert(Connections, kbConn)

-- 5. Speed Enforcement
local speedConn = RunService.Heartbeat:Connect(function()
    if Config.SpeedBoost and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= Config.SpeedValue then
            hum.WalkSpeed = Config.SpeedValue
        end
    end
end)
table.insert(Connections, speedConn)

-- 6. Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
table.insert(Connections, jumpConn)

-- 7. Player ESP / Chams
local function applyESP(player)
    if player == LocalPlayer then return end
    local function setupChar(char)
        if not char then return end
        local hl = char:FindFirstChild("StrafexHL") or Instance.new("Highlight")
        hl.Name = "StrafexHL"
        hl.FillColor = Color3.fromRGB(255, 45, 85)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Enabled = Config.ESPEnabled
        hl.Parent = char
        Highlights[player] = hl
    end
    if player.Character then setupChar(player.Character) end
    player.CharacterAdded:Connect(setupChar)
end

for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
local pAddedConn = Players.PlayerAdded:Connect(applyESP)
table.insert(Connections, pAddedConn)

-- ──────────────────────────────────────────────────────────────────────
-- UNLOAD HOOK
-- ──────────────────────────────────────────────────────────────────────
Hub:OnUnload(function()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    pcall(task.cancel, clickerTask)

    -- Reset Hitboxes
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
            end
            local hl = p.Character:FindFirstChild("StrafexHL")
            if hl then hl:Destroy() end
        end
    end
    Highlights = {}

    -- Reset Speed
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end

    print("[Strafex] Suite unloaded cleanly.")
end)

Hub:Notify("STRAFEX Loaded", "Press [RightShift] to toggle • [End] to panic unload.", 4)

return Hub
