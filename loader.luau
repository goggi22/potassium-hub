--[[
    ══════════════════════════════════════════════════════════════════════
    POTASSIUM HUB — SMART AUTO-DETECT MASTER LOADER
    ══════════════════════════════════════════════════════════════════════
    Repository : https://github.com/goggi22/potassium-hub
    Author     : goggi22
    Platform   : Potassium Executor / Luau Environment
    
    Quick Execution:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/goggi22/potassium-hub/main/loader.luau"))()
    ══════════════════════════════════════════════════════════════════════
]]

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId

local BaseURL = "https://raw.githubusercontent.com/goggi22/potassium-hub/main/"

-- Supported Game Registry
local GameRegistry = {
    [121362092826008] = {
        Name = "Jump To Steal Baddies!",
        Script = "games/steal_baddies.luau",
        Icon = "🥷"
    },
    [18134283205] = {
        Name = "Lucky Islands",
        Script = "games/lucky_islands.luau",
        Icon = "🍀"
    },
    [108114331578868] = {
        Name = "Towers of Fortune",
        Script = "games/towers_of_fortune.luau",
        Icon = "🏰"
    },
    [99507719593544] = {
        Name = "Texas Granny (Lobby)",
        Script = "games/texas_granny.luau",
        Icon = "👵"
    },
    [128897979987102] = {
        Name = "Texas Granny (Match)",
        Script = "games/texas_granny.luau",
        Icon = "👵"
    },
    [117273975798730] = {
        Name = "Fling Arena 💥",
        Script = "games/fling_arena.luau",
        Icon = "💥"
    },
    [82115753075808] = {
        Name = "Хрущёвка 🎃 [Ужасы]",
        Script = "games/khrushchyovka.luau",
        Icon = "🏢"
    },
    [72393956865647] = {
        Name = "[⚔️] 1.8 KIT PVP",
        Script = "games/kit_pvp_1_8.luau",
        Icon = "⚔️"
    },
    [129861507977954] = {
        Name = "STRAFEX [Spear Mace!]",
        Script = "games/strafex.luau",
        Icon = "🛡️"
    },
}

-- Animated Notification Toast
local function ShowNotification(titleText, subtitleText, iconText, duration)
    pcall(function()
        local sg = CoreGui:FindFirstChild("PotassiumToastGui") or Instance.new("ScreenGui")
        sg.Name = "PotassiumToastGui"
        sg.ResetOnSpawn = false
        sg.Parent = CoreGui

        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 300, 0, 64)
        card.Position = UDim2.new(1, 20, 1, -85) -- Start offscreen right
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
        icon.Size = UDim2.new(0, 40, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.Text = iconText or "⚡"
        icon.TextColor3 = Color3.fromRGB(0, 215, 255)
        icon.TextSize = 22
        icon.Parent = card

        local title = Instance.new("TextLabel")
        title.Position = UDim2.new(0, 44, 0, 12)
        title.Size = UDim2.new(1, -50, 0, 20)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = titleText
        title.TextColor3 = Color3.fromRGB(245, 248, 255)
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = card

        local sub = Instance.new("TextLabel")
        sub.Position = UDim2.new(0, 44, 0, 32)
        sub.Size = UDim2.new(1, -50, 0, 18)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.Gotham
        sub.Text = subtitleText
        sub.TextColor3 = Color3.fromRGB(150, 165, 195)
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Parent = card

        -- Animate In
        TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -320, 1, -85)
        }):Play()

        task.delay(duration or 3.5, function()
            local outTween = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 20, 1, -85)
            })
            outTween:Play()
            outTween.Completed:Connect(function()
                card:Destroy()
            end)
        end)
    end)
end

-- Loader Controller
local PotassiumHub = {
    Version = "2.5.0",
    Registry = GameRegistry,
}

function PotassiumHub.ExecuteScript(relPath, gameName)
    local url = BaseURL .. relPath
    local ok, content = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not content or #content == 0 then
        ShowNotification("Load Error", "Failed to fetch " .. relPath, "❌", 4)
        return false
    end

    local loadOk, fn = pcall(loadstring, content)
    if not loadOk or not fn then
        ShowNotification("Syntax Error", "Could not compile " .. relPath, "❌", 4)
        return false
    end

    local execOk, err = pcall(fn)
    if not execOk then
        ShowNotification("Runtime Error", tostring(err):sub(1, 35), "⚠️", 4)
        return false
    end

    return true
end

function PotassiumHub.Init()
    local matched = GameRegistry[PlaceId]
    if matched then
        ShowNotification(
            "Game Detected!",
            matched.Icon .. " " .. matched.Name,
            "⚡",
            3.5
        )
        task.wait(0.4)
        PotassiumHub.ExecuteScript(matched.Script, matched.Name)
    else
        ShowNotification(
            "Universal Mode",
            "Unsupported Place • Loading Universal Suite",
            "🌐",
            3.5
        )
        task.wait(0.4)
        PotassiumHub.ExecuteScript("games/universal.luau", "Universal")
    end
end

getgenv().PotassiumHub = PotassiumHub

task.spawn(PotassiumHub.Init)

return PotassiumHub
