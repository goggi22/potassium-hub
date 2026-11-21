--[[
    ══════════════════════════════════════════════════════════════════════
    LIQUID GLASS × MATERIAL DESIGN 3 (MD3) UI FRAMEWORK FOR LUAU
    ══════════════════════════════════════════════════════════════════════
    Visual Aesthetics:
      • Liquid Glass / Glassmorphism: Acrylic translucent surfaces, 
        specular rim highlights (UIStroke gradient), diffuse ambient drop shadow.
      • Material Design 3: Pill-shaped tonal selectors, dynamic surface tokens,
        tactile spring-like tweening on press, clean layout rhythm.
      • Standalone & Modular: Returns an engine table to construct custom hubs.
    ══════════════════════════════════════════════════════════════════════
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Clean previous instances with the same tag
if getgenv and getgenv()._LiquidGlassUIInstance then
    pcall(function()
        getgenv()._LiquidGlassUIInstance:Destroy()
    end)
    getgenv()._LiquidGlassUIInstance = nil
end

local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

-- MD3 & Glass Theme Tokens
local Theme = {
    -- Glass Surfaces
    Surface = Color3.fromRGB(15, 17, 24),
    SurfaceTrans = 0.28,
    SurfaceContainer = Color3.fromRGB(24, 28, 40),
    SurfaceContainerTrans = 0.35,
    SurfaceHigh = Color3.fromRGB(34, 40, 58),
    SurfaceHighTrans = 0.40,
    
    -- MD3 Accents (Tonal Palette)
    Primary = Color3.fromRGB(120, 160, 255),       -- Vibrant Ice Blue
    PrimaryContainer = Color3.fromRGB(45, 68, 120),
    OnPrimary = Color3.fromRGB(10, 14, 26),
    Secondary = Color3.fromRGB(190, 160, 255),     -- Soft Violet
    
    -- Glass Rim & Borders
    RimLight = Color3.fromRGB(255, 255, 255),
    RimLightTrans = 0.82,
    BorderSubtle = Color3.fromRGB(255, 255, 255),
    BorderSubtleTrans = 0.90,
    
    -- Text & Icons
    OnSurface = Color3.fromRGB(240, 243, 255),
    OnSurfaceVariant = Color3.fromRGB(150, 160, 185),
    Outline = Color3.fromRGB(80, 90, 115),
    
    -- Status
    Success = Color3.fromRGB(110, 230, 160),
    Warning = Color3.fromRGB(255, 195, 80),
    Danger = Color3.fromRGB(255, 105, 115)
}

local function Tween(obj, info, props)
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    return tween
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
    
    self.Title = config.Title or "LIQUID GLASS"
    self.Subtitle = config.Subtitle or "MD3 Experimental Hub"
    self.Keybind = config.Keybind or Enum.KeyCode.RightShift
    self.Size = config.Size or UDim2.fromOffset(620, 390)
    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.Connections = {}

    -- Mount Target
    local targetParent = pcall(function() return CoreGui:GetChildren() end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LiquidGlass_" .. math.random(10000, 99999)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = targetParent
    self.ScreenGui = screenGui

    if getgenv then
        getgenv()._LiquidGlassUIInstance = screenGui
    end

    -- Ambient Shadow Layer
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = self.Size + UDim2.fromOffset(80, 80)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843" -- Soft radial blur shadow
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
    local mainStroke = MakeStroke(main, Theme.RimLight, 0.78, 1.2)

    -- Top Gradient Specular Sheen (Liquid Glass feel)
    local sheen = Instance.new("Frame")
    sheen.Name = "SheenGradient"
    sheen.Size = UDim2.new(1, 0, 0, 120)
    sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheen.BackgroundTransparency = 0.94
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
    logoBadge.Size = UDim2.fromOffset(28, 28)
    logoBadge.Position = UDim2.fromOffset(18, 12)
    logoBadge.BackgroundColor3 = Theme.Primary
    logoBadge.BackgroundTransparency = 0.15
    logoBadge.Parent = header
    MakeRounded(logoBadge, 8)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.Size = UDim2.fromScale(1, 1)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Text = "◈"
    logoIcon.TextColor3 = Theme.OnPrimary
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 16
    logoIcon.Parent = logoBadge

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(56, 11)
    title.Size = UDim2.new(0, 200, 0, 18)
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
    subtitle.Size = UDim2.new(0, 200, 0, 14)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = self.Subtitle
    subtitle.TextColor3 = Theme.OnSurfaceVariant
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header

    -- Header Controls (Minimize / Close)
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
    divider.Size = UDim2.new(1, -36, 0, 1)
    divider.Position = UDim2.fromOffset(18, 52)
    divider.BackgroundColor3 = Theme.BorderSubtle
    divider.BackgroundTransparency = Theme.BorderSubtleTrans
    divider.BorderSizePixel = 0
    divider.Parent = main

    -- Sidebar / Tab Pill Navigation (MD3 Navigation Rail)
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(0, 150, 1, -66)
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
    contentFrame.Position = UDim2.fromOffset(178, 58)
    contentFrame.BackgroundColor3 = Theme.SurfaceContainer
    contentFrame.BackgroundTransparency = Theme.SurfaceContainerTrans
    contentFrame.BorderSizePixel = 0
    contentFrame.ClipsDescendants = true
    contentFrame.Parent = main
    MakeRounded(contentFrame, 14)
    MakeStroke(contentFrame, Theme.BorderSubtle, 0.88, 1)

    self.ContentFrame = contentFrame

    -- Keybind Toggle Listener
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end))

    return self
end

function LiquidGlass:Toggle()
    self.Visible = not self.Visible
    local targetTrans = self.Visible and Theme.SurfaceTrans or 1
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
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

-- Tab Creator (MD3 Pill Style)
function LiquidGlass:CreateTab(name, iconText)
    local tab = {}
    tab.Name = name
    tab.Hub = self
    
    -- MD3 Pill Tab Button
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. name
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Theme.SurfaceHigh
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = self.TabContainer
    MakeRounded(btn, 18) -- Pill shape

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

    -- Page Container for Tab Content
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

    -- If first tab, auto activate
    if #self.Tabs == 1 then
        Activate()
    end

    -- Tab Component Builders
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
            -- Ripple / bounce feedback
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

        -- MD3 Pill Switch Track
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

        -- Thumb
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

        -- Track
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -28, 0, 6)
        track.Position = UDim2.fromOffset(14, 34)
        track.BackgroundColor3 = Theme.SurfaceContainer
        track.BackgroundTransparency = 0.3
        track.BorderSizePixel = 0
        track.Parent = card
        MakeRounded(track, 3)

        -- Progress Fill
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

-- Notification Toast System (Floating Acrylic Pill)
function LiquidGlass:Notify(title, message, duration)
    duration = duration or 3
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

-- ====================================================================
-- DEMO INITIALIZATION (STANDALONE STUB)
-- ====================================================================
local Hub = LiquidGlass.new({
    Title = "A E T H E R",
    Subtitle = "LiquidGlass • Material Design 3",
    Keybind = Enum.KeyCode.RightShift,
    Size = UDim2.fromOffset(600, 380)
})

-- Tab 1: Overview
local tabMain = Hub:CreateTab("Overview", "✦")
tabMain:AddSection("System Status")
tabMain:AddToggle("Acrylic Sheen Filter", true, function(v)
    print("[UI] Sheen Filter toggled:", v)
end)
tabMain:AddToggle("Ambient Shadow Layer", true, function(v)
    Hub.Shadow.Visible = v
end)
tabMain:AddSlider("UI Scale Offset", 80, 140, 100, function(val)
    print("[UI] Scale Offset:", val)
end)

-- Tab 2: Settings & Controls
local tabControls = Hub:CreateTab("Controls", "⚙")
tabControls:AddSection("Actions")
tabControls:AddButton("Send MD3 Toast Notification", function()
    Hub:Notify("MD3 Notification", "Liquid glass surface rendered successfully!", 3)
end)
tabControls:AddButton("Reset Surface Geometry", function()
    Hub.Main.Position = UDim2.fromScale(0.5, 0.5)
    Hub.Shadow.Position = UDim2.fromScale(0.5, 0.5)
    Hub:Notify("Surface Reset", "Position re-centered to viewport center.", 2.5)
end)

-- Tab 3: Themes
local tabThemes = Hub:CreateTab("Themes", "🎨")
tabThemes:AddSection("Colorway")
tabThemes:AddButton("Ice Blue (Default Accent)", function()
    Theme.Primary = Color3.fromRGB(120, 160, 255)
    Hub:Notify("Theme Applied", "Switched accent to Ice Blue.", 2)
end)
tabThemes:AddButton("Neon Violet", function()
    Theme.Primary = Color3.fromRGB(190, 120, 255)
    Hub:Notify("Theme Applied", "Switched accent to Neon Violet.", 2)
end)
tabThemes:AddButton("Emerald Mint", function()
    Theme.Primary = Color3.fromRGB(110, 240, 180)
    Hub:Notify("Theme Applied", "Switched accent to Emerald Mint.", 2)
end)

Hub:Notify("Aether UI Loaded", "Press [RightShift] to toggle the interface.", 4)

return LiquidGlass
