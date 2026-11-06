--[[
    Boost Hub (Farm Edition)  |  built with WindUI (Footagesus)
    Tabs: Main (player stuff), ESP (Players + Coins), Farm (Auto Farm Coins)
]]

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Services -------------------------------------------------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")

local lp = Players.LocalPlayer

-- Helpers --------------------------------------------------------------
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

-- Window ---------------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "Boost Hub",
    Icon = "rocket",
    Author = "Boost Hub",
    Folder = "BoostHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
})

pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)

local MainTab = Window:Tab({ Title = "Main", Icon = "user" })
local ESPTab  = Window:Tab({ Title = "ESP",  Icon = "eye" })
local FarmTab = Window:Tab({ Title = "Farm", Icon = "coins" })

-- =====================================================================
-- MAIN (Player)
-- =====================================================================
local DEFAULT_SPEED, DEFAULT_JUMP, DEFAULT_GRAVITY = 16, 50, workspace.Gravity

local state = {
    speedOn = false, speed = 50,
    jumpOn = false,  jump = 100,
    flyOn = false,   flySpeed = 60,
}

-- Forward declaration so protections can check it
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

-- Fly --------------------------------------------------------------
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
        local flatLook = Vector3.new(look.X, 0, look.Z)
        local flatRight = Vector3.new(right.X, 0, right.Z)
        flatLook = flatLook.Magnitude > 1e-3 and flatLook.Unit or Vector3.new(0, 0, -1)
        flatRight = flatRight.Magnitude > 1e-3 and flatRight.Unit or Vector3.new(1, 0, 0)

        local md = hum.MoveDirection
        local dir = look * md:Dot(flatLook) + right * md:Dot(flatRight)

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
    Desc = "WASD / joystick to move, Space up, Ctrl down. Turn off while Auto Farm is running.",
    Value = false, Default = false,
    Callback = function(on)
        state.flyOn = on
        if on then startFly() else stopFly() end
    end,
})

-- Protection -------------------------------------------------------
MainTab:Section({ Title = "Protection" })

MainTab:Toggle({
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

MainTab:Toggle({
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
                if root and not state.flyOn and not farm.on then
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

MainTab:Section({ Title = "Misc" })

MainTab:Button({
    Title = "Reset Character",
    Callback = function()
        local h = getHum()
        if h then h.Health = 0 end
    end,
})

MainTab:Button({
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

-- =====================================================================
-- ESP
-- =====================================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "BoostHubESP"
local okParent = pcall(function()
    espFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not okParent then
    espFolder.Parent = lp:WaitForChild("PlayerGui")
end

-- Shared coin finder (parts named "Coin_Server"), cached for 1 second
local coinCache, coinCacheTime = {}, 0
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

-- Model based ESP (players)
local function newModelESP(color, interval, collect)
    local self = { entries = {}, conn = nil, last = 0 }

    local function remove(model)
        local e = self.entries[model]
        if e then
            e.hl:Destroy()
            e.gui:Destroy()
            self.entries[model] = nil
        end
    end

    local function add(model, name)
        local part = model:FindFirstChild("Head")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart")
        if not part then return end

        local hl = Instance.new("Highlight")
        hl.Adornee = model
        hl.FillColor = color
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.6
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = espFolder

        local gui = Instance.new("BillboardGui")
        gui.Adornee = part
        gui.Size = UDim2.fromOffset(200, 30)
        gui.StudsOffset = Vector3.new(0, 2.5, 0)
        gui.AlwaysOnTop = true
        gui.Parent = espFolder

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.3
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.Parent = gui

        self.entries[model] = { hl = hl, gui = gui, label = label, name = name, part = part }
    end

    function self.Start()
        if self.conn then return end
        self.conn = RunService.RenderStepped:Connect(function()
            local now = os.clock()
            if now - self.last >= interval then
                self.last = now
                local targets = collect()
                for model in pairs(self.entries) do
                    if not targets[model] or not model.Parent then remove(model) end
                end
                for model, name in pairs(targets) do
                    if not self.entries[model] then add(model, name) end
                end
            end

            local root = getRoot()
            for model, e in pairs(self.entries) do
                local hum = model:FindFirstChildOfClass("Humanoid")
                local dist = root and math.floor((e.part.Position - root.Position).Magnitude) or 0
                local hp = hum and string.format(" | %d HP", math.floor(hum.Health)) or ""
                e.label.Text = string.format("%s [%dm]%s", e.name, dist, hp)
            end
        end)
    end

    function self.Stop()
        if self.conn then
            self.conn:Disconnect()
            self.conn = nil
        end
        for model in pairs(self.entries) do remove(model) end
    end

    return self
end

-- Part based ESP (coins): a small dot per coin, no Highlight limit
local coinESP = { entries = {}, conn = nil, last = 0 }

local function removeCoinESP(part)
    local gui = coinESP.entries[part]
    if gui then
        gui:Destroy()
        coinESP.entries[part] = nil
    end
end

local function addCoinESP(part)
    local gui = Instance.new("BillboardGui")
    gui.Adornee = part
    gui.Size = UDim2.fromOffset(14, 14)
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

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 1.5
    stroke.Parent = dot

    coinESP.entries[part] = gui
end

local function startCoinESP()
    if coinESP.conn then return end
    coinESP.conn = RunService.Heartbeat:Connect(function()
        if os.clock() - coinESP.last < 1 then return end
        coinESP.last = os.clock()

        local alive = {}
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

local function stopCoinESP()
    if coinESP.conn then
        coinESP.conn:Disconnect()
        coinESP.conn = nil
    end
    for part in pairs(coinESP.entries) do removeCoinESP(part) end
end

local playerESP = newModelESP(Color3.fromRGB(255, 70, 70), 0.25, function()
    local t = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            t[plr.Character] = plr.DisplayName
        end
    end
    return t
end)

ESPTab:Toggle({
    Title = "ESP Players",
    Desc = "Highlight, name, distance and health of other players",
    Value = false, Default = false,
    Callback = function(on)
        if on then playerESP.Start() else playerESP.Stop() end
    end,
})

ESPTab:Toggle({
    Title = "ESP Coins",
    Desc = "Marks every Coin_Server part with a gold dot",
    Value = false, Default = false,
    Callback = function(on)
        if on then startCoinESP() else stopCoinESP() end
    end,
})

-- =====================================================================
-- FARM
-- =====================================================================
local visited = setmetatable({}, { __mode = "k" })
local farmBV
local currentTween

local function nearestCoin(fromPos)
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

local function stopFarm()
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

local function startFarm()
    stopFarm()
    farm.on = true
    farm.run += 1
    local id = farm.run

    -- Pass through walls and floors
    bind("farmnoclip", RunService.Stepped, function()
        local c = getChar()
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end)

    task.spawn(function()
        while farm.on and farm.run == id do
            local root, hum = getRoot(), getHum()
            if not root or not hum or hum.Health <= 0 then
                task.wait(0.5)
                continue
            end

            -- Hold position so gravity doesn't pull us while tweening
            if not farmBV or farmBV.Parent ~= root then
                if farmBV then farmBV:Destroy() end
                farmBV = Instance.new("BodyVelocity")
                farmBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                farmBV.Velocity = Vector3.zero
                farmBV.Parent = root
            end

            local coin = nearestCoin(root.Position)
            if not coin then
                task.wait(0.3)
                continue
            end

            local goal = coin.Position
            if farm.underground then
                goal -= Vector3.new(0, farm.depth, 0)
            end

            local dist = (goal - root.Position).Magnitude
            local duration = math.max(dist / farm.speed, 0.03)

            currentTween = TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Linear),
                { CFrame = CFrame.new(goal) }
            )
            currentTween:Play()

            while farm.on and farm.run == id and currentTween
                and currentTween.PlaybackState == Enum.PlaybackState.Playing
                and coin.Parent do
                task.wait()
            end

            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end

            visited[coin] = os.clock()
            task.wait(0.1)
        end
    end)
end

FarmTab:Section({ Title = "Coins" })

FarmTab:Slider({
    Title = "Tween Speed",
    Desc = "Studs per second (10 - 27). Lower is safer.",
    Step = 1,
    Value = { Min = 10, Max = 27, Default = 20 },
    Callback = function(v) farm.speed = tonumber(v) or 20 end,
})

FarmTab:Toggle({
    Title = "Auto Farm Coins",
    Desc = "Tweens to the nearest coin through walls and floors",
    Value = false, Default = false,
    Callback = function(on)
        if on then
            startFarm()
        else
            stopFarm()
        end
    end,
})

FarmTab:Toggle({
    Title = "Underground Farm",
    Desc = "While Auto Farm is on, you travel underneath the coins",
    Value = false, Default = false,
    Callback = function(on)
        farm.underground = on
    end,
})

FarmTab:Slider({
    Title = "Underground Depth",
    Desc = "How many studs below the coin. Too deep may stop coins from collecting.",
    Step = 1,
    Value = { Min = 2, Max = 12, Default = 4 },
    Callback = function(v) farm.depth = tonumber(v) or 4 end,
})

Window:SelectTab(1)
notify("Boost Hub", "Loaded. Press RightShift to toggle the window.")
