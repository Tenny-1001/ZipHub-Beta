local P=game:GetService("Players")local T=game:GetService("TweenService")local U=game:GetService("UserInputService")local R=game:GetService("RunService")local H=game:GetService("HttpService")local TP=game:GetService("TeleportService")local C=game:GetService("CollectionService")local L=game:GetService("Lighting")local CG=game:GetService("CoreGui")local LP=P.LocalPlayer local G=(getgenv and getgenv())or _G
repeat task.wait(0.25)until game:IsLoaded()and LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")and LP.Character:FindFirstChildOfClass("Humanoid")and LP.Character.Humanoid.Health>0
print("[ZIP HUB] Environment ready — starting logic.")
if G.ZipHubUnload then pcall(G.ZipHubUnload)end
local RT={"Rare","Epic","Legendary","Mythic","Secret"}local HA=30
local RC={common=Color3.fromRGB(190,190,200),uncommon=Color3.fromRGB(90,220,120),rare=Color3.fromRGB(70,140,255),epic=Color3.fromRGB(170,90,255),legendary=Color3.fromRGB(255,170,40),mythic=Color3.fromRGB(255,70,120),secret=Color3.fromRGB(0,234,255),divine=Color3.fromRGB(255,255,255)}
local DF={AutoSteal=false,AutoHop=false,TweenSpeed=0.3,StealFromPlayers=false,MinValue=0,AutoFarmBase=false,AutoUFO=false,AutoMeteor=false,AutoMinigame=false,ESPEggs=false,ShowNames=false,HideOthers=false,LowGraphics=false,Noclip=false,AntiAFK=false,WalkSpeed=16,WebhookURL=""}
local CK={}for k in pairs(DF)do table.insert(CK,k)end local CF="ZipHub"local CFI="ZipHub/config_beta.json"
for k,v in pairs(DF)do if G[k]==nil then G[k]=v end end
G.LastEggSeen=os.clock()G.LastStealTime=0 G.CurrentlyStealing=nil G.CurrentlyStealingValue=nil G.CancelCurrentSteal=false
local function lc()if not(readfile and isfile)then return end local ok,d=pcall(function()if isfile(CFI)then return H:JSONDecode(readfile(CFI))end end)if ok and type(d)=="table"then for _,k in ipairs(CK)do if d[k]~=nil and type(d[k])==type(DF[k])then G[k]=d[k]end end end end
local function sc()if not writefile then return false end local d={}for _,k in ipairs(CK)do d[k]=G[k]end return pcall(function()if makefolder and isfolder and not isfolder(CF)then makefolder(CF)end writefile(CFI,H:JSONEncode(d))end)end
lc()
local TH={Glass=Color3.fromRGB(15,15,25),GlassTransparency=0.25,Row=Color3.fromRGB(22,22,36),Cyan=Color3.fromRGB(0,234,255),Blue=Color3.fromRGB(60,120,255),Purple=Color3.fromRGB(160,90,255),Text=Color3.fromRGB(238,240,255),TextDim=Color3.fromRGB(150,156,185),Off=Color3.fromRGB(46,46,66),Danger=Color3.fromRGB(255,80,110),Success=Color3.fromRGB(80,255,170)}
local NS=ColorSequence.new({ColorSequenceKeypoint.new(0,TH.Cyan),ColorSequenceKeypoint.new(0.5,TH.Purple),ColorSequenceKeypoint.new(1,TH.Cyan)})
local alive=true local conns={}
local function cn(s,cb)local c=s:Connect(cb)table.insert(conns,c)return c end
local function lp(d,fn)task.spawn(function()while alive do task.wait(d)if alive then pcall(fn)end end end)end
local function mk(cls,props,kids)local i=Instance.new(cls)local par for p,v in pairs(props or{})do if p=="Parent"then par=v else i[p]=v end end for _,c in ipairs(kids or{})do c.Parent=i end if par then i.Parent=par end return i end
local function cr(r)return mk("UICorner",{CornerRadius=UDim.new(0,r)})end
local function stk(cl,t,tr)return mk("UIStroke",{Color=cl,Thickness=t or 1,Transparency=tr or 0.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})end
local function ns(par,t,tr,sec)local s=mk("UIStroke",{Color=Color3.new(1,1,1),Thickness=t,Transparency=tr,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=par})local g=mk("UIGradient",{Color=NS,Parent=s})T:Create(g,TweenInfo.new(sec or 6,Enum.EasingStyle.Linear,Enum.EasingDirection.In,-1),{Rotation=360}):Play()return s end
local function tw(i,d,p,st,dr)local t=T:Create(i,TweenInfo.new(d,st or Enum.EasingStyle.Quint,dr or Enum.EasingDirection.Out),p)t:Play()return t end
local function no(c)local n=(c:GetAttribute("Order")or 0)+1 c:SetAttribute("Order",n)return n end
local function gp()if gethui then local ok,r=pcall(gethui)if ok and r then return r end end local ok=pcall(function()return CG.Name end)if ok then return CG end return LP:WaitForChild("PlayerGui")end
local function fv(v)v=tonumber(v)or 0 if v>=1e9 then return string.format("%.2fB",v/1e9)elseif v>=1e6 then return string.format("%.2fM",v/1e6)elseif v>=1e3 then return string.format("%.2fK",v/1e3)end return tostring(math.floor(v))end
local function pn(t)local s=string.lower((string.gsub(t,"[,%s]","")))local n,sf=string.match(s,"^([%d%.]+)([kmb]?)$")n=tonumber(n)if not n then return 0 end local m=({k=1e3,m=1e6,b=1e9})[sf]or 1 return n*m endlocal ob=L:FindFirstChild("ZipHubBlur")if ob then ob:Destroy()end local BL=mk("BlurEffect",{Name="ZipHubBlur",Size=0,Parent=L})
local GUI=mk("ScreenGui",{Name="ZipHub",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999})
if syn and syn.protect_gui then pcall(syn.protect_gui,GUI)end
local cam=workspace.CurrentCamera local vp=cam and cam.ViewportSize or Vector2.new(1280,720)
local W=math.clamp(vp.X*0.9,400,600)local HH=math.clamp(vp.Y*0.85,310,400)local MG=26 local RD=16
local ROOT=mk("CanvasGroup",{Name="Root",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(W+MG*2,HH+MG*2),BackgroundTransparency=1,BorderSizePixel=0,GroupTransparency=1,Visible=false,Parent=GUI})
local RS=mk("UIScale",{Scale=0.82,Parent=ROOT})
local function gl(g,t,tr,r)local f=mk("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(W+g,HH+g),BackgroundTransparency=1,BorderSizePixel=0,Parent=ROOT},{cr(r)})ns(f,t,tr,8)return f end
gl(22,14,0.94,RD+11)gl(14,9,0.9,RD+7)gl(8,5,0.8,RD+4)
local MA=mk("CanvasGroup",{Name="Main",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(W,HH),BackgroundColor3=TH.Glass,BackgroundTransparency=TH.GlassTransparency,BorderSizePixel=0,Parent=ROOT},{cr(RD)})
local function orb(c,s,p,g,sec)local o=mk("Frame",{Size=UDim2.fromOffset(s,s),Position=p,BackgroundColor3=c,BackgroundTransparency=0.86,BorderSizePixel=0,Parent=MA},{cr(s)})T:Create(o,TweenInfo.new(sec,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=g}):Play()return o end
orb(TH.Cyan,240,UDim2.fromOffset(-90,-90),UDim2.fromOffset(-30,-40),7)orb(TH.Purple,280,UDim2.new(1,-170,1,-170),UDim2.new(1,-230,1,-210),9)orb(TH.Blue,160,UDim2.new(0.45,0,0.1,0),UDim2.new(0.3,0,0.35,0),11)
local SH=mk("Frame",{Name="Sheen",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Parent=MA})
mk("UIGradient",{Rotation=40,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.84),NumberSequenceKeypoint.new(0.45,0.96),NumberSequenceKeypoint.new(1,0.985)}),Parent=SH})
local BR=mk("Frame",{Name="Border",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(W,HH),BackgroundTransparency=1,BorderSizePixel=0,Parent=ROOT},{cr(RD)})ns(BR,1.8,0.05,5)
local TB=mk("Frame",{Name="TopBar",Size=UDim2.new(1,0,0,52),BackgroundTransparency=1,Active=true,Parent=MA})
local TG=mk("TextLabel",{Name="TitleGlow",Position=UDim2.fromOffset(20,0),Size=UDim2.new(0,320,1,0),BackgroundTransparency=1,Text="⚡ ZIP HUB [BETA]",Font=Enum.Font.GothamBlack,TextSize=22,TextColor3=TH.Cyan,TextTransparency=0.3,TextXAlignment=Enum.TextXAlignment.Left,Parent=TB})
local GS=mk("UIStroke",{Color=TH.Cyan,Thickness=4,Transparency=0.4,LineJoinMode=Enum.LineJoinMode.Round,Parent=TG})
local TT=mk("TextLabel",{Name="Title",Position=UDim2.fromOffset(20,0),Size=UDim2.new(0,320,1,0),BackgroundTransparency=1,Text="⚡ ZIP HUB [BETA]",Font=Enum.Font.GothamBlack,TextSize=22,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left,Parent=TB})
local TGR=mk("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(170,255,255)),ColorSequenceKeypoint.new(0.5,TH.Cyan),ColorSequenceKeypoint.new(1,Color3.fromRGB(200,150,255))}),Parent=TT})
local PI=TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true)
T:Create(GS,PI,{Transparency=0.92}):Play()T:Create(TG,PI,{TextTransparency=0.85}):Play()T:Create(TGR,TweenInfo.new(4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Offset=Vector2.new(0.25,0)}):Play()
local function wb(t,x,hc)local b=mk("TextButton",{Size=UDim2.fromOffset(30,30),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,x,0.5,0),BackgroundColor3=TH.Row,BackgroundTransparency=0.35,AutoButtonColor=false,Text=t,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=TH.TextDim,Parent=TB},{cr(9)})local s=stk(hc,1,1)s.Parent=b local sc=mk("UIScale",{Scale=1,Parent=b})cn(b.MouseEnter,function()tw(b,0.2,{BackgroundColor3=hc,BackgroundTransparency=0.15,TextColor3=Color3.new(1,1,1)})tw(s,0.2,{Transparency=0.2})tw(sc,0.2,{Scale=1.1})end)cn(b.MouseLeave,function()tw(b,0.2,{BackgroundColor3=TH.Row,BackgroundTransparency=0.35,TextColor3=TH.TextDim})tw(s,0.2,{Transparency=1})tw(sc,0.2,{Scale=1})end)cn(b.MouseButton1Down,function()tw(sc,0.1,{Scale=0.92})end)return b end
local CB=wb("✕",-14,TH.Danger)local MB=wb("—",-50,TH.Blue)
local DV=mk("Frame",{Name="Divider",Position=UDim2.new(0,14,0,52),Size=UDim2.new(1,-28,0,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Parent=MA})
local DVG=mk("UIGradient",{Color=NS,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.1),NumberSequenceKeypoint.new(1,1)}),Offset=Vector2.new(-0.6,0),Parent=DV})
T:Create(DVG,TweenInfo.new(3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Offset=Vector2.new(0.6,0)}):Play()
local SB=mk("Frame",{Name="Sidebar",Position=UDim2.fromOffset(12,62),Size=UDim2.new(0,138,1,-74),BackgroundColor3=Color3.fromRGB(10,10,18),BackgroundTransparency=0.4,BorderSizePixel=0,Parent=MA},{cr(12),stk(TH.Purple,1,0.75)})
local TL=mk("Frame",{Name="TabList",Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-46),BackgroundTransparency=1,Parent=SB},{mk("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})})
mk("TextLabel",{Name="PlayerTag",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,12,1,-8),Size=UDim2.new(1,-24,0,22),BackgroundTransparency=1,Text="● "..LP.DisplayName,Font=Enum.Font.Gotham,TextSize=12,TextColor3=TH.TextDim,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=SB})
local CT=mk("Frame",{Name="Content",Position=UDim2.fromOffset(160,62),Size=UDim2.new(1,-172,1,-92),BackgroundTransparency=1,ClipsDescendants=true,Parent=MA})
mk("TextLabel",{Name="Watermark",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-7),Size=UDim2.fromOffset(180,16),BackgroundTransparency=1,Text="ZIP HUB BETA v1.1",Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=Color3.new(1,1,1),TextTransparency=0.65,TextXAlignment=Enum.TextXAlignment.Right,Parent=MA})
local tabs={}local AT local selTab
local function mkTab(n,ic)local b=mk("TextButton",{Name=n,Size=UDim2.new(1,0,0,38),BackgroundColor3=TH.Purple,BackgroundTransparency=1,AutoButtonColor=false,Text="",LayoutOrder=no(TL),Parent=TL},{cr(9)})
mk("TextLabel",{Position=UDim2.fromOffset(14,0),Size=UDim2.fromOffset(22,38),BackgroundTransparency=1,Text=ic,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=TH.Text,Parent=b})
local lb=mk("TextLabel",{Position=UDim2.fromOffset(38,0),Size=UDim2.new(1,-38,1,0),BackgroundTransparency=1,Text=n,Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=TH.TextDim,TextXAlignment=Enum.TextXAlignment.Left,Parent=b})
local ba=mk("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,3,0.5,0),Size=UDim2.new(0,3,0,0),BackgroundColor3=TH.Cyan,BorderSizePixel=0,Parent=b},{cr(2)})
local pg=mk("ScrollingFrame",{Name=n.."Page",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=TH.Purple,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false,Parent=CT},{mk("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder}),mk("UIPadding",{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,6)})})
tabs[n]={Button=b,Label=lb,Bar=ba,Page=pg}cn(b.MouseButton1Click,function()selTab(n)end)cn(b.MouseEnter,function()if AT~=n then tw(b,0.2,{BackgroundTransparency=0.88})tw(lb,0.2,{TextColor3=TH.Text})end end)cn(b.MouseLeave,function()if AT~=n then tw(b,0.2,{BackgroundTransparency=1})tw(lb,0.2,{TextColor3=TH.TextDim})end end)return pg end
selTab=function(n)local pv=AT AT=n for tn,tb in pairs(tabs)do local a=tn==n tb.Page.Visible=a tw(tb.Button,0.3,{BackgroundTransparency=a and 0.72 or 1})tw(tb.Label,0.3,{TextColor3=a and Color3.new(1,1,1)or TH.TextDim})tw(tb.Bar,0.3,{Size=UDim2.new(0,3,a and 0.55 or 0,0)})if a and pv~=n then tb.Page.Position=UDim2.fromOffset(0,16)tw(tb.Page,0.4,{Position=UDim2.fromOffset(0,0)})end end endlocal function rf(pg,h)local r=mk("Frame",{Size=UDim2.new(1,0,0,h),BackgroundColor3=TH.Row,BackgroundTransparency=0.4,BorderSizePixel=0,LayoutOrder=no(pg),Parent=pg},{cr(11)})local rs=stk(TH.Purple,1,0.78)rs.Parent=r return r,rs end
local function hr(tg,r,rs)cn(tg.MouseEnter,function()tw(r,0.2,{BackgroundTransparency=0.25})tw(rs,0.2,{Color=TH.Cyan,Transparency=0.45})end)cn(tg.MouseLeave,function()tw(r,0.2,{BackgroundTransparency=0.4})tw(rs,0.2,{Color=TH.Purple,Transparency=0.78})end)end
local function as(pg,t)mk("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text=string.upper(t),Font=Enum.Font.GothamBold,TextSize=11,TextColor3=TH.Purple,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=no(pg),Parent=pg},{mk("UIPadding",{PaddingLeft=UDim.new(0,4)})})end
local function al(pg,t)mk("TextLabel",{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,Text=t,Font=Enum.Font.Gotham,TextSize=12,TextColor3=TH.TextDim,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=no(pg),Parent=pg},{mk("UIPadding",{PaddingLeft=UDim.new(0,4)})})end
local function at(pg,t,k,cb)local s=G[k]and true or false local r,rs=rf(pg,44)mk("TextLabel",{Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-80,1,0),BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=TH.Text,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=r})
local tr=mk("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(44,24),BackgroundColor3=TH.Off,BorderSizePixel=0,Parent=r},{cr(12)})local ts=stk(TH.Cyan,1.2,1)ts.Parent=tr
local kn=mk("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,3,0.5,0),Size=UDim2.fromOffset(18,18),BackgroundColor3=Color3.fromRGB(200,204,225),BorderSizePixel=0,Parent=tr},{cr(9)})
local function rr(an)local d=an and 0.28 or 0 tw(tr,d,{BackgroundColor3=s and TH.Purple or TH.Off})tw(ts,d,{Transparency=s and 0.1 or 1})tw(kn,d,{Position=s and UDim2.new(1,-21,0.5,0)or UDim2.new(0,3,0.5,0),BackgroundColor3=s and Color3.new(1,1,1)or Color3.fromRGB(200,204,225)},Enum.EasingStyle.Back)end
rr(false)local ht=mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",Parent=r})cn(ht.MouseButton1Click,function()s=not s G[k]=s rr(true)if cb then task.spawn(cb,s)end end)hr(ht,r,rs)end
local function asl(pg,t,k,mn,mx,st,sf,dc,cb)local v=math.clamp(tonumber(G[k])or mn,mn,mx)local r,rs=rf(pg,62)
mk("TextLabel",{Position=UDim2.fromOffset(14,7),Size=UDim2.new(1,-100,0,22),BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=TH.Text,TextXAlignment=Enum.TextXAlignment.Left,Parent=r})
local vl=mk("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,7),Size=UDim2.fromOffset(80,22),BackgroundTransparency=1,Text="",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=TH.Cyan,TextXAlignment=Enum.TextXAlignment.Right,Parent=r})
local tr=mk("Frame",{Position=UDim2.new(0,14,0,42),Size=UDim2.new(1,-28,0,6),BackgroundColor3=TH.Off,BorderSizePixel=0,Parent=r},{cr(3)})
local fl=mk("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Parent=tr},{cr(3),mk("UIGradient",{Color=ColorSequence.new(TH.Cyan,TH.Purple)})})
local kn=mk("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),Size=UDim2.fromOffset(15,15),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=2,Parent=tr},{cr(8)})local ks=stk(TH.Cyan,2,0.05)ks.Parent=kn
local function rr()local a=(v-mn)/(mx-mn)fl.Size=UDim2.fromScale(a,1)kn.Position=UDim2.fromScale(a,0.5)vl.Text=string.format("%."..(dc or 0).."f%s",v,sf or"")end
local function ap(x)local a=math.clamp((x-tr.AbsolutePosition.X)/math.max(tr.AbsoluteSize.X,1),0,1)local rw=mn+(mx-mn)*a local sn=math.clamp(math.floor(rw/st+0.5)*st,mn,mx)sn=tonumber(string.format("%."..(dc or 0).."f",sn))if sn~=v then v=sn G[k]=v rr()if cb then task.spawn(cb,v)end end end
G[k]=v rr()local ht=mk("TextButton",{Position=UDim2.new(0,8,0,32),Size=UDim2.new(1,-16,0,26),BackgroundTransparency=1,Text="",Parent=r})
local dg=false cn(ht.InputBegan,function(inp)if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dg=true tw(kn,0.15,{Size=UDim2.fromOffset(20,20)})ap(inp.Position.X)end end)
cn(U.InputChanged,function(inp)if dg and(inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch)then ap(inp.Position.X)end end)
cn(U.InputEnded,function(inp)if dg and(inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch)then dg=false tw(kn,0.15,{Size=UDim2.fromOffset(15,15)})end end)hr(ht,r,rs)end
local function atb(pg,t,k,ph,op)op=op or{}local r=rf(pg,84)
mk("TextLabel",{Position=UDim2.fromOffset(14,7),Size=UDim2.new(1,-110,0,22),BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=TH.Text,TextXAlignment=Enum.TextXAlignment.Left,Parent=r})
local stt=mk("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,7),Size=UDim2.fromOffset(90,22),BackgroundTransparency=1,Text="Applied ✓",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=TH.Success,TextTransparency=1,TextXAlignment=Enum.TextXAlignment.Right,Parent=r})
local function fm(v)if op.format then return op.format(v)end return tostring(v or"")end
local bx=mk("TextBox",{Position=UDim2.new(0,14,0,38),Size=UDim2.new(1,-28,0,36),BackgroundColor3=Color3.fromRGB(8,8,16),BackgroundTransparency=0.25,BorderSizePixel=0,ClearTextOnFocus=false,ClipsDescendants=true,Text=fm(G[k]),PlaceholderText=ph or"",PlaceholderColor3=Color3.fromRGB(100,104,134),Font=Enum.Font.Gotham,TextSize=13,TextColor3=TH.Text,TextXAlignment=Enum.TextXAlignment.Left,Parent=r},{cr(9),mk("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})})
local bs=stk(TH.Purple,1.2,0.55)bs.Parent=bx
local function cm()local cl=string.gsub(bx.Text,"^%s*(.-)%s*$","%1")local v=op.parse and op.parse(cl)or cl G[k]=v bx.Text=fm(v)return v end
local fc=false cn(bx.MouseEnter,function()if not fc then tw(bs,0.2,{Transparency=0.25})end end)cn(bx.MouseLeave,function()if not fc then tw(bs,0.2,{Transparency=0.55})end end)
cn(bx.Focused,function()fc=true tw(bs,0.25,{Color=TH.Cyan,Transparency=0,Thickness=1.8})end)
cn(bx.FocusLost,function()fc=false local v=cm()tw(bs,0.25,{Color=TH.Purple,Transparency=0.55,Thickness=1.2})stt.TextTransparency=0 tw(stt,1.2,{TextTransparency=1},Enum.EasingStyle.Quad,Enum.EasingDirection.In)if op.callback then task.spawn(op.callback,v)end end)
return bx,cm end
local function abt(pg,t,cb)local b=mk("TextButton",{Size=UDim2.new(1,0,0,44),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.3,BorderSizePixel=0,AutoButtonColor=false,Text="",LayoutOrder=no(pg),Parent=pg},{cr(11),mk("UIGradient",{Color=ColorSequence.new(TH.Cyan,TH.Purple)})})
local bs=stk(Color3.new(1,1,1),1.2,0.7)bs.Parent=b local sc=mk("UIScale",{Scale=1,Parent=b})
local lb=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),Parent=b})
cn(b.MouseEnter,function()tw(b,0.2,{BackgroundTransparency=0.05})tw(bs,0.2,{Transparency=0.2})tw(sc,0.2,{Scale=1.02})end)cn(b.MouseLeave,function()tw(b,0.2,{BackgroundTransparency=0.3})tw(bs,0.2,{Transparency=0.7})tw(sc,0.2,{Scale=1})end)
cn(b.MouseButton1Down,function()tw(sc,0.08,{Scale=0.97})end)cn(b.MouseButton1Up,function()tw(sc,0.15,{Scale=1.02})end)cn(b.MouseButton1Click,function()if cb then task.spawn(cb,lb)end end)return b,lb end
local AST=mkTab("Auto Steal","🎯")local VST=mkTab("Visuals","👁")local PST=mkTab("Player","🏃")local SST=mkTab("Settings","⚙")
as(AST,"Automation")at(AST,"Auto Steal (Rare Only)","AutoSteal")at(AST,"Auto Hop (Server Hop)","AutoHop",function(on)if on then G.LastEggSeen=os.clock()end end)asl(AST,"Speed","TweenSpeed",0.1,1,0.05,"s",2)as(AST,"Targeting")at(AST,"Steal From Players","StealFromPlayers")
atb(AST,"Min Value (0 = any, e.g. 5k, 2m)","MinValue","0",{parse=pn,format=function(v)return string.format("%.0f",tonumber(v)or 0)end})
as(AST,"Events")at(AST,"Auto Farm Base","AutoFarmBase")at(AST,"Auto UFO","AutoUFO")at(AST,"Auto Meteor","AutoMeteor")at(AST,"Auto Minigame","AutoMinigame")
as(VST,"ESP")at(VST,"ESP Eggs (Highlight rare targets)","ESPEggs")at(VST,"Show Names","ShowNames")as(VST,"Performance")at(VST,"Hide Others","HideOthers")at(VST,"Low Graphics","LowGraphics")
as(PST,"Movement")at(PST,"Noclip","Noclip")at(PST,"Anti-AFK","AntiAFK")asl(PST,"WalkSpeed","WalkSpeed",16,200,1,"",0)
as(SST,"Webhook")local _,cw=atb(SST,"Discord Webhook URL","WebhookURL","https://discord.com/api/webhooks/...")as(SST,"Config")
local srt abt(SST,"💾  Save Config",function(lb)cw()local ok=sc()if srt then task.cancel(srt)end if ok then lb.Text="✔  Config Saved"tw(lb,0.2,{TextColor3=TH.Success})else lb.Text="⚠  File access unavailable"tw(lb,0.2,{TextColor3=Color3.fromRGB(255,200,120)})end srt=task.delay(1.8,function()lb.Text="💾  Save Config"tw(lb,0.3,{TextColor3=Color3.new(1,1,1)})end)end)
as(SST,"Interface")al(SST,"Press RightShift or tap the ⚡ button to show / hide ZIP HUB.")
selTab("Auto Steal")
local LN=mk("TextButton",{Name="Launcher",AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,16,0.5,0),Size=UDim2.fromOffset(48,48),BackgroundColor3=TH.Glass,BackgroundTransparency=1,AutoButtonColor=false,Text="⚡",Font=Enum.Font.GothamBlack,TextSize=24,TextColor3=TH.Cyan,TextTransparency=1,Visible=false,Parent=GUI},{cr(24)})
local LS=ns(LN,2,1,4)local LSC=mk("UIScale",{Scale=1,Parent=LN})cn(LN.MouseEnter,function()tw(LSC,0.2,{Scale=1.12})end)cn(LN.MouseLeave,function()tw(LSC,0.2,{Scale=1})end)
local SC=0
local HD=mk("Frame",{Name="HUD",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,18),Size=UDim2.fromOffset(250,112),BackgroundTransparency=1,Visible=false,Parent=GUI},{cr(12)})local HS=ns(HD,1.5,1,5)
local HG=mk("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundColor3=TH.Glass,BackgroundTransparency=TH.GlassTransparency,BorderSizePixel=0,GroupTransparency=1,Parent=HD},{cr(12)})
mk("TextLabel",{Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-24,0,20),BackgroundTransparency=1,Text="⚡ ZIP HUB [BETA]",Font=Enum.Font.GothamBlack,TextSize=13,TextColor3=TH.Cyan,TextXAlignment=Enum.TextXAlignment.Left,Parent=HG})
local HC=mk("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,6),Size=UDim2.fromOffset(90,20),BackgroundTransparency=1,Text="Stolen: 0",Font=Enum.Font.GothamBold,TextSize=11,TextColor3=TH.TextDim,TextXAlignment=Enum.TextXAlignment.Right,Parent=HG})
local HSX=mk("TextLabel",{Position=UDim2.fromOffset(12,28),Size=UDim2.new(1,-24,0,44),BackgroundTransparency=1,Text="Waiting for target...",Font=Enum.Font.Gotham,TextSize=12,TextColor3=TH.TextDim,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=HG})
local CNB=mk("TextButton",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,12,1,-10),Size=UDim2.new(1,-24,0,26),BackgroundColor3=TH.Danger,BackgroundTransparency=0.25,BorderSizePixel=0,AutoButtonColor=false,Text="CANCEL STEAL",Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.new(1,1,1),Visible=false,Parent=HG},{cr(8)})
local CS=mk("UIScale",{Scale=1,Parent=CNB})cn(CNB.MouseEnter,function()tw(CNB,0.2,{BackgroundTransparency=0.02})tw(CS,0.2,{Scale=1.03})end)cn(CNB.MouseLeave,function()tw(CNB,0.2,{BackgroundTransparency=0.25})tw(CS,0.2,{Scale=1})end)cn(CNB.MouseButton1Click,function()if G.CurrentlyStealing then G.CancelCurrentSteal=true end end)
local hsd=false
local function sHS(s)if s==hsd then return end hsd=s if s then HD.Visible=true tw(HG,0.35,{GroupTransparency=0})tw(HS,0.35,{Transparency=0.2})else tw(HG,0.3,{GroupTransparency=1})tw(HS,0.3,{Transparency=1})task.delay(0.32,function()if not hsd then HD.Visible=false end end)end end
local iso=false
local function sOP(s)iso=s if s then ROOT.Visible=true tw(ROOT,0.4,{GroupTransparency=0})tw(RS,0.5,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)tw(BL,0.45,{Size=24})tw(LN,0.2,{BackgroundTransparency=1,TextTransparency=1})tw(LS,0.2,{Transparency=1})task.delay(0.2,function()if iso then LN.Visible=false end end)else tw(ROOT,0.3,{GroupTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.In)tw(RS,0.3,{Scale=0.82},Enum.EasingStyle.Quint,Enum.EasingDirection.In)tw(BL,0.3,{Size=0})LN.Visible=true tw(LN,0.3,{BackgroundTransparency=0.3,TextTransparency=0})tw(LS,0.3,{Transparency=0.15})task.delay(0.32,function()if not iso then ROOT.Visible=false end end)end end
cn(LN.MouseButton1Click,function()sOP(true)end)cn(MB.MouseButton1Click,function()sOP(false)end)
cn(CB.MouseButton1Click,function()sOP(false)task.delay(0.35,function()if G.ZipHubUnload then G.ZipHubUnload()end end)end)
cn(U.InputBegan,function(inp,pr)if pr then return end if inp.KeyCode==Enum.KeyCode.RightShift then sOP(not iso)end end)
local drg,ds,sp=false,nil,nil
cn(TB.InputBegan,function(inp)if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then drg=true ds=inp.Position sp=ROOT.Position end end)
cn(U.InputChanged,function(inp)if drg and(inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch)then local dl=inp.Position-ds local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)local x=math.clamp(sp.X.Offset+dl.X,-v.X/2+80,v.X/2-80)local y=math.clamp(sp.Y.Offset+dl.Y,-v.Y/2+50,v.Y/2-50)tw(ROOT,0.08,{Position=UDim2.new(sp.X.Scale,x,sp.Y.Scale,y)},Enum.EasingStyle.Sine)end end)
cn(U.InputEnded,function(inp)if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then drg=false end end)local function gC()local c=LP.Character if not c or not c.Parent then return nil end return c end
local function gH()local c=gC()return c and c:FindFirstChild("HumanoidRootPart")end
local function gHm()local c=gC()return c and c:FindFirstChildOfClass("Humanoid")end
local function gV(e)return e:GetAttribute("Value")or e:GetAttribute("Price")or e:GetAttribute("ValuePerSecond")or e:GetAttribute("Income")or 0 end
local function gRn(e)local r=e:GetAttribute("Rarity")or e:GetAttribute("rarity")return r and tostring(r)or nil end
local function mR(e)local r=gRn(e)if not r then return true end local f=G.RarityFilter or RT r=string.lower(r)if type(f)=="table"then for _,v in ipairs(f)do if string.lower(tostring(v))==r then return true end end return false end return string.lower(tostring(f))==r end
local function gO(e)return e:GetAttribute("Owner")or e:GetAttribute("OwnerName")or e:GetAttribute("User")end
local function gRt(e)if e:IsA("BasePart")then return e end return e.PrimaryPart or e:FindFirstChild("HumanoidRootPart")or e:FindFirstChildWhichIsA("BasePart")end
local function fP(p)if not p then return false end local ok=pcall(function()fireproximityprompt(p)end)if ok then return true end ok=pcall(function()p:InputHoldBegin()task.wait(p.HoldDuration or 0)p:InputHoldEnd()end)return ok end
local hR=(syn and syn.request)or(http and http.request)or http_request or request or(fluxus and fluxus.request)local lH=0
local function sWh(t,d,c)local u=tostring(G.WebhookURL or"")if not(string.match(u,"^https://[%w%.]*discord%.com/api/webhooks/")or string.match(u,"^https://[%w%.]*discordapp%.com/api/webhooks/"))then return end if not hR then return end task.spawn(function()local wt=1.5-(os.clock()-lH)if wt>0 then task.wait(wt)end lH=os.clock()pcall(function()hR({Url=u,Method="POST",Headers={["Content-Type"]="application/json"},Body=H:JSONEncode({username="ZIP HUB [BETA]",embeds={{title=t,description=d,color=c or 52479,footer={text="ZIP HUB BETA v1.1 • "..LP.Name}}}})})end)end)end
local bC={list=nil,time=0}
local function bS()local n=os.clock()if bC.list and n-bC.time<2 then return bC.list end local o={}for _,d in ipairs(workspace:GetDescendants())do if d and d.Parent and(d:IsA("Model")or d:IsA("BasePart"))then local nm=string.lower(d.Name)local iE=string.find(nm,"egg",1,true)~=nil or string.find(nm,"brainrot",1,true)~=nil local hV=(tonumber(d:GetAttribute("Value"))or 0)>0 or(tonumber(d:GetAttribute("Price"))or 0)>0 or(tonumber(d:GetAttribute("Income"))or 0)>0 if iE or hV then o[#o+1]=d end end end bC.list=o bC.time=n return o end
local function sT(i,p,mn,mv,ro)local o=gO(i)if ro then if not o or o==mn then return nil end elseif o==mn then return nil end local r=gRt(i)if not r then return nil end local v=tonumber(gV(i))or 0 if v<mv or not mR(i)then return nil end return v/((r.Position-p).Magnitude+1)end
local function fb()local h=gH()if not h then return nil end local p,mn=h.Position,LP.Name local mv=tonumber(G.MinValue)or 0 local b,bs=nil,-math.huge
local function cs(i,ro)if not i or not i.Parent then return end local s=sT(i,p,mn,mv,ro)if s and s>bs then b,bs=i,s end end
local tg=C:GetTagged("Egg")if #tg>0 then for _,e in ipairs(tg)do cs(e,false)end else for _,o in ipairs(bS())do cs(o,false)end end
if G.StealFromPlayers then for _,pt in ipairs(C:GetTagged("Pet"))do cs(pt,true)end end return b end
local lHop=0
local function sHop()if os.clock()-lHop<15 then return end lHop=os.clock()sWh("🔄 Server Hop","No valid target for "..HA.."s — switching.",10181046)local ok=pcall(function()local rs=game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")local d=H:JSONDecode(rs)if d and d.data then for _,s in ipairs(d.data)do if s.id~=game.JobId and s.playing<s.maxPlayers then TP:TeleportToPlaceInstance(game.PlaceId,s.id,LP)return end end end end)if not ok then pcall(function()TP:Teleport(game.PlaceId,LP)end)end G.LastEggSeen=os.clock()end
local pFC={}
local function stE(e)local h=gH()local hm=gHm()if not h or not hm then return end local nw=os.clock()if pFC[e]and nw-pFC[e]<10 then return end local r=gRt(e)if not r then pFC[e]=nw return end local pr=e:FindFirstChildWhichIsA("ProximityPrompt",true)local cd=(not pr)and e:FindFirstChildWhichIsA("ClickDetector",true)if not pr and not cd then pFC[e]=nw return end print("[ZIP HUB] Found target:",e:GetFullName())
local inf=TweenInfo.new(math.clamp(tonumber(G.TweenSpeed)or 0.3,0.1,1),Enum.EasingStyle.Linear)local og=h.CFrame local tg=r.CFrame*CFrame.new(0,2,0)local nm,v,rr=e.Name,gV(e),gRn(e)G.CurrentlyStealing=nm G.CurrentlyStealingValue=fv(v)
local dd=false local dc pcall(function()dc=hm.Died:Connect(function()dd=true end)end)
local function fn(sc)if dc then pcall(function()dc:Disconnect()end)end if h and h.Parent then pcall(function()h.Anchored=false end)end G.CurrentlyStealing=nil G.CurrentlyStealingValue=nil G.CancelCurrentSteal=false if sc then G.LastStealTime=os.clock()SC+=1 sWh("🥚 Steal Complete",string.format("**%s**\nRarity: %s\nValue: %s",nm,rr or"?",fv(v)),5832555)end end
pcall(function()h.Anchored=true end)
local t1=T:Create(h,inf,{CFrame=tg})t1:Play()t1.Completed:Wait()
if dd or G.CancelCurrentSteal or not e.Parent or not h.Parent then if h and h.Parent then pcall(function()h.CFrame=og end)end fn(false)return end
local it=false if pr then it=fP(pr)task.wait((pr.HoldDuration or 0.5)+0.15)elseif cd then it=pcall(function()fireclickdetector(cd)end)task.wait(0.3)end
if dd or not h or not h.Parent then fn(false)return end
local t2=T:Create(h,inf,{CFrame=og})t2:Play()t2.Completed:Wait()fn(it)end
lp(0.2,function()if not(G.AutoSteal or G.AutoHop)then return end for e in pairs(pFC)do if not e.Parent then pFC[e]=nil end end local eg=fb()if eg then G.LastEggSeen=os.clock()if G.AutoSteal then stE(eg)end elseif G.AutoHop and os.clock()-(G.LastEggSeen or 0)>HA then sHop()end end)
local function fB(pat)local pg=LP:FindFirstChildOfClass("PlayerGui")if not pg then return nil end for _,d in ipairs(pg:GetDescendants())do if(d:IsA("TextButton")or d:IsA("ImageButton"))and not d:IsDescendantOf(GUI)then local lb=d:IsA("TextButton")and d.Text~=""and d.Text or d.Name lb=string.lower(lb)for _,p in ipairs(pat)do if string.find(lb,string.lower(p),1,true)then return d end end end end return nil end
local function ckB(b)if not b then return false end local ok=pcall(function()b:Activate()end)if not ok then pcall(function()b.MouseButton1Click:Fire()end)end return ok end
local FP={"upgrade","buy slot","purchase slot","unlock slot","claim","collect","daily","offline","index","reward"}
lp(3,function()if G.AutoFarmBase then ckB(fB(FP))ckB(fB({"mutate","mutation","enhance"}))end end)
local function sTop(pat)for _,o in ipairs(workspace:GetChildren())do local n=string.lower(o.Name)for _,p in ipairs(pat)do if string.find(n,string.lower(p),1,true)then return o end end end return nil end
local function tpC(t)local h=gH()if not h or not t then return end local r=t:IsA("BasePart")and t or t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")if not r then return end pcall(function()h.CFrame=r.CFrame+Vector3.new(0,3,0)end)pcall(function()local p=t:FindFirstChildWhichIsA("ProximityPrompt",true)if p then fP(p)end end)end
lp(2,function()if G.AutoUFO then local u=sTop({"ufo","debris","saucer"})if u then tpC(u)ckB(fB({"trade","sell"}))end end if G.AutoMeteor then local s=sTop({"star","meteor","falling"})if s then tpC(s)end end end)
lp(1,function()if not G.AutoMinigame then return end local f=sTop({"finish","safe zone","safe","goal","checkpoint"})if f then tpC(f)end local sig=sTop({"red light","green light","signal","traffic"})if sig then local rd=sig:GetAttribute("Red")or(sig:GetAttribute("State")=="Red")or(string.find(string.lower(sig.Name),"red")~=nil)if rd then local sf=sTop({"safe","cover","hiding"})if sf then tpC(sf)end end end end)
local LP2={"GlobalShadows","FogEnd","Brightness","EnvironmentDiffuseScale","EnvironmentSpecularScale","Ambient","OutdoorAmbient"}local WP={"WaterWaveSize","WaterWaveSpeed","WaterReflectance","WaterTransparency"}local EC={"BloomEffect","BlurEffect","DepthOfFieldEffect","SunRaysEffect","ColorCorrectionEffect"}local gB
local function iPE(v)if v==BL then return false end for _,c in ipairs(EC)do if v:IsA(c)then return true end end return false end
local function aLG()pcall(function()local tr=workspace.Terrain if not gB then gB={Lighting={},Effects={},Water={},SkyParent=nil}for _,p in ipairs(LP2)do gB.Lighting[p]=L[p]end for _,p in ipairs(WP)do gB.Water[p]=tr[p]end local sk=L:FindFirstChildOfClass("Sky")if sk then gB.SkyParent=sk.Parent sk.Parent=nil end end L.GlobalShadows=false L.FogEnd=100000 L.Brightness=1 L.EnvironmentDiffuseScale=0 L.EnvironmentSpecularScale=0 L.Ambient=Color3.fromRGB(128,128,128)L.OutdoorAmbient=Color3.fromRGB(128,128,128)tr.WaterWaveSize=0 tr.WaterWaveSpeed=0 tr.WaterReflectance=0 tr.WaterTransparency=1 for _,v in ipairs(L:GetChildren())do if iPE(v)then if gB.Effects[v]==nil then gB.Effects[v]=v.Enabled end v.Enabled=false end end end)end
local function rGR()if not gB then return end pcall(function()for p,v in pairs(gB.Lighting)do L[p]=v end for p,v in pairs(gB.Water)do workspace.Terrain[p]=v end for i,e in pairs(gB.Effects)do if i.Parent then i.Enabled=e end end end)gB=nil end
local lGF lp(0.5,function()local w=G.LowGraphics and true or false if w~=lGF then lGF=w if w then aLG()else rGR()end end end)
cn(LP.CharacterAdded,function()task.wait(0.5)if alive and G.LowGraphics then aLG()end end)
local hP={}
local function hI(i)local function hO(p)if(p:IsA("BasePart")or p:IsA("Decal")or p:IsA("Texture"))and hP[p]==nil then hP[p]=p.Transparency p.Transparency=1 end end hO(i)for _,d in ipairs(i:GetDescendants())do hO(d)end end
local function rH()for p,t in pairs(hP)do if p.Parent then p.Transparency=t end end table.clear(hP)end
lp(1,function()if G.HideOthers then for p in pairs(hP)do if not p.Parent then hP[p]=nil end end for _,pl in ipairs(P:GetPlayers())do if pl~=LP and pl.Character then hI(pl.Character)end end for _,pt in ipairs(C:GetTagged("Pet"))do local o=gO(pt)if o and o~=LP.Name then hI(pt)end end elseif next(hP)then rH()end end)
cn(LP.Idled,function()if G.AntiAFK then pcall(function()local VU=game:GetService("VirtualUser")VU:CaptureController()VU:ClickButton2(Vector2.new())end)end end)
lp(120,function()if G.AntiAFK then game:GetService("VirtualUser"):ClickButton1(Vector2.new())end end)
cn(R.Stepped,function()if not G.Noclip then return end local c=gC()if not c then return end for _,p in ipairs(c:GetDescendants())do if p:IsA("BasePart")and p.CanCollide then p.CanCollide=false end end end)
local bWS=16
cn(LP.CharacterAdded,function(ch)task.wait(0.3)local hm=ch:FindFirstChildOfClass("Humanoid")if hm then bWS=hm.WalkSpeed end end)
if LP.Character then local h0=LP.Character:FindFirstChildOfClass("Humanoid")if h0 then bWS=h0.WalkSpeed end end
local wE=false
lp(0.1,function()local hm=gHm()if not hm then return end local ws=tonumber(G.WalkSpeed)or bWS if ws~=bWS then wE=true if hm.WalkSpeed~=ws then hm.WalkSpeed=ws end elseif wE then wE=false hm.WalkSpeed=bWS end end)
local eO={}
local function rC(i)local r=gRn(i)return(r and RC[string.lower(r)])or Color3.new(1,1,1)end
local function cE(i)local o=eO[i]if o then if o.hl then o.hl:Destroy()end if o.bb then o.bb:Destroy()end eO[i]=nil end end
local function cAE()for i in pairs(eO)do cE(i)end end
local function uE(i,wh,wn)local o=eO[i]or{}eO[i]=o local cl=rC(i)if wh then if not o.hl then o.hl=mk("Highlight",{Name="ZipHubESP",Adornee=i,FillTransparency=0.6,OutlineTransparency=0,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,Parent=i})end o.hl.FillColor=cl o.hl.OutlineColor=cl elseif o.hl then o.hl:Destroy()o.hl=nil end if wn then local r=gRt(i)if r then if not o.bb then o.bb=mk("BillboardGui",{Name="ZipHubName",Adornee=r,AlwaysOnTop=true,Size=UDim2.fromOffset(170,36),StudsOffset=Vector3.new(0,3,0),Parent=r})o.label=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=13,TextStrokeTransparency=0.3,Parent=o.bb})end o.label.TextColor3=cl o.label.Text=string.format("%s\n%s • %s",tostring(i:GetAttribute("DisplayName")or i.Name),gRn(i)or"?",fv(gV(i)))end elseif o.bb then o.bb:Destroy()o.bb=nil o.label=nil end end
lp(0.75,function()if not(G.ESPEggs or G.ShowNames)then if next(eO)then cAE()end return end local sn={}local mn=LP.Name
local function cs(i,no)if not i.Parent then return end local o=gO(i)if o==mn or(no and not o)then return end sn[i]=true uE(i,G.ESPEggs and mR(i),G.ShowNames)end
for _,e in ipairs(C:GetTagged("Egg"))do cs(e,false)end if G.StealFromPlayers then for _,pt in ipairs(C:GetTagged("Pet"))do cs(pt,true)end end for i in pairs(eO)do if not sn[i]or not i.Parent then cE(i)end end end)
lp(0.25,function()local ac=G.AutoSteal or G.AutoHop sHS(ac and true or false)if not ac then return end HC.Text="Stolen: "..SC local nm=G.CurrentlyStealing if nm then HSX.TextColor3=Color3.fromRGB(255,215,130)HSX.Text="Stealing: "..tostring(nm).."\nValue: "..tostring(G.CurrentlyStealingValue)CNB.Visible=true else HSX.TextColor3=TH.TextDim CNB.Visible=false if G.AutoHop then local lf=math.max(0,math.ceil(HA-(os.clock()-(G.LastEggSeen or 0))))HSX.Text="Waiting for target...\nHop in "..lf.."s"else HSX.Text="Waiting for target..."end end end)
G.ZipHubUnload=function()alive=false for _,c in ipairs(conns)do pcall(function()c:Disconnect()end)end table.clear(conns)pcall(cAE)pcall(rH)pcall(rGR)if BL then BL:Destroy()end if GUI then GUI:Destroy()end G.ZipHubUnload=nil end
GUI.Parent=gp()sOP(true)print("[ZIP HUB] Loaded — v1.1 (mobile-safe).")