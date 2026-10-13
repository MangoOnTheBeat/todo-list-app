-- Kaido Drift (Roblox) client: the browser game's screens, HUD, controls, drift scoring, camera and
-- physics (an exact port), the browser car models, free roaming between the Hakone pass and
-- Shin-Hakone city, graphics levels, time of day and engine sound. Progress lives on Roblox's servers.
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
local CarMesh = require(script.Parent:WaitForChild("CarMesh"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local U = {} -- screen widgets (kept in one table: Luau allows 200 locals per scope)
local make, text, fmt = Ui.make, Ui.text, Ui.fmt
local K = Config.SCALE -- studs per metre
local HALF = Config.ROAD_HALF

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local gui = make("ScreenGui", { Name = "KaidoUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

-- ===================== loading =====================
local loading = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.INK, ZIndex = 50, Parent = gui })
text({ Text = 'KAIDO <font color="#ff7eb6">峠</font> DRIFT', FontFace = Ui.DISPLAY, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.4, -40), ZIndex = 51, Parent = loading })
text({ Text = "VERSION " .. Config.VERSION, TextSize = 12, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -40), ZIndex = 51, Parent = loading })
local loadMsg = text({ Text = "Building Japan…", TextSize = 16, TextColor3 = Ui.DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.4, 30), ZIndex = 51, Parent = loading })
U.barBack = make("Frame", { Size = UDim2.new(0, 260, 0, 3), Position = UDim2.new(0.5, -130, 0.4, 64), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 51, Parent = loading })
U.loadBar = make("Frame", { Size = UDim2.new(0.1, 0, 1, 0), BackgroundColor3 = Ui.SAKURA, BorderSizePixel = 0, ZIndex = 52, Parent = U.barBack })
-- any error while loading is shown here (and in View › Output) rather than loading forever
local function showLoadError(where, message)
	if loading.Parent then
		loadMsg.Text = "Something went wrong (" .. where .. "):\n" .. message .. "\nSend a screenshot of this to fix it."
		loadMsg.TextColor3 = Ui.DANGER
	end
end
game:GetService("ScriptContext").Error:Connect(function(message, trace) showLoadError("game", message .. "\n" .. trace) end)
local R = ReplicatedStorage:WaitForChild("KaidoRemotes")
local mapFolder = workspace:WaitForChild("KaidoMap")
local t0 = os.clock()
while not mapFolder:GetAttribute("Ready") do
	U.loadBar.Size = UDim2.new(math.min(0.95, 0.1 + (os.clock() - t0) / 60), 0, 1, 0)
	local err = ReplicatedStorage:GetAttribute("KaidoError")
	if err then showLoadError("server", err) end
	task.wait(0.1)
end
loadMsg.Text = "Loading your garage…"
local World = require(script.Parent:WaitForChild("World"))
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
-- the time of day: yours, unless the game owner has set one for everyone
local function curTime() return ReplicatedStorage:GetAttribute("KaidoTime") or S.time end
local function night() local t = curTime(); return t < 6.2 or t > 17.8 end
local trees = mapFolder:FindFirstChild("Trees")
local lamps = mapFolder:FindFirstChild("Lamps")
local village = mapFolder:FindFirstChild("Village")
local cityF = mapFolder:FindFirstChild("City")
local function applyTree(m)
	local show = (m:GetAttribute("Tier") or 1) <= Config.Quality[qName()].trees
	for _, p in m:GetChildren() do if p:IsA("BasePart") then p.LocalTransparencyModifier = show and 0 or 1 end end
end
local function applyLamp(head)
	local Q = Config.Quality[qName()]
	local l = head:FindFirstChildOfClass("PointLight")
	head.Material = night() and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if l then l.Enabled = night() and ((head:GetAttribute("N") or 0) % Q.lights == 0) end
end
local function applyGlow(p)
	if not p:IsA("BasePart") then return end
	local n = p.Name
	if n == "Window" then
		local show = (p:GetAttribute("Tier") or 1) <= Config.Quality[qName()].windows
		p.LocalTransparencyModifier = (show and night()) and 0 or 1
	elseif n == "Lantern" or n == "AirLight" then
		p.Material = night() and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local l = p:FindFirstChildOfClass("PointLight")
		if l then l.Enabled = night() end
	elseif n == "SignFace" or n == "Screen" then
		local g = p:FindFirstChildOfClass("SurfaceGui")
		if g then g.Enabled = Config.Quality[qName()].signs or n == "Screen" end
	end
end
local function applyWorld()
	if lamps then for _, h in lamps:GetDescendants() do if h.Name == "LampHead" then applyLamp(h) end end end
	if village then for _, p in village:GetDescendants() do applyGlow(p) end end
	if cityF then
		for _, d in cityF:GetDescendants() do
			if d.Name == "LampHead" then applyLamp(d) elseif d.Name == "Tree" then applyTree(d) else applyGlow(d) end
		end
	end
	if trees then for _, m in trees:GetChildren() do applyTree(m) end end
end
local function applyQuality()
	local Q = Config.Quality[qName()]
	Lighting.GlobalShadows = Q.shadows
	local bloom = Lighting:FindFirstChild("KaidoBloom")
	if bloom then bloom.Enabled = Q.bloom end
	applyWorld()
end
local carModel: Model? = nil
local function setCarLights(m, on)
	local root = m.PrimaryPart
	if root and root:FindFirstChild("Beam") then root.Beam.Enabled = on end
end
local function applyTime()
	Lighting.ClockTime = curTime()
	local n = night()
	local dusk = math.clamp(1 - math.min(math.abs(curTime() - 6), math.abs(curTime() - 18)) / 1.5, 0, 1)
	Lighting.Ambient = n and Color3.fromRGB(34, 38, 62) or Color3.fromRGB(110, 110, 118)
	Lighting.OutdoorAmbient = n and Color3.fromRGB(58, 64, 100) or Color3.fromRGB(130, 134, 146):Lerp(Color3.fromRGB(150, 110, 100), dusk)
	Lighting.Brightness = n and 1.4 or 2.6
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = n and 0.3 or 0.26
		atmo.Color = n and Color3.fromRGB(72, 82, 122) or Color3.fromRGB(199, 214, 232):Lerp(Color3.fromRGB(240, 160, 120), dusk)
		atmo.Decay = n and Color3.fromRGB(22, 24, 42) or Color3.fromRGB(106, 122, 150):Lerp(Color3.fromRGB(160, 90, 80), dusk)
	end
	applyWorld()
	if carModel then setCarLights(carModel, n) end
end
applyQuality()
applyTime()

-- ===================== the car =====================
local camMode = S.cam
local carDef = Config.car(profile.selected)
local START = 8
local P = CarPhysics.new(Track.X[START] / K, Track.Z[START] / K, Track.heading(START))
local idx, posY, vy = START, Track.Y[START], 0
local groundN, onGround = Vector3.yAxis, true
local onPass = true
local roll, rollV, pitch, pitchV, fspin = 0, 0, 0, 0, 0
local garageSel = profile.selected
local sound = nil
local usingMesh = false
local input = { throttle = 0, brake = 0, hand = false, steer = 0 }
local physSet = { assist = S.assist, trans = S.trans, sens = S.sens }
local junction = mapFolder:GetAttribute("Junction") or 1
local function nearJunction(k)
	local d = math.abs(k - junction)
	return math.min(d, Track.N - d) <= 7
end

local function buildCar(def, name, paint)
	local m = CarMesh.build(def, name, paint)
	if m then return m, true end
	return CarModel.build(def, name, paint), false
end
local function placeCar(m, mesh, cf, steer, rf, rr)
	if mesh then CarMesh.place(m, cf, steer, rf, rr) else CarModel.place(m, cf, steer, rf) end
end

-- cosmetics bought in the garage: underglow, rim colour, stance kit (lowered body)
local function applyStyle(m, def)
	local cs = profile.cos and profile.cos[def.id]
	local size = Vector3.new(def.b.wid * K, 1, def.b.len * K)
	Fx.underglow(m, cs and cs.glowOwned and cs.glow > 0 and Config.GlowColors[cs.glow] or nil, size)
	local rim = cs and cs.rimsOwned and Config.RimColors[cs.rims] or def.rim
	local drop = cs and cs.kit and 0.35 or 0
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local wheel = p:GetAttribute("Wheel") ~= nil or string.match(p.Name, "^Rim") or string.match(p.Name, "^Spoke") or string.match(p.Name, "^Tire") or string.match(p.Name, "^Tyre") or string.match(p.Name, "^Hub") or string.match(p.Name, "^Caliper")
			if wheel and p.Material == Enum.Material.Metal and not string.match(p.Name, "^Hub") and not string.match(p.Name, "^Caliper") then p.Color = rim end
			local w = p:FindFirstChild("W")
			if not wheel and p.Name ~= "Underglow" and w and w:IsA("Weld") then
				local baseC0 = p:GetAttribute("BaseC0")
				if not baseC0 then baseC0 = w.C0; p:SetAttribute("BaseC0", baseC0) end
				w.C0 = CFrame.new(0, -drop, 0) * baseC0
			end
		end
	end
end
local function spawnCar(id)
	if carModel then carModel:Destroy() end
	if sound then sound:destroy(); sound = nil end
	local base = Config.car(id or profile.selected)
	carDef = Config.tuned(base, profile.upg and profile.upg[base.id]) -- garage upgrades change the real numbers
	local col = paintOf(carDef.id)
	carModel, usingMesh = buildCar(carDef, "MyCar", col)
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
	setCarLights(carModel, night())
	applyStyle(carModel, carDef)
	if Audio.available() then sound = Audio.new(carModel, carDef, true) end
end

local drift = { active = false, score = 0, mult = 1, time = 0, idle = 0, tags = {}, combo = 1, comboT = 0, sign = 1, tandemPts = 0 }
local function placeAt(x, y, z, h)
	P = CarPhysics.new(x / K, z / K, h)
	posY, vy = y, 0
	idx = Track.nearest(x, z, nil)
	drift.active, drift.score, drift.mult, drift.combo, drift.comboT, drift.tandemPts = false, 0, 1, 1, 0, 0
	Fx.clearSkids()
end
local function resetCar(i)
	if not onPass and not i then
		-- in the city: back onto the nearest street, facing along it
		local min, cpitch, street = mapFolder:GetAttribute("CityMin"), mapFolder:GetAttribute("CityPitch"), mapFolder:GetAttribute("CityStreet")
		if min then
			local x, z = P.x * K, P.z * K
			local gx = min.X + math.floor((x - min.X) / cpitch + 0.5) * cpitch + street / 2
			local gz = min.Y + math.floor((z - min.Y) / cpitch + 0.5) * cpitch + street / 2
			if math.abs(x - gx) < math.abs(z - gz) then placeAt(gx, (World.ground(gx, 200, z)) or 7, z, 0) else placeAt(x, (World.ground(x, 200, gz)) or 7, gz, math.pi / 2) end
			return
		end
	end
	i = i or Track.nearest(P.x * K, P.z * K, idx)
	placeAt(Track.X[i], Track.Y[i], Track.Z[i], Track.heading(i))
end
local function goCity()
	local sp = mapFolder:GetAttribute("CitySpawn")
	if sp then placeAt(sp.X, sp.Y + 0.5, sp.Z, math.pi / 2); onPass = false end
end

local shake, wallT, lastZone = 0, 0, -1
local showToast -- set up with the HUD below
-- ===================== screens =====================
-- title
local title, tCol = Ui.sheet(gui)
text({ Text = 'KAIDO DRIFT\n<font color="#ff7eb6" size="40">街道 · 峠</font>', FontFace = Ui.DISPLAY, TextSize = 62, LineHeight = 0.95, LayoutOrder = 1, Parent = tCol })
text({ Text = "Midnight at Lake Ashi. Slide a 1989 coupe through Kojiri village, up the Hakone hairpins and along the shore, then down into the neon streets and elevated expressway of Shin-Hakone city. Earn credits for every drift and unlock the garage.", TextColor3 = Ui.DIM, TextSize = 16, LineHeight = 1.3, LayoutOrder = 2, Parent = tCol })
local tStats = Ui.stats({ { "Credits", Ui.GOLD }, { "Best drift" }, { "Cars" } }, 3, tCol)
local tMenu = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = tCol }, { Ui.list(10) })
U.bSolo = Ui.button("Play solo", "Just you on the mountain", "primary", 1, tMenu)
U.bPublic = Ui.button("Play with others", "Public map · drift together · chat", nil, 2, tMenu)
U.bGarage = Ui.button("Garage", "Unlock & paint", nil, 3, tMenu)
U.bSettings = Ui.button("Settings", "Graphics, gearbox, assists, sound", nil, 4, tMenu)
U.bBoards = Ui.button("Leaderboards", "Best drift and total points, worldwide", nil, 5, tMenu)
U.bAdmin = Ui.button("Admin panel", "Only you can see this", "ghost", 7, tMenu)
U.bAdmin.Visible = profile.admin == true
do
	local f = Ui.field("Start at", 6, tMenu)
	Ui.chips({ { "city", "Shin-Hakone city" }, { "pass", "Hakone pass" } }, S.start, function(v) S.start = v; saveSettings() end, 1, f)
end
Ui.fine(touch and "Drag on the left to steer. GAS, BRAKE and HAND BRAKE are on the right; hold BRAKE when stopped to reverse. To start a drift: steer hard with GAS, tap HAND BRAKE, or lift and re-press GAS (clutch kick). CAM switches to the cockpit view."
	or "W/↑ gas · S/↓ brake (hold to reverse) · A D / ← → steer · Space hand brake · drift: steer + gas, tap Space, or lift and re-press W (clutch kick) · C camera · Q/E shift (manual) · R reset · Esc pause. Controllers work too.", 5, tCol)
-- today's challenges (reset every day at 00:00 UTC)
U.dailyF = Ui.field("Daily challenges", 4, tCol)
U.dailyF.LayoutOrder = 5
U.dailyRows = {}
for k = 1, 3 do
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = k, Parent = U.dailyF }, { Ui.list(4) })
	local label = text({ Text = "", TextSize = 14, RichText = true, LayoutOrder = 1, Parent = row })
	local back = make("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, LayoutOrder = 2, Parent = row }, { Ui.corner(3) })
	local bar = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Ui.NEON, BorderSizePixel = 0, Parent = back }, { Ui.corner(3) })
	U.dailyRows[k] = { label = label, bar = bar }
end
local function refreshDaily()
	for k, r in U.dailyRows do
		local c = profile.daily and profile.daily[k]
		r.label.Parent.Visible = c ~= nil
		if c then
			r.label.Text = (c.done and '<font color="#59e3ff">✓ </font>' or "") .. c.text .. '  <font color="#ffc94d">+' .. fmt(c.reward) .. " CR</font>"
			r.bar.Size = UDim2.new(math.clamp(c.prog / c.goal, 0, 1), 0, 1, 0)
			r.bar.BackgroundColor3 = c.done and Ui.NEON or Ui.SAKURA
		end
	end
end
local function refreshTitle()
	refreshDaily()
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
U.gPaintF = Ui.field("Paint (free)", 5, gCol)
local gSwatches = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = U.gPaintF }, {
	make("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder }),
})
U.gUpF = Ui.field("Upgrades", 6, gCol)
local gUpList = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = U.gUpF }, { Ui.list(8) })
U.gStyleF = Ui.field("Style", 7, gCol)
local gStyle = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = U.gStyleF }, { Ui.list(10) })
Ui.fine("Drag on the car to turn it around.", 8, gCol)
U.gBack = Ui.button("Back", nil, nil, 9, gCol)
local renderGarage
local function statBar(label, v, parent, order)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	text({ Text = string.upper(label), TextSize = 12, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 110, 1, 0), Parent = row })
	local back = make("Frame", { Size = UDim2.new(1, -120, 0, 6), Position = UDim2.new(0, 120, 0.5, -3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = row }, { Ui.corner(3) })
	make("Frame", { Size = UDim2.new(math.clamp(v, 0.05, 1), 0, 1, 0), BackgroundColor3 = Ui.NEON, BorderSizePixel = 0, Parent = back }, { Ui.corner(3) })
end
-- upgrades and style for the highlighted car (only once you own it)
local function tune(id, action, value)
	task.spawn(function()
		local res = R.Tune:InvokeServer(id, action, value)
		if res then profile = res; profile.settings = S; spawnCar(garageSel); renderGarage(); refreshTitle() end
	end)
end
local function swatchRow(parent, order, colors, cur, withOff, onPick)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }, {
		make("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for k = withOff and 0 or 1, #colors do
		local sel = k == cur
		local sw = make("TextButton", { Size = UDim2.new(0, 34, 0, 34), Text = k == 0 and "OFF" or "", TextSize = 9, FontFace = Ui.BOLD, TextColor3 = Ui.DIM,
			AutoButtonColor = false, BackgroundColor3 = k == 0 and Ui.INK or colors[k], LayoutOrder = k, Parent = row }, {
			make("UICorner", { CornerRadius = UDim.new(0, 17) }), Ui.stroke(sel and Ui.SAKURA or Ui.LINE, sel and 3 or 1, sel and 0 or 0.6),
		})
		Ui.bouncy(sw)
		sw.Activated:Connect(function() onPick(k) end)
	end
end
local function renderTuning(car, have)
	for _, c in gUpList:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for _, c in gStyle:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	if not have then
		Ui.fine("Own this car to upgrade and style it.", 1, gUpList)
		Ui.fine("Own this car to upgrade and style it.", 1, gStyle)
		return
	end
	local u = profile.upg and profile.upg[car.id] or {}
	for k, up in Config.Upgrades do
		local l = u[up.key] or 0
		local pips = string.rep("●", l) .. string.rep("○", Config.UPGRADE_MAX - l)
		if l >= Config.UPGRADE_MAX then
			Ui.button(up.name .. "   " .. pips, up.desc .. " · fully upgraded", nil, k, gUpList)
		else
			local cost = up.cost[l + 1]
			local b = Ui.button(up.name .. "   " .. pips, up.desc .. " · " .. fmt(cost) .. " CR", profile.credits >= cost and "primary" or nil, k, gUpList)
			b.Activated:Connect(function()
				if profile.credits >= cost then tune(car.id, "up_" .. up.key) else showToast("Need " .. fmt(cost - profile.credits) .. " more CR", Ui.DANGER) end
			end)
		end
	end
	local cs = profile.cos and profile.cos[car.id] or {}
	-- underglow
	local f1 = Ui.field(Config.Cosmetics.glow.name, 1, gStyle)
	if cs.glowOwned then
		swatchRow(f1, 1, Config.GlowColors, cs.glow or 0, true, function(k) tune(car.id, "glow", k) end)
	else
		local c = Config.Cosmetics.glow.cost
		Ui.button("Fit underglow", fmt(c) .. " CR · then any colour, free", profile.credits >= c and "primary" or nil, 1, f1).Activated:Connect(function() tune(car.id, "glowOwn") end)
	end
	-- rims
	local f2 = Ui.field(Config.Cosmetics.rims.name, 2, gStyle)
	if cs.rimsOwned then
		swatchRow(f2, 1, Config.RimColors, cs.rims or 1, false, function(k) tune(car.id, "rims", k) end)
	else
		local c = Config.Cosmetics.rims.cost
		Ui.button("Custom rims", fmt(c) .. " CR · then any colour, free", profile.credits >= c and "primary" or nil, 1, f2).Activated:Connect(function() tune(car.id, "rimsOwn") end)
	end
	-- stance kit
	local f3 = Ui.field(Config.Cosmetics.kit.name, 3, gStyle)
	if cs.kit then
		Ui.button("Remove stance kit", "Back to stock height (refitting costs " .. fmt(Config.Cosmetics.kit.cost) .. " CR)", "ghost", 1, f3).Activated:Connect(function() tune(car.id, "kitOff") end)
	else
		local c = Config.Cosmetics.kit.cost
		Ui.button("Fit stance kit", "Lowered body · " .. fmt(c) .. " CR", profile.credits >= c and "primary" or nil, 1, f3).Activated:Connect(function() tune(car.id, "kitOwn") end)
	end
end
renderGarage = function()
	gStats[1].Text = fmt(profile.credits)
	for _, c in gList:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local order = 0
	for k, car in Config.Cars do
		order += 1
		if car.premium and not Config.Cars[k - 1].premium then
			-- the Robux section, with its own header
			local h = text({ Text = 'SPECIAL CARS  <font color="#b3b0c4">·  faster than anything in the garage  ·  Robux</font>', TextSize = 12, FontFace = Ui.BOLD, TextColor3 = Ui.VIOLET, LayoutOrder = order, Parent = gList })
			h.RichText = true
			order += 1
		end
		local sel = car.id == garageSel
		local have = owned(car.id)
		local card = make("TextButton", { Size = UDim2.new(1, 0, 0, 58), AutoButtonColor = false, Text = "", LayoutOrder = order, BackgroundColor3 = car.premium and Ui.VIOLET or Color3.new(1, 1, 1), BackgroundTransparency = sel and 0.82 or (car.premium and 0.9 or 0.97), Parent = gList },
			{ Ui.corner(14), Ui.stroke(sel and Ui.SAKURA or (car.premium and Ui.VIOLET or Ui.LINE), sel and 1.5 or 1, sel and 0 or (car.premium and 0.5 or 0.87)) })
		Ui.bouncy(card)
		text({ Text = car.name, FontFace = Ui.BOLD, TextSize = 16, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -150, 0, 22), Position = UDim2.new(0, 14, 0, 8), TextWrapped = false, Parent = card })
		text({ Text = car.tag, TextSize = 13, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -150, 0, 18), Position = UDim2.new(0, 14, 0, 31), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		local pr = car.id == profile.selected and "DRIVING" or have and "OWNED"
			or car.premium and (car.pass > 0 and ("R$ " .. car.robux) or "COMING SOON")
			or (fmt(car.price) .. " CR")
		text({ Text = pr, FontFace = Ui.BOLD, TextSize = 15, TextColor3 = have and Ui.NEON or car.premium and Ui.VIOLET or (profile.credits >= car.price and Ui.GOLD or Ui.DIM), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(1, -144, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = card })
		card.Activated:Connect(function()
			garageSel = car.id
			spawnCar(car.id)
			renderGarage()
		end)
	end
	-- detail for the highlighted car
	for _, c in gDetail:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local car = Config.tuned(Config.car(garageSel), profile.upg and profile.upg[garageSel])
	local kwPerT = car.torque * math.min(car.red * 0.9, car.peak + 1600) / 9549 / (car.mass / 1000)
	statBar("Power", kwPerT / 260, gDetail, 1)
	statBar("Grip", (car.mu - 0.98) / 0.22, gDetail, 2)
	statBar("Weight", 1 - (car.mass - 900) / 700, gDetail, 3)
	statBar("Steering lock", (car.lock - 46) / 17, gDetail, 4)
	statBar("Agility", 1 - (car.b.wb - 2.2) / 0.6, gDetail, 5)
	text({ Text = car.tag .. "  ·  " .. (car.turbo and "turbo" or "naturally aspirated") .. "  ·  " .. #car.gears .. "-speed", TextSize = 13, TextColor3 = Ui.DIM, LayoutOrder = 0, Parent = gDetail })
	local have = owned(car.id)
	local label, note, kind
	if car.id == profile.selected then
		label, note, kind = "Driving this car", nil, nil
	elseif have then
		label, note, kind = "Drive this car", nil, "primary"
	elseif car.premium then
		if car.pass > 0 then
			label, note, kind = "Buy for R$ " .. car.robux, "One-time Robux purchase · yours on every device", "primary"
		else
			label, note, kind = "Coming soon", "Not on sale yet", nil
		end
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
		elseif not have and car.premium then
			if car.pass > 0 then R.BuySpecial:FireServer(car.id) end
			return
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
	renderTuning(car, have)
end

-- leaderboards (the server refreshes them every minute)
local boards, bCol = Ui.sheet(gui, true)
Ui.heading("Leaderboards", "ランキング", 1, bCol)
U.boardCols = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = bCol }, { Ui.list(16) })
U.boardsBack = Ui.button("Back", nil, nil, 4, bCol)
Ui.fine("Updated every minute. Your scores count once you bank a drift. The same board glows over the street at the city start.", 3, bCol)
local function renderBoards()
	for _, c in U.boardCols:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("Boards") or "{}") end)
	data = ok and data or {}
	for order, col in { { "best", "Best single drift", Ui.GOLD }, { "total", "Total drift points", Ui.NEON } } do
		local f = Ui.field(col[2], order, U.boardCols)
		local list = data[col[1]] or {}
		if #list == 0 then Ui.fine("No scores yet. Bank a drift to be first.", 1, f) end
		for k, e in list do
			local me = e[1] == player.Name
			local row = Ui.glass(make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = k, Parent = f }), 12, me and 0.2 or 0.5)
			text({ Text = k .. "   " .. e[1], TextSize = 15, FontFace = Ui.BOLD, TextColor3 = me and Ui.SAKURA or Ui.TEXT, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -150, 1, 0), Position = UDim2.new(0, 14, 0, 0), TextWrapped = false, TextYAlignment = Enum.TextYAlignment.Center, Parent = row })
			text({ Text = fmt(e[2]), TextSize = 15, FontFace = Ui.BOLD, TextColor3 = col[3], AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(1, -144, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false, Parent = row })
		end
	end
end

-- admin panel (its own module; only drawn for admins, the server checks every action again)
U.adminPanel = require(script.Parent:WaitForChild("AdminPanel")).init({
	Ui = Ui, R = R, U = U, gui = gui, player = player, Config = Config,
	placeAt = function(x, y, z, h) placeAt(x, y, z, h); onPass = false end,
	goCity = function() goCity() end,
	goPass = function() resetCar(START); onPass = true end,
	getPos = function() return P.x * K, posY, P.z * K, P.h end,
	setMode = function(m) U.setMode(m) end,
	setBoost = function() end, -- the drive loop builds the boosted car when U.boost is on
})
U.adminRoot = U.adminPanel.root

-- settings
local settings, sCol = Ui.sheet(gui)
Ui.heading("Settings", "設定", 1, sCol)
do
	local f = Ui.field("Graphics quality", 2, sCol)
	Ui.chips({ { "auto", "Auto" }, { "low", "Low" }, { "medium", "Medium" }, { "high", "High" } }, S.quality, function(v) S.quality = v; applyQuality(); saveSettings() end, 1, f)
	Ui.fine("Low: phones and older computers. Medium adds shadows. High adds bloom and every tree.", 2, f)
end
local setTimeSlider, setTimeChips
do
	local f, l = Ui.field("Time of day", 3, sCol)
	U.timeLabel = l
	local function show() U.timeLabel.Text = string.format("TIME OF DAY · %02d:%02d", math.floor(S.time), math.floor((S.time % 1) * 60 + 0.5)) end
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
	local am = Audio.mode()
	if am == "full" then
		Ui.fine("Engine sound: the game's own engine sounds are installed.", 3, f)
	elseif am == "simple" then
		Ui.fine("Engine sound: using an engine sound from the Toolbox. Add a tyre screech too (name with \"tire\" or \"screech\").", 3, f)
	else
		Ui.fine('<font color="#ffc94d">No engine sound in this place yet.</font> Quickest fix, no uploading: in Studio open Toolbox › Audio, search "car engine loop", click one so it lands in Workspace (keep "engine" in its name). Do the same for "tire screech". Or upload the game\'s own 7 kaido_*.ogg sounds for the full engine.', 3, f)
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
U.sBack = Ui.button("Back", nil, nil, 10, sCol)

-- pause
local pause, pCol = Ui.sheet(gui)
Ui.heading("Paused", "一時停止", 1, pCol)
local pMenu = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = pCol }, { Ui.list(10) })
U.pResume = Ui.button("Resume", nil, "primary", 1, pMenu)
U.pGarage = Ui.button("Garage", "Unlock & paint", nil, 2, pMenu)
U.pSettings = Ui.button("Settings", "Graphics, gearbox, assists", nil, 3, pMenu)
U.pPass = Ui.button("Go to Hakone pass", "Start line at Kojiri", nil, 4, pMenu)
U.pCity = Ui.button("Go to Shin-Hakone city", "Neon streets & expressway", nil, 5, pMenu)
U.pPhoto = Ui.button("Photo mode", "Freeze the moment · drag to frame your shot", nil, 6, pMenu)
U.pQuit = Ui.button("Main menu", nil, "ghost", 7, pMenu)
U.pAdmin = Ui.button("Admin panel", "Only you can see this", "ghost", 8, pMenu)
U.pAdmin.Visible = profile.admin == true

-- ===================== HUD =====================
local hud = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
-- photo mode: just the scene, plus a small glass bar to leave
U.photoBar = Ui.glass(make("Frame", { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Visible = false, Parent = gui }, { Ui.list(12, true, Enum.VerticalAlignment.Center), Ui.pad(16, 8, 8, 8) }), 18, 0.4)
text({ Text = touch and "Drag to orbit · pinch to zoom" or "Drag to orbit · scroll to zoom · Esc to leave", TextSize = 13, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false, LayoutOrder = 1, Parent = U.photoBar })
U.photoExit = Ui.bouncy(make("TextButton", { Size = UDim2.new(0, 120, 0, 34), Text = "Done", TextColor3 = Ui.INK, FontFace = Ui.BOLD, TextSize = 14, BackgroundColor3 = Ui.SAKURA, AutoButtonColor = false, LayoutOrder = 2, Parent = U.photoBar }, { Ui.corner(17) }))
U.photo = { yaw = 0, pitch = 0.25, dist = 9 }
local shadowT = function(o) make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = o }); return o end
local tl = Ui.glass(make("Frame", { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, Position = UDim2.new(0, 16, 0, 62), Parent = hud }, { Ui.list(2), Ui.pad(14, 8, 18, 10) }), 16, 0.45)
U.credRow = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1, Parent = tl }, { Ui.list(8, true, Enum.VerticalAlignment.Bottom) })
text({ Text = "CR", TextSize = 11, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false, LayoutOrder = 1, Parent = U.credRow })
local hCredits = shadowT(text({ Text = "0", TextSize = 22, FontFace = Ui.BOLD, TextColor3 = Ui.GOLD, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false, LayoutOrder = 2, Parent = U.credRow }))
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
showToast = function(t, c) toast.Text, toast.TextColor3, toast.TextTransparency, toastT = t, c or Ui.GOLD, 0, 2.4; Ui.pop(toast, 1.25) end
local hint = make("TextLabel", { Size = UDim2.new(0, 0, 0, 34), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 0), BackgroundColor3 = Color3.fromHex("0a0b14"), BackgroundTransparency = 0.3, Text = "", FontFace = Ui.BOLD, TextSize = 14, TextColor3 = Ui.TEXT, Visible = false, Parent = hud }, { Ui.corner(4), Ui.pad(14, 0, 14, 0) })
-- speed
local spBox = Ui.glass(make("Frame", { Size = UDim2.new(0, 210, 0, 96), Position = UDim2.new(0.5, -105, 1, touch and -112 or -108), Parent = hud }, { Ui.pad(10, 6, 10, 6) }), 20, 0.45)
local hSpeed = shadowT(text({ Text = "0", TextSize = touch and 42 or 56, FontFace = Ui.DISPLAY, TextXAlignment = Enum.TextXAlignment.Right, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.6, 0, 0, 56), Parent = spBox }))
text({ Text = "KM/H", TextSize = 11, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.38, 0, 0, 14), Position = UDim2.new(0.64, 0, 0, 12), Parent = spBox })
local hGear = shadowT(text({ Text = "1", TextSize = 22, FontFace = Ui.BOLD, TextColor3 = Ui.NEON, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.38, 0, 0, 26), Position = UDim2.new(0.64, 0, 0, 26), Parent = spBox }))
U.rpmBack = make("Frame", { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0, 62), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.87, BorderSizePixel = 0, Parent = spBox }, { Ui.corner(2) })
local rpmBar = make("Frame", { Size = UDim2.new(0.2, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = U.rpmBack }, {
	Ui.corner(2), make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Ui.NEON), ColorSequenceKeypoint.new(0.85, Ui.SAKURA), ColorSequenceKeypoint.new(1, Ui.DANGER) }) }),
})
local hAngle = text({ Text = "", TextSize = 11, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 70), Parent = spBox })
-- minimap (the pass and the city)
local mmSize = touch and 100 or 150
local mm = make("Frame", { Size = UDim2.new(0, mmSize, 0, mmSize), Position = UDim2.new(1, -mmSize - 14, 0, 14), BackgroundColor3 = Color3.fromHex("1a1d36"), BackgroundTransparency = 0.45, ClipsDescendants = true, Parent = hud }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Ui.stroke(Ui.LINE, 1.5, 0.7) })
local cityMin, cityMax = mapFolder:GetAttribute("CityMin"), mapFolder:GetAttribute("CityMax")
local mmMinX, mmMaxX, mmMinZ, mmMaxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, Track.N do
	mmMinX, mmMaxX = math.min(mmMinX, Track.X[i]), math.max(mmMaxX, Track.X[i])
	mmMinZ, mmMaxZ = math.min(mmMinZ, Track.Z[i]), math.max(mmMaxZ, Track.Z[i])
end
if cityMin then
	mmMinX, mmMaxX = math.min(mmMinX, cityMin.X), math.max(mmMaxX, cityMax.X)
	mmMinZ, mmMaxZ = math.min(mmMinZ, cityMin.Y), math.max(mmMaxZ, cityMax.Y)
end
local mmSpan = math.max(mmMaxX - mmMinX, mmMaxZ - mmMinZ) * 1.08
local function mmPos(x, z) return UDim2.new(0.5 + (x - (mmMinX + mmMaxX) / 2) / mmSpan, 0, 0.5 + (z - (mmMinZ + mmMaxZ) / 2) / mmSpan, 0) end
U.zoneCol = { [0] = Ui.NEON, [1] = Ui.SAKURA, [2] = Ui.GOLD }
for i = 1, Track.N, math.max(1, Track.N // 260) do
	make("Frame", { Size = UDim2.new(0, 3, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = mmPos(Track.X[i], Track.Z[i]), BackgroundColor3 = U.zoneCol[Track.ZONE[i]], BorderSizePixel = 0, Parent = mm })
end
if cityMin then
	local grid, pitch, street = mapFolder:GetAttribute("CityGrid"), mapFolder:GetAttribute("CityPitch"), mapFolder:GetAttribute("CityStreet")
	local span = (cityMax.X - cityMin.X) / mmSpan
	for k = 0, grid, 2 do
		local x = cityMin.X + k * pitch + street / 2
		make("Frame", { Size = UDim2.new(0, 1, span, 0), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(mmPos(x, 0).X.Scale, 0, mmPos(0, cityMin.Y).Y.Scale, 0), BackgroundColor3 = Color3.fromRGB(200, 200, 210), BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = mm })
		local z = cityMin.Y + k * pitch + street / 2
		make("Frame", { Size = UDim2.new(span, 0, 0, 1), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(mmPos(cityMin.X, 0).X.Scale, 0, mmPos(0, z).Y.Scale, 0), BackgroundColor3 = Color3.fromRGB(200, 200, 210), BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = mm })
	end
	local r1, r2 = mapFolder:GetAttribute("CityRing"), mapFolder:GetAttribute("CityRing2")
	local p0, p1 = mmPos(r1.X, r1.Y), mmPos(r1.Z, r2)
	make("Frame", { Size = UDim2.new(p1.X.Scale - p0.X.Scale, 0, p1.Y.Scale - p0.Y.Scale, 0), Position = p0, BackgroundTransparency = 1, Parent = mm }, { make("UIStroke", { Color = Ui.SAKURA, Thickness = 1.5 }) })
end
local mmMe = make("Frame", { Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.SAKURA, BorderSizePixel = 0, ZIndex = 3, Parent = mm }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), make("UIStroke", { Color = Ui.INK, Thickness = 2 }) })
-- buttons: bottom-right row on computers, a row beside the minimap on phones
local hb = make("Frame", { Size = UDim2.new(0, 4 * 60, 0, 44), BackgroundTransparency = 1, Parent = hud }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }),
})
hb.Position = touch and UDim2.new(1, -mmSize - 14 - 4 * 60 - 8, 0, 14) or UDim2.new(1, -4 * 60 - 14, 1, -58)
local function hudBtn(t, order)
	return Ui.bouncy(Ui.glass(make("TextButton", { Size = UDim2.new(0, 54, 0, 44), Text = t, TextColor3 = Ui.TEXT, FontFace = Ui.BOLD, TextSize = 13, AutoButtonColor = false, LayoutOrder = order, Parent = hb }), 14, 0.45))
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
		local b = make("TextButton", { Size = size, Position = pos, BackgroundColor3 = color, BackgroundTransparency = 0.3, Text = t, TextColor3 = Ui.INK, FontFace = Ui.BOLD, TextSize = 15, AutoButtonColor = false, Parent = hud }, { Ui.corner(18), Ui.stroke(Ui.LINE, 1.5, 0.5), make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.3) }) })
		Ui.bouncy(b)
		local held = {}
		b.InputBegan:Connect(function(io) if io.UserInputType == Enum.UserInputType.Touch then held[io] = true; touchState[key] = true; b.BackgroundTransparency = 0.05 end end)
		b.InputEnded:Connect(function(io) held[io] = nil; if next(held) == nil then touchState[key] = false; b.BackgroundTransparency = 0.3 end end)
		return b
	end
	pedal("GAS", UDim2.new(0, 88, 0, 150), UDim2.new(1, -102, 1, -164), Ui.SAKURA, "gas")
	pedal("BRAKE", UDim2.new(0, 84, 0, 70), UDim2.new(1, -194, 1, -84), Color3.fromRGB(214, 216, 226), "brake")
	pedal("HAND", UDim2.new(0, 84, 0, 70), UDim2.new(1, -194, 1, -164), Ui.NEON, "hand")
	local reset = Ui.bouncy(Ui.glass(make("TextButton", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(1, -58, 1, -214), Text = "↺", TextColor3 = Ui.TEXT, TextSize = 20, FontFace = Ui.BOLD, AutoButtonColor = false, Parent = hud }), 14, 0.45))
	reset.Activated:Connect(function() resetCar() end)
	shiftRow = make("Frame", { Size = UDim2.new(0, 100, 0, 40), Position = UDim2.new(1, -164, 1, -214), BackgroundTransparency = 1, Parent = hud }, { Ui.list(8, true) })
	for k, d in { { "▼", -1 }, { "▲", 1 } } do
		local sb = Ui.bouncy(Ui.glass(make("TextButton", { Size = UDim2.new(0, 46, 0, 40), Text = d[1], TextColor3 = Ui.TEXT, TextSize = 18, FontFace = Ui.BOLD, AutoButtonColor = false, LayoutOrder = k, Parent = shiftRow }), 14, 0.45))
		sb.Activated:Connect(function() if d[2] > 0 then CarPhysics.shiftUp(P, carDef) else CarPhysics.shiftDown(P, carDef) end end)
	end
end

-- ===================== other players on the public map =====================
local ghosts = {}
local publicMap = false
local mode = "title" -- title | garage | settings | pause | play
R.Others.OnClientEvent:Connect(function(uid, x, y, z, h, carId, paint, drifting)
	if not publicMap or (mode ~= "play" and mode ~= "pause") then return end
	local g = ghosts[uid]
	if not g or g.carId ~= carId or g.paint ~= paint then
		if g then g.model:Destroy(); if g.sound then g.sound:destroy() end end
		local car = Config.car(carId)
		local m, mesh = buildCar(car, "Driver" .. uid, paint > 0 and Config.Paints[paint] or car.color)
		local who = Players:GetPlayerByUserId(uid)
		local tag = make("BillboardGui", { Size = UDim2.new(0, 160, 0, 24), StudsOffset = Vector3.new(0, 7, 0), AlwaysOnTop = true, MaxDistance = 500, Parent = m.PrimaryPart })
		text({ Text = who and who.DisplayName or "Driver", TextSize = 15, FontFace = Ui.BOLD, TextColor3 = Ui.NEON, TextXAlignment = Enum.TextXAlignment.Center, Parent = tag })
		m.Parent = workspace
		setCarLights(m, night())
		g = { model = m, mesh = mesh, carId = carId, paint = paint, cf = CFrame.new(x, y, z) * CFrame.Angles(0, h + math.pi, 0), sound = Audio.available() and Audio.new(m, car, false) or nil, rpm = 3000, spin = 0 }
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
local returnTo = "title"
local warnedSound = false
-- version badge on the menus (bottom right)
U.version = Ui.glass(make("TextLabel", { Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16), Text = "Version " .. Config.VERSION, TextSize = 13, FontFace = Ui.BOLD, TextColor3 = Ui.TEXT, ZIndex = 20, Parent = gui },
	{ Ui.pad(12, 0, 12, 0) }), 14, 0.45)
local function setMode(m)
	if (m == "garage" or m == "settings") and (mode == "pause" or mode == "play") then returnTo = "pause"
	elseif m == "garage" or m == "settings" then returnTo = "title" end
	if mode == "garage" and m ~= "garage" and garageSel ~= profile.selected then garageSel = profile.selected; spawnCar() end
	mode = m
	-- the new screen slides in on glass; the world behind blurs while a menu is open
	if m == "boards" then renderBoards() end
	if m == "admin" then U.adminPanel.refresh() end
	for name, root in { title = title, garage = garage, settings = settings, pause = pause, boards = boards, admin = U.adminRoot } do
		if name == m then
			if not root.Visible then Ui.show(root) end
		else
			root.Visible = false
		end
	end
	Ui.blur(m ~= "play" and m ~= "photo")
	U.version.Visible = m ~= "play" and m ~= "photo"
	U.photoBar.Visible = m == "photo"
	if m ~= "play" then Fx.tandem(nil, nil, 0) end
	if m == "photo" then U.photo.yaw, U.photo.pitch, U.photo.dist = P.h + math.pi * 0.75, 0.22, 8 end
	hud.Visible = m == "play"
	if m == "title" then clearGhosts(); refreshTitle() end
	if m == "garage" then garageSel = profile.selected; renderGarage() end
	if m == "play" and shiftRow then shiftRow.Visible = S.trans == "manual" end
	if m ~= "play" and sound then sound:mute() end
end
U.setMode = setMode
local function start(public)
	publicMap = public
	R.SetMode:FireServer(public and "public" or "solo")
	setMode("play")
	if S.start == "city" then goCity() else resetCar(START); onPass = true end
	lastZone = -1
	showToast(public and "Public map · everyone here drives together" or "Solo · just you", public and Ui.NEON or Ui.TEXT)
	if not warnedSound and not Audio.available() then
		warnedSound = true
		task.delay(2.6, function() showToast("No engine sound yet · see Settings › Sound", Ui.GOLD) end)
	end
	if not usingMesh and CarMesh.lastError then warn("Kaido Drift: browser car models unavailable (" .. CarMesh.lastError .. "). Turn on Game Settings › Security › Allow Mesh / Image APIs.") end
end
U.bSolo.Activated:Connect(function() start(false) end)
U.bPublic.Activated:Connect(function() start(true) end)
U.bGarage.Activated:Connect(function() setMode("garage") end)
U.bSettings.Activated:Connect(function() setMode("settings") end)
U.bBoards.Activated:Connect(function() setMode("boards") end)
U.boardsBack.Activated:Connect(function() setMode("title") end)
U.bAdmin.Activated:Connect(function() U.adminFrom = "title"; setMode("admin") end)
U.pAdmin.Activated:Connect(function() U.adminFrom = "pause"; setMode("admin") end)
-- the game owner can force one time of day for everyone
ReplicatedStorage:GetAttributeChangedSignal("KaidoTime"):Connect(function() applyTime(); applyWorld() end)
ReplicatedStorage:GetAttributeChangedSignal("Boards"):Connect(function() if mode == "boards" then renderBoards() end end)
U.gBack.Activated:Connect(function() setMode(returnTo) end)
U.sBack.Activated:Connect(function() physSet.assist, physSet.trans, physSet.sens = S.assist, S.trans, S.sens; setMode(returnTo) end)
U.pResume.Activated:Connect(function() setMode("play") end)
U.pGarage.Activated:Connect(function() setMode("garage") end)
U.pSettings.Activated:Connect(function() setMode("settings") end)
U.pPass.Activated:Connect(function() resetCar(START); onPass = true; setMode("play") end)
U.pCity.Activated:Connect(function() goCity(); setMode("play") end)
U.pQuit.Activated:Connect(function() R.SetMode:FireServer("solo"); setMode("title") end)
U.pPhoto.Activated:Connect(function() setMode("photo") end)
U.photoExit.Activated:Connect(function() setMode("pause") end)
-- drag to turn the car in the garage, or to orbit the camera in photo mode; wheel / pinch zooms
UserInputService.InputChanged:Connect(function(io, processed)
	if mode ~= "garage" and mode ~= "photo" then return end
	local t = io.UserInputType
	if t == Enum.UserInputType.MouseWheel and mode == "photo" then
		U.photo.dist = math.clamp(U.photo.dist - io.Position.Z * 0.8, 3, 30)
		return
	end
	if processed then return end
	local dragging = t == Enum.UserInputType.Touch or (t == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
	if not dragging then return end
	local d = io.Delta
	if mode == "garage" then
		U.orbitNudge = (U.orbitNudge or 0) - d.X * 0.008 -- applied by the camera below
		U.dragT = os.clock()
	else
		U.photo.yaw -= d.X * 0.008
		U.photo.pitch = math.clamp(U.photo.pitch + d.Y * 0.006, -0.1, 1.3)
	end
end)
UserInputService.TouchPinch:Connect(function(_, scale, _, state)
	if mode == "photo" and state == Enum.UserInputState.Change then U.photo.dist = math.clamp(U.photo.dist / math.max(scale, 0.5) ^ 0.05, 3, 30) end
end)
-- a special car bought with Robux: the server sends the new profile
R.Profile.OnClientEvent:Connect(function(res, message, why)
	if why == "admin" then
		profile = res
		profile.settings = S
		spawnCar(profile.selected) -- picks up new cars and upgrades
		showToast("Updated by the game owner", Ui.VIOLET)
		if mode == "garage" then renderGarage() end
		refreshTitle()
		return
	end
	local carChanged = res.selected ~= profile.selected
	profile = res
	profile.settings = S
	if message then
		-- a daily challenge finished: keep driving, just show it
		showToast(message, Ui.GOLD)
		if U.showCallout then U.showCallout("CHALLENGE COMPLETE!", Ui.NEON) end
	else
		garageSel = profile.selected
		if carChanged then spawnCar(profile.selected) end
		showToast("Unlocked · " .. Config.car(profile.selected).name, Ui.VIOLET)
	end
	if mode == "garage" then renderGarage() end
	refreshTitle()
end)
U.CAM_NAMES = { [0] = "Chase", [1] = "Far chase", [2] = "Cockpit · first person", [3] = "Hood" }
local function cycleCam()
	camMode = (camMode + 1) % 4
	S.cam = camMode
	setCamChips(camMode)
	saveSettings()
	showToast(U.CAM_NAMES[camMode], Ui.TEXT)
end
bCam.Activated:Connect(cycleCam)
bSnd.Activated:Connect(function() S.sound = not S.sound; saveSettings(); showToast(S.sound and "Sound on" or "Sound off", Ui.TEXT) end)
bPause.Activated:Connect(function() setMode("pause") end)
UserInputService.InputBegan:Connect(function(io, processed)
	if processed then return end
	local k = io.KeyCode
	if k == Enum.KeyCode.F2 and profile.admin and (mode == "play" or mode == "pause" or mode == "title") then
		U.adminFrom = if mode == "title" then "title" else "pause"
		setMode("admin")
		return
	end
	if mode == "play" then
		if k == Enum.KeyCode.C or k == Enum.KeyCode.V or k == Enum.KeyCode.ButtonY then cycleCam() end
		if k == Enum.KeyCode.R or k == Enum.KeyCode.ButtonSelect then resetCar() end
		if k == Enum.KeyCode.Escape or k == Enum.KeyCode.P or k == Enum.KeyCode.ButtonStart then setMode("pause") end
		if S.trans == "manual" then
			if k == Enum.KeyCode.E or k == Enum.KeyCode.ButtonR1 or k == Enum.KeyCode.DPadUp then CarPhysics.shiftUp(P, carDef) end
			if k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonL1 or k == Enum.KeyCode.DPadDown then CarPhysics.shiftDown(P, carDef) end
		end
	elseif mode == "pause" and (k == Enum.KeyCode.Escape or k == Enum.KeyCode.P or k == Enum.KeyCode.ButtonStart) then
		setMode("play")
	elseif mode == "photo" and (k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.ButtonStart) then
		setMode("pause")
	end
end)

-- ===================== input (as in the browser: keys ramp, gas rolls on) =====================
local kbSteer, kbThr = 0, 0
local function readInput(dt)
	local k = UserInputService
	local typing = k:GetFocusedTextBox() ~= nil
	local left = not typing and (k:IsKeyDown(Enum.KeyCode.A) or k:IsKeyDown(Enum.KeyCode.Left))
	local right = not typing and (k:IsKeyDown(Enum.KeyCode.D) or k:IsKeyDown(Enum.KeyCode.Right))
	local target = (right and 1 or 0) - (left and 1 or 0)
	local rate = if target == 0 then 7 elseif kbSteer ~= 0 and math.sign(target) ~= math.sign(kbSteer) then 9 else 4.2
	kbSteer += math.clamp(target - kbSteer, -rate * dt, rate * dt)
	local thrT = (not typing and (k:IsKeyDown(Enum.KeyCode.W) or k:IsKeyDown(Enum.KeyCode.Up))) or (touch and touchState.gas)
	kbThr += math.clamp((thrT and 1 or 0) - kbThr, -dt * 9, dt * (if kbThr < 0.5 then 6 else 3))
	local thr, steer = kbThr, kbSteer
	local brk = (not typing and (k:IsKeyDown(Enum.KeyCode.S) or k:IsKeyDown(Enum.KeyCode.Down))) and 1 or 0
	local hand = not typing and (k:IsKeyDown(Enum.KeyCode.Space) or k:IsKeyDown(Enum.KeyCode.LeftShift))
	if touch then
		if touchState.brake then brk = 1 end
		if touchState.hand then hand = true end
		if math.abs(touchState.steer) > math.abs(steer) then steer = touchState.steer end
	end
	local okPad, pad = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
	for _, io in (okPad and pad or {}) do
		if io.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(io.Position.X) > 0.12 and math.abs(io.Position.X) > math.abs(steer) then
			steer = math.sign(io.Position.X) * math.abs(io.Position.X) ^ 1.4
		end
		if io.KeyCode == Enum.KeyCode.ButtonR2 then thr = math.max(thr, io.Position.Z) end
		if io.KeyCode == Enum.KeyCode.ButtonL2 then brk = math.max(brk, io.Position.Z) end
	end
	-- hand brake on A, B or X (held), as most drift games map it
	local pad1 = Enum.UserInputType.Gamepad1
	for _, b in { Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX } do
		local okB, down = pcall(UserInputService.IsGamepadButtonDown, UserInputService, pad1, b)
		if okB and down then hand = true end
	end
	input.throttle, input.brake, input.hand, input.steer = thr, brk, hand, steer
end

-- ===================== drift scoring (as in the browser game) =====================
U.TIERS = { { 0, "DRIFT" }, { 3000, "GREAT DRIFT" }, { 8000, "AWESOME DRIFT" }, { 15000, "INSANE DRIFT" }, { 30000, "UNBELIEVABLE DRIFT" } }
local function tierOf(pts) local t = "DRIFT"; for _, x in U.TIERS do if pts >= x[1] then t = x[2] end end; return t end
local nearWall, tandem, tandemWith = false, 0, nil -- tandem: 0 (alone) .. 1 (door to door with another drifter)
-- big centre-screen callouts when a drift banks
U.CALLOUTS = { { 0, "NICE DRIFT!", Ui.TEXT }, { 5000, "GREAT DRIFT!", Ui.NEON }, { 15000, "AWESOME!", Ui.GOLD }, { 30000, "INSANE!", Ui.SAKURA }, { 60000, "LEGENDARY!", Ui.VIOLET } }
U.callout = shadowT(text({ Text = "", TextSize = touch and 34 or 58, FontFace = Ui.DISPLAY, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0.3, 0), TextTransparency = 1, Parent = hud }))
U.calloutT = 0
local function callout(t, color)
	U.callout.Text, U.callout.TextColor3, U.callout.TextTransparency, U.calloutT = t, color, 0, 1.6
	Ui.pop(U.callout, 1.5)
end
U.showCallout = callout
-- a rising ping each time the combo goes up (a sound every Roblox client has built in)
U.comboSound = make("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Parent = game:GetService("SoundService") })
local function comboUp()
	drift.combo = math.min(6, drift.combo + 0.5)
	Ui.pop(dMult, 1.4)
	if S.sound then
		U.comboSound.Volume = 0.45 * S.volume
		U.comboSound.PlaybackSpeed = 0.9 + drift.combo * 0.1
		U.comboSound:Play()
	end
end
local function endDrift(bank)
	if not drift.active then return end
	local total = math.floor(drift.score * drift.mult)
	local combo, tandemPts = drift.mult, math.floor(drift.tandemPts * drift.mult)
	drift.active = false
	table.clear(drift.tags)
	drift.combo, drift.mult, drift.comboT = 1, 1, 0
	if not bank or total < 50 then drift.score, drift.tandemPts = 0, 0; return end
	local cr = total // 10
	R.Bank:FireServer(total, if onPass then "pass" elseif lastZone == 3 then "city" else "link", tandemPts, combo)
	profile.credits += cr
	profile.total = (profile.total or 0) + total
	local best = total > profile.best
	if best then profile.best = total end
	local c = U.CALLOUTS[1]
	for _, x in U.CALLOUTS do if total >= x[1] then c = x end end
	callout(best and "NEW BEST!" or c[2], best and Ui.GOLD or c[3])
	showToast(string.format("+%s  ·  ×%.1f combo  ·  %s CR", fmt(total), combo, fmt(cr)), Ui.GOLD)
	drift.score, drift.tandemPts = 0, 0
end
local lastCrash = 0
local function crash(force)
	local now = os.clock()
	if now - lastCrash < 0.6 then return end
	lastCrash = now
	shake = math.min(1, force / 14)
	if drift.active and drift.score * drift.mult > 200 then
		callout("CRASH!", Ui.DANGER)
		showToast(fmt(drift.score * drift.mult) .. " lost  ·  combo reset", Ui.DANGER)
	end
	drift.active, drift.score, drift.tandemPts = false, 0, 0
	drift.combo, drift.mult, drift.comboT = 1, 1, 0
	table.clear(drift.tags)
end
-- points = angle × speed × time; the combo grows while you keep sliding (every 2.5 s) and each time you
-- link into the next drift (switching direction, or re-entering within 1.4 s). Straight for 1.4 s banks it.
local function updateScoring(dt, sp)
	local vdot = if onPass and sp > 1 then (P.vx * Track.TX[idx] + P.vz * Track.TZ[idx]) / sp else 1
	if P.drifting and sp > 8 and vdot > 0.2 then
		local sign = if P.slip > 0 then 1 else -1
		if not drift.active then
			drift.active, drift.score, drift.time, drift.tandemPts = true, 0, 0, 0
			drift.combo, drift.comboT, drift.sign = 1, 0, sign
		elseif drift.idle > 0.15 then
			comboUp() -- linked a new drift onto the chain
		elseif sign ~= drift.sign and math.abs(P.slip) > 0.17 then
			comboUp() -- direction switch (feint / S-bend)
		end
		if math.abs(P.slip) > 0.17 then drift.sign = sign end
		drift.idle = 0
		drift.time += dt
		drift.comboT += dt
		if drift.comboT >= 2.5 then drift.comboT -= 2.5; comboUp() end
		local ang = math.min(math.abs(P.slip) * 57.3, 90)
		local bonus = 1
		table.clear(drift.tags)
		if tandem > 0 then bonus *= 1 + tandem; drift.tags.TANDEM = string.format("TANDEM ×%.1f", 1 + tandem) end
		if nearWall then bonus *= 1.35; drift.tags["NEAR WALL"] = true end
		if ang > 45 then drift.tags.ANGLE = true; bonus *= 1.15 end
		if sp * 3.6 > 110 then drift.tags.SPEED = true; bonus *= 1.15 end
		drift.mult = drift.combo
		local gain = sp * 3.6 * ang * 0.5 * dt * bonus
		drift.score += gain
		if tandem > 0 then drift.tandemPts += gain end
	elseif drift.active then
		drift.idle += dt
		if drift.idle > 1.4 then endDrift(true) end
	end
end
local tagCache = ""
local function renderTags()
	local names = {}
	for _, n in { "TANDEM", "NEAR WALL", "ANGLE", "SPEED" } do
		local v = drift.tags[n]
		if v then table.insert(names, if type(v) == "string" then v else n) end
	end
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
local lapCP, prevIdx = 0, START
local WALL = HALF + 0.65 -- guardrail line on the pass (studs from the centre)
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.05)
	if not carModel then spawnCar() end
	local m = carModel :: Model
	local c = carDef
	if U.boost then
		-- admin speed boost: double power, a little more grip, for your car only
		if U.boostBase ~= carDef then
			U.boostBase = carDef
			U.boostDef = table.clone(carDef)
			U.boostDef.torque *= 2
			U.boostDef.mu *= 1.12
		end
		c = U.boostDef
	end
	physSet.assist, physSet.trans, physSet.sens = S.assist, S.trans, S.sens

	if mode == "play" then
		readInput(dt)
		if U.frozen then
			-- frozen by the game owner: no input, no movement
			input.throttle, input.brake, input.hand, input.steer = 0, 1, true, 0
			P.vx, P.vz, P.r = 0, 0, 0
		end
		local prev = Vector3.new(P.x * K, posY, P.z * K)
		local steps = math.max(1, math.ceil(dt * 240))
		for _ = 1, steps do CarPhysics.step(P, c, input, physSet, dt / steps) end
		CarPhysics.visual(P, c, dt)
		local X, Z = P.x * K, P.z * K

		-- where are we: on the pass (guardrails from the road line) or free in the city
		idx = Track.nearest(X, Z, idx)
		local _, roadY = Track.at(X, Z, idx)
		local dd = math.sqrt((Track.X[idx] - X) ^ 2 + (Track.Z[idx] - Z) ^ 2)
		onPass = dd < HALF + 10 and math.abs(posY - roadY) < 14
		nearWall, tandem, tandemWith = false, 0, nil
		if U.noclip then
			-- admin ghost mode: no guardrails, no walls
		elseif onPass and not nearJunction(idx) then
			local hl, hw = c.b.len / 2 - 0.05, c.b.wid / 2
			local fx2, fz2 = math.sin(P.h), math.cos(P.h)
			local lx2, lz2 = fz2, -fx2
			local worst, wc, maxLat = 0, nil, 0
			for k = 0, 3 do
				local cx = if bit32.band(k, 1) ~= 0 then hw else -hw
				local cz = if bit32.band(k, 2) ~= 0 then hl else -hl
				local px, pz = P.x + lx2 * cx + fx2 * cz, P.z + lz2 * cx + fz2 * cz
				local l = (px * K - Track.X[idx]) * Track.RX[idx] + (pz * K - Track.Z[idx]) * Track.RZ[idx]
				maxLat = math.max(maxLat, math.abs(l))
				local pen = math.abs(l) - WALL
				if pen > worst then worst, wc = pen, { px - P.x, pz - P.z, math.sign(l) } end
			end
			nearWall = P.drifting and maxLat > WALL - 1.3 * K
			if wc then
				local v = CarPhysics.wallHit(P, c, -Track.RX[idx] * wc[3], -Track.RZ[idx] * wc[3], worst / K, wc[1], wc[2])
				if v > 6.5 then crash(v) end
			end
		elseif not onPass then
			-- swept box against buildings, barriers and pillars
			local size = Vector3.new(c.b.wid * K, 2.6, c.b.len * K)
			local up = Vector3.new(0, 2.6, 0)
			local now = Vector3.new(P.x * K, posY, P.z * K)
			local hit = World.sweep(prev + up, now + up, P.h, size)
			if hit then
				-- stop at the wall (no tunnelling at speed), then bounce and slide along it
				local dir = (now - prev).Unit
				local back = prev + dir * math.max(0, hit.Distance - 0.05)
				P.x, P.z = back.X / K, back.Z / K
				local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
				if n.Magnitude > 0.1 then
					n = n.Unit
					local v = CarPhysics.wallHit(P, c, n.X, n.Z, 0, (hit.Position.X - back.X) / K, (hit.Position.Z - back.Z) / K)
					if v > 6.5 then crash(v) end
				end
			end
			-- touching a wall after turning into it: push the car out sideways, never freeze it in place
			for _ = 1, 3 do
				local here = Vector3.new(P.x * K, posY, P.z * K) + up
				local push, n = World.pushOut(here, P.h, size)
				if not push then break end
				P.x, P.z = P.x + push.X / K, P.z + push.Z / K
				local v = CarPhysics.wallHit(P, c, n.X, n.Z, 0, -n.X * c.b.wid / 2, -n.Z * c.b.wid / 2)
				if v > 6.5 then crash(v) end
			end
		end

		-- ground: follow roads, kerbs, ramps and the expressway; fly off crests, land
		X, Z = P.x * K, P.z * K
		local sp = math.sqrt(P.vx * P.vx + P.vz * P.vz)
		local gy, gn = World.ground(X, posY, Z)
		if gy then
			local snap = 0.6 + sp * K * dt * 0.7
			if onGround and posY - gy <= snap then
				vy = (gy - posY) / dt
				posY = gy
				groundN = groundN:Lerp(gn, math.min(1, dt * 12))
			else
				if onGround then onGround = false end
				vy -= 34.3 * dt
				posY += vy * dt
				if posY <= gy then
					if vy < -30 then shake = math.min(1, -vy / 80) end
					posY, vy, onGround = gy, 0, true
				end
			end
			if posY >= gy - 0.01 and math.abs(posY - gy) < 0.05 then onGround = true end
		else
			resetCar()
		end
		wallT = (wallT or 0)

		-- tandem with another driver
		-- closer = bigger bonus: ×1 at 11 m apart, up to ×2 door to door
		for _, g in ghosts do
			if P.drifting and g.drifting then
				local d = (g.cf.Position - Vector3.new(X, posY, Z)).Magnitude
				local q = math.clamp(1 - (d - 2 * K) / (9 * K), 0, 1)
				if q > tandem then tandem, tandemWith = q, g end
			end
		end
		Fx.tandem(tandemWith and m.PrimaryPart or nil, tandemWith and tandemWith.model.PrimaryPart or nil, tandem)
		updateScoring(dt, sp)

		-- laps on the pass: all four quarters, then the start line
		if onPass then
			lapCP = bit32.bor(lapCP, bit32.lshift(1, math.min(3, math.floor((idx - 1) / (Track.N / 4)))))
			if prevIdx > Track.N * 0.9 and idx < Track.N * 0.1 and lapCP == 15 then
				lapCP = 1
				R.Lap:FireServer()
				profile.credits += 2000
				showToast("Lap complete  ·  +2,000 CR", Ui.GOLD)
			end
			prevIdx = idx
		end

		-- HUD
		local kmh = sp * 3.6
		hSpeed.Text = tostring(math.floor(kmh))
		hGear.Text = (S.trans == "manual" and "M" or "") .. (if P.gear < 0 then "R" elseif sp < 0.5 and input.throttle == 0 then "N" else tostring(P.gear))
		rpmBar.Size = UDim2.new(math.clamp((P.rpm - 800) / (c.red - 800), 0, 1), 0, 1, 0)
		hAngle.Text = if P.drifting then (math.floor(math.abs(P.slip) * 57.3) .. "° ANGLE") else ""
		local credText = fmt(profile.credits)
		if credText ~= hCredits.Text then hCredits.Text = credText; Ui.pop(tl, 1.12) end
		local cmin, cmax = mapFolder:GetAttribute("CityMin"), mapFolder:GetAttribute("CityMax")
		local z = if onPass then Track.ZONE[idx] elseif cmin and X > cmin.X and X < cmax.X and Z > cmin.Y and Z < cmax.Y then 3 else 4
		if z ~= lastZone then
			lastZone = z
			local name = Track.ZONE_NAMES[z] or (z == 3 and "新箱根 · Shin-Hakone city" or "連絡道路 · Link road")
			hZone.Text = name
			showToast(name, Ui.TEXT)
		end
		dBox.Visible = drift.active
		if drift.active then
			local pts = drift.score * drift.mult
			dScore.Text = fmt(pts)
			dMult.Text = string.format("×%.1f", drift.mult)
			local tier = tierOf(pts)
			if tier ~= dTier.Text then dTier.Text = tier; Ui.pop(dBox, 1.15) end
			renderTags()
		end
		mmMe.Position = mmPos(X, Z)
		if toastT > 0 then toastT -= dt; if toastT < 0.5 then toast.TextTransparency = 1 - toastT * 2 end end
		if U.calloutT > 0 then U.calloutT -= dt; if U.calloutT < 0.5 then U.callout.TextTransparency = 1 - U.calloutT * 2 end end
		local vdot = if onPass and sp > 3 then (P.vx * Track.TX[idx] + P.vz * Track.TZ[idx]) / sp else 1
		local h = if vdot < -0.5 and P.gear > 0 then (touch and "Wrong way · tap ↺ to reset" or "Wrong way · press R to reset") else ""
		hint.Text, hint.Visible = h, h ~= ""

		sendT += dt
		if publicMap and sendT > 0.1 then
			sendT = 0
			local _, pidx = paintOf(c.id)
			R.State:FireServer(X, posY, Z, P.h, c.id, pidx, P.drifting)
		end
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

	-- suspension: spring-damped body roll and pitch from the accelerations (as in the browser)
	rollV += ((math.clamp(P.ay * 0.0065, -0.1, 0.1) - roll) * 90 - rollV * 11) * dt; roll += rollV * dt
	pitchV += ((math.clamp(-P.ax * 0.0045, -0.05, 0.06) - pitch) * 110 - pitchV * 13) * dt; pitch += pitchV * dt
	fspin += (P.u or 0) / CarPhysics.RW * dt
	P.rspin = (P.rspin or 0) + P.wr * dt
	local X, Z = P.x * K, P.z * K
	local pos = Vector3.new(X, posY, Z)
	local f = Vector3.new(math.sin(P.h), 0, math.cos(P.h))
	local up = groundN.Magnitude > 0.5 and groundN.Unit or Vector3.yAxis
	local fwd = (f - up * f:Dot(up))
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or f
	local cf = CFrame.lookAt(pos, pos + fwd, up) * CFrame.Angles(-pitch, 0, -roll)
	placeCar(m, usingMesh, cf, -P.delta, fspin, P.rspin)

	-- tyre smoke follows real rear-tyre slip and gets thicker with drift angle; skid marks; sound
	local skid = math.clamp((P.rearSlip - 2.5) / 9, 0, 1)
	local angF = math.clamp(math.abs(P.slip) * 57.3 / 45, 0, 1)
	local smoking = mode == "play" and skid > 0.12
	local rate = smoking and math.floor(50 * Config.Quality[qName()].smoke * skid * (0.5 + angF)) or 0
	local root = m.PrimaryPart
	for _, a in { "SmokeL", "SmokeR" } do
		local att = root:FindFirstChild(a)
		if att then
			local on = mode == "play" and onGround and skid > 0.15
			Fx.skid(a, root.CFrame:PointToWorldSpace(att.Position - Vector3.new(0, att.Position.Y, 0)), up, on and skid or 0, 0.9)
		end
	end
	-- backfire: a pop of flame on a fast upshift, and crackles when you lift off at high revs
	if mode == "play" then
		local lift = U.lastThr and U.lastThr > 0.8 and input.throttle < 0.1 and P.rpm > c.red * 0.7
		local upshift = U.lastGear and P.gear > U.lastGear and U.lastGear >= 1 and P.rpm > c.red * 0.45
		if upshift or (lift and math.random() < 0.6) then
			local tips = {}
			local back = -root.CFrame.LookVector
			for k = 1, c.b.exhaust or 1 do
				local x = if (c.b.exhaust or 1) == 1 then -c.b.wid * K * 0.3 else (k == 1 and -1 or 1) * c.b.wid * K * 0.3
				local tipPos = root.CFrame:PointToWorldSpace(Vector3.new(x, 0.32 * K, c.b.len * K / 2 + 0.2))
				table.insert(tips, CFrame.lookAt(tipPos, tipPos + back))
			end
			Fx.backfire(tips, upshift == true)
		end
		U.lastThr, U.lastGear = input.throttle, P.gear
	end
	if rate ~= smokeOn then
		smokeOn = rate
		for _, a in m.PrimaryPart:GetChildren() do
			local e = a:FindFirstChild("Smoke")
			if e then e.Rate = rate end
		end
	end
	if sound and mode == "play" then
		sound:update(dt, P.rpm, P.thrEff, skid, math.sqrt(P.vx * P.vx + P.vz * P.vz) * 3.6, P.limiter, S.sound and S.volume or 0)
	end

	-- other players glide to their latest positions
	for uid, g in ghosts do
		if os.clock() - g.seen > 3 then
			g.model:Destroy(); if g.sound then g.sound:destroy() end; ghosts[uid] = nil
		else
			local before = g.cf.Position
			g.cf = g.cf:Lerp(g.target, math.min(1, dt * 10))
			local spd = (g.cf.Position - before).Magnitude / math.max(dt, 1e-3)
			g.spin += spd / (CarPhysics.RW * K) * dt
			placeCar(g.model, g.mesh, g.cf, 0, g.spin, g.spin)
			if g.sound then
				g.rpm += ((1500 + spd * 30) - g.rpm) * math.min(1, dt * 3)
				g.sound:update(dt, math.min(g.rpm, 7000), 0.8, g.drifting and 0.7 or 0, spd / K * 3.6, false, S.sound and S.volume * 0.8 or 0)
			end
		end
	end

	-- camera (as in the browser game, in studs)
	local sp = math.sqrt(P.vx * P.vx + P.vz * P.vz)
	if mode == "photo" then
		local ph = U.photo
		local r = ph.dist * K
		local eye = pos + Vector3.new(math.sin(ph.yaw) * math.cos(ph.pitch) * r, math.sin(ph.pitch) * r + 0.6 * K, math.cos(ph.yaw) * math.cos(ph.pitch) * r)
		local gy = World.ground(eye.X, eye.Y, eye.Z)
		if gy and eye.Y < gy + 0.6 * K then eye = Vector3.new(eye.X, gy + 0.6 * K, eye.Z) end
		camera.CFrame = CFrame.lookAt(eye, pos + Vector3.new(0, 0.6 * K, 0))
		camera.FieldOfView += (45 - camera.FieldOfView) * math.min(1, dt * 4)
		CarModel.setCabinVisible(m, true)
	elseif mode ~= "play" then
		if os.clock() - (U.dragT or 0) > 3 then orbit += dt * 0.18 end
		orbit += U.orbitNudge or 0
		U.orbitNudge = 0
		local r = (mode == "garage" and 6.2 or 8.5) * K
		local eye = pos + Vector3.new(math.sin(P.h + orbit) * r, (mode == "garage" and 1.5 or 2.4) * K, math.cos(P.h + orbit) * r)
		local side = (mode == "title" or mode == "garage") and camera.ViewportSize.X > 800
		local right = Vector3.new(-math.cos(P.h + orbit), 0, math.sin(P.h + orbit))
		camera.CFrame = CFrame.lookAt(eye, pos + Vector3.new(0, 0.7 * K, 0) + (side and right * 2.2 * K or Vector3.zero))
		camera.FieldOfView = 50
		CarModel.setCabinVisible(m, true)
	elseif camMode == 2 or camMode == 3 then
		lookYaw += (math.clamp(-P.slip * (camMode == 2 and 0.6 or 0.3), -0.7, 0.7) - lookYaw) * math.min(1, dt * 4)
		local eye = if camMode == 2 then cf * CFrame.new(c.b.wid * 0.21 * K, c.b.h * 0.8 * K, c.b.wb * 0.08 * K) else cf * CFrame.new(0, c.b.h * 0.86 * K, -c.b.wb * 0.18 * K)
		local cam = eye * CFrame.Angles(math.rad(camMode == 2 and -4 or -2), lookYaw, 0)
		if shake > 0 then cam = cam * CFrame.Angles(0, 0, (math.random() - 0.5) * shake * 0.03); shake = math.max(0, shake - dt * 2.5) end
		camera.CFrame = cam
		local fov = math.clamp((camMode == 2 and 70 or 66) + sp * 0.18, 60, 84)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 3)
	else
		local dx, dz = f.X, f.Z
		if sp > 4 then
			local vx, vz = P.vx / sp, P.vz / sp
			dx, dz = dx + (vx - dx) * 0.55, dz + (vz - dz) * 0.55
			local l = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / l, dz / l
		end
		local dist, height, look = (6.4 + sp * 0.035) * K, 2.25 * K, 1.0 * K
		if camMode == 1 then dist, height, look = (10.5 + sp * 0.04) * K, 3.9 * K, 0.8 * K end
		local tx, tz = X - dx * dist, Z - dz * dist
		local ty = posY + height
		local gy = World.ground(tx, ty, tz)
		if gy then ty = math.max(ty, gy + 1.2 * K) end
		if (camPos - Vector3.new(tx, ty, tz)).Magnitude > 20 * K then camPos = Vector3.new(tx, ty, tz) end
		local kx = 1 - math.exp(-6 * dt)
		camPos = Vector3.new(camPos.X + (tx - camPos.X) * kx, camPos.Y + (ty - camPos.Y) * (1 - math.exp(-4 * dt)), camPos.Z + (tz - camPos.Z) * kx)
		local eye = camPos
		if shake > 0 then eye += Vector3.new((math.random() - 0.5) * shake * 0.5 * K, (math.random() - 0.5) * shake * 0.4 * K, 0); shake = math.max(0, shake - dt * 2.5) end
		-- a faint buzz above 150 km/h, so speed feels fast
		local hs = math.clamp((sp * 3.6 - 150) / 150, 0, 1)
		if hs > 0 then eye += Vector3.new((math.random() - 0.5), (math.random() - 0.5), (math.random() - 0.5)) * hs * 0.07 * K end
		camera.CFrame = CFrame.lookAt(eye, Vector3.new(X + f.X * 2.5 * K, posY + look, Z + f.Z * 2.5 * K))
		local fov = math.clamp(60 + sp * 0.32, 60, 82)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 3)
	end
	-- admin spectate: the camera follows another player's car
	local spec = U.spectate and ghosts[U.spectate]
	if mode == "play" and spec then
		local gp = spec.cf.Position
		local fwd = spec.cf.LookVector -- ghost CFrames are built with heading + pi, which points LookVector along the car's travel
		camera.CFrame = CFrame.lookAt(gp - fwd * 9 * K + Vector3.new(0, 3.2 * K, 0), gp + Vector3.new(0, 0.8 * K, 0))
	end
	CarModel.setCabinVisible(m, not (mode == "play" and camMode == 2))
end)

spawnCar()
refreshTitle()
loading:Destroy()
setMode("title")
