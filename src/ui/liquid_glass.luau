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
      • Integrated Config / Save Manager: JSON persistence via writefile/readfile.
      • Unified Unload & Panic Hook: Safe disconnection of all threads and UIs.
    ══════════════════════════════════════════════════════════════════════
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
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
    self.Keybind = config.Keybind or Enum.KeyCode.RightControl
    self.PanicKey = config.PanicKey or Enum.KeyCode.End
    self.ConfigFolder = config.ConfigFolder or "Default"
    self.Size = config.Size or UDim2.fromOffset(620, 390)
    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.Connections = {}
    self.UnloadHooks = {}
    self.Flags = {}

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
    shadow.Size = self.Size + UDim2.fromOffset(50, 50)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.35
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Parent = screenGui
    self.Shadow = shadow

    -- Main Container Window
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = self.Size
    main.BackgroundColor3 = Theme.Surface
    main.BackgroundTransparency = Theme.SurfaceTrans
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    self.Main = main

    MakeRounded(main, 14)
    local mainStroke = MakeStroke(main, Theme.RimLight, Theme.RimLightTrans, 1.2)

    -- Specular Rim Highlight Gradient
    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Rotation = 45
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 160, 255)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 255))
    })
    strokeGrad.Parent = mainStroke

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
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            shadow.Position = main.Position
        end
    end)

    -- Top App Bar (Header)
    local header = Instance.new("Frame")
    header.Name = "TopAppBar"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Theme.SurfaceContainer
    header.BackgroundTransparency = Theme.SurfaceContainerTrans
    header.BorderSizePixel = 0
    header.Parent = main

    local title = Instance.new("TextLabel")
    title.Name = "AppTitle"
    title.Size = UDim2.new(0, 200, 0, 20)
    title.Position = UDim2.fromOffset(16, 7)
    title.BackgroundTransparency = 1
    title.Text = self.Title
    title.TextColor3 = Theme.OnSurface
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "AppSubtitle"
    subtitle.Size = UDim2.new(0, 200, 0, 14)
    subtitle.Position = UDim2.fromOffset(16, 26)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = self.Subtitle
    subtitle.TextColor3 = Theme.Primary
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header

    -- Close & Minimize Buttons
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
    closeBtn.BackgroundColor3 = Theme.SurfaceHigh
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Theme.OnSurfaceVariant
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    MakeRounded(closeBtn, 8)

    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)

    -- Sidebar (Navigation Rail)
    local rail = Instance.new("Frame")
    rail.Name = "NavigationRail"
    rail.Size = UDim2.new(0, 145, 1, -48)
    rail.Position = UDim2.fromOffset(0, 48)
    rail.BackgroundColor3 = Theme.SurfaceContainer
    rail.BackgroundTransparency = Theme.SurfaceContainerTrans + 0.1
    rail.BorderSizePixel = 0
    rail.Parent = main

    local railList = Instance.new("UIListLayout")
    railList.Padding = UDim.new(0, 6)
    railList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    railList.Parent = rail

    local railPad = Instance.new("UIPadding")
    railPad.PaddingTop = UDim.new(0, 10)
    railPad.Parent = rail

    -- Content Viewport
    local viewport = Instance.new("Frame")
    viewport.Name = "ContentViewport"
    viewport.Size = UDim2.new(1, -155, 1, -58)
    viewport.Position = UDim2.fromOffset(150, 53)
    viewport.BackgroundTransparency = 1
    viewport.Parent = main
    self.Viewport = viewport
    self.Rail = rail

    -- Keybind Toggle Listener & Panic Listener
    local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == self.Keybind then
            self:Toggle()
        elseif input.KeyCode == self.PanicKey then
            self:Unload()
        end
    end)
    table.insert(self.Connections, keyConn)

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

-- ====================================================================
-- UNLOAD & PANIC SYSTEM
-- ====================================================================
function LiquidGlass:OnUnload(callback)
    if typeof(callback) == "function" then
        table.insert(self.UnloadHooks, callback)
    end
end

function LiquidGlass:Unload()
    -- Fire user unload hooks first
    for _, hook in ipairs(self.UnloadHooks) do
        pcall(hook)
    end
    self.UnloadHooks = {}

    -- Disconnect internal UI connections
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end

    if getgenv then
        getgenv()._LiquidGlassUIInstance = nil
    end
end

-- ====================================================================
-- CONFIG / SAVE MANAGER
-- ====================================================================
local function EnsureConfigFolder(folderName)
    if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
        if not isfolder("potassium_hub") then makefolder("potassium_hub") end
        if not isfolder("potassium_hub/configs") then makefolder("potassium_hub/configs") end
        local target = "potassium_hub/configs/" .. folderName
        if not isfolder(target) then makefolder(target) end
        return target
    end
    return nil
end

function LiquidGlass:SaveConfig(configName)
    configName = configName or "default"
    local dir = EnsureConfigFolder(self.ConfigFolder)
    if not dir or typeof(writefile) ~= "function" then return false end

    local data = {}
    for flag, entry in pairs(self.Flags) do
        if entry.Get then
            data[flag] = entry.Get()
        end
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if ok and encoded then
        writefile(dir .. "/" .. configName .. ".json", encoded)
        self:Notify("Config Saved", "Saved preset '" .. configName .. "' successfully.", 2)
        return true
    end
    return false
end

function LiquidGlass:LoadConfig(configName)
    configName = configName or "default"
    local dir = EnsureConfigFolder(self.ConfigFolder)
    if not dir or typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return false end

    local path = dir .. "/" .. configName .. ".json"
    if not isfile(path) then return false end

    local ok, content = pcall(readfile, path)
    if not ok or not content then return false end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if decodeOk and typeof(data) == "table" then
        for flag, val in pairs(data) do
            local entry = self.Flags[flag]
            if entry and entry.Set then
                pcall(entry.Set, val)
            end
        end
        self:Notify("Config Loaded", "Loaded preset '" .. configName .. "' successfully.", 2)
        return true
    end
    return false
end

function LiquidGlass:AutoSave(enable, interval)
    if self._AutoSaveTask then
        pcall(task.cancel, self._AutoSaveTask)
        self._AutoSaveTask = nil
    end
    if enable then
        interval = interval or 10
        self._AutoSaveTask = task.spawn(function()
            while true do
                task.wait(interval)
                pcall(function() self:SaveConfig("autosave") end)
            end
        end)
    end
end

-- ====================================================================
-- TAB CREATION
-- ====================================================================
function LiquidGlass:CreateTab(name, iconText)
    local tab = {}
    iconText = iconText or "•"

    -- Rail Segment Button
    local railBtn = Instance.new("TextButton")
    railBtn.Name = "Tab_" .. name
    railBtn.Size = UDim2.new(1, -16, 0, 36)
    railBtn.BackgroundColor3 = Theme.SurfaceContainer
    railBtn.BackgroundTransparency = 1
    railBtn.AutoButtonColor = false
    railBtn.Text = ""
    railBtn.Parent = self.Rail
    MakeRounded(railBtn, 8)

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.fromOffset(24, 24)
    icon.Position = UDim2.fromOffset(10, 6)
    icon.BackgroundTransparency = 1
    icon.Text = iconText
    icon.TextColor3 = Theme.OnSurfaceVariant
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 13
    icon.Parent = railBtn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -44, 1, 0)
    label.Position = UDim2.fromOffset(38, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Theme.OnSurfaceVariant
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = railBtn

    -- Page Container
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Primary
    page.Visible = false
    page.Parent = self.Viewport

    local pageList = Instance.new("UIListLayout")
    pageList.Padding = UDim.new(0, 8)
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingTop = UDim.new(0, 4)
    pagePad.PaddingRight = UDim.new(0, 8)
    pagePad.Parent = page

    -- Selection Indicator Pill
    local activePill = Instance.new("Frame")
    activePill.Name = "ActivePill"
    activePill.Size = UDim2.new(0, 3, 0, 20)
    activePill.Position = UDim2.fromOffset(2, 8)
    activePill.BackgroundColor3 = Theme.Primary
    activePill.BorderSizePixel = 0
    activePill.Visible = false
    activePill.Parent = railBtn
    MakeRounded(activePill, 2)

    local function Select()
        for _, otherTab in ipairs(self.Tabs) do
            otherTab.Page.Visible = false
            otherTab.ActivePill.Visible = false
            Tween(otherTab.RailBtn, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
            Tween(otherTab.Label, TweenInfo.new(0.2), { TextColor3 = Theme.OnSurfaceVariant })
            Tween(otherTab.Icon, TweenInfo.new(0.2), { TextColor3 = Theme.OnSurfaceVariant })
        end

        page.Visible = true
        activePill.Visible = true
        Tween(railBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Theme.PrimaryContainer,
            BackgroundTransparency = 0.6
        })
        Tween(label, TweenInfo.new(0.2), { TextColor3 = Theme.OnSurface })
        Tween(icon, TweenInfo.new(0.2), { TextColor3 = Theme.Primary })
        self.ActiveTab = tab
    end

    railBtn.MouseButton1Click:Connect(Select)

    tab.Page = page
    tab.RailBtn = railBtn
    tab.Label = label
    tab.Icon = icon
    tab.ActivePill = activePill

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then Select() end

    -- ================================================================
    -- COMPONENT FACTORIES (MD3 CONTROLS)
    -- ================================================================
    function tab:AddSection(text)
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 24)
        header.BackgroundTransparency = 1
        header.Text = string.upper(text)
        header.TextColor3 = Theme.Primary
        header.Font = Enum.Font.GothamBold
        header.TextSize = 10
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = page

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.PaddingTop = UDim.new(0, 6)
        pad.Parent = header
        return header
    end

    function tab:AddButton(text, callback)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 38)
        card.BackgroundColor3 = Theme.SurfaceHigh
        card.BackgroundTransparency = 0.55
        card.Parent = page
        MakeRounded(card, 10)
        local stroke = MakeStroke(card, Theme.BorderSubtle, 0.90, 1)

        local b = Instance.new("TextButton")
        b.Size = UDim2.fromScale(1, 1)
        b.BackgroundTransparency = 1
        b.Text = text
        b.TextColor3 = Theme.OnSurface
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.AutoButtonColor = false
        b.Parent = card

        b.MouseEnter:Connect(function()
            Tween(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.35 })
            Tween(stroke, TweenInfo.new(0.18), { Transparency = 0.65 })
        end)
        b.MouseLeave:Connect(function()
            Tween(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.55 })
            Tween(stroke, TweenInfo.new(0.18), { Transparency = 0.90 })
        end)
        b.MouseButton1Click:Connect(function()
            Tween(card, TweenInfo.new(0.08), { BackgroundColor3 = Theme.PrimaryContainer })
            task.delay(0.08, function()
                Tween(card, TweenInfo.new(0.15), { BackgroundColor3 = Theme.SurfaceHigh })
            end)
            if callback then callback() end
        end)
        return b
    end

    function tab:AddToggle(text, default, callback, flag)
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

        local toggleObj = {
            Set = UpdateState,
            Get = function() return state end
        }

        if flag then
            self.Flags[flag] = toggleObj
        end

        return toggleObj
    end

    function tab:AddSlider(text, min, max, default, callback, flag)
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

        local sliderObj = {
            Set = function(val)
                value = math.clamp(val, min, max)
                valLabel.Text = tostring(value)
                local pct = (value - min) / (max - min)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                if callback then callback(value) end
            end,
            Get = function() return value end
        }

        if flag then
            self.Flags[flag] = sliderObj
        end

        return sliderObj
    end

    function tab:AddDropdown(text, options, default, callback, flag)
        options = options or {}
        local current = default or options[1] or ""
        local isOpen = false

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 42)
        card.BackgroundColor3 = Theme.SurfaceHigh
        card.BackgroundTransparency = 0.55
        card.ClipsDescendants = true
        card.Parent = page
        MakeRounded(card, 10)
        MakeStroke(card, Theme.BorderSubtle, 0.90, 1)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -140, 0, 42)
        titleLabel.Position = UDim2.fromOffset(14, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = text
        titleLabel.TextColor3 = Theme.OnSurface
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 12
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = card

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 120, 0, 26)
        btn.Position = UDim2.new(1, -130, 0, 8)
        btn.BackgroundColor3 = Theme.SurfaceContainer
        btn.BackgroundTransparency = 0.3
        btn.Text = tostring(current) .. " ▾"
        btn.TextColor3 = Theme.Primary
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = card
        MakeRounded(btn, 6)

        local optList = Instance.new("Frame")
        optList.Size = UDim2.new(1, -28, 0, #options * 26)
        optList.Position = UDim2.fromOffset(14, 46)
        optList.BackgroundTransparency = 1
        optList.Parent = card

        local optLayout = Instance.new("UIListLayout")
        optLayout.Padding = UDim.new(0, 4)
        optLayout.Parent = optList

        local function SetOption(opt)
            current = opt
            btn.Text = tostring(opt) .. (isOpen and " ▴" or " ▾")
            if callback then callback(opt) end
        end

        local function ToggleOpen()
            isOpen = not isOpen
            btn.Text = tostring(current) .. (isOpen and " ▴" or " ▾")
            local targetH = isOpen and (46 + #options * 30 + 6) or 42
            Tween(card, TweenInfo.new(0.2, Enum.EasingStyle.Cubic), { Size = UDim2.new(1, 0, 0, targetH) })
        end

        btn.MouseButton1Click:Connect(ToggleOpen)

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 26)
            optBtn.BackgroundColor3 = Theme.SurfaceContainer
            optBtn.BackgroundTransparency = 0.5
            optBtn.Text = tostring(opt)
            optBtn.TextColor3 = Theme.OnSurfaceVariant
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 11
            optBtn.Parent = optList
            MakeRounded(optBtn, 4)

            optBtn.MouseButton1Click:Connect(function()
                SetOption(opt)
                ToggleOpen()
            end)
        end

        local dropdownObj = {
            Set = SetOption,
            Get = function() return current end
        }
        if flag then self.Flags[flag] = dropdownObj end
        return dropdownObj
    end

    return tab
end

-- Notification Toast System (Floating Acrylic Pill)
function LiquidGlass:Notify(title, message, duration)
    duration = duration or 3
    local toast = Instance.new("Frame")
    toast.Name = "ToastNotification"
    toast.Size = UDim2.fromOffset(260, 56)
    toast.Position = UDim2.new(1, 300, 1, -24)
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.BackgroundColor3 = Theme.Surface
    toast.BackgroundTransparency = 0.15
    toast.BorderSizePixel = 0
    toast.Parent = self.ScreenGui

    MakeRounded(toast, 12)
    MakeStroke(toast, Theme.Primary, 0.4, 1.2)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -24, 0, 18)
    t.Position = UDim2.fromOffset(12, 8)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Theme.OnSurface
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = toast

    local m = Instance.new("TextLabel")
    m.Size = UDim2.new(1, -24, 0, 16)
    m.Position = UDim2.fromOffset(12, 26)
    m.BackgroundTransparency = 1
    m.Text = message
    m.TextColor3 = Theme.OnSurfaceVariant
    m.Font = Enum.Font.Gotham
    m.TextSize = 10
    m.TextXAlignment = Enum.TextXAlignment.Left
    m.Parent = toast

    Tween(toast, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -24, 1, -24)
    })

    task.delay(duration, function()
        if toast and toast.Parent then
            local tw = Tween(toast, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 300, 1, -24)
            })
            tw.Completed:Connect(function()
                toast:Destroy()
            end)
        end
    end)
end

return LiquidGlass
