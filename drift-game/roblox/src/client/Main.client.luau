-- Kaido Drift (Roblox) client: title, garage, settings and pause screens in the browser game's style,
-- the HUD, controls (keyboard, controller, touch), drift scoring, laps, cameras, graphics levels,
-- time of day and engine sound. Progress and settings live on Roblox's servers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local CarModel = require(Shared:WaitForChild("CarModel"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local make, text, fmt = Ui.make, Ui.text, Ui.fmt

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local gui = make("ScreenGui", { Name = "KaidoUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

-- ===================== loading =====================
local loading = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.INK, ZIndex = 50, Parent = gui })
text({ Text = 'KAIDO <font color="#ff7eb6">峠</font> DRIFT', FontFace = Ui.DISPLAY, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.4, -40), ZIndex = 51, Parent = loading })
local loadMsg = text({ Text = "Building Japan…", TextSize = 16, TextColor3 = Ui.DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.4, 30), ZIndex = 51, Parent = loading })
local barBack = make("Frame", { Size = UDim2.new(0, 260, 0, 3), Position = UDim2.new(0.5, -130, 0.4, 64), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 51, Parent = loading })
local bar = make("Frame", { Size = UDim2.new(0.1, 0, 1, 0), BackgroundColor3 = Ui.SAKURA, BorderSizePixel = 0, ZIndex = 52, Parent = barBack })
local R = ReplicatedStorage:WaitForChild("KaidoRemotes")
local mapFolder = workspace:WaitForChild("KaidoMap")
local t0 = os.clock()
while not mapFolder:GetAttribute("Ready") do
	bar.Size = UDim2.new(math.min(0.95, 0.1 + (os.clock() - t0) / 20), 0, 1, 0)
	task.wait(0.1)
end
loadMsg.Text = "Loading your garage…"
local profile = R.GetProfile:InvokeServer()
local S = profile.settings
if S.assist == "" then S.assist = touch and "touch" or "std" end

local function owned(id)
	for _, o in profile.owned do if o == id then return true end end
	return false
end
local function paintOf(id)
	local idx = profile.paint[id] or 0
	return idx > 0 and Config.Paints[idx] or Config.car(id).color, idx
end
local saveQueued = false
local function saveSettings()
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function() saveQueued = false; R.SaveSettings:FireServer(S) end)
end

-- ===================== graphics level and time of day (this device only) =====================
local qAuto = touch and "low" or "high"
local function qName() return S.quality == "auto" and qAuto or S.quality end
local trees = mapFolder:WaitForChild("Trees", 10)
local lamps = mapFolder:WaitForChild("Lamps", 10)
local village = mapFolder:WaitForChild("Village", 10)
local function night() return S.time < 6.2 or S.time > 17.8 end
local function applyTree(m)
	local Q = Config.Quality[qName()]
	local show = (m:GetAttribute("Tier") or 1) <= Q.trees
	for _, p in m:GetChildren() do if p:IsA("BasePart") then p.LocalTransparencyModifier = show and 0 or 1 end end
end
local function applyLamp(head)
	local Q = Config.Quality[qName()]
	local l = head:FindFirstChildOfClass("PointLight")
	local on = night()
	head.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if l then l.Enabled = on and ((head:GetAttribute("N") or 0) % Q.lights == 0) end
end
local function applyVillage(p)
	if p:IsA("BasePart") and (p.Name == "Window" or p.Name == "Lantern" or p.Name == "VendingFace") then
		p.Material = (night() or p.Name == "VendingFace") and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local l = p:FindFirstChildOfClass("PointLight")
		if l then l.Enabled = night() end
	end
end
local function applyQuality()
	local Q = Config.Quality[qName()]
	Lighting.GlobalShadows = Q.shadows
	local bloom = Lighting:FindFirstChild("KaidoBloom")
	if bloom then bloom.Enabled = Q.bloom end
	if trees then for _, m in trees:GetChildren() do applyTree(m) end end
	if lamps then for _, h in lamps:GetDescendants() do if h.Name == "LampHead" then applyLamp(h) end end end
end
local carModel: Model? = nil
local function applyTime()
	Lighting.ClockTime = S.time
	local n = night()
	local dusk = math.clamp(1 - math.min(math.abs(S.time - 6), math.abs(S.time - 18)) / 1.5, 0, 1)
	Lighting.Ambient = n and Color3.fromRGB(34, 38, 62) or Color3.fromRGB(110, 110, 118)
	Lighting.OutdoorAmbient = n and Color3.fromRGB(58, 64, 100) or Color3.fromRGB(130, 134, 146):Lerp(Color3.fromRGB(150, 110, 100), dusk)
	Lighting.Brightness = n and 1.4 or 2.6
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = n and 0.3 or 0.26
		atmo.Color = n and Color3.fromRGB(72, 82, 122) or Color3.fromRGB(199, 214, 232):Lerp(Color3.fromRGB(240, 160, 120), dusk)
		atmo.Decay = n and Color3.fromRGB(22, 24, 42) or Color3.fromRGB(106, 122, 150):Lerp(Color3.fromRGB(160, 90, 80), dusk)
	end
	if lamps then for _, h in lamps:GetDescendants() do if h.Name == "LampHead" then applyLamp(h) end end end
	if village then for _, p in village:GetDescendants() do applyVillage(p) end end
	if carModel then CarModel.setLights(carModel, n) end
end
if trees then trees.ChildAdded:Connect(applyTree) end
if lamps then lamps.DescendantAdded:Connect(function(d) if d.Name == "LampHead" then applyLamp(d) end end) end
if village then village.DescendantAdded:Connect(applyVillage) end
applyQuality()
applyTime()

-- ===================== state =====================
local mode = "title" -- title | garage | settings | pause | play
local returnTo = "title"
local publicMap = false
local camMode = S.cam
local carDef = Config.car(profile.selected)
local carPhys = Config.physics(carDef)
local START = 8
local St = CarPhysics.new(Track.X[START], Track.Z[START], Track.heading(START))
local idx, posY = START, Track.Y[START]
local input = { thr = 0, brk = 0, hand = false, steer = 0 }
local drift = { active = false, score = 0, mult = 1, t = 0, off = 0, tags = {} }
local wallT, wheelRoll, lastZone = 0, 0, -1
local lapCP, prevIdx = 0, START
local sound = nil
local garageSel = profile.selected

local function spawnCar(id)
	if carModel then carModel:Destroy() end
	if sound then sound:destroy(); sound = nil end
	carDef = Config.car(id or profile.selected)
	carPhys = Config.physics(carDef)
	local col = paintOf(carDef.id)
	carModel = CarModel.build(carDef, "MyCar", col)
	carModel.Parent = workspace
	for _, a in carModel.PrimaryPart:GetChildren() do
		if a:IsA("Attachment") then
			make("ParticleEmitter", {
				Name = "Smoke", Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 0,
				Lifetime = NumberRange.new(1.6, 2.8), Speed = NumberRange.new(2, 7), SpreadAngle = Vector2.new(45, 45),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 14) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
				Color = ColorSequence.new(Color3.fromRGB(222, 224, 232)), Drag = 1.6, Acceleration = Vector3.new(0, 3, 0),
				LightInfluence = 1, Parent = a,
			})
		end
	end
	CarModel.setLights(carModel, night())
	if Audio.available() then sound = Audio.new(carModel, carDef, true) end
end

local function resetCar(i)
	i = i or Track.nearest(St.x, St.z, idx)
	St = CarPhysics.new(Track.X[i], Track.Z[i], Track.heading(i))
	idx, posY, prevIdx = i, Track.Y[i], i
	drift.active, drift.score, drift.mult = false, 0, 1
end

-- ===================== screens =====================
-- title
local title, tCol = Ui.sheet(gui)
text({ Text = 'KAIDO DRIFT\n<font color="#ff7eb6" size="40">街道 · 峠</font>', FontFace = Ui.DISPLAY, TextSize = 62, LineHeight = 0.95, LayoutOrder = 1, Parent = tCol })
text({ Text = "Midnight at Lake Ashi. Slide a 1989 coupe through Kojiri village, up the Hakone hairpins and along the shore, on the real course under Mt. Fuji. Earn credits for every drift and unlock the garage.", TextColor3 = Ui.DIM, TextSize = 16, LineHeight = 1.3, LayoutOrder = 2, Parent = tCol })
local tStats = Ui.stats({ { "Credits", Ui.GOLD }, { "Best drift" }, { "Cars" } }, 3, tCol)
local tMenu = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = tCol }, { Ui.list(10) })
local bSolo = Ui.button("Play solo", "Just you on the mountain", "primary", 1, tMenu)
local bPublic = Ui.button("Play with others", "Public map · drift together · chat", nil, 2, tMenu)
local bGarage = Ui.button("Garage", "Unlock & paint", nil, 3, tMenu)
local bSettings = Ui.button("Settings", "Graphics, gearbox, assists, sound", nil, 4, tMenu)
Ui.fine(touch and "Drag on the left to steer. GAS, BRAKE and HAND BRAKE are on the right; hold BRAKE when stopped to reverse. To start a drift: steer hard with GAS, tap HAND BRAKE, or lift and re-press GAS (clutch kick). CAM switches to the cockpit view."
	or "W/↑ gas · S/↓ brake (hold to reverse) · A D / ← → steer · Space hand brake · drift: steer + gas, tap Space, or lift and re-press W (clutch kick) · C camera · Q/E shift (manual) · R reset · Esc pause. Controllers work too.", 5, tCol)
local function refreshTitle()
	tStats[1].Text = fmt(profile.credits)
	tStats[2].Text = fmt(profile.best)
	tStats[3].Text = #profile.owned .. "/" .. #Config.Cars
end

-- garage
local garage, gCol = Ui.sheet(gui, true)
Ui.heading("Garage", "ガレージ", 1, gCol)
local gStats = Ui.stats({ { "Credits", Ui.GOLD } }, 2, gCol)
local gList = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3, Parent = gCol }, { Ui.list(8) })
local gDetail = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = gCol }, { Ui.list(10) })
local gPaintF = Ui.field("Paint (free)", 5, gCol)
local gSwatches = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = gPaintF }, {
	make("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local gBack = Ui.button("Back", nil, nil, 6, gCol)
local renderGarage
local function statBar(label, v, parent, order)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	text({ Text = string.upper(label), TextSize = 12, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 110, 1, 0), Parent = row })
	local back = make("Frame", { Size = UDim2.new(1, -120, 0, 6), Position = UDim2.new(0, 120, 0.5, -3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = row }, { Ui.corner(3) })
	make("Frame", { Size = UDim2.new(math.clamp(v, 0.05, 1), 0, 1, 0), BackgroundColor3 = Ui.NEON, BorderSizePixel = 0, Parent = back }, { Ui.corner(3) })
end
renderGarage = function()
	gStats[1].Text = fmt(profile.credits)
	for _, c in gList:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for k, car in Config.Cars do
		local sel = car.id == garageSel
		local have = owned(car.id)
		local card = make("TextButton", { Size = UDim2.new(1, 0, 0, 58), AutoButtonColor = false, Text = "", LayoutOrder = k, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = sel and 0.9 or 0.97, Parent = gList },
			{ Ui.corner(4), Ui.stroke(sel and Ui.SAKURA or Ui.LINE, sel and 1.5 or 1, sel and 0 or 0.87) })
		text({ Text = car.name, FontFace = Ui.BOLD, TextSize = 16, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -150, 0, 22), Position = UDim2.new(0, 14, 0, 8), TextWrapped = false, Parent = card })
		text({ Text = car.tag, TextSize = 13, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -150, 0, 18), Position = UDim2.new(0, 14, 0, 31), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		local pr = car.id == profile.selected and "DRIVING" or have and "OWNED" or (fmt(car.price) .. " CR")
		text({ Text = pr, FontFace = Ui.BOLD, TextSize = 15, TextColor3 = have and Ui.NEON or (profile.credits >= car.price and Ui.GOLD or Ui.DIM), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(1, -144, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = card })
		card.Activated:Connect(function()
			garageSel = car.id
			spawnCar(car.id)
			renderGarage()
		end)
	end
	-- detail for the highlighted car
	for _, c in gDetail:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local car = Config.car(garageSel)
	local ph = Config.physics(car)
	statBar("Power", car.power / 2100, gDetail, 1)
	statBar("Grip", (car.grip - 0.98) / 0.22, gDetail, 2)
	statBar("Top speed", (car.top - 170) / 110, gDetail, 3)
	statBar("Steering lock", (car.lock - 0.78) / 0.3, gDetail, 4)
	statBar("Agility", 1 - (ph.a * ph.b - 18) / 30, gDetail, 5)
	local have = owned(car.id)
	local label, note, kind
	if car.id == profile.selected then
		label, note, kind = "Driving this car", nil, nil
	elseif have then
		label, note, kind = "Drive this car", nil, "primary"
	elseif profile.credits >= car.price then
		label, note, kind = "Buy", fmt(car.price) .. " CR", "primary"
	else
		label, note, kind = "Locked", "Need " .. fmt(car.price - profile.credits) .. " more CR", nil
	end
	local act = Ui.button(label, note, kind, 6, gDetail)
	act.Activated:Connect(function()
		local res
		if have and car.id ~= profile.selected then
			res = R.Select:InvokeServer(car.id)
		elseif not have and profile.credits >= car.price then
			res = R.Buy:InvokeServer(car.id)
		end
		if res then profile = res; profile.settings = S; spawnCar(garageSel); renderGarage(); refreshTitle() end
	end)
	for _, c in gSwatches:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local _, cur = paintOf(car.id)
	for k = 0, #Config.Paints do
		local col = k == 0 and car.color or Config.Paints[k]
		local sw = make("TextButton", { Size = UDim2.new(0, 36, 0, 36), Text = "", AutoButtonColor = true, BackgroundColor3 = col, LayoutOrder = k, Parent = gSwatches }, {
			make("UICorner", { CornerRadius = UDim.new(0, 18) }), Ui.stroke(k == cur and Ui.SAKURA or Ui.LINE, k == cur and 3 or 1, k == cur and 0 or 0.6),
		})
		sw.Activated:Connect(function()
			profile.paint[car.id] = k
			if carModel then CarModel.paint(carModel, col) end
			task.spawn(function() local res = R.Paint:InvokeServer(car.id, k); if res then profile.paint = res.paint end end)
			renderGarage()
		end)
	end
end

-- settings
local settings, sCol = Ui.sheet(gui)
Ui.heading("Settings", "設定", 1, sCol)
do
	local f = Ui.field("Graphics quality", 2, sCol)
	Ui.chips({ { "auto", "Auto" }, { "low", "Low" }, { "medium", "Medium" }, { "high", "High" } }, S.quality, function(v) S.quality = v; applyQuality(); saveSettings() end, 1, f)
	Ui.fine("Low: phones and older computers. Medium adds shadows. High adds bloom and every tree.", 2, f)
end
local timeLabel
local setTimeSlider, setTimeChips
do
	local f, l = Ui.field("Time of day", 3, sCol)
	timeLabel = l
	local function show() timeLabel.Text = string.format("TIME OF DAY · %02d:%02d", math.floor(S.time), math.floor((S.time % 1) * 60 + 0.5)) end
	setTimeSlider = Ui.slider(0, 23.75, 0.25, S.time, function(v) S.time = v; show(); applyTime(); saveSettings(); if setTimeChips then setTimeChips(v) end end, 1, f)
	setTimeChips = Ui.chips({ { 5.75, "Dawn" }, { 12.5, "Noon" }, { 17.25, "Sunset" }, { 0, "Midnight" } }, S.time, function(v) S.time = v; setTimeSlider(v); show(); applyTime(); saveSettings() end, 2, f)
	show()
end
do
	local f = Ui.field("Gearbox", 4, sCol)
	Ui.chips({ { "auto", "Automatic" }, { "manual", "Manual" } }, S.trans, function(v) S.trans = v; saveSettings() end, 1, f)
	Ui.fine(touch and "Manual: ▲ ▼ buttons appear above the pedals." or "Manual: Q / E or LB / RB to shift. Hold brake when stopped to reverse in either mode.", 2, f)
end
local assistDesc
do
	local f = Ui.field("Drift assists", 5, sCol)
	local opts = {}
	for _, a in Config.Assists do table.insert(opts, { a.id, a.name }) end
	assistDesc = Ui.fine(Config.assist(S.assist).desc, 2, f)
	Ui.chips(opts, S.assist, function(v) S.assist = v; assistDesc.Text = Config.assist(v).desc; saveSettings() end, 1, f)
	Ui.fine("Every level uses the same tyre physics. Assists only help with steering and catching slides, like in sim drift games.", 3, f)
end
local setCamChips
do
	local f = Ui.field("Camera", 6, sCol)
	setCamChips = Ui.chips({ { 0, "Chase" }, { 1, "Far chase" }, { 2, "Cockpit" }, { 3, "Hood" } }, S.cam, function(v) S.cam = v; camMode = v; saveSettings() end, 1, f)
end
do
	local f = Ui.field("Steering sensitivity", 7, sCol)
	Ui.slider(0.5, 1.6, 0.05, S.sens, function(v) S.sens = v; saveSettings() end, 1, f)
end
do
	local f = Ui.field("Sound", 8, sCol)
	Ui.chips({ { true, "On" }, { false, "Off" } }, S.sound, function(v) S.sound = v; saveSettings() end, 1, f)
	Ui.slider(0, 1, 0.05, S.volume, function(v) S.volume = v; saveSettings() end, 2, f)
	if not Audio.available() then
		Ui.fine('<font color="#ffc94d">Engine sounds are not added to this place yet.</font> Upload the files in the game\'s sounds folder to Roblox and drag them into Workspace (see README).', 3, f)
	end
end
do
	local f = Ui.field("Your progress", 9, sCol)
	Ui.fine("Credits, cars, paint and these settings are saved to your Roblox account automatically, on any device you play on.", 1, f)
	local erase = Ui.button("Erase progress", nil, "ghost", 2, f)
	local sure = false
	erase.Activated:Connect(function()
		if not sure then
			sure = true
			erase.Label.Text = "TAP AGAIN TO ERASE EVERYTHING"
			erase.Label.TextColor3 = Ui.DANGER
			task.delay(4, function() sure = false; erase.Label.Text = "ERASE PROGRESS"; erase.Label.TextColor3 = Ui.TEXT end)
		else
			sure = false
			local res = R.Erase:InvokeServer()
			if res then profile = res; profile.settings = S; garageSel = profile.selected; spawnCar(); refreshTitle() end
			erase.Label.Text = "PROGRESS ERASED"
		end
	end)
end
local sBack = Ui.button("Back", nil, nil, 10, sCol)

-- pause
local pause, pCol = Ui.sheet(gui)
Ui.heading("Paused", "一時停止", 1, pCol)
local pMenu = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = pCol }, { Ui.list(10) })
local pResume = Ui.button("Resume", nil, "primary", 1, pMenu)
local pGarage = Ui.button("Garage", "Unlock & paint", nil, 2, pMenu)
local pSettings = Ui.button("Settings", "Graphics, gearbox, assists", nil, 3, pMenu)
local pQuit = Ui.button("Main menu", nil, "ghost", 4, pMenu)

-- ===================== HUD =====================
local hud = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
local shadowT = function(o) make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = o }); return o end
local tl = make("Frame", { Size = UDim2.new(0, 280, 0, 60), Position = UDim2.new(0, 16, 0, 62), BackgroundTransparency = 1, Parent = hud }, { Ui.list(2) })
local credRow = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1, Parent = tl }, { Ui.list(8, true, Enum.VerticalAlignment.Bottom) })
text({ Text = "CR", TextSize = 11, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false, LayoutOrder = 1, Parent = credRow })
local hCredits = shadowT(text({ Text = "0", TextSize = 22, FontFace = Ui.BOLD, TextColor3 = Ui.GOLD, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false, LayoutOrder = 2, Parent = credRow }))
local hZone = shadowT(text({ Text = "", TextSize = touch and 12 or 15, FontFace = Ui.DISPLAY, LayoutOrder = 2, Parent = tl }))
-- drift score: top centre, compact on phones
local dW = touch and 200 or 360
local dBox = make("Frame", { Size = UDim2.new(0, dW, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, -dW / 2, 0, touch and 6 or 12), BackgroundTransparency = 1, Visible = false, Parent = hud }, {
	make("UIListLayout", { Padding = UDim.new(0, touch and 0 or 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local dTier = shadowT(text({ Text = "DRIFT", TextSize = touch and 10 or 13, FontFace = Ui.BOLD, TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = dBox }))
local dScore = shadowT(text({ Text = "0", TextSize = touch and 30 or 52, FontFace = Ui.DISPLAY, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = dBox }))
local dMult = shadowT(text({ Text = "×1.0", TextSize = touch and 12 or 18, FontFace = Ui.BOLD, TextColor3 = Ui.SAKURA, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = dBox }))
local dTags = make("Frame", { Size = UDim2.new(1, 0, 0, touch and 16 or 22), BackgroundTransparency = 1, LayoutOrder = 4, Parent = dBox }, {
	make("UIListLayout", { Padding = UDim.new(0, 6), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toast = shadowT(text({ Text = "", TextSize = touch and 16 or 24, FontFace = Ui.DISPLAY, TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 520, 0, 0), Position = UDim2.new(0.5, -260, 0, touch and 82 or 130), TextTransparency = 1, Parent = hud }))
local toastT = 0
local function showToast(t, c) toast.Text, toast.TextColor3, toast.TextTransparency, toastT = t, c or Ui.GOLD, 0, 2.4 end
local hint = make("TextLabel", { Size = UDim2.new(0, 0, 0, 34), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 0), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.3, Text = "", FontFace = Ui.BOLD, TextSize = 14, TextColor3 = Ui.TEXT, Visible = false, Parent = hud }, { Ui.corner(4), Ui.pad(14, 0, 14, 0) })
-- speed
local spBox = make("Frame", { Size = UDim2.new(0, 190, 0, 86), Position = UDim2.new(0.5, -95, 1, touch and -104 or -100), BackgroundTransparency = 1, Parent = hud })
local hSpeed = shadowT(text({ Text = "0", TextSize = touch and 42 or 56, FontFace = Ui.DISPLAY, TextXAlignment = Enum.TextXAlignment.Right, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.6, 0, 0, 56), Parent = spBox }))
text({ Text = "KM/H", TextSize = 11, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.38, 0, 0, 14), Position = UDim2.new(0.64, 0, 0, 12), Parent = spBox })
local hGear = shadowT(text({ Text = "1", TextSize = 22, FontFace = Ui.BOLD, TextColor3 = Ui.NEON, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.38, 0, 0, 26), Position = UDim2.new(0.64, 0, 0, 26), Parent = spBox }))
local rpmBack = make("Frame", { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0, 62), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.87, BorderSizePixel = 0, Parent = spBox }, { Ui.corner(2) })
local rpmBar = make("Frame", { Size = UDim2.new(0.2, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = rpmBack }, {
	Ui.corner(2), make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Ui.NEON), ColorSequenceKeypoint.new(0.85, Ui.SAKURA), ColorSequenceKeypoint.new(1, Ui.DANGER) }) }),
})
local hAngle = text({ Text = "", TextSize = 11, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 70), Parent = spBox })
-- minimap
local mmSize = touch and 100 or 150
local mm = make("Frame", { Size = UDim2.new(0, mmSize, 0, mmSize), Position = UDim2.new(1, -mmSize - 14, 0, 14), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.45, Parent = hud }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Ui.stroke(Ui.LINE, 1, 0.87) })
local mmMinX, mmMaxX, mmMinZ, mmMaxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, Track.N do
	mmMinX, mmMaxX = math.min(mmMinX, Track.X[i]), math.max(mmMaxX, Track.X[i])
	mmMinZ, mmMaxZ = math.min(mmMinZ, Track.Z[i]), math.max(mmMaxZ, Track.Z[i])
end
local mmSpan = math.max(mmMaxX - mmMinX, mmMaxZ - mmMinZ) * 1.18
local function mmPos(x, z) return UDim2.new(0.5 + (x - (mmMinX + mmMaxX) / 2) / mmSpan, 0, 0.5 + (z - (mmMinZ + mmMaxZ) / 2) / mmSpan, 0) end
local zoneCol = { [0] = Ui.NEON, [1] = Ui.SAKURA, [2] = Ui.GOLD }
for i = 1, Track.N, math.max(1, Track.N // 220) do
	make("Frame", { Size = UDim2.new(0, 3, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = mmPos(Track.X[i], Track.Z[i]), BackgroundColor3 = zoneCol[Track.ZONE[i]], BorderSizePixel = 0, Parent = mm })
end
local mmMe = make("Frame", { Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.SAKURA, BorderSizePixel = 0, ZIndex = 3, Parent = mm }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), make("UIStroke", { Color = Ui.INK, Thickness = 2 }) })
-- buttons: bottom-right row on computers, a row beside the minimap on phones
local hb = make("Frame", { Size = UDim2.new(0, 4 * 60, 0, 44), BackgroundTransparency = 1, Parent = hud }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }),
})
hb.Position = touch and UDim2.new(1, -mmSize - 14 - 4 * 60 - 8, 0, 14) or UDim2.new(1, -4 * 60 - 14, 1, -58)
local function hudBtn(t, order)
	return make("TextButton", { Size = UDim2.new(0, 54, 0, 44), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.4, Text = t, TextColor3 = Ui.TEXT, FontFace = Ui.BOLD, TextSize = 13, LayoutOrder = order, Parent = hb }, { Ui.corner(4), Ui.stroke(Ui.LINE, 1, 0.87) })
end
local bCam, bSnd, bPause = hudBtn("CAM", 1), hudBtn("SND", 2), hudBtn("II", 3)

-- touch controls
local touchState = { gas = false, brake = false, hand = false, steer = 0 }
local shiftRow
if touch then
	local steerZone = make("Frame", { Size = UDim2.new(0.45, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, Parent = hud })
	local knobBase = make("Frame", { Size = UDim2.new(0, 170, 0, 56), Position = UDim2.new(0, 24, 1, -84), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.45, Parent = hud }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Ui.stroke(Ui.LINE, 1, 0.8) })
	local knob = make("Frame", { Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0.5, -24, 0, 4), BackgroundColor3 = Ui.NEON, BackgroundTransparency = 0.25, Parent = knobBase }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local steerInput, startX = nil, 0
	steerZone.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch and not steerInput then steerInput, startX = io, io.Position.X end
	end)
	UserInputService.InputChanged:Connect(function(io) if io == steerInput then touchState.steer = math.clamp((io.Position.X - startX) / 70, -1, 1) end end)
	UserInputService.InputEnded:Connect(function(io) if io == steerInput then steerInput = nil; touchState.steer = 0 end end)
	RunService.RenderStepped:Connect(function() knob.Position = UDim2.new(0.5, -24 + touchState.steer * 58, 0, 4) end)
	local function pedal(t, size, pos, color, key)
		local b = make("TextButton", { Size = size, Position = pos, BackgroundColor3 = color, BackgroundTransparency = 0.3, Text = t, TextColor3 = Ui.INK, FontFace = Ui.BOLD, TextSize = 15, AutoButtonColor = false, Parent = hud }, { Ui.corner(8) })
		local held = {}
		b.InputBegan:Connect(function(io) if io.UserInputType == Enum.UserInputType.Touch then held[io] = true; touchState[key] = true; b.BackgroundTransparency = 0.05 end end)
		b.InputEnded:Connect(function(io) held[io] = nil; if next(held) == nil then touchState[key] = false; b.BackgroundTransparency = 0.3 end end)
		return b
	end
	pedal("GAS", UDim2.new(0, 88, 0, 150), UDim2.new(1, -102, 1, -164), Ui.SAKURA, "gas")
	pedal("BRAKE", UDim2.new(0, 84, 0, 70), UDim2.new(1, -194, 1, -84), Color3.fromRGB(214, 216, 226), "brake")
	pedal("HAND", UDim2.new(0, 84, 0, 70), UDim2.new(1, -194, 1, -164), Ui.NEON, "hand")
	local reset = make("TextButton", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(1, -58, 1, -214), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.4, Text = "↺", TextColor3 = Ui.TEXT, TextSize = 20, FontFace = Ui.BOLD, Parent = hud }, { Ui.corner(4) })
	reset.Activated:Connect(function() resetCar() end)
	shiftRow = make("Frame", { Size = UDim2.new(0, 100, 0, 40), Position = UDim2.new(1, -164, 1, -214), BackgroundTransparency = 1, Parent = hud }, { Ui.list(8, true) })
	for k, d in { { "▼", -1 }, { "▲", 1 } } do
		local sb = make("TextButton", { Size = UDim2.new(0, 46, 0, 40), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.4, Text = d[1], TextColor3 = Ui.TEXT, TextSize = 18, FontFace = Ui.BOLD, LayoutOrder = k, Parent = shiftRow }, { Ui.corner(4) })
		sb.Activated:Connect(function() CarPhysics.shift(St, carPhys, d[2]) end)
	end
end

-- ===================== other players on the public map =====================
local ghosts = {}
R.Others.OnClientEvent:Connect(function(uid, x, y, z, h, carId, paint, drifting)
	if not publicMap or (mode ~= "play" and mode ~= "pause") then return end
	local g = ghosts[uid]
	if not g or g.carId ~= carId or g.paint ~= paint then
		if g then g.model:Destroy(); if g.sound then g.sound:destroy() end end
		local car = Config.car(carId)
		local m = CarModel.build(car, "Driver" .. uid, paint > 0 and Config.Paints[paint] or car.color)
		local who = Players:GetPlayerByUserId(uid)
		local tag = make("BillboardGui", { Size = UDim2.new(0, 160, 0, 24), StudsOffset = Vector3.new(0, 7, 0), AlwaysOnTop = true, MaxDistance = 500, Parent = m.PrimaryPart })
		text({ Text = who and who.DisplayName or "Driver", TextSize = 15, FontFace = Ui.BOLD, TextColor3 = Ui.NEON, TextXAlignment = Enum.TextXAlignment.Center, Parent = tag })
		m.Parent = workspace
		CarModel.setLights(m, night())
		g = { model = m, carId = carId, paint = paint, cf = CFrame.new(x, y, z) * CFrame.Angles(0, h + math.pi, 0), sound = Audio.available() and Audio.new(m, car, false) or nil, rpm = 3000 }
		ghosts[uid] = g
	end
	g.target = CFrame.new(x, y, z) * CFrame.Angles(0, h + math.pi, 0)
	g.drifting = drifting
	g.seen = os.clock()
end)
local function clearGhosts()
	for uid, g in ghosts do g.model:Destroy(); if g.sound then g.sound:destroy() end; ghosts[uid] = nil end
end
Players.PlayerRemoving:Connect(function(p)
	local g = ghosts[p.UserId]
	if g then g.model:Destroy(); if g.sound then g.sound:destroy() end; ghosts[p.UserId] = nil end
end)

-- ===================== screen switching =====================
local function setMode(m)
	if (m == "garage" or m == "settings") and (mode == "pause" or mode == "play") then returnTo = "pause"
	elseif m == "garage" or m == "settings" then returnTo = "title" end
	if mode == "garage" and m ~= "garage" and garageSel ~= profile.selected then garageSel = profile.selected; spawnCar() end
	mode = m
	title.Visible, garage.Visible, settings.Visible, pause.Visible = m == "title", m == "garage", m == "settings", m == "pause"
	hud.Visible = m == "play"
	if m == "title" then clearGhosts(); refreshTitle() end
	if m == "garage" then garageSel = profile.selected; renderGarage() end
	if m == "play" and shiftRow then shiftRow.Visible = S.trans == "manual" end
	if m ~= "play" and sound then sound:mute() end
end
local function start(public)
	publicMap = public
	R.SetMode:FireServer(public and "public" or "solo")
	setMode("play")
	resetCar(START)
	lastZone = -1
	showToast(public and "Public map · everyone here drives together" or "Solo · just you on the mountain", public and Ui.NEON or Ui.TEXT)
end
bSolo.Activated:Connect(function() start(false) end)
bPublic.Activated:Connect(function() start(true) end)
bGarage.Activated:Connect(function() setMode("garage") end)
bSettings.Activated:Connect(function() setMode("settings") end)
gBack.Activated:Connect(function() setMode(returnTo) end)
sBack.Activated:Connect(function() setMode(returnTo) end)
pResume.Activated:Connect(function() setMode("play") end)
pGarage.Activated:Connect(function() setMode("garage") end)
pSettings.Activated:Connect(function() setMode("settings") end)
pQuit.Activated:Connect(function() R.SetMode:FireServer("solo"); setMode("title") end)
local CAM_NAMES = { [0] = "Chase", [1] = "Far chase", [2] = "Cockpit · first person", [3] = "Hood" }
local function cycleCam()
	camMode = (camMode + 1) % 4
	S.cam = camMode
	setCamChips(camMode)
	saveSettings()
	showToast(CAM_NAMES[camMode], Ui.TEXT)
end
bCam.Activated:Connect(cycleCam)
bSnd.Activated:Connect(function() S.sound = not S.sound; saveSettings(); showToast(S.sound and "Sound on" or "Sound off", Ui.TEXT) end)
bPause.Activated:Connect(function() setMode("pause") end)
UserInputService.InputBegan:Connect(function(io, processed)
	if processed then return end
	local k = io.KeyCode
	if mode == "play" then
		if k == Enum.KeyCode.C or k == Enum.KeyCode.V or k == Enum.KeyCode.ButtonY then cycleCam() end
		if k == Enum.KeyCode.R or k == Enum.KeyCode.ButtonSelect then resetCar() end
		if k == Enum.KeyCode.Escape or k == Enum.KeyCode.P or k == Enum.KeyCode.ButtonStart then setMode("pause") end
		if S.trans == "manual" then
			if k == Enum.KeyCode.E or k == Enum.KeyCode.ButtonR1 then CarPhysics.shift(St, carPhys, 1) end
			if k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonL1 then CarPhysics.shift(St, carPhys, -1) end
		end
	elseif mode == "pause" and (k == Enum.KeyCode.Escape or k == Enum.KeyCode.P or k == Enum.KeyCode.ButtonStart) then
		setMode("play")
	end
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
	steer = math.clamp(steer * S.sens, -1, 1)
	input.steer += math.clamp(steer - input.steer, -dt * 5.5, dt * 5.5)
	input.thr, input.brk, input.hand = thr, brk, hand
end

-- ===================== drift scoring (as in the browser game) =====================
local TIERS = { { 0, "DRIFT" }, { 3000, "GREAT DRIFT" }, { 8000, "AWESOME DRIFT" }, { 15000, "INSANE DRIFT" }, { 30000, "UNBELIEVABLE DRIFT" } }
local nearWall = false
local function endDrift(keep)
	if drift.active and drift.score > 0 then
		local pts = math.floor(drift.score * drift.mult)
		if keep and pts >= 50 then
			R.Bank:FireServer(pts)
			profile.credits += pts
			profile.best = math.max(profile.best, pts)
			showToast("+" .. fmt(pts) .. " CR", Ui.GOLD)
		elseif not keep and pts > 200 then
			showToast("CRASH  ·  " .. fmt(pts) .. " lost", Ui.DANGER)
		end
	end
	drift.active, drift.score, drift.mult, drift.t, drift.off = false, 0, 1, 0, 0
	table.clear(drift.tags)
end
local function updateDrift(dt)
	local kmh = CarPhysics.kmh(St.speed)
	local ang = math.abs(St.beta) * 57.3
	if ang > 10 and kmh > 25 and ang < 110 and St.gear > 0 then
		drift.active, drift.off = true, 0
		drift.t += dt
		local bonus = 1
		if nearWall then drift.tags["NEAR WALL"] = true; bonus *= 1.35 end
		if ang > 45 then drift.tags.ANGLE = true; bonus *= 1.15 end
		if kmh > 110 then drift.tags.SPEED = true; bonus *= 1.15 end
		for _, g in ghosts do
			if g.drifting and (g.cf.Position - Vector3.new(St.x, posY, St.z)).Magnitude < 30 then drift.tags.TANDEM = true; bonus *= 1.5 end
		end
		drift.mult = math.min(5, 1 + math.floor(drift.t / 1.6) * 0.5)
		drift.score += kmh * ang * 0.5 * dt * bonus
	elseif drift.active then
		drift.off += dt
		if drift.off > 0.7 then endDrift(true) end
	end
end
local tagCache = ""
local function renderTags()
	local names = {}
	for _, n in { "ANGLE", "SPEED", "NEAR WALL", "TANDEM" } do if drift.tags[n] then table.insert(names, n) end end
	local key = table.concat(names, "|")
	if key == tagCache then return end
	tagCache = key
	for _, c in dTags:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for k, n in names do
		make("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Ui.NEON, Text = n, TextColor3 = Color3.fromHex("04222b"), FontFace = Ui.BOLD, TextSize = touch and 9 or 11, LayoutOrder = k, Parent = dTags }, { Ui.corner(2), Ui.pad(6, 0, 6, 0) })
	end
end

-- ===================== main loop =====================
local camPos = camera.CFrame.Position
local sendT, orbit, smokeOn, lookYaw = 0, 0, false, 0
local perfT, perfN, perfDone = 0, 0, false
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.05)
	if not carModel then spawnCar() end
	local m = carModel :: Model
	local A = Config.assist(S.assist)
	local manual = S.trans == "manual"

	if mode == "play" then
		readInput(dt)
		local steps = math.max(1, math.ceil(dt * 120))
		for _ = 1, steps do CarPhysics.step(St, input, carPhys, A, manual, dt / steps) end
		-- guardrails: stay on the road, scrape along the rail
		idx = Track.nearest(St.x, St.z, idx)
		local lat, y = Track.at(St.x, St.z, idx)
		local lim = Config.ROAD_HALF - 3.2
		nearWall = math.abs(lat) > lim - 3
		if math.abs(lat) > lim then
			local rx, rz = Track.RX[idx], Track.RZ[idx]
			local sgn = lat > 0 and 1 or -1
			St.x -= rx * (math.abs(lat) - lim) * sgn
			St.z -= rz * (math.abs(lat) - lim) * sgn
			local vn = St.vx * rx + St.vz * rz
			if vn * sgn > 0 then
				St.vx -= rx * vn * 1.3; St.vz -= rz * vn * 1.3
				St.vx *= 0.92; St.vz *= 0.92
				St.r *= 0.55
				if math.abs(vn) > 14 and wallT <= 0 then endDrift(false); wallT = 0.6 end
			end
		end
		wallT -= dt
		posY += (y - posY) * math.min(1, dt * 20)
		updateDrift(dt)

		-- laps: pass all four quarters, then the start line
		lapCP = bit32.bor(lapCP, bit32.lshift(1, math.min(3, math.floor((idx - 1) / (Track.N / 4)))))
		if prevIdx > Track.N * 0.9 and idx < Track.N * 0.1 and lapCP == 15 then
			lapCP = 1
			R.Lap:FireServer()
			profile.credits += 2000
			showToast("Lap complete  ·  +2,000 CR", Ui.GOLD)
		end
		prevIdx = idx

		-- HUD
		local kmh = CarPhysics.kmh(St.speed)
		hSpeed.Text = tostring(math.floor(kmh))
		hGear.Text = (manual and "M" or "") .. (St.gear < 0 and "R" or tostring(St.gear))
		rpmBar.Size = UDim2.new(math.clamp((St.rpm - 800) / (carDef.red - 800), 0, 1), 0, 1, 0)
		hAngle.Text = drift.active and (math.floor(math.abs(St.beta) * 57.3) .. "° ANGLE") or ""
		hCredits.Text = fmt(profile.credits)
		local z = Track.ZONE[idx]
		if z ~= lastZone then lastZone = z; hZone.Text = Track.ZONE_NAMES[z]; showToast(Track.ZONE_NAMES[z], Ui.TEXT) end
		dBox.Visible = drift.active
		if drift.active then
			local pts = drift.score * drift.mult
			dScore.Text = fmt(pts)
			dMult.Text = string.format("×%.1f", drift.mult)
			local tier = "DRIFT"
			for _, t in TIERS do if pts >= t[1] then tier = t[2] end end
			dTier.Text = tier
			renderTags()
		end
		mmMe.Position = mmPos(St.x, St.z)
		if toastT > 0 then toastT -= dt; if toastT < 0.5 then toast.TextTransparency = 1 - toastT * 2 end end
		local vdot = St.speed > 3 and (St.vx * Track.TX[idx] + St.vz * Track.TZ[idx]) / St.speed or 1
		local h = vdot < -0.5 and St.gear > 0 and (touch and "Wrong way · tap ↺ to reset" or "Wrong way · press R to reset") or ""
		hint.Text, hint.Visible = h, h ~= ""

		-- tell the server where we are (public map only)
		sendT += dt
		if publicMap and sendT > 0.1 then
			sendT = 0
			local _, pidx = paintOf(carDef.id)
			R.State:FireServer(St.x, posY, St.z, St.h, carDef.id, pidx, drift.active)
		end
		-- auto graphics: drop a level if this device runs below ~38 fps
		if S.quality == "auto" and not perfDone then
			perfT += dt; perfN += 1
			if perfT > 6 then
				local fps = perfN / perfT
				perfT, perfN = 0, 0
				if fps < 38 and qAuto ~= "low" then
					qAuto = qAuto == "high" and "medium" or "low"
					applyQuality()
					showToast("Graphics lowered for smoother driving", Ui.TEXT)
				else
					perfDone = true
				end
			end
		end
	end

	-- place the car on the road, pitched with the slope and leaning in the corners
	local fx, fz = math.sin(St.h), math.cos(St.h)
	local pos = Vector3.new(St.x, posY, St.z)
	local fwd = Vector3.new(fx, Track.slope(idx), fz).Unit
	local lean = math.clamp(-St.r * CarPhysics.kmh(St.speed) * 0.0005, -0.05, 0.05)
	local cf = CFrame.lookAt(pos, pos + fwd) * CFrame.Angles(0, 0, lean)
	wheelRoll += St.u / 1.12 * dt
	CarModel.place(m, cf, St.delta, wheelRoll)

	-- smoke and sound
	local slide = math.clamp((math.abs(St.beta) - 0.12) / 0.5, 0, 1)
	local smoking = mode == "play" and St.speed > 8 and (math.abs(St.beta) > 0.2 or St.spin)
	if smoking ~= smokeOn then
		smokeOn = smoking
		local rate = 48 * Config.Quality[qName()].smoke
		for _, a in m.PrimaryPart:GetChildren() do
			local e = a:FindFirstChild("Smoke")
			if e then e.Rate = smoking and rate or 0 end
		end
	end
	if sound and mode == "play" then
		sound:update(dt, St.rpm, St.thrEff, St.spin and math.max(slide, 0.6) or slide, CarPhysics.kmh(St.speed), St.limiter, S.sound and S.volume or 0)
	end

	-- other players glide to their latest positions; drop anyone silent for 3 s
	for uid, g in ghosts do
		if os.clock() - g.seen > 3 then
			g.model:Destroy(); if g.sound then g.sound:destroy() end; ghosts[uid] = nil
		else
			local before = g.cf.Position
			g.cf = g.cf:Lerp(g.target, math.min(1, dt * 10))
			CarModel.place(g.model, g.cf, 0, 0)
			if g.sound then
				local spd = (g.cf.Position - before).Magnitude / math.max(dt, 1e-3)
				g.rpm += ((1500 + spd * 32) - g.rpm) * math.min(1, dt * 3)
				g.sound:update(dt, math.min(g.rpm, 7000), 0.8, g.drifting and 0.7 or 0, spd / 3.5 * 3.6, false, S.sound and S.volume * 0.8 or 0)
			end
		end
	end

	-- camera
	if mode ~= "play" then
		orbit += dt * 0.18
		local r = mode == "garage" and 24 or 32
		local eye = pos + Vector3.new(math.sin(St.h + orbit) * r, mode == "garage" and 6 or 9, math.cos(St.h + orbit) * r)
		local side = (mode == "title" or mode == "garage") and camera.ViewportSize.X > 800
		local right = Vector3.new(-math.cos(St.h + orbit), 0, math.sin(St.h + orbit))
		camera.CFrame = CFrame.lookAt(eye, pos + Vector3.new(0, 2.5, 0) + (side and right * 7 or Vector3.zero))
		camera.FieldOfView = 50
		CarModel.setCabinVisible(m, true)
	elseif camMode == 2 or camMode == 3 then
		CarModel.setCabinVisible(m, camMode ~= 2)
		lookYaw += (math.clamp(-St.beta * (camMode == 2 and 0.6 or 0.3), -0.7, 0.7) - lookYaw) * math.min(1, dt * 4)
		local eye = camMode == 2 and cf * CFrame.new(carDef.wid / 2 - 1.75, carDef.h * 0.82, carDef.wb * 0.12) or cf * CFrame.new(0, carDef.h * 0.7, -carDef.len * 0.22)
		camera.CFrame = eye * CFrame.Angles(math.rad(camMode == 2 and -4 or -2), lookYaw, 0)
		camera.FieldOfView = math.clamp((camMode == 2 and 70 or 66) + CarPhysics.kmh(St.speed) * 0.09, 60, 88)
	else
		CarModel.setCabinVisible(m, true)
		local sp2 = St.speed
		local dx, dz = fx, fz
		if sp2 > 10 then
			local vx, vz = St.vx / sp2, St.vz / sp2
			dx, dz = fx * 0.45 + vx * 0.55, fz * 0.45 + vz * 0.55
			local l = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / l, dz / l
		end
		local dist = camMode == 1 and 36 or 22
		local hgt = camMode == 1 and 13 or 7.5
		local target = pos - Vector3.new(dx, 0, dz) * (dist + sp2 * 0.04) + Vector3.new(0, hgt, 0)
		if (camPos - target).Magnitude > 120 then camPos = target end
		camPos = Vector3.new(camPos.X + (target.X - camPos.X) * math.min(1, dt * 6), camPos.Y + (target.Y - camPos.Y) * math.min(1, dt * 4), camPos.Z + (target.Z - camPos.Z) * math.min(1, dt * 6))
		camera.CFrame = CFrame.lookAt(camPos, pos + Vector3.new(fx, 0, fz) * 8 + Vector3.new(0, 3, 0))
		camera.FieldOfView = math.clamp(60 + CarPhysics.kmh(sp2) * 0.13, 60, 84)
	end
end)

spawnCar()
refreshTitle()
loading:Destroy()
setMode("title")
