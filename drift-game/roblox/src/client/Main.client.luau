-- Kaido Drift (Roblox) client: menus, garage, HUD, controls (keyboard, controller, touch),
-- the drift car, scoring and the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local CarModel = require(Shared:WaitForChild("CarModel"))
local R = ReplicatedStorage:WaitForChild("KaidoRemotes")

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

-- ===================== UI helpers =====================
local PINK, CYAN, GOLD = Color3.fromRGB(255, 126, 182), Color3.fromRGB(89, 227, 255), Color3.fromRGB(255, 201, 77)
local INK, PANEL = Color3.fromRGB(12, 13, 22), Color3.fromRGB(16, 18, 30)

local function make(class, props, children)
	local o = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then (o :: any)[k] = v end
	end
	for _, c in children or {} do c.Parent = o end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(r) return make("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function stroke(c, t) return make("UIStroke", { Color = c, Thickness = t or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextScaled = props.TextScaled ~= false
	return make("TextLabel", props)
end
local function button(text, sub, color, parent, order)
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, sub and 62 or 48), BackgroundColor3 = color or PANEL, AutoButtonColor = true,
		Text = "", LayoutOrder = order or 0, Parent = parent,
	}, { corner(6), stroke(color == PANEL and Color3.fromRGB(70, 74, 100) or color, 1.5) })
	label({ Text = text, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.new(0, 12, 0, sub and 9 or 12), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack, TextColor3 = (color == PINK) and INK or Color3.new(1, 1, 1), Parent = b })
	if sub then
		label({ Text = sub, Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 12, 0, 37), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextColor3 = (color == PINK) and INK or Color3.fromRGB(190, 194, 214), Parent = b })
	end
	return b
end

local gui = make("ScreenGui", { Name = "KaidoUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

local loading = label({ Text = "Building the mountain pass…", Size = UDim2.new(0, 360, 0, 28), Position = UDim2.new(0.5, -180, 0.5, -14), Parent = gui })
local mapFolder = workspace:WaitForChild("KaidoMap")
while not mapFolder:GetAttribute("Ready") do task.wait(0.2) end

local profile = R.GetProfile:InvokeServer()
loading:Destroy()

-- ===================== state =====================
local mode = "menu" -- menu | garage | play
local publicMap = false
local easy = true
local camMode = 0 -- 0 chase, 1 far chase, 2 cockpit
local carDef = Config.car(profile.selected)
local carPhys = Config.physics(carDef)
local startH = Track.heading(1)
local S = CarPhysics.new(Track.X[1], Track.Z[1], startH)
local idx, posY = 1, Track.Y[1]
local carModel: Model? = nil
local input = { thr = 0, brk = 0, hand = false, steer = 0 }
local drift = { active = false, score = 0, mult = 1, t = 0, off = 0 }
local wallT = 0

local function owned(id)
	for _, o in profile.owned do if o == id then return true end end
	return false
end

local function spawnCar()
	if carModel then carModel:Destroy() end
	carDef = Config.car(profile.selected)
	carPhys = Config.physics(carDef)
	carModel = CarModel.build(carDef, "MyCar")
	carModel.Parent = workspace
	-- tyre smoke
	for _, a in carModel.PrimaryPart:GetChildren() do
		if a:IsA("Attachment") then
			make("ParticleEmitter", {
				Name = "Smoke", Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 0, Enabled = true,
				Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(40, 40),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 12) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
				Color = ColorSequence.new(Color3.fromRGB(220, 222, 230)), Drag = 1.5, Acceleration = Vector3.new(0, 3, 0),
				LightInfluence = 1, Parent = a,
			})
		end
	end
end

local function resetCar(i)
	i = i or Track.nearest(S.x, S.z, idx)
	local h = Track.heading(i)
	S = CarPhysics.new(Track.X[i], Track.Z[i], h)
	idx, posY = i, Track.Y[i]
	drift.active, drift.score, drift.mult = false, 0, 1
end

-- ===================== title screen =====================
local title = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.35, Parent = gui })
local tCol = make("Frame", { Size = UDim2.new(0, 380, 1, 0), Position = UDim2.new(0, 40, 0, 0), BackgroundTransparency = 1, Parent = title }, {
	make("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UISizeConstraint", { MaxSize = Vector2.new(380, math.huge) }),
})
if touch then tCol.Size = UDim2.new(0.86, 0, 1, 0); tCol.Position = UDim2.new(0.07, 0, 0, 0) end
label({ Text = "KAIDO DRIFT", Size = UDim2.new(1, 0, 0, 54), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = tCol })
label({ Text = "街道 · 峠  —  midnight on the mountain pass", Size = UDim2.new(1, 0, 0, 20), TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = tCol })
local tStats = label({ Text = "", Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Gotham, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, Parent = tCol })
local bSolo = button("PLAY SOLO", "Just you on the mountain", PINK, tCol, 4)
local bPublic = button("PLAY WITH OTHERS", "Public map · drift with everyone in this server + chat", PANEL, tCol, 5)
bPublic:FindFirstChildOfClass("UIStroke").Color = CYAN
local bGarage = button("GARAGE", "Unlock and choose cars", PANEL, tCol, 6)
local bEasy = button("EASY DRIFT: ON", "Steer hard with gas to slide · no hand brake needed", PANEL, tCol, 7)
label({
	Text = touch and "Drag on the left to steer · GAS, BRAKE, HAND on the right" or "W/S gas & brake · A/D steer · Space hand brake · C camera · R reset · controllers work too",
	Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(170, 174, 196), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, LayoutOrder = 8, Parent = tCol,
})

local function fmt(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end
local function refreshTitle()
	tStats.Text = string.format("%s CR   ·   best drift %s   ·   %s", fmt(profile.credits), fmt(profile.best), Config.car(profile.selected).name)
end
refreshTitle()

-- ===================== garage =====================
local garage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.2, Visible = false, Parent = gui })
local gBox = make("Frame", { Size = UDim2.new(0.9, 0, 0.86, 0), Position = UDim2.new(0.05, 0, 0.07, 0), BackgroundTransparency = 1, Parent = garage }, {
	make("UISizeConstraint", { MaxSize = Vector2.new(560, math.huge) }),
})
label({ Text = "GARAGE", Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = gBox })
local gCredits = label({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 42), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = gBox })
local gList = make("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -130), Position = UDim2.new(0, 0, 0, 70), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = gBox }, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local gBack = button("BACK", nil, PANEL, gBox, 0)
gBack.Position = UDim2.new(0, 0, 1, -50)

local function bar(v)
	local n = math.clamp(math.floor(v * 10 + 0.5), 1, 10)
	return string.rep("■", n) .. string.rep("□", 10 - n)
end
local function renderGarage()
	gCredits.Text = fmt(profile.credits) .. " CR"
	for _, c in gList:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	for k, car in Config.Cars do
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 92), BackgroundColor3 = PANEL, LayoutOrder = k, Parent = gList }, { corner(6), stroke(car.id == profile.selected and PINK or Color3.fromRGB(60, 64, 90), 1.5) })
		make("Frame", { Size = UDim2.new(0, 10, 1, -16), Position = UDim2.new(0, 8, 0, 8), BackgroundColor3 = car.color, Parent = row }, { corner(3) })
		label({ Text = car.name, Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.new(0, 28, 0, 8), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		label({ Text = "POWER " .. bar(car.power / 1650) .. "\nGRIP  " .. bar((car.grip - 0.9) / 0.2) .. "\nTOP   " .. car.top .. " km/h", Size = UDim2.new(0.6, 0, 0, 48), Position = UDim2.new(0, 28, 0, 34), Font = Enum.Font.Code, TextColor3 = Color3.fromRGB(190, 194, 214), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local have = owned(car.id)
		local txt = car.id == profile.selected and "SELECTED" or have and "SELECT" or (fmt(car.price) .. " CR")
		local can = have or profile.credits >= car.price
		local b = make("TextButton", { Size = UDim2.new(0.32, 0, 0, 40), Position = UDim2.new(0.66, 0, 0.5, -20), BackgroundColor3 = (have or can) and PINK or Color3.fromRGB(50, 52, 66), AutoButtonColor = true, Text = txt, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = INK, Parent = row }, { corner(6), make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }) })
		b.Activated:Connect(function()
			if car.id == profile.selected then return end
			local res = have and R.Select:InvokeServer(car.id) or (can and R.Buy:InvokeServer(car.id))
			if res then profile = res; spawnCar(); resetCar(1); renderGarage(); refreshTitle() end
		end)
	end
end

-- ===================== HUD =====================
local hud = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
local hCredits = label({ Text = "", Size = UDim2.new(0, 220, 0, 24), Position = UDim2.new(0, 16, 0, 14), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = hud })
local hMode = label({ Text = "", Size = UDim2.new(0, 260, 0, 16), Position = UDim2.new(0, 16, 0, 40), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(190, 194, 214), TextXAlignment = Enum.TextXAlignment.Left, Parent = hud })
-- drift score: compact, top centre (small on phones so it never covers the road)
local dW = touch and 150 or 260
local dBox = make("Frame", { Size = UDim2.new(0, dW, 0, touch and 64 or 96), Position = UDim2.new(0.5, -dW / 2, 0, touch and 8 or 14), BackgroundTransparency = 1, Visible = false, Parent = hud })
local dTier = label({ Text = "DRIFT", Size = UDim2.new(0.6, 0, 0.22, 0), TextColor3 = GOLD, Parent = dBox })
local dMult = label({ Text = "×1.0", Size = UDim2.new(0.4, 0, 0.22, 0), Position = UDim2.new(0.6, 0, 0, 0), TextColor3 = PINK, Parent = dBox })
local dScore = label({ Text = "0", Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.26, 0), Font = Enum.Font.GothamBlack, Parent = dBox }, nil)
make("UIStroke", { Color = INK, Thickness = 2, Parent = dScore })
local toast = label({ Text = "", Size = UDim2.new(0, 360, 0, 26), Position = UDim2.new(0.5, -180, 0, touch and 76 or 116), TextColor3 = GOLD, TextTransparency = 1, Parent = hud })
local toastT = 0
local function showToast(t, c)
	toast.Text, toast.TextColor3, toast.TextTransparency, toastT = t, c or GOLD, 0, 2
end
-- speed
local sp = make("Frame", { Size = UDim2.new(0, 170, 0, 74), Position = touch and UDim2.new(0, 16, 1, -250) or UDim2.new(0.5, -85, 1, -92), BackgroundTransparency = 1, Parent = hud })
local hSpeed = label({ Text = "0", Size = UDim2.new(0.62, 0, 0.7, 0), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right, Parent = sp })
label({ Text = "KM/H", Size = UDim2.new(0.34, 0, 0.26, 0), Position = UDim2.new(0.66, 0, 0.08, 0), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(190, 194, 214), TextXAlignment = Enum.TextXAlignment.Left, Parent = sp })
local hGear = label({ Text = "1", Size = UDim2.new(0.34, 0, 0.36, 0), Position = UDim2.new(0.66, 0, 0.36, 0), TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Left, Parent = sp })
local rpmBack = make("Frame", { Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 1, -5), BackgroundColor3 = Color3.fromRGB(40, 42, 60), BorderSizePixel = 0, Parent = sp })
local rpmBar = make("Frame", { Size = UDim2.new(0.2, 0, 1, 0), BackgroundColor3 = PINK, BorderSizePixel = 0, Parent = rpmBack })
-- minimap
local mmSize = touch and 96 or 140
local mm = make("Frame", { Size = UDim2.new(0, mmSize, 0, mmSize), Position = UDim2.new(1, -mmSize - 14, 0, 14), BackgroundColor3 = INK, BackgroundTransparency = 0.35, Parent = hud }, { corner(mmSize), stroke(Color3.fromRGB(70, 74, 100), 1) })
local mmMinX, mmMaxX, mmMinZ, mmMaxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, Track.N do
	mmMinX, mmMaxX = math.min(mmMinX, Track.X[i]), math.max(mmMaxX, Track.X[i])
	mmMinZ, mmMaxZ = math.min(mmMinZ, Track.Z[i]), math.max(mmMaxZ, Track.Z[i])
end
local mmSpan = math.max(mmMaxX - mmMinX, mmMaxZ - mmMinZ) * 1.15
local function mmPos(x, z)
	return UDim2.new(0.5 + (x - (mmMinX + mmMaxX) / 2) / mmSpan, 0, 0.5 + (z - (mmMinZ + mmMaxZ) / 2) / mmSpan, 0)
end
for i = 1, Track.N, math.max(1, Track.N // 140) do
	make("Frame", { Size = UDim2.new(0, 3, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = mmPos(Track.X[i], Track.Z[i]), BackgroundColor3 = Color3.fromRGB(235, 230, 220), BorderSizePixel = 0, Parent = mm })
end
local mmMe = make("Frame", { Size = UDim2.new(0, 9, 0, 9), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = PINK, BorderSizePixel = 0, ZIndex = 3, Parent = mm }, { corner(9) })
-- buttons under the minimap
local hb = make("Frame", { Size = UDim2.new(0, 3 * 62, 0, 40), Position = UDim2.new(1, -3 * 62 - 14, 0, mmSize + 22), BackgroundTransparency = 1, Parent = hud }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }),
})
local function smallBtn(t)
	return make("TextButton", { Size = UDim2.new(0, 56, 0, 40), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2, Text = t, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14, Parent = hb }, { corner(6), stroke(Color3.fromRGB(70, 74, 100), 1) })
end
local bCam, bReset, bMenu = smallBtn("CAM"), smallBtn("↺"), smallBtn("MENU")

-- ===================== touch controls =====================
local touchState = { gas = false, brake = false, hand = false, steer = 0 }
if touch then
	local steerZone = make("Frame", { Size = UDim2.new(0.5, 0, 0.62, 0), Position = UDim2.new(0, 0, 0.38, 0), BackgroundTransparency = 1, Parent = hud })
	local knobBase = make("Frame", { Size = UDim2.new(0, 160, 0, 52), Position = UDim2.new(0, 24, 1, -80), BackgroundColor3 = PANEL, BackgroundTransparency = 0.4, Parent = hud }, { corner(26), stroke(Color3.fromRGB(70, 74, 100), 1) })
	local knob = make("Frame", { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0.5, -22, 0, 4), BackgroundColor3 = CYAN, BackgroundTransparency = 0.2, Parent = knobBase }, { corner(22) })
	local steerInput, startX = nil, 0
	steerZone.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch and not steerInput then steerInput, startX = io, io.Position.X end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if io == steerInput then touchState.steer = math.clamp((io.Position.X - startX) / 70, -1, 1) end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io == steerInput then steerInput = nil; touchState.steer = 0 end
	end)
	RunService.RenderStepped:Connect(function()
		knob.Position = UDim2.new(0.5, -22 + touchState.steer * 54, 0, 4)
	end)
	local function pedal(text, size, pos, color, key)
		local b = make("TextButton", { Size = size, Position = pos, BackgroundColor3 = color, BackgroundTransparency = 0.25, Text = text, TextColor3 = INK, Font = Enum.Font.GothamBlack, TextSize = 16, Parent = hud }, { corner(10) })
		local held = {}
		b.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch then held[io] = true; touchState[key] = true end
		end)
		b.InputEnded:Connect(function(io)
			held[io] = nil
			if next(held) == nil then touchState[key] = false end
		end)
	end
	pedal("GAS", UDim2.new(0, 88, 0, 150), UDim2.new(1, -104, 1, -166), PINK, "gas")
	pedal("BRAKE", UDim2.new(0, 80, 0, 70), UDim2.new(1, -196, 1, -86), Color3.fromRGB(200, 204, 220), "brake")
	pedal("HAND", UDim2.new(0, 80, 0, 70), UDim2.new(1, -196, 1, -166), CYAN, "hand")
end

-- ===================== other players (public map) =====================
local ghosts = {}
R.Others.OnClientEvent:Connect(function(uid, x, y, z, h, carId, drifting)
	if not publicMap or mode ~= "play" then return end
	local g = ghosts[uid]
	if not g or g.carId ~= carId then
		if g then g.model:Destroy() end
		local m = CarModel.build(Config.car(carId), "Ghost" .. uid)
		local who = Players:GetPlayerByUserId(uid)
		local tag = make("BillboardGui", { Size = UDim2.new(0, 140, 0, 26), StudsOffset = Vector3.new(0, 8, 0), AlwaysOnTop = true, MaxDistance = 400, Parent = m.PrimaryPart })
		label({ Text = who and who.DisplayName or "Driver", Size = UDim2.fromScale(1, 1), TextColor3 = CYAN, Parent = tag })
		m.Parent = workspace
		g = { model = m, carId = carId, cf = CFrame.new(x, y, z) * CFrame.Angles(0, h + math.pi, 0) }
		ghosts[uid] = g
	end
	g.target = CFrame.new(x, y, z) * CFrame.Angles(0, h + math.pi, 0) -- car forward is (sin h, cos h)
	g.seen = os.clock()
end)
local function clearGhosts()
	for uid, g in ghosts do g.model:Destroy(); ghosts[uid] = nil end
end
Players.PlayerRemoving:Connect(function(p)
	local g = ghosts[p.UserId]
	if g then g.model:Destroy(); ghosts[p.UserId] = nil end
end)

-- ===================== screens =====================
local function setMode(m)
	mode = m
	title.Visible = m == "menu"
	garage.Visible = m == "garage"
	hud.Visible = m == "play"
	if m ~= "play" then clearGhosts() end
	if m == "garage" then renderGarage() end
	if m == "menu" then refreshTitle() end
end
local function start(public)
	publicMap = public
	R.SetMode:FireServer(public and "public" or "solo")
	hMode.Text = public and "PUBLIC MAP · everyone in this server" or "SOLO · just you"
	setMode("play")
	if public then showToast("Public map · say hi in chat!", CYAN) end
end
bSolo.Activated:Connect(function() start(false) end)
bPublic.Activated:Connect(function() start(true) end)
bGarage.Activated:Connect(function() setMode("garage") end)
gBack.Activated:Connect(function() setMode("menu") end)
bEasy.Activated:Connect(function()
	easy = not easy
	bEasy:FindFirstChildWhichIsA("TextLabel").Text = easy and "EASY DRIFT: ON" or "EASY DRIFT: OFF (sim)"
end)
bMenu.Activated:Connect(function()
	R.SetMode:FireServer("solo")
	setMode("menu")
end)
local function cycleCam()
	camMode = (camMode + 1) % 3
	showToast(({ "Chase camera", "Far chase", "Cockpit · first person" })[camMode + 1], Color3.new(1, 1, 1))
end
bCam.Activated:Connect(cycleCam)
bReset.Activated:Connect(function() resetCar() end)
UserInputService.InputBegan:Connect(function(io, processed)
	if processed or mode ~= "play" then return end
	if io.KeyCode == Enum.KeyCode.C or io.KeyCode == Enum.KeyCode.V or io.KeyCode == Enum.KeyCode.ButtonY then cycleCam() end
	if io.KeyCode == Enum.KeyCode.R or io.KeyCode == Enum.KeyCode.ButtonSelect then resetCar() end
end)

-- ===================== input =====================
local function readInput(dt)
	local thr, brk, hand, steer = 0, 0, false, 0
	if not UserInputService:GetFocusedTextBox() then
		local k = UserInputService
		if k:IsKeyDown(Enum.KeyCode.W) or k:IsKeyDown(Enum.KeyCode.Up) then thr = 1 end
		if k:IsKeyDown(Enum.KeyCode.S) or k:IsKeyDown(Enum.KeyCode.Down) then brk = 1 end
		if k:IsKeyDown(Enum.KeyCode.A) or k:IsKeyDown(Enum.KeyCode.Left) then steer -= 1 end
		if k:IsKeyDown(Enum.KeyCode.D) or k:IsKeyDown(Enum.KeyCode.Right) then steer += 1 end
		hand = k:IsKeyDown(Enum.KeyCode.Space)
	end
	local okPad, pad = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
	for _, io in (okPad and pad or {}) do
		if io.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(io.Position.X) > 0.12 then steer = io.Position.X end
		if io.KeyCode == Enum.KeyCode.ButtonR2 then thr = math.max(thr, io.Position.Z) end
		if io.KeyCode == Enum.KeyCode.ButtonL2 then brk = math.max(brk, io.Position.Z) end
		if (io.KeyCode == Enum.KeyCode.ButtonX or io.KeyCode == Enum.KeyCode.ButtonA) and io.UserInputState == Enum.UserInputState.Begin then hand = true end
	end
	if touch then
		if touchState.gas then thr = 1 end
		if touchState.brake then brk = 1 end
		if touchState.hand then hand = true end
		if touchState.steer ~= 0 then steer = touchState.steer end
	end
	-- keys and buttons are on/off: ramp the steering so it feels smooth
	input.steer += math.clamp(steer - input.steer, -dt * 5, dt * 5)
	input.thr, input.brk, input.hand = thr, brk, hand
end

-- ===================== drift scoring =====================
local TIERS = { { 0, "DRIFT" }, { 1500, "NICE" }, { 5000, "GREAT" }, { 12000, "KAIDO" }, { 25000, "LEGEND" } }
local function endDrift(keep)
	if drift.active and drift.score > 0 then
		local pts = math.floor(drift.score * drift.mult)
		if keep and pts >= 50 then
			R.Bank:FireServer(pts)
			profile.credits += pts
			profile.best = math.max(profile.best, pts)
			showToast("+" .. fmt(pts) .. " CR", GOLD)
		elseif not keep then
			showToast("Crashed · drift lost", Color3.fromRGB(255, 90, 90))
		end
	end
	drift.active, drift.score, drift.mult, drift.t, drift.off = false, 0, 1, 0, 0
end
local function updateDrift(dt)
	local kmh = CarPhysics.kmh(S.speed)
	local ang = math.abs(S.beta) * 57.3
	if ang > 10 and kmh > 25 and ang < 110 then
		drift.active = true
		drift.off = 0
		drift.t += dt
		drift.score += ang * kmh * 0.03 * dt * 10
		drift.mult = math.min(5, 1 + drift.t * 0.2)
	elseif drift.active then
		drift.off += dt
		if drift.off > 0.7 then endDrift(true) end
	end
end

-- ===================== main loop =====================
local camPos = camera.CFrame.Position
local sendT, orbit, smokeOn = 0, 0, false
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.05)
	if not carModel then spawnCar() end
	local m = carModel :: Model

	if mode == "play" then
		readInput(dt)
		local steps = math.max(1, math.ceil(dt * 120))
		for _ = 1, steps do CarPhysics.step(S, input, carPhys, easy, dt / steps) end
		-- stay on the road: guardrails
		idx = Track.nearest(S.x, S.z, idx)
		local lat, y = Track.at(S.x, S.z, idx)
		local lim = Config.ROAD_HALF - 3.4
		if math.abs(lat) > lim then
			local rx, rz = Track.RX[idx], Track.RZ[idx]
			local sgn = lat > 0 and 1 or -1
			S.x -= rx * (math.abs(lat) - lim) * sgn
			S.z -= rz * (math.abs(lat) - lim) * sgn
			local vn = S.vx * rx + S.vz * rz
			if vn * sgn > 0 then
				S.vx -= rx * vn * 1.35; S.vz -= rz * vn * 1.35
				S.vx *= 0.9; S.vz *= 0.9
				S.r *= 0.5
				if math.abs(vn) > 12 and wallT <= 0 then endDrift(false); wallT = 0.6 end
			end
		end
		wallT -= dt
		posY += (y - posY) * math.min(1, dt * 20)
		updateDrift(dt)
		if UserInputService:IsKeyDown(Enum.KeyCode.Backspace) then resetCar() end

		-- HUD
		local kmh = CarPhysics.kmh(S.speed)
		hSpeed.Text = tostring(math.floor(kmh))
		local band = carDef.top / 6
		local gear = math.clamp(math.floor(kmh / band) + 1, 1, 6)
		if S.u < -1 then gear = 0 end
		hGear.Text = gear == 0 and "R" or tostring(gear)
		local rpm = (S.spin or input.hand) and 0.95 or math.clamp((kmh - (gear - 1) * band) / band, 0, 1) * 0.75 + 0.2
		rpmBar.Size = UDim2.new(rpm, 0, 1, 0)
		hCredits.Text = fmt(profile.credits) .. " CR"
		dBox.Visible = drift.active
		if drift.active then
			local pts = drift.score * drift.mult
			dScore.Text = fmt(pts)
			dMult.Text = string.format("×%.1f", drift.mult)
			local tier = "DRIFT"
			for _, t in TIERS do if pts >= t[1] then tier = t[2] end end
			dTier.Text = tier
		end
		mmMe.Position = mmPos(S.x, S.z)
		if toastT > 0 then toastT -= dt; if toastT < 0.5 then toast.TextTransparency = 1 - toastT * 2 end end

		-- tell the server where we are (public map only)
		sendT += dt
		if publicMap and sendT > 0.1 then
			sendT = 0
			R.State:FireServer(S.x, posY, S.z, S.h, carDef.id, drift.active)
		end
	end

	-- place the car on the road, pitched with the slope
	local fx, fz = math.sin(S.h), math.cos(S.h)
	local slope = Track.slope(idx)
	local pos = Vector3.new(S.x, posY, S.z)
	local fwd = Vector3.new(fx, slope, fz).Unit
	local roll = math.clamp(-S.r * CarPhysics.kmh(S.speed) * 0.0006, -0.06, 0.06)
	local cf = CFrame.lookAt(pos, pos + fwd) * CFrame.Angles(0, 0, roll)
	CarModel.place(m, cf, S.delta)

	-- tyre smoke while sliding or spinning
	local smoking = mode == "play" and S.speed > 8 and (math.abs(S.beta) > 0.2 or S.spin)
	if smoking ~= smokeOn then
		smokeOn = smoking
		for _, a in m.PrimaryPart:GetChildren() do
			local e = a:FindFirstChild("Smoke")
			if e then e.Rate = smoking and 45 or 0 end
		end
	end

	-- other players glide to their latest positions; drop anyone silent for 3 s
	for uid, g in ghosts do
		if os.clock() - g.seen > 3 then
			g.model:Destroy(); ghosts[uid] = nil
		else
			g.cf = g.cf:Lerp(g.target, math.min(1, dt * 10))
			CarModel.place(g.model, g.cf, 0)
		end
	end

	-- camera
	if mode ~= "play" then
		orbit += dt * 0.15
		local r = mode == "garage" and 26 or 34
		local eye = pos + Vector3.new(math.sin(S.h + orbit) * r, 9, math.cos(S.h + orbit) * r)
		camera.CFrame = CFrame.lookAt(eye, pos + Vector3.new(0, 3, 0))
		camera.FieldOfView = 55
		CarModel.setCabinVisible(m, true)
	elseif camMode == 2 then
		CarModel.setCabinVisible(m, false)
		local eye = cf * CFrame.new(1.3, 4.0, 0.6)
		camera.CFrame = eye * CFrame.Angles(math.rad(-4), math.clamp(-S.beta * 0.5, -0.6, 0.6), 0)
		camera.FieldOfView = math.clamp(70 + CarPhysics.kmh(S.speed) * 0.08, 70, 88)
	else
		CarModel.setCabinVisible(m, true)
		local sp2 = S.speed
		local dx, dz = fx, fz
		if sp2 > 10 then
			local vx, vz = S.vx / sp2, S.vz / sp2
			dx, dz = fx * 0.45 + vx * 0.55, fz * 0.45 + vz * 0.55
			local l = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / l, dz / l
		end
		local dist = camMode == 1 and 34 or 22
		local hgt = camMode == 1 and 12 or 7.5
		local target = pos - Vector3.new(dx, 0, dz) * (dist + sp2 * 0.04) + Vector3.new(0, hgt, 0)
		if (camPos - target).Magnitude > 120 then camPos = target end
		camPos = camPos:Lerp(target, math.min(1, dt * 6))
		camera.CFrame = CFrame.lookAt(camPos, pos + Vector3.new(fx, 0, fz) * 8 + Vector3.new(0, 3, 0))
		camera.FieldOfView = math.clamp(62 + CarPhysics.kmh(sp2) * 0.12, 62, 85)
	end
end)

setMode("menu")
