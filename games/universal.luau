--[[
    ══════════════════════════════════════════════════════════════════════
    POTASSIUM HUB — UNIVERSAL ENGINE & UTILITY SUITE
    ══════════════════════════════════════════════════════════════════════
    Platform    : Potassium Executor / Luau Environment
    Design      : Liquid Glass × Material Design 3 (MD3) Translucent GUI
    Scope       : Universal (Runs across any Roblox experience)
    
    Features:
      • Movement:
        - 3D Physics Flight (WASD + Space/LeftShift)
        - Noclip (All parts collision bypass)
        - Custom WalkSpeed & JumpPower
        - Infinite Jump
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
    ══════════════════════════════════════════════════════════════════════
]]

-- Clean previous instances
if getgenv().UniversalPotassiumInstance and typeof(getgenv().UniversalPotassiumInstance.Destroy) == "function" then
    pcall(function()
        getgenv().UniversalPotassiumInstance:Destroy()
    end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ──────────────────────────────────────────────────────────────────────
-- PALETTE & MD3 TOKENS
-- ──────────────────────────────────────────────────────────────────────
local Theme = {
    SurfaceDark      = Color3.fromRGB(13, 16, 24),
    SurfaceElevated  = Color3.fromRGB(22, 27, 40),
    SurfaceCard      = Color3.fromRGB(29, 36, 54),
    SurfaceInput     = Color3.fromRGB(18, 22, 33),
    
    Primary          = Color3.fromRGB(0, 215, 255),    -- Neon Cyan
    Secondary        = Color3.fromRGB(140, 95, 255),   -- Electric Violet
    AccentGold       = Color3.fromRGB(255, 205, 50),
    AccentDanger     = Color3.fromRGB(255, 75, 95),
    
    TextPrimary      = Color3.fromRGB(245, 248, 255),
    TextSecondary    = Color3.fromRGB(155, 168, 195),
    
    StrokeSubtle     = Color3.fromRGB(45, 58, 85),
    StrokeActive     = Color3.fromRGB(0, 215, 255),
    
    GlassAlpha       = 0.18,
    CardAlpha        = 0.28,
}

local UniversalSuite = {
    Version = "1.2.0",
    Connections = {},
    ESPObjects = {},
    OriginalLighting = {},
    
    Config = {
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
    },
    
    State = {
        LastSafeCFrame = nil,
    }
}

local function GetCharacterRoot(char)
    char = char or LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

-- ──────────────────────────────────────────────────────────────────────
-- MOVEMENT SYSTEMS
-- ──────────────────────────────────────────────────────────────────────
function UniversalSuite:SetFly(enabled)
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

function UniversalSuite:UpdateFlight()
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

function UniversalSuite:UpdateNoclip()
    if not self.Config.Noclip then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

function UniversalSuite:UpdateHumanoid()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if self.Config.ModifySpeed then
        hum.WalkSpeed = self.Config.WalkSpeed
    end
    if self.Config.ModifyJump then
        hum.UseJumpPower = true
        hum.JumpPower = self.Config.JumpPower
    end
end

function UniversalSuite:CheckAntiVoid()
    local root = GetCharacterRoot()
    if not root then return end
    
    if root.Position.Y > self.Config.AntiVoidY + 10 then
        self.State.LastSafeCFrame = root.CFrame
    elseif self.Config.AntiVoid and root.Position.Y < self.Config.AntiVoidY then
        root.AssemblyLinearVelocity = Vector3.zero
        if self.State.LastSafeCFrame then
            root.CFrame = self.State.LastSafeCFrame + Vector3.new(0, 5, 0)
        else
            root.CFrame = CFrame.new(root.Position.X, 20, root.Position.Z)
        end
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- VISUALS: PLAYER ESP & LIGHTING
-- ──────────────────────────────────────────────────────────────────────
function UniversalSuite:CreatePlayerESP(player)
    if player == LocalPlayer or self.ESPObjects[player] then return end
    
    local function applyToChar(char)
        if not char then return end
        local root = char:WaitForChild("HumanoidRootPart", 4)
        local hum = char:WaitForChild("Humanoid", 4)
        if not root or not hum then return end
        
        local hl = Instance.new("Highlight")
        hl.Name = "UniversalHighlight"
        hl.Adornee = char
        hl.FillColor = Theme.Primary
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
        nameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
        nameLabel.TextColor3 = Theme.TextPrimary
        nameLabel.TextSize = 12
        nameLabel.TextStrokeTransparency = 0.4
        nameLabel.Parent = bb
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Position = UDim2.new(0, 0, 0, 18)
        infoLabel.Size = UDim2.new(1, 0, 0, 16)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Font = Enum.Font.GothamMedium
        infoLabel.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. " HP • 0m"
        infoLabel.TextColor3 = Theme.Primary
        infoLabel.TextSize = 11
        infoLabel.TextStrokeTransparency = 0.4
        infoLabel.Parent = bb
        
        self.ESPObjects[player] = {
            Highlight = hl,
            Billboard = bb,
            InfoLabel = infoLabel,
            Root = root,
            Hum = hum,
            Char = char
        }
    end
    
    if player.Character then
        task.spawn(applyToChar, player.Character)
    end
    player.CharacterAdded:Connect(applyToChar)
end

function UniversalSuite:ClearPlayerESP(player)
    local entry = self.ESPObjects[player]
    if entry then
        if entry.Highlight then entry.Highlight:Destroy() end
        if entry.Billboard then entry.Billboard:Destroy() end
        self.ESPObjects[player] = nil
    end
end

function UniversalSuite:UpdateESP()
    if not self.Config.PlayerESP then
        for p, _ in pairs(self.ESPObjects) do
            self:ClearPlayerESP(p)
        end
        return
    end
    
    local myRoot = GetCharacterRoot()
    local myPos = myRoot and myRoot.Position or Vector3.zero
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if not self.ESPObjects[p] then
                self:CreatePlayerESP(p)
            else
                local entry = self.ESPObjects[p]
                if entry.Root and entry.Root.Parent and entry.Hum and entry.Hum.Parent then
                    local dist = math.floor((entry.Root.Position - myPos).Magnitude)
                    entry.InfoLabel.Text = math.floor(entry.Hum.Health) .. "/" .. math.floor(entry.Hum.MaxHealth) .. " HP • " .. dist .. " studs"
                else
                    self:ClearPlayerESP(p)
                end
            end
        end
    end
end

function UniversalSuite:SetFullbright(enabled)
    self.Config.Fullbright = enabled
    if enabled then
        self.OriginalLighting = {
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
        if self.OriginalLighting.Ambient then
            Lighting.Ambient = self.OriginalLighting.Ambient
            Lighting.OutdoorAmbient = self.OriginalLighting.OutdoorAmbient
            Lighting.Brightness = self.OriginalLighting.Brightness
            Lighting.ClockTime = self.OriginalLighting.ClockTime
        end
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- GUI CONSTRUCTION
-- ──────────────────────────────────────────────────────────────────────
function UniversalSuite:BuildInterface()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PotassiumUniversalMD3"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = CoreGui
    self.ScreenGui = ScreenGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 560, 0, 440)
    MainFrame.Position = UDim2.new(0.5, -280, 0.5, -220)
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

    -- Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 50)
    Header.BackgroundColor3 = Theme.SurfaceElevated
    Header.BackgroundTransparency = 0.25
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame

    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 14)
    HeaderCorner.Parent = Header

    local GlowLine = Instance.new("Frame")
    GlowLine.Size = UDim2.new(1, 0, 0, 2)
    GlowLine.Position = UDim2.new(0, 0, 1, -2)
    GlowLine.BackgroundColor3 = Theme.Primary
    GlowLine.BorderSizePixel = 0
    GlowLine.Parent = Header

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Position = UDim2.new(0, 16, 0, 8)
    TitleLabel.Size = UDim2.new(0, 300, 0, 20)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "POTASSIUM HUB • UNIVERSAL"
    TitleLabel.TextColor3 = Theme.TextPrimary
    TitleLabel.TextSize = 15
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Header

    local SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Position = UDim2.new(0, 16, 0, 28)
    SubtitleLabel.Size = UDim2.new(0, 300, 0, 16)
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.Text = "Universal Experience Suite • v" .. self.Version
    SubtitleLabel.TextColor3 = Theme.Primary
    SubtitleLabel.TextSize = 11
    SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLabel.Parent = Header

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -40, 0, 10)
    CloseBtn.BackgroundColor3 = Theme.SurfaceCard
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Theme.TextSecondary
    CloseBtn.TextSize = 14
    CloseBtn.Parent = Header

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseBtn

    -- Tab Bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(0, 130, 1, -50)
    TabBar.Position = UDim2.new(0, 0, 0, 50)
    TabBar.BackgroundColor3 = Theme.SurfaceElevated
    TabBar.BackgroundTransparency = 0.4
    TabBar.BorderSizePixel = 0
    TabBar.Parent = MainFrame

    local TabList = Instance.new("UIListLayout")
    TabList.Padding = UDim.new(0, 6)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.Parent = TabBar

    local TabPad = Instance.new("UIPadding")
    TabPad.PaddingTop = UDim.new(0, 12)
    TabPad.Parent = TabBar

    -- Content
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -140, 1, -60)
    Content.Position = UDim2.new(0, 135, 0, 55)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame

    local Pages = {}
    local TabButtons = {}

    local Tabs = {
        { Id = "Movement", Icon = "🚀", Name = "Движение" },
        { Id = "Visuals",  Icon = "👁️", Name = "ВХ / Визуал" },
        { Id = "Utils",    Icon = "⚙️", Name = "Утилиты" },
    }

    local function SwitchTab(id)
        for tabId, p in pairs(Pages) do
            p.Visible = (tabId == id)
        end
        for tabId, b in pairs(TabButtons) do
            local active = (tabId == id)
            b.BackgroundColor3 = active and Theme.Primary or Theme.SurfaceCard
            b.TextColor3 = active and Theme.SurfaceDark or Theme.TextSecondary
            b.Font = active and Enum.Font.GothamBold or Enum.Font.Gotham
        end
    end

    for idx, tabInfo in ipairs(Tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 114, 0, 36)
        btn.BackgroundColor3 = Theme.SurfaceCard
        btn.Font = Enum.Font.Gotham
        btn.Text = tabInfo.Icon .. "  " .. tabInfo.Name
        btn.TextColor3 = Theme.TextSecondary
        btn.TextSize = 12
        btn.Parent = TabBar

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 8)
        bCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            SwitchTab(tabInfo.Id)
        end)
        TabButtons[tabInfo.Id] = btn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.Visible = false
        page.Parent = Content

        local pList = Instance.new("UIListLayout")
        pList.Padding = UDim.new(0, 8)
        pList.Parent = page

        local pPad = Instance.new("UIPadding")
        pPad.PaddingTop = UDim.new(0, 4)
        pPad.PaddingRight = UDim.new(0, 8)
        pPad.Parent = page

        Pages[tabInfo.Id] = page
    end

    local function CreateCard(parent, titleText, height)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, height or 44)
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

    local function CreateButton(parent, text, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = color or Theme.SurfaceCard
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
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    -- Tab 1: Movement
    local movePage = Pages["Movement"]
    CreateToggle(movePage, "🛸 3D Fly (WASD + Space/Shift)", self.Config.Fly, function(val)
        self:SetFly(val)
    end)
    CreateSlider(movePage, "Fly Speed", 20, 200, self.Config.FlySpeed, function(val)
        self.Config.FlySpeed = val
    end)
    CreateToggle(movePage, "👻 Noclip (Прохождение сквозь стены)", self.Config.Noclip, function(val)
        self.Config.Noclip = val
    end)
    CreateToggle(movePage, "⚡ Custom WalkSpeed", self.Config.ModifySpeed, function(val)
        self.Config.ModifySpeed = val
    end)
    CreateSlider(movePage, "WalkSpeed Value", 16, 250, self.Config.WalkSpeed, function(val)
        self.Config.WalkSpeed = val
    end)
    CreateToggle(movePage, "🦘 Custom JumpPower", self.Config.ModifyJump, function(val)
        self.Config.ModifyJump = val
    end)
    CreateSlider(movePage, "JumpPower Value", 50, 350, self.Config.JumpPower, function(val)
        self.Config.JumpPower = val
    end)
    CreateToggle(movePage, "🕳️ Anti-Void Fall Saver", self.Config.AntiVoid, function(val)
        self.Config.AntiVoid = val
    end)
    CreateToggle(movePage, "🎯 Ctrl + Click Teleport", self.Config.ClickTP, function(val)
        self.Config.ClickTP = val
    end)

    -- Tab 2: Visuals
    local visPage = Pages["Visuals"]
    CreateToggle(visPage, "👁️ Player 3D Highlight & Tag ESP", self.Config.PlayerESP, function(val)
        self.Config.PlayerESP = val
        self:UpdateESP()
    end)
    CreateToggle(visPage, "☀️ Fullbright / Ночное видение", self.Config.Fullbright, function(val)
        self:SetFullbright(val)
    end)
    CreateToggle(visPage, "🔍 Custom Camera FOV", self.Config.CustomFOV, function(val)
        self.Config.CustomFOV = val
        if val then Camera.FieldOfView = self.Config.FOVValue else Camera.FieldOfView = 70 end
    end)
    CreateSlider(visPage, "Field Of View", 70, 120, self.Config.FOVValue, function(val)
        self.Config.FOVValue = val
        if self.Config.CustomFOV then Camera.FieldOfView = val end
    end)

    -- Tab 3: Utils
    local utilPage = Pages["Utils"]
    CreateToggle(utilPage, "🛡️ Anti-AFK / Anti-Idle (Защита от кика 20 мин)", self.Config.AntiAFK, function(val)
        self.Config.AntiAFK = val
    end)
    CreateButton(utilPage, "🔄 Rejoin Current Server", Theme.Secondary, function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    CreateButton(utilPage, "🌐 Server Hop (Найти другой сервер)", Theme.SurfaceCard, function()
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
    CreateButton(utilPage, "📋 Copy Game & Server Info", Theme.SurfaceCard, function()
        local info = string.format("PlaceId: %s | JobId: %s | Players: %d", tostring(game.PlaceId), tostring(game.JobId), #Players:GetPlayers())
        if typeof(setclipboard) == "function" then
            setclipboard(info)
        end
    end)

    -- Floating Pill Toggle
    local Pill = Instance.new("TextButton")
    Pill.Size = UDim2.new(0, 150, 0, 36)
    Pill.Position = UDim2.new(0.5, -75, 0, 14)
    Pill.BackgroundColor3 = Theme.SurfaceElevated
    Pill.Font = Enum.Font.GothamBold
    Pill.Text = "⚡ POTASSIUM HUB"
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
    PillStroke.Parent = Pill

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        Pill.Visible = true
    end)

    Pill.MouseButton1Click:Connect(function()
        Pill.Visible = false
        MainFrame.Visible = true
    end)

    -- Keybind Toggle
    local inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.V then
            MainFrame.Visible = not MainFrame.Visible
            Pill.Visible = not MainFrame.Visible
        end
        if self.Config.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local mouse = LocalPlayer:GetMouse()
            local root = GetCharacterRoot()
            if root and mouse.Hit then
                root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3.5, 0))
            end
        end
    end)
    table.insert(self.Connections, inputConn)

    SwitchTab("Movement")
end

-- ──────────────────────────────────────────────────────────────────────
-- LIFECYCLE
-- ──────────────────────────────────────────────────────────────────────
function UniversalSuite:Init()
    self:BuildInterface()

    local renderConn = RunService.RenderStepped:Connect(function()
        self:UpdateFlight()
        self:UpdateNoclip()
    end)
    table.insert(self.Connections, renderConn)

    local hbConn = RunService.Heartbeat:Connect(function()
        self:UpdateHumanoid()
        self:CheckAntiVoid()
    end)
    table.insert(self.Connections, hbConn)

    local steppedConn = RunService.Stepped:Connect(function()
        if self.Config.Noclip then
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
    end)
    table.insert(self.Connections, steppedConn)

    -- Anti-Idle / Anti-AFK
    LocalPlayer.Idled:Connect(function()
        if self.Config.AntiAFK then
            local VirtualUser = game:GetService("VirtualUser")
            if VirtualUser then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end
        end
    end)

    -- ESP Loop
    local espTask = task.spawn(function()
        while true do
            pcall(function() self:UpdateESP() end)
            task.wait(0.5)
        end
    end)
    self.ESPTask = espTask

    getgenv().UniversalPotassiumInstance = self
    print("[PotassiumHub] Universal Suite Loaded Successfully.")
end

function UniversalSuite:Destroy()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    if self.ESPTask then
        pcall(task.cancel, self.ESPTask)
        self.ESPTask = nil
    end

    for p, _ in pairs(self.ESPObjects) do
        self:ClearPlayerESP(p)
    end
    self.ESPObjects = {}

    self:SetFullbright(false)

    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end

    getgenv().UniversalPotassiumInstance = nil
end

UniversalSuite:Init()
return UniversalSuite
