--[[
Boost Hub (Combat & Aim Edition)  |  built with WindUI (Footagesus)
Tabs: Main, ESP, Farm, Aim, Combat
]]
​-- Load WindUI with retries and fallback mirrors
local WINDUI_URLS = {
"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
"https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/dist/main.lua",
}
​local WindUI
for attempt = 1, 3 do
for _, url in ipairs(WINDUI_URLS) do
local ok, lib = pcall(function()
return loadstring(game:HttpGet(url))()
end)
if ok and lib then
WindUI = lib
break
end
end
if WindUI then break end
task.wait(2)
end
​if not WindUI then
warn("[Boost Hub] Could not load WindUI (the download server may be down). Try again in a minute.")
return
end
​-- Services -------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local VirtualInputMgr   = game:GetService("VirtualInputManager")
​local lp = Players.LocalPlayer
​-- Helpers --------------------------------------------------------------
local function getChar(plr)
plr = plr or lp
return plr and plr.Character
end
​local function getHum(plr)
local c = getChar(plr)
return c and c:FindFirstChildOfClass("Humanoid")
end
​local function getRoot(plr)
local c = getChar(plr)
return c and c:FindFirstChild("HumanoidRootPart")
end
​local function notify(title, content)
WindUI:Notify({ Title = title, Content = content, Duration = 3 })
end
​local conns = {}
local function unbind(name)
if conns[name] then
conns[name]:Disconnect()
conns[name] = nil
end
end
local function bind(name, signal, fn)
unbind(name)
conns[name] = signal:Connect(fn)
end
​-- Role & Tool Detection Helpers ----------------------------------------
-- Checks Backpack (and optionally Character if equipped) for a specific tool name
local function hasTool(plr, toolName, checkEquipped)
if not plr then return nil end
local bp = plr:FindFirstChild("Backpack")
if bp then
local t = bp:FindFirstChild(toolName)
if t and t:IsA("Tool") then return t end
end
if checkEquipped and plr.Character then
local t = plr.Character:FindFirstChild(toolName)
if t and t:IsA("Tool") then return t end
end
return nil
end
​local function findPlayerWithTool(toolName)
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= lp then
if hasTool(plr, toolName, true) then
return plr
end
end
end
return nil
end
​local function getMurderer()
return findPlayerWithTool("Knife")
end
​local function getSheriff()
return findPlayerWithTool("Gun")
end
​local function equipTool(toolName)
local char = getChar(lp)
local hum = getHum(lp)
if not (char and hum) then return nil end
​local equipped = char:FindFirstChild(toolName)
if equipped and equipped:IsA("Tool") then
return equipped
end
​local bp = lp:FindFirstChild("Backpack")
local tool = bp and bp:FindFirstChild(toolName)
if tool and tool:IsA("Tool") then
hum:EquipTool(tool)
return tool
end
return nil
end
​local function clickScreenAt(x, y)
pcall(function()
VirtualInputMgr:SendMouseButtonEvent(x, y, 0, true, game, 1)
task.wait(0.03)
VirtualInputMgr:SendMouseButtonEvent(x, y, 0, false, game, 1)
end)
end
​local function clickCenterScreen()
local cam = workspace.CurrentCamera
if cam then
local vp = cam.ViewportSize
clickScreenAt(vp.X / 2, vp.Y / 2)
else
VirtualUser:CaptureController()
VirtualUser:ClickButton1(Vector2.new())
end
end
​-- Window ---------------------------------------------------------------
local Window = WindUI:CreateWindow({
Title = "Boost Hub",
Icon = "rocket",
Author = "Boost Hub",
Folder = "BoostHub",
Size = UDim2.fromOffset(580, 480),
Theme = "Dark",
})
​pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)
​local MainTab   = Window:Tab({ Title = "Main",   Icon = "user" })
local ESPTab    = Window:Tab({ Title = "ESP",    Icon = "eye" })
local FarmTab   = Window:Tab({ Title = "Farm",   Icon = "coins" })
local AimTab    = Window:Tab({ Title = "Aim",    Icon = "crosshair" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "sword" })
​-- =====================================================================
-- MAIN (Player)
-- =====================================================================
local DEFAULT_SPEED, DEFAULT_JUMP, DEFAULT_GRAVITY = 16, 50, workspace.Gravity
​local state = {
speedOn = false, speed = 50,
jumpOn = false,  jump = 100,
flyOn = false,   flySpeed = 60,
}
​local farm = { on = false, run = 0, speed = 20, underground = false, depth = 4 }
​MainTab:Section({ Title = "Movement" })
​MainTab:Slider({
Title = "WalkSpeed",
Step = 1,
Value = { Min = 16, Max = 300, Default = 50 },
Callback = function(v) state.speed = v end,
})
MainTab:Toggle({
Title = "Enable WalkSpeed",
Desc = "Keeps your custom speed applied",
Value = false, Default = false,
Callback = function(on)
state.speedOn = on
if not on then
local h = getHum()
if h then h.WalkSpeed = DEFAULT_SPEED end
end
end,
})
​MainTab:Slider({
Title = "JumpPower",
Step = 1,
Value = { Min = 50, Max = 400, Default = 100 },
Callback = function(v) state.jump = v end,
})
MainTab:Toggle({
Title = "Enable JumpPower",
Value = false, Default = false,
Callback = function(on)
state.jumpOn = on
if not on then
local h = getHum()
if h then h.JumpPower = DEFAULT_JUMP end
end
end,
})
​RunService.Heartbeat:Connect(function()
local h = getHum()
if not h then return end
if state.speedOn then h.WalkSpeed = state.speed end
if state.jumpOn then
h.UseJumpPower = true
h.JumpPower = state.jump
end
end)
​MainTab:Slider({
Title = "Gravity",
Step = 1,
Value = { Min = 0, Max = 400, Default = math.floor(DEFAULT_GRAVITY) },
Callback = function(v) workspace.Gravity = v end,
})
​MainTab:Toggle({
Title = "Infinite Jump",
Value = false, Default = false,
Callback = function(on)
if on then
bind("infjump", UserInputService.JumpRequest, function()
local h = getHum()
if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
else
unbind("infjump")
end
end,
})
​MainTab:Toggle({
Title = "Noclip",
Desc = "Walk through walls",
Value = false, Default = false,
Callback = function(on)
if on then
bind("noclip", RunService.Stepped, function()
local c = getChar()
if not c then return end
for _, p in ipairs(c:GetDescendants()) do
if p:IsA("BasePart") and p.CanCollide then
p.CanCollide = false
end
end
end)
else
unbind("noclip")
end
end,
})
​-- Fly --------------------------------------------------------------
MainTab:Section({ Title = "Fly" })
​local flyBV, flyBG
​local function stopFly()
unbind("fly")
if flyBV then flyBV:Destroy() flyBV = nil end
if flyBG then flyBG:Destroy() flyBG = nil end
local h = getHum()
if h then h.PlatformStand = false end
end
​local function startFly()
bind("fly", RunService.RenderStepped, function()
local root, hum, cam = getRoot(), getHum(), workspace.CurrentCamera
if not (root and hum and cam) then return end
​if not flyBV or flyBV.Parent ~= root then
if flyBV then flyBV:Destroy() end
flyBV = Instance.new("BodyVelocity")
flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
flyBV.Velocity = Vector3.zero
flyBV.Parent = root
end
if not flyBG or flyBG.Parent ~= root then
if flyBG then flyBG:Destroy() end
flyBG = Instance.new("BodyGyro")
flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
flyBG.P = 1e4
flyBG.D = 100
flyBG.Parent = root
end
​hum.PlatformStand = true
​local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
local flatLook = Vector3.new(look.X, 0, look.Z)
local flatRight = Vector3.new(right.X, 0, right.Z)
flatLook = flatLook.Magnitude > 1e-3 and flatLook.Unit or Vector3.new(0, 0, -1)
flatRight = flatRight.Magnitude > 1e-3 and flatRight.Unit or Vector3.new(1, 0, 0)
​local md = hum.MoveDirection
local dir = look * md:Dot(flatLook) + right * md:Dot(flatRight)
​if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
​flyBV.Velocity = dir * state.flySpeed
flyBG.CFrame = cam.CFrame
end)
end
​MainTab:Slider({
Title = "Fly Speed",
Step = 1,
Value = { Min = 10, Max = 300, Default = 60 },
Callback = function(v) state.flySpeed = v end,
})
MainTab:Toggle({
Title = "Fly",
Desc = "WASD / joystick to move, Space up, Ctrl down. Turn off while Auto Farm is running.",
Value = false, Default = false,
Callback = function(on)
state.flyOn = on
if on then startFly() else stopFly() end
end,
})
​-- Protection & Fling -----------------------------------------------
MainTab:Section({ Title = "Protection & Target Fling" })
​local isFlinging = false
​local function flingTarget(targetPlr, roleName)
if not targetPlr then
notify("Fling", "Could not find " .. roleName .. "!")
return
end
local myRoot = getRoot(lp)
local myHum = getHum(lp)
local tRoot = getRoot(targetPlr)
if not (myRoot and myHum and tRoot) then
notify("Fling", "Character not ready.")
return
end
​if isFlinging then return end
isFlinging = true
notify("Fling", "Flinging " .. targetPlr.DisplayName .. " (" .. roleName .. ")...")
​local oldCFrame = myRoot.CFrame
local oldWalkSpeed = myHum.WalkSpeed
​local bav = Instance.new("BodyAngularVelocity")
bav.AngularVelocity = Vector3.new(0, 99999, 0)
bav.MaxTorque = Vector3.new(0, math.huge, 0)
bav.P = math.huge
bav.Parent = myRoot
​local noclipConn = RunService.Stepped:Connect(function()
local c = getChar(lp)
if c then
for _, p in ipairs(c:GetDescendants()) do
if p:IsA("BasePart") then
p.CanCollide = false
end
end
end
end)
​local startTime = os.clock()
while os.clock() - startTime < 2.2 do
if not targetPlr.Parent or not tRoot.Parent then break end
myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 0.5)
myRoot.AssemblyLinearVelocity = Vector3.new(500, 500, 500)
task.wait()
end
​noclipConn:Disconnect()
bav:Destroy()
myRoot.AssemblyLinearVelocity = Vector3.zero
myRoot.AssemblyAngularVelocity = Vector3.zero
myRoot.CFrame = oldCFrame
myHum.WalkSpeed = oldWalkSpeed
isFlinging = false
notify("Fling", "Finished flinging " .. roleName .. ".")
end
​MainTab:Button({
Title = "Fling Murderer",
Desc = "Flings the player who has the Knife tool",
Callback = function()
task.spawn(function()
flingTarget(getMurderer(), "Murderer")
end)
end,
})
​MainTab:Button({
Title = "Fling Sheriff",
Desc = "Flings the player who has the Gun tool",
Callback = function()
task.spawn(function()
flingTarget(getSheriff(), "Sheriff")
end)
end,
})
​MainTab:Toggle({
Title = "Anti AFK",
Desc = "Prevents the 20 minute idle kick",
Value = false, Default = false,
Callback = function(on)
if on then
bind("antiafk", lp.Idled, function()
VirtualUser:CaptureController()
VirtualUser:ClickButton2(Vector2.new())
end)
else
unbind("antiafk")
end
end,
})
​MainTab:Toggle({
Title = "Anti Fling",
Desc = "Disables collisions with other players and cancels extreme velocity",
Value = false, Default = false,
Callback = function(on)
if on then
bind("antifling", RunService.Stepped, function()
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= lp and plr.Character then
for _, p in ipairs(plr.Character:GetDescendants()) do
if p:IsA("BasePart") and p.CanCollide then
p.CanCollide = false
end
end
end
end
local root = getRoot()
if root and not state.flyOn and not farm.on and not isFlinging then
if root.AssemblyLinearVelocity.Magnitude > 150
or root.AssemblyAngularVelocity.Magnitude > 50 then
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end
end
end)
else
unbind("antifling")
end
end,
})
​MainTab:Section({ Title = "Misc" })
​MainTab:Button({
Title = "Reset Character",
Callback = function()
local h = getHum()
if h then h.Health = 0 end
end,
})
​MainTab:Button({
Title = "Reset All Movement",
Desc = "Restores default speed, jump and gravity",
Callback = function()
local h = getHum()
if h then
h.WalkSpeed = DEFAULT_SPEED
h.JumpPower = DEFAULT_JUMP
end
workspace.Gravity = DEFAULT_GRAVITY
notify("Main", "Movement reset to defaults")
end,
})
​-- =====================================================================
-- ESP (Role-Based Color Detection)
-- =====================================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "BoostHubESP"
local okParent = pcall(function()
espFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not okParent then
espFolder.Parent = lp:WaitForChild("PlayerGui")
end
​local coinCache, coinCacheTime = {}, 0
local function getCoins()
if os.clock() - coinCacheTime > 1 then
coinCacheTime = os.clock()
local list = {}
for _, d in ipairs(workspace:GetDescendants()) do
if d.Name == "Coin_Server" and d:IsA("BasePart") then
list[#list + 1] = d
end
end
coinCache = list
end
return coinCache
end
​local COLOR_SHERIFF  = Color3.fromRGB(0, 140, 255)   -- Blue (Gun in Backpack/Equipped)
local COLOR_MURDERER = Color3.fromRGB(255, 50, 50)   -- Red (Knife in Backpack/Equipped)
local COLOR_INNOCENT = Color3.fromRGB(50, 230, 90)   -- Green (Neither)
​local function getPlayerRoleInfo(plr)
local bp = plr:FindFirstChild("Backpack")
local char = plr.Character
​local hasKnife = (bp and bp:FindFirstChild("Knife")) or (char and char:FindFirstChild("Knife"))
if hasKnife then
return COLOR_MURDERER, "Murderer"
end
​local hasGun = (bp and bp:FindFirstChild("Gun")) or (char and char:FindFirstChild("Gun"))
if hasGun then
return COLOR_SHERIFF, "Sheriff"
end
​return COLOR_INNOCENT, "Innocent"
end
​-- Role-aware Model ESP
local playerESP = { entries = {}, conn = nil, last = 0 }
​function playerESP.Remove(model)
local e = playerESP.entries[model]
if e then
e.hl:Destroy()
e.gui:Destroy()
playerESP.entries[model] = nil
end
end
​function playerESP.Add(model, plr)
local part = model:FindFirstChild("Head")
or model.PrimaryPart
or model:FindFirstChildWhichIsA("BasePart")
if not part then return end
​local color, role = getPlayerRoleInfo(plr)
​local hl = Instance.new("Highlight")
hl.Adornee = model
hl.FillColor = color
hl.OutlineColor = Color3.new(1, 1, 1)
hl.FillTransparency = 0.55
hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hl.Parent = espFolder
​local gui = Instance.new("BillboardGui")
gui.Adornee = part
gui.Size = UDim2.fromOffset(220, 32)
gui.StudsOffset = Vector3.new(0, 2.5, 0)
gui.AlwaysOnTop = true
gui.Parent = espFolder
​local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.TextColor3 = color
label.TextStrokeTransparency = 0.3
label.TextSize = 14
label.Font = Enum.Font.GothamBold
label.Parent = gui
​playerESP.entries[model] = {
hl = hl,
gui = gui,
label = label,
plr = plr,
part = part,
role = role
}
end
​function playerESP.Start()
if playerESP.conn then return end
playerESP.conn = RunService.RenderStepped:Connect(function()
local now = os.clock()
if now - playerESP.last >= 0.25 then
playerESP.last = now
local activeModels = {}
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= lp and plr.Character then
activeModels[plr.Character] = plr
end
end
​for model in pairs(playerESP.entries) do
if not activeModels[model] or not model.Parent then
playerESP.Remove(model)
end
end
​for model, plr in pairs(activeModels) do
if not playerESP.entries[model] then
playerESP.Add(model, plr)
end
end
end
​local root = getRoot()
for model, e in pairs(playerESP.entries) do
if e.plr and e.plr.Parent then
local color, role = getPlayerRoleInfo(e.plr)
e.hl.FillColor = color
e.label.TextColor3 = color
​local hum = model:FindFirstChildOfClass("Humanoid")
local dist = root and math.floor((e.part.Position - root.Position).Magnitude) or 0
local hp = hum and string.format(" | %d HP", math.floor(hum.Health)) or ""
e.label.Text = string.format("[%s] %s [%dm]%s", role, e.plr.DisplayName, dist, hp)
end
end
end)
end
​function playerESP.Stop()
if playerESP.conn then
playerESP.conn:Disconnect()
playerESP.conn = nil
end
for model in pairs(playerESP.entries) do
playerESP.Remove(model)
end
end
​-- Part based ESP (coins)
local coinESP = { entries = {}, conn = nil, last = 0 }
​local function removeCoinESP(part)
local gui = coinESP.entries[part]
if gui then
gui:Destroy()
coinESP.entries[part] = nil
end
end
​local function addCoinESP(part)
local gui = Instance.new("BillboardGui")
gui.Adornee = part
gui.Size = UDim2.fromOffset(14, 14)
gui.AlwaysOnTop = true
gui.Parent = espFolder
​local dot = Instance.new("Frame")
dot.Size = UDim2.fromScale(1, 1)
dot.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
dot.BorderSizePixel = 0
dot.Parent = gui
​local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = dot
​local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(1, 1, 1)
stroke.Thickness = 1.5
stroke.Parent = dot
​coinESP.entries[part] = gui
end
​local function startCoinESP()
if coinESP.conn then return end
coinESP.conn = RunService.Heartbeat:Connect(function()
if os.clock() - coinESP.last < 1 then return end
coinESP.last = os.clock()
​local alive = {}
for _, coin in ipairs(getCoins()) do
if coin.Parent then alive[coin] = true end
end
for part in pairs(coinESP.entries) do
if not alive[part] then removeCoinESP(part) end
end
for part in pairs(alive) do
if not coinESP.entries[part] then addCoinESP(part) end
end
end)
end
​local function stopCoinESP()
if coinESP.conn then
coinESP.conn:Disconnect()
coinESP.conn = nil
end
for part in pairs(coinESP.entries) do removeCoinESP(part) end
end
​ESPTab:Toggle({
Title = "ESP Players (Role Colors)",
Desc = "Blue = Gun (Sheriff), Red = Knife (Murderer), Green = Innocent",
Value = false, Default = false,
Callback = function(on)
if on then playerESP.Start() else playerESP.Stop() end
end,
})
​ESPTab:Toggle({
Title = "ESP Coins",
Desc = "Marks every Coin_Server part with a gold dot",
Value = false, Default = false,
Callback = function(on)
if on then startCoinESP() else stopCoinESP() end
end,
})
​-- =====================================================================
-- FARM
-- =====================================================================
local visited = setmetatable({}, { __mode = "k" })
local farmBV
local currentTween
​local function nearestCoin(fromPos)
local best, bestDist
local now = os.clock()
for _, coin in ipairs(getCoins()) do
if coin.Parent and not (visited[coin] and now - visited[coin] < 3) then
local d = (coin.Position - fromPos).Magnitude
if not bestDist or d < bestDist then
best, bestDist = coin, d
end
end
end
return best
end
​local function stopFarm()
farm.on = false
farm.run += 1
unbind("farmnoclip")
if currentTween then
currentTween:Cancel()
currentTween = nil
end
if farmBV then
farmBV:Destroy()
farmBV = nil
end
end
​local function startFarm()
stopFarm()
farm.on = true
farm.run += 1
local id = farm.run
​bind("farmnoclip", RunService.Stepped, function()
local c = getChar()
if not c then return end
for _, p in ipairs(c:GetDescendants()) do
if p:IsA("BasePart") and p.CanCollide then
p.CanCollide = false
end
end
end)
​task.spawn(function()
while farm.on and farm.run == id do
local root, hum = getRoot(), getHum()
if not root or not hum or hum.Health <= 0 then
task.wait(0.5)
continue
end
​if not farmBV or farmBV.Parent ~= root then
if farmBV then farmBV:Destroy() end
farmBV = Instance.new("BodyVelocity")
farmBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
farmBV.Velocity = Vector3.zero
farmBV.Parent = root
end
​local coin = nearestCoin(root.Position)
if not coin then
task.wait(0.3)
continue
end
​local goal = coin.Position
if farm.underground then
goal -= Vector3.new(0, farm.depth, 0)
end
​local dist = (goal - root.Position).Magnitude
local duration = math.max(dist / farm.speed, 0.03)
​currentTween = TweenService:Create(
root,
TweenInfo.new(duration, Enum.EasingStyle.Linear),
{ CFrame = CFrame.new(goal) }
)
currentTween:Play()
​while farm.on and farm.run == id and currentTween
and currentTween.PlaybackState == Enum.PlaybackState.Playing
and coin.Parent do
task.wait()
end
​if currentTween then
currentTween:Cancel()
currentTween = nil
end
​visited[coin] = os.clock()
task.wait(0.1)
end
end)
end
​FarmTab:Section({ Title = "Coins" })
​FarmTab:Slider({
Title = "Tween Speed",
Desc = "Studs per second (10 - 27). Lower is safer.",
Step = 1,
Value = { Min = 10, Max = 27, Default = 20 },
Callback = function(v) farm.speed = tonumber(v) or 20 end,
})
​FarmTab:Toggle({
Title = "Auto Farm Coins",
Desc = "Tweens to the nearest coin through walls and floors",
Value = false, Default = false,
Callback = function(on)
if on then startFarm() else stopFarm() end
end,
})
​FarmTab:Toggle({
Title = "Underground Farm",
Desc = "While Auto Farm is on, you travel underneath the coins",
Value = false, Default = false,
Callback = function(on) farm.underground = on end,
})
​FarmTab:Slider({
Title = "Underground Depth",
Desc = "How many studs below the coin. Too deep may stop coins from collecting.",
Step = 1,
Value = { Min = 2, Max = 12, Default = 4 },
Callback = function(v) farm.depth = tonumber(v) or 4 end,
})
​-- =====================================================================
-- AIM (Sheriff / Gun Features)
-- =====================================================================
AimTab:Section({ Title = "Sheriff Actions" })
​local function shootMurderer(silentNoGun)
local gun = hasTool(lp, "Gun", true)
if not gun then
if not silentNoGun then
notify("Aim", "You don't have gun to shoot murderer")
end
return false
end
​local murderer = getMurderer()
if not murderer then
if not silentNoGun then
notify("Aim", "Murderer not found!")
end
return false
end
​local mRoot = getRoot(murderer)
local cam = workspace.CurrentCamera
if not (mRoot and cam) then return false end
​-- Equip Gun
equipTool("Gun")
task.wait(0.05)
​-- Aim camera directly at Murderer's HumanoidRootPart and tap on it
local oldCFrame = cam.CFrame
cam.CFrame = CFrame.new(cam.CFrame.Position, mRoot.Position)
​local screenPos, onScreen = cam:WorldToViewportPoint(mRoot.Position)
if onScreen then
clickScreenAt(screenPos.X, screenPos.Y)
else
clickCenterScreen()
end
​-- Also activate tool directly in case the game listens to Tool:Activate()
pcall(function()
local equippedGun = getChar(lp) and getChar(lp):FindFirstChild("Gun")
if equippedGun then equippedGun:Activate() end
end)
​task.wait(0.05)
cam.CFrame = oldCFrame
return true
end
​AimTab:Button({
Title = "Shoot Murderer",
Desc = "Equips Gun and taps directly on the Murderer's HumanoidRootPart",
Callback = function()
task.spawn(function()
shootMurderer(false)
end)
end,
})
​local autoShootOn = false
AimTab:Toggle({
Title = "Auto Shoot Murderer",
Desc = "Automatically shoots the Murderer whenever you have the Gun in your inventory",
Value = false, Default = false,
Callback = function(on)
autoShootOn = on
if on then
task.spawn(function()
while autoShootOn do
if hasTool(lp, "Gun", true) and getMurderer() then
shootMurderer(true)
task.wait(0.6)
end
task.wait(0.2)
end
end)
end
end,
})
​local autoClaimGunOn = false
AimTab:Toggle({
Title = "Auto Claim Gun",
Desc = "Automatically teleports to DroppedGun when it spawns",
Value = false, Default = false,
Callback = function(on)
autoClaimGunOn = on
if on then
task.spawn(function()
while autoClaimGunOn do
local root = getRoot(lp)
if root and not hasTool(lp, "Gun", true) then
local dropped = workspace:FindFirstChild("DroppedGun", true)
if dropped then
local targetPart = dropped:IsA("BasePart") and dropped or dropped:FindFirstChildWhichIsA("BasePart")
if targetPart then
local oldPos = root.CFrame
root.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0)
task.wait(0.15)
if firetouchinterest then
pcall(function()
firetouchinterest(root, targetPart, 0)
task.wait()
firetouchinterest(root, targetPart, 1)
end)
end
task.wait(0.15)
root.CFrame = oldPos
end
end
end
task.wait(0.3)
end
end)
end
end,
})
​AimTab:Section({ Title = "Shiftlock Aim" })
​local autoAimShiftlockOn = false
AimTab:Toggle({
Title = "Auto Aim At Murderer",
Desc = "Enables Shiftlock behavior and locks aim directly onto Murderer's HumanoidRootPart",
Value = false, Default = false,
Callback = function(on)
autoAimShiftlockOn = on
if on then
bind("aimShiftlock", RunService.RenderStepped, function()
local myRoot = getRoot(lp)
local myHum = getHum(lp)
local cam = workspace.CurrentCamera
local murderer = getMurderer()
local mRoot = murderer and getRoot(murderer)
​if myRoot and myHum and cam and mRoot then
-- Force Shiftlock style camera & character orientation
pcall(function()
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end)
myHum.AutoRotate = false
​-- Point camera at Murderer's HumanoidRootPart with slight shoulder offset
local shoulderOffset = cam.CFrame.RightVector * 1.75 + Vector3.new(0, 0.5, 0)
local camOrigin = cam.CFrame.Position
cam.CFrame = CFrame.new(camOrigin, mRoot.Position)
​-- Rotate character horizontally to match Shiftlock direction toward Murderer
local flatLook = Vector3.new(mRoot.Position.X - myRoot.Position.X, 0, mRoot.Position.Z - myRoot.Position.Z)
if flatLook.Magnitude > 0.01 then
myRoot.CFrame = CFrame.new(myRoot.Position, myRoot.Position + flatLook.Unit)
end
end
end)
else
unbind("aimShiftlock")
pcall(function()
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end)
local myHum = getHum(lp)
if myHum then myHum.AutoRotate = true end
end
end,
})
​-- =====================================================================
-- COMBAT (Murderer / Knife Features)
-- =====================================================================
CombatTab:Section({ Title = "Murderer Actions" })
​local function verifyMurdererRole(silent)
local knife = hasTool(lp, "Knife", true)
if not knife then
if not silent then
notify("Combat", "You are not murderer silly!")
end
return false
end
return true
end
​local function executeKillTargets(targetList)
local myRoot = getRoot(lp)
if not myRoot then return end
​local knife = equipTool("Knife")
if not knife then return end
​for _, plr in ipairs(targetList) do
if plr ~= lp and plr.Character then
local tRoot = getRoot(plr)
local tHum = getHum(plr)
if tRoot and tHum and tHum.Health > 0 then
-- Bring player within 1 stud in front of you
tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -1)
end
end
end
​task.wait(0.05)
-- Slash / click screen to kill
clickCenterScreen()
pcall(function()
local eqKnife = getChar(lp) and getChar(lp):FindFirstChild("Knife")
if eqKnife then eqKnife:Activate() end
end)
end
​CombatTab:Button({
Title = "Kill All",
Desc = "Brings all players within 1 stud of you, equips Knife, and attacks",
Callback = function()
if not verifyMurdererRole(false) then return end
task.spawn(function()
executeKillTargets(Players:GetPlayers())
end)
end,
})
​CombatTab:Button({
Title = "Kill Sheriff",
Desc = "Brings the player with the Gun tool to you and eliminates them with Knife",
Callback = function()
if not verifyMurdererRole(false) then return end
local sheriff = getSheriff()
if not sheriff then
notify("Combat", "No Sheriff found!")
return
end
task.spawn(function()
executeKillTargets({ sheriff })
end)
end,
})
​local autoKillAllOn = false
CombatTab:Toggle({
Title = "Auto Kill All",
Desc = "Automatically brings and eliminates all players while you have the Knife",
Value = false, Default = false,
Callback = function(on)
if on and not verifyMurdererRole(false) then
autoKillAllOn = false
return
end
autoKillAllOn = on
if on then
task.spawn(function()
while autoKillAllOn do
if hasTool(lp, "Knife", true) then
executeKillTargets(Players:GetPlayers())
end
task.wait(0.25)
end
end)
end
end,
})
​Window:SelectTab(1)
notify("Boost Hub", "Loaded. Press RightShift to toggle the window.")
