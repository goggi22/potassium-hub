--[[
    ══════════════════════════════════════════════════════════════════════
    POTASSIUM HUB — SMART UNIVERSE-AWARE MASTER LOADER
    ══════════════════════════════════════════════════════════════════════
    Repository : https://github.com/goggi22/potassium-hub
    Author     : goggi22
    Platform   : Potassium Executor / Luau Environment
    
    Quick Execution:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/goggi22/potassium-hub/main/loader.luau"))()
    
    Upgrades:
      • Cache-Buster on all raw GitHub HttpGet requests (prevents stale client cache)
      • Dual Detection: Matches both game.PlaceId and game.GameId (Universe ID)
      • Unified Panic / Unload System: [End] key unloads any running suite immediately
    ══════════════════════════════════════════════════════════════════════
]]

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local GameId = game.GameId -- Universe ID

local BaseURL = "https://raw.githubusercontent.com/goggi22/potassium-hub/main/"

-- Cache-Buster Helper
local function CacheBust(url)
    local sep = url:find("%?") and "&" or "?"
    return url .. sep .. "nocache=" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- Supported Experience Registry (Supports UniverseIds & PlaceIds)
local GameRegistry = {
    {
        Id = "steal_baddies",
        Name = "Jump To Steal Baddies!",
        UniverseIds = { 10769344844 },
        PlaceIds = { 121362092826008 },
        Script = "games/steal_baddies.luau",
        Icon = "🥷"
    },
    {
        Id = "lucky_islands",
        Name = "Lucky Islands",
        UniverseIds = { 6265007289 },
        PlaceIds = { 18134283205 },
        Script = "games/lucky_islands.luau",
        Icon = "🍀"
    },
    {
        Id = "towers_of_fortune",
        Name = "Towers of Fortune",
        UniverseIds = { 3724395896 },
        PlaceIds = { 108114331578868, 8872596853 },
        Script = "games/towers_of_fortune.luau",
        Icon = "🏰"
    },
    {
        Id = "texas_granny",
        Name = "Texas Granny",
        UniverseIds = { 6625841029 },
        PlaceIds = { 99507719593544, 128897979987102 },
        Script = "games/texas_granny.luau",
        Icon = "👵"
    },
    {
        Id = "fling_arena",
        Name = "Fling Arena 💥",
        UniverseIds = { 10772462583 },
        PlaceIds = { 117273975798730 },
        Script = "games/fling_arena.luau",
        Icon = "💥"
    },
    {
        Id = "khrushchyovka",
        Name = "Хрущёвка 🎃 [Ужасы]",
        UniverseIds = { 2873491823 },
        PlaceIds = { 82115753075808, 8974581290 },
        Script = "games/khrushchyovka.luau",
        Icon = "🏢"
    },
    {
        Id = "kit_pvp_1_8",
        Name = "[⚔️] 1.8 KIT PVP",
        UniverseIds = { 2618305829 },
        PlaceIds = { 72393956865647 },
        Script = "games/kit_pvp_1_8.luau",
        Icon = "⚔️"
    },
    {
        Id = "strafex",
        Name = "STRAFEX [Spear Mace!]",
        UniverseIds = { 4639201948 },
        PlaceIds = { 129861507977954 },
        Script = "games/strafex.luau",
        Icon = "🛡️"
    },
}

-- Notification Toast
local function ShowToast(titleText, subtitleText, iconText, duration)
    pcall(function()
        local sg = CoreGui:FindFirstChild("PotassiumToastGui") or Instance.new("ScreenGui")
        sg.Name = "PotassiumToastGui"
        sg.ResetOnSpawn = false
        sg.Parent = CoreGui

        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 310, 0, 64)
        card.Position = UDim2.new(1, 20, 1, -85)
        card.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
        card.BackgroundTransparency = 0.15
        card.BorderSizePixel = 0
        card.Parent = sg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = card

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 215, 255)
        stroke.Thickness = 1.2
        stroke.Transparency = 0.3
        stroke.Parent = card

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 42, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.Text = iconText or "⚡"
        icon.TextColor3 = Color3.fromRGB(0, 215, 255)
        icon.TextSize = 22
        icon.Parent = card

        local title = Instance.new("TextLabel")
        title.Position = UDim2.new(0, 46, 0, 12)
        title.Size = UDim2.new(1, -52, 0, 20)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = titleText
        title.TextColor3 = Color3.fromRGB(245, 248, 255)
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = card

        local sub = Instance.new("TextLabel")
        sub.Position = UDim2.new(0, 46, 0, 32)
        sub.Size = UDim2.new(1, -52, 0, 18)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.Gotham
        sub.Text = subtitleText
        sub.TextColor3 = Color3.fromRGB(150, 165, 195)
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Parent = card

        TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -330, 1, -85)
        }):Play()

        task.delay(duration or 3.5, function()
            local outTween = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 20, 1, -85)
            })
            outTween:Play()
            outTween.Completed:Connect(function()
                card:Destroy()
            end)
        end)
    end)
end

-- Resolve target experience
local function ResolveExperience()
    for _, entry in ipairs(GameRegistry) do
        if table.find(entry.PlaceIds, PlaceId) then
            return entry
        end
        if GameId and GameId ~= 0 and table.find(entry.UniverseIds, GameId) then
            return entry
        end
    end
    return nil
end

-- Master Hub Controller
local PotassiumHub = {
    Version = "2.6.0",
    Registry = GameRegistry,
    ActiveSuite = nil,
    Connections = {},
}

function PotassiumHub.ExecuteRaw(relPath, label)
    local targetUrl = CacheBust(BaseURL .. relPath)
    local ok, content = pcall(function()
        return game:HttpGet(targetUrl)
    end)
    if not ok or not content or #content == 0 then
        ShowToast("Fetch Failed", "Could not retrieve " .. relPath, "❌", 4)
        return false
    end

    local loadOk, fn = pcall(loadstring, content)
    if not loadOk or not fn then
        ShowToast("Compile Error", "Syntax error in " .. relPath, "❌", 4)
        return false
    end

    local execOk, res = pcall(fn)
    if not execOk then
        ShowToast("Runtime Error", tostring(res):sub(1, 35), "⚠️", 4)
        return false
    end

    PotassiumHub.ActiveSuite = res
    return true
end

function PotassiumHub.Unload()
    -- 1. Unload Active Suite if it has Destroy or Unload method
    if PotassiumHub.ActiveSuite then
        if typeof(PotassiumHub.ActiveSuite.Unload) == "function" then
            pcall(PotassiumHub.ActiveSuite.Unload, PotassiumHub.ActiveSuite)
        elseif typeof(PotassiumHub.ActiveSuite.Destroy) == "function" then
            pcall(PotassiumHub.ActiveSuite.Destroy, PotassiumHub.ActiveSuite)
        end
        PotassiumHub.ActiveSuite = nil
    end

    -- 2. Clean Global UI instances
    if getgenv()._LiquidGlassUIInstance then
        pcall(function() getgenv()._LiquidGlassUIInstance:Destroy() end)
        getgenv()._LiquidGlassUIInstance = nil
    end

    -- 3. Clean specific game instances if left in getgenv
    if getgenv()._KitPvPInstance and typeof(getgenv()._KitPvPInstance.Unload) == "function" then
        pcall(function() getgenv()._KitPvPInstance:Unload() end)
        getgenv()._KitPvPInstance = nil
    end
    if getgenv().StealBaddiesInstance and typeof(getgenv().StealBaddiesInstance.Destroy) == "function" then
        pcall(function() getgenv().StealBaddiesInstance:Destroy() end)
        getgenv().StealBaddiesInstance = nil
    end
    if getgenv().UniversalPotassiumInstance and typeof(getgenv().UniversalPotassiumInstance.Destroy) == "function" then
        pcall(function() getgenv().UniversalPotassiumInstance:Destroy() end)
        getgenv().UniversalPotassiumInstance = nil
    end

    -- 4. Disconnect Loader Connections
    for _, conn in ipairs(PotassiumHub.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    PotassiumHub.Connections = {}

    ShowToast("Hub Unloaded", "Detached all hooks and interfaces.", "🛡️", 2.5)
end

function PotassiumHub.Init()
    -- Bind Global Panic Key [End]
    local panicConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.End then
            PotassiumHub.Unload()
        end
    end)
    table.insert(PotassiumHub.Connections, panicConn)

    local matched = ResolveExperience()
    if matched then
        ShowToast(
            "Game Detected!",
            matched.Icon .. " " .. matched.Name,
            "⚡",
            3.5
        )
        task.wait(0.35)
        PotassiumHub.ExecuteRaw(matched.Script, matched.Name)
    else
        ShowToast(
            "Universal Mode",
            "Place: " .. tostring(PlaceId) .. " • Loading Universal Suite",
            "🌐",
            3.5
        )
        task.wait(0.35)
        PotassiumHub.ExecuteRaw("games/universal.luau", "Universal")
    end
end

getgenv().PotassiumHub = PotassiumHub

task.spawn(PotassiumHub.Init)

return PotassiumHub
