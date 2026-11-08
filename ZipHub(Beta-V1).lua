--[[ ZipHub (Beta) — UI + Backend | Delta Android Mobile ]]

-- Services
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local TweenService= game:GetService("TweenService")
local LP          = Players.LocalPlayer

-- Palette
local COLOR = {
    Bg        = Color3.fromRGB(20, 22, 28),
    Sidebar   = Color3.fromRGB(15, 17, 22),
    Topbar    = Color3.fromRGB(28, 30, 38),
    Row       = Color3.fromRGB(28, 30, 38),
    Accent    = Color3.fromRGB(90, 130, 250),
    Text      = Color3.fromRGB(240, 240, 240),
    SubText   = Color3.fromRGB(150, 155, 165),
    Toggle    = Color3.fromRGB(45, 50, 60),
    ToggleOn  = Color3.fromRGB(90, 200, 120),
    Close     = Color3.fromRGB(220, 70, 70),
    Stroke    = Color3.fromRGB(60, 65, 80),
}

-- FIX 1: Parent chỉ vào PlayerGui — không dùng gethui/CoreGui (Delta chặn)
local PlayerGui = LP:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "ZipHubGui"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 999
ScreenGui.Parent         = PlayerGui

-- Main Frame
local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.fromOffset(600, 400)
Main.Position         = UDim2.new(0.5, -300, 0.5, -200)
Main.BackgroundColor3 = COLOR.Bg
Main.BorderSizePixel  = 0
Main.Parent           = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color     = COLOR.Stroke
MainStroke.Thickness = 1
MainStroke.Parent    = Main

-- FIX 2: UIScale tự động theo ViewportSize
local UIScale = Instance.new("UIScale")
UIScale.Parent = Main

local function applyResponsiveScale()
    local cam = workspace.CurrentCamera
    local vp  = cam and cam.ViewportSize or Vector2.new(800, 600)
    local baseW, baseH = 600, 400
    local sx = (vp.X * 0.9) / baseW
    local sy = (vp.Y * 0.9) / baseH
    local s  = math.min(sx, sy, 1)
    if UIS.TouchEnabled then
        s = math.min(s, 0.7)
    end
    UIScale.Scale = s
end

applyResponsiveScale()

local function hookCamera()
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveScale)
        applyResponsiveScale()
    end
end
hookCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

-- Topbar
local Topbar = Instance.new("Frame")
Topbar.Name             = "Topbar"
Topbar.Size             = UDim2.new(1, 0, 0, 36)
Topbar.BackgroundColor3 = COLOR.Topbar
Topbar.BorderSizePixel  = 0
Topbar.Parent           = Main

local TopbarCorner = Instance.new("UICorner")
TopbarCorner.CornerRadius = UDim.new(0, 10)
TopbarCorner.Parent = Topbar

local Title = Instance.new("TextLabel")
Title.Size                = UDim2.new(1, -60, 1, 0)
Title.Position            = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text                = "ZipHub (Beta)"
Title.TextColor3          = COLOR.Text
Title.TextXAlignment      = Enum.TextXAlignment.Left
Title.Font                = Enum.Font.GothamBold
Title.TextSize            = 16
Title.Parent              = Topbar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.fromOffset(28, 28)
CloseBtn.Position         = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = COLOR.Close
CloseBtn.Text             = "×"
CloseBtn.TextColor3       = COLOR.Text
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextSize         = 18
CloseBtn.BorderSizePixel  = 0
CloseBtn.AutoButtonColor  = false
CloseBtn.Parent           = Topbar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name             = "Sidebar"
Sidebar.Size             = UDim2.new(0, 140, 1, -36)
Sidebar.Position         = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = COLOR.Sidebar
Sidebar.BorderSizePixel  = 0
Sidebar.Parent           = Main

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding     = UDim.new(0, 4)
SidebarLayout.SortOrder   = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent      = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop   = UDim.new(0, 8)
SidebarPad.PaddingLeft  = UDim.new(0, 6)
SidebarPad.PaddingRight = UDim.new(0, 6)
SidebarPad.Parent       = Sidebar

-- Content container
local Content = Instance.new("Frame")
Content.Name                = "Content"
Content.Size                = UDim2.new(1, -140, 1, -36)
Content.Position            = UDim2.new(0, 140, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent              = Main

-- TabPages registry
local TabPages = {}

local function CreateTabButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Name             = name .. "Tab"
    btn.Size             = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = COLOR.Bg
    btn.Text             = name
    btn.TextColor3       = COLOR.SubText
    btn.Font             = Enum.Font.GothamSemibold
    btn.TextSize         = 13
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.LayoutOrder      = order or 1
    btn.Parent           = Sidebar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Name                = name .. "Page"
    page.Size                = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel     = 0
    page.ScrollBarThickness  = 4
    page.CanvasSize          = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible             = false
    page.Parent              = Content

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingTop   = UDim.new(0, 8)
    pagePad.PaddingLeft  = UDim.new(0, 8)
    pagePad.PaddingRight = UDim.new(0, 8)
    pagePad.Parent       = page

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding    = UDim.new(0, 6)
    pageLayout.SortOrder  = Enum.SortOrder.LayoutOrder
    pageLayout.Parent     = page

    TabPages[name] = page

    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(TabPages) do
            p.Visible = (n == name)
        end
        for _, ch in ipairs(Sidebar:GetChildren()) do
            if ch:IsA("TextButton") then
                ch.TextColor3 = (ch == btn) and COLOR.Accent or COLOR.SubText
            end
        end
    end)

    return btn, page
end

CreateTabButton("Main",   1)
CreateTabButton("Player", 2)
CreateTabButton("ESP",    3)
CreateTabButton("Misc",   4)

TabPages["Main"].Visible = true
Sidebar:FindFirstChild("MainTab").TextColor3 = COLOR.Accent
-- ==================== UI element creators ====================
local function CreateSection(page, title, order)
    local f = Instance.new("Frame")
    f.Size                = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.LayoutOrder         = order or 1
    f.Parent              = page

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = title
    lbl.TextColor3          = COLOR.Accent
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 12
    lbl.Parent              = f
    return f
end

local function CreateToggleRow(page, text, order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = COLOR.Row
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order or 1
    row.Parent           = page

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -60, 1, 0)
    lbl.Position            = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = text
    lbl.TextColor3          = COLOR.Text
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Font                = Enum.Font.Gotham
    lbl.TextSize            = 13
    lbl.Parent              = row

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.fromOffset(40, 20)
    btn.Position         = UDim2.new(1, -50, 0.5, -10)
    btn.BackgroundColor3 = COLOR.Toggle
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = btn

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.fromOffset(16, 16)
    knob.Position         = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = COLOR.Text
    knob.BorderSizePixel  = 0
    knob.Parent           = btn

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    return row, btn, knob
end

local function CreateSliderRow(page, text, minV, maxV, defV, order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = COLOR.Row
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order or 1
    row.Parent           = page

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -60, 0, 22)
    lbl.Position            = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text                = text
    lbl.TextColor3          = COLOR.Text
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Font                = Enum.Font.Gotham
    lbl.TextSize            = 13
    lbl.Parent              = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size                = UDim2.new(0, 50, 0, 22)
    valLbl.Position            = UDim2.new(1, -60, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                = tostring(defV)
    valLbl.TextColor3          = COLOR.Accent
    valLbl.TextXAlignment      = Enum.TextXAlignment.Right
    valLbl.Font                = Enum.Font.GothamBold
    valLbl.TextSize            = 13
    valLbl.Parent              = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 6)
    track.Position         = UDim2.new(0, 10, 1, -18)
    track.BackgroundColor3 = COLOR.Toggle
    track.BorderSizePixel  = 0
    track.Parent           = row

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0)
    tc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((defV - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = COLOR.Accent
    fill.BorderSizePixel  = 0
    fill.Parent           = track

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    return row, track, fill, valLbl
end

local function CreateButtonRow(page, text, order)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = COLOR.Accent
    btn.Text             = text
    btn.TextColor3       = COLOR.Text
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 13
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.LayoutOrder      = order or 1
    btn.Parent           = page

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    return btn
end

-- ==================== ZipHub Backend (không đổi tên) ====================
local ZipHub = {}
ZipHub.States = {
    AutoSteal = false, InstantSteal = false, AutoPlaceEgg = false,
    AutoTreadmill = false, AutoHatch = false, AutoSell = false,
    AutoFuse = false, AutoHitPlayer = false,
    ESP = { Eggs = false, Guards = false, Players = false },
    Speed = 16, Jump = 50,
}

local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TeleportService")
local HS = game:GetService("HttpService")

local function getRemote(path)
    local parts = string.split(path, "/")
    local current = RS:FindFirstChild("Packages")
    if not current then return nil end
    current = current:FindFirstChild("Networking")
    if not current then return nil end
    for _, part in ipairs(parts) do
        current = current:FindFirstChild(part)
        if not current then return nil end
    end
    return current
end

local R = {
    AskHatch         = getRemote("RF/EggWorld/AskHatch"),
    AskFinishHatch   = getRemote("RF/EggWorld/AskFinishHatch"),
    AskPlaceEgg      = getRemote("RF/EggWorld/AskPlaceEgg"),
    AskFieldEggCarry = getRemote("RF/EggWorld/AskFieldEggCarry"),
    AskFieldEggDrop  = getRemote("RF/EggWorld/AskFieldEggDrop"),
    AskSkipGrowth    = getRemote("RF/EggWorld/AskSkipGrowth"),
    SubmitClipView   = getRemote("RE/Treadmill/SubmitClipView"),
    AskSlowToggleSet = getRemote("RF/Treadmill/AskSlowToggleSet"),
    SellEveryPet     = getRemote("RE/PetSatchel/SellEveryPet"),
    SellPet          = getRemote("RE/PetSatchel/SellPet"),
    OfferFullSale    = getRemote("RF/Haul/OfferFullSatchelSale"),
    BeginFuse        = getRemote("RF/Fusery/BeginFuse"),
    ConfirmBriefing  = getRemote("RF/Fusery/ConfirmBriefing"),
    FinishReveal     = getRemote("RF/Fusery/FinishReveal"),
    BatSwing         = getRemote("RE/BatSwing/Trigger"),
    ToolTrigger      = getRemote("RE/ToolTrigger/Trigger"),
}

local function safeInvoke(r, ...)
    if not r then return nil end
    local ok, res = pcall(function() return r:InvokeServer(...) end)
    return ok and res or nil
end
local function safeFire(r, ...)
    if not r then return end
    pcall(function() r:FireServer(...) end)
end

local function getChar()
    local c = LP.Character or LP.CharacterAdded:Wait()
    local h = c:FindFirstChildOfClass("Humanoid")
    local hrp = c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 5)
    return c, h, hrp
end

-- Shared cache
local eggCache, guardCache, playerCache = {}, {}, {}
local lastRefresh = 0
local REFRESH_INTERVAL = 3

local function refreshCache(force)
    local now = tick()
    if not force and (now - lastRefresh) < REFRESH_INTERVAL then return end
    lastRefresh = now

    local neweggs = {}
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o.PrimaryPart and o.Name:lower():find("egg") then
            neweggs[#neweggs + 1] = o
        end
    end
    eggCache = neweggs

    local plrChars = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then plrChars[p.Character] = true end
    end
    local newguards = {}
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o:FindFirstChildOfClass("Humanoid") and not plrChars[o] then
            local n = o.Name:lower()
            if n:find("guard") or n:find("enemy") then
                newguards[#newguards + 1] = o
            end
        end
    end
    guardCache = newguards

    local newplrs = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then newplrs[#newplrs + 1] = p.Character end
    end
    playerCache = newplrs
end

local function getNearestEgg(maxD)
    maxD = maxD or 2000
    local _, _, hrp = getChar()
    if not hrp then return nil end
    local myPos = hrp.Position
    local best, bestD = nil, maxD
    for _, o in ipairs(eggCache) do
        if o.Parent and o.PrimaryPart then
            local ok, pos = pcall(function() return o.PrimaryPart.Position end)
            if ok and pos then
                local d = (pos - myPos).Magnitude
                if d < bestD then best, bestD = o, d end
            end
        end
    end
    return best
end

local function getNearestPlayer(maxD)
    maxD = maxD or 30
    local _, _, hrp = getChar()
    if not hrp then return nil end
    local myPos = hrp.Position
    local best, bestD = nil, maxD
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local t = p.Character:FindFirstChild("HumanoidRootPart")
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if t and t.Parent and h and h.Health > 0 then
                local ok, pos = pcall(function() return t.Position end)
                if ok and pos then
                    local d = (pos - myPos).Magnitude
                    if d < bestD then best, bestD = p, d end
                end
            end
        end
    end
    return best
end

function ZipHub.AutoSteal()
    local egg = getNearestEgg(2000)
    if not egg then return end
    local _, _, hrp = getChar()
    if not hrp then return end
    pcall(function() hrp.CFrame = egg.PrimaryPart.CFrame * CFrame.new(0, 3, 0) end)
    task.wait(0.08)
    safeInvoke(R.AskFieldEggCarry, egg.Name)
end

function ZipHub.InstantSteal()
    local egg = getNearestEgg(2000)
    if not egg then return end
    local _, _, hrp = getChar()
    if not hrp then return end
    pcall(function() hrp.CFrame = egg.PrimaryPart.CFrame * CFrame.new(0, 3, 0) end)
    safeInvoke(R.AskFieldEggCarry, egg.Name)
    safeInvoke(R.AskPlaceEgg, 1)
end

function ZipHub.AutoPlaceEgg()
    safeInvoke(R.AskPlaceEgg, 1)
end

function ZipHub.AutoTreadmill()
    safeInvoke(R.AskSlowToggleSet, false)
    safeFire(R.SubmitClipView)
end

function ZipHub.AutoHatch()
    local r = safeInvoke(R.AskHatch)
    if r ~= nil then
        task.wait(0.15)
        safeInvoke(R.AskFinishHatch)
    end
end

function ZipHub.AutoSell()
    safeFire(R.SellEveryPet)
end

function ZipHub.AutoFuse()
    safeInvoke(R.BeginFuse)
    task.wait(0.3)
    safeInvoke(R.ConfirmBriefing)
    task.wait(0.5)
    safeInvoke(R.FinishReveal)
end

function ZipHub.AutoHitPlayer()
    local target = getNearestPlayer(30)
    if not target then return end
    safeFire(R.BatSwing, target.Name)
    safeFire(R.ToolTrigger, target.Name)
end

-- ESP
ZipHub.ESPData = { Eggs = {}, Guards = {}, Players = {} }

local function checkDrawing()
    local ok, d = pcall(function() return Drawing.new("Text") end)
    if ok and d then pcall(function() d:Remove() end); return true end
    return false
end
ZipHub.DrawingOK = checkDrawing()

local function mkText()
    if not ZipHub.DrawingOK then return nil end
    local ok, d = pcall(function() return Drawing.new("Text") end)
    return ok and d or nil
end
local function dispose(d) if d and d.Text then pcall(function() d.Text:Remove() end) end end

local function updateType(key, list, color, label)
    local tbl = ZipHub.ESPData[key]
    local cam = workspace.CurrentCamera
    local seen = {}
    for _, obj in ipairs(list) do
        if obj and obj.Parent then
            seen[obj] = true
            local d = tbl[obj]
            if not d then
                local t = mkText()
                if not t then return end
                t.Size = 16
                t.Center = true
                t.Outline = true
                t.OutlineColor = Color3.new(0, 0, 0)
                t.Color = color
                d = { Text = t }
                tbl[obj] = d
            end
            local part = obj:IsA("Model")
                and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart"))
                or (obj:IsA("BasePart") and obj)
            if part and cam then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position + Vector3.new(0, 3, 0))
                d.Text.Text = label(obj)
                d.Text.Position = Vector2.new(sp.X, sp.Y)
                d.Text.Visible = onScreen
            end
        end
    end
    for obj, d in pairs(tbl) do
        if not seen[obj] then
            dispose(d)
            tbl[obj] = nil
        end
    end
end

function ZipHub.ESPUpdate()
    if not ZipHub.DrawingOK then return end
    if ZipHub.States.ESP.Eggs then
        updateType("Eggs", eggCache, Color3.fromRGB(255, 255, 0), function(o) return "Egg: " .. o.Name end)
    end
    if ZipHub.States.ESP.Guards then
        updateType("Guards", guardCache, Color3.fromRGB(255, 140, 0), function(o) return "Guard: " .. o.Name end)
    end
    if ZipHub.States.ESP.Players then
        updateType("Players", playerCache, Color3.fromRGB(255, 40, 40), function(o) return o.Name end)
    end
end

function ZipHub.SetSpeed(v)
    ZipHub.States.Speed = tonumber(v) or 16
    local _, h = getChar()
    if h then h.WalkSpeed = ZipHub.States.Speed end
end

function ZipHub.SetJump(v)
    ZipHub.States.Jump = tonumber(v) or 50
    local _, h = getChar()
    if h then h.JumpPower = ZipHub.States.Jump end
end

function ZipHub.ServerHop()
    local ok, body = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HS:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not body or not body.data then
        warn("[ZipHub] ServerHop fetch failed")
        return false
    end
    for _, s in ipairs(body.data) do
        if s.id ~= game.JobId and s.playing < s.maxPlayers then
            pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, s.id, LP) end)
            return true
        end
    end
    warn("[ZipHub] No available servers")
    return false
end

function ZipHub.Init()
    refreshCache(true)
    task.spawn(function()
        while true do
            pcall(function() refreshCache(false) end)
            task.wait(1)
        end
    end)
    task.spawn(function() while true do task.wait(0.5)  if ZipHub.States.AutoSteal     then pcall(ZipHub.AutoSteal)     end end end)
    task.spawn(function() while true do if ZipHub.States.InstantSteal then pcall(ZipHub.InstantSteal); task.wait(0.15) else task.wait(0.3) end end end)
    task.spawn(function() while true do task.wait(1)    if ZipHub.States.AutoPlaceEgg  then pcall(ZipHub.AutoPlaceEgg)  end end end)
    task.spawn(function() while true do task.wait(0.1)  if ZipHub.States.AutoTreadmill then pcall(ZipHub.AutoTreadmill) end end end)
    task.spawn(function() while true do task.wait(0.4)  if ZipHub.States.AutoHatch     then pcall(ZipHub.AutoHatch)     end end end)
    task.spawn(function() while true do task.wait(3)    if ZipHub.States.AutoSell      then pcall(ZipHub.AutoSell)      end end end)
    task.spawn(function() while true do task.wait(4)    if ZipHub.States.AutoFuse      then pcall(ZipHub.AutoFuse)      end end end)
    task.spawn(function() while true do task.wait(0.4)  if ZipHub.States.AutoHitPlayer then pcall(ZipHub.AutoHitPlayer) end end end)
    task.spawn(function() while true do task.wait(0.15) pcall(ZipHub.ESPUpdate) end end)
    task.spawn(function()
        while true do
            task.wait(0.5)
            local _, h = getChar()
            if h then
                if h.WalkSpeed ~= ZipHub.States.Speed then h.WalkSpeed = ZipHub.States.Speed end
                if h.JumpPower ~= ZipHub.States.Jump  then h.JumpPower = ZipHub.States.Jump  end
            end
        end
    end)
    LP.CharacterAdded:Connect(function()
        task.wait(1)
        local _, h = getChar()
        if h then h.WalkSpeed = ZipHub.States.Speed; h.JumpPower = ZipHub.States.Jump end
    end)
end
-- ==================== Bind helpers ====================
local function BindToggle(page, text, stateKey, order)
    local row, btn, knob = CreateToggleRow(page, text, order)
    local on = false
    local function render()
        if on then
            btn.BackgroundColor3 = COLOR.ToggleOn
            knob.Position = UDim2.new(1, -18, 0.5, -8)
        else
            btn.BackgroundColor3 = COLOR.Toggle
            knob.Position = UDim2.new(0, 2, 0.5, -8)
        end
    end
    btn.MouseButton1Click:Connect(function()
        on = not on
        render()
        if string.find(stateKey, ".", 1, true) then
            local parts = string.split(stateKey, ".")
            local t = ZipHub.States
            for i = 1, #parts - 1 do
                t = t[parts[i]]
            end
            t[parts[#parts]] = on
        else
            ZipHub.States[stateKey] = on
        end
    end)
    render()
    return btn
end

local function BindSlider(page, text, minV, maxV, defV, order, onChanged)
    local row, track, fill, valLbl = CreateSliderRow(page, text, minV, maxV, defV, order)
    local dragging = false
    local function setFromX(mouseX)
        local absPos  = track.AbsolutePosition.X
        local absSize = track.AbsoluteSize.X
        if absSize <= 0 then return end
        local ratio = math.clamp((mouseX - absPos) / absSize, 0, 1)
        local val = minV + (maxV - minV) * ratio
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        valLbl.Text = tostring(math.floor(val + 0.5))
        if onChanged then onChanged(val) end
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return track
end

local function BindButton(page, text, order, onClick)
    local btn = CreateButtonRow(page, text, order)
    btn.MouseButton1Click:Connect(function()
        pcall(onClick)
    end)
    return btn
end

-- ==================== Populate tabs ====================
local MainPage = TabPages["Main"]
CreateSection(MainPage, "AUTO FARM", 1)
BindToggle(MainPage, "Auto Steal",      "AutoSteal",     2)
BindToggle(MainPage, "Instant Steal",   "InstantSteal",  3)
BindToggle(MainPage, "Auto Place Egg",  "AutoPlaceEgg",  4)
BindToggle(MainPage, "Auto Treadmill",  "AutoTreadmill", 5)
BindToggle(MainPage, "Auto Hatch",      "AutoHatch",     6)
BindToggle(MainPage, "Auto Sell",       "AutoSell",      7)
BindToggle(MainPage, "Auto Fuse",       "AutoFuse",      8)
BindToggle(MainPage, "Auto Hit Player", "AutoHitPlayer", 9)

local PlayerPage = TabPages["Player"]
CreateSection(PlayerPage, "PLAYER MODS", 1)
BindSlider(PlayerPage, "WalkSpeed", 16, 200, 16, 2, function(v) ZipHub.SetSpeed(v) end)
BindSlider(PlayerPage, "JumpPower", 50, 300, 50, 3, function(v) ZipHub.SetJump(v)  end)

local ESPPage = TabPages["ESP"]
CreateSection(ESPPage, "ESP", 1)
BindToggle(ESPPage, "ESP Eggs",    "ESP.Eggs",    2)
BindToggle(ESPPage, "ESP Guards",  "ESP.Guards",  3)
BindToggle(ESPPage, "ESP Players", "ESP.Players", 4)

local MiscPage = TabPages["Misc"]
CreateSection(MiscPage, "SERVER", 1)
BindButton(MiscPage, "Server Hop", 2, function() ZipHub.ServerHop() end)

-- ==================== FIX 3: Drag clamp (mobile) ====================
local dragging = false
local dragStart = Vector2.new()
local startPos  = Vector2.new()

local function clampPosition(pos)
    local cam = workspace.CurrentCamera
    local vp  = cam and cam.ViewportSize or Vector2.new(800, 600)
    local size = Main.AbsoluteSize
    local x = math.clamp(pos.X, 0, math.max(0, vp.X - size.X))
    local y = math.clamp(pos.Y, 0, math.max(0, vp.Y - size.Y))
    return UDim2.fromOffset(x, y)
end

Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = Vector2.new(Main.AbsolutePosition.X, Main.AbsolutePosition.Y)
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta  = input.Position - dragStart
        local newPos = startPos + delta
        Main.Position = clampPosition(newPos)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ==================== Boot ====================
task.spawn(function()
    pcall(ZipHub.Init)
end)

print("[ZipHub] UI + Backend loaded")