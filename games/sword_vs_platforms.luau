--[[
    ══════════════════════════════════════════════════════════════════════════════════
    1 SWORD VS PLATFORMS (Place ID: 96222041874857) — ADVANCED SUITE v2.0
    ══════════════════════════════════════════════════════════════════════════════════
    Target Experience : 1 Sword Vs Platforms (Roblox ID: 96222041874857)
    Platform          : Potassium Executor / Luau Runtime
    Design Language   : Liquid Glass × Material Design 3 (MD3) Translucent Framework
    
    Features:
      • Intelligent Gate Navigator & Chest Harvester:
        - Smart Green & Golden Gate Steer (Never hits red doors, 100% positive multipliers)
        - Dynamic Chest Interceptor (Collects AuraChests & Admin Drops along the run)
        - Multi-phase steering (Prioritizes chests between gates, locks green doors near gates)
      • Screen Bonus Harvester:
        - Auto detects & clicks floating MultiPopups (Damage, XP, Wins, Sparks, Rainbow)
        - Instant Activated/MouseButton1Click dispatch + claim fallback
        - Stat counter tracking claimed bonuses
      • AFK Progression Engine:
        - Auto Train Dummy / Zone (Auto-selects best unlocked zone or manual zone lock)
        - Auto Run / Win Farmer (Loops Start.Hitbox, slices gates, harvests thousands of wins)
        - Auto Rebirth (Instant progression reset when level requirement satisfied)
      • Smart Equipment & Upgrades:
        - Auto Equip Best Owned Weapon (Evaluates Order, Damage, XP - fixes downgrade bug)
        - Auto Equip Best Owned Shield (Evaluates Order, Health - fixes downgrade bug)
        - Auto Buy & Upgrade Best Affordable Weapon & Shield
        - Auto Claim Playtime Gifts (Tiers 1 to 12)
        - Auto Claim Daily Reward & Daily Chest
        - Auto Claim Group Chest
        - One-Click Promo Code Redeemer (Bypasses rate limit)
      • Movement & QoL:
        - WalkSpeed & JumpPower Sliders
        - Infinite Jump
        - Noclip
        - 3D Physics Flight
        - Anti-AFK (20-min kick bypass)
      • Direct Teleports:
        - Spawn, Game Start, Shops, All 7 Training Dummies, Portals
    ══════════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEANUP PREVIOUS INSTANCES
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._SwordVsPlatformsSuite then
    pcall(function()
        getgenv()._SwordVsPlatformsSuite:Unload()
    end)
    getgenv()._SwordVsPlatformsSuite = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVICES & LOCAL REFERENCES
-- ─────────────────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Wait for player character
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local char = getCharacter()
    return char and char:WaitForChild("HumanoidRootPart", 5)
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:WaitForChild("Humanoid", 5)
end

-- Networking References
local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))
local DataMod = require(ReplicatedStorage:WaitForChild("Data"))

local WeaponRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Registries"):WaitForChild("WeaponRegistry"))
local ShieldRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Registries"):WaitForChild("ShieldRegistry"))
local TrainingRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Registries"):WaitForChild("TrainingRegistry"))

local RunController = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("RunController"))
local GateDoors = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("GateDoors"))

-- Network channels
local NetMultiPopups = Networker.client.new("MultiPopups")
local NetWeaponStore = Networker.client.new("WeaponStore")
local NetShieldStore = Networker.client.new("ShieldStore")
local NetRebirth     = Networker.client.new("Rebirth")
local NetPlaytime    = Networker.client.new("PlaytimeRewards")
local NetDaily       = Networker.client.new("DailyRewards")
local NetDailyChest  = Networker.client.new("DailyChest")
local NetGroup       = Networker.client.new("GroupReward")
local NetCodes       = Networker.client.new("Codes")

-- Preserve original functions for clean unload
local orig_pickAutoSide = RunController._pickAutoSide
local orig_pickAutoTargets = RunController._pickAutoTargets
local orig_getSteer = RunController._getSteer

-- ─────────────────────────────────────────────────────────────────────────────
-- LIQUID GLASS × MD3 UI ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

local Theme = {
    Surface = Color3.fromRGB(13, 17, 26),
    SurfaceTrans = 0.22,
    SurfaceContainer = Color3.fromRGB(20, 26, 42),
    SurfaceContainerTrans = 0.32,
    SurfaceHigh = Color3.fromRGB(30, 38, 62),
    SurfaceHighTrans = 0.40,
    
    Primary = Color3.fromRGB(0, 225, 255),           -- Vibrant Neon Cyan
    PrimaryContainer = Color3.fromRGB(15, 65, 105),
    OnPrimary = Color3.fromRGB(5, 15, 28),
    Secondary = Color3.fromRGB(175, 120, 255),       -- Electric Violet
    AccentGold = Color3.fromRGB(255, 210, 50),
    
    RimLight = Color3.fromRGB(255, 255, 255),
    RimLightTrans = 0.80,
    BorderSubtle = Color3.fromRGB(100, 160, 255),
    BorderSubtleTrans = 0.85,
    
    OnSurface = Color3.fromRGB(242, 246, 255),
    OnSurfaceVariant = Color3.fromRGB(145, 162, 195),
    Outline = Color3.fromRGB(65, 80, 115),
    
    Success = Color3.fromRGB(80, 240, 150),
    Warning = Color3.fromRGB(255, 200, 60),
    Danger = Color3.fromRGB(255, 85, 95)
}

local function Tween(obj, info, props)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
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

function LiquidGlass.new(config)
    config = config or {}
    local self = setmetatable({}, LiquidGlass)
    
    self.Title = config.Title or "SWORD VS PLATFORMS"
    self.Subtitle = config.Subtitle or "Liquid Glass • MD3 Suite"
    self.Keybind = config.Keybind or Enum.KeyCode.RightShift
    self.Size = config.Size or UDim2.fromOffset(630, 410)
    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.Connections = {}

    local targetParent = pcall(function() return CoreGui:GetChildren() end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LiquidGlass_SVP_" .. math.random(10000, 99999)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = targetParent
    self.ScreenGui = screenGui

    -- Ambient Shadow Layer
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = self.Size + UDim2.fromOffset(80, 80)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 8)
    shadow.ImageTransparency = 0.32
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Parent = screenGui
    self.Shadow = shadow

    -- Main Acrylic Frame
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = self.Size
    main.BackgroundColor3 = Theme.Surface
    main.BackgroundTransparency = Theme.SurfaceTrans
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    self.Main = main

    MakeRounded(main, 18)
    MakeStroke(main, Theme.RimLight, 0.75, 1.2)

    -- Top Gradient Specular Sheen
    local sheen = Instance.new("Frame")
    sheen.Name = "SheenGradient"
    sheen.Size = UDim2.new(1, 0, 0, 130)
    sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheen.BackgroundTransparency = 0.93
    sheen.BorderSizePixel = 0
    sheen.Parent = main
    MakeRounded(sheen, 18)

    local sheenGrad = Instance.new("UIGradient")
    sheenGrad.Rotation = 90
    sheenGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.4, 0.8),
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
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                local delta = input.Position - dragStart
                local newPos = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
                main.Position = newPos
                shadow.Position = newPos
            end
        end
    end)

    -- Header Bar
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 52)
    header.BackgroundTransparency = 1
    header.Parent = main

    local logoBadge = Instance.new("Frame")
    logoBadge.Name = "LogoBadge"
    logoBadge.Size = UDim2.fromOffset(30, 30)
    logoBadge.Position = UDim2.fromOffset(16, 11)
    logoBadge.BackgroundColor3 = Theme.Primary
    logoBadge.BackgroundTransparency = 0.15
    logoBadge.Parent = header
    MakeRounded(logoBadge, 8)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.Size = UDim2.fromScale(1, 1)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Text = "⚔"
    logoIcon.TextColor3 = Theme.OnPrimary
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 16
    logoIcon.Parent = logoBadge

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(56, 11)
    title.Size = UDim2.new(0, 260, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = self.Title
    title.TextColor3 = Theme.OnSurface
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Position = UDim2.fromOffset(56, 29)
    subtitle.Size = UDim2.new(0, 260, 0, 14)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = self.Subtitle
    subtitle.TextColor3 = Theme.OnSurfaceVariant
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -40, 0, 12)
    closeBtn.BackgroundColor3 = Theme.SurfaceHigh
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Theme.OnSurfaceVariant
    closeBtn.Font = Enum.Font.GothamMedium
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    MakeRounded(closeBtn, 8)
    MakeStroke(closeBtn, Theme.BorderSubtle, 0.85, 1)

    closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Danger, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.2})
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, TextColor3 = Theme.OnSurfaceVariant, BackgroundTransparency = 0.5})
    end)
    closeBtn.MouseButton1Click:Connect(function()
        self:Unload()
    end)

    -- Divider Line
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.fromOffset(16, 52)
    divider.BackgroundColor3 = Theme.BorderSubtle
    divider.BackgroundTransparency = Theme.BorderSubtleTrans
    divider.BorderSizePixel = 0
    divider.Parent = main

    -- Sidebar (Tabs)
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(0, 154, 1, -66)
    tabContainer.Position = UDim2.fromOffset(16, 58)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = main

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer

    self.TabContainer = tabContainer

    -- Content Container (Pages)
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -196, 1, -66)
    contentFrame.Position = UDim2.fromOffset(180, 58)
    contentFrame.BackgroundColor3 = Theme.SurfaceContainer
    contentFrame.BackgroundTransparency = Theme.SurfaceContainerTrans
    contentFrame.BorderSizePixel = 0
    contentFrame.ClipsDescendants = true
    contentFrame.Parent = main
    MakeRounded(contentFrame, 14)
    MakeStroke(contentFrame, Theme.BorderSubtle, 0.88, 1)

    self.ContentFrame = contentFrame

    -- Keybind Listener
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end))

    return self
end

function LiquidGlass:Toggle()
    self.Visible = not self.Visible
    local shadowTrans = self.Visible and 0.32 or 1
    
    if self.Visible then
        self.Main.Visible = true
        self.Shadow.Visible = true
        Tween(self.Main, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5, 0.5)
        })
        Tween(self.Shadow, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5, 0.5),
            ImageTransparency = shadowTrans
        })
    else
        local tween = Tween(self.Main, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0.5, 25)
        })
        Tween(self.Shadow, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0.5, 25),
            ImageTransparency = 1
        })
        task.delay(0.2, function()
            if not self.Visible then
                self.Main.Visible = false
                self.Shadow.Visible = false
            end
        end)
    end
end

function LiquidGlass:Unload()
    -- Restore hooked RunController functions
    if orig_pickAutoSide then RunController._pickAutoSide = orig_pickAutoSide end
    if orig_pickAutoTargets then RunController._pickAutoTargets = orig_pickAutoTargets end
    if orig_getSteer then RunController._getSteer = orig_getSteer end

    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

function LiquidGlass:CreateTab(name, iconText)
    local tab = {}
    tab.Name = name
    tab.Hub = self
    
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. name
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Theme.SurfaceHigh
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = self.TabContainer
    MakeRounded(btn, 18)

    local pillStroke = MakeStroke(btn, Theme.Primary, 1, 1)

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.fromOffset(24, 24)
    icon.Position = UDim2.fromOffset(10, 6)
    icon.BackgroundTransparency = 1
    icon.Text = iconText or "•"
    icon.TextColor3 = Theme.OnSurfaceVariant
    icon.Font = Enum.Font.GothamMedium
    icon.TextSize = 14
    icon.Parent = btn

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Position = UDim2.fromOffset(36, 0)
    label.Size = UDim2.new(1, -40, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Theme.OnSurfaceVariant
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Primary
    page.ScrollBarImageTransparency = 0.5
    page.Visible = false
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = self.ContentFrame

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 14)
    pagePadding.PaddingBottom = UDim.new(0, 14)
    pagePadding.PaddingLeft = UDim.new(0, 14)
    pagePadding.PaddingRight = UDim.new(0, 14)
    pagePadding.Parent = page

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Parent = page

    tab.Button = btn
    tab.Page = page
    tab.Label = label
    tab.Icon = icon
    tab.Stroke = pillStroke

    local function Activate()
        for _, t in ipairs(self.Tabs) do
            t.Page.Visible = false
            Tween(t.Button, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, BackgroundTransparency = 1})
            Tween(t.Label, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurfaceVariant})
            Tween(t.Icon, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurfaceVariant})
            Tween(t.Stroke, TweenInfo.new(0.2), {Transparency = 1})
        end

        page.Visible = true
        self.ActiveTab = tab
        Tween(btn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic), {BackgroundColor3 = Theme.PrimaryContainer, BackgroundTransparency = 0.3})
        Tween(label, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurface})
        Tween(icon, TweenInfo.new(0.2), {TextColor3 = Theme.Primary})
        Tween(pillStroke, TweenInfo.new(0.2), {Transparency = 0.6})
    end

    btn.MouseButton1Click:Connect(Activate)
    table.insert(self.Tabs, tab)

    if #self.Tabs == 1 then
        Activate()
    end

    function tab:AddSection(text)
        local sec = Instance.new("TextLabel")
        sec.Size = UDim2.new(1, 0, 0, 20)
        sec.BackgroundTransparency = 1
        sec.Text = string.upper(text)
        sec.TextColor3 = Theme.Primary
        sec.Font = Enum.Font.GothamBold
        sec.TextSize = 10
        sec.TextXAlignment = Enum.TextXAlignment.Left
        sec.Parent = page
        return sec
    end

    function tab:AddButton(text, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 38)
        b.BackgroundColor3 = Theme.SurfaceHigh
        b.BackgroundTransparency = 0.5
        b.Text = ""
        b.AutoButtonColor = false
        b.Parent = page
        MakeRounded(b, 10)
        local bStroke = MakeStroke(b, Theme.BorderSubtle, 0.88, 1)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -24, 1, 0)
        t.Position = UDim2.fromOffset(14, 0)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextColor3 = Theme.OnSurface
        t.Font = Enum.Font.GothamMedium
        t.TextSize = 12
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = b

        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.fromOffset(20, 20)
        arrow.Position = UDim2.new(1, -28, 0.5, -10)
        arrow.BackgroundTransparency = 1
        arrow.Text = "→"
        arrow.TextColor3 = Theme.OnSurfaceVariant
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 13
        arrow.Parent = b

        b.MouseEnter:Connect(function()
            Tween(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, BackgroundTransparency = 0.2})
            Tween(bStroke, TweenInfo.new(0.2), {Transparency = 0.6, Color = Theme.Primary})
            Tween(arrow, TweenInfo.new(0.2), {TextColor3 = Theme.Primary, Position = UDim2.new(1, -24, 0.5, -10)})
        end)
        b.MouseLeave:Connect(function()
            Tween(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHigh, BackgroundTransparency = 0.5})
            Tween(bStroke, TweenInfo.new(0.2), {Transparency = 0.88, Color = Theme.BorderSubtle})
            Tween(arrow, TweenInfo.new(0.2), {TextColor3 = Theme.OnSurfaceVariant, Position = UDim2.new(1, -28, 0.5, -10)})
        end)
        b.MouseButton1Click:Connect(function()
            Tween(b, TweenInfo.new(0.1), {Size = UDim2.new(1, -4, 0, 36)})
            task.delay(0.1, function()
                Tween(b, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Size = UDim2.new(1, 0, 0, 38)})
            end)
            if callback then callback() end
        end)

        return b
    end

    function tab:AddToggle(text, default, callback)
        local state = default or false

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 42)
        card.BackgroundColor3 = Theme.SurfaceHigh
        card.BackgroundTransparency = 0.55
        card.Parent = page
        MakeRounded(card, 10)
        local cStroke = MakeStroke(card, Theme.BorderSubtle, 0.90, 1)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -70, 1, 0)
        t.Position = UDim2.fromOffset(14, 0)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextColor3 = Theme.OnSurface
        t.Font = Enum.Font.GothamMedium
        t.TextSize = 12
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = card

        local switch = Instance.new("TextButton")
        switch.Name = "SwitchTrack"
        switch.Size = UDim2.fromOffset(42, 22)
        switch.Position = UDim2.new(1, -54, 0.5, -11)
        switch.BackgroundColor3 = state and Theme.Primary or Theme.SurfaceContainer
        switch.BackgroundTransparency = state and 0.1 or 0.3
        switch.Text = ""
        switch.AutoButtonColor = false
        switch.Parent = card
        MakeRounded(switch, 11)
        local swStroke = MakeStroke(switch, state and Theme.Primary or Theme.Outline, state and 0.5 or 0.7, 1)

        local thumb = Instance.new("Frame")
        thumb.Name = "Thumb"
        thumb.Size = UDim2.fromOffset(16, 16)
        thumb.Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
        thumb.BackgroundColor3 = state and Theme.OnPrimary or Theme.OnSurfaceVariant
        thumb.BorderSizePixel = 0
        thumb.Parent = switch
        MakeRounded(thumb, 8)

        local function UpdateState(val)
            state = val
            local targetPos = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
            local targetTrackCol = state and Theme.Primary or Theme.SurfaceContainer
            local targetThumbCol = state and Theme.OnPrimary or Theme.OnSurfaceVariant
            local targetTrans = state and 0.1 or 0.3

            Tween(thumb, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                Position = targetPos,
                BackgroundColor3 = targetThumbCol
            })
            Tween(switch, TweenInfo.new(0.2), {
                BackgroundColor3 = targetTrackCol,
                BackgroundTransparency = targetTrans
            })
            Tween(swStroke, TweenInfo.new(0.2), {
                Color = state and Theme.Primary or Theme.Outline
            })

            if callback then callback(state) end
        end

        switch.MouseButton1Click:Connect(function()
            UpdateState(not state)
        end)

        return {
            Set = UpdateState,
            Get = function() return state end
        }
    end

    function tab:AddSlider(text, min, max, default, callback)
        local value = default or min

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 52)
        card.BackgroundColor3 = Theme.SurfaceHigh
        card.BackgroundTransparency = 0.55
        card.Parent = page
        MakeRounded(card, 10)
        MakeStroke(card, Theme.BorderSubtle, 0.90, 1)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -70, 0, 20)
        label.Position = UDim2.fromOffset(14, 8)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Theme.OnSurface
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = card

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.fromOffset(50, 20)
        valLabel.Position = UDim2.new(1, -64, 0, 8)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(value)
        valLabel.TextColor3 = Theme.Primary
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextSize = 12
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = card

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -28, 0, 6)
        track.Position = UDim2.fromOffset(14, 34)
        track.BackgroundColor3 = Theme.SurfaceContainer
        track.BackgroundTransparency = 0.3
        track.BorderSizePixel = 0
        track.Parent = card
        MakeRounded(track, 3)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(math.clamp((value - min) / (max - min), 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Primary
        fill.BorderSizePixel = 0
        fill.Parent = track
        MakeRounded(fill, 3)

        local draggingSlider = false

        local function UpdateFromInput(input)
            local relX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            local pct = relX / track.AbsoluteSize.X
            value = math.floor(min + (max - min) * pct)
            valLabel.Text = tostring(value)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            if callback then callback(value) end
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                UpdateFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateFromInput(input)
            end
        end)

        return {
            Set = function(val)
                value = math.clamp(val, min, max)
                valLabel.Text = tostring(value)
                local pct = (value - min) / (max - min)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                if callback then callback(value) end
            end,
            Get = function() return value end
        }
    end

    return tab
end

function LiquidGlass:Notify(title, message, duration)
    duration = duration or 3
    if not self.ScreenGui then return end
    
    local toast = Instance.new("Frame")
    toast.Size = UDim2.fromOffset(260, 56)
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, 300, 1, -24)
    toast.BackgroundColor3 = Theme.Surface
    toast.BackgroundTransparency = 0.2
    toast.BorderSizePixel = 0
    toast.Parent = self.ScreenGui
    MakeRounded(toast, 14)
    MakeStroke(toast, Theme.Primary, 0.7, 1)

    local tLabel = Instance.new("TextLabel")
    tLabel.Position = UDim2.fromOffset(14, 8)
    tLabel.Size = UDim2.new(1, -28, 0, 18)
    tLabel.BackgroundTransparency = 1
    tLabel.Text = title or "Notification"
    tLabel.TextColor3 = Theme.Primary
    tLabel.Font = Enum.Font.GothamBold
    tLabel.TextSize = 12
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = toast

    local mLabel = Instance.new("TextLabel")
    mLabel.Position = UDim2.fromOffset(14, 26)
    mLabel.Size = UDim2.new(1, -28, 0, 22)
    mLabel.BackgroundTransparency = 1
    mLabel.Text = message or ""
    mLabel.TextColor3 = Theme.OnSurface
    mLabel.Font = Enum.Font.Gotham
    mLabel.TextSize = 11
    mLabel.TextXAlignment = Enum.TextXAlignment.Left
    mLabel.TextTruncate = Enum.TextTruncate.AtEnd
    mLabel.Parent = toast

    Tween(toast, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -24, 1, -24)
    })

    task.delay(duration, function()
        if toast and toast.Parent then
            local tw = Tween(toast, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 300, 1, -24)
            })
            tw.Completed:Connect(function()
                toast:Destroy()
            end)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- GLOBAL STATE CONFIGURATION
-- ─────────────────────────────────────────────────────────────────────────────
local Config = {
    -- Screen Bonuses
    AutoBonus = true,
    BonusClaimedCount = 0,
    
    -- Gate Navigation & Chests
    SmartSteer = true,
    CollectChests = true,
    
    -- Farming
    AutoTrain = false,
    SelectedZone = "Auto", -- "Auto", "Starter", "Golden", "Amethyst", "Explosive", "Void", "Nuclear", "Admin"
    AutoRun = false,
    AutoRebirth = false,
    
    -- Upgrades & Rewards
    AutoBuyWeapons = true,
    AutoBuyShields = true,
    AutoClaimPlaytime = false,
    AutoClaimDaily = false,
    AutoClaimChest = false,
    AutoClaimGroup = false,
    
    -- Movement & QoL
    WalkSpeed = 16,
    JumpPower = 50,
    SpeedEnabled = false,
    JumpEnabled = false,
    InfiniteJump = false,
    Noclip = false,
    Flight = false,
    FlightSpeed = 40,
    AntiAFK = true,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- FEATURE IMPLEMENTATIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. SCREEN BONUS AUTO-HARVESTER
local function ClickBonusHitbox(hitbox)
    if not hitbox or not hitbox:IsA("GuiButton") then return end
    pcall(function()
        if firesignal then
            firesignal(hitbox.Activated)
            firesignal(hitbox.MouseButton1Click)
        else
            for _, conn in ipairs(getconnections(hitbox.Activated)) do
                conn:Fire()
            end
        end
    end)
end

local function ProcessPopup(child)
    if not Config.AutoBonus then return end
    if child.Name == "MultiPopup" then
        task.spawn(function()
            local hitbox = child:WaitForChild("Hitbox", 2)
            if hitbox then
                task.wait(0.05)
                ClickBonusHitbox(hitbox)
                Config.BonusClaimedCount = Config.BonusClaimedCount + 1
            end
        end)
    end
end

local function InitBonusCollector(hub)
    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    local mpGui = pgui:WaitForChild("MultiPopups")
    
    -- Sweep existing
    for _, child in ipairs(mpGui:GetChildren()) do
        ProcessPopup(child)
    end
    
    -- Hook incoming
    table.insert(hub.Connections, mpGui.ChildAdded:Connect(ProcessPopup))
end

-- 2. SMART GATE STEERING & CHEST HARVESTER
local function InitSmartSteer(hub)
    -- Hook 1: _pickAutoSide strictly returns Green / Golden doors (never red)
    RunController._pickAutoSide = function(self, entry)
        if entry.Left and entry.Left.Golden then return "Left" end
        if entry.Right and entry.Right.Golden then return "Right" end
        if entry.Left and entry.Left.Good then return "Left" end
        if entry.Right and entry.Right.Good then return "Right" end
        return "Left"
    end
    
    -- Hook 2: _pickAutoTargets sets target offsets strictly for the winning doors
    RunController._pickAutoTargets = function(self, gatesTable, laneTable)
        local lateral = self.direction:Cross(Vector3.new(0, 1, 0))
        local targets = {}
        for _, v in ipairs(gatesTable) do
            local gateModel = v.Gate
            if gateModel then
                local chosenSide = self:_pickAutoSide(v)
                local door = self:_getDoor(gateModel, chosenSide)
                if door and door.panel then
                    local rel = door.panel.Position - laneTable.Center
                    table.insert(targets, {
                        Progress = rel:Dot(self.direction),
                        Offset = rel:Dot(lateral),
                        Side = chosenSide,
                        Gate = gateModel
                    })
                end
            end
        end
        table.sort(targets, function(a, b) return a.Progress < b.Progress end)
        return targets
    end
    
    -- Hook 3: Custom steering loop intercepting every frame during the Gates run
    RunController._getSteer = function(self, humanoid, rootPart, lateralVector)
        if not Config.SmartSteer then
            return orig_getSteer(self, humanoid, rootPart, lateralVector)
        end
        
        local lane = self.lane
        if not lane then return 0 end
        
        local relPos = rootPart.Position - lane.Center
        local currentProgress = relPos:Dot(self.direction)
        local currentOffset = relPos:Dot(lateralVector)
        
        -- Identify the next gate in front of the character
        local nextGate = nil
        if self.autoTargets and #self.autoTargets > 0 then
            for _, t in ipairs(self.autoTargets) do
                if currentProgress < t.Progress then
                    nextGate = t
                    break
                end
            end
        end
        
        local targetOffset = nil
        local distToGate = nextGate and (nextGate.Progress - currentProgress) or 9999
        
        -- Scan for interactive chests along the track ahead (AuraChests & Admin Drops)
        if Config.CollectChests and distToGate > 16 then
            local checkFolders = {
                Workspace:FindFirstChild("AuraChestPickups"),
                Workspace:FindFirstChild("AdminChestRain"),
            }
            local bestChestDist = 999
            for _, folder in ipairs(checkFolders) do
                if folder then
                    for _, chestModel in ipairs(folder:GetChildren()) do
                        local chestPos = chestModel:GetPivot().Position
                        local chestRel = chestPos - lane.Center
                        local chestProg = chestRel:Dot(self.direction)
                        local chestOff = chestRel:Dot(lateralVector)
                        
                        local progDiff = chestProg - currentProgress
                        if progDiff > -1 and progDiff < 45 and math.abs(chestOff) <= (lane.HalfWidth - 2) then
                            -- Only divert if safe (on same side as gate or sufficient distance before gate)
                            local safeToDivert = (not nextGate) or (progDiff < (distToGate - 14)) or (math.abs(chestOff - nextGate.Offset) < 10)
                            if safeToDivert and progDiff < bestChestDist then
                                bestChestDist = progDiff
                                targetOffset = chestOff
                            end
                        end
                    end
                end
            end
        end
        
        -- If no chest in priority, lock directly to the green gate door
        if not targetOffset and nextGate then
            targetOffset = nextGate.Offset
        end
        
        -- Execute snappy lateral alignment towards the target offset
        if targetOffset then
            local diff = targetOffset - currentOffset
            local steer = math.clamp(diff * 1.6, -1, 1)
            
            -- Respect lane borders
            local halfWidth = lane.HalfWidth - (rootPart.Size.X or 2)
            if (currentOffset >= halfWidth and steer > 0) or (currentOffset <= -halfWidth and steer < 0) then
                return 0
            end
            return steer
        end
        
        return 0
    end
end

-- 3. PROXIMITY CHEST TOUCH COLLECTOR
local function StepChestCollector()
    if not Config.CollectChests then return end
    local root = getRootPart()
    if not root then return end
    
    local checkFolders = {
        Workspace:FindFirstChild("AuraChestPickups"),
        Workspace:FindFirstChild("AdminChestRain"),
    }
    for _, folder in ipairs(checkFolders) do
        if folder then
            for _, chest in ipairs(folder:GetChildren()) do
                local pos = chest:GetPivot().Position
                local dist = (root.Position - pos).Magnitude
                if dist < 18 then
                    for _, p in ipairs(chest:GetDescendants()) do
                        if p:IsA("BasePart") then
                            pcall(function()
                                if firetouchinterest and p.CanTouch then
                                    firetouchinterest(root, p, 0)
                                    task.wait(0.01)
                                    firetouchinterest(root, p, 1)
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
end

-- 4. AUTO RUN / WIN FARMER
local function GetRunStartHitbox()
    local w1 = Workspace:FindFirstChild("Worlds") and Workspace.Worlds:FindFirstChild("World 1")
    return w1 and w1:FindFirstChild("Game") and w1.Game:FindFirstChild("Start") and w1.Game.Start:FindFirstChild("Hitbox")
end

local function StepAutoRun()
    if not Config.AutoRun then return end
    
    local inRun = LocalPlayer:GetAttribute("InRun") == true
    if not inRun then
        local root = getRootPart()
        local startHitbox = GetRunStartHitbox()
        if root and startHitbox then
            if firetouchinterest then
                firetouchinterest(root, startHitbox, 0)
                task.wait(0.05)
                firetouchinterest(root, startHitbox, 1)
            else
                root.CFrame = startHitbox.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end
end

-- 5. AUTO TRAINING DUMMY
local TrainingZonePositions = {
    Starter   = Vector3.new(-35.5, 11.5, 255.9),
    Golden    = Vector3.new(-35.5, 11.5, 274.2),
    Amethyst  = Vector3.new(-35.5, 11.5, 292.5),
    Explosive = Vector3.new(-35.5, 11.5, 310.8),
    Void      = Vector3.new(-35.5, 11.5, 329.0),
    Nuclear   = Vector3.new(-35.5, 11.5, 347.3),
    Admin     = Vector3.new(-35.5, 11.5, 365.6),
}

local function GetBestUnlockedZone()
    local data = DataMod:tryGetData()
    local rebirths = (data and data.Rebirths and data.Rebirths()) or 0
    
    if rebirths >= 13 then
        return "Nuclear"
    elseif rebirths >= 10 then
        return "Void"
    elseif rebirths >= 7 then
        return "Explosive"
    elseif rebirths >= 4 then
        return "Amethyst"
    elseif rebirths >= 2 then
        return "Golden"
    else
        return "Starter"
    end
end

local function StepAutoTrain()
    if not Config.AutoTrain then return end
    if LocalPlayer:GetAttribute("InRun") == true then return end
    
    local root = getRootPart()
    if not root then return end
    
    local targetZone = Config.SelectedZone
    if targetZone == "Auto" then
        targetZone = GetBestUnlockedZone()
    end
    
    local pos = TrainingZonePositions[targetZone] or TrainingZonePositions.Starter
    local dist = (root.Position - pos).Magnitude
    if dist > 6 then
        root.CFrame = CFrame.new(pos)
    end
end

-- 6. AUTO REBIRTH
local function StepAutoRebirth()
    if not Config.AutoRebirth then return end
    pcall(function()
        NetRebirth:fetch("rebirth")
    end)
end

-- 7. SMART BEST WEAPON & SHIELD MANAGERS
local function GetBestOwnedWeapon(ownedWeapons)
    local bestName = nil
    local bestOrder = -1
    local bestDmg = -1
    for name, isOwned in pairs(ownedWeapons or {}) do
        if isOwned then
            local info = WeaponRegistry[name]
            local order = (info and info.Order) or 0
            local dmg = (info and info.Damage) or 0
            if order > bestOrder or (order == bestOrder and dmg > bestDmg) then
                bestOrder = order
                bestDmg = dmg
                bestName = name
            end
        end
    end
    return bestName
end

local function GetBestOwnedShield(ownedShields)
    local bestName = nil
    local bestOrder = -1
    local bestHp = -1
    for name, isOwned in pairs(ownedShields or {}) do
        if isOwned then
            local info = ShieldRegistry[name]
            local order = (info and info.Order) or 0
            local hp = (info and info.Health) or 0
            if order > bestOrder or (order == bestOrder and hp > bestHp) then
                bestOrder = order
                bestHp = hp
                bestName = name
            end
        end
    end
    return bestName
end

local function EquipBestOwnedEquipment()
    local data = DataMod:tryGetData()
    if not data then return end
    
    local ownedW = (data.OwnedWeapons and data.OwnedWeapons()) or {}
    local equippedW = data.EquippedWeapon and data.EquippedWeapon()
    local bestW = GetBestOwnedWeapon(ownedW)
    if bestW and bestW ~= equippedW then
        pcall(function()
            NetWeaponStore:fetch("equipWeapon", bestW)
        end)
    end
    
    local ownedS = (data.OwnedShields and data.OwnedShields()) or {}
    local equippedS = data.EquippedShield and data.EquippedShield()
    local bestS = GetBestOwnedShield(ownedS)
    if bestS and bestS ~= equippedS then
        pcall(function()
            NetShieldStore:fetch("equipShield", bestS)
        end)
    end
end

local function StepAutoBuyWeapons()
    local data = DataMod:tryGetData()
    if not data or not data.Wins then return end
    
    local wins = data.Wins()
    local owned = (data.OwnedWeapons and data.OwnedWeapons()) or {}
    local equipped = data.EquippedWeapon and data.EquippedWeapon()
    
    if Config.AutoBuyWeapons then
        -- Find best affordable unowned weapon
        local bestAffordable = nil
        local maxOrder = -1
        for weaponName, info in pairs(WeaponRegistry) do
            if typeof(info) == "table" and info.Price and info.Price > 0 and info.Price <= wins then
                local order = info.Order or 0
                if not owned[weaponName] and order > maxOrder then
                    maxOrder = order
                    bestAffordable = weaponName
                end
            end
        end
        if bestAffordable then
            pcall(function()
                local bought = NetWeaponStore:fetch("buyWeapon", bestAffordable)
                if bought then
                    owned[bestAffordable] = true
                end
            end)
        end
    end
    
    -- Always ensure the highest tier owned weapon is equipped!
    local bestOwned = GetBestOwnedWeapon(owned)
    if bestOwned and bestOwned ~= equipped then
        pcall(function()
            NetWeaponStore:fetch("equipWeapon", bestOwned)
        end)
    end
end

local function StepAutoBuyShields()
    local data = DataMod:tryGetData()
    if not data or not data.Wins then return end
    
    local wins = data.Wins()
    local owned = (data.OwnedShields and data.OwnedShields()) or {}
    local equipped = data.EquippedShield and data.EquippedShield()
    
    if Config.AutoBuyShields then
        -- Find best affordable unowned shield
        local bestAffordable = nil
        local maxOrder = -1
        for shieldName, info in pairs(ShieldRegistry) do
            if typeof(info) == "table" and info.Price and info.Price > 0 and info.Price <= wins then
                local order = info.Order or 0
                if not owned[shieldName] and order > maxOrder then
                    maxOrder = order
                    bestAffordable = shieldName
                end
            end
        end
        if bestAffordable then
            pcall(function()
                local bought = NetShieldStore:fetch("buyShield", bestAffordable)
                if bought then
                    owned[shieldName] = true
                end
            end)
        end
    end
    
    -- Always ensure the highest tier owned shield is equipped!
    local bestOwned = GetBestOwnedShield(owned)
    if bestOwned and bestOwned ~= equipped then
        pcall(function()
            NetShieldStore:fetch("equipShield", bestOwned)
        end)
    end
end

-- 8. REWARDS CLAIMER
local function StepClaimPlaytime()
    if not Config.AutoClaimPlaytime then return end
    for i = 1, 12 do
        pcall(function()
            NetPlaytime:fetch("claim", i)
        end)
    end
end

local function StepClaimDaily()
    if Config.AutoClaimDaily then
        pcall(function() NetDaily:fetch("claim") end)
    end
    if Config.AutoClaimChest then
        pcall(function() NetDailyChest:fetch("claim") end)
    end
    if Config.AutoClaimGroup then
        pcall(function() NetGroup:fetch("claim") end)
    end
end

-- 9. REDEEM WORKING CODES
local KnownCodes = {
    "RELEASE", "1SWORD", "PLATFORMS", "SWORD", "WINS", "UPDATE1",
    "LIKE100", "LIKE500", "LIKE1K", "2MVISITS", "FREE"
}

local function RedeemAllCodes(hub)
    task.spawn(function()
        hub:Notify("Code Engine", "Starting code redemption sequence...", 2)
        local count = 0
        for _, code in ipairs(KnownCodes) do
            local success, res = pcall(function()
                return NetCodes:fetch("redeem", code)
            end)
            if success and res and res.Success then
                count = count + 1
                hub:Notify("Code Redeemed!", code .. ": " .. tostring(res.Message), 3)
            end
            task.wait(1.5) -- Respect anti-spam throttle
        end
        hub:Notify("Redemption Done", "Processed " .. tostring(#KnownCodes) .. " codes (" .. tostring(count) .. " claimed).", 3.5)
    end)
end

-- 10. NOCLIP ENGINE
local function InitNoclip(hub)
    table.insert(hub.Connections, RunService.Stepped:Connect(function()
        if Config.Noclip then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end))
end

-- 11. INFINITE JUMP
local function InitInfiniteJump(hub)
    table.insert(hub.Connections, UserInputService.JumpRequest:Connect(function()
        if Config.InfiniteJump then
            local hum = getHumanoid()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))
end

-- 12. FLIGHT ENGINE
local function InitFlight(hub)
    local bv, bg
    table.insert(hub.Connections, RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if Config.Flight and root and hum and hum.Health > 0 then
            if not bv or bv.Parent ~= root then
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Parent = root
            end
            if not bg or bg.Parent ~= root then
                bg = Instance.new("BodyGyro")
                bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                bg.P = 10000
                bg.D = 500
                bg.Parent = root
            end
            
            bg.CFrame = Camera.CFrame
            
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                dir = dir + Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                dir = dir - Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                dir = dir - Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                dir = dir + Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                dir = dir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                dir = dir - Vector3.new(0, 1, 0)
            end
            
            bv.Velocity = dir.Unit * Config.FlightSpeed
            if dir.Magnitude == 0 then
                bv.Velocity = Vector3.zero
            end
        else
            if bv then bv:Destroy() bv = nil end
            if bg then bg:Destroy() bg = nil end
        end
    end))
end

-- 13. ANTI-AFK
local function InitAntiAFK(hub)
    local VirtualUser = game:GetService("VirtualUser")
    table.insert(hub.Connections, LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end)
        end
    end))
end

-- 14. SPEED & JUMP MODIFIER
local function InitSpeedJump(hub)
    table.insert(hub.Connections, RunService.Heartbeat:Connect(function()
        local hum = getHumanoid()
        if hum then
            if Config.SpeedEnabled then
                hum.WalkSpeed = Config.WalkSpeed
            end
            if Config.JumpEnabled then
                hum.JumpPower = Config.JumpPower
            end
        end
    end))
end

-- 15. MASTER BACKGROUND LOOP
local function StartMasterLoop(hub)
    task.spawn(function()
        while hub.ScreenGui and hub.ScreenGui.Parent do
            StepAutoRun()
            StepChestCollector()
            StepAutoTrain()
            StepAutoRebirth()
            StepAutoBuyWeapons()
            StepAutoBuyShields()
            StepClaimPlaytime()
            StepClaimDaily()
            task.wait(0.5)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UI ASSEMBLY & TAB POPULATION
-- ─────────────────────────────────────────────────────────────────────────────
local Hub = LiquidGlass.new({
    Title = "1 SWORD VS PLATFORMS",
    Subtitle = "Liquid Glass • Material Design 3 Suite v2.0",
    Keybind = Enum.KeyCode.RightShift,
    Size = UDim2.fromOffset(630, 420)
})

getgenv()._SwordVsPlatformsSuite = Hub

-- TAB 1: ⚡ AUTOMATION
local tabAuto = Hub:CreateTab("Automation", "⚡")

tabAuto:AddSection("Gate Navigation & Track Chests")
tabAuto:AddToggle("Smart Green Gate Steer", Config.SmartSteer, function(v)
    Config.SmartSteer = v
    Hub:Notify("Smart Steer", v and "Steering strictly locked to Green & Golden gates!" or "Smart Steer disabled.", 2.5)
end)

tabAuto:AddToggle("Auto Collect Path Chests", Config.CollectChests, function(v)
    Config.CollectChests = v
    Hub:Notify("Chests Harvester", v and "Track chest collector active." or "Chest collector disabled.", 2)
end)

tabAuto:AddSection("Game Runner & Wins Farm")
tabAuto:AddToggle("Auto Run / Wins Harvester", Config.AutoRun, function(v)
    Config.AutoRun = v
    Hub:Notify("Run Harvester", v and "Auto Run enabled! Slicing gates & win paths..." or "Auto Run disabled.", 2.5)
end)

tabAuto:AddSection("Screen Bonus Harvester")
tabAuto:AddToggle("Auto Click Screen Bonuses (MultiPopups)", Config.AutoBonus, function(v)
    Config.AutoBonus = v
    Hub:Notify("Bonus Harvester", v and "Auto Clicker activated." or "Auto Clicker disabled.", 2)
end)

tabAuto:AddSection("Training AFK Farm")
tabAuto:AddToggle("Auto Train on Dummy", Config.AutoTrain, function(v)
    Config.AutoTrain = v
    Hub:Notify("Auto Train", v and ("Auto training active on " .. Config.SelectedZone .. " dummy.") or "Auto train stopped.", 2)
end)

tabAuto:AddButton("Switch Zone: Auto Best (Based on Rebirths)", function()
    Config.SelectedZone = "Auto"
    Hub:Notify("Training Zone", "Set to Auto Best (Dynamically selects zone).", 2)
end)

tabAuto:AddButton("Lock Zone: Amethyst (Rebirth 4+)", function()
    Config.SelectedZone = "Amethyst"
    Hub:Notify("Training Zone", "Locked to Amethyst Dummy.", 2)
end)

tabAuto:AddButton("Lock Zone: Explosive (Rebirth 7+)", function()
    Config.SelectedZone = "Explosive"
    Hub:Notify("Training Zone", "Locked to Explosive Dummy.", 2)
end)

tabAuto:AddButton("Lock Zone: Void (Rebirth 10+)", function()
    Config.SelectedZone = "Void"
    Hub:Notify("Training Zone", "Locked to Void Dummy.", 2)
end)

tabAuto:AddButton("Lock Zone: Nuclear (Rebirth 13+)", function()
    Config.SelectedZone = "Nuclear"
    Hub:Notify("Training Zone", "Locked to Nuclear Dummy.", 2)
end)

tabAuto:AddSection("Rebirth Progression")
tabAuto:AddToggle("Auto Rebirth When Ready", Config.AutoRebirth, function(v)
    Config.AutoRebirth = v
    Hub:Notify("Auto Rebirth", v and "Rebirth loop activated." or "Auto Rebirth disabled.", 2)
end)

-- TAB 2: 🎁 REWARDS & UPGRADES
local tabRewards = Hub:CreateTab("Rewards", "🎁")

tabRewards:AddSection("Smart Equipment Manager")
tabRewards:AddButton("Force Equip Best Weapon & Shield", function()
    EquipBestOwnedEquipment()
    local data = DataMod:tryGetData()
    local w = data and data.EquippedWeapon and data.EquippedWeapon() or "None"
    local s = data and data.EquippedShield and data.EquippedShield() or "None"
    Hub:Notify("Equipment Synced", "Weapon: " .. w .. " | Shield: " .. s, 3.5)
end)

tabRewards:AddToggle("Auto Buy & Equip Best Weapon", Config.AutoBuyWeapons, function(v)
    Config.AutoBuyWeapons = v
    Hub:Notify("Weapon Shop", v and "Auto weapon purchaser active." or "Weapon purchaser disabled.", 2)
end)

tabRewards:AddToggle("Auto Buy & Equip Best Shield", Config.AutoBuyShields, function(v)
    Config.AutoBuyShields = v
    Hub:Notify("Shield Shop", v and "Auto shield purchaser active." or "Shield purchaser disabled.", 2)
end)

tabRewards:AddSection("Freebies & Gift Claims")
tabRewards:AddToggle("Auto Claim Playtime Gifts (1..12)", Config.AutoClaimPlaytime, function(v)
    Config.AutoClaimPlaytime = v
    Hub:Notify("Playtime Gifts", v and "Auto claim enabled." or "Auto claim disabled.", 2)
end)

tabRewards:AddToggle("Auto Claim Daily Rewards", Config.AutoClaimDaily, function(v)
    Config.AutoClaimDaily = v
end)

tabRewards:AddToggle("Auto Claim Daily Chest", Config.AutoClaimChest, function(v)
    Config.AutoClaimChest = v
end)

tabRewards:AddToggle("Auto Claim Group Chest", Config.AutoClaimGroup, function(v)
    Config.AutoClaimGroup = v
end)

tabRewards:AddSection("Promo Codes")
tabRewards:AddButton("Redeem All Active Codes", function()
    RedeemAllCodes(Hub)
end)

-- TAB 3: 🚀 MOVEMENT & QOL
local tabMovement = Hub:CreateTab("Movement", "🚀")

tabMovement:AddSection("Speed & Jump")
tabMovement:AddToggle("Enable Custom WalkSpeed", Config.SpeedEnabled, function(v)
    Config.SpeedEnabled = v
    if not v then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end
end)

tabMovement:AddSlider("WalkSpeed Value", 16, 150, Config.WalkSpeed, function(val)
    Config.WalkSpeed = val
    if Config.SpeedEnabled then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = val end
    end
end)

tabMovement:AddToggle("Enable Custom JumpPower", Config.JumpEnabled, function(v)
    Config.JumpEnabled = v
    if not v then
        local hum = getHumanoid()
        if hum then hum.JumpPower = 50 end
    end
end)

tabMovement:AddSlider("JumpPower Value", 50, 250, Config.JumpPower, function(val)
    Config.JumpPower = val
    if Config.JumpEnabled then
        local hum = getHumanoid()
        if hum then hum.JumpPower = val end
    end
end)

tabMovement:AddSection("Physics & Disconnect Defense")
tabMovement:AddToggle("Infinite Jump (Air Jump)", Config.InfiniteJump, function(v)
    Config.InfiniteJump = v
end)

tabMovement:AddToggle("Noclip (Walk Through Barriers)", Config.Noclip, function(v)
    Config.Noclip = v
end)

tabMovement:AddToggle("3D Fly (WASD + Space/Shift)", Config.Flight, function(v)
    Config.Flight = v
end)

tabMovement:AddSlider("Flight Speed", 15, 120, Config.FlightSpeed, function(val)
    Config.FlightSpeed = val
end)

tabMovement:AddToggle("Anti-AFK (20-Min Idle Kick Defense)", Config.AntiAFK, function(v)
    Config.AntiAFK = v
end)

-- TAB 4: 📍 TELEPORTS
local tabTeleports = Hub:CreateTab("Teleports", "📍")

local function TeleportTo(cf, name)
    local root = getRootPart()
    if root then
        root.CFrame = cf
        Hub:Notify("Teleport", "Transported to " .. name .. ".", 2)
    end
end

tabTeleports:AddSection("Hub & Gameplay Spawns")
tabTeleports:AddButton("Teleport: Spawn / Lobby", function()
    TeleportTo(CFrame.new(-89.9, 8.0, 310.8), "Spawn")
end)

tabTeleports:AddButton("Teleport: Game Start (Gate Run)", function()
    TeleportTo(CFrame.new(-164.5, 23.0, 310.8), "Game Start")
end)

tabTeleports:AddSection("Shops & Amenities")
tabTeleports:AddButton("Teleport: Sword Shop", function()
    TeleportTo(CFrame.new(-99.3, 11.5, 361.5), "Sword Shop")
end)

tabTeleports:AddButton("Teleport: Shield Shop", function()
    TeleportTo(CFrame.new(-82.1, 11.5, 361.5), "Shield Shop")
end)

tabTeleports:AddButton("Teleport: Group Chest", function()
    TeleportTo(CFrame.new(-134.6, 13.5, 266.6), "Group Chest")
end)

tabTeleports:AddButton("Teleport: World Portal", function()
    TeleportTo(CFrame.new(-88.2, 19.0, 255.5), "World Portal")
end)

tabTeleports:AddSection("Training Dummies")
for _, zoneName in ipairs({"Starter", "Golden", "Amethyst", "Explosive", "Void", "Nuclear", "Admin"}) do
    tabTeleports:AddButton("Teleport: " .. zoneName .. " Dummy", function()
        TeleportTo(CFrame.new(TrainingZonePositions[zoneName]), zoneName .. " Dummy")
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- INITIALIZATION
-- ─────────────────────────────────────────────────────────────────────────────
InitBonusCollector(Hub)
InitSmartSteer(Hub)
InitNoclip(Hub)
InitInfiniteJump(Hub)
InitFlight(Hub)
InitAntiAFK(Hub)
InitSpeedJump(Hub)
EquipBestOwnedEquipment()
StartMasterLoop(Hub)

Hub:Notify("Suite Loaded v2.0", "Smart Green Steer & Best Equipment active. Press [RightShift] for menu.", 4)
print("[PotassiumHub] 1 Sword Vs Platforms Suite v2.0 successfully loaded with Liquid Glass!")

return Hub
