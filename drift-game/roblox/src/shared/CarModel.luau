-- Kaido Drift (Roblox): car bodies in the browser game's styles (notchback, hatch, fastback, sedan,
-- roadster) with pop-up lamps, ducktails, wings and twin exhausts. The front of the car is local -Z.
-- Only the invisible root is anchored and moved; every other part is welded to it, so placing a car
-- is one CFrame write. Wheels spin and the fronts steer through their weld offsets.
local CarModel = {}

local DARK, GLASS, CHROME = Color3.fromRGB(16, 16, 20), Color3.fromRGB(70, 88, 108), Color3.fromRGB(200, 202, 208)

-- per-style shape: roof length, rear glass length, trunk deck height, deck length (share of the car)
local STYLE = {
	notch = { roof = 0.27, rearGlass = 0.13, deck = 0.93, cowl = 0.30, ws = 0.16 },
	hatch = { roof = 0.29, rearGlass = 0.27, deck = 0.0, cowl = 0.30, ws = 0.15 },
	fast = { roof = 0.22, rearGlass = 0.30, deck = 0.0, cowl = 0.32, ws = 0.18 },
	sedan = { roof = 0.33, rearGlass = 0.11, deck = 0.95, cowl = 0.29, ws = 0.14 },
	roadster = { roof = 0, rearGlass = 0, deck = 0.9, cowl = 0.36, ws = 0.08 },
}

local function weldPart(m, root, class, name, size, offset, color, material, opts)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if opts and opts.shape then p.Shape = opts.shape end
	if opts and opts.transparency then p.Transparency = opts.transparency end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = root.CFrame * offset
	p.Parent = m
	local w = Instance.new("Weld")
	w.Name = "W"
	w.Part0, w.Part1, w.C0 = root, p, offset
	w.Parent = p
	if opts and opts.paint then p:SetAttribute("Paint", true) end
	if opts and opts.cabin then p:SetAttribute("Cabin", true) end
	return p
end

function CarModel.build(car, name: string, paint: Color3?)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.CFrame = CFrame.new(0, 1e4, 0)
	root.Parent = m
	m.PrimaryPart = root

	local st = STYLE[car.style] or STYLE.notch
	local L, W, H, WB = car.len, car.wid, car.h, car.wb
	local body = paint or car.color
	local mat = Enum.Material.SmoothPlastic
	local function P(nm, size, off, col, mt, o) return weldPart(m, root, "Part", nm, size, off, col, mt or mat, o) end
	local function Wd(nm, size, off, col, mt, o) return weldPart(m, root, "WedgePart", nm, size, off, col, mt or mat, o) end
	local paintO = { paint = true }

	local sill, shoulder = 0.62, H * 0.55
	local roofY = H
	local front, rear = -L / 2, L / 2
	local zf, zr = -WB / 2, WB / 2
	local tire = 2.25

	-- lower body with wheel arches cut around each axle, and fender flares over them
	local archHalf, archTop = tire / 2 + 0.35, tire + 0.25
	local function slab(nm, z0, z1, y0, y1)
		if z1 - z0 > 0.05 and y1 - y0 > 0.05 then
			P(nm, Vector3.new(W, y1 - y0, z1 - z0), CFrame.new(0, (y0 + y1) / 2, (z0 + z1) / 2), body, mat, paintO)
		end
	end
	slab("BodyF", front + 0.6, zf - archHalf, sill, shoulder)
	slab("BodyM", zf + archHalf, zr - archHalf, sill, shoulder)
	slab("BodyR", zr + archHalf, rear - 0.6, sill, shoulder)
	for _, z in { zf, zr } do
		slab("Arch", z - archHalf, z + archHalf, archTop, shoulder)
		P("Flare", Vector3.new(W + 0.2, 0.32, archHalf * 2 + 0.2), CFrame.new(0, archTop + 0.12, z), body, mat, paintO)
		P("Well", Vector3.new(W - 0.25, 0.1, archHalf * 2 - 0.1), CFrame.new(0, archTop - 0.05, z), DARK)
	end
	P("Skirt", Vector3.new(W + 0.06, 0.3, (zr - archHalf) - (zf + archHalf)), CFrame.new(0, sill + 0.02, (zf + zr) / 2), DARK)
	-- nose: hood slopes down to a low nose; bumper and lip
	local hoodTop = shoulder * 0.98
	local noseLen = math.max(L / 2 + zf - 0.4, 1.5)
	Wd("Nose", Vector3.new(W - 0.1, 0.55, noseLen), CFrame.new(0, hoodTop - 0.27, front + 0.6 + noseLen / 2), body, mat, paintO)
	local noseEnd = front + 0.6 + noseLen
	local cowlZ0 = front + L * st.cowl
	local hoodLen = math.max(0.4, cowlZ0 - noseEnd + 0.15)
	P("Hood", Vector3.new(W - 0.15, 0.22, hoodLen), CFrame.new(0, hoodTop + 0.1, noseEnd + hoodLen / 2 - 0.1), body, mat, paintO)
	P("FrontBumper", Vector3.new(W, 1.05, 0.9), CFrame.new(0, sill + 0.55, front + 0.45), body, mat, paintO)
	P("Lip", Vector3.new(W - 0.3, 0.18, 0.7), CFrame.new(0, sill - 0.05, front + 0.45), DARK)
	P("Intake", Vector3.new(W * 0.5, 0.35, 0.1), CFrame.new(0, sill + 0.45, front - 0.02), DARK)
	P("PlateF", Vector3.new(1.5, 0.4, 0.06), CFrame.new(0, sill + 0.75, front - 0.03), Color3.fromRGB(235, 235, 225))
	-- lamps: pop-ups sit on the hood, the rest are in the nose
	local lampCol = Color3.fromRGB(255, 244, 214)
	if car.popups then
		for _, x in { -1, 1 } do
			P("Popup", Vector3.new(1.35, 0.32, 1.0), CFrame.new(x * (W / 2 - 1.0), hoodTop + 0.3, front + 1.3), body, mat, paintO)
			P("Lamp", Vector3.new(1.2, 0.08, 0.05), CFrame.new(x * (W / 2 - 1.0), hoodTop + 0.3, front + 0.78), lampCol, Enum.Material.Neon)
		end
		for _, x in { -1, 1 } do P("Indicator", Vector3.new(1.0, 0.22, 0.06), CFrame.new(x * (W / 2 - 0.8), sill + 0.95, front - 0.02), Color3.fromRGB(255, 170, 60), Enum.Material.Neon) end
	else
		for _, x in { -1, 1 } do
			P("Lamp", Vector3.new(1.3, 0.38, 0.12), CFrame.new(x * (W / 2 - 0.95), shoulder - 0.25, front + 0.62), lampCol, Enum.Material.Neon)
		end
	end
	-- greenhouse
	local cabW = W * 0.84
	local cowlZ = front + L * st.cowl
	local wsLen = L * st.ws
	local glassO = { transparency = 0.35, cabin = true }
	if car.style == "roadster" then
		Wd("Windscreen", Vector3.new(cabW, 1.1, wsLen), CFrame.new(0, shoulder + 0.55, cowlZ + wsLen / 2), GLASS, Enum.Material.Glass, glassO)
		P("Seats", Vector3.new(cabW - 0.4, 0.9, 2.6), CFrame.new(0, shoulder + 0.2, cowlZ + wsLen + 1.6), DARK, Enum.Material.Fabric)
		P("Hoop", Vector3.new(cabW - 0.6, 0.25, 0.25), CFrame.new(0, shoulder + 1.1, cowlZ + wsLen + 3.0), CHROME, Enum.Material.Metal)
		P("Deck", Vector3.new(W - 0.15, 0.3, rear - (cowlZ + wsLen + 3.2)), CFrame.new(0, shoulder * st.deck + 0.05, (rear + cowlZ + wsLen + 3.2) / 2), body, mat, paintO)
	else
		local roofLen = L * st.roof
		local rgLen = L * st.rearGlass
		local roofZ0 = cowlZ + wsLen
		local roofZ1 = roofZ0 + roofLen
		Wd("Windscreen", Vector3.new(cabW, roofY - hoodTop, wsLen), CFrame.new(0, (roofY + hoodTop) / 2, cowlZ + wsLen / 2), GLASS, Enum.Material.Glass, glassO)
		P("Cabin", Vector3.new(cabW + 0.02, roofY - hoodTop - 0.2, roofLen), CFrame.new(0, (roofY + hoodTop) / 2 - 0.1, (roofZ0 + roofZ1) / 2), GLASS, Enum.Material.Glass, glassO)
		P("Pillar", Vector3.new(cabW + 0.06, roofY - hoodTop - 0.2, 0.35), CFrame.new(0, (roofY + hoodTop) / 2 - 0.1, roofZ0 + roofLen * (car.style == "sedan" and 0.48 or 0.62)), body, mat, { paint = true, cabin = true })
		P("Roof", Vector3.new(cabW - 0.1, 0.24, roofLen + 0.3), CFrame.new(0, roofY, (roofZ0 + roofZ1) / 2), body, mat, { paint = true, cabin = true })
		local deckY = if st.deck > 0 then shoulder * st.deck else shoulder * 0.9
		local rg = Wd("RearGlass", Vector3.new(cabW, roofY - deckY, rgLen), CFrame.new(0, (roofY + deckY) / 2, roofZ1 + rgLen / 2) * CFrame.Angles(0, math.pi, 0), GLASS, Enum.Material.Glass, glassO)
		if st.deck > 0 then
			P("Deck", Vector3.new(W - 0.15, 0.26, rear - (roofZ1 + rgLen) - 0.2), CFrame.new(0, deckY, (rear - 0.2 + roofZ1 + rgLen) / 2), body, mat, paintO)
		end
		for _, x in { -1, 1 } do
			P("Mirror", Vector3.new(0.5, 0.35, 0.3), CFrame.new(x * (cabW / 2 + 0.3), hoodTop + 0.35, cowlZ + wsLen * 0.6), body, mat, paintO)
		end
		local _ = rg
	end
	-- tail
	P("RearBumper", Vector3.new(W, 1.05, 0.9), CFrame.new(0, sill + 0.55, rear - 0.45), body, mat, paintO)
	P("Diffuser", Vector3.new(W - 0.6, 0.2, 0.6), CFrame.new(0, sill - 0.05, rear - 0.45), DARK)
	P("Tail", Vector3.new(W - 0.3, 0.42, 0.08), CFrame.new(0, shoulder - 0.35, rear - 0.17), Color3.fromRGB(60, 10, 14))
	for _, x in { -1, 1 } do
		P("TailLamp", Vector3.new(1.5, 0.36, 0.06), CFrame.new(x * (W / 2 - 1.0), shoulder - 0.35, rear - 0.12), Color3.fromRGB(255, 30, 40), Enum.Material.Neon)
	end
	P("PlateR", Vector3.new(1.5, 0.4, 0.06), CFrame.new(0, sill + 0.8, rear + 0.03), Color3.fromRGB(235, 235, 225))
	if car.duck then
		Wd("Duck", Vector3.new(W - 0.4, 0.4, 0.7), CFrame.new(0, shoulder * (st.deck > 0 and st.deck or 0.9) + 0.32, rear - 0.55), body, mat, paintO)
	end
	if car.wing then
		local wy = shoulder * 0.95 + 1.1
		P("Wing", Vector3.new(W - 0.4, 0.14, 1.0), CFrame.new(0, wy, rear - 0.75) * CFrame.Angles(math.rad(-6), 0, 0), body, mat, paintO)
		for _, x in { -1, 1 } do
			P("WingStand", Vector3.new(0.14, 1.0, 0.5), CFrame.new(x * (W / 2 - 1.3), wy - 0.55, rear - 0.75), DARK)
			P("WingPlate", Vector3.new(0.08, 0.6, 1.1), CFrame.new(x * (W / 2 - 0.2), wy, rear - 0.75), DARK)
		end
	end
	for k = 1, car.exhaust do
		local x = car.exhaust == 1 and (W / 2 - 1.2) or (k == 1 and -(W / 2 - 1.2) or (W / 2 - 1.2))
		P("Exhaust", Vector3.new(0.7, 0.42, 0.42), CFrame.new(x, sill + 0.15, rear + 0.05) * CFrame.Angles(0, math.pi / 2, 0), CHROME, Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
	end
	-- wheels: tyre, rim, hub, caliper; they spin and the fronts steer (see CarModel.place)
	local wheels = {}
	for _, w in { { "FL", -1, zf }, { "FR", 1, zf }, { "RL", -1, zr }, { "RR", 1, zr } } do
		local x = w[2] * (W / 2 - 0.42)
		local base = CFrame.new(x, tire / 2, w[3])
		local t = P("Tyre" .. w[1], Vector3.new(0.95, tire, tire), base, Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		local r = P("Rim" .. w[1], Vector3.new(0.97, tire * 0.66, tire * 0.66), base, car.rim, Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		local spoke = P("Spoke" .. w[1], Vector3.new(0.99, tire * 0.6, 0.18), base, car.rim, Enum.Material.Metal)
		local spoke2 = P("Spoke2" .. w[1], Vector3.new(0.99, 0.18, tire * 0.6), base, car.rim, Enum.Material.Metal)
		local hub = P("Hub" .. w[1], Vector3.new(1.0, 0.45, 0.45), base, DARK, Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		P("Caliper" .. w[1], Vector3.new(0.3, 0.55, 0.7), CFrame.new(x - w[2] * 0.15, tire / 2 + 0.45, w[3] - 0.25), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic)
		table.insert(wheels, { parts = { t, r, spoke, spoke2, hub }, base = base, front = w[3] < 0 })
	end
	-- headlight beams and rear smoke points on the root
	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Range, beam.Angle, beam.Brightness = 80, 70, 4
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Parent = root
	for _, s in { { "SmokeL", -1 }, { "SmokeR", 1 } } do
		local a = Instance.new("Attachment")
		a.Name = s[1]
		a.Position = Vector3.new(s[2] * (W / 2 - 0.4), 0.5, zr + 0.4)
		a.Parent = root
	end
	m:SetAttribute("Spin", 0)
	CarModel._wheels = CarModel._wheels or setmetatable({}, { __mode = "k" })
	CarModel._wheels[m] = wheels
	return m
end

-- place the car at ground point cf; steer = front wheel angle (rad, + = right); roll = wheel turn (rad)
function CarModel.place(m: Model, cf: CFrame, steer: number, roll: number?)
	local root = m.PrimaryPart :: BasePart
	root.CFrame = cf
	local wheels = CarModel._wheels and CarModel._wheels[m]
	if wheels then
		local spin = CFrame.Angles(-(roll or 0), 0, 0)
		local turn = CFrame.Angles(0, -steer, 0)
		for _, w in wheels do
			local c0 = if w.front then w.base * turn * spin else w.base * spin
			for _, p in w.parts do (p:FindFirstChild("W") :: Weld).C0 = c0 end
		end
	end
end

-- repaint the body panels
function CarModel.paint(m: Model, color: Color3)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Paint") then p.Color = color end
	end
end

-- hide the cabin for the first-person view
function CarModel.setCabinVisible(m: Model, visible: boolean)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Cabin") then p.LocalTransparencyModifier = visible and 0 or 1 end
	end
end

-- pop-up lamps and beams on at night
function CarModel.setLights(m: Model, on: boolean)
	local root = m.PrimaryPart
	if root and root:FindFirstChild("Beam") then (root.Beam :: SpotLight).Enabled = on end
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Lamp" then p.Material = on and Enum.Material.Neon or Enum.Material.Glass end
	end
end

return CarModel
