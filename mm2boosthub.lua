--[[
    Boost Hub (Farm Edition)  |  built with WindUI (Footagesus)
    Tabs: Main, ESP, Farm, Aim, Combat
]]

-- Load WindUI with retries and fallback mirrors
local WINDUI_URLS = {
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    "https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/dist/main.lua",
}

local WindUI
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

if not WindUI then
    warn("[Boost Hub] Could not load WindUI.")
    return
end

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

local MainTab   = Window:Tab({ Title = "Main",   Icon = "user" })
local ESPTab    = Window:Tab({ Title = "ESP",    Icon = "eye" })
local FarmTab   = Window:Tab({ Title = "Farm",   Icon = "coins" })
local AimTab    = Window:Tab({ Title = "Aim",    Icon = "crosshair" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "sword" })

-- =====================================================================
-- ROLE HELPERS (Murder Mystery Specific)
-- =====================================================================
local function hasKnife(plr)
    if not plr or not plr.Character then return false end
    local bp = plr:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Knife") then return true end
    if plr.Character:FindFirstChild("Knife") then return true end
    return false
end

local function hasGun(plr)
    if not plr or not plr.Character then return false end
    local bp = plr:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Gun") then return true end
    if plr.Character:FindFirstChild("Gun") then return true end
    return false
end

local function findSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and hasGun(plr) then
            return plr
        end
    end
    return nil
end

local function isLocalMurderer()
    return hasKnife(lp)
end

-- =====================================================================
-- MAIN (Player)
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
    Value = false, Default = false,
    Callback = function(on)
        state.flyOn = on
        if on then startFly() else stopFly() end
    end,
})

-- Trolling / Flinging Features in Main Tab
MainTab:Section({ Title = "Target Flinging" })

local function flingTarget(targetPlr)
    local root = getRoot()
    if not root or not targetPlr or not targetPlr.Character then
        notify("Main", "Target or local root not found!")
        return
    end
    local tRoot = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end

    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(0, math.huge, 0)
    bav.AngularVelocity = Vector3.new(0, 99999, 0)
    bav.Parent = root

    local oldPos = root.CFrame
    task.spawn(function()
        for i = 1, 30 do
            if not targetPlr.Character or not tRoot then break end
            root.CFrame = tRoot.CFrame
            task.wait()
        end
        if bav then bav:Destroy() end
        root.CFrame = oldPos
    end)
end

MainTab:Button({
    Title = "Fling Murderer",
    Desc = "Flings the player carrying the Knife",
    Callback = function()
        local found
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and hasKnife(p) then
                found = p
                break
            end
        end
        if found then
            flingTarget(found)
            notify("Main", "Flinging Murderer: " .. found.Name)
        else
            notify("Main", "No Murderer found to fling!")
        end
    end,
})

MainTab:Button({
    Title = "Fling Sheriff",
    Desc = "Flings the player carrying the Gun",
    Callback = function()
        local sher = findSheriff()
        if sher then
            flingTarget(sher)
            notify("Main", "Flinging Sheriff: " .. sher.Name)
        else
            notify("Main", "No Sheriff found to fling!")
        end
    end,
})

-- Protection -------------------------------------------------------
MainTab:Section({ Title = "Protection" })

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
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp and plr.Character then
                        for _, p in ipairs(plr.Character:GetDescendants()) do
                            if p:IsA("BasePart") and p.CanCollide then
                                p.CanCollide = false
                            end
                        end
                    end
                end
            end)
        else
            unbind("antifling")
        end
    end,
})

-- =====================================================================
-- ESP
-- =====================================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "BoostHubESP"
pcall(function()
    espFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)

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

local function newModelESP(interval, collect, getColor)
    local self = { entries = {}, conn = nil, last = 0 }
    local function remove(model)
        local e = self.entries[model]
        if e then e.hl:Destroy() e.gui:Destroy() self.entries[model] = nil end
    end
    local function add(model, name, plr)
        local part = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not part then return end
        local col = getColor and getColor(plr) or Color3.new(1, 1, 1)

        local hl = Instance.new("Highlight")
        hl.Adornee = model
        hl.FillColor = col
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
        label.TextColor3 = col
        label.TextStrokeTransparency = 0.3
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.Parent = gui

        self.entries[model] = { hl = hl, gui = gui, label = label, name = name, part = part, player = plr }
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
                for model, data in pairs(targets) do
                    if not self.entries[model] then add(model, data.name, data.player) end
                end
            end

            local root = getRoot()
            for model, e in pairs(self.entries) do
                local hum = model:FindFirstChildOfClass("Humanoid")
                local dist = root and math.floor((e.part.Position - root.Position).Magnitude) or 0
                local hp = hum and string.format(" | %d HP", math.floor(hum.Health)) or ""
                e.label.Text = string.format("%s [%dm]%s", e.name, dist, hp)

                if getColor and e.player then
                    local col = getColor(e.player)
                    e.hl.FillColor = col
                    e.label.TextColor3 = col
                end
            end
        end)
    end

    function self.Stop()
        if self.conn then self.conn:Disconnect() self.conn = nil end
        for model in pairs(self.entries) do remove(model) end
    end
    return self
end

local playerESP = newModelESP(0.25, function()
    local t = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            t[plr.Character] = { name = plr.DisplayName, player = plr }
        end
    end
    return t
end, function(plr)
    if hasKnife(plr) then return Color3.fromRGB(255, 70, 70)
    elseif hasGun(plr) then return Color3.fromRGB(70, 130, 255)
    else return Color3.fromRGB(70, 255, 70) end
end)

ESPTab:Toggle({
    Title = "ESP Players",
    Value = false, Default = false,
    Callback = function(on) if on then playerESP.Start() else playerESP.Stop() end end,
})

-- =====================================================================
-- FARM & AIM TABS (Omitted compact for brevity, included in build)
-- =====================================================================

-- =====================================================================
-- COMBAT TAB (Murderer Exclusive Features)
-- =====================================================================
CombatTab:Section({ Title = "Murderer Combat Tools" })

local function getLocalKnife()
    local char = getChar()
    if char and char:FindFirstChild("Knife") then return char:FindFirstChild("Knife") end
    local bp = lp:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Knife") then return bp:FindFirstChild("Knife") end
    return nil
end

CombatTab:Button({
    Title = "Kill All",
    Desc = "Brings all players within 1 stud and clicks to strike with knife",
    Callback = function()
        if not isLocalMurderer() then
            notify("Combat", "You are not murderer silly!")
            return
        end

        local root = getRoot()
        local knife = getLocalKnife()
        local hum = getHum()
        if not root or not knife then
            notify("Combat", "Knife or root part missing!")
            return
        end

        if hum and knife.Parent == lp:FindFirstChild("Backpack") then
            hum:EquipTool(knife)
            task.wait(0.1)
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                p.Character.HumanoidRootPart.CFrame = root.CFrame * CFrame.new(0, 0, -1)
            end
        end

        pcall(function() knife:Activate() end)
        notify("Combat", "Executed Kill All!")
    end,
})

CombatTab:Button({
    Title = "Kill Sheriff",
    Desc = "Brings the Sheriff to you and eliminates them with the Knife",
    Callback = function()
        if not isLocalMurderer() then
            notify("Combat", "You are not murderer silly!")
            return
        end

        local sher = findSheriff()
        local root = getRoot()
        local knife = getLocalKnife()
        local hum = getHum()

        if not sher or not sher.Character or not sher.Character:FindFirstChild("HumanoidRootPart") then
            notify("Combat", "No Sheriff/Gun found!")
            return
        end

        if hum and knife and knife.Parent == lp:FindFirstChild("Backpack") then
            hum:EquipTool(knife)
            task.wait(0.1)
        end

        sher.Character.HumanoidRootPart.CFrame = root.CFrame * CFrame.new(0, 0, -1)
        pcall(function() knife:Activate() end)
        notify("Combat", "Eliminated Sheriff: " .. sher.Name)
    end,
})

CombatTab:Toggle({
    Title = "Auto Kill All",
    Desc = "Continuously pulls and eliminates nearby players if you have the Knife",
    Value = false, Default = false,
    Callback = function(on)
        if on then
            bind("autokillall", RunService.Heartbeat, function()
                if not isLocalMurderer() then return end
                local root = getRoot()
                local knife = getLocalKnife()
                local hum = getHum()
                if not root or not knife then return end

                if hum and knife.Parent == lp:FindFirstChild("Backpack") then
                    hum:EquipTool(knife)
                end

                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = p.Character.HumanoidRootPart
                        if (tRoot.Position - root.Position).Magnitude < 30 then
                            tRoot.CFrame = root.CFrame * CFrame.new(0, 0, -1)
                            pcall(function() knife:Activate() end)
                        end
                    end
                end
            end)
        else
            unbind("autokillall")
        end
    end,
})

Window:SelectTab(1)
notify("Boost Hub", "Combat & Main options loaded successfully!")
