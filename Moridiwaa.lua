--[[
    Moridiwaa - Player Control Panel
    Loadstring Compatible Version
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local MAX_PLAYERS = 50
local STUDS_TO_METERS = 1

local ESPEnabled = true
local ShowNames = true
local ShowDistance = true
local HighlightEnabled = true
local AlwaysOnTop = true

local Selected = {}
local ESP = {}

local FlyEnabled = false
local FlySpeed = 50
local WalkSpeed = 16
local WalkSpeedEnabled = false
local NoclipEnabled = false

local FlyVelocity
local FlyConnection
local NoclipConnection
local MovementConnection

local TeleportRemote = ReplicatedStorage:FindFirstChild("MoridiwaaTeleport")
local ServerStatus = ReplicatedStorage:FindFirstChild("MoridiwaaServerStatus")

-- ============================================================
-- GUI
-- ============================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "Moridiwaa"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = LP:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Window"
Main.Size = UDim2.fromOffset(820, 540)
Main.Position = UDim2.new(.5, -410, .5, -270)
Main.BackgroundColor3 = Color3.fromRGB(17, 18, 21)
Main.BorderSizePixel = 0
Main.Parent = Gui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

-- Top bar
local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 55)
Top.BackgroundColor3 = Color3.fromRGB(20, 21, 24)
Top.BorderSizePixel = 0
Top.Parent = Main

local Title = Instance.new("TextLabel")
Title.Position = UDim2.fromOffset(20, 8)
Title.Size = UDim2.fromOffset(260, 22)
Title.BackgroundTransparency = 1
Title.Text = "Moridiwaa"
Title.TextColor3 = Color3.fromRGB(235,235,235)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

local SubTitle = Instance.new("TextLabel")
SubTitle.Position = UDim2.fromOffset(20, 30)
SubTitle.Size = UDim2.fromOffset(300, 18)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "PLAYER CONTROL PANEL"
SubTitle.TextColor3 = Color3.fromRGB(115,115,120)
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = 11
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = Top

local Hint = Instance.new("TextLabel")
Hint.Position = UDim2.new(1, -180, 0, 20)
Hint.Size = UDim2.fromOffset(150, 20)
Hint.BackgroundTransparency = 1
Hint.Text = "Left Ctrl  •  Toggle"
Hint.TextColor3 = Color3.fromRGB(110,110,115)
Hint.Font = Enum.Font.Gotham
Hint.TextSize = 11
Hint.TextXAlignment = Enum.TextXAlignment.Right
Hint.Parent = Top

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Position = UDim2.fromOffset(0, 55)
Sidebar.Size = UDim2.fromOffset(190, 485)
Sidebar.BackgroundColor3 = Color3.fromRGB(14,15,17)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local function SidebarButton(text, y)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(15, y)
    b.Size = UDim2.fromOffset(160, 43)
    b.BackgroundColor3 = Color3.fromRGB(14,15,17)
    b.TextColor3 = Color3.fromRGB(155,155,160)
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.Parent = Sidebar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 15)
    pad.Parent = b

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = b

    return b
end

local MainTab = SidebarButton("◉   Main", 20)
local PlayersTab = SidebarButton("♙   Players", 70)
local VisualTab = SidebarButton("▦   Visuals", 120)
local OthersTab = SidebarButton("⚙   Others", 170)

-- Content
local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(190, 55)
Content.Size = UDim2.new(1, -190, 1, -55)
Content.BackgroundColor3 = Color3.fromRGB(18,19,22)
Content.BorderSizePixel = 0
Content.Parent = Main

local Pages = {}

local function Page(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Size = UDim2.fromScale(1,1)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 4
    p.Visible = false
    p.CanvasSize = UDim2.new()
    p.Parent = Content
    Pages[name] = p
    return p
end

local MainPage = Page("Main")
local PlayerPage = Page("Players")
local VisualPage = Page("Visuals")
local OtherPage = Page("Others")

-- Helpers
local function Card(parent, x, y, w, h, title)
    local c = Instance.new("Frame")
    c.Position = UDim2.fromOffset(x,y)
    c.Size = UDim2.fromOffset(w,h)
    c.BackgroundColor3 = Color3.fromRGB(23,24,27)
    c.BorderSizePixel = 0
    c.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,10)
    corner.Parent = c

    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(18,14)
    t.Size = UDim2.new(1,-36,0,24)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Color3.fromRGB(205,205,208)
    t.Font = Enum.Font.GothamMedium
    t.TextSize = 15
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = c

    return c
end

local function Toggle(parent, text, y, default, callback)
    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(18,y)
    label.Size = UDim2.fromOffset(230,35)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(150,150,155)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local b = Instance.new("TextButton")
    b.Position = UDim2.new(1,-70,0,y+4)
    b.Size = UDim2.fromOffset(48,26)
    b.Text = ""
    b.BackgroundColor3 = default and Color3.fromRGB(80,80,84) or Color3.fromRGB(48,49,53)
    b.AutoButtonColor = false
    b.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1,0)
    corner.Parent = b

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(20,20)
    dot.Position = default and UDim2.new(1,-24,.5,-10) or UDim2.fromOffset(4,3)
    dot.BackgroundColor3 = Color3.fromRGB(235,235,235)
    dot.Parent = b

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1,0)
    dotCorner.Parent = dot

    local state = default

    b.MouseButton1Click:Connect(function()
        state = not state
        dot.Position = state and UDim2.new(1,-24,.5,-10) or UDim2.fromOffset(4,3)
        b.BackgroundColor3 = state and Color3.fromRGB(80,80,84) or Color3.fromRGB(48,49,53)
        callback(state)
    end)

    return b
end

local function NumberBox(parent, labelText, y, initial, minValue, maxValue, callback)
    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(18,y)
    label.Size = UDim2.fromOffset(220,30)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(150,150,155)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local box = Instance.new("TextBox")
    box.Position = UDim2.new(1,-115,0,y)
    box.Size = UDim2.fromOffset(85,32)
    box.BackgroundColor3 = Color3.fromRGB(32,33,37)
    box.TextColor3 = Color3.fromRGB(235,235,235)
    box.Text = tostring(initial)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent = box

    box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value then
            value = math.clamp(value, minValue, maxValue)
            box.Text = tostring(value)
            callback(value)
        else
            box.Text = tostring(initial)
        end
    end)

    return box
end

local function SetStatus(text)
    local status = OtherPage:FindFirstChild("ServerStatusLabel")
    if status then
        status.Text = text
    end
end

local function RequestServerAction(action)
    if not TeleportRemote then
        TeleportRemote = ReplicatedStorage:FindFirstChild("MoridiwaaTeleport")
    end

    if not TeleportRemote then
        SetStatus("Server script not installed")
        return
    end

    SetStatus("Requesting: " .. action .. " ...")

    local ok, err = pcall(function()
        TeleportRemote:FireServer(action)
    end)

    if not ok then
        SetStatus("Request failed: " .. tostring(err))
    end
end

-- ============================================================
-- Main page
-- ============================================================

local MainCard = Card(MainPage,20,20,570,220,"Master Controls")

Toggle(MainCard,"Player ESP",55,true,function(v)
    ESPEnabled = v
    for _,e in pairs(ESP) do
        e.Highlight.Enabled = v and HighlightEnabled
        e.Billboard.Enabled = v and ShowNames
    end
end)

Toggle(MainCard,"Show Player Names",100,true,function(v)
    ShowNames = v
    for _,e in pairs(ESP) do
        e.Billboard.Enabled = ESPEnabled and v
    end
end)

Toggle(MainCard,"Show Distance",145,true,function(v)
    ShowDistance = v
end)

local MovementCard = Card(MainPage,20,260,570,280,"Movement")

Toggle(MovementCard,"Fly",55,false,function(state)
    FlyEnabled = state

    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        FlyEnabled = false
        return
    end

    if state then
        humanoid.PlatformStand = true

        if FlyVelocity then
            FlyVelocity:Destroy()
        end

        FlyVelocity = Instance.new("BodyVelocity")
        FlyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        FlyVelocity.Velocity = Vector3.zero
        FlyVelocity.Parent = root

        if FlyConnection then
            FlyConnection:Disconnect()
        end

        FlyConnection = RunService.RenderStepped:Connect(function()
            if not FlyEnabled or not FlyVelocity or not FlyVelocity.Parent then
                return
            end

            local camera = workspace.CurrentCamera
            local direction = Vector3.zero

            if UIS:IsKeyDown(Enum.KeyCode.W) then
                direction += camera.CFrame.LookVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.S) then
                direction -= camera.CFrame.LookVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.A) then
                direction -= camera.CFrame.RightVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.D) then
                direction += camera.CFrame.RightVector
            end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then
                direction += Vector3.yAxis
            end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
                direction -= Vector3.yAxis
            end

            if direction.Magnitude > 0 then
                direction = direction.Unit * FlySpeed
            end

            FlyVelocity.Velocity = direction
        end)
    else
        humanoid.PlatformStand = false

        if FlyConnection then
            FlyConnection:Disconnect()
            FlyConnection = nil
        end

        if FlyVelocity then
            FlyVelocity:Destroy()
            FlyVelocity = nil
        end
    end
end)

Toggle(MovementCard,"Custom Walk Speed",100,false,function(state)
    WalkSpeedEnabled = state

    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid.WalkSpeed = state and WalkSpeed or 16
    end
end)

Toggle(MovementCard,"Noclip",145,false,function(state)
    NoclipEnabled = state

    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end

    if state then
        NoclipConnection = RunService.Stepped:Connect(function()
            local character = LP.Character
            if not character then
                return
            end

            for _,obj in ipairs(character:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.CanCollide = false
                end
            end
        end)
    else
        local character = LP.Character
        if character then
            for _,obj in ipairs(character:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                    obj.CanCollide = true
                end
            end
        end
    end
end)

NumberBox(MovementCard,"Walk Speed",190,WalkSpeed,16,200,function(value)
    WalkSpeed = value

    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid and WalkSpeedEnabled then
        humanoid.WalkSpeed = WalkSpeed
    end
end)

NumberBox(MovementCard,"Fly Speed",230,FlySpeed,10,200,function(value)
    FlySpeed = value
end)

MainPage.CanvasSize = UDim2.fromOffset(0,560)

-- ============================================================
-- Visuals
-- ============================================================

local VisualCard = Card(VisualPage,20,20,570,220,"Visual Settings")

Toggle(VisualCard,"Highlight Players",55,true,function(v)
    HighlightEnabled = v
    for _,e in pairs(ESP) do
        e.Highlight.Enabled = ESPEnabled and v
    end
end)

Toggle(VisualCard,"Always On Top",100,true,function(v)
    AlwaysOnTop = v
    for _,e in pairs(ESP) do
        e.Billboard.AlwaysOnTop = v
    end
end)

-- ============================================================
-- Players
-- ============================================================

local PlayerCard = Card(PlayerPage,20,20,570,440,"Select Players")

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Position = UDim2.fromOffset(15,55)
PlayerList.Size = UDim2.new(1,-30,1,-70)
PlayerList.BackgroundColor3 = Color3.fromRGB(18,19,22)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 4
PlayerList.Parent = PlayerCard

local PlayerLayout = Instance.new("UIListLayout")
PlayerLayout.Padding = UDim.new(0,5)
PlayerLayout.Parent = PlayerList

-- ============================================================
-- ESP
-- ============================================================

local function RemoveESP(p)
    if ESP[p] then
        if ESP[p].Highlight then
            ESP[p].Highlight:Destroy()
        end
        if ESP[p].Billboard then
            ESP[p].Billboard:Destroy()
        end
        ESP[p] = nil
    end
end

local function CreateESP(p)
    if p == LP or not Selected[p] or ESP[p] or not p.Character then
        return
    end

    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local h = Instance.new("Highlight")
    h.Name = "PlayerESP"
    h.FillColor = Color3.fromRGB(220,70,70)
    h.OutlineColor = Color3.fromRGB(240,240,240)
    h.FillTransparency = .55
    h.Parent = p.Character

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(220,55)
    bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = AlwaysOnTop
    bb.Parent = root

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1,1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(240,240,240)
    label.TextStrokeTransparency = .15
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
    label.Parent = bb

    ESP[p] = {
        Highlight = h,
        Billboard = bb,
        Label = label
    }

    h.Enabled = ESPEnabled and HighlightEnabled
    bb.Enabled = ESPEnabled and ShowNames
end

local function RefreshPlayers()
    for _,v in ipairs(PlayerList:GetChildren()) do
        if v:IsA("TextButton") then
            v:Destroy()
        end
    end

    local count = 0

    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            count += 1

            if count <= MAX_PLAYERS then
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1,-10,0,38)
                b.BackgroundColor3 = Selected[p]
                    and Color3.fromRGB(55,70,58)
                    or Color3.fromRGB(30,31,35)

                b.Text = (Selected[p] and "✓  " or "□  ") .. p.DisplayName
                b.TextColor3 = Color3.fromRGB(210,210,212)
                b.TextSize = 13
                b.Font = Enum.Font.Gotham
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.AutoButtonColor = false
                b.Parent = PlayerList

                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0,12)
                pad.Parent = b

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0,6)
                corner.Parent = b

                b.MouseButton1Click:Connect(function()
                    Selected[p] = not Selected[p]

                    if Selected[p] then
                        CreateESP(p)
                    else
                        RemoveESP(p)
                    end

                    RefreshPlayers()
                end)
            end
        end
    end

    PlayerList.CanvasSize = UDim2.fromOffset(0,count * 43)
end

-- ============================================================
-- Others
-- ============================================================

local OtherCard = Card(OtherPage,20,20,570,320,"Server Functions")

local function ActionButton(text, y)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(18,y)
    b.Size = UDim2.fromOffset(250,42)
    b.BackgroundColor3 = Color3.fromRGB(32,33,37)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(205,205,208)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.Parent = OtherCard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,7)
    corner.Parent = b
    return b
end

local Rejoin = ActionButton("↻   Rejoin Current Server",60)
local Hop = ActionButton("⇄   Server Hop",112)
local LowPing = ActionButton("⌁   Hop to Low Ping",164)

local ServerStatusLabel = Instance.new("TextLabel")
ServerStatusLabel.Name = "ServerStatusLabel"
ServerStatusLabel.Position = UDim2.fromOffset(18,225)
ServerStatusLabel.Size = UDim2.new(1,-36,0,60)
ServerStatusLabel.BackgroundTransparency = 1
ServerStatusLabel.Text = "Ready"
ServerStatusLabel.TextColor3 = Color3.fromRGB(120,120,125)
ServerStatusLabel.Font = Enum.Font.Gotham
ServerStatusLabel.TextSize = 12
ServerStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
ServerStatusLabel.TextWrapped = true
ServerStatusLabel.Parent = OtherCard

Rejoin.MouseButton1Click:Connect(function()
    RequestServerAction("rejoin")
end)

Hop.MouseButton1Click:Connect(function()
    RequestServerAction("hop")
end)

LowPing.MouseButton1Click:Connect(function()
    RequestServerAction("lowping")
end)

OtherPage.CanvasSize = UDim2.fromOffset(0,360)

-- ============================================================
-- Tabs
-- ============================================================

local Tabs = {
    {MainTab,MainPage},
    {PlayersTab,PlayerPage},
    {VisualTab,VisualPage},
    {OthersTab,OtherPage}
}

local function OpenPage(page)
    for _,data in ipairs(Tabs) do
        data[2].Visible = false
        data[1].BackgroundColor3 = Color3.fromRGB(14,15,17)
        data[1].TextColor3 = Color3.fromRGB(155,155,160)
    end

    page.Visible = true

    for _,data in ipairs(Tabs) do
        if data[2] == page then
            data[1].BackgroundColor3 = Color3.fromRGB(31,32,36)
            data[1].TextColor3 = Color3.fromRGB(235,235,235)
        end
    end
end

MainTab.MouseButton1Click:Connect(function() OpenPage(MainPage) end)
PlayersTab.MouseButton1Click:Connect(function() OpenPage(PlayerPage) end)
VisualTab.MouseButton1Click:Connect(function() OpenPage(VisualPage) end)
OthersTab.MouseButton1Click:Connect(function() OpenPage(OtherPage) end)

-- ============================================================
-- Left Ctrl
-- ============================================================

UIS.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.LeftControl then
        Main.Visible = not Main.Visible
    end
end)

-- ============================================================
-- Movement maintenance
-- ============================================================

MovementConnection = RunService.Heartbeat:Connect(function()
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        return
    end

    if WalkSpeedEnabled then
        if math.abs(humanoid.WalkSpeed - WalkSpeed) > 0.01 then
            humanoid.WalkSpeed = WalkSpeed
        end
    end

    if NoclipEnabled and character then
        for _,obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.CanCollide = false
            end
        end
    end
end)

-- ============================================================
-- ESP distance update
-- ============================================================

RunService.RenderStepped:Connect(function()
    if not ESPEnabled then
        return
    end

    local myCharacter = LP.Character
    local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")

    if not myRoot then
        return
    end

    for p,e in pairs(ESP) do
        if p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")

            if root then
                local distance =
                    (myRoot.Position - root.Position).Magnitude
                    * STUDS_TO_METERS

                if ShowNames then
                    if ShowDistance then
                        e.Label.Text =
                            p.DisplayName ..
                            "\n[" ..
                            math.floor(distance) ..
                            " m]"
                    else
                        e.Label.Text = p.DisplayName
                    end
                else
                    e.Label.Text = ""
                end
            end
        end
    end
end)

-- ============================================================
-- Player events
-- ============================================================

local function HookPlayer(p)
    if p == LP then
        return
    end

    if Selected[p] == nil then
        Selected[p] = false
    end

    p.CharacterAdded:Connect(function()
        task.wait(.5)
        RemoveESP(p)
        CreateESP(p)
    end)
end

for _,p in ipairs(Players:GetPlayers()) do
    HookPlayer(p)
end

Players.PlayerAdded:Connect(function(p)
    HookPlayer(p)
    RefreshPlayers()
end)

Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p)
    Selected[p] = nil
    RefreshPlayers()
end)

-- ============================================================
-- Respawn
-- ============================================================

LP.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 5)

    if humanoid then
        humanoid.WalkSpeed = WalkSpeedEnabled and WalkSpeed or 16
    end

    if FlyEnabled then
        FlyEnabled = false

        if FlyConnection then
            FlyConnection:Disconnect()
            FlyConnection = nil
        end

        if FlyVelocity then
            FlyVelocity:Destroy()
            FlyVelocity = nil
        end

        if humanoid then
            humanoid.PlatformStand = false
        end
    end

    if NoclipEnabled then
        task.wait(.2)
        if not NoclipConnection then
            NoclipConnection = RunService.Stepped:Connect(function()
                local char = LP.Character
                if not char then
                    return
                end

                for _,obj in ipairs(char:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.CanCollide = false
                    end
                end
            end)
        end
    end
end)

-- Server status events
if ServerStatus then
    ServerStatus.OnClientEvent:Connect(function(message)
        SetStatus(tostring(message))
    end)
end

-- Start
OpenPage(MainPage)
RefreshPlayers()
