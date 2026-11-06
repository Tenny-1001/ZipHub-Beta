local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local VirtualUser       = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local G = getgenv().ZIP or {}
getgenv().ZIP = G

G.AutoSteal = false
G.AutoHop   = false
G.AutoSpeed = false
G.ESPEggs   = false
G.Noclip    = false
G.AntiAFK   = false
G.WalkSpeed   = 45
G.TweenSteps  = 4
G.StepTime    = 0.2
G.HopAfter    = 30
G.WebhookURL  = ""
G.LastEggSeen = os.clock()
G.Stealing    = nil
G.LastGrab    = 0
G.espCache    = G.espCache or {}

G.GOLD = Color3.fromRGB(255, 184, 0)
G.FIRE = Color3.fromRGB(255, 59, 48)
G.TEXT = Color3.fromRGB(240, 220, 190)
G.GRAD = ColorSequence.new(G.GOLD, G.FIRE)

function G.mk(cls, props)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

function G.cr(r, p) return G.mk("UICorner", {CornerRadius = UDim.new(0, r), Parent = p}) end
function G.stk(color, thick, p) return G.mk("UIStroke", {Color = color, Thickness = thick, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p}) end

function G.spin(grad)
    task.spawn(function()
        local t0 = tick()
        while grad.Parent do
            grad.Rotation = ((tick() - t0) / 4 * 360) % 360
            RunService.RenderStepped:Wait()
        end
    end)
end

function G.drag(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, target.Position, i.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

function G.gHRP(timeout)
    timeout = timeout or 3
    local t0 = tick()
    while tick() - t0 < timeout do
        local ch = LP.Character
        local h  = ch and ch:FindFirstChildOfClass("Humanoid")
        local r  = ch and ch:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 then return r end
        task.wait(0.1)
    end
    return nil
end

function G.eggPos(e)
    if not e or not e.Parent then return nil end
    if e:IsA("BasePart") then return e.Position end
    if e.PrimaryPart then return e.PrimaryPart.Position end
    local h = e:FindFirstChild("HumanoidRootPart", true)
    return h and h.Position or nil
end

G._scanCache, G._scanAt = {}, 0
function G.collectEggs()
    local tg = CollectionService:GetTagged("Egg")
    if #tg > 0 then return tg end
    if tick() - G._scanAt < 1.0 then return G._scanCache end
    G._scanAt = tick(); G._scanCache = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") or v:IsA("BasePart") then
            local n = string.lower(v.Name)
            if n:match("%f[%w]egg%f[%W]") or n:find("brainrot", 1, true) then
                table.insert(G._scanCache, v)
            end
        end
    end
    return G._scanCache
end

function G.scoreEgg(e, pos)
    local p = G.eggPos(e); if not p then return nil end
    local v = tonumber(e:GetAttribute("Value")) or tonumber(e:GetAttribute("Cost")) or tonumber(e:GetAttribute("Price")) or 0
    local d = (p - pos).Magnitude
    if d > 5000 then return nil end
    return v * 10 - d
end

function G.findBestEgg()
    local hrp = G.gHRP(2); if not hrp then return nil end
    local pos = hrp.Position
    local b, bs = nil, -math.huge
    for _, e in ipairs(G.collectEggs()) do
        if e.Parent then
            local s = G.scoreEgg(e, pos)
            if s and s > bs then b, bs = e, s end
        end
    end
    return b
end

function G.webhook(msg)
    if G.WebhookURL == "" then return end
    task.spawn(function()
        pcall(function() HttpService:PostAsync(G.WebhookURL, HttpService:JSONEncode({content = msg}), Enum.HttpContentType.ApplicationJson) end)
    end)
end

function G.grab(e)
    if not e or not e.Parent then return false end
    if os.clock() - G.LastGrab < 2.5 then return false end
    local hrp = G.gHRP(2); if not hrp then return false end
    local dest = G.eggPos(e); if not dest then return false end
    
    G.LastGrab = os.clock(); G.Stealing = e
    local startCF = hrp.CFrame
    local targetCF = CFrame.new(dest + Vector3.new(0, 3, 0))
    
    for i = 1, G.TweenSteps do
        if not hrp.Parent then break end
        local a = i / G.TweenSteps
        local t = TweenService:Create(hrp, TweenInfo.new(G.StepTime, Enum.EasingStyle.Linear), {CFrame = startCF:Lerp(targetCF, a)})
        t:Play(); t.Completed:Wait()
    end
    
    task.wait(0.3)
    local promptHold = 0
    for _, x in ipairs(e:GetDescendants()) do
        if x:IsA("ProximityPrompt") then 
            pcall(fireproximityprompt, x)
            promptHold = x.HoldDuration or 0.5
        elseif x:IsA("ClickDetector") then 
            pcall(fireclickdetector, x) 
        end
    end
    
    task.wait(promptHold + 0.1)
    
    if hrp and hrp.Parent then
        for i = 1, G.TweenSteps do
            if not hrp.Parent then break end
            local a = i / G.TweenSteps
            local t = TweenService:Create(hrp, TweenInfo.new(G.StepTime, Enum.EasingStyle.Linear), {CFrame = targetCF:Lerp(startCF, a)})
            t:Play(); t.Completed:Wait()
        end
    end
    
    G.Stealing = nil
    G.webhook("`ZIP HUB` | +**"..tostring(e.Name).."**")
    return true
end

function G.hop()
    task.spawn(function()
        local ok, raw = pcall(function()
            return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId))
        end)
        if not ok then return end
        local okJ, d = pcall(function() return HttpService:JSONDecode(raw) end)
        if not okJ then return end
        for _, s in ipairs(d.data or {}) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP) end)
                return
            end
        end
    end)
end
local GOLD, FIRE, TEXT, GRAD = G.GOLD, G.FIRE, G.TEXT, G.GRAD
local mk, cr, stk, spin, drag = G.mk, G.cr, G.stk, G.spin, G.drag

local parent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent:FindFirstChild("ZipHub")
    if old then old:Destroy() end
end)

local gui = mk("ScreenGui", {
    Name = "ZipHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
})
G.gui = gui

local main = mk("Frame", {
    Name = "Main", Size = UDim2.fromOffset(280, 380),
    Position = UDim2.new(0.5, -140, 0.5, -190),
    BackgroundColor3 = Color3.fromRGB(18, 14, 10),
    BackgroundTransparency = 0.12, Active = true, Parent = gui,
})
cr(12, main)
local mainStroke = stk(Color3.new(1, 1, 1), 1.5, main)
local mainGrad = mk("UIGradient", {Color = GRAD, Parent = mainStroke})
spin(mainGrad)

local header = mk("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Active = true, Parent = main})
drag(header, main)

mk("TextLabel", {
    Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -90, 0, 22),
    BackgroundTransparency = 1, Text = "⚡ ZIP HUB",
    Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = GOLD,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

mk("TextLabel", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -90, 0, 14),
    BackgroundTransparency = 1, Text = "v1.0 BETA",
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = FIRE,
    TextTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

local function hdrBtn(txt, color, x)
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, x, 0, 13),
        BackgroundColor3 = Color3.fromRGB(50, 30, 20), Text = txt,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = color,
        AutoButtonColor = false, Parent = header,
    })
    cr(8, b)
    return b
end

local closeBtn = hdrBtn("✕", FIRE, -40)
local miniBtn  = hdrBtn("—", GOLD, -72)

local bubble = mk("TextButton", {
    Name = "Bubble", Size = UDim2.fromOffset(46, 46),
    Position = UDim2.new(0, 30, 0.5, -23),
    BackgroundColor3 = Color3.fromRGB(18, 14, 10),
    BackgroundTransparency = 0.12, Text = "⚡",
    Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = GOLD,
    AutoButtonColor = false, Visible = false, Active = true, Parent = gui,
})
cr(23, bubble)
local bs = stk(Color3.new(1, 1, 1), 1.5, bubble)
local bg = mk("UIGradient", {Color = ColorSequence.new(FIRE, GOLD), Parent = bs})
spin(bg)
drag(bubble, bubble)

miniBtn.MouseButton1Click:Connect(function()
    bubble.Position = UDim2.new(0, main.AbsolutePosition.X, 0, main.AbsolutePosition.Y)
    main.Visible = false; bubble.Visible = true
end)

local downPos = nil
bubble.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        downPos = i.Position
    end
end)
bubble.InputEnded:Connect(function(i)
    if downPos and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        if (i.Position - downPos).Magnitude < 6 then
            local vp = workspace.CurrentCamera.ViewportSize
            local bx = math.clamp(bubble.AbsolutePosition.X, 0, vp.X - 280)
            local by = math.clamp(bubble.AbsolutePosition.Y, 0, vp.Y - 380)
            main.Position = UDim2.new(0, bx, 0, by)
            bubble.Visible = false; main.Visible = true
        end
        downPos = nil
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    for _, g in pairs(G.espCache or {}) do pcall(function() g:Destroy() end) end
    gui:Destroy()
end)

local body = mk("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 1, -68),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = GOLD,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = main,
})
mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})

local order = 0
local function nextOrder() order += 1; return order end

function G.section(txt)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = txt,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = GOLD,
        TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextOrder(), Parent = body,
    })
end

function G.toggle(label, key, cb)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(30, 20, 15),
        BackgroundTransparency = 0.15, LayoutOrder = nextOrder(), Parent = body,
    })
    cr(8, row)
    mk("TextLabel", {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1, Text = label, Font = Enum.Font.Gotham,
        TextSize = 13, TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local pill = mk("TextButton", {
        Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(46, 30, 20), Text = "",
        AutoButtonColor = false, Parent = row,
    })
    cr(10, pill)
    local pg = mk("UIGradient", {Color = GRAD, Enabled = false, Parent = pill})
    local dot = mk("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(140, 120, 100), Parent = pill,
    })
    cr(8, dot)
    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function set(v)
        G[key] = v
        pg.Enabled = v
        TweenService:Create(pill, info, {BackgroundColor3 = v and Color3.new(1,1,1) or Color3.fromRGB(46,30,20)}):Play()
        TweenService:Create(dot, info, {
            Position = v and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
            BackgroundColor3 = v and Color3.new(1,1,1) or Color3.fromRGB(140,120,100),
        }):Play()
        print("[ZIP HUB] "..key..": "..tostring(v))
        if cb then task.spawn(cb, v) end
    end
    pill.MouseButton1Click:Connect(function() set(not G[key]) end)
    return set
end
local RARITY = {
    common=Color3.fromRGB(190,190,200), uncommon=Color3.fromRGB(90,220,120),
    rare=Color3.fromRGB(70,140,255), epic=Color3.fromRGB(170,90,255),
    legendary=Color3.fromRGB(255,170,40), mythic=Color3.fromRGB(255,70,120),
    secret=Color3.fromRGB(0,234,255),
}
local function rarityCol(name)
    local s = string.lower(name)
    for k, v in pairs(RARITY) do
        if s:find(k, 1, true) then return v end
    end
    return RARITY.common
end

local function clearESP()
    for _, g in pairs(G.espCache) do pcall(function() g:Destroy() end) end
    G.espCache = {}
end

local function refreshESP()
    if not G.ESPEggs then return end
    for _, e in ipairs(G.collectEggs()) do
        if e.Parent and not G.espCache[e] then
            local p = G.eggPos(e)
            if p then
                local bb = G.mk("BillboardGui", {
                    Size = UDim2.fromOffset(140, 40), Adornee = e,
                    StudsOffset = Vector3.new(0, 3, 0),
                    AlwaysOnTop = true, Parent = e,
                })
                G.mk("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold, TextSize = 13,
                    TextColor3 = rarityCol(e.Name), TextStrokeTransparency = 0.4,
                    Text = e.Name, Parent = bb,
                })
                G.espCache[e] = bb
            end
        end
    end
end

local function applyNoclip()
    local ch = LP.Character; if not ch then return end
    for _, x in ipairs(ch:GetDescendants()) do
        if x:IsA("BasePart") and x.CanCollide then
            x.CanCollide = false
        end
    end
end

LP.Idled:Connect(function()
    if not G.AntiAFK then return end
    pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
end)

LP.CharacterAdded:Connect(function(ch)
    local h = ch:WaitForChild("Humanoid", 10)
    if not h then return end
    task.wait(0.5)
    if G.AutoSpeed then pcall(function() h.WalkSpeed = G.WalkSpeed end) end
end)

G.section("🔥 FARM")
G.toggle("Auto Steal", "AutoSteal")
G.toggle("Auto Hop",   "AutoHop")
G.toggle("Auto Speed", "AutoSpeed", function(v)
    local hrp = G.gHRP(2); if not hrp then return end
    local h = hrp.Parent:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = v and G.WalkSpeed or 16 end
end)

G.section("👁 VISUALS")
G.toggle("ESP Eggs", "ESPEggs", function(v)
    if not v then clearESP() else refreshESP() end
end)

G.section("👤 PLAYER")
G.toggle("Noclip",   "Noclip", function(v)
    if v then applyNoclip() end
end)
G.toggle("Anti-AFK", "AntiAFK")

task.spawn(function()
    while G.gui.Parent do
        task.wait(0.2)
        if G.AutoSteal then
            local hrp = G.gHRP(2)
            if hrp then
                local egg = G.findBestEgg()
                if egg then
                    G.LastEggSeen = os.clock()
                    pcall(G.grab, egg)
                elseif G.AutoHop and os.clock() - G.LastEggSeen > G.HopAfter then
                    G.LastEggSeen = os.clock()
                    G.hop()
                    task.wait(3)
                end
            end
        else
            G.LastEggSeen = os.clock()
        end
    end
end)

task.spawn(function()
    while G.gui.Parent do
        task.wait(1.0)
        if G.ESPEggs then pcall(refreshESP) end
    end
end)

task.spawn(function()
    while G.gui.Parent do
        task.wait(0.5)
        if G.Noclip then pcall(applyNoclip) end
    end
end)

task.spawn(function()
    while G.gui.Parent do
        task.wait(0.3)
        if G.AutoSpeed then
            local hrp = G.gHRP(1)
            if hrp then
                local h = hrp.Parent:FindFirstChildOfClass("Humanoid")
                if h and math.abs(h.WalkSpeed - G.WalkSpeed) > 0.5 then
                    pcall(function() h.WalkSpeed = G.WalkSpeed end)
                end
            end
        end
    end
end)

print("[ZIP HUB] Ready.")