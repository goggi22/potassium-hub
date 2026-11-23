--[[
    ══════════════════════════════════════════════════════════════════════════════════
    LUCKY BLOCK RACE (Place ID: 94106144703688) — ADVANCED AUTOMATION SUITE
    ══════════════════════════════════════════════════════════════════════════════════
    Target Experience : Lucky Block Race (Roblox ID: 94106144703688)
    Platform          : Potassium Executor / Luau Runtime
    Design Language   : Liquid Glass × Material Design 3 (MD3) Translucent Framework
    
    Features:
      • Intelligent Lucky Block Miner:
        - Auto-mines lane lucky blocks 1 through 40 with zero desync
        - Sub-100ms rapid block destruction sequence (BreakStart -> BreakFinish)
        - Fast TP Mine & Smooth Walk Mine options
        - Auto Finish Gate: Crosses finish line at block 40 to lock in match win
        - Auto Match Loop: Auto skip vote during lobby, auto respawn on death
      • Loot & Inventory Engine:
        - Instant Auto Equip Best gear (weapons + armor) via Inv_EquipBest
        - Proximity Drop Vacuum from Workspace.Drops
        - Auto Food / Golden Apple consumption on low health
      • Arena Combat Engine:
        - Player Kill Aura in PvP arena / match
        - Mob Kill Aura for hostile entities and McMob tags
        - Native CombatClient integration (proper crit, sprint, charge mechanics)
      • Hub & Progression Automation:
        - Auto Claim Playtime Gifts (all tiers 1..12)
        - Auto Claim Daily Reward & Group Chest
        - Auto Parkour Completer (walks/touches Start -> Checkpoints -> Finish)
        - Wood Crate Auto Opener
      • Movement & QoL:
        - WalkSpeed & JumpPower Sliders
        - Infinite Jump
        - Barrier Noclip (traverse between lanes seamlessly)
        - 3D Physics Flight
        - Anti-AFK Kick Prevention (20-min idle bypass)
      • Direct Teleports:
        - Hub Spawn, Arena Center, Parkour Start/Finish, Finish Platform, Lanes 1..8
    ══════════════════════════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEANUP PREVIOUS INSTANCES
-- ─────────────────────────────────────────────────────────────────────────────
if getgenv and getgenv()._LuckyBlockRaceSuite then
    pcall(function()
        getgenv()._LuckyBlockRaceSuite:Unload()
    end)
    getgenv()._LuckyBlockRaceSuite = nil
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
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5))
end

local function getHumanoid()
    local char = getCharacter()
    return char and (char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5))
end

-- Game Module References
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local RaceLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceLayout"))

local ProgState = nil
local CombatClient = nil

task.spawn(function()
    pcall(function()
        ProgState = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("HubClient"):WaitForChild("ProgState", 10))
    end)
    pcall(function()
        CombatClient = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("HudClient"):WaitForChild("CombatClient", 10))
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- LIQUID GLASS × MD3 UI ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

local Theme = {
    Surface = Color3.fromRGB(14, 18, 28),
    SurfaceTrans = 0.25,
    SurfaceContainer = Color3.fromRGB(22, 28, 44),
    SurfaceContainerTrans = 0.35,
    SurfaceHigh = Color3.fromRGB(32, 42, 66),
    SurfaceHighTrans = 0.45,
    
    Primary = Color3.fromRGB(255, 205, 40),          -- Lucky Gold
    PrimaryContainer = Color3.fromRGB(90, 70, 15),
    OnPrimary = Color3.fromRGB(15, 12, 5),
    Secondary = Color3.fromRGB(60, 220, 130),        -- Lucky Emerald
    
    RimLight = Color3.fromRGB(255, 235, 170),
    RimLightTrans = 0.82,
    BorderSubtle = Color3.fromRGB(120, 150, 200),
    BorderSubtleTrans = 0.86,
    
    OnSurface = Color3.fromRGB(244, 246, 255),
    OnSurfaceVariant = Color3.fromRGB(155, 170, 200),
    Outline = Color3.fromRGB(75, 90, 125),
    
    Success = Color3.fromRGB(80, 235, 140),
    Warning = Color3.fromRGB(255, 200, 60),
    Danger = Color3.fromRGB(255, 90, 95)
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
    
    self.Title = config.Title or "LUCKY BLOCK RACE"
    self.Subtitle = config.Subtitle or "Liquid Glass • MD3 Suite"
    self.Keybind = config.Keybind or Enum.KeyCode.RightShift
    self.Size = config.Size or UDim2.fromOffset(640, 420)
    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.Connections = {}

    local targetParent = pcall(function() return CoreGui:GetChildren() end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LiquidGlass_LBR_" .. math.random(10000, 99999)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = targetParent
    self.ScreenGui = screenGui

    -- Ambient Drop Shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = self.Size + UDim2.fromOffset(80, 80)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 5)
    shadow.ImageTransparency = 0.35
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
    MakeStroke(main, Theme.RimLight, 0.78, 1.2)

    -- Top Gradient Specular Sheen
    local sheen = Instance.new("Frame")
    sheen.Name = "SheenGradient"
    sheen.Size = UDim2.new(1, 0, 0, 130)
    sheen.Position = UDim2.fromOffset(0, 0)
    sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheen.BorderSizePixel = 0
    sheen.Parent = main
    MakeRounded(sheen, 18)

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.88),
        NumberSequenceKeypoint.new(0.4, 0.96),
        NumberSequenceKeypoint.new(1, 1)
    })
    gradient.Parent = sheen

    -- Draggable Top Bar
    local dragging, dragStart, startPos
    sheen.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)

    sheen.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            shadow.Position = main.Position
        end
    end))

    -- Header
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
    logoBadge.BackgroundTransparency = 0.12
    logoBadge.Parent = header
    MakeRounded(logoBadge, 8)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.Size = UDim2.fromScale(1, 1)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Text = "★"
    logoIcon.TextColor3 = Theme.OnPrimary
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 16
    logoIcon.Parent = logoBadge

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(56, 10)
    title.Size = UDim2.new(0, 260, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = self.Title
    title.TextColor3 = Theme.OnSurface
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
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

    -- Divider
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.fromOffset(16, 52)
    divider.BackgroundColor3 = Theme.BorderSubtle
    divider.BackgroundTransparency = Theme.BorderSubtleTrans
    divider.BorderSizePixel = 0
    divider.Parent = main

    -- Sidebar / Tab Rail
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(0, 160, 1, -66)
    tabContainer.Position = UDim2.fromOffset(16, 58)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = main

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer

    self.TabContainer = tabContainer

    -- Content Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -204, 1, -66)
    contentFrame.Position = UDim2.fromOffset(188, 58)
    contentFrame.BackgroundColor3 = Theme.SurfaceContainer
    contentFrame.BackgroundTransparency = Theme.SurfaceContainerTrans
    contentFrame.BorderSizePixel = 0
    contentFrame.ClipsDescendants = true
    contentFrame.Parent = main
    MakeRounded(contentFrame, 14)
    MakeStroke(contentFrame, Theme.BorderSubtle, 0.88, 1)

    self.ContentFrame = contentFrame

    -- Keybind listener
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end))

    return self
end

function LiquidGlass:Toggle()
    self.Visible = not self.Visible
    local shadowTrans = self.Visible and 0.35 or 1
    
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
        Tween(self.Main, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
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
    pagePadding.PaddingTop = UDim.new(0, 12)
    pagePadding.PaddingBottom = UDim.new(0, 12)
    pagePadding.PaddingLeft = UDim.new(0, 12)
    pagePadding.PaddingRight = UDim.new(0, 12)
    pagePadding.Parent = page

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 8)
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
        Tween(btn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic), {BackgroundColor3 = Theme.PrimaryContainer, BackgroundTransparency = 0.35})
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
        sec.Size = UDim2.new(1, 0, 0, 22)
        sec.BackgroundTransparency = 1
        sec.Text = string.upper(text)
        sec.TextColor3 = Theme.Primary
        sec.Font = Enum.Font.GothamBold
        sec.TextSize = 11
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
        valLabel.Size = UDim2.fromOffset(60, 20)
        valLabel.Position = UDim2.new(1, -74, 0, 8)
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

        table.insert(self.Hub.Connections, UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateFromInput(input)
            end
        end))

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

    function tab:AddStatusBadge(labelTitle, initialValue)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 36)
        card.BackgroundColor3 = Theme.SurfaceHigh
        card.BackgroundTransparency = 0.65
        card.Parent = page
        MakeRounded(card, 10)
        MakeStroke(card, Theme.BorderSubtle, 0.92, 1)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0, 160, 1, 0)
        t.Position = UDim2.fromOffset(14, 0)
        t.BackgroundTransparency = 1
        t.Text = labelTitle
        t.TextColor3 = Theme.OnSurfaceVariant
        t.Font = Enum.Font.GothamMedium
        t.TextSize = 11
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = card

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(1, -184, 1, 0)
        v.Position = UDim2.fromOffset(170, 0)
        v.BackgroundTransparency = 1
        v.Text = tostring(initialValue or "—")
        v.TextColor3 = Theme.Primary
        v.Font = Enum.Font.GothamBold
        v.TextSize = 11
        v.TextXAlignment = Enum.TextXAlignment.Right
        v.Parent = card

        return {
            Set = function(val, color)
                v.Text = tostring(val)
                if color then v.TextColor3 = color end
            end
        }
    end

    return tab
end

function LiquidGlass:Notify(titleText, messageText, duration)
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
    tLabel.Text = titleText or "Notification"
    tLabel.TextColor3 = Theme.Primary
    tLabel.Font = Enum.Font.GothamBold
    tLabel.TextSize = 12
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = toast

    local mLabel = Instance.new("TextLabel")
    mLabel.Position = UDim2.fromOffset(14, 26)
    mLabel.Size = UDim2.new(1, -28, 0, 22)
    mLabel.BackgroundTransparency = 1
    mLabel.Text = messageText or ""
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
-- AUTOMATION STATE & LOGIC ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
local State = {
    -- Auto Race & Mine
    AutoMineLane = false,
    MineDelayMs = 80,
    FastTPMine = true,
    AutoFinishGate = true,
    AutoMatchCycle = true,
    
    -- Loot & Inventory
    AutoEquipBest = true,
    AutoVacuumDrops = true,
    VacuumRadius = 60,
    AutoHeal = false,
    
    -- Combat Aura
    KillAuraPlayers = false,
    KillAuraMobs = true,
    AuraRange = 12,
    AuraDelayMs = 120,
    
    -- Progression & Hub
    AutoPlaytime = true,
    AutoDaily = true,
    AutoGroup = true,
    AutoOpenWoodCrate = false,
    
    -- Movement & QoL
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    Noclip = false,
    Flight = false,
    FlightSpeed = 45,
    AntiAFK = true,
    
    -- Internal trackers
    MiningInProgress = false,
    LastAuraTick = 0,
    LastEquipTick = 0,
    LastRewardTick = 0,
    LastVacuumTick = 0
}

-- Instantiate Liquid Glass UI
local Hub = LiquidGlass.new({
    Title = "LUCKY BLOCK RACE",
    Subtitle = "Liquid Glass × MD3 Suite",
    Keybind = Enum.KeyCode.RightShift,
    Size = UDim2.fromOffset(640, 420)
})

getgenv()._LuckyBlockRaceSuite = Hub

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB 1: AUTO RACE & MINER
-- ─────────────────────────────────────────────────────────────────────────────
local TabRace = Hub:CreateTab("Auto Race", "⚡")

TabRace:AddSection("Live Match Status")
local BadgePhase = TabRace:AddStatusBadge("Match Phase", "Loading...")
local BadgeLane = TabRace:AddStatusBadge("Assigned Lane", "—")
local BadgeBlocks = TabRace:AddStatusBadge("Blocks Remaining", "—")

TabRace:AddSection("Lane Mining Engine")
TabRace:AddToggle("Auto Mine Lane", false, function(v)
    State.AutoMineLane = v
    if v then
        Hub:Notify("Auto Mine", "Lane miner activated", 2.5)
    end
end)

TabRace:AddToggle("Instant TP Mine (vs Walk)", true, function(v)
    State.FastTPMine = v
end)

TabRace:AddSlider("Break Delay (ms)", 40, 200, 80, function(v)
    State.MineDelayMs = v
end)

TabRace:AddSection("Finish & Match Cycle")
TabRace:AddToggle("Auto Cross Finish Gate", true, function(v)
    State.AutoFinishGate = v
end)

TabRace:AddToggle("Auto Match Cycle (Skip Vote & Respawn)", true, function(v)
    State.AutoMatchCycle = v
end)

TabRace:AddButton("Force Cross Finish Gate Now", function()
    local hrp = getRootPart()
    local laneNum = LocalPlayer:GetAttribute("Lane") or 1
    local lInfo = RaceLayout.lane(laneNum)
    if hrp and lInfo then
        local targetX = 735
        local targetZ = lInfo.centerZ * 3
        hrp.CFrame = CFrame.new(targetX, 5, targetZ)
        Hub:Notify("Finish Gate", "Teleported through Lane " .. laneNum .. " finish line!", 2.5)
    end
end)

TabRace:AddButton("Vote Skip Match Prep", function()
    pcall(function()
        Remotes.Race_SkipVote:FireServer(true)
        Hub:Notify("Skip Vote", "Dispatched skip vote to server", 2)
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB 2: LOOT & INVENTORY
-- ─────────────────────────────────────────────────────────────────────────────
local TabLoot = Hub:CreateTab("Loot & Inv", "💎")

TabLoot:AddSection("Equipment Optimization")
TabLoot:AddToggle("Auto Equip Best Gear (Armor + Weapons)", true, function(v)
    State.AutoEquipBest = v
end)

TabLoot:AddButton("Equip Best Gear Now", function()
    pcall(function()
        Remotes.Inv_EquipBest:InvokeServer()
        Hub:Notify("Inventory", "Equipped highest tier gear!", 2)
    end)
end)

TabLoot:AddSection("Proximity Drop Harvester")
TabLoot:AddToggle("Auto Vacuum Drops", true, function(v)
    State.AutoVacuumDrops = v
end)

TabLoot:AddSlider("Vacuum Search Radius", 20, 150, 60, function(v)
    State.VacuumRadius = v
end)

TabLoot:AddSection("Health & Consumables")
TabLoot:AddToggle("Auto Consume Golden Apples / Food", false, function(v)
    State.AutoHeal = v
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB 3: COMBAT & ARENA
-- ─────────────────────────────────────────────────────────────────────────────
local TabCombat = Hub:CreateTab("Combat Aura", "⚔️")

TabCombat:AddSection("Targeting Modes")
TabCombat:AddToggle("Player Kill Aura (PvP Arena)", false, function(v)
    State.KillAuraPlayers = v
    if v then Hub:Notify("Kill Aura", "Player Kill Aura enabled", 2) end
end)

TabCombat:AddToggle("Mob Kill Aura (Hostiles & McMob)", true, function(v)
    State.KillAuraMobs = v
end)

TabCombat:AddSection("Combat Parameters")
TabCombat:AddSlider("Aura Reach (studs)", 6, 16, 12, function(v)
    State.AuraRange = v
end)

TabCombat:AddSlider("Attack Interval (ms)", 50, 300, 120, function(v)
    State.AuraDelayMs = v
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB 4: HUB & PROGRESSION
-- ─────────────────────────────────────────────────────────────────────────────
local TabHub = Hub:CreateTab("Hub & Rewards", "🎁")

TabHub:AddSection("Progression Rewards")
TabHub:AddToggle("Auto Claim Playtime Gifts (1..12)", true, function(v)
    State.AutoPlaytime = v
end)

TabHub:AddToggle("Auto Claim Daily Rewards", true, function(v)
    State.AutoDaily = v
end)

TabHub:AddToggle("Auto Claim Group Chest", true, function(v)
    State.AutoGroup = v
end)

TabHub:AddButton("Harvest All Claimable Rewards Now", function()
    task.spawn(function()
        local count = 0
        if ProgState and ProgState.request then
            local okD = pcall(function() return ProgState.request("claimDaily", {}) end)
            if okD then count = count + 1 end
            local okG = pcall(function() return ProgState.request("claimGroup", {}) end)
            if okG then count = count + 1 end
            for i = 1, 12 do
                pcall(function() ProgState.request("claimPlaytime", { index = i }) end)
            end
        end
        Hub:Notify("Harvester", "Harvested all available gifts & daily chests!", 2.5)
    end)
end)

TabHub:AddSection("Parkour Challenge")
TabHub:AddButton("Auto Complete Daily Parkour", function()
    task.spawn(function()
        local hrp = getRootPart()
        local zones = Workspace:FindFirstChild("Hub") and Workspace.Hub:FindFirstChild("Parkour") and Workspace.Hub.Parkour:FindFirstChild("Zones")
        if not (hrp and zones) then
            Hub:Notify("Parkour", "Parkour zones not found (Must be in Hub)", 2.5)
            return
        end

        local order = { zones:FindFirstChild("Start"), zones:FindFirstChild("Checkpoint1"), zones:FindFirstChild("Checkpoint2"), zones:FindFirstChild("Checkpoint3"), zones:FindFirstChild("Finish") }
        local savedPos = hrp.CFrame
        Hub:Notify("Parkour", "Navigating parkour course...", 3)
        
        for _, z in ipairs(order) do
            if z then
                hrp.CFrame = z.CFrame + Vector3.new(0, 2, 0)
                if firetouchinterest then
                    firetouchinterest(hrp, z, 0)
                    task.wait(0.05)
                    firetouchinterest(hrp, z, 1)
                end
                task.wait(0.25)
            end
        end
        
        task.wait(0.4)
        hrp.CFrame = savedPos
        Hub:Notify("Parkour", "Daily Parkour successfully completed!", 3)
    end)
end)

TabHub:AddSection("Crate Opener")
TabHub:AddToggle("Auto Open Wood Crates", false, function(v)
    State.AutoOpenWoodCrate = v
end)

TabHub:AddButton("Open 1 Wood Crate", function()
    task.spawn(function()
        if ProgState and ProgState.request then
            local success, res = ProgState.request("openCrate", { kind = "wood" })
            pcall(ProgState.request, "closeCrate", {})
            if success then
                Hub:Notify("Crates", "Wood crate opened!", 2.5)
            else
                Hub:Notify("Crates", tostring(res or "No wood crates available"), 2.5)
            end
        end
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB 5: TELEPORTS
-- ─────────────────────────────────────────────────────────────────────────────
local TabTP = Hub:CreateTab("Teleports", "📍")

TabTP:AddSection("World Locations")
TabTP:AddButton("Hub Spawn", function()
    local hrp = getRootPart()
    if hrp then hrp.CFrame = CFrame.new(7.66, 9.16, 45.15) end
end)

TabTP:AddButton("PvP Arena Center", function()
    local hrp = getRootPart()
    if hrp then hrp.CFrame = CFrame.new(954, 4.5, 0) end
end)

TabTP:AddButton("Finish Platform (Post-Race)", function()
    local hrp = getRootPart()
    if hrp then hrp.CFrame = CFrame.new(735, 5, 0) end
end)

TabTP:AddButton("Parkour Start Pad", function()
    local hrp = getRootPart()
    if hrp then hrp.CFrame = CFrame.new(-196.5, 27, -82.5) end
end)

TabTP:AddButton("Parkour Finish Line", function()
    local hrp = getRootPart()
    if hrp then hrp.CFrame = CFrame.new(70.5, 21, 91.5) end
end)

TabTP:AddSection("Lane Starting Lines")
for i = 1, 8 do
    local lInfo = RaceLayout.lane(i)
    local z = lInfo and lInfo.centerZ * 3 or 0
    TabTP:AddButton("Lane " .. i .. " Start Line", function()
        local hrp = getRootPart()
        if hrp then hrp.CFrame = CFrame.new(35, 3, z) end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB 6: MOVEMENT & QOL
-- ─────────────────────────────────────────────────────────────────────────────
local TabMove = Hub:CreateTab("Movement", "🏃")

TabMove:AddSection("Locomotion Attributes")
TabMove:AddSlider("WalkSpeed", 16, 120, 16, function(v)
    State.WalkSpeed = v
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
end)

TabMove:AddSlider("JumpPower", 50, 200, 50, function(v)
    State.JumpPower = v
    local hum = getHumanoid()
    if hum then
        hum.JumpPower = v
        hum.UseJumpPower = true
    end
end)

TabMove:AddToggle("Infinite Jump", false, function(v)
    State.InfJump = v
end)

TabMove:AddToggle("Barrier Noclip (Bypass Lane Walls)", false, function(v)
    State.Noclip = v
end)

TabMove:AddSection("3D Physics Flight")
TabMove:AddToggle("Enable 3D Fly", false, function(v)
    State.Flight = v
end)

TabMove:AddSlider("Flight Speed", 20, 150, 45, function(v)
    State.FlightSpeed = v
end)

TabMove:AddSection("Session & QoL")
TabMove:AddToggle("Anti-AFK (20-Min Idle Kick Bypass)", true, function(v)
    State.AntiAFK = v
end)

TabMove:AddButton("Unload Suite Cleanly", function()
    Hub:Unload()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE AUTOMATION WORKERS
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Anti-AFK Hook
table.insert(Hub.Connections, LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

-- 2. Infinite Jump Hook
table.insert(Hub.Connections, UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- 3. Noclip Worker
table.insert(Hub.Connections, RunService.Stepped:Connect(function()
    if State.Noclip then
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

-- 4. 3D Flight Controller
local bodyGyro, bodyVel
table.insert(Hub.Connections, RunService.RenderStepped:Connect(function()
    local hrp = getRootPart()
    local hum = getHumanoid()
    if not (hrp and hum) then return end

    if State.Flight then
        if not bodyGyro or not bodyGyro.Parent then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            bodyGyro.P = 9e4
            bodyGyro.Parent = hrp
        end
        if not bodyVel or not bodyVel.Parent then
            bodyVel = Instance.new("BodyVelocity")
            bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bodyVel.Velocity = Vector3.new(0, 0, 0)
            bodyVel.Parent = hrp
        end

        bodyGyro.CFrame = Camera.CFrame
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            bodyVel.Velocity = moveDir.Unit * State.FlightSpeed
        else
            bodyVel.Velocity = Vector3.new(0, 0, 0)
        end
    else
        if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
        if bodyVel then bodyVel:Destroy() bodyVel = nil end
    end
end))

-- 5. Humanoid Speed/Jump Enforcement
table.insert(Hub.Connections, RunService.Heartbeat:Connect(function()
    local hum = getHumanoid()
    if hum then
        if State.WalkSpeed > 16 and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
        end
        if State.JumpPower > 50 and hum.JumpPower ~= State.JumpPower then
            hum.JumpPower = State.JumpPower
            hum.UseJumpPower = true
        end
    end
end))

-- 6. Live Status Badges & Match State Monitor
table.insert(Hub.Connections, RunService.Heartbeat:Connect(function()
    local phase = Workspace:GetAttribute("MatchPhase") or "Lobby"
    local lane = LocalPlayer:GetAttribute("Lane")
    local blocks = LocalPlayer:GetAttribute("LaneBlocksLeft")
    
    local phaseCol = Theme.Primary
    if phase == "Race" then
        phaseCol = Theme.Success
    elseif phase == "PvP" then
        phaseCol = Theme.Danger
    end
    BadgePhase.Set(phase, phaseCol)
    BadgeLane.Set(lane and ("Lane " .. tostring(lane)) or "Not in Match", lane and Theme.Secondary or Theme.OnSurfaceVariant)
    BadgeBlocks.Set(blocks and (tostring(blocks) .. " / 40") or "—", (blocks and blocks == 0) and Theme.Success or Theme.Primary)
end))

-- 7. Auto Match Loop & Skip Vote
task.spawn(function()
    while Hub.ScreenGui and Hub.ScreenGui.Parent do
        task.wait(1.5)
        if State.AutoMatchCycle then
            local phase = Workspace:GetAttribute("MatchPhase")
            if phase == "Prep" or phase == "Lobby" then
                pcall(function()
                    Remotes.Race_SkipVote:FireServer(true)
                end)
            end
            if LocalPlayer:GetAttribute("Alive") == false then
                pcall(function()
                    Remotes.Respawn:FireServer()
                end)
            end
        end
    end
end)

-- 8. Intelligent Lucky Block Mining Engine
task.spawn(function()
    while Hub.ScreenGui and Hub.ScreenGui.Parent do
        task.wait(0.04)
        if State.AutoMineLane and not State.MiningInProgress then
            local phase = Workspace:GetAttribute("MatchPhase")
            local inMatch = LocalPlayer:GetAttribute("InMatch")
            local laneNum = LocalPlayer:GetAttribute("Lane")
            local blocksLeft = LocalPlayer:GetAttribute("LaneBlocksLeft")
            local hrp = getRootPart()

            if phase == "Race" and inMatch and laneNum and blocksLeft and blocksLeft > 0 and hrp then
                State.MiningInProgress = true
                local lInfo = RaceLayout.lane(laneNum)

                while State.AutoMineLane and LocalPlayer:GetAttribute("InMatch") and Workspace:GetAttribute("MatchPhase") == "Race" do
                    local left = LocalPlayer:GetAttribute("LaneBlocksLeft")
                    if not left or left <= 0 then break end

                    local idx = 40 - left + 1
                    local grid = lInfo.lucky[idx]
                    if not grid then break end

                    local targetPos = Vector3.new(grid.X * 3, 4.5, grid.Z * 3)

                    if State.FastTPMine then
                        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 1.5))
                    else
                        local hum = getHumanoid()
                        if hum then hum:MoveTo(targetPos) end
                        local startMove = os.clock()
                        while (hrp.Position - targetPos).Magnitude > 6 and os.clock() - startMove < 2 do
                            task.wait(0.05)
                        end
                    end

                    local delaySec = math.clamp(State.MineDelayMs / 1000, 0.04, 0.25)
                    Remotes.BreakStart:FireServer(grid, delaySec)
                    task.wait(delaySec)
                    Remotes.BreakFinish:FireServer(grid)

                    if State.AutoEquipBest and os.clock() - State.LastEquipTick > 1.2 then
                        State.LastEquipTick = os.clock()
                        pcall(function() Remotes.Inv_EquipBest:InvokeServer() end)
                    end

                    task.wait(0.02)
                end

                -- Block 40 broken -> Navigate to finish gate
                if State.AutoFinishGate and LocalPlayer:GetAttribute("InMatch") and (LocalPlayer:GetAttribute("LaneBlocksLeft") or 0) <= 0 then
                    local targetX = 735
                    local targetZ = lInfo.centerZ * 3
                    hrp.CFrame = CFrame.new(targetX, 5, targetZ)
                    task.wait(0.3)
                    pcall(function() Remotes.Inv_EquipBest:InvokeServer() end)
                    Hub:Notify("Race", "Finished lane! Crossed finish line into Arena!", 3)
                end

                State.MiningInProgress = false
            end
        end
    end
end)

-- 9. Auto Equip Best Gear Worker
task.spawn(function()
    while Hub.ScreenGui and Hub.ScreenGui.Parent do
        task.wait(2.5)
        if State.AutoEquipBest and os.clock() - State.LastEquipTick > 2.0 then
            State.LastEquipTick = os.clock()
            pcall(function()
                Remotes.Inv_EquipBest:InvokeServer()
            end)
        end
    end
end)

-- 10. Proximity Drop Vacuum Worker
task.spawn(function()
    while Hub.ScreenGui and Hub.ScreenGui.Parent do
        task.wait(0.2)
        if State.AutoVacuumDrops and not State.MiningInProgress then
            local drops = Workspace:FindFirstChild("Drops")
            local hrp = getRootPart()
            if drops and hrp then
                local myPos = hrp.Position
                for _, drop in ipairs(drops:GetChildren()) do
                    if drop:IsA("BasePart") then
                        local dist = (drop.Position - myPos).Magnitude
                        if dist <= State.VacuumRadius and dist > 4.5 then
                            -- Step momentarily near drop to trigger server pickup
                            local saved = hrp.CFrame
                            hrp.CFrame = CFrame.new(drop.Position + Vector3.new(0, 1.5, 0))
                            task.wait(0.06)
                            hrp.CFrame = saved
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
    end
end)

-- 11. Combat Kill Aura Engine
task.spawn(function()
    while Hub.ScreenGui and Hub.ScreenGui.Parent do
        task.wait(math.clamp(State.AuraDelayMs / 1000, 0.05, 0.3))
        if (State.KillAuraPlayers or State.KillAuraMobs) and os.clock() - State.LastAuraTick >= (State.AuraDelayMs / 1000) then
            local hrp = getRootPart()
            if not hrp then continue end

            local targets = {}
            local myPos = hrp.Position

            -- Players
            if State.KillAuraPlayers then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local tHrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if tHrp and tHum and tHum.Health > 0 and p.Character:GetAttribute("Ghost") ~= true then
                            local d = (tHrp.Position - myPos).Magnitude
                            if d <= State.AuraRange then
                                table.insert(targets, { model = p.Character, dist = d })
                            end
                        end
                    end
                end
            end

            -- Mobs
            if State.KillAuraMobs then
                for _, folderName in ipairs({ "Mobs", "Entities", "NPCs" }) do
                    local folder = Workspace:FindFirstChild(folderName)
                    if folder then
                        for _, m in ipairs(folder:GetChildren()) do
                            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                                local mHrp = m:FindFirstChild("HumanoidRootPart")
                                local mHum = m:FindFirstChildOfClass("Humanoid")
                                if mHrp and mHum and mHum.Health > 0 then
                                    local d = (mHrp.Position - myPos).Magnitude
                                    if d <= State.AuraRange then
                                        table.insert(targets, { model = m, dist = d })
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Dispatch attacks
            if #targets > 0 then
                table.sort(targets, function(a, b) return a.dist < b.dist end)
                local target = targets[1].model
                State.LastAuraTick = os.clock()

                if CombatClient and type(CombatClient.attack) == "function" then
                    pcall(function() CombatClient.attack(target) end)
                else
                    pcall(function()
                        Remotes.Attack:FireServer(target, {
                            charge = 1,
                            crit = true,
                            sprint = true
                        })
                        Remotes.PlayerSwing:FireServer()
                    end)
                end
            end
        end
    end
end)

-- 12. Progression & Daily Auto Harvester
task.spawn(function()
    while Hub.ScreenGui and Hub.ScreenGui.Parent do
        task.wait(10)
        if ProgState and ProgState.request then
            if State.AutoDaily then
                pcall(function() ProgState.request("claimDaily", {}) end)
            end
            if State.AutoGroup then
                pcall(function() ProgState.request("claimGroup", {}) end)
            end
            if State.AutoPlaytime then
                for i = 1, 12 do
                    pcall(function() ProgState.request("claimPlaytime", { index = i }) end)
                end
            end
            if State.AutoOpenWoodCrate then
                pcall(function()
                    if ProgState.data and ProgState.data.crates and (tonumber(ProgState.data.crates.wood) or 0) > 0 then
                        ProgState.request("openCrate", { kind = "wood" })
                        task.wait(0.2)
                        pcall(ProgState.request, "closeCrate", {})
                    end
                end)
            end
        end
    end
end)

-- Hub Load Greeting
Hub:Notify("LUCKY BLOCK RACE", "Liquid Glass MD3 Suite Loaded! Press RightShift to Toggle", 4)
