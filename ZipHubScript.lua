-- ZipHub Beta | Blox Fruits | remotes taken from BloxFruits_Remotes.txt
-- INSERT = show/hide. Nothing runs on launch. Swing once by hand so the hit token gets captured.
-- ban risk: bulk remote fire on a main. alt only.

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local VirtualUser  = game:GetService("VirtualUser")
local lp           = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if not (hookmetamethod and newcclosure and checkcaller and getnamecallmethod) then
    return warn("ZipHub: executor lacks hookmetamethod/newcclosure/checkcaller/getnamecallmethod")
end
if not (writefile and getcustomasset) then warn("ZipHub: no writefile/getcustomasset, icon and sounds disabled") end
if env.ZipHub then pcall(env.ZipHub.stop) end

-- remotes (all seen in the log)
local off = {
    net  = RS:WaitForChild("Modules"):WaitForChild("Net"),
    comm = RS:WaitForChild("Remotes"):WaitForChild("CommF_"),   -- InvokeServer("StartQuest","BanditQuest1",1) / ("AddPoint","Melee",1)
    talk = RS.Remotes:WaitForChild("OnTalkToNPC"),              -- FireServer(Workspace.NPCs["Bandit Quest Giver"])
}
local QU = RS.Remotes:WaitForChild("QuestUpdate")               -- S->C: (nil | {InternalQuestName=..}, {Context="Update"|"Complete"})
local CS = RS.Remotes:WaitForChild("ChangeSetting")              -- FireServer("DmgCounter"|"CameraShake", bool)
local RA = off.net:WaitForChild("RE/RegisterAttack")            -- FireServer(0.5|1, combo 1..4)
local RH = off.net:WaitForChild("RE/RegisterHit")               -- FireServer(part, {}, nil, token)

-- farm presets. Bandit is fully from the log. add more: mob name from Workspace.Enemies, quest + npc from your own spy log
local PRESETS = {
    Bandit = { mob = "Bandit", quest = "BanditQuest1", idx = 1, npc = "Bandit Quest Giver",
               area = Vector3.new(1139.6, 10.8, 1679.6) },      -- swing target seen in log
    ["Mob Only"] = { mob = nil, quest = "FILL", idx = 1, npc = "FILL", area = nil },   -- uses CFG.mob, no quest
    Custom = { mob = "Monkey", quest = "FILL", idx = 1, npc = "FILL", area = nil },
}
local PRESET_ORDER = { "Bandit", "Mob Only", "Custom" }
local MOBS = { "Bandit", "Monkey", "Toga Warrior", "Military Soldier", "Military Spy", "Dangerous Prisoner", "Snowman", "Galley Pirate", "Galley Captain" }
local NPCS = { "Bandit Quest Giver", "Boat Dealer", "Blox Fruit Dealer", "Sword Dealer", "ZiolesShadow" }
local SPAWNS = { "Jungle" }   -- only "Jungle" seen in the log; add names from your own spy log

local CFG = {
    farm = false, quest = true, fastAttack = false, autoStat = false,
    preset = "Bandit", weapon = "Combat", mob = "Monkey", npc = "Boat Dealer", spawn = "Jungle",
    dmgCounter = true, camShake = false,
    antiBan = true, rateCap = 30,
    stat = "Melee", statAmt = 1,
    tweenSpeed = 300, hover = 8, hitRange = 60, attackDelay = 0.12,
    espPlayers = false, espEnemies = false, noclip = true, antiAfk = true,
}
local STATS = { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } -- only "Melee" verified in log

local running, conns, hitToken, combo, lastQuest = true, {}, nil, 0, 0
local questState   -- nil = no QuestUpdate seen yet, true/false after

conns[#conns + 1] = QU.OnClientEvent:Connect(function(q, info)
    if type(info) == "table" and info.Context == "Complete" then questState = false
    elseif type(q) == "table" and q.InternalQuestName then questState = true
    elseif q == nil then questState = false end
end)

-- grab the hit token from the game's own call, never hardcode it
local oldNc
oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if self == RH and not checkcaller() and getnamecallmethod() == "FireServer" then
        local a = { ... }
        if type(a[4]) == "string" then hitToken = a[4] end
    end
    return oldNc(self, ...)
end))

-- helpers
local function char() return lp.Character end
local function root() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function enemyList()
    local f = workspace:FindFirstChild("Enemies")
    return f and f:GetChildren() or {}
end
local function findNpc(name)
    local f = workspace:FindFirstChild("NPCs")
    return f and f:FindFirstChild(name)
end
local function isAlive(m)
    local h = m and m:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local curTween
local function cancelTween()
    if curTween then pcall(function() curTween:Cancel() end) curTween = nil end
end

-- Completed also fires on Cancel, so cancelTween() releases the waiting caller
local function tweenTo(cf)
    local hrp = root()
    if not (running and hrp) then return end
    cancelTween()
    local d = (hrp.Position - cf.Position).Magnitude
    local t = TweenService:Create(hrp, TweenInfo.new(math.max(d / CFG.tweenSpeed, 0.05), Enum.EasingStyle.Linear), { CFrame = cf })
    curTween = t
    t:Play()
    t.Completed:Wait()
    if curTween == t then curTween = nil end
end

local function nearestMob(name)
    local hrp, best, bd = root(), nil, math.huge
    if not hrp then return end
    for _, m in ipairs(enemyList()) do
        local mr = m:FindFirstChild("HumanoidRootPart")
        if m.Name == name and mr and isAlive(m) then
            local d = (mr.Position - hrp.Position).Magnitude
            if d < bd then best, bd = m, d end
        end
    end
    return best
end

local function mobsInRange()
    local hrp, out = root(), {}
    if not hrp then return out end
    for _, m in ipairs(enemyList()) do
        local mr = m:FindFirstChild("HumanoidRootPart")
        if mr and isAlive(m) and (mr.Position - hrp.Position).Magnitude <= CFG.hitRange then
            out[#out + 1] = m
        end
    end
    return out
end

local lastEquip = 0
local function equip()
    local c = char()
    if not c or c:FindFirstChild(CFG.weapon) or os.clock() - lastEquip < 0.6 then return end
    lastEquip = os.clock()
    local t = lp.Backpack:FindFirstChild(CFG.weapon)
    local h = c:FindFirstChildOfClass("Humanoid")
    if t and h then h:EquipTool(t) end
end

local function questActive() return questState end   -- nil until the first QuestUpdate arrives

local function takeQuest(P)
    local npc = findNpc(P.npc)
    if npc then
        tweenTo(npc:GetPivot() * CFrame.new(0, 3, 4))
        pcall(function() off.talk:FireServer(npc) end)
        task.wait(0.4)
    end
    pcall(function() off.comm:InvokeServer("StartQuest", P.quest, P.idx) end)
    lastQuest = os.clock()
end

local function goNpc()
    local npc = findNpc(CFG.npc)
    if not npc then return end
    tweenTo(npc:GetPivot() * CFrame.new(0, 3, 4))
    pcall(function() off.talk:FireServer(npc) end)
end

local function setSpawn()
    pcall(function() off.comm:InvokeServer("SetLastSpawnPoint", CFG.spawn) end)
end

local function farmStep()
    local P = PRESETS[CFG.preset]
    local hrp = root()
    if not (P and hrp and isAlive(char())) then return end
    equip()
    if CFG.quest and P.quest ~= "FILL" then
        local act = questActive()
        if act == nil then act = (os.clock() - lastQuest) < 5 end
        if not act then takeQuest(P) end
    end
    local m = nearestMob(P.mob or CFG.mob)
    if not m then
        if P.area and (hrp.Position - P.area).Magnitude > 120 then tweenTo(CFrame.new(P.area + Vector3.new(0, CFG.hover, 0))) end
        return
    end
    local mp = m.HumanoidRootPart.Position
    local tp = mp + Vector3.new(0, CFG.hover, 0)
    if (hrp.Position - tp).Magnitude > 2 then tweenTo(CFrame.new(tp, mp)) end
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- anti-ban (basic): random jitter on every loop wait + per-second cap on attack remotes
-- shortcut: only shapes the traffic, no server-side evasion; upgrade after test results
local fired = {}
local function jitter(t) return CFG.antiBan and t * (0.8 + math.random() * 0.5) or t end
local function budgetOk(n)
    if not CFG.antiBan then return true end
    local now = os.clock()
    while fired[1] and (now - fired[1] > 1 or fired[1] > now) do table.remove(fired, 1) end
    if #fired + n > CFG.rateCap then return false end
    for _ = 1, n do fired[#fired + 1] = now end
    return true
end

-- loops
task.spawn(function()
    while running do
        task.wait(jitter(0.1))
        if CFG.farm then pcall(farmStep) else cancelTween() end
    end
end)

task.spawn(function()   -- fast attack: attack ping then a hit per mob in range
    while running do
        task.wait(jitter(CFG.attackDelay))
        if CFG.fastAttack and hitToken then
            local list = mobsInRange()
            local n = math.min(#list, CFG.antiBan and 4 or #list, math.max(CFG.rateCap - 1, 1))
            for i = #list, n + 1, -1 do list[i] = nil end
            if #list > 0 and budgetOk(1 + #list) then
                combo = combo % 4 + 1
                pcall(function() RA:FireServer(combo == 4 and 1 or 0.5, combo) end)
                for _, m in ipairs(list) do
                    local part = m:FindFirstChild("RightHand") or m:FindFirstChild("LeftHand") or m:FindFirstChild("HumanoidRootPart")
                    pcall(function() RH:FireServer(part, {}, nil, hitToken) end)
                    if CFG.antiBan then task.wait(0.01 + math.random() * 0.02) end
                end
            end
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(jitter(1.5))
        if CFG.autoStat then pcall(function() off.comm:InvokeServer("AddPoint", CFG.stat, CFG.statAmt) end) end
    end
end)

local parts, lastScan = {}, 0
conns[#conns + 1] = RunService.Stepped:Connect(function()
    local c = char()
    if not (CFG.farm and CFG.noclip and c) then return end
    if os.clock() - lastScan > 1 then
        lastScan, parts = os.clock(), {}
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then parts[#parts + 1] = p end
        end
    end
    for _, p in ipairs(parts) do
        if p.CanCollide then p.CanCollide = false end
    end
end)

conns[#conns + 1] = lp.Idled:Connect(function()
    if CFG.antiAfk then
        task.wait(math.random() * 2 + 0.5)
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- esp
local function tag(model, col, on)
    local hl = model:FindFirstChild("RK_ESP")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not on or not hrp then
        if hl then hl:Destroy() end
        if hrp and hrp:FindFirstChild("RK_TAG") then hrp.RK_TAG:Destroy() end
        return
    end
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name, hl.FillColor, hl.FillTransparency, hl.OutlineColor = "RK_ESP", col, 0.7, col
        hl.Parent = model
    end
    local bb = hrp:FindFirstChild("RK_TAG")
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name, bb.Size, bb.AlwaysOnTop, bb.StudsOffset = "RK_TAG", UDim2.fromOffset(140, 30), true, Vector3.new(0, 3.5, 0)
        local l = Instance.new("TextLabel")
        l.Name, l.Size, l.BackgroundTransparency, l.TextColor3 = "L", UDim2.fromScale(1, 1), 1, col
        l.TextStrokeTransparency, l.Font, l.TextSize = 0.4, Enum.Font.GothamBold, 12
        l.Parent = bb
        bb.Parent = hrp
    end
    local me, h = root(), model:FindFirstChildOfClass("Humanoid")
    local d = me and math.floor((me.Position - hrp.Position).Magnitude) or 0
    bb.L.Text = string.format("%s [%dm]%s", model.Name, d, h and (" " .. math.floor(h.Health)) or "")
end

task.spawn(function()
    while running do
        task.wait(0.4)
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and p.Character then tag(p.Character, Color3.fromRGB(255, 60, 60), CFG.espPlayers) end
            end
            for _, m in ipairs(enemyList()) do
                tag(m, Color3.fromRGB(255, 170, 0), CFG.espEnemies)
            end
        end)
    end
end)

-- ===== ZipHub UI: glass window, cyan/purple, tweens, synthesized sounds, bolt icon when minimized =====
local SoundService = game:GetService("SoundService")
-- base64 decode (icon) + wav synth (ui sounds), no external assets
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LUT = {}
for i = 1, 64 do LUT[B64:byte(i)] = i - 1 end

local function b64dec(s)
    s = s:gsub("[^%w%+/]", "")
    local out, r = {}, #s % 4
    for i = 1, #s - r, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        local v = LUT[a] * 262144 + LUT[b] * 4096 + LUT[c] * 64 + LUT[d]
        out[#out + 1] = string.char(v // 65536, v // 256 % 256, v % 256)
    end
    if r >= 2 then
        local a, b, c = s:byte(#s - r + 1, #s - r + 3)
        if r == 2 then
            out[#out + 1] = string.char((LUT[a] * 64 + LUT[b]) // 16)
        else
            local v = LUT[a] * 4096 + LUT[b] * 64 + LUT[c]
            out[#out + 1] = string.char(v // 1024, v // 4 % 256)
        end
    end
    return table.concat(out)
end

local SR = 22050
local function synth(dur, fn)
    local n, parts = math.floor(SR * dur), {}
    for i = 0, n - 1 do
        local v = math.max(-1, math.min(1, fn(i / SR)))
        parts[#parts + 1] = string.pack("<i2", math.floor(v * 30000))
    end
    local data = table.concat(parts)
    return "RIFF" .. string.pack("<I4", 36 + #data) .. "WAVEfmt "
        .. string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, SR, SR * 2, 2, 16)
        .. "data" .. string.pack("<I4", #data) .. data
end

local TAU = math.pi * 2
local function chirp(f0, k, amp, dur, decay)   -- soft glide, attack ramp kills the pop
    return synth(dur, function(t)
        local env = (1 - math.exp(-t * 500)) * math.exp(-t * decay)
        return math.sin(TAU * (f0 * t + k * t * t / 2)) * env * amp
    end)
end

local SFX = {
    click = synth(0.07, function(t)
        local a = (1 - math.exp(-t * 800)) * math.exp(-t * 70)
        return (math.sin(TAU * 1250 * t) * 0.35 + math.sin(TAU * 2500 * t) * 0.07) * a
    end),
    hover = chirp(2000, 0, 0.1, 0.035, 120),
    on    = chirp(650, 3500, 0.3, 0.15, 16),
    off   = chirp(1000, -3000, 0.28, 0.15, 16),
    open  = chirp(400, 2800, 0.28, 0.3, 9),
    close = chirp(900, -2600, 0.26, 0.3, 9),
}


local ICON_B64 = [==[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]==]

local ACC, ACC2 = Color3.fromRGB(34, 211, 238), Color3.fromRGB(168, 85, 247)
local BG = Color3.fromRGB(11, 6, 24)
local TXT, MUT, LNC = Color3.fromRGB(232, 230, 255), Color3.fromRGB(143, 134, 184), Color3.fromRGB(120, 90, 220)
local WHITE, OFFTRACK = Color3.new(1, 1, 1), Color3.fromRGB(42, 32, 80)
local U2 = UDim2.fromOffset

CFG.sound = true

local function C(sig, fn) conns[#conns + 1] = sig:Connect(fn) end
local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    i.Parent = parent
    return i
end
local function tw(o, props, t, style, dir)
    local x = TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    x:Play()
    return x
end

-- sounds: wav bytes made in-script, written to workspace, loaded via getcustomasset (no rbxassetid needed)
local sounds = {}
if writefile and getcustomasset then
    for name, bytes in pairs(SFX) do
        pcall(function()
            local f = "ZipHub_" .. name .. ".wav"
            writefile(f, bytes)
            sounds[name] = mk("Sound", { SoundId = getcustomasset(f), Volume = 0.55 }, SoundService)
        end)
    end
end
local function play(n)
    local s = sounds[n]
    if s and CFG.sound then s.TimePosition = 0; s:Play() end
end

local iconAsset
if writefile and getcustomasset then
    pcall(function()
        writefile("ZipHub_icon.png", b64dec(ICON_B64))
        iconAsset = getcustomasset("ZipHub_icon.png")
    end)
end

-- window
local gui = mk("ScreenGui", { Name = "ZipHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, (gethui and gethui()) or game:GetService("CoreGui"))
local view = workspace.CurrentCamera.ViewportSize
local baseScale = math.min(1, view.X / 620, view.Y / 420)

local win = mk("Frame", { Size = U2(580, 380), AnchorPoint = Vector2.new(0.5, 0.5), Position = U2(view.X / 2, view.Y / 2),
    BackgroundColor3 = WHITE, BackgroundTransparency = 0.06, ClipsDescendants = true, Visible = false }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 16) }, win)
mk("UIGradient", { Rotation = 55, Color = ColorSequence.new(Color3.fromRGB(38, 20, 82), Color3.fromRGB(10, 6, 24)) }, win)
local scale = mk("UIScale", { Scale = 0.05 }, win)
local stroke = mk("UIStroke", { Thickness = 1.6, Color = WHITE, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, win)
local sgrad = mk("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ACC),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(46, 28, 96)), ColorSequenceKeypoint.new(1, ACC2) }) }, stroke)

local blob = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -30, 1, 10), Size = U2(300, 300),
    BackgroundColor3 = ACC2, BackgroundTransparency = 0.88, BorderSizePixel = 0 }, win)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, blob)

local fx = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, win)
local drops = {}
for i = 1, 18 do
    local f = mk("Frame", { Size = U2(1, math.random(18, 40)), BackgroundColor3 = ACC, BackgroundTransparency = math.random(80, 92) / 100,
        BorderSizePixel = 0 }, fx)
    drops[i] = { f = f, x = math.random(0, 580), y = math.random(-40, 380), v = math.random(120, 260) }
end

-- sidebar
local side = mk("Frame", { Size = U2(150, 380), BackgroundTransparency = 1 }, win)
mk("Frame", { Position = U2(149, 0), Size = U2(1, 380), BackgroundColor3 = LNC, BackgroundTransparency = 0.7, BorderSizePixel = 0 }, side)

local logo = mk("ImageLabel", { Position = U2(14, 12), Size = U2(32, 32), BackgroundColor3 = BG, Image = iconAsset or "",
    ScaleType = Enum.ScaleType.Crop }, side)
mk("UICorner", { CornerRadius = UDim.new(0, 9) }, logo)
mk("UIStroke", { Color = ACC, Transparency = 0.5, Thickness = 1 }, logo)
local nm = mk("TextLabel", { Position = U2(54, 10), Size = U2(90, 20), BackgroundTransparency = 1, Text = "ZipHub",
    Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }, side)
mk("UIGradient", { Color = ColorSequence.new(ACC, ACC2) }, nm)
mk("TextLabel", { Position = U2(54, 29), Size = U2(90, 14), BackgroundTransparency = 1, Text = "BETA", Font = Enum.Font.GothamBold,
    TextSize = 9, TextColor3 = ACC, TextXAlignment = Enum.TextXAlignment.Left }, side)
mk("TextLabel", { Position = U2(14, 352), Size = U2(122, 16), BackgroundTransparency = 1, Text = "ZipHub Beta  |  INSERT = hide",
    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = MUT, TextXAlignment = Enum.TextXAlignment.Left }, side)

local ind = mk("Frame", { Position = U2(0, 69), Size = U2(3, 22), BackgroundColor3 = ACC, BorderSizePixel = 0 }, side)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, ind)
mk("UIStroke", { Color = ACC, Transparency = 0.6, Thickness = 3 }, ind)

-- main area
local top = mk("Frame", { Position = U2(150, 0), Size = U2(430, 44), BackgroundTransparency = 1 }, win)
mk("Frame", { Position = U2(0, 43), Size = U2(430, 1), BackgroundColor3 = LNC, BackgroundTransparency = 0.7, BorderSizePixel = 0 }, top)
local title = mk("TextLabel", { Position = U2(16, 0), Size = U2(160, 44), BackgroundTransparency = 1, Text = "FARM", Font = Enum.Font.GothamBold,
    TextSize = 14, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left }, top)
local status = mk("TextLabel", { Position = U2(170, 0), Size = U2(200, 44), BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = MUT, TextXAlignment = Enum.TextXAlignment.Right }, top)
local minBtn = mk("TextButton", { Position = U2(396, 9), Size = U2(26, 26), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "-",
    Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = MUT, AutoButtonColor = false }, top)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, minBtn)
minBtn.MouseEnter:Connect(function() tw(minBtn, { BackgroundTransparency = 0.88, TextColor3 = ACC }, 0.15); play("hover") end)
minBtn.MouseLeave:Connect(function() tw(minBtn, { BackgroundTransparency = 1, TextColor3 = MUT }, 0.15) end)

local holder = mk("CanvasGroup", { Position = U2(150, 44), Size = U2(430, 336), BackgroundTransparency = 1 }, win)

-- tabs / pages
local ORDER = { "FARM", "COMBAT", "VISUAL", "MISC", "CONFIG" }
local tabs, pages, cur = {}, {}, nil

local function setTab(name, instant)
    if cur == name then return end
    cur = name
    for n, t in pairs(tabs) do
        local on = n == name
        tw(t.label, { TextColor3 = on and WHITE or MUT }, 0.2)
        tw(t.btn, { BackgroundTransparency = on and 0.86 or 1 }, 0.2)
        pages[n].Visible = on
    end
    title.Text = name
    tw(ind, { Position = U2(0, tabs[name].y + 7) }, 0.4, Enum.EasingStyle.Back)
    if not instant then
        holder.GroupTransparency, holder.Position = 1, U2(150, 56)
        tw(holder, { GroupTransparency = 0, Position = U2(150, 44) }, 0.35)
        play("click")
    end
end

for i, name in ipairs(ORDER) do
    local y = 62 + (i - 1) * 40
    local b = mk("TextButton", { Position = U2(10, y), Size = U2(130, 36), BackgroundColor3 = ACC, BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false }, side)
    mk("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
    local l = mk("TextLabel", { Position = U2(14, 0), Size = U2(110, 36), BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = MUT, TextXAlignment = Enum.TextXAlignment.Left }, b)
    tabs[name] = { btn = b, label = l, y = y }
    local pg = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = ACC2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false }, holder)
    mk("UIListLayout", { Padding = UDim.new(0, 8) }, pg)
    mk("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16) }, pg)
    pages[name] = pg
    b.MouseEnter:Connect(function()
        if cur ~= name then tw(b, { BackgroundTransparency = 0.94 }, 0.15); tw(l, { Position = U2(18, 0) }, 0.15) end
        play("hover")
    end)
    b.MouseLeave:Connect(function() if cur ~= name then tw(b, { BackgroundTransparency = 1 }, 0.15) end; tw(l, { Position = U2(14, 0) }, 0.15) end)
    b.MouseButton1Click:Connect(function() setTab(name) end)
end

-- row widgets
local refreshers = {}

local function ripple(btn)
    btn.MouseButton1Down:Connect(function(x, y)
        local s = scale.Scale
        local d = btn.AbsoluteSize.X / s * 2.2
        local c = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = U2((x - btn.AbsolutePosition.X) / s, (y - btn.AbsolutePosition.Y) / s),
            Size = U2(0, 0), BackgroundColor3 = ACC, BackgroundTransparency = 0.7, BorderSizePixel = 0 }, btn)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
        tw(c, { Size = U2(d, d), BackgroundTransparency = 1 }, 0.55)
        game:GetService("Debris"):AddItem(c, 0.7)
    end)
end

local function rowFrame(page, label, sub)
    local r = mk("TextButton", { Size = UDim2.new(1, 0, 0, sub and 48 or 40), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Text = "",
        AutoButtonColor = false, ClipsDescendants = true }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 12) }, r)
    local st = mk("UIStroke", { Color = LNC, Transparency = 0.6, Thickness = 1 }, r)
    mk("TextLabel", { Position = U2(12, sub and 6 or 0), Size = UDim2.new(1, -150, 0, sub and 18 or 40), BackgroundTransparency = 1, Text = label,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left }, r)
    if sub then
        mk("TextLabel", { Position = U2(12, 25), Size = UDim2.new(1, -150, 0, 16), BackgroundTransparency = 1, Text = sub, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = MUT, TextXAlignment = Enum.TextXAlignment.Left }, r)
    end
    r.MouseEnter:Connect(function() tw(st, { Color = ACC, Transparency = 0.25 }, 0.2); tw(r, { BackgroundTransparency = 0.9 }, 0.2); play("hover") end)
    r.MouseLeave:Connect(function() tw(st, { Color = LNC, Transparency = 0.6 }, 0.2); tw(r, { BackgroundTransparency = 0.94 }, 0.2) end)
    ripple(r)
    return r
end

local function pill(parent, w)
    local p = mk("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = U2(w, 24), BackgroundColor3 = ACC,
        BackgroundTransparency = 0.86, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = ACC }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, p)
    return p
end

local function toggle(page, label, key, sub, fn)
    local r = rowFrame(page, label, sub)
    local sw = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = U2(42, 22), BackgroundColor3 = OFFTRACK }, r)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, sw)
    local g = mk("UIGradient", { Color = ColorSequence.new(ACC, ACC2), Enabled = false }, sw)
    local sst = mk("UIStroke", { Color = ACC, Thickness = 1.5, Transparency = 1 }, sw)
    local knob = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = U2(16, 16), BackgroundColor3 = MUT }, sw)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    local function rf(anim)
        local on, d = CFG[key], anim and 0.28 or 0
        g.Enabled = on
        sw.BackgroundColor3 = on and WHITE or OFFTRACK
        tw(sst, { Transparency = on and 0.4 or 1 }, d)
        tw(knob, { Position = on and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = on and WHITE or MUT }, d, Enum.EasingStyle.Back)
    end
    r.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]; rf(true); play(CFG[key] and "on" or "off")
        if fn then pcall(fn, CFG[key]) end
    end)
    refreshers[#refreshers + 1] = rf
    rf(false)
end

local function cycle(page, label, key, list, sub)
    local r = rowFrame(page, label, sub)
    local p = pill(r, 140)
    local function rf() p.Text = tostring(CFG[key]) end
    r.MouseButton1Click:Connect(function()
        local n = 1
        for i, v in ipairs(list) do if v == CFG[key] then n = i % #list + 1 end end
        CFG[key] = list[n]
        rf()
        p.BackgroundTransparency = 0.6
        tw(p, { BackgroundTransparency = 0.86 }, 0.3)
        play("click")
    end)
    refreshers[#refreshers + 1] = rf
    rf()
end

local function step(page, label, key, lo, hi, inc, sub)
    local r = rowFrame(page, label, sub)
    local function sbtn(txt, x)
        local b = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = U2(24, 24), BackgroundColor3 = ACC,
            BackgroundTransparency = 0.86, Text = txt, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = ACC, AutoButtonColor = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
        b.MouseEnter:Connect(function() tw(b, { BackgroundTransparency = 0.6 }, 0.15) end)
        b.MouseLeave:Connect(function() tw(b, { BackgroundTransparency = 0.86 }, 0.15) end)
        return b
    end
    local plus, minus = sbtn("+", -12), sbtn("-", -86)
    local val = mk("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = U2(44, 24), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TXT }, r)
    local function rf() val.Text = inc < 1 and string.format("%.2f", CFG[key]) or tostring(CFG[key]) end
    local function move(d)
        CFG[key] = math.floor(math.max(lo, math.min(hi, CFG[key] + d)) / inc + 0.5) * inc
        rf()
        play("click")
    end
    plus.MouseButton1Click:Connect(function() move(inc) end)
    minus.MouseButton1Click:Connect(function() move(-inc) end)
    refreshers[#refreshers + 1] = rf
    rf()
end

local function button(page, label, fn, sub)
    local r = rowFrame(page, label, sub)
    pill(r, 56).Text = "RUN"
    r.MouseButton1Click:Connect(function() play("click"); fn() end)
end

-- pages
toggle(pages.FARM, "Auto Farm", "farm", "quest + tween to mob + fast attack range")
toggle(pages.FARM, "Auto Quest", "quest")
cycle(pages.FARM, "Preset", "preset", PRESET_ORDER)
cycle(pages.FARM, "Mob", "mob", MOBS, "used by the Mob Only preset (no quest)")
step(pages.FARM, "Tween speed", "tweenSpeed", 100, 400, 25)
step(pages.FARM, "Hover height", "hover", 4, 20, 1)
toggle(pages.FARM, "Noclip while farming", "noclip")
toggle(pages.FARM, "Auto Stats", "autoStat")
cycle(pages.FARM, "Stat", "stat", STATS)

toggle(pages.COMBAT, "Fast Attack", "fastAttack", "swing once by hand so the hit token is captured")
step(pages.COMBAT, "Hit range", "hitRange", 20, 200, 10)
step(pages.COMBAT, "Attack delay", "attackDelay", 0.05, 0.5, 0.01)
cycle(pages.COMBAT, "Weapon", "weapon", { "Combat", "Saber", "Blade-Blade" })
toggle(pages.COMBAT, "Anti-ban (basic)", "antiBan", "random delays + cap on attack remotes")
step(pages.COMBAT, "Max remotes / sec", "rateCap", 10, 60, 5)

toggle(pages.VISUAL, "ESP Players", "espPlayers")
toggle(pages.VISUAL, "ESP Enemies", "espEnemies")

toggle(pages.MISC, "Anti AFK", "antiAfk")
toggle(pages.MISC, "UI Sounds", "sound")
toggle(pages.MISC, "Damage counter", "dmgCounter", nil, function(v) CS:FireServer("DmgCounter", v) end)
toggle(pages.MISC, "Camera shake", "camShake", nil, function(v) CS:FireServer("CameraShake", v) end)
cycle(pages.MISC, "NPC", "npc", NPCS)
button(pages.MISC, "Go to NPC", function() task.spawn(goNpc) end, "tween there + talk")
cycle(pages.MISC, "Spawn", "spawn", SPAWNS)
button(pages.MISC, "Set spawn point", setSpawn)
button(pages.MISC, "Re-take quest now", function() task.spawn(function() pcall(takeQuest, PRESETS[CFG.preset]) end) end)
button(pages.MISC, "Unload", function() if env.ZipHub then env.ZipHub.stop() end end)

local FILE = "ZipHub.json"
button(pages.CONFIG, "Save config", function()
    if writefile then pcall(function() writefile(FILE, HttpService:JSONEncode(CFG)) end) end
end)
button(pages.CONFIG, "Load config", function()
    if not (isfile and readfile and isfile(FILE)) then return end
    local ok, t = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
    if not ok then return end
    for k, v in pairs(t) do
        if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
    end
    CFG.farm, CFG.fastAttack, CFG.autoStat = false, false, false   -- nothing fires on load
    if not PRESETS[CFG.preset] then CFG.preset = "Bandit" end
    for _, rf in ipairs(refreshers) do rf(false) end
end)

-- minimized icon (the bolt)
local icon = mk("ImageButton", { Name = "ZipIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = U2(64, 64), Size = U2(58, 58), BackgroundColor3 = BG,
    Image = iconAsset or "", ScaleType = Enum.ScaleType.Crop, AutoButtonColor = false, Visible = false }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 15) }, icon)
local iscale = mk("UIScale", { Scale = 0 }, icon)
local istroke = mk("UIStroke", { Thickness = 2, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, icon)
local igrad = mk("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ACC), ColorSequenceKeypoint.new(0.5, ACC2),
    ColorSequenceKeypoint.new(1, ACC) }) }, istroke)
if not iconAsset then
    mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "Z", Font = Enum.Font.GothamBold, TextSize = 28, TextColor3 = ACC }, icon)
end
icon.MouseEnter:Connect(function() tw(iscale, { Scale = 1.1 }, 0.2, Enum.EasingStyle.Back); play("hover") end)
icon.MouseLeave:Connect(function() tw(iscale, { Scale = 1 }, 0.2) end)

local opened, busy, lastPos = false, false, win.Position

local function openUI()
    if opened or busy then return end
    busy = true
    win.Position, win.Visible = icon.Position, true
    scale.Scale = 0.05
    tw(iscale, { Scale = 0 }, 0.2)
    tw(win, { Position = lastPos }, 0.5)
    tw(scale, { Scale = baseScale }, 0.5, Enum.EasingStyle.Back)
    play("open")
    task.delay(0.5, function() icon.Visible, opened, busy = false, true, false end)
end

local function closeUI()
    if not opened or busy then return end
    busy, opened = true, false
    lastPos = win.Position
    tw(win, { Position = icon.Position }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tw(scale, { Scale = 0.05 }, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    play("close")
    task.delay(0.28, function() icon.Visible = true; iscale.Scale = 0; tw(iscale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back) end)
    task.delay(0.42, function() win.Visible, busy = false, false end)
end

minBtn.MouseButton1Click:Connect(closeUI)

-- drag (window by top bar, icon by body; a tap on the icon opens)
local function drag(handle, target, onTap)
    local down, from, startPos, moved, track
    local function isPtr(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
    C(handle.InputBegan, function(i)
        if isPtr(i) then down, from, startPos, moved, track = true, i.Position, target.Position, false, i end
    end)
    C(UIS.InputChanged, function(i)
        if down and (i.UserInputType == Enum.UserInputType.MouseMovement or (i.UserInputType == Enum.UserInputType.Touch and i == track)) then
            local d = i.Position - from
            if d.Magnitude > 5 then moved = true end
            if moved then target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
        end
    end)
    C(UIS.InputEnded, function(i)
        if down and isPtr(i) and (i.UserInputType ~= Enum.UserInputType.Touch or i == track) then
            down = false
            if not moved and onTap then onTap() end
        end
    end)
end
drag(top, win)
drag(icon, icon, openUI)

C(UIS.InputBegan, function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.Insert then
        if opened then closeUI() else openUI() end
    end
end)

-- animation loop: rotating border, icon glow, rain
C(RunService.Heartbeat, function(dt)
    local t = os.clock()
    igrad.Rotation = (t * 90) % 360
    if win.Visible then
        sgrad.Rotation = (t * 45) % 360
        for _, d in ipairs(drops) do
            d.y = d.y + d.v * dt
            if d.y > 380 then d.y, d.x = -40, math.random(0, 580) end
            d.f.Position = U2(d.x, d.y)
        end
    end
end)

task.spawn(function()
    while running do
        status.Text = (hitToken and "token ok" or "hit a mob once") .. "  |  quest: " .. (questState == nil and "?" or questState and "on" or "off")
        task.wait(0.5)
    end
end)

setTab("FARM", true)
win.Visible = true
tw(scale, { Scale = baseScale }, 0.6, Enum.EasingStyle.Back)
play("open")
task.delay(0.6, function() opened = true end)

env.ZipHub = {
    stop = function()
        running = false
        cancelTween()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for _, s in pairs(sounds) do pcall(function() s:Destroy() end) end
        pcall(function() gui:Destroy() end)
        pcall(function()
            for _, m in ipairs(enemyList()) do tag(m, nil, false) end
            for _, p in ipairs(Players:GetPlayers()) do if p.Character then tag(p.Character, nil, false) end end
        end)
        env.ZipHub = nil
    end,
}
