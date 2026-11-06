--[[
	⚡ ZIP HUB [BETA] v1.0 — UI + LOGIC (merged, fully bound)
	Every UI control writes to getgenv(); every logic loop reads from getgenv().
	Toggle UI: RightShift (or the ⚡ launcher button)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local genv = (getgenv and getgenv()) or _G

-- Unload any previous instance (stops its loops, restores the world)
if genv.ZipHubUnload then
	pcall(genv.ZipHubUnload)
end

---------------------------------------------------------------------
-- Settings the logic uses (edit to match your game)
---------------------------------------------------------------------
local RARE_TIERS = { "Rare", "Epic", "Legendary", "Mythic", "Secret" } -- "Rare Only" = these tiers
local HOP_AFTER = 30 -- seconds without a valid target before Auto Hop switches server

local RARITY_COLORS = {
	common = Color3.fromRGB(190, 190, 200),
	uncommon = Color3.fromRGB(90, 220, 120),
	rare = Color3.fromRGB(70, 140, 255),
	epic = Color3.fromRGB(170, 90, 255),
	legendary = Color3.fromRGB(255, 170, 40),
	mythic = Color3.fromRGB(255, 70, 120),
	secret = Color3.fromRGB(0, 234, 255),
	divine = Color3.fromRGB(255, 255, 255),
}

---------------------------------------------------------------------
-- Defaults + config persistence
---------------------------------------------------------------------
local DEFAULTS = {
	-- Auto Steal
	AutoSteal = false,
	AutoHop = false,
	TweenSpeed = 0.3,
	StealFromPlayers = false,
	MinValue = 0,
	AutoFarmBase = false,
	AutoUFO = false,
	AutoMeteor = false,
	AutoMinigame = false,
	-- Visuals
	ESPEggs = false,
	ShowNames = false,
	HideOthers = false,
	LowGraphics = false,
	-- Player
	Noclip = false,
	AntiAFK = false,
	WalkSpeed = 16,
	-- Settings
	WebhookURL = "",
}
local CONFIG_KEYS = {}
for key in pairs(DEFAULTS) do
	table.insert(CONFIG_KEYS, key)
end
local CONFIG_FOLDER = "ZipHub"
local CONFIG_FILE = "ZipHub/config_beta.json"

for key, value in pairs(DEFAULTS) do
	if genv[key] == nil then
		genv[key] = value
	end
end
-- runtime state shared with the HUD / logic
genv.LastEggSeen = os.clock()
genv.LastStealTime = 0
genv.CurrentlyStealing = nil
genv.CurrentlyStealingValue = nil
genv.CancelCurrentSteal = false

local function loadConfig()
	if not (readfile and isfile) then
		return
	end
	local ok, data = pcall(function()
		if isfile(CONFIG_FILE) then
			return HttpService:JSONDecode(readfile(CONFIG_FILE))
		end
	end)
	if ok and type(data) == "table" then
		for _, key in ipairs(CONFIG_KEYS) do
			if data[key] ~= nil and type(data[key]) == type(DEFAULTS[key]) then
				genv[key] = data[key]
			end
		end
	end
end

local function saveConfig()
	if not writefile then
		return false
	end
	local data = {}
	for _, key in ipairs(CONFIG_KEYS) do
		data[key] = genv[key]
	end
	local ok = pcall(function()
		if makefolder and isfolder and not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end
		writefile(CONFIG_FILE, HttpService:JSONEncode(data))
	end)
	return ok
end

loadConfig()

---------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------
local THEME = {
	Glass = Color3.fromRGB(15, 15, 25), -- rgba(15,15,25,0.75) → transparency 0.25
	GlassTransparency = 0.25,
	Row = Color3.fromRGB(22, 22, 36),
	Cyan = Color3.fromRGB(0, 234, 255),
	Blue = Color3.fromRGB(60, 120, 255),
	Purple = Color3.fromRGB(160, 90, 255),
	Text = Color3.fromRGB(238, 240, 255),
	TextDim = Color3.fromRGB(150, 156, 185),
	Off = Color3.fromRGB(46, 46, 66),
	Danger = Color3.fromRGB(255, 80, 110),
	Success = Color3.fromRGB(80, 255, 170),
}

local NEON_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Cyan),
	ColorSequenceKeypoint.new(0.5, THEME.Purple),
	ColorSequenceKeypoint.new(1, THEME.Cyan),
})

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local alive = true
local connections = {}

local function connect(signal, callback)
	local c = signal:Connect(callback)
	table.insert(connections, c)
	return c
end

-- background loop that stops on unload and never dies on errors
local function loop(delay, fn)
	task.spawn(function()
		while alive do
			task.wait(delay)
			if alive then
				pcall(fn)
			end
		end
	end)
end

local function create(className, props, children)
	local inst = Instance.new(className)
	local parent
	for prop, value in pairs(props or {}) do
		if prop == "Parent" then
			parent = value
		else
			inst[prop] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Neon stroke with a continuously rotating cyan↔purple gradient
local function neonStroke(parent, thickness, transparency, seconds)
	local s = create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = thickness,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	local g = create("UIGradient", { Color = NEON_SEQUENCE, Parent = s })
	TweenService:Create(
		g,
		TweenInfo.new(seconds or 6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 }
	):Play()
	return s
end

local function tween(inst, duration, props, style, direction)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function nextOrder(container)
	local n = (container:GetAttribute("Order") or 0) + 1
	container:SetAttribute("Order", n)
	return n
end

local function getGuiParent()
	if gethui then
		local ok, res = pcall(gethui)
		if ok and res then
			return res
		end
	end
	local ok = pcall(function()
		return CoreGui.Name
	end)
	if ok then
		return CoreGui
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function formatValue(v)
	v = tonumber(v) or 0
	if v >= 1e9 then
		return string.format("%.2fB", v / 1e9)
	elseif v >= 1e6 then
		return string.format("%.2fM", v / 1e6)
	elseif v >= 1e3 then
		return string.format("%.2fK", v / 1e3)
	end
	return tostring(math.floor(v))
end

local function parseNumber(text)
	local s = string.lower((string.gsub(text, "[,%s]", "")))
	local num, suffix = string.match(s, "^([%d%.]+)([kmb]?)$")
	num = tonumber(num)
	if not num then
		return 0
	end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9 })[suffix] or 1
	return num * mult
end

---------------------------------------------------------------------
-- Root GUI + backdrop blur
---------------------------------------------------------------------
local oldBlur = Lighting:FindFirstChild("ZipHubBlur")
if oldBlur then
	oldBlur:Destroy()
end
local Blur = create("BlurEffect", { Name = "ZipHubBlur", Size = 0, Parent = Lighting })

local Gui = create("ScreenGui", {
	Name = "ZipHub",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999,
})
if syn and syn.protect_gui then
	pcall(syn.protect_gui, Gui)
end

---------------------------------------------------------------------
-- Window structure
---------------------------------------------------------------------
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local WIDTH = math.clamp(viewport.X * 0.9, 400, 600)
local HEIGHT = math.clamp(viewport.Y * 0.85, 310, 400)
local MARGIN = 26
local RADIUS = 16

local Root = create("CanvasGroup", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH + MARGIN * 2, HEIGHT + MARGIN * 2),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	Visible = false,
	Parent = Gui,
})
local RootScale = create("UIScale", { Scale = 0.82, Parent = Root })

local function glowLayer(grow, thickness, transparency, radius)
	local f = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH + grow, HEIGHT + grow),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Root,
	}, { corner(radius) })
	neonStroke(f, thickness, transparency, 8)
	return f
end
glowLayer(22, 14, 0.94, RADIUS + 11)
glowLayer(14, 9, 0.9, RADIUS + 7)
glowLayer(8, 5, 0.8, RADIUS + 4)

local Main = create("CanvasGroup", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundColor3 = THEME.Glass,
	BackgroundTransparency = THEME.GlassTransparency,
	BorderSizePixel = 0,
	Parent = Root,
}, { corner(RADIUS) })

local function orb(color, size, pos, goal, seconds)
	local o = create("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = pos,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Parent = Main,
	}, { corner(size) })
	TweenService:Create(
		o,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = goal }
	):Play()
	return o
end
orb(THEME.Cyan, 240, UDim2.fromOffset(-90, -90), UDim2.fromOffset(-30, -40), 7)
orb(THEME.Purple, 280, UDim2.new(1, -170, 1, -170), UDim2.new(1, -230, 1, -210), 9)
orb(THEME.Blue, 160, UDim2.new(0.45, 0, 0.1, 0), UDim2.new(0.3, 0, 0.35, 0), 11)

local sheen = create("Frame", {
	Name = "Sheen",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = Main,
})
create("UIGradient", {
	Rotation = 40,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.84),
		NumberSequenceKeypoint.new(0.45, 0.96),
		NumberSequenceKeypoint.new(1, 0.985),
	}),
	Parent = sheen,
})

local Border = create("Frame", {
	Name = "Border",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = Root,
}, { corner(RADIUS) })
neonStroke(Border, 1.8, 0.05, 5)

---------------------------------------------------------------------
-- Header (entire header is the drag handle)
---------------------------------------------------------------------
local TopBar = create("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundTransparency = 1,
	Active = true,
	Parent = Main,
})

local TitleGlow = create("TextLabel", {
	Name = "TitleGlow",
	Position = UDim2.fromOffset(20, 0),
	Size = UDim2.new(0, 320, 1, 0),
	BackgroundTransparency = 1,
	Text = "⚡ ZIP HUB [BETA]",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = THEME.Cyan,
	TextTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = TopBar,
})
local glowStroke = create("UIStroke", {
	Color = THEME.Cyan,
	Thickness = 4,
	Transparency = 0.4,
	LineJoinMode = Enum.LineJoinMode.Round,
	Parent = TitleGlow,
})

local Title = create("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(20, 0),
	Size = UDim2.new(0, 320, 1, 0),
	BackgroundTransparency = 1,
	Text = "⚡ ZIP HUB [BETA]",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = TopBar,
})
local titleGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 255, 255)),
		ColorSequenceKeypoint.new(0.5, THEME.Cyan),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 255)),
	}),
	Parent = Title,
})

local pulseInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
TweenService:Create(glowStroke, pulseInfo, { Transparency = 0.92 }):Play()
TweenService:Create(TitleGlow, pulseInfo, { TextTransparency = 0.85 }):Play()
TweenService:Create(
	titleGradient,
	TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Offset = Vector2.new(0.25, 0) }
):Play()

local function windowButton(text, xOffset, hoverColor)
	local btn = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, xOffset, 0.5, 0),
		BackgroundColor3 = THEME.Row,
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = THEME.TextDim,
		Parent = TopBar,
	}, { corner(9) })
	local s = stroke(hoverColor, 1, 1)
	s.Parent = btn
	local sc = create("UIScale", { Scale = 1, Parent = btn })
	connect(btn.MouseEnter, function()
		tween(btn, 0.2, { BackgroundColor3 = hoverColor, BackgroundTransparency = 0.15, TextColor3 = Color3.new(1, 1, 1) })
		tween(s, 0.2, { Transparency = 0.2 })
		tween(sc, 0.2, { Scale = 1.1 })
	end)
	connect(btn.MouseLeave, function()
		tween(btn, 0.2, { BackgroundColor3 = THEME.Row, BackgroundTransparency = 0.35, TextColor3 = THEME.TextDim })
		tween(s, 0.2, { Transparency = 1 })
		tween(sc, 0.2, { Scale = 1 })
	end)
	connect(btn.MouseButton1Down, function()
		tween(sc, 0.1, { Scale = 0.92 })
	end)
	return btn
end

local CloseBtn = windowButton("✕", -14, THEME.Danger)
local MinBtn = windowButton("—", -50, THEME.Blue)

local divider = create("Frame", {
	Name = "Divider",
	Position = UDim2.new(0, 14, 0, 52),
	Size = UDim2.new(1, -28, 0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = Main,
})
local dividerGradient = create("UIGradient", {
	Color = NEON_SEQUENCE,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Offset = Vector2.new(-0.6, 0),
	Parent = divider,
})
TweenService:Create(
	dividerGradient,
	TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Offset = Vector2.new(0.6, 0) }
):Play()

---------------------------------------------------------------------
-- Sidebar + content area + watermark
---------------------------------------------------------------------
local Sidebar = create("Frame", {
	Name = "Sidebar",
	Position = UDim2.fromOffset(12, 62),
	Size = UDim2.new(0, 138, 1, -74),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	Parent = Main,
}, { corner(12), stroke(THEME.Purple, 1, 0.75) })

local TabList = create("Frame", {
	Name = "TabList",
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 1, -46),
	BackgroundTransparency = 1,
	Parent = Sidebar,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

create("TextLabel", {
	Name = "PlayerTag",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -8),
	Size = UDim2.new(1, -24, 0, 22),
	BackgroundTransparency = 1,
	Text = "● " .. LocalPlayer.DisplayName,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = THEME.TextDim,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = Sidebar,
})

local Content = create("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(160, 62),
	Size = UDim2.new(1, -172, 1, -92),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = Main,
})

create("TextLabel", {
	Name = "Watermark",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -7),
	Size = UDim2.fromOffset(180, 16),
	BackgroundTransparency = 1,
	Text = "ZIP HUB BETA v1.0",
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextColor3 = Color3.new(1, 1, 1),
	TextTransparency = 0.65,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = Main,
})

---------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------
local tabs = {}
local activeTab
local selectTab

local function createTab(name, icon)
	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = THEME.Purple,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = nextOrder(TabList),
		Parent = TabList,
	}, { corner(9) })

	create("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.fromOffset(22, 38),
		BackgroundTransparency = 1,
		Text = icon,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = THEME.Text,
		Parent = button,
	})

	local label = create("TextLabel", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = THEME.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})

	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.new(0, 3, 0, 0),
		BackgroundColor3 = THEME.Cyan,
		BorderSizePixel = 0,
		Parent = button,
	}, { corner(2) })

	local page = create("ScrollingFrame", {
		Name = name .. "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = THEME.Purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Content,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
	})

	tabs[name] = { Button = button, Label = label, Bar = bar, Page = page }

	connect(button.MouseButton1Click, function()
		selectTab(name)
	end)
	connect(button.MouseEnter, function()
		if activeTab ~= name then
			tween(button, 0.2, { BackgroundTransparency = 0.88 })
			tween(label, 0.2, { TextColor3 = THEME.Text })
		end
	end)
	connect(button.MouseLeave, function()
		if activeTab ~= name then
			tween(button, 0.2, { BackgroundTransparency = 1 })
			tween(label, 0.2, { TextColor3 = THEME.TextDim })
		end
	end)

	return page
end

selectTab = function(name)
	local previous = activeTab
	activeTab = name
	for tabName, tab in pairs(tabs) do
		local active = tabName == name
		tab.Page.Visible = active
		tween(tab.Button, 0.3, { BackgroundTransparency = active and 0.72 or 1 })
		tween(tab.Label, 0.3, { TextColor3 = active and Color3.new(1, 1, 1) or THEME.TextDim })
		tween(tab.Bar, 0.3, { Size = UDim2.new(0, 3, active and 0.55 or 0, 0) })
		if active and previous ~= name then
			tab.Page.Position = UDim2.fromOffset(0, 16)
			tween(tab.Page, 0.4, { Position = UDim2.fromOffset(0, 0) })
		end
	end
end

---------------------------------------------------------------------
-- Components
---------------------------------------------------------------------
local function rowFrame(page, height)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.Row,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(page),
		Parent = page,
	}, { corner(11) })
	local rowStroke = stroke(THEME.Purple, 1, 0.78)
	rowStroke.Parent = row
	return row, rowStroke
end

local function hoverRow(target, row, rowStroke)
	connect(target.MouseEnter, function()
		tween(row, 0.2, { BackgroundTransparency = 0.25 })
		tween(rowStroke, 0.2, { Color = THEME.Cyan, Transparency = 0.45 })
	end)
	connect(target.MouseLeave, function()
		tween(row, 0.2, { BackgroundTransparency = 0.4 })
		tween(rowStroke, 0.2, { Color = THEME.Purple, Transparency = 0.78 })
	end)
end

local function addSection(page, text)
	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = string.upper(text),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = THEME.Purple,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(page),
		Parent = page,
	}, { create("UIPadding", { PaddingLeft = UDim.new(0, 4) }) })
end

local function addLabel(page, text)
	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = THEME.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = nextOrder(page),
		Parent = page,
	}, { create("UIPadding", { PaddingLeft = UDim.new(0, 4) }) })
end

local function addToggle(page, text, key, callback)
	local state = genv[key] and true or false
	local row, rowStroke = rowFrame(page, 44)

	create("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -80, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local track = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = THEME.Off,
		BorderSizePixel = 0,
		Parent = row,
	}, { corner(12) })
	local trackStroke = stroke(THEME.Cyan, 1.2, 1)
	trackStroke.Parent = track

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(200, 204, 225),
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(9) })

	local function render(animated)
		local d = animated and 0.28 or 0
		tween(track, d, { BackgroundColor3 = state and THEME.Purple or THEME.Off })
		tween(trackStroke, d, { Transparency = state and 0.1 or 1 })
		tween(knob, d, {
			Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(200, 204, 225),
		}, Enum.EasingStyle.Back)
	end
	render(false)

	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row,
	})

	connect(hit.MouseButton1Click, function()
		state = not state
		genv[key] = state
		render(true)
		if callback then
			task.spawn(callback, state)
		end
	end)
	hoverRow(hit, row, rowStroke)
end

local function addSlider(page, text, key, min, max, step, suffix, decimals, callback)
	local value = math.clamp(tonumber(genv[key]) or min, min, max)
	local row, rowStroke = rowFrame(page, 62)

	create("TextLabel", {
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.new(1, -100, 0, 22),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.fromOffset(80, 22),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = THEME.Cyan,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local track = create("Frame", {
		Position = UDim2.new(0, 14, 0, 42),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = THEME.Off,
		BorderSizePixel = 0,
		Parent = row,
	}, { corner(3) })

	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}, {
		corner(3),
		create("UIGradient", { Color = ColorSequence.new(THEME.Cyan, THEME.Purple) }),
	})

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(15, 15),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	}, { corner(8) })
	local knobStroke = stroke(THEME.Cyan, 2, 0.05)
	knobStroke.Parent = knob

	local function render()
		local alpha = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = string.format("%." .. (decimals or 0) .. "f%s", value, suffix or "")
	end

	local function apply(inputX)
		local alpha = math.clamp((inputX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local raw = min + (max - min) * alpha
		local snapped = math.clamp(math.floor(raw / step + 0.5) * step, min, max)
		snapped = tonumber(string.format("%." .. (decimals or 0) .. "f", snapped))
		if snapped ~= value then
			value = snapped
			genv[key] = value
			render()
			if callback then
				task.spawn(callback, value)
			end
		end
	end

	genv[key] = value
	render()

	local hit = create("TextButton", {
		Position = UDim2.new(0, 8, 0, 32),
		Size = UDim2.new(1, -16, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row,
	})

	local dragging = false
	connect(hit.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(knob, 0.15, { Size = UDim2.fromOffset(20, 20) })
			apply(input.Position.X)
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			apply(input.Position.X)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, 0.15, { Size = UDim2.fromOffset(15, 15) })
		end
	end)
	hoverRow(hit, row, rowStroke)
end

-- opts: { parse = fn(text) -> value, format = fn(value) -> text, callback = fn(value) }
local function addTextBox(page, text, key, placeholder, opts)
	opts = opts or {}
	local row = rowFrame(page, 84)

	create("TextLabel", {
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.new(1, -110, 0, 22),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local status = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.fromOffset(90, 22),
		BackgroundTransparency = 1,
		Text = "Applied ✓",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = THEME.Success,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local function fmt(v)
		if opts.format then
			return opts.format(v)
		end
		return tostring(v or "")
	end

	local box = create("TextBox", {
		Position = UDim2.new(0, 14, 0, 38),
		Size = UDim2.new(1, -28, 0, 36),
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Text = fmt(genv[key]),
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = Color3.fromRGB(100, 104, 134),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}, {
		corner(9),
		create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	local boxStroke = stroke(THEME.Purple, 1.2, 0.55)
	boxStroke.Parent = box

	local function commit()
		local clean = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
		local value = opts.parse and opts.parse(clean) or clean
		genv[key] = value
		box.Text = fmt(value)
		return value
	end

	local focused = false
	connect(box.MouseEnter, function()
		if not focused then
			tween(boxStroke, 0.2, { Transparency = 0.25 })
		end
	end)
	connect(box.MouseLeave, function()
		if not focused then
			tween(boxStroke, 0.2, { Transparency = 0.55 })
		end
	end)
	connect(box.Focused, function()
		focused = true
		tween(boxStroke, 0.25, { Color = THEME.Cyan, Transparency = 0, Thickness = 1.8 })
	end)
	connect(box.FocusLost, function()
		focused = false
		local value = commit()
		tween(boxStroke, 0.25, { Color = THEME.Purple, Transparency = 0.55, Thickness = 1.2 })
		status.TextTransparency = 0
		tween(status, 1.2, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if opts.callback then
			task.spawn(opts.callback, value)
		end
	end)

	return box, commit
end

local function addButton(page, text, callback)
	local btn = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = nextOrder(page),
		Parent = page,
	}, {
		corner(11),
		create("UIGradient", { Color = ColorSequence.new(THEME.Cyan, THEME.Purple) }),
	})
	local btnStroke = stroke(Color3.new(1, 1, 1), 1.2, 0.7)
	btnStroke.Parent = btn
	local sc = create("UIScale", { Scale = 1, Parent = btn })

	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = btn,
	})

	connect(btn.MouseEnter, function()
		tween(btn, 0.2, { BackgroundTransparency = 0.05 })
		tween(btnStroke, 0.2, { Transparency = 0.2 })
		tween(sc, 0.2, { Scale = 1.02 })
	end)
	connect(btn.MouseLeave, function()
		tween(btn, 0.2, { BackgroundTransparency = 0.3 })
		tween(btnStroke, 0.2, { Transparency = 0.7 })
		tween(sc, 0.2, { Scale = 1 })
	end)
	connect(btn.MouseButton1Down, function()
		tween(sc, 0.08, { Scale = 0.97 })
	end)
	connect(btn.MouseButton1Up, function()
		tween(sc, 0.15, { Scale = 1.02 })
	end)
	connect(btn.MouseButton1Click, function()
		if callback then
			task.spawn(callback, label)
		end
	end)

	return btn, label
end

---------------------------------------------------------------------
-- Tab contents (every control is bound to getgenv())
---------------------------------------------------------------------
local AutoStealTab = createTab("Auto Steal", "🎯")
local VisualsTab = createTab("Visuals", "👁")
local PlayerTab = createTab("Player", "🏃")
local SettingsTab = createTab("Settings", "⚙")

-- 1) Auto Steal
addSection(AutoStealTab, "Automation")
addToggle(AutoStealTab, "Auto Steal (Rare Only)", "AutoSteal")
addToggle(AutoStealTab, "Auto Hop (Server Hop)", "AutoHop", function(on)
	if on then
		genv.LastEggSeen = os.clock() -- restart the hop countdown
	end
end)
addSlider(AutoStealTab, "Speed", "TweenSpeed", 0.1, 1, 0.05, "s", 2)
addSection(AutoStealTab, "Targeting")
addToggle(AutoStealTab, "Steal From Players", "StealFromPlayers")
addTextBox(AutoStealTab, "Min Value (0 = any, e.g. 5k, 2m)", "MinValue", "0", {
	parse = parseNumber,
	format = function(v)
		return string.format("%.0f", tonumber(v) or 0)
	end,
})
addSection(AutoStealTab, "Events")
addToggle(AutoStealTab, "Auto Farm Base", "AutoFarmBase")
addToggle(AutoStealTab, "Auto UFO", "AutoUFO")
addToggle(AutoStealTab, "Auto Meteor", "AutoMeteor")
addToggle(AutoStealTab, "Auto Minigame", "AutoMinigame")

-- 2) Visuals
addSection(VisualsTab, "ESP")
addToggle(VisualsTab, "ESP Eggs (Highlight rare targets)", "ESPEggs")
addToggle(VisualsTab, "Show Names", "ShowNames")
addSection(VisualsTab, "Performance")
addToggle(VisualsTab, "Hide Others", "HideOthers")
addToggle(VisualsTab, "Low Graphics", "LowGraphics")

-- 3) Player
addSection(PlayerTab, "Movement")
addToggle(PlayerTab, "Noclip", "Noclip")
addToggle(PlayerTab, "Anti-AFK", "AntiAFK")
addSlider(PlayerTab, "WalkSpeed", "WalkSpeed", 16, 200, 1, "", 0)

-- 4) Settings
addSection(SettingsTab, "Webhook")
local _, commitWebhook = addTextBox(SettingsTab, "Discord Webhook URL", "WebhookURL", "https://discord.com/api/webhooks/...")
addSection(SettingsTab, "Config")

local saveResetThread
addButton(SettingsTab, "💾  Save Config", function(label)
	commitWebhook() -- commit the box even if it is still focused
	local ok = saveConfig()
	if saveResetThread then
		task.cancel(saveResetThread)
	end
	if ok then
		label.Text = "✔  Config Saved"
		tween(label, 0.2, { TextColor3 = THEME.Success })
	else
		label.Text = "⚠  File access unavailable"
		tween(label, 0.2, { TextColor3 = Color3.fromRGB(255, 200, 120) })
	end
	saveResetThread = task.delay(1.8, function()
		label.Text = "💾  Save Config"
		tween(label, 0.3, { TextColor3 = Color3.new(1, 1, 1) })
	end)
end)

addSection(SettingsTab, "Interface")
addLabel(SettingsTab, "Press RightShift or tap the ⚡ button to show / hide ZIP HUB.")

selectTab("Auto Steal")

---------------------------------------------------------------------
-- Floating launcher (visible while the window is hidden)
---------------------------------------------------------------------
local Launcher = create("TextButton", {
	Name = "Launcher",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = THEME.Glass,
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "⚡",
	Font = Enum.Font.GothamBlack,
	TextSize = 24,
	TextColor3 = THEME.Cyan,
	TextTransparency = 1,
	Visible = false,
	Parent = Gui,
}, { corner(24) })
local launcherStroke = neonStroke(Launcher, 2, 1, 4)
local launcherScale = create("UIScale", { Scale = 1, Parent = Launcher })
connect(Launcher.MouseEnter, function()
	tween(launcherScale, 0.2, { Scale = 1.12 })
end)
connect(Launcher.MouseLeave, function()
	tween(launcherScale, 0.2, { Scale = 1 })
end)

---------------------------------------------------------------------
-- Status HUD (replaces the old overlay) — glass style, auto shows
-- while Auto Steal / Auto Hop is enabled
---------------------------------------------------------------------
local stolenCount = 0

local HUD = create("Frame", {
	Name = "HUD",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(250, 112),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = Gui,
}, { corner(12) })
local hudStroke = neonStroke(HUD, 1.5, 1, 5)

local HUDGroup = create("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Glass,
	BackgroundTransparency = THEME.GlassTransparency,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	Parent = HUD,
}, { corner(12) })

create("TextLabel", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 20),
	BackgroundTransparency = 1,
	Text = "⚡ ZIP HUB [BETA]",
	Font = Enum.Font.GothamBlack,
	TextSize = 13,
	TextColor3 = THEME.Cyan,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = HUDGroup,
})

local HUDCount = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 6),
	Size = UDim2.fromOffset(90, 20),
	BackgroundTransparency = 1,
	Text = "Stolen: 0",
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = THEME.TextDim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = HUDGroup,
})

local HUDStatus = create("TextLabel", {
	Position = UDim2.fromOffset(12, 28),
	Size = UDim2.new(1, -24, 0, 44),
	BackgroundTransparency = 1,
	Text = "Waiting for target...",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = THEME.TextDim,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = HUDGroup,
})

local CancelBtn = create("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -10),
	Size = UDim2.new(1, -24, 0, 26),
	BackgroundColor3 = THEME.Danger,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "CANCEL STEAL",
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = Color3.new(1, 1, 1),
	Parent = HUDGroup,
}, { corner(8) })
local cancelScale = create("UIScale", { Scale = 1, Parent = CancelBtn })
connect(CancelBtn.MouseEnter, function()
	tween(CancelBtn, 0.2, { BackgroundTransparency = 0.02 })
	tween(cancelScale, 0.2, { Scale = 1.03 })
end)
connect(CancelBtn.MouseLeave, function()
	tween(CancelBtn, 0.2, { BackgroundTransparency = 0.25 })
	tween(cancelScale, 0.2, { Scale = 1 })
end)
connect(CancelBtn.MouseButton1Click, function()
	if genv.CurrentlyStealing then -- only cancel a steal that is actually running
		genv.CancelCurrentSteal = true
	end
end)

local hudShown = false
local function setHudShown(state)
	if state == hudShown then
		return
	end
	hudShown = state
	if state then
		HUD.Visible = true
		tween(HUDGroup, 0.35, { GroupTransparency = 0 })
		tween(hudStroke, 0.35, { Transparency = 0.2 })
	else
		tween(HUDGroup, 0.3, { GroupTransparency = 1 })
		tween(hudStroke, 0.3, { Transparency = 1 })
		task.delay(0.32, function()
			if not hudShown then
				HUD.Visible = false
			end
		end)
	end
end

---------------------------------------------------------------------
-- Open / close (smooth scale + fade + blur)
---------------------------------------------------------------------
local isOpen = false

local function setOpen(state)
	isOpen = state
	if state then
		Root.Visible = true
		tween(Root, 0.4, { GroupTransparency = 0 })
		tween(RootScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(Blur, 0.45, { Size = 24 })
		tween(Launcher, 0.2, { BackgroundTransparency = 1, TextTransparency = 1 })
		tween(launcherStroke, 0.2, { Transparency = 1 })
		task.delay(0.2, function()
			if isOpen then
				Launcher.Visible = false
			end
		end)
	else
		tween(Root, 0.3, { GroupTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(RootScale, 0.3, { Scale = 0.82 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(Blur, 0.3, { Size = 0 })
		Launcher.Visible = true
		tween(Launcher, 0.3, { BackgroundTransparency = 0.3, TextTransparency = 0 })
		tween(launcherStroke, 0.3, { Transparency = 0.15 })
		task.delay(0.32, function()
			if not isOpen then
				Root.Visible = false
			end
		end)
	end
end

connect(Launcher.MouseButton1Click, function()
	setOpen(true)
end)
connect(MinBtn.MouseButton1Click, function()
	setOpen(false)
end)
connect(CloseBtn.MouseButton1Click, function()
	setOpen(false)
	task.delay(0.35, function()
		if genv.ZipHubUnload then
			genv.ZipHubUnload()
		end
	end)
end)
connect(UserInputService.InputBegan, function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		setOpen(not isOpen)
	end
end)

---------------------------------------------------------------------
-- Dragging (entire header, clamped to the screen)
---------------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil

connect(TopBar.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Root.Position
	end
end)
connect(UserInputService.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
		local x = math.clamp(startPos.X.Offset + delta.X, -vp.X / 2 + 80, vp.X / 2 - 80)
		local y = math.clamp(startPos.Y.Offset + delta.Y, -vp.Y / 2 + 50, vp.Y / 2 - 50)
		tween(Root, 0.08, { Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y) }, Enum.EasingStyle.Sine)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

---------------------------------------------------------------------
-- ═════════════════════  LOGIC (reads getgenv())  ═════════════════════
---------------------------------------------------------------------
local function getChar()
	local c = LocalPlayer.Character
	if not c or not c.Parent then
		return nil
	end
	return c
end

local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getValue(e)
	return e:GetAttribute("Value") or e:GetAttribute("Price") or e:GetAttribute("ValuePerSecond") or e:GetAttribute("Income") or 0
end

local function getRarityName(e)
	return tostring(e:GetAttribute("Rarity") or e:GetAttribute("rarity") or "Common")
end

-- "Rare Only": uses RARE_TIERS unless you set getgenv().RarityFilter (string or table)
local function matchesRarity(e)
	local f = genv.RarityFilter or RARE_TIERS
	local r = string.lower(getRarityName(e))
	if type(f) == "table" then
		for _, v in ipairs(f) do
			if string.lower(tostring(v)) == r then
				return true
			end
		end
		return false
	end
	return string.lower(tostring(f)) == r
end

local function getOwner(e)
	return e:GetAttribute("Owner") or e:GetAttribute("OwnerName") or e:GetAttribute("User")
end

local function getRoot(e)
	if e:IsA("BasePart") then
		return e
	end
	return e.PrimaryPart or e:FindFirstChild("HumanoidRootPart") or e:FindFirstChildWhichIsA("BasePart")
end

local function firePrompt(p)
	if not p then
		return false
	end
	local ok = pcall(function()
		fireproximityprompt(p)
	end)
	if ok then
		return true
	end
	ok = pcall(function()
		p:InputHoldBegin()
		task.wait(p.HoldDuration or 0)
		p:InputHoldEnd()
	end)
	return ok
end

-- Discord webhook (only to discord.com / discordapp.com webhook URLs)
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
local lastHook = 0
local function sendWebhook(title, description, color)
	local url = tostring(genv.WebhookURL or "")
	if not (string.match(url, "^https://[%w%.]*discord%.com/api/webhooks/") or string.match(url, "^https://[%w%.]*discordapp%.com/api/webhooks/")) then
		return
	end
	if not httpRequest then
		return
	end
	task.spawn(function()
		local wait = 1.5 - (os.clock() - lastHook)
		if wait > 0 then
			task.wait(wait)
		end
		lastHook = os.clock()
		pcall(function()
			httpRequest({
				Url = url,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({
					username = "ZIP HUB [BETA]",
					embeds = { {
						title = title,
						description = description,
						color = color or 52479,
						footer = { text = "ZIP HUB BETA v1.0 • " .. LocalPlayer.Name },
					} },
				}),
			})
		end)
	end)
end

-- ── Target selection (Auto Steal) ──────────────────────────────────
local function scoreTarget(inst, pos, myName, minV, requireOwner)
	local owner = getOwner(inst)
	if requireOwner then
		if not owner or owner == myName then
			return nil
		end
	elseif owner == myName then
		return nil
	end
	local root = getRoot(inst)
	if not root then
		return nil
	end
	local v = getValue(inst)
	if v < minV or not matchesRarity(inst) then
		return nil
	end
	return v / ((root.Position - pos).Magnitude + 1)
end

local function findBestEgg()
	local hrp = getHRP()
	if not hrp then
		return nil
	end
	local pos, myName = hrp.Position, LocalPlayer.Name
	local minV = tonumber(genv.MinValue) or 0
	local best, bestScore = nil, -math.huge

	for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
		if egg.Parent then
			local s = scoreTarget(egg, pos, myName, minV, false)
			if s and s > bestScore then
				best, bestScore = egg, s
			end
		end
	end
	if genv.StealFromPlayers then
		for _, pet in ipairs(CollectionService:GetTagged("Pet")) do
			if pet.Parent then
				local s = scoreTarget(pet, pos, myName, minV, true)
				if s and s > bestScore then
					best, bestScore = pet, s
				end
			end
		end
	end
	return best
end

-- ── Server hop (Auto Hop) ──────────────────────────────────────────
local lastHop = 0
local function serverHop()
	if os.clock() - lastHop < 15 then
		return
	end
	lastHop = os.clock()
	sendWebhook("🔄 Server Hop", "No valid target for " .. HOP_AFTER .. "s — switching server.", 10181046)
	local ok = pcall(function()
		local res = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
		local data = HttpService:JSONDecode(res)
		if data and data.data then
			for _, s in ipairs(data.data) do
				if s.id ~= game.JobId and s.playing < s.maxPlayers then
					TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
					return
				end
			end
		end
	end)
	if not ok then
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end
	genv.LastEggSeen = os.clock()
end

-- ── Steal routine (duration = Speed slider) ────────────────────────
local function stealEgg(egg)
	local hrp = getHRP()
	if not hrp then
		return
	end
	local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return
	end
	local root = getRoot(egg)
	if not root then
		return
	end

	local info = TweenInfo.new(math.clamp(tonumber(genv.TweenSpeed) or 0.3, 0.1, 1), Enum.EasingStyle.Linear)
	local origin, target = hrp.CFrame, root.CFrame
	local name, value, rarity = egg.Name, getValue(egg), getRarityName(egg)

	genv.CurrentlyStealing = name
	genv.CurrentlyStealingValue = formatValue(value)

	local function finish(success)
		genv.CurrentlyStealing = nil
		genv.CurrentlyStealingValue = nil
		genv.CancelCurrentSteal = false
		if success then
			genv.LastStealTime = os.clock()
			stolenCount += 1
			sendWebhook(
				"🥚 Steal Complete",
				string.format("**%s**\nRarity: %s\nValue: %s", name, rarity, formatValue(value)),
				5832555
			)
		end
	end

	local t1 = TweenService:Create(hrp, info, { CFrame = target })
	t1:Play()
	t1.Completed:Wait()

	if genv.CancelCurrentSteal or not egg.Parent then
		if hrp.Parent then
			hrp.CFrame = origin
		end
		finish(false)
		return
	end

	firePrompt(prompt)
	task.wait((prompt.HoldDuration or 0.5) + 0.15)

	if hrp.Parent then
		local t2 = TweenService:Create(hrp, info, { CFrame = origin })
		t2:Play()
		t2.Completed:Wait()
	end
	finish(true)
end

-- Main loop: Auto Steal and/or Auto Hop
loop(0.2, function()
	if not (genv.AutoSteal or genv.AutoHop) then
		return
	end
	local egg = findBestEgg()
	if egg then
		genv.LastEggSeen = os.clock()
		if genv.AutoSteal then
			stealEgg(egg)
		end
	elseif genv.AutoHop and os.clock() - (genv.LastEggSeen or 0) > HOP_AFTER then
		serverHop()
	end
end)

-- ── GUI-button helpers (events / farm) ─────────────────────────────
local function findBtn(patterns)
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	for _, d in ipairs(pg:GetDescendants()) do
		if (d:IsA("TextButton") or d:IsA("ImageButton")) and not d:IsDescendantOf(Gui) then
			local label = d:IsA("TextButton") and d.Text ~= "" and d.Text or d.Name
			label = string.lower(label)
			for _, p in ipairs(patterns) do
				if string.find(label, string.lower(p), 1, true) then
					return d
				end
			end
		end
	end
	return nil
end

local function clickBtn(b)
	if not b then
		return false
	end
	local ok = pcall(function()
		b:Activate()
	end)
	if not ok then
		pcall(function()
			b.MouseButton1Click:Fire()
		end)
	end
	return ok
end

local FARM_PATTERNS = { "upgrade", "buy slot", "purchase slot", "unlock slot", "claim", "collect", "daily", "offline", "index", "reward" }
loop(3, function()
	if genv.AutoFarmBase then
		clickBtn(findBtn(FARM_PATTERNS))
		clickBtn(findBtn({ "mutate", "mutation", "enhance" }))
	end
end)

local function scanTop(patterns)
	for _, o in ipairs(workspace:GetChildren()) do
		local n = string.lower(o.Name)
		for _, p in ipairs(patterns) do
			if string.find(n, string.lower(p), 1, true) then
				return o
			end
		end
	end
	return nil
end

local function tpCollect(t)
	local hrp = getHRP()
	if not hrp or not t then
		return
	end
	local r = t:IsA("BasePart") and t or t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")
	if not r then
		return
	end
	pcall(function()
		hrp.CFrame = r.CFrame + Vector3.new(0, 3, 0)
	end)
	pcall(function()
		local p = t:FindFirstChildWhichIsA("ProximityPrompt", true)
		if p then
			firePrompt(p)
		end
	end)
end

loop(2, function()
	if genv.AutoUFO then
		local u = scanTop({ "ufo", "debris", "saucer" })
		if u then
			tpCollect(u)
			clickBtn(findBtn({ "trade", "sell" }))
		end
	end
	if genv.AutoMeteor then
		local s = scanTop({ "star", "meteor", "falling" })
		if s then
			tpCollect(s)
		end
	end
end)

loop(1, function()
	if not genv.AutoMinigame then
		return
	end
	local f = scanTop({ "finish", "safe zone", "safe", "goal", "checkpoint" })
	if f then
		tpCollect(f)
	end
	local sig = scanTop({ "red light", "green light", "signal", "traffic" })
	if sig then
		local red = sig:GetAttribute("Red") or (sig:GetAttribute("State") == "Red") or (string.find(string.lower(sig.Name), "red") ~= nil)
		if red then
			local sf = scanTop({ "safe", "cover", "hiding" })
			if sf then
				tpCollect(sf)
			end
		end
	end
end)

-- ── Low Graphics (reversible) ──────────────────────────────────────
local LIGHTING_PROPS = { "GlobalShadows", "FogEnd", "Brightness", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "Ambient", "OutdoorAmbient" }
local WATER_PROPS = { "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance", "WaterTransparency" }
local EFFECT_CLASSES = { "BloomEffect", "BlurEffect", "DepthOfFieldEffect", "SunRaysEffect", "ColorCorrectionEffect" }
local gfxBackup

local function isPostEffect(v)
	if v == Blur then
		return false
	end
	for _, class in ipairs(EFFECT_CLASSES) do
		if v:IsA(class) then
			return true
		end
	end
	return false
end

local function applyLow()
	pcall(function()
		local terrain = workspace.Terrain
		if not gfxBackup then
			gfxBackup = { Lighting = {}, Effects = {}, Water = {} }
			for _, p in ipairs(LIGHTING_PROPS) do
				gfxBackup.Lighting[p] = Lighting[p]
			end
			for _, p in ipairs(WATER_PROPS) do
				gfxBackup.Water[p] = terrain[p]
			end
		end
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 100000
		Lighting.Brightness = 1
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
		terrain.WaterTransparency = 1
		for _, v in ipairs(Lighting:GetChildren()) do
			if isPostEffect(v) then
				if gfxBackup.Effects[v] == nil then
					gfxBackup.Effects[v] = v.Enabled
				end
				v.Enabled = false
			end
		end
	end)
end

local function restoreGraphics()
	if not gfxBackup then
		return
	end
	pcall(function()
		for p, v in pairs(gfxBackup.Lighting) do
			Lighting[p] = v
		end
		for p, v in pairs(gfxBackup.Water) do
			workspace.Terrain[p] = v
		end
		for inst, enabled in pairs(gfxBackup.Effects) do
			if inst.Parent then
				inst.Enabled = enabled
			end
		end
	end)
	gfxBackup = nil
end

local lastGfx
loop(0.5, function()
	local want = genv.LowGraphics and true or false
	if want ~= lastGfx then
		lastGfx = want
		if want then
			applyLow()
		else
			restoreGraphics()
		end
	end
end)

connect(LocalPlayer.CharacterAdded, function()
	task.wait(0.5)
	if alive and genv.LowGraphics then
		applyLow()
	end
end)

-- ── Hide Others (restores each part's real transparency) ───────────
local hiddenParts = {} -- instance -> original transparency

local function hideInstance(inst)
	local function hideOne(p)
		if (p:IsA("BasePart") or p:IsA("Decal") or p:IsA("Texture")) and hiddenParts[p] == nil then
			hiddenParts[p] = p.Transparency
			p.Transparency = 1
		end
	end
	hideOne(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		hideOne(d)
	end
end

local function restoreHidden()
	for p, t in pairs(hiddenParts) do
		if p.Parent then
			p.Transparency = t
		end
	end
	table.clear(hiddenParts)
end

loop(1, function()
	if genv.HideOthers then
		for p in pairs(hiddenParts) do
			if not p.Parent then
				hiddenParts[p] = nil
			end
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= LocalPlayer and pl.Character then
				hideInstance(pl.Character)
			end
		end
		for _, pet in ipairs(CollectionService:GetTagged("Pet")) do
			local owner = getOwner(pet)
			if owner and owner ~= LocalPlayer.Name then
				hideInstance(pet)
			end
		end
	elseif next(hiddenParts) then
		restoreHidden()
	end
end)

-- ── Anti-AFK ───────────────────────────────────────────────────────
connect(LocalPlayer.Idled, function()
	if genv.AntiAFK then
		pcall(function()
			local VU = game:GetService("VirtualUser")
			VU:CaptureController()
			VU:ClickButton2(Vector2.new())
		end)
	end
end)
loop(120, function()
	if genv.AntiAFK then
		game:GetService("VirtualUser"):ClickButton1(Vector2.new())
	end
end)

-- ── Noclip + WalkSpeed ─────────────────────────────────────────────
connect(RunService.Stepped, function()
	if not genv.Noclip then
		return
	end
	local c = getChar()
	if not c then
		return
	end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			p.CanCollide = false
		end
	end
end)

local DEFAULT_WALKSPEED = 16
local walkEnforced = false
loop(0.1, function()
	local hm = getHumanoid()
	if not hm then
		return
	end
	local ws = tonumber(genv.WalkSpeed) or DEFAULT_WALKSPEED
	if ws ~= DEFAULT_WALKSPEED then
		walkEnforced = true
		if hm.WalkSpeed ~= ws then
			hm.WalkSpeed = ws
		end
	elseif walkEnforced then
		walkEnforced = false
		hm.WalkSpeed = DEFAULT_WALKSPEED
	end
end)

-- ── ESP Eggs (rarity colors) + Show Names ──────────────────────────
local espObjects = {} -- inst -> { hl = Highlight?, bb = BillboardGui? }

local function rarityColor(inst)
	return RARITY_COLORS[string.lower(getRarityName(inst))] or Color3.new(1, 1, 1)
end

local function clearESP(inst)
	local o = espObjects[inst]
	if o then
		if o.hl then
			o.hl:Destroy()
		end
		if o.bb then
			o.bb:Destroy()
		end
		espObjects[inst] = nil
	end
end

local function clearAllESP()
	for inst in pairs(espObjects) do
		clearESP(inst)
	end
end

local function updateESPFor(inst, wantHL, wantName)
	local o = espObjects[inst] or {}
	espObjects[inst] = o
	local color = rarityColor(inst)

	if wantHL then
		if not o.hl then
			o.hl = create("Highlight", {
				Name = "ZipHubESP",
				Adornee = inst,
				FillTransparency = 0.6,
				OutlineTransparency = 0,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				Parent = inst,
			})
		end
		o.hl.FillColor = color
		o.hl.OutlineColor = color
	elseif o.hl then
		o.hl:Destroy()
		o.hl = nil
	end

	if wantName then
		local root = getRoot(inst)
		if root then
			if not o.bb then
				o.bb = create("BillboardGui", {
					Name = "ZipHubName",
					Adornee = root,
					AlwaysOnTop = true,
					Size = UDim2.fromOffset(170, 36),
					StudsOffset = Vector3.new(0, 3, 0),
					Parent = root,
				})
				o.label = create("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextStrokeTransparency = 0.3,
					Parent = o.bb,
				})
			end
			o.label.TextColor3 = color
			o.label.Text = string.format("%s\n%s • %s", tostring(inst:GetAttribute("DisplayName") or inst.Name), getRarityName(inst), formatValue(getValue(inst)))
		end
	elseif o.bb then
		o.bb:Destroy()
		o.bb = nil
		o.label = nil
	end
end

loop(0.75, function()
	if not (genv.ESPEggs or genv.ShowNames) then
		if next(espObjects) then
			clearAllESP()
		end
		return
	end
	local seen = {}
	local myName = LocalPlayer.Name

	local function consider(inst, needOwner)
		if not inst.Parent then
			return
		end
		local owner = getOwner(inst)
		if owner == myName or (needOwner and not owner) then
			return
		end
		seen[inst] = true
		updateESPFor(inst, genv.ESPEggs and matchesRarity(inst), genv.ShowNames)
	end

	for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
		consider(egg, false)
	end
	if genv.StealFromPlayers then
		for _, pet in ipairs(CollectionService:GetTagged("Pet")) do
			consider(pet, true)
		end
	end
	for inst in pairs(espObjects) do
		if not seen[inst] or not inst.Parent then
			clearESP(inst)
		end
	end
end)

-- ── HUD updater ────────────────────────────────────────────────────
loop(0.25, function()
	local active = genv.AutoSteal or genv.AutoHop
	setHudShown(active and true or false)
	if not active then
		return
	end
	HUDCount.Text = "Stolen: " .. stolenCount
	local name = genv.CurrentlyStealing
	if name then
		HUDStatus.TextColor3 = Color3.fromRGB(255, 215, 130)
		HUDStatus.Text = "Stealing: " .. tostring(name) .. "\nValue: " .. tostring(genv.CurrentlyStealingValue)
		CancelBtn.Visible = true
	else
		HUDStatus.TextColor3 = THEME.TextDim
		if genv.AutoHop then
			local left = math.max(0, math.ceil(HOP_AFTER - (os.clock() - (genv.LastEggSeen or 0))))
			HUDStatus.Text = "Waiting for target...\nHop in " .. left .. "s"
		else
			HUDStatus.Text = "Waiting for target..."
		end
	end
end)

---------------------------------------------------------------------
-- Unload + mount
---------------------------------------------------------------------
genv.ZipHubUnload = function()
	alive = false
	for _, c in ipairs(connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(connections)
	pcall(clearAllESP)
	pcall(restoreHidden)
	pcall(restoreGraphics)
	if Blur then
		Blur:Destroy()
	end
	if Gui then
		Gui:Destroy()
	end
	genv.ZipHubUnload = nil
end

Gui.Parent = getGuiParent()
setOpen(true)
