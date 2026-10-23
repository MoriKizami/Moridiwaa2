--[[
    Moridiwaa - Player Control Panel (Client-Side Standalone Version)
    Features:
    - 100% Perfect Cast Engine (Visual Effects + Faster Bite Rate)
    - Auto Fishing (Perfect Cast + Auto Hook Bite State + Frame-by-Frame Reel Lock)
    - Independent Auto Equip Rod
    - Tween Auto Sell to NPC (Speed 10 - 100 + Bag Full 500/500 Detection)
    - Full ESP, Movement, Aimbot, Server Hop
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local MAX_PLAYERS = 50
local STUDS_TO_METERS = 1

-- Theme / Accent Color System
local AccentColor = Color3.fromRGB(80, 140, 240)
local ThemeElements = {}

-- Feature States
local ESPEnabled = false
local ShowNames = false
local ShowDistance = false
local HighlightEnabled = false
local AlwaysOnTop = false

local Selected = {}
local ESP = {}

local FlyEnabled = false
local FlySpeed = 50
local WalkSpeed = 16
local WalkSpeedEnabled = false
local NoclipEnabled = false

-- Aimbot States
local AimbotEnabled = false
local SilentAimEnabled = false
local ShowFOVCircle = false
local FOVSize = 150

local AntiAFKEnabled = false

-- ============================================================
-- AUTO FISHING & PERFECT CAST STATES
-- ============================================================
local AutoFishingEnabled = false
local AutoEquipEnabled = false
local AutoSellEnabled = false
local ROD_ID = 6958
local TweenSpeed = 45
local isTweening = false
local isHoldingInput = false

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local FishingRemotes = Remotes and Remotes:WaitForChild("Fishing", 15)
local FishingAction = FishingRemotes and FishingRemotes:WaitForChild("Action", 15)
local InventoryAction = Remotes and Remotes:WaitForChild("Inventory", 15) and Remotes.Inventory:WaitForChild("Action", 15)
local FishShopRemotes = Remotes and Remotes:WaitForChild("FishShop", 15)
local FishShopRequest = FishShopRemotes and FishShopRemotes:WaitForChild("Request", 15)

-- โหลด Controllers และ Shared Configs แท้ของเกม
local InventoryController = nil
local FishShopController = nil
local FishingFxController = nil
local FishingConfig = nil

local function getInventoryController()
    if not InventoryController then
        pcall(function()
            local controllers = LP:WaitForChild("PlayerScripts"):WaitForChild("Controllers")
            InventoryController = require(controllers:WaitForChild("InventoryController"))
        end)
    end
    return InventoryController
end

local function getFishShopController()
    if not FishShopController then
        pcall(function()
            local controllers = LP:WaitForChild("PlayerScripts"):WaitForChild("Controllers")
            FishShopController = require(controllers:WaitForChild("FishShopController"))
        end)
    end
    return FishShopController
end

local function getFishingFxController()
    if not FishingFxController then
        pcall(function()
            local controllers = LP:WaitForChild("PlayerScripts"):WaitForChild("Controllers")
            FishingFxController = require(controllers:WaitForChild("FishingFxController"))
        end)
    end
    return FishingFxController
end

local function getFishingConfig()
    if not FishingConfig then
        pcall(function()
            local shared = ReplicatedStorage:WaitForChild("Shared", 10)
            local config = shared and shared:WaitForChild("Config", 10)
            FishingConfig = config and require(config:WaitForChild("FishingConfig", 10))
        end)
    end
    return FishingConfig
end

local FlyVelocity
local FlyConnection
local NoclipConnection
local MovementConnection

-- FOV Circle
local FOVCircle = nil
if typeof(Drawing) == "table" or typeof(Drawing) == "function" then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 60
        FOVCircle.Filled = false
        FOVCircle.Transparency = 1
        FOVCircle.Color = AccentColor
        FOVCircle.Visible = false
    end)
end

-- Theme Functions
local function RegisterThemeElement(instance, property, colorType)
    table.insert(ThemeElements, {Instance = instance, Property = property, Type = colorType or "Accent"})
    if colorType == "Accent" then
        instance[property] = AccentColor
    end
end

local function UpdateTheme(newColor)
    AccentColor = newColor
    for _, elem in ipairs(ThemeElements) do
        if elem.Instance and elem.Instance.Parent then
            if elem.Type == "Accent" then
                elem.Instance[elem.Property] = AccentColor
            end
        end
    end
    for p, e in pairs(ESP) do
        if e.Highlight then
            e.Highlight.FillColor = AccentColor
        end
    end
    if FOVCircle then
        FOVCircle.Color = AccentColor
    end
end

local function MakeDraggable(gui, handle)
    handle = handle or gui
    local dragging, dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- ============================================================
-- GUI BASE
-- ============================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "Moridiwaa"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = LP:WaitForChild("PlayerGui")

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "OpenCloseToggle"
ToggleBtn.Size = UDim2.fromOffset(60, 32)
ToggleBtn.Position = UDim2.new(0.5, -30, 0, 10)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 21, 24)
ToggleBtn.Text = "UI"
ToggleBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
ToggleBtn.Parent = Gui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Thickness = 2
ToggleStroke.Color = AccentColor
ToggleStroke.Parent = ToggleBtn
RegisterThemeElement(ToggleStroke, "Color", "Accent")

MakeDraggable(ToggleBtn, ToggleBtn)

local Main = Instance.new("Frame")
Main.Name = "Window"
Main.Size = UDim2.fromOffset(820, 540)
Main.Position = UDim2.new(0.5, -410, 0, 50)
Main.BackgroundColor3 = Color3.fromRGB(17, 18, 21)
Main.BorderSizePixel = 0
Main.Parent = Gui

ToggleBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 55)
Top.BackgroundColor3 = Color3.fromRGB(20, 21, 24)
Top.BorderSizePixel = 0
Top.Parent = Main

MakeDraggable(Main, Top)

local TopAccentBar = Instance.new("Frame")
TopAccentBar.Size = UDim2.new(1, 0, 0, 3)
TopAccentBar.Position = UDim2.new(0, 0, 1, -3)
TopAccentBar.BorderSizePixel = 0
TopAccentBar.Parent = Top
RegisterThemeElement(TopAccentBar, "BackgroundColor3", "Accent")

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
Hint.Text = "Left Ctrl / Button • Toggle"
Hint.TextColor3 = Color3.fromRGB(110,110,115)
Hint.Font = Enum.Font.Gotham
Hint.TextSize = 11
Hint.TextXAlignment = Enum.TextXAlignment.Right
Hint.Parent = Top

local Sidebar = Instance.new("Frame")
Sidebar.Position = UDim2.fromOffset(0, 55)
Sidebar.Size = UDim2.fromOffset(190, 485)
Sidebar.BackgroundColor3 = Color3.fromRGB(14,15,17)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local function SidebarButton(text, y)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(15, y)
    b.Size = UDim2.fromOffset(160, 40)
    b.BackgroundColor3 = Color3.fromRGB(14,15,17)
    b.TextColor3 = Color3.fromRGB(155,155,160)
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
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

local MainTab = SidebarButton("◉    Main", 15)
local AutoTab = SidebarButton("🤖    Auto", 62)
local AimbotTab = SidebarButton("🎯    Aimbot", 109)
local PlayersTab = SidebarButton("♙    Players", 156)
local VisualTab = SidebarButton("▦    Visuals", 203)
local OthersTab = SidebarButton("⚙    Others", 250)

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
local AutoPage = Page("Auto")
local AimbotPage = Page("Aimbot")
local PlayerPage = Page("Players")
local VisualPage = Page("Visuals")
local OtherPage = Page("Others")

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
    b.BackgroundColor3 = default and AccentColor or Color3.fromRGB(48,49,53)
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
        b.BackgroundColor3 = state and AccentColor or Color3.fromRGB(48,49,53)
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

-- ============================================================
-- 100% PERFECT CAST & FISHING CORE ENGINE
-- ============================================================

local function setHoldState(shouldHold, clickPos)
    if isHoldingInput == shouldHold then return end
    isHoldingInput = shouldHold
    local pos = clickPos or Vector2.new(500, 500)
    if mouse1press and mouse1release then
        if shouldHold then mouse1press() else mouse1release() end
    end
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, shouldHold, game, 0)
        end)
    end
end

local function getEquippedRod()
    local char = LP.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and CollectionService:HasTag(item, "FishingRod") then
                return item
            end
        end
    end
    return nil
end

local function getMinigameElements()
    local hud = LP.PlayerGui:FindFirstChild("FishingHud")
    if not hud then return nil end
    local reel = hud:FindFirstChild("Reel")
    if not reel or not reel.Visible then return nil end
    local water = reel:FindFirstChild("Water")
    if not water then return nil end
    return reel, water:FindFirstChild("Zone"), water:FindFirstChild("Fish")
end

local function findWaterTarget()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.new(-170.33, 12, -36.36) end

    local forward = hrp.CFrame.LookVector
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {char}
    rayParams.IgnoreWater = false

    local checkPos = hrp.Position + Vector3.new(forward.X, 0, forward.Z).Unit * 18
    local hit = workspace:Raycast(checkPos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), rayParams)
    if hit and hit.Material == Enum.Material.Water then
        return hit.Position
    end
    return hrp.Position + (forward * 16) - Vector3.new(0, 1.5, 0)
end

-- ดึงข้อมูลปลาในกระเป๋า 100%
local function getInventoryFishData()
    local totalFish = 0
    local sellableIds = {}
    local maxCapacity = 500

    local fConfig = getFishingConfig()
    if fConfig and fConfig.MaxFish then
        maxCapacity = fConfig.MaxFish
    end

    local invCtrl = getInventoryController()
    if invCtrl then
        local snapshot = invCtrl:GetSnapshot()
        local items = snapshot and snapshot.Items
        if items then
            for _, item in pairs(items) do
                local isFish = false
                if fConfig and fConfig.IsSellable then
                    isFish = fConfig.IsSellable(item.Key)
                elseif item.Weight or (item.Key and string.find(string.lower(item.Key), "fish")) then
                    isFish = true
                end

                if isFish then
                    totalFish = totalFish + 1
                    if not item.Fav and item.Id then
                        table.insert(sellableIds, item.Id)
                    end
                end
            end
        end
    end

    return totalFish, maxCapacity, sellableIds
end

-- ฟังก์ชันรัน Perfect Cast แบบสมบูรณ์ (แอนิเมชันเต็มหลอด + ส่ง Remote Flag true 100%)
local function ExecutePerfectCast(rod, targetPos)
    local fxCtrl = getFishingFxController()
    local hud = LP.PlayerGui:FindFirstChild("FishingHud")
    local powerFrame = hud and hud:FindFirstChild("Power", true)
    local powerFill = powerFrame and powerFrame:FindFirstChild("Fill", true)
    local powerLabel = powerFrame and powerFrame:FindFirstChild("Label", true)

    -- 1. ชาร์จพลังหลอดขึ้นหน้าจอแบบเนียนตา (Smooth Power Charge)
    if powerFrame then
        powerFrame.Visible = true
        if powerLabel then powerLabel.Text = "✨ เพอร์เฟกต์! ปล่อยเลย!" end
        if powerFill then powerFill.Size = UDim2.fromScale(1, 1) end
    end
    if fxCtrl and rod then
        pcall(function()
            fxCtrl:SetCharge(rod, 1)
        end)
    end

    task.wait(0.2)

    -- 2. รันแอนิเมชันสะบัดคันเบ็ดและคลื่นผิวน้ำแท้ของเกม (Game PredictCast Visuals)
    if fxCtrl and rod then
        pcall(function()
            fxCtrl:PredictCast(rod, targetPos)
            fxCtrl:SetCharge(rod, nil)
        end)
    end
    if powerFrame then
        powerFrame.Visible = false
    end

    -- 3. ยิงคำสั่งเหวี่ยงเบ็ดพร้อมสิทธิ์ Perfect Cast (true) ไปยัง Server
    FishingAction:FireServer("Cast", targetPos, true)

    -- 4. แสดงข้อความแจ้งเตือนป๊อปอัปแท้ของเกม
    pcall(function()
        local toastLabel = hud and hud:FindFirstChild("Toast", true)
        if toastLabel then
            toastLabel.Text = "เพอร์เฟกต์! ✨ ปลาจะกินไวขึ้น"
            toastLabel.TextColor3 = Color3.fromRGB(255, 214, 10)
            toastLabel.Visible = true
            task.delay(1.5, function()
                if toastLabel then toastLabel.Visible = false end
            end)
        end
    end)
end

-- ค้นหาพิกัดร้านค้าขายปลา
local function getFishShopPosition()
    for _, obj in ipairs(CollectionService:GetTagged("FishShop")) do
        local point = obj:FindFirstChild("ShopPoint", true)
        if point and point:IsA("BasePart") then
            return point.Position
        end
        if obj:IsA("Model") then
            return obj:GetPivot().Position
        elseif obj:IsA("BasePart") then
            return obj.Position
        end
    end
    local directShop = workspace:FindFirstChild("FishShop", true)
    if directShop then
        if directShop:IsA("Model") then return directShop:GetPivot().Position end
        if directShop:IsA("BasePart") then return directShop.Position end
    end
    return nil
end

-- Tween เคลื่อนที่อย่างปลอดภัยพร้อมเปิด Noclip
local function TweenToPosition(targetPos, speed)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local distance = (hrp.Position - targetPos).Magnitude
    local duration = distance / math.clamp(speed, 10, 100)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))})

    local noclipLoop = RunService.Stepped:Connect(function()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    tween:Play()
    tween.Completed:Wait()
    noclipLoop:Disconnect()
    return true
end

-- ขายปลาผ่าน RemoteFunction "SellIds"
local function SellAllFishNative()
    local _, _, sellableIds = getInventoryFishData()
    if #sellableIds == 0 then
        return false, 0, "ไม่พบปลาที่ขายได้"
    end

    local request = FishShopRequest or (Remotes and Remotes:FindFirstChild("FishShop") and Remotes.FishShop:FindFirstChild("Request"))
    if not request then
        return false, 0, "ไม่พบ Remote ขายปลา"
    end

    local success, res = pcall(function()
        return request:InvokeServer("SellIds", sellableIds)
    end)

    if success and type(res) == "table" and res.Ok then
        return true, res.Count or #sellableIds, string.format("ขายสำเร็จ %d ตัว (+%s เหรียญ)", res.Count or #sellableIds, tostring(res.Coins or 0))
    elseif success and type(res) == "table" and res.Message then
        return false, 0, res.Message
    else
        return false, 0, "เกิดข้อผิดพลาดในการขาย"
    end
end

-- การทำงานลูป Tween ไปร้านค้า -> สั่งขาย -> บินกลับจุดเดิม
local AutoStatusLabel = nil
local BagCounterLabel = nil

local function ExecuteTweenAndSell()
    if isTweening then return end
    isTweening = true

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        isTweening = false
        return
    end

    local originalSpot = hrp.CFrame
    local shopPos = getFishShopPosition()

    if not shopPos then
        if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: ไม่พบพิกัดร้านขายปลาในแผนที่!" end
        isTweening = false
        return
    end

    -- 1. บินไปหน้าร้าน
    if AutoStatusLabel then AutoStatusLabel.Text = string.format("สถานะ: กำลัง Tween ไปหน้าร้าน (ความเร็ว: %d)...", TweenSpeed) end
    TweenToPosition(shopPos, TweenSpeed)
    task.wait(0.5)

    -- 2. สั่งขายปลา
    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: ถึงร้านค้าแล้ว! กำลังขายปลาทั้งหมด..." end
    local ok, count, msg = SellAllFishNative()
    task.wait(1.0)

    -- 3. บินกลับมาที่จุดตกเดิม
    if AutoStatusLabel then AutoStatusLabel.Text = string.format("สถานะ: กำลัง Tween กลับจุดตกเดิม... (%s)", ok and ("ขายได้ " .. count .. " ตัว") or "ไม่มีปลา") end
    TweenToPosition(originalSpot.Position, TweenSpeed)
    if hrp then
        hrp.CFrame = originalSpot
    end
    task.wait(0.5)

    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: กลับถึงที่เดิมเรียบร้อย พร้อมตกปลาต่อ!" end
    isTweening = false
end

-- เปิดร้านค้าของแท้ของเกม
local function OpenRealFishShop()
    local shopGui = LP.PlayerGui:FindFirstChild("FishShopMenu") or LP.PlayerGui:FindFirstChild("MacUI")
    if shopGui then
        shopGui.Enabled = true
        local panel = shopGui:FindFirstChild("Panel", true) or shopGui:FindFirstChild("Window", true)
        if panel then
            panel.Visible = true
            return true
        end
    end

    local shopCtrl = getFishShopController()
    if shopCtrl then
        pcall(function()
            local shopTarget = workspace:FindFirstChild("FishShop", true) or workspace
            local openFn = shopCtrl.OpenShop or shopCtrl.openShop or shopCtrl.Open
            if openFn then
                openFn(shopTarget)
            end
        end)
    end
    return true
end

-- ลูปการทำงาน Auto Fishing & Auto Sell 500/500
task.spawn(function()
    while true do
        pcall(function()
            if BagCounterLabel then
                local currentFish, maxFish, sellableIds = getInventoryFishData()
                BagCounterLabel.Text = string.format("🎒 จำนวนปลา: %d / %d ตัว (พร้อมขาย: %d)", currentFish, maxFish, #sellableIds)
                if currentFish >= maxFish or currentFish >= 500 then
                    BagCounterLabel.TextColor3 = Color3.fromRGB(240, 70, 70)
                else
                    BagCounterLabel.TextColor3 = Color3.fromRGB(150, 220, 160)
                end
            end
        end)

        if AutoFishingEnabled and not isTweening then
            -- เช็คกระเป๋าเต็ม 500/500 แล้วบินไปขายอัตโนมัติ
            if AutoSellEnabled then
                local currentFish, maxFish, sellableIds = getInventoryFishData()
                if (currentFish >= maxFish or currentFish >= 500) and #sellableIds > 0 then
                    ExecuteTweenAndSell()
                    task.wait(1.5)
                end
            end

            -- เช็คการถือเบ็ด
            local rod = getEquippedRod()
            if not rod then
                if AutoStatusLabel and not isTweening then
                    AutoStatusLabel.Text = "สถานะ: รอถือเบ็ด (กรุณาเปิด Auto Equip หรือถือเบ็ดเอง)..."
                end
                task.wait(0.5)
            else
                local state = rod:GetAttribute("State") or "Idle"

                -- 1. เหวี่ยงเบ็ดแบบ 100% Perfect Cast
                if state == "Idle" then
                    local waterPos = findWaterTarget()
                    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: เหวี่ยงเบ็ดแบบ 100% Perfect Cast! ✨" end
                    ExecutePerfectCast(rod, waterPos)
                    task.wait(0.8)

                -- 2. รอปลากินเบ็ด (เช็ค State จริง)
                elseif state == "Casting" or state == "Waiting" then
                    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: เพอร์เฟกต์แล้ว! กำลังรอปลากินเบ็ดไวขึ้น..." end
                    local waitStart = tick()
                    while AutoFishingEnabled and not isTweening and (tick() - waitStart < 15) do
                        if not rod or not rod.Parent then break end
                        if rod:GetAttribute("State") == "Bite" then break end
                        task.wait(0.03)
                    end

                -- 3. Hook ทันทีที่ปลากินเบ็ด
                elseif state == "Bite" then
                    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: ปลากินแล้ว! ส่งคำสั่ง Hook ทันที!" end
                    FishingAction:FireServer("Hook")
                    task.wait(0.2)

                -- 4. ล็อกเป้าแถบเขียวตามตัวปลา (Lock-On Reel)
                elseif state == "Reeling" then
                    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: ล็อกเป้าแถบเขียวตามตัวปลา 🎯" end
                    while AutoFishingEnabled and not isTweening and rod and rod:GetAttribute("State") == "Reeling" do
                        local reel, zone, fish = getMinigameElements()
                        if reel and zone and fish and reel.Visible then
                            local centerPos = reel.AbsolutePosition + (reel.AbsoluteSize / 2)
                            local zoneCenter = zone.Position.X.Scale + (zone.Size.X.Scale / 2)
                            local fishPos = fish.Position.X.Scale

                            if fishPos > (zoneCenter + 0.015) then
                                setHoldState(true, centerPos)
                            elseif fishPos < (zoneCenter - 0.015) then
                                setHoldState(false, centerPos)
                            end
                        end
                        RunService.RenderStepped:Wait()
                    end
                    setHoldState(false)
                    task.wait(0.4)

                -- 5. ตกสำเร็จ รอเริ่มรอบใหม่
                elseif state == "Caught" then
                    if AutoStatusLabel then AutoStatusLabel.Text = "สถานะ: ได้ปลาสำเร็จ! กำลังเริ่มรอบถัดไป..." end
                    task.wait(2.0)
                else
                    task.wait(0.15)
                end
            end
        else
            setHoldState(false)
            task.wait(0.5)
        end
    end
end)

-- UI หน้าแท็บ Auto
local AutoCard = Card(AutoPage, 20, 20, 570, 240, "Fishing Automation (100% Perfect Cast)")

Toggle(AutoCard, "Auto Fishing (Perfect Cast + Hook + Lock Reel)", 55, false, function(v)
    AutoFishingEnabled = v
    if not v and AutoStatusLabel then
        AutoStatusLabel.Text = "สถานะ: หยุดตกปลาเรียบร้อย"
        setHoldState(false)
    end
end)

Toggle(AutoCard, "Auto Equip Rod (เบ็ดตกปลา)", 100, false, function(v)
    AutoEquipEnabled = v
    if InventoryAction then
        if v then
            InventoryAction:FireServer("Equip", ROD_ID)
        else
            InventoryAction:FireServer("Unequip")
        end
    end
end)

NumberBox(AutoCard, "Fishing Rod ID", 145, ROD_ID, 1, 999999, function(v)
    ROD_ID = v
end)

AutoStatusLabel = Instance.new("TextLabel")
AutoStatusLabel.Position = UDim2.fromOffset(18, 190)
AutoStatusLabel.Size = UDim2.new(1, -36, 0, 35)
AutoStatusLabel.BackgroundTransparency = 1
AutoStatusLabel.Text = "สถานะ: พร้อมทำงาน (100% Perfect Cast)"
AutoStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
AutoStatusLabel.Font = Enum.Font.Gotham
AutoStatusLabel.TextSize = 12
AutoStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
AutoStatusLabel.Parent = AutoCard

-- การ์ดระบบขายปลาแบบ Tween (Tween Auto Sell & Fish Shop)
local SellCard = Card(AutoPage, 20, 280, 570, 250, "Tween Auto Sell & Fish Shop")

Toggle(SellCard, "Auto Sell When Bag Full (เต็ม 500 บินไปขายแล้วกลับ)", 50, false, function(v)
    AutoSellEnabled = v
end)

NumberBox(SellCard, "Tween Speed (ความเร็วบิน 10 - 100)", 90, TweenSpeed, 10, 100, function(v)
    TweenSpeed = v
end)

BagCounterLabel = Instance.new("TextLabel")
BagCounterLabel.Position = UDim2.fromOffset(18, 130)
BagCounterLabel.Size = UDim2.new(1, -36, 0, 20)
BagCounterLabel.BackgroundTransparency = 1
BagCounterLabel.Text = "🎒 จำนวนปลา: กำลังตรวจสอบ..."
BagCounterLabel.TextColor3 = Color3.fromRGB(150, 220, 160)
BagCounterLabel.Font = Enum.Font.GothamBold
BagCounterLabel.TextSize = 13
BagCounterLabel.TextXAlignment = Enum.TextXAlignment.Left
BagCounterLabel.Parent = SellCard

local function AutoActionButton(parent, text, x, y, w, h, callback)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, h)
    b.BackgroundColor3 = Color3.fromRGB(32, 33, 37)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(215, 215, 220)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = b

    b.MouseButton1Click:Connect(callback)
    return b
end

AutoActionButton(SellCard, "🚀  Tween & Sell Now (บินไปขายเดี๋ยวนี้)", 18, 165, 250, 42, function()
    task.spawn(ExecuteTweenAndSell)
end)

AutoActionButton(SellCard, "🏪  Open Real Fish Shop GUI", 280, 165, 250, 42, function()
    OpenRealFishShop()
    if AutoStatusLabel then
        AutoStatusLabel.Text = "สถานะ: เปิดหน้าต่างร้านค้าขายปลาของแท้แล้ว"
    end
end)

AutoPage.CanvasSize = UDim2.fromOffset(0, 560)

-- ============================================================
-- MAIN PAGE
-- ============================================================

local MainCard = Card(MainPage,20,20,570,220,"Master Controls")

Toggle(MainCard,"Player ESP",55,false,function(v)
    ESPEnabled = v
    for _,e in pairs(ESP) do
        e.Highlight.Enabled = v and HighlightEnabled
        e.Billboard.Enabled = v and ShowNames
    end
end)

Toggle(MainCard,"Show Player Names",100,false,function(v)
    ShowNames = v
    for _,e in pairs(ESP) do
        e.Billboard.Enabled = ESPEnabled and v
    end
end)

Toggle(MainCard,"Show Distance",145,false,function(v)
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
            if not character then return end
            for _,obj in ipairs(character:GetDescendants()) do
                if obj:IsA("BasePart") then obj.CanCollide = false end
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

NumberBox(MovementCard,"Walk Speed",190,WalkSpeed,16,300,function(value)
    WalkSpeed = value
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and WalkSpeedEnabled then
        humanoid.WalkSpeed = WalkSpeed
    end
end)

NumberBox(MovementCard,"Fly Speed",230,FlySpeed,10,300,function(value)
    FlySpeed = value
end)

MainPage.CanvasSize = UDim2.fromOffset(0,560)

-- ============================================================
-- AIMBOT PAGE
-- ============================================================

local AimbotCard = Card(AimbotPage,20,20,570,270,"Aimbot & Bullet Lock")

Toggle(AimbotCard,"Enable Camera Lock (Hold RMB)",55,false,function(v)
    AimbotEnabled = v
end)

Toggle(AimbotCard,"Silent Aim / Bullet Lock (กระสุนล็อค)",100,false,function(v)
    SilentAimEnabled = v
end)

Toggle(AimbotCard,"Show FOV Circle",145,false,function(v)
    ShowFOVCircle = v
end)

NumberBox(AimbotCard,"FOV Radius / Size",190,FOVSize,10,800,function(value)
    FOVSize = value
end)

AimbotPage.CanvasSize = UDim2.fromOffset(0,320)

-- ============================================================
-- VISUALS PAGE
-- ============================================================

local VisualCard = Card(VisualPage,20,20,570,160,"Visual Settings")

Toggle(VisualCard,"Highlight Players",55,false,function(v)
    HighlightEnabled = v
    for _,e in pairs(ESP) do
        e.Highlight.Enabled = ESPEnabled and v
    end
end)

Toggle(VisualCard,"Always On Top",100,false,function(v)
    AlwaysOnTop = v
    for _,e in pairs(ESP) do
        e.Billboard.AlwaysOnTop = v
    end
end)

local ThemeCard = Card(VisualPage,20,200,570,280,"UI Color Theme Settings")

local PresetLabel = Instance.new("TextLabel")
PresetLabel.Position = UDim2.fromOffset(18,50)
PresetLabel.Size = UDim2.fromOffset(200,20)
PresetLabel.BackgroundTransparency = 1
PresetLabel.Text = "Theme Presets:"
PresetLabel.TextColor3 = Color3.fromRGB(150,150,155)
PresetLabel.Font = Enum.Font.Gotham
PresetLabel.TextSize = 13
PresetLabel.TextXAlignment = Enum.TextXAlignment.Left
PresetLabel.Parent = ThemeCard

local Presets = {
    {Name = "Cyan", Color = Color3.fromRGB(80, 140, 240)},
    {Name = "Red", Color = Color3.fromRGB(240, 70, 70)},
    {Name = "Purple", Color = Color3.fromRGB(160, 80, 240)},
    {Name = "Green", Color = Color3.fromRGB(70, 210, 120)},
    {Name = "Gold", Color = Color3.fromRGB(240, 180, 60)},
    {Name = "Pink", Color = Color3.fromRGB(240, 100, 180)}
}

for i, p in ipairs(Presets) do
    local btn = Instance.new("TextButton")
    btn.Position = UDim2.fromOffset(18 + ((i-1)%3)*180, 80 + math.floor((i-1)/3)*40)
    btn.Size = UDim2.fromOffset(170, 32)
    btn.BackgroundColor3 = p.Color
    btn.Text = p.Name
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = ThemeCard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        UpdateTheme(p.Color)
    end)
end

local curR, curG, curB = 80, 140, 240

NumberBox(ThemeCard, "Custom Red (R)", 170, curR, 0, 255, function(v)
    curR = v
    UpdateTheme(Color3.fromRGB(curR, curG, curB))
end)

NumberBox(ThemeCard, "Custom Green (G)", 205, curG, 0, 255, function(v)
    curG = v
    UpdateTheme(Color3.fromRGB(curR, curG, curB))
end)

NumberBox(ThemeCard, "Custom Blue (B)", 240, curB, 0, 255, function(v)
    curB = v
    UpdateTheme(Color3.fromRGB(curR, curG, curB))
end)

VisualPage.CanvasSize = UDim2.fromOffset(0,500)

-- ============================================================
-- PLAYERS PAGE & ESP
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

local function RemoveESP(p)
    if ESP[p] then
        if ESP[p].Highlight then ESP[p].Highlight:Destroy() end
        if ESP[p].Billboard then ESP[p].Billboard:Destroy() end
        ESP[p] = nil
    end
end

local function CreateESP(p)
    if p == LP or not Selected[p] or ESP[p] or not p.Character then return end
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local h = Instance.new("Highlight")
    h.Name = "PlayerESP"
    h.FillColor = AccentColor
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

    ESP[p] = {Highlight = h, Billboard = bb, Label = label}
    h.Enabled = ESPEnabled and HighlightEnabled
    bb.Enabled = ESPEnabled and ShowNames
end

local function RefreshPlayers()
    for _,v in ipairs(PlayerList:GetChildren()) do
        if v:IsA("TextButton") then v:Destroy() end
    end
    local count = 0
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            count += 1
            if count <= MAX_PLAYERS then
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1,-10,0,38)
                b.BackgroundColor3 = Selected[p] and Color3.fromRGB(55,70,58) or Color3.fromRGB(30,31,35)
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
                    if Selected[p] then CreateESP(p) else RemoveESP(p) end
                    RefreshPlayers()
                end)
            end
        end
    end
    PlayerList.CanvasSize = UDim2.fromOffset(0, count * 43)
end

-- ============================================================
-- OTHERS PAGE
-- ============================================================

local OtherCard = Card(OtherPage,20,20,570,380,"Server & Misc Functions")

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

local Rejoin = ActionButton("↻    Rejoin Current Server",60)
local Hop = ActionButton("⇄    Server Hop",112)
local LowPing = ActionButton("⌁    Hop to Low Ping",164)

Toggle(OtherCard, "Anti-AFK", 220, false, function(v)
    AntiAFKEnabled = v
end)

local ServerStatusLabel = Instance.new("TextLabel")
ServerStatusLabel.Name = "ServerStatusLabel"
ServerStatusLabel.Position = UDim2.fromOffset(18,275)
ServerStatusLabel.Size = UDim2.new(1,-36,0,80)
ServerStatusLabel.BackgroundTransparency = 1
ServerStatusLabel.Text = "Ready"
ServerStatusLabel.TextColor3 = Color3.fromRGB(120,120,125)
ServerStatusLabel.Font = Enum.Font.Gotham
ServerStatusLabel.TextSize = 12
ServerStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
ServerStatusLabel.TextWrapped = true
ServerStatusLabel.Parent = OtherCard

local function SetStatus(text)
    ServerStatusLabel.Text = text
end

local function RejoinServer()
    SetStatus("Rejoining current server...")
    if #Players:GetPlayers() <= 1 then
        LP:Kick("\nRejoining server...")
        task.wait(.5)
        TeleportService:Teleport(game.PlaceId, LP)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end
end

local function ServerHop()
    SetStatus("Searching for another server...")
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/0?sortOrder=Desc&limit=100"
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response then SetStatus("Failed to fetch server list!") return end

    local data
    local parseOk = pcall(function() data = HttpService:JSONDecode(response) end)
    if not parseOk or not data or not data.data then SetStatus("Error reading server response!") return end

    local validServers = {}
    for _, server in ipairs(data.data) do
        if type(server) == "table" and server.id ~= game.JobId and server.playing < server.maxPlayers then
            table.insert(validServers, server)
        end
    end

    if #validServers > 0 then
        local target = validServers[math.random(1, #validServers)]
        SetStatus("Teleporting to server: " .. string.sub(target.id, 1, 8) .. "...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LP)
    else
        SetStatus("No alternative servers found!")
    end
end

local function HopLowPing()
    SetStatus("Finding lowest ping server...")
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/0?sortOrder=Asc&limit=100"
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response then SetStatus("Failed to fetch server list!") return end

    local data
    local parseOk = pcall(function() data = HttpService:JSONDecode(response) end)
    if not parseOk or not data or not data.data then SetStatus("Error reading server response!") return end

    local bestServer, lowestPing = nil, math.huge
    for _, server in ipairs(data.data) do
        if type(server) == "table" and server.id ~= game.JobId and server.playing < server.maxPlayers then
            local ping = server.ping or server.playing
            if ping < lowestPing then
                lowestPing = ping
                bestServer = server
            end
        end
    end

    if bestServer then
        SetStatus("Teleporting to optimal server: " .. string.sub(bestServer.id, 1, 8) .. "...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServer.id, LP)
    else
        SetStatus("No low ping server found!")
    end
end

Rejoin.MouseButton1Click:Connect(RejoinServer)
Hop.MouseButton1Click:Connect(ServerHop)
LowPing.MouseButton1Click:Connect(HopLowPing)
OtherPage.CanvasSize = UDim2.fromOffset(0,420)

LP.Idled:Connect(function()
    if AntiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

-- ============================================================
-- TABS MANAGER
-- ============================================================

local Tabs = {
    {MainTab, MainPage},
    {AutoTab, AutoPage},
    {AimbotTab, AimbotPage},
    {PlayersTab, PlayerPage},
    {VisualTab, VisualPage},
    {OthersTab, OtherPage}
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
AutoTab.MouseButton1Click:Connect(function() OpenPage(AutoPage) end)
AimbotTab.MouseButton1Click:Connect(function() OpenPage(AimbotPage) end)
PlayersTab.MouseButton1Click:Connect(function() OpenPage(PlayerPage) end)
VisualTab.MouseButton1Click:Connect(function() OpenPage(VisualPage) end)
OthersTab.MouseButton1Click:Connect(function() OpenPage(OtherPage) end)

-- Keybind Toggle
UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.LeftControl then
        Main.Visible = not Main.Visible
    end
end)

-- Aimbot Core Functions
local function GetClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = FOVSize
    local mousePos = UIS:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            local head = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and head then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distance = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if distance <= shortestDistance then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

local rawmeta = getrawmetatable or (debug and debug.getmetatable)
if rawmeta then
    local gmt = rawmeta(game)
    local oldNamecall = gmt.__namecall
    local setreadonly = setreadonly or make_writeable or function() end

    if setreadonly and gmt then
        setreadonly(gmt, false)
        gmt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod()
            local args = {...}
            if SilentAimEnabled and (method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") then
                local target = GetClosestPlayerInFOV()
                if target and target.Character then
                    local head = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
                    if head and method == "Raycast" and args[1] then
                        local origin = args[1]
                        args[2] = (head.Position - origin).Unit * 5000
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(gmt, true)
    end
end

-- ============================================================
-- MAIN CONNECTIONS & LOOPS
-- ============================================================

MovementConnection = RunService.Heartbeat:Connect(function()
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if WalkSpeedEnabled and math.abs(humanoid.WalkSpeed - WalkSpeed) > 0.01 then
        humanoid.WalkSpeed = WalkSpeed
    end

    if NoclipEnabled and character and not isTweening then
        for _,obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then obj.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Visible = ShowFOVCircle
        FOVCircle.Radius = FOVSize
        FOVCircle.Position = UIS:GetMouseLocation()
    end

    if AimbotEnabled and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosestPlayerInFOV()
        if target and target.Character then
            local head = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
            if head then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
            end
        end
    end

    if not ESPEnabled then return end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    for p,e in pairs(ESP) do
        if p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local distance = (myRoot.Position - root.Position).Magnitude * STUDS_TO_METERS
                if ShowNames then
                    e.Label.Text = ShowDistance and (p.DisplayName .. "\n[" .. math.floor(distance) .. " m]") or p.DisplayName
                else
                    e.Label.Text = ""
                end
            end
        end
    end
end)

local function HookPlayer(p)
    if p == LP then return end
    if Selected[p] == nil then Selected[p] = false end
    p.CharacterAdded:Connect(function()
        task.wait(.5)
        RemoveESP(p)
        CreateESP(p)
    end)
end

for _,p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
Players.PlayerAdded:Connect(function(p) HookPlayer(p) RefreshPlayers() end)
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) Selected[p] = nil RefreshPlayers() end)

LP.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then humanoid.WalkSpeed = WalkSpeedEnabled and WalkSpeed or 16 end
    if FlyEnabled then
        FlyEnabled = false
        if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
        if FlyVelocity then FlyVelocity:Destroy() FlyVelocity = nil end
        if humanoid then humanoid.PlatformStand = false end
    end
end)

-- Start GUI
OpenPage(MainPage)
RefreshPlayers()
