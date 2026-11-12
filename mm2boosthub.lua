--[[
    Boost Hub (Complete Edition) | built with WindUI
    Tabs: Main, ESP, Farm, Aim, Combat
]]

-- Load WindUI using the standard clean loadstring
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

if not WindUI then
    warn("[Boost Hub] Failed to load WindUI.")
    return
end

-- Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer

-- Helpers
local function getChar() return lp.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function notify(title, content)
    WindUI:Notify({ Title = title, Content = content, Duration = 3 })
end

local conns = {}
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

-- Window Setup with Emerald Theme
local Window = WindUI:CreateWindow({
    Title = "Boost Hub",
    Icon = "rocket",
    Author = "Boost Hub",
    Folder = "BoostHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
})

pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)

local MainTab   = Window:Tab({ Title = "Main",   Icon = "user" })
local ESPTab    = Window:Tab({ Title = "ESP",    Icon = "eye" })
local FarmTab   = Window:Tab({ Title = "Farm",   Icon = "coins" })
local AimTab    = Window:Tab({ Title = "Aim",    Icon = "crosshair" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })

-- =====================================================================
-- MAIN (Player & Fling)
-- =====================================================================
local DEFAULT_SPEED, DEFAULT_JUMP, DEFAULT_GRAVITY = 16, 50, workspace.Gravity
local state = {
    speedOn = false, speed = 50,
    jumpOn = false,  jump = 100,
    flyOn = false,   flySpeed = 60,
}
local farm = { on = false, run = 0, speed = 20, underground = false, depth = 4 }

MainTab:Section({ Title = "Movement" })
MainTab:Slider({
    Title = "WalkSpeed",
    Step = 1,
    Value = { Min = 16, Max = 300, Default = 50 },
    Callback = function(v) state.speed = v end,
})
MainTab:Toggle({
    Title = "Enable WalkSpeed",
    Value = false, Default = false,
    Callback = function(on)
        state.speedOn = on
        if not on then
            local h = getHum()
            if h then h.WalkSpeed = DEFAULT_SPEED end
        end
    end,
})

MainTab:Slider({
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

RunService.Heartbeat:Connect(function()
    local h = getHum()
    if not h then return end
    if state.speedOn then h.WalkSpeed = state.speed end
    if state.jumpOn then
        h.UseJumpPower = true
        h.JumpPower = state.jump
    end
end)

MainTab:Slider({
    Title = "Gravity",
    Step = 1,
    Value = { Min = 0, Max = 400, Default = math.floor(DEFAULT_GRAVITY) },
    Callback = function(v) workspace.Gravity = v end,
})

MainTab:Toggle({
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

MainTab:Toggle({
    Title = "Noclip",
    Value = false, Default = false,
    Callback = function(on)
        if on then
            bind("noclip", RunService.Stepped, function()
                local c = getChar()
                if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end)
        else
            unbind("noclip")
        end
    end,
})

-- Fly
MainTab:Section({ Title = "Fly" })
local flyBV, flyBG

local function stopFly()
    unbind("fly")
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local h = getHum()
    if h then h.PlatformStand = false end
end

local function startFly()
    bind("fly", RunService.RenderStepped, function()
        local root, hum, cam = getRoot(), getHum(), workspace.CurrentCamera
        if not (root and hum and cam) then return end

        if not flyBV or flyBV.Parent ~= root then
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

        hum.PlatformStand = true
        local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
        local flatLook = Vector3.new(look.X, 0, look.Z).Unit
        local flatRight = Vector3.new(right.X, 0, right.Z).Unit
        local md = hum.MoveDirection
        local dir = flatLook * md.Z + flatRight * md.X

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end

        flyBV.Velocity = dir * state.flySpeed
        flyBG.CFrame = cam.CFrame
    end)
end

MainTab:Slider({
    Title = "Fly Speed",
    Step = 1,
    Value = { Min = 10, Max = 300, Default = 60 },
    Callback = function(v) state.flySpeed = v end,
})
MainTab:Toggle({
    Title = "Fly",
    Value = false, Default = false,
    Callback = function(on)
        state.flyOn = on
        if on then startFly() else stopFly() end
    end,
})

-- Protection & Target Fling
MainTab:Section({ Title = "Protection & Targets" })

MainTab:Toggle({
    Title = "Anti AFK",
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

MainTab:Toggle({
    Title = "Anti Fling",
    Value = false, Default = false,
    Callback = function(on)
        if on then
            bind("antifling", RunService.Stepped, function()
                local root = getRoot()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp and plr.Character then
                        for _, p in ipairs(plr.Character:GetDescendants()) do
                            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                        end
                    end
                end
                if root and not state.flyOn and not farm.on then
                    if root.AssemblyLinearVelocity.Magnitude > 150 or root.AssemblyAngularVelocity.Magnitude > 50 then
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

local function getPlayerByTool(toolName)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local bp = plr:FindFirstChild("Backpack")
            local char = plr.Character
            local has = false
            if bp and bp:FindFirstChild(toolName) then has = true end
            if char and char:FindFirstChild(toolName) then has = true end
            if has then return plr end
        end
    end
end

local function flingTarget(targetPlr)
    local root = getRoot()
    local targetRoot = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not root or not targetRoot then
        notify("Fling", "Target not found or dead")
        return
    end
    local rotVel = root.AssemblyAngularVelocity
    root.AssemblyAngularVelocity = Vector3.new(0, 99999, 0)
    task.wait(0.2)
    root.CFrame = targetRoot.CFrame
    task.wait(0.2)
    root.AssemblyAngularVelocity = rotVel
    notify("Fling", "Flung " .. targetPlr.Name)
end

MainTab:Button({
    Title = "Fling Murderer",
    Callback = function()
        local m = getPlayerByTool("Knife")
        if m then flingTarget(m) else notify("Fling", "No Murderer found!") end
    end,
})

MainTab:Button({
    Title = "Fling Sheriff",
    Callback = function()
        local s = getPlayerByTool("Gun")
        if s then flingTarget(s) else notify("Fling", "No Sheriff found!") end
    end,
})

-- =====================================================================
-- ESP (Role Colored)
-- =====================================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "BoostHubESP"
pcall(function() espFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not espFolder.Parent then espFolder.Parent = lp:WaitForChild("PlayerGui") end

local function getCoins()
    local list = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == "Coin_Server" and d:IsA("BasePart") then
            list[#list + 1] = d
        end
    end
    return list
end

local espEntries = {}
local function clearESP()
    for _, e in pairs(espEntries) do
        if e.hl then e.hl:Destroy() end
        if e.gui then e.gui:Destroy() end
    end
    espEntries = {}
end

local espRunning = false
local function togglePlayerESP(on)
    espRunning = on
    if not on then
        clearESP()
        return
    end
    task.spawn(function()
        while espRunning do
            local currentModels = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp and plr.Character then
                    local char = plr.Character
                    local bp = plr:FindFirstChild("Backpack")
                    local color = Color3.fromRGB(0, 255, 0) -- Green default
                    local roleName = plr.DisplayName

                    local hasGun = (bp and bp:FindFirstChild("Gun")) or char:FindFirstChild("Gun")
                    local hasKnife = (bp and bp:FindFirstChild("Knife")) or char:FindFirstChild("Knife")

                    if hasGun then
                        color = Color3.fromRGB(0, 150, 255) -- Blue for Sheriff/Gun
                        roleName = roleName .. " [GUN]"
                    elseif hasKnife then
                        color = Color3.fromRGB(255, 50, 50) -- Red for Murderer
                        roleName = roleName .. " [KNIFE]"
                    end

                    currentModels[char] = { color = color, name = roleName }
                end
            end

            for model, e in pairs(espEntries) do
                if not currentModels[model] or not model.Parent then
                    if e.hl then e.hl:Destroy() end
                    if e.gui then e.gui:Destroy() end
                    espEntries[model] = nil
                end
            end

            local root = getRoot()
            for model, data in pairs(currentModels) do
                local e = espEntries[model]
                local head = model:FindFirstChild("Head") or model.PrimaryPart
                if head then
                    if not e then
                        local hl = Instance.new("Highlight")
                        hl.Adornee = model
                        hl.FillColor = data.color
                        hl.OutlineColor = Color3.new(1, 1, 1)
                        hl.FillTransparency = 0.5
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = espFolder

                        local gui = Instance.new("BillboardGui")
                        gui.Adornee = head
                        gui.Size = UDim2.fromOffset(200, 30)
                        gui.StudsOffset = Vector3.new(0, 2.5, 0)
                        gui.AlwaysOnTop = true
                        gui.Parent = espFolder

                        local label = Instance.new("TextLabel")
                        label.BackgroundTransparency = 1
                        label.Size = UDim2.fromScale(1, 1)
                        label.TextColor3 = data.color
                        label.TextStrokeTransparency = 0.3
                        label.TextSize = 14
                        label.Font = Enum.Font.GothamBold
                        label.Parent = gui

                        espEntries[model] = { hl = hl, gui = gui, label = label, head = head }
                        e = espEntries[model]
                    else
                        e.hl.FillColor = data.color
                        e.label.TextColor3 = data.color
                    end

                    local dist = root and math.floor((head.Position - root.Position).Magnitude) or 0
                    e.label.Text = string.format("%s [%dm]", data.name, dist)
                end
            end
            task.wait(0.2)
        end
    end)
end

ESPTab:Toggle({
    Title = "ESP Players (Role Colored)",
    Desc = "Red = Knife, Blue = Gun, Green = Innocent",
    Value = false, Default = false,
    Callback = function(on) togglePlayerESP(on) end,
})

local coinESPEntries = {}
local coinESPRunning = false
local function toggleCoinESP(on)
    coinESPRunning = on
    if not on then
        for _, g in pairs(coinESPEntries) do g:Destroy() end
        coinESPEntries = {}
        return
    end
    task.spawn(function()
        while coinESPRunning do
            local alive = {}
            for _, coin in ipairs(getCoins()) do
                if coin.Parent then alive[coin] = true end
            end
            for part, gui in pairs(coinESPEntries) do
                if not alive[part] then gui:Destroy() coinESPEntries[part] = nil end
            end
            for part in pairs(alive) do
                if not coinESPEntries[part] then
                    local gui = Instance.new("BillboardGui")
                    gui.Adornee = part
                    gui.Size = UDim2.fromOffset(12, 12)
                    gui.AlwaysOnTop = true
                    gui.Parent = espFolder
                    local dot = Instance.new("Frame")
                    dot.Size = UDim2.fromScale(1, 1)
                    dot.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                    dot.BorderSizePixel = 0
                    dot.Parent = gui
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(1, 0)
                    corner.Parent = dot
                    coinESPEntries[part] = gui
                end
            end
            task.wait(1)
        end
    end)
end

ESPTab:Toggle({
    Title = "ESP Coins",
    Value = false, Default = false,
    Callback = function(on) toggleCoinESP(on) end,
})

-- =====================================================================
-- FARM
-- =====================================================================
local visited = setmetatable({}, { __mode = "k" })
local farmBV, currentTween

local function stopFarm()
    farm.on = false
    farm.run += 1
    unbind("farmnoclip")
    if currentTween then currentTween:Cancel() currentTween = nil end
    if farmBV then farmBV:Destroy() farmBV = nil end
end

local function startFarm()
    stopFarm()
    farm.on = true
    farm.run += 1
    local id = farm.run

    bind("farmnoclip", RunService.Stepped, function()
        local c = getChar()
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)

    task.spawn(function()
        while farm.on and farm.run == id do
            local root, hum = getRoot(), getHum()
            if not root or not hum or hum.Health <= 0 then
                task.wait(0.5)
                continue
            end

            if not farmBV or farmBV.Parent ~= root then
                if farmBV then farmBV:Destroy() end
                farmBV = Instance.new("BodyVelocity")
                farmBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                farmBV.Velocity = Vector3.zero
                farmBV.Parent = root
            end

            local best, bestDist
            local now = os.clock()
            for _, coin in ipairs(getCoins()) do
                if coin.Parent and not (visited[coin] and now - visited[coin] < 3) then
                    local d = (coin.Position - root.Position).Magnitude
                    if not bestDist or d < bestDist then
                        best, bestDist = coin, d
                    end
                end
            end

            if not best then
                task.wait(0.3)
                continue
            end

            local goal = best.Position
            if farm.underground then goal -= Vector3.new(0, farm.depth, 0) end

            local dist = (goal - root.Position).Magnitude
            currentTween = TweenService:Create(root, TweenInfo.new(math.max(dist / farm.speed, 0.03), Enum.EasingStyle.Linear), { CFrame = CFrame.new(goal) })
            currentTween:Play()

            while farm.on and farm.run == id and currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing and best.Parent do
                task.wait()
            end

            if currentTween then currentTween:Cancel() currentTween = nil end
            visited[best] = os.clock()
            task.wait(0.1)
        end
    end)
end

FarmTab:Section({ Title = "Coin Auto Farm" })
FarmTab:Slider({
    Title = "Tween Speed",
    Step = 1,
    Value = { Min = 10, Max = 27, Default = 20 },
    Callback = function(v) farm.speed = tonumber(v) or 20 end,
})
FarmTab:Toggle({
    Title = "Auto Farm Coins",
    Value = false, Default = false,
    Callback = function(on) if on then startFarm() else stopFarm() end end,
})
FarmTab:Toggle({
    Title = "Underground Farm",
    Value = false, Default = false,
    Callback = function(on) farm.underground = on end,
})
FarmTab:Slider({
    Title = "Underground Depth",
    Step = 1,
    Value = { Min = 2, Max = 12, Default = 4 },
    Callback = function(v) farm.depth = tonumber(v) or 4 end,
})

-- =====================================================================
-- AIM TAB (REAL USER TAP / SCREEN CLICK FOR SHOT)
-- =====================================================================
local function hasTool(plr, toolName)
    local bp = plr:FindFirstChild("Backpack")
    local char = plr.Character
    return (bp and bp:FindFirstChild(toolName)) or (char and char:FindFirstChild(toolName))
end

local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and hasTool(plr, "Knife") then return plr end
    end
end

local function shootMurderer()
    if not hasTool(lp, "Gun") then
        notify("Aim", "You don't have gun to shoot murderer")
        return false
    end
    local m = getMurderer()
    if not m or not m.Character or not m.Character:FindFirstChild("HumanoidRootPart") then
        notify("Aim", "Murderer not found!")
        return false
    end

    local char = lp.Character
    local gun = char and char:FindFirstChild("Gun")
    if not gun then
        local bp = lp:FindFirstChild("Backpack")
        gun = bp and bp:FindFirstChild("Gun")
        if gun and getHum() then
            getHum():EquipTool(gun)
            task.wait(0.3)
        end
    end

    gun = lp.Character and lp.Character:FindFirstChild("Gun")
    if gun then
        -- Aim camera directly at the Murderer's HumanoidRootPart so screen-tap hits them
        local cam = workspace.CurrentCamera
        local mRoot = m.Character.HumanoidRootPart
        if cam and mRoot then
            cam.CFrame = CFrame.new(cam.CFrame.Position, mRoot.Position)
        end
        task.wait(0.05)

        -- Activate gun tool visually and programmatically
        pcall(function()
            gun:Activate()
        end)

        -- Physically simulate screen tap/click for mobile & PC users
        local vp = cam.ViewportSize
        local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(screenCenter.X, screenCenter.Y, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(screenCenter.X, screenCenter.Y, 0, false, game, 1)
        end)

        notify("Aim", "Shot Murderer!")
        return true
    else
        notify("Aim", "Equip Gun failed!")
        return false
    end
end

AimTab:Section({ Title = "Sheriff & Gun Tools" })
AimTab:Button({
    Title = "Shoot Murderer",
    Callback = function() shootMurderer() end,
})

local autoShootOn = false
AimTab:Toggle({
    Title = "Auto Shoot Murderer",
    Value = false, Default = false,
    Callback = function(on)
        autoShootOn = on
        task.spawn(function()
            while autoShootOn do
                shootMurderer()
                task.wait(1)
            end
        end)
    end,
})

AimTab:Button({
    Title = "Auto Claim Gun",
    Desc = "Teleports to DroppedGun part",
    Callback = function()
        local root = getRoot()
        local droppedGun
        for _, d in ipairs(workspace:GetDescendants()) do
            if d.Name == "DroppedGun" and d:IsA("BasePart") then
                droppedGun = d
                break
            end
        end
        if root and droppedGun then
            root.CFrame = droppedGun.CFrame + Vector3.new(0, 3, 0)
            notify("Aim", "Teleported to DroppedGun!")
        else
            notify("Aim", "DroppedGun not found!")
        end
    end,
})

local autoAimOn = false
AimTab:Toggle({
    Title = "Auto Aim At Murderer (Shiftlock)",
    Value = false, Default = false,
    Callback = function(on)
        autoAimOn = on
        if on then
            bind("autoaim", RunService.RenderStepped, function()
                local cam = workspace.CurrentCamera
                local root = getRoot()
                local m = getMurderer()
                if cam and root and m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
                    local mPos = m.Character.HumanoidRootPart.Position
                    cam.CFrame = CFrame.new(cam.CFrame.Position, mPos)
                end
            end)
        else
            unbind("autoaim")
        end
    end,
})

-- =====================================================================
-- COMBAT TAB (VISUAL TELEPORT & REAL SCREEN TAP FOR YOU)
-- =====================================================================
local function executeKillAll()
    if not hasTool(lp, "Knife") then
        notify("Combat", "You are not murderer silly!")
        return false
    end

    local root = getRoot()
    local char = lp.Character
    local knife = char and char:FindFirstChild("Knife")
    if not knife then
        local bp = lp:FindFirstChild("Backpack")
        knife = bp and bp:FindFirstChild("Knife")
        if knife and getHum() then
            getHum():EquipTool(knife)
            task.wait(0.2)
        end
    end
    knife = lp.Character and lp.Character:FindFirstChild("Knife")
    if not knife then
        notify("Combat", "Knife not equipped!")
        return false
    end

    -- Visually bring and tap for each player
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = plr.Character.HumanoidRootPart
            if root then
                -- Step 1: Visually bring player to 1 stud in front of you (or teleport you directly to them)
                root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.5)
                task.wait(0.08)

                -- Step 2: Activate knife tool
                pcall(function()
                    knife:Activate()
                end)

                -- Step 3: Simulate real screen tap/click for you so the game registers the stab
                local cam = workspace.CurrentCamera
                if cam then
                    local vp = cam.ViewportSize
                    local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(screenCenter.X, screenCenter.Y, 0, true, game, 1)
                        task.wait(0.04)
                        VirtualInputManager:SendMouseButtonEvent(screenCenter.X, screenCenter.Y, 0, false, game, 1)
                    end)
                end
                task.wait(0.05)
            end
        end
    end
    notify("Combat", "Kill All executed visually!")
    return true
end

local function executeKillSheriff()
    if not hasTool(lp, "Knife") then
        notify("Combat", "You are not murderer silly!")
        return false
    end
    local root = getRoot()
    local char = lp.Character
    local knife = char and char:FindFirstChild("Knife")
    if not knife then
        local bp = lp:FindFirstChild("Backpack")
        knife = bp and bp:FindFirstChild("Knife")
        if knife and getHum() then
            getHum():EquipTool(knife)
            task.wait(0.2)
        end
    end
    knife = lp.Character and lp.Character:FindFirstChild("Knife")

    local sheriff = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and hasTool(plr, "Gun") then
            sheriff = plr
            break
        end
    end

    if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("HumanoidRootPart") and root and knife then
        local targetRoot = sheriff.Character.HumanoidRootPart
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.5)
        task.wait(0.08)

        pcall(function() knife:Activate() end)

        local cam = workspace.CurrentCamera
        if cam then
            local vp = cam.ViewportSize
            local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(screenCenter.X, screenCenter.Y, 0, true, game, 1)
                task.wait(0.04)
                VirtualInputManager:SendMouseButtonEvent(screenCenter.X, screenCenter.Y, 0, false, game, 1)
            end)
        end

        notify("Combat", "Killed Sheriff visually!")
        return true
    else
        notify("Combat", "Sheriff not found or missing knife!")
        return false
    end
end

CombatTab:Section({ Title = "Murderer Combat" })
CombatTab:Button({
    Title = "Kill All",
    Callback = function() executeKillAll() end,
})

CombatTab:Button({
    Title = "Kill Sheriff",
    Callback = function() executeKillSheriff() end,
})

local autoKillAllOn = false
CombatTab:Toggle({
    Title = "Auto Kill All",
    Value = false, Default = false,
    Callback = function(on)
        autoKillAllOn = on
        task.spawn(function()
            while autoKillAllOn do
                executeKillAll()
                task.wait(1.5)
            end
        end)
    end,
})

Window:SelectTab(1)
notify("Boost Hub", "Loaded successfully. Press RightShift to toggle window.")
