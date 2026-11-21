--[[
    ══════════════════════════════════════════════════════════════════════
    LIQUID GLASS × MATERIAL DESIGN 3 — DEMO & STANDALONE EXAMPLE
    ══════════════════════════════════════════════════════════════════════
    Usage:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/goggi22/potassium-hub/main/examples/demo.luau"))()
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

local Hub = LiquidGlass.new({
    Title = "A E T H E R",
    Subtitle = "LiquidGlass • Material Design 3",
    Keybind = Enum.KeyCode.RightControl,
    PanicKey = Enum.KeyCode.End,
    ConfigFolder = "AetherDemo",
    Size = UDim2.fromOffset(600, 390)
})

-- Tab 1: Overview
local tabMain = Hub:CreateTab("Overview", "✦")
tabMain:AddSection("System Status")
tabMain:AddToggle("Acrylic Sheen Filter", true, function(v)
    print("[UI] Sheen Filter toggled:", v)
end, "SheenToggle")

tabMain:AddToggle("Ambient Shadow Layer", true, function(v)
    Hub.Shadow.Visible = v
end, "ShadowToggle")

tabMain:AddSlider("UI Scale Offset", 80, 140, 100, function(val)
    print("[UI] Scale Offset:", val)
end, "ScaleSlider")

tabMain:AddDropdown("Visual Mode", {"Obsidian Glass", "Frost Cyan", "Midnight Violet"}, "Obsidian Glass", function(mode)
    print("[UI] Selected Mode:", mode)
end, "ModeDropdown")

-- Tab 2: Settings & Controls
local tabControls = Hub:CreateTab("Controls", "⚙")
tabControls:AddSection("Presets & Config")
tabControls:AddButton("💾 Save Current Config", function()
    Hub:SaveConfig("preset1")
end)
tabControls:AddButton("📂 Load Saved Config", function()
    Hub:LoadConfig("preset1")
end)
tabControls:AddButton("⚡ AutoSave Toggle (10s)", function()
    Hub:AutoSave(true, 10)
    Hub:Notify("AutoSave", "Config will auto-save every 10 seconds.", 2.5)
end)

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
    Hub:Notify("Theme Applied", "Switched accent to Ice Blue.", 2)
end)
tabThemes:AddButton("Neon Violet", function()
    Hub:Notify("Theme Applied", "Switched accent to Neon Violet.", 2)
end)
tabThemes:AddButton("Emerald Mint", function()
    Hub:Notify("Theme Applied", "Switched accent to Emerald Mint.", 2)
end)

Hub:Notify("Aether UI Loaded", "Press [RightControl] to toggle • [End] to panic unload.", 4)

return Hub
