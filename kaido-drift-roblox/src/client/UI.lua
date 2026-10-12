--!strict
-- All 2D interface, built in code: title screen, garage, driving HUD (drift score, speedometer,
-- minimap, buttons) and on-screen touch controls for phones/tablets.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local Track = require(Shared:WaitForChild("Track"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local Input = require(script.Parent:WaitForChild("Input"))

local C = Config.COLORS
local UI = {}

export type Profile = { credits: number, owned: { string }, selected: string, best: number, total: number, easyDrift: boolean }

UI.callbacks = {
	play = function() end,
	garage = function() end,
	back = function() end,
	buy = function(_id: string) end,
	select = function(_id: string) end,
	menu = function() end,
	camera = function() end,
	reset = function() end,
	easy = function() end,
}

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
UI.fmt = fmt

local function make(class: string, props: { [string]: any }, children: { any }?): any
	local inst = Instance.new(class :: any)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, ch in children do
			ch.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number): any
	return make("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color: Color3, t: number?, thick: number?): any
	return make("UIStroke", { Color = color, Transparency = t or 0, Thickness = thick or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}
	for k, v in props do
		base[k] = v
	end
	return make("TextLabel", base)
end

local function button(text: string, primary: boolean, props: { [string]: any }): TextButton
	local base = {
		Text = text,
		AutoButtonColor = true,
		BackgroundColor3 = if primary then C.sakura else C.panel,
		BackgroundTransparency = if primary then 0 else 0.15,
		TextColor3 = if primary then C.ink else C.text,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
	}
	for k, v in props do
		base[k] = v
	end
	local b = make("TextButton", base, { corner(10), stroke(if primary then C.sakura else C.dim, if primary then 0 else 0.6) })
	return b
end

-- ---------------------------------------------------------------- root
local gui: ScreenGui = make("ScreenGui", {
	Name = "KaidoUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local profile: Profile = { credits = 0, owned = { Cars.DEFAULT }, selected = Cars.DEFAULT, best = 0, total = 0, easyDrift = true }
local function owns(id: string): boolean
	return table.find(profile.owned, id) ~= nil
end

-- ---------------------------------------------------------------- title
local title: Frame = make("Frame", { Name = "Title", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.2, Parent = gui }, {
	make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.5), NumberSequenceKeypoint.new(1, 1) }) }),
})
local col: Frame = make("Frame", {
	Size = UDim2.new(0, if isTouch then 330 else 440, 1, 0),
	Position = UDim2.new(0, if isTouch then 28 else 72, 0, 0),
	BackgroundTransparency = 1,
	Parent = title,
}, {
	make("UIListLayout", { Padding = UDim.new(0, if isTouch then 6 else 12), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
label({ Text = "峠  MIDNIGHT TOUGE", TextColor3 = C.sakura, TextSize = if isTouch then 14 else 18, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = col })
label({ Text = "KAIDO DRIFT", Font = Enum.Font.GothamBlack, TextSize = if isTouch then 44 else 68, Size = UDim2.new(1, 0, 0, if isTouch then 48 else 74), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = col })
label({
	Text = "Midnight on the lake pass. Slide a 90s coupe through the lantern village, up the hairpins and along the shore. Every drift earns credits for the garage.",
	Font = Enum.Font.Gotham, TextSize = if isTouch then 13 else 16, TextColor3 = C.dim, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, if isTouch then 52 else 66), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 3, Parent = col,
})
local titleStats = label({ Text = "", TextColor3 = C.gold, TextSize = if isTouch then 15 else 18, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 4, Parent = col })
local playBtn = button("PLAY", true, { Size = UDim2.new(1, 0, 0, if isTouch then 46 else 56), TextSize = if isTouch then 20 else 24, LayoutOrder = 5, Parent = col })
local garageBtn = button("GARAGE", false, { Size = UDim2.new(1, 0, 0, if isTouch then 42 else 50), LayoutOrder = 6, Parent = col })
local easyBtn = button("EASY DRIFT: ON", false, { Size = UDim2.new(1, 0, 0, if isTouch then 36 else 40), TextSize = 16, Font = Enum.Font.GothamBold, LayoutOrder = 7, Parent = col })
local status = label({ Text = "Building the mountain pass…", TextColor3 = C.neon, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 8, Parent = col })
label({
	Text = if isTouch then "Stick: steer · GAS / BRAKE / HB buttons · ⟳ resets the car"
		else "W/S gas & brake · A/D steer · Space handbrake · C camera · R reset\nGamepad: RT gas · LT brake · left stick steer · B/X handbrake · Y camera",
	Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.dim, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 9, Parent = col,
})

playBtn.Activated:Connect(function()
	if Workspace:GetAttribute("MapReady") then
		UI.callbacks.play()
	end
end)
garageBtn.Activated:Connect(function()
	UI.callbacks.garage()
end)
easyBtn.Activated:Connect(function()
	UI.callbacks.easy()
end)

-- ---------------------------------------------------------------- garage
local garage: Frame = make("Frame", { Name = "Garage", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.05, Visible = false, Parent = gui })
local pad = if isTouch then 12 else 28
label({ Text = "GARAGE", Font = Enum.Font.GothamBlack, TextSize = if isTouch then 26 else 36, Position = UDim2.new(0, pad, 0, pad), Size = UDim2.new(0, 300, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, Parent = garage })
local garageCredits = label({ Text = "", TextColor3 = C.gold, TextSize = if isTouch then 16 else 20, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -pad - 130, 0, pad + 6), Size = UDim2.new(0, 260, 0, 30), TextXAlignment = Enum.TextXAlignment.Right, Parent = garage })
local backBtn = button("BACK", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -pad, 0, pad), Size = UDim2.new(0, 110, 0, 40), TextSize = 16, Parent = garage })
backBtn.Activated:Connect(function()
	UI.callbacks.back()
end)
local listTop = pad + 56
local list: ScrollingFrame = make("ScrollingFrame", {
	Position = UDim2.new(0, pad, 0, listTop), Size = UDim2.new(0.36, -pad, 1, -listTop - pad),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = garage,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local detail: Frame = make("Frame", { Position = UDim2.new(0.36, pad, 0, listTop), Size = UDim2.new(0.64, -2 * pad, 1, -listTop - pad), BackgroundTransparency = 1, Parent = garage })
local viewport: ViewportFrame = make("ViewportFrame", {
	Size = UDim2.new(1, 0, 0.55, 0), BackgroundColor3 = C.panel, BackgroundTransparency = 0.2,
	Ambient = Color3.fromRGB(140, 140, 160), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -1, -0.5), Parent = detail,
}, { corner(14) })
local vpCam: Camera = make("Camera", { FieldOfView = 40, Parent = viewport })
viewport.CurrentCamera = vpCam
local dName = label({ Text = "", Font = Enum.Font.GothamBlack, TextSize = if isTouch then 20 else 28, Position = UDim2.new(0, 0, 0.57, 0), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
local dTag = label({ Text = "", Font = Enum.Font.Gotham, TextColor3 = C.dim, TextSize = 14, Position = UDim2.new(0, 0, 0.57, 32), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
local statsFrame: Frame = make("Frame", { Position = UDim2.new(0, 0, 0.57, 56), Size = UDim2.new(0.62, 0, 0, 84), BackgroundTransparency = 1, Parent = detail }, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function statBar(name: string, order: number): (Frame, TextLabel)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = order, Parent = statsFrame })
	label({ Text = name, TextSize = 13, TextColor3 = C.dim, Size = UDim2.new(0, 70, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local track = make("Frame", { Position = UDim2.new(0, 74, 0.5, -4), Size = UDim2.new(1, -170, 0, 8), BackgroundColor3 = Color3.fromRGB(50, 52, 70), Parent = row }, { corner(4) })
	local fill = make("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.neon, Parent = track }, { corner(4) })
	local val = label({ Text = "", TextSize = 13, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 90, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	return fill, val
end
local powerFill, powerVal = statBar("POWER", 1)
local weightFill, weightVal = statBar("WEIGHT", 2)
local gripFill, gripVal = statBar("GRIP", 3)
local actionBtn = button("SELECT", true, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0.57, 60), Size = UDim2.new(0.34, 0, 0, 52), Parent = detail })
local garageMsg = label({ Text = "", TextColor3 = C.danger, TextSize = 14, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0.57, 118), Size = UDim2.new(0.34, 0, 0, 20), Parent = detail })

local shownId = Cars.DEFAULT
local cards: { [string]: TextButton } = {}
local previewModel: Model? = nil

local function refreshGarage()
	garageCredits.Text = "CR  " .. fmt(profile.credits)
	for id, card in cards do
		local spec = Cars.byId[id]
		local priceLbl = card:FindFirstChild("Price") :: TextLabel
		if id == profile.selected then
			priceLbl.Text = "SELECTED"
			priceLbl.TextColor3 = C.sakura
		elseif owns(id) then
			priceLbl.Text = "OWNED"
			priceLbl.TextColor3 = C.neon
		else
			priceLbl.Text = "CR " .. fmt(spec.price)
			priceLbl.TextColor3 = if profile.credits >= spec.price then C.gold else C.dim
		end
		local s = card:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = if id == shownId then C.sakura else C.dim
			s.Transparency = if id == shownId then 0 else 0.7
		end
	end
	local spec = Cars.get(shownId)
	dName.Text = spec.name
	dTag.Text = spec.tag
	powerFill.Size = UDim2.fromScale(math.clamp(spec.hp / 520, 0.05, 1), 1)
	powerVal.Text = spec.hp .. " hp · " .. spec.torque .. " Nm"
	weightFill.Size = UDim2.fromScale(math.clamp((spec.mass - 800) / 800, 0.05, 1), 1)
	weightVal.Text = fmt(spec.mass) .. " kg"
	gripFill.Size = UDim2.fromScale(math.clamp((spec.mu - 0.9) / 0.28, 0.05, 1), 1)
	gripVal.Text = string.format("μ %.2f", spec.mu)
	if spec.id == profile.selected then
		actionBtn.Text = "SELECTED"
		actionBtn.BackgroundColor3 = C.panel
		actionBtn.TextColor3 = C.dim
	elseif owns(spec.id) then
		actionBtn.Text = "SELECT"
		actionBtn.BackgroundColor3 = C.sakura
		actionBtn.TextColor3 = C.ink
	else
		actionBtn.Text = "BUY  CR " .. fmt(spec.price)
		local afford = profile.credits >= spec.price
		actionBtn.BackgroundColor3 = if afford then C.gold else C.panel
		actionBtn.TextColor3 = if afford then C.ink else C.dim
	end
end

local function showCar(id: string)
	shownId = id
	garageMsg.Text = ""
	if previewModel then
		previewModel:Destroy()
	end
	local m = CarBuilder.build(Cars.get(id))
	m.Parent = viewport
	previewModel = m
	refreshGarage()
end

for i, spec in Cars.list do
	local card = button("", false, { Size = UDim2.new(1, -6, 0, if isTouch then 52 else 64), LayoutOrder = i, Parent = list, AutoButtonColor = true })
	make("Frame", { Size = UDim2.new(0, 6, 1, -16), Position = UDim2.new(0, 10, 0, 8), BackgroundColor3 = spec.color, Parent = card }, { corner(3) })
	label({ Name = "CarName", Text = spec.name, TextSize = if isTouch then 15 else 18, Position = UDim2.new(0, 26, 0, 6), Size = UDim2.new(1, -36, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	label({ Name = "Price", Text = "", TextSize = 13, Position = UDim2.new(0, 26, 0.5, 0), Size = UDim2.new(1, -36, 0.5, -6), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	card.Activated:Connect(function()
		showCar(spec.id)
	end)
	cards[spec.id] = card
end

actionBtn.Activated:Connect(function()
	local spec = Cars.get(shownId)
	if spec.id == profile.selected then
		return
	end
	if owns(spec.id) then
		UI.callbacks.select(spec.id)
	elseif profile.credits >= spec.price then
		UI.callbacks.buy(spec.id)
	else
		garageMsg.Text = "Need CR " .. fmt(spec.price - profile.credits) .. " more"
	end
end)

local vpAngle = 0
RunService.RenderStepped:Connect(function(dt: number)
	if garage.Visible and previewModel then
		vpAngle += dt * 0.4
		local spec = Cars.get(shownId)
		local r = spec.b.len * Config.STUDS_PER_M * 1.5
		vpCam.CFrame = CFrame.lookAt(Vector3.new(math.cos(vpAngle) * r, r * 0.38, math.sin(vpAngle) * r), Vector3.new(0, 1.6, 0))
	end
end)

function UI.garageMessage(text: string)
	garageMsg.Text = text
end

-- ---------------------------------------------------------------- HUD
local hud: Frame = make("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
local inset = GuiService:GetGuiInset()
local topY = inset.Y + 8

-- drift score, top centre
local driftBox: Frame = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, topY), Size = UDim2.new(0, 360, 0, 110), BackgroundTransparency = 1, Parent = hud }, {
	make("UIScale", { Scale = if isTouch then 0.6 else 1 }),
})
local dTier = label({ Text = "DRIFT", TextColor3 = C.sakura, TextSize = 18, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 22), Parent = driftBox })
local dScore = label({ Text = "0", Font = Enum.Font.GothamBlack, TextSize = 52, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 54), TextStrokeTransparency = 0.6, Parent = driftBox })
local dMult = label({ Text = "×1.0", TextColor3 = C.sakura, TextSize = 20, Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 0, 22), Parent = driftBox })
local dTags = label({ Text = "", TextColor3 = C.neon, TextSize = 13, Position = UDim2.new(0, 0, 0, 94), Size = UDim2.new(1, 0, 0, 16), Parent = driftBox })
driftBox.Visible = false

-- right column: minimap + buttons + credits
local mapSize = if isTouch then 112 else 180
local rightCol: Frame = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, topY), Size = UDim2.new(0, mapSize, 0, mapSize + 90), BackgroundTransparency = 1, Parent = hud })
local minimap: Frame = make("Frame", { Size = UDim2.new(0, mapSize, 0, mapSize), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25, ClipsDescendants = true, Parent = rightCol }, {
	corner(12), stroke(C.dim, 0.6),
})
local btnRow: Frame = make("Frame", { Position = UDim2.new(0, 0, 0, mapSize + 6), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = rightCol }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right }),
})
local camBtn = button("CAM", false, { Size = UDim2.new(0, if isTouch then 34 else 54, 0, 30), TextSize = if isTouch then 11 else 13, Parent = btnRow })
local resetBtn = button("⟳", false, { Size = UDim2.new(0, if isTouch then 34 else 54, 0, 30), TextSize = 16, Parent = btnRow })
local menuBtn = button("MENU", false, { Size = UDim2.new(0, if isTouch then 38 else 60, 0, 30), TextSize = if isTouch then 11 else 13, Parent = btnRow })
camBtn.Activated:Connect(function()
	UI.callbacks.camera()
end)
resetBtn.Activated:Connect(function()
	UI.callbacks.reset()
end)
menuBtn.Activated:Connect(function()
	UI.callbacks.menu()
end)
local hudCredits = label({ Text = "CR 0", TextColor3 = C.gold, TextSize = if isTouch then 13 else 17, Position = UDim2.new(0, 0, 0, mapSize + 40), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.6, Parent = rightCol })

-- minimap drawing
local trackData = Track.build()
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, trackData.n do
	minX, maxX = math.min(minX, trackData.x[i]), math.max(maxX, trackData.x[i])
	minZ, maxZ = math.min(minZ, trackData.z[i]), math.max(maxZ, trackData.z[i])
end
local span = math.max(maxX - minX, maxZ - minZ) * 1.12
local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
local function mapPos(x: number, z: number): (number, number)
	return 0.5 + (x - cx) / span, 0.5 + (z - cz) / span
end
do
	local step = 3
	for i = 1, trackData.n, step do
		local j = (i + step - 1) % trackData.n + 1
		local ax, ay = mapPos(trackData.x[i], trackData.z[i])
		local bx, by = mapPos(trackData.x[j], trackData.z[j])
		local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((ax + bx) / 2, (ay + by) / 2),
			Size = UDim2.new(len + 0.004, 0, 0, if isTouch then 2 else 3),
			Rotation = math.deg(math.atan2(by - ay, bx - ax)),
			BackgroundColor3 = Color3.fromRGB(200, 200, 215),
			BorderSizePixel = 0,
			Parent = minimap,
		})
	end
	local sx, sy = mapPos(trackData.x[1], trackData.z[1])
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(sx, sy), Size = UDim2.new(0, 8, 0, 3), BackgroundColor3 = C.gold, BorderSizePixel = 0, Parent = minimap })
end
local dots: { [Model]: Frame } = {}
local function updateMinimap(myCar: Model?)
	local folder = Workspace:FindFirstChild("Cars")
	if not folder then
		return
	end
	for m, dot in dots do
		if not m.Parent then
			dot:Destroy()
			dots[m] = nil
		end
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart then
			local dot = dots[m]
			local mine = m == myCar
			if not dot then
				dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, if mine then 10 else 7, 0, if mine then 10 else 7), BackgroundColor3 = if mine then C.sakura else C.neon, ZIndex = if mine then 3 else 2, Parent = minimap }, { corner(5), stroke(C.ink, 0, 1) })
				dots[m] = dot
			end
			local p = (m.PrimaryPart :: BasePart).Position
			local x, y = mapPos(p.X, p.Z)
			dot.Position = UDim2.fromScale(x, y)
		end
	end
end

-- speedometer
local speedo: Frame = make("Frame", {
	AnchorPoint = if isTouch then Vector2.new(0.5, 1) else Vector2.new(1, 1),
	Position = if isTouch then UDim2.new(0.5, 0, 1, -10) else UDim2.new(1, -16, 1, -16),
	Size = UDim2.new(0, 236, 0, 104), BackgroundColor3 = C.ink, BackgroundTransparency = 0.3, Parent = hud,
}, { corner(14), stroke(C.dim, 0.7), make("UIScale", { Scale = if isTouch then 0.7 else 1 }) })
local speedLbl = label({ Text = "0", Font = Enum.Font.GothamBlack, TextSize = 56, Position = UDim2.new(0, 14, 0, 4), Size = UDim2.new(0, 130, 0, 60), TextXAlignment = Enum.TextXAlignment.Right, Parent = speedo })
label({ Text = "km/h", TextColor3 = C.dim, TextSize = 14, Position = UDim2.new(0, 148, 0, 38), Size = UDim2.new(0, 40, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = speedo })
local gearBox: Frame = make("Frame", { Position = UDim2.new(1, -54, 0, 10), Size = UDim2.new(0, 42, 0, 48), BackgroundColor3 = C.panel, Parent = speedo }, { corner(8), stroke(C.sakura, 0.3) })
local gearLbl = label({ Text = "N", Font = Enum.Font.GothamBlack, TextSize = 32, TextColor3 = C.sakura, Size = UDim2.fromScale(1, 1), Parent = gearBox })
local rpmTrack: Frame = make("Frame", { Position = UDim2.new(0, 14, 0, 72), Size = UDim2.new(1, -28, 0, 10), BackgroundColor3 = Color3.fromRGB(40, 42, 60), Parent = speedo }, { corner(5) })
local rpmFill: Frame = make("Frame", { Size = UDim2.fromScale(0.1, 1), BackgroundColor3 = C.neon, Parent = rpmTrack }, { corner(5) })
make("Frame", { Position = UDim2.fromScale(0.88, 0), Size = UDim2.new(0.12, 0, 1, 0), BackgroundColor3 = C.danger, BackgroundTransparency = 0.6, Parent = rpmTrack }, { corner(5) })
local rpmLbl = label({ Text = "0 rpm", TextColor3 = C.dim, TextSize = 12, Position = UDim2.new(0, 14, 0, 84), Size = UDim2.new(1, -28, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = speedo })

-- toast
local toast = label({ Text = "", Font = Enum.Font.GothamBlack, TextSize = if isTouch then 20 else 28, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.26, 0), Size = UDim2.new(0.8, 0, 0, 34), TextStrokeTransparency = 0.5, TextTransparency = 1, TextStrokeColor3 = C.ink, Parent = gui })
local toastSmall = label({ Text = "", Font = Enum.Font.GothamBold, TextSize = 14, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if isTouch then -90 else -24), Size = UDim2.new(0.8, 0, 0, 20), TextColor3 = C.neon, TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
local toastId = 0
function UI.toast(text: string, color: Color3?)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or C.gold
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.5
	task.delay(2.2, function()
		if toastId == id then
			toast.TextTransparency = 1
			toast.TextStrokeTransparency = 1
		end
	end)
end
local smallId = 0
function UI.notice(text: string)
	smallId += 1
	local id = smallId
	toastSmall.Text = text
	toastSmall.TextTransparency = 0
	task.delay(4, function()
		if smallId == id then
			toastSmall.TextTransparency = 1
		end
	end)
end

-- ---------------------------------------------------------------- touch controls
local touchLayer: Frame = make("Frame", { Name = "Touch", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = hud })
local stickBase: Frame = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -28), Size = UDim2.new(0, 150, 0, 150), BackgroundColor3 = C.ink, BackgroundTransparency = 0.45, Active = true, Parent = touchLayer }, {
	corner(75), stroke(C.dim, 0.5, 2),
})
local knob: Frame = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 62, 0, 62), BackgroundColor3 = C.text, BackgroundTransparency = 0.2, Parent = stickBase }, { corner(31) })
local function pedal(text: string, size: Vector2, pos: UDim2, color: Color3): TextButton
	return button(text, false, { AnchorPoint = Vector2.new(1, 1), Position = pos, Size = UDim2.new(0, size.X, 0, size.Y), BackgroundColor3 = color, BackgroundTransparency = 0.35, TextSize = 16, AutoButtonColor = false, Parent = touchLayer })
end
local gasBtn = pedal("GAS", Vector2.new(104, 120), UDim2.new(1, -24, 1, -24), Color3.fromRGB(40, 140, 90))
local brakeBtn = pedal("BRAKE", Vector2.new(86, 92), UDim2.new(1, -140, 1, -24), Color3.fromRGB(150, 50, 60))
local hbBtn = pedal("HB", Vector2.new(104, 62), UDim2.new(1, -24, 1, -156), C.panel)

local stickInput: InputObject? = nil
local held: { [InputObject]: string } = {}
local function recomputePedals()
	local t = Input.touch
	t.throttle, t.brake, t.handbrake = 0, 0, false
	for _, what in held do
		if what == "gas" then
			t.throttle = 1
		elseif what == "brake" then
			t.brake = 1
		elseif what == "hb" then
			t.handbrake = true
		end
	end
	gasBtn.BackgroundTransparency = if t.throttle > 0 then 0.05 else 0.35
	brakeBtn.BackgroundTransparency = if t.brake > 0 then 0.05 else 0.35
	hbBtn.BackgroundTransparency = if t.handbrake then 0.05 else 0.35
end
local function bindPedal(b: GuiObject, what: string)
	b.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			held[io] = what
			recomputePedals()
		end
	end)
end
bindPedal(gasBtn, "gas")
bindPedal(brakeBtn, "brake")
bindPedal(hbBtn, "hb")
local function setStick(pos: Vector3)
	local centre = stickBase.AbsolutePosition + stickBase.AbsoluteSize / 2
	local r = stickBase.AbsoluteSize.X / 2
	local dx = math.clamp((pos.X - centre.X) / r, -1, 1)
	local dy = math.clamp((pos.Y - centre.Y) / r, -1, 1)
	knob.Position = UDim2.new(0.5, dx * r * 0.7, 0.5, dy * r * 0.35)
	Input.touch.steer = if math.abs(dx) < 0.08 then 0 else dx
	Input.touch.steerActive = true
end
stickBase.InputBegan:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
		stickInput = io
		setStick(io.Position)
	end
end)
UserInputService.InputChanged:Connect(function(io)
	if io == stickInput then
		setStick(io.Position)
	elseif stickInput and stickInput.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputType == Enum.UserInputType.MouseMovement then
		setStick(io.Position)
	end
end)
UserInputService.TouchMoved:Connect(function(io)
	if io == stickInput then
		setStick(io.Position)
	end
end)
local function release(io: InputObject)
	if io == stickInput or (stickInput and stickInput.UserInputType == io.UserInputType and io.UserInputType == Enum.UserInputType.MouseButton1) then
		stickInput = nil
		knob.Position = UDim2.fromScale(0.5, 0.5)
		Input.touch.steer = 0
		Input.touch.steerActive = false
	end
	for h in held do
		if h == io or (h.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputType == Enum.UserInputType.MouseButton1) then
			held[h] = nil
		end
	end
	recomputePedals()
end
UserInputService.InputEnded:Connect(release)
UserInputService.TouchEnded:Connect(function(io)
	release(io)
end)

-- ---------------------------------------------------------------- screens
local function selectFor(obj: GuiObject?)
	if Input.lastDevice == "gamepad" then
		GuiService.SelectedObject = obj
	end
end

function UI.showTitle()
	title.Visible, garage.Visible, hud.Visible = true, false, false
	selectFor(playBtn)
end

function UI.showGarage()
	title.Visible, garage.Visible, hud.Visible = false, true, false
	showCar(profile.selected)
	selectFor(cards[profile.selected])
end

function UI.showHUD()
	title.Visible, garage.Visible, hud.Visible = false, false, true
	touchLayer.Visible = isTouch or Input.lastDevice == "touch"
	GuiService.SelectedObject = nil
end

function UI.setProfile(p: Profile)
	profile = p
	titleStats.Text = string.format("CR %s   ·   BEST %s", fmt(p.credits), fmt(p.best))
	hudCredits.Text = "CR " .. fmt(p.credits)
	easyBtn.Text = if p.easyDrift then "EASY DRIFT: ON" else "EASY DRIFT: OFF"
	easyBtn.TextColor3 = if p.easyDrift then C.neon else C.dim
	if garage.Visible then
		refreshGarage()
	end
end

function UI.setMapReady(ready: boolean)
	status.Text = if ready then "" else "Building the mountain pass…"
	playBtn.AutoButtonColor = ready
	playBtn.BackgroundTransparency = if ready then 0 else 0.6
end

export type DriftView = { active: boolean, score: number, mult: number, tags: { string } }
function UI.updateHUD(tel: any, drift: DriftView, myCar: Model?)
	speedLbl.Text = tostring(math.floor(tel.kmh + 0.5))
	gearLbl.Text = tel.gear
	local frac = math.clamp(tel.rpm / tel.red, 0, 1)
	rpmFill.Size = UDim2.fromScale(frac, 1)
	rpmFill.BackgroundColor3 = if frac > 0.88 then C.danger elseif frac > 0.7 then C.gold else C.neon
	rpmLbl.Text = fmt(math.floor(tel.rpm / 50) * 50) .. " rpm"
	driftBox.Visible = drift.active
	if drift.active then
		local total = math.floor(drift.score * drift.mult)
		dTier.Text = Config.tierFor(total)
		dScore.Text = fmt(drift.score)
		dMult.Text = string.format("×%.1f", drift.mult)
		dTags.Text = table.concat(drift.tags, "  ·  ")
	end
	updateMinimap(myCar)
end

return UI
