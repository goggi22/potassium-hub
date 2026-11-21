-- STRAFEX [SPEAR MACE!] Combat Suite
-- Place ID: 129861507977954 | Oathforge Studios
-- Universal R15/R6 Block PvP Engine (Reach + Auto Mace Assist + Anti-KB + Clicker)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "STRAFEX | Combat Suite",
   LoadingTitle = "Loading STRAFEX Engine...",
   LoadingSubtitle = "Keyless / Clean",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local CombatTab = Window:CreateTab("Combat", 4483362458)
local MoveTab   = Window:CreateTab("Movement", 4483362458)
local VisualTab = Window:CreateTab("Visuals", 4483362458)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Settings
local ReachEnabled = true
local HitboxSize = 14
local AutoClicker = false
local CPSValue = 16
local AutoMaceCrit = true
local AntiKnockback = true
local SpeedBoost = false
local SpeedValue = 24
local InfJump = false
local ESPEnabled = true

-- 1. HITBOX EXPANDER (REACH ДЛЯ БУЛАВЫ, КОПЬЯ И МЕЧА)
CombatTab:CreateToggle({
   Name = "Hitbox Expander (Reach)",
   CurrentValue = true,
   Flag = "ReachToggle",
   Callback = function(val)
      ReachEnabled = val
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
   end,
})

CombatTab:CreateSlider({
   Name = "Reach Distance",
   Range = {4, 30},
   Increment = 1,
   Suffix = " studs",
   CurrentValue = 14,
   Flag = "ReachSlider",
   Callback = function(val)
      HitboxSize = val
   end,
})

RunService.RenderStepped:Connect(function()
   if ReachEnabled then
      for _, p in ipairs(Players:GetPlayers()) do
         if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
               hrp.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
               hrp.Transparency = 0.75
               hrp.CanCollide = false
               hrp.Material = Enum.Material.ForceField
            end
         end
      end
   end
end)

-- 2. AUTO MACE CRIT ASSIST
CombatTab:CreateToggle({
   Name = "Auto Mace Fall-Smash Assist",
   CurrentValue = true,
   Flag = "MaceCritToggle",
   Callback = function(val)
      AutoMaceCrit = val
   end,
})

-- Детект падения персонажа: когда падаешь вниз на врага с булавой, ускоряет атаку для максимального урона
RunService.Heartbeat:Connect(function()
   if AutoMaceCrit and LocalPlayer.Character then
      local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
      if hrp and hrp.AssemblyLinearVelocity.Y < -15 then
         -- Персонаж в падении (критический удар булавой)
         for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
               local targetHRP = p.Character:FindFirstChild("HumanoidRootPart")
               if targetHRP then
                  local dist = (hrp.Position - targetHRP.Position).Magnitude
                  if dist <= HitboxSize + 4 and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
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

-- 3. FAST AUTO CLICKER
CombatTab:CreateToggle({
   Name = "Auto Clicker (Зажать ЛКМ)",
   CurrentValue = false,
   Flag = "ClickerToggle",
   Callback = function(val)
      AutoClicker = val
   end,
})

CombatTab:CreateSlider({
   Name = "CPS Speed",
   Range = {6, 25},
   Increment = 1,
   Suffix = " CPS",
   CurrentValue = 16,
   Flag = "CPSSlider",
   Callback = function(val)
      CPSValue = val
   end,
})

task.spawn(function()
   while true do
      if AutoClicker and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
         pcall(function()
            VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
         end)
         task.wait(1 / math.clamp(CPSValue, 5, 30))
      else
         task.wait(0.05)
      end
   end
end)

-- 4. ANTI KNOCKBACK (VELOCITY DAMPENER)
CombatTab:CreateToggle({
   Name = "Anti-Knockback (Гасить откидывание)",
   CurrentValue = true,
   Flag = "AntiKBToggle",
   Callback = function(val)
      AntiKnockback = val
   end,
})

RunService.Heartbeat:Connect(function()
   if AntiKnockback and LocalPlayer.Character then
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

-- 5. MOVEMENT
MoveTab:CreateToggle({
   Name = "Speed Boost",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(val)
      SpeedBoost = val
      if not val and LocalPlayer.Character then
         local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
         if hum then hum.WalkSpeed = 16 end
      end
   end,
})

MoveTab:CreateSlider({
   Name = "WalkSpeed",
   Range = {16, 45},
   Increment = 1,
   Suffix = " ws",
   CurrentValue = 24,
   Flag = "SpeedSlider",
   Callback = function(val)
      SpeedValue = val
   end,
})

RunService.Heartbeat:Connect(function()
   if SpeedBoost and LocalPlayer.Character then
      local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
      if hum and hum.WalkSpeed ~= SpeedValue then
         hum.WalkSpeed = SpeedValue
      end
   end
end)

MoveTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "InfJumpToggle",
   Callback = function(val)
      InfJump = val
   end,
})

UserInputService.JumpRequest:Connect(function()
   if InfJump and LocalPlayer.Character then
      local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
      if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
   end
end)

-- 6. VISUALS (ESP / HIGHLIGHT)
local function applyESP(player)
   if player == LocalPlayer then return end
   local function setupChar(char)
      if not char then return end
      local hl = char:FindFirstChild("StrafexHL") or Instance.new("Highlight")
      hl.Name = "StrafexHL"
      hl.FillColor = Color3.fromRGB(255, 35, 75)
      hl.OutlineColor = Color3.fromRGB(255, 255, 255)
      hl.FillTransparency = 0.5
      hl.OutlineTransparency = 0
      hl.Enabled = ESPEnabled
      hl.Parent = char
   end
   if player.Character then setupChar(player.Character) end
   player.CharacterAdded:Connect(setupChar)
end

for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
Players.PlayerAdded:Connect(applyESP)

VisualTab:CreateToggle({
   Name = "Player ESP / Chams",
   CurrentValue = true,
   Flag = "ESPToggle",
   Callback = function(val)
      ESPEnabled = val
      for _, p in ipairs(Players:GetPlayers()) do
         if p.Character then
            local hl = p.Character:FindFirstChild("StrafexHL")
            if hl then hl.Enabled = val end
         end
      end
   end,
})
