-- Kaido Drift (Roblox): builds a car out of parts. Front of the car is local -Z (CFrame.lookAt forward).
local CarModel = {}

local function part(model, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p:SetAttribute("Offset", offset)
	p.Parent = model
	return p
end

-- returns the model; parts carry an "Offset" CFrame relative to the car's ground point
function CarModel.build(car, name: string)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.Parent = m
	m.PrimaryPart = root

	local body, dark = car.color, Color3.fromRGB(18, 18, 22)
	local glass = Color3.fromRGB(40, 52, 66)
	local paint = Enum.Material.SmoothPlastic
	-- lower body, nose and tail
	part(m, "Body", Vector3.new(6.4, 1.7, 14.4), CFrame.new(0, 2.0, 0), body, paint)
	part(m, "Hood", Vector3.new(6.2, 0.5, 4.6), CFrame.new(0, 3.0, -4.6) * CFrame.Angles(math.rad(-4), 0, 0), body, paint)
	part(m, "Deck", Vector3.new(6.2, 0.5, 3.2), CFrame.new(0, 3.0, 5.3), body, paint)
	-- cabin with glass and roof
	local cabin = part(m, "Cabin", Vector3.new(5.6, 1.6, 6.0), CFrame.new(0, 3.6, 0.9), glass, Enum.Material.Glass)
	cabin.Transparency = 0.25
	cabin:SetAttribute("Cabin", true)
	local roof = part(m, "Roof", Vector3.new(5.4, 0.35, 4.6), CFrame.new(0, 4.55, 1.1), car.two or body, paint)
	roof:SetAttribute("Cabin", true)
	-- bumpers, side skirts
	part(m, "FrontBumper", Vector3.new(6.5, 1.1, 0.7), CFrame.new(0, 1.55, -7.3), car.two or body, paint)
	part(m, "RearBumper", Vector3.new(6.5, 1.1, 0.7), CFrame.new(0, 1.55, 7.3), car.two or body, paint)
	part(m, "Grille", Vector3.new(3.2, 0.5, 0.2), CFrame.new(0, 1.8, -7.7), dark)
	-- lights
	local hl = Color3.fromRGB(255, 244, 214)
	part(m, "HeadL", Vector3.new(1.4, 0.45, 0.2), CFrame.new(-2.3, 2.45, -7.25), hl, Enum.Material.Neon)
	part(m, "HeadR", Vector3.new(1.4, 0.45, 0.2), CFrame.new(2.3, 2.45, -7.25), hl, Enum.Material.Neon)
	local tl = Color3.fromRGB(255, 30, 40)
	part(m, "TailL", Vector3.new(1.6, 0.5, 0.2), CFrame.new(-2.2, 2.45, 7.25), tl, Enum.Material.Neon)
	part(m, "TailR", Vector3.new(1.6, 0.5, 0.2), CFrame.new(2.2, 2.45, 7.25), tl, Enum.Material.Neon)
	if car.wing then
		part(m, "Wing", Vector3.new(6.0, 0.25, 1.2), CFrame.new(0, 4.1, 6.4), car.two or body, paint)
		part(m, "WingL", Vector3.new(0.25, 0.9, 0.8), CFrame.new(-2.4, 3.6, 6.4), dark)
		part(m, "WingR", Vector3.new(0.25, 0.9, 0.8), CFrame.new(2.4, 3.6, 6.4), dark)
	end
	-- wheels (cylinders lie along X)
	for _, w in { { "WFL", -3.05, -4.6 }, { "WFR", 3.05, -4.6 }, { "WRL", -3.05, 4.6 }, { "WRR", 3.05, 4.6 } } do
		local t = part(m, w[1], Vector3.new(1.3, 2.7, 2.7), CFrame.new(w[2], 1.35, w[3]), dark, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		t:SetAttribute("Front", w[3] < 0)
		local rim = part(m, w[1] .. "Rim", Vector3.new(1.35, 1.7, 1.7), CFrame.new(w[2] + (w[2] > 0 and 0.05 or -0.05), 1.35, w[3]), Color3.fromRGB(170, 172, 180), Enum.Material.Metal, Enum.PartType.Cylinder)
		rim:SetAttribute("Front", w[3] < 0)
	end
	-- headlight beams and rear smoke points on the root
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range, beam.Angle, beam.Brightness = 70, 70, 4
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Parent = root
	for _, s in { { "SmokeL", -3.0 }, { "SmokeR", 3.0 } } do
		local a = Instance.new("Attachment")
		a.Name = s[1]
		a.Position = Vector3.new(s[2], 0.6, 4.8)
		a.Parent = root
	end
	return m
end

-- place the car: ground point cf; front wheels turned by steer (radians, positive = right)
function CarModel.place(m: Model, cf: CFrame, steer: number)
	local root = m.PrimaryPart :: BasePart
	root.CFrame = cf
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local off = p:GetAttribute("Offset") :: CFrame
			if p:GetAttribute("Front") then
				local pos = off.Position
				p.CFrame = cf * CFrame.new(pos) * CFrame.Angles(0, -steer, 0)
			else
				p.CFrame = cf * off
			end
		end
	end
end

-- hide the cabin for the first-person view
function CarModel.setCabinVisible(m: Model, visible: boolean)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Cabin") then
			p.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

return CarModel
