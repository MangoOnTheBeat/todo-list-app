--!strict
-- Builds a 1990s-JDM-style coupe out of parts from a Cars entry. Used by the server (real cars)
-- and the client (garage preview). Model space: origin on the ground under the car centre, nose = -Z.
local Config = require(script.Parent.Config)
local Cars = require(script.Parent.Cars)

local CarBuilder = {}

local S = Config.STUDS_PER_M

export type Geometry = {
	radius: number,
	ride: number,
	chassisY: number, -- chassis centre height above ground
	originY: number, -- suspension ray origin, relative to chassis centre
	restLen: number, -- origin -> wheel centre at full droop
	wheels: { { name: string, x: number, z: number, front: boolean } },
	seat: Vector3, -- driver head position relative to chassis centre (cockpit cam)
	length: number,
	width: number,
}

function CarBuilder.geometry(car: Cars.Car): Geometry
	local L, W, WB = car.b.len * S, car.b.wid * S, car.b.wb * S
	local R = Config.WHEEL_RADIUS_M * S
	local ride = 0.13 * S
	local belt = car.b.h * S * 0.6
	local chassisY = (ride + belt) / 2
	local ww = 0.22 * S
	local wx = W / 2 - ww / 2 - 0.05
	local originAbs = ride + 1.0
	return {
		radius = R,
		ride = ride,
		chassisY = chassisY,
		originY = originAbs - chassisY,
		restLen = originAbs - R + 0.45,
		wheels = {
			{ name = "FL", x = -wx, z = -WB / 2, front = true },
			{ name = "FR", x = wx, z = -WB / 2, front = true },
			{ name = "RL", x = -wx, z = WB / 2, front = false },
			{ name = "RR", x = wx, z = WB / 2, front = false },
		},
		-- right-hand drive
		seat = Vector3.new(W * 0.2, car.b.h * S * 0.84 - chassisY, 0.15 * S + 0.2),
		length = L,
		width = W,
	}
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, class: string?): any
	local p = Instance.new((class or "Part") :: any) :: Part
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Returns an unparented model whose PrimaryPart is "Chassis", pivoted at `at` (ground point under the car).
function CarBuilder.build(car: Cars.Car, at: CFrame?, paint: Color3?): Model
	local g = CarBuilder.geometry(car)
	local model = Instance.new("Model")
	model.Name = car.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local body = paint or car.color
	local L, W, H = car.b.len * S, car.b.wid * S, car.b.h * S
	local ride = g.ride
	local belt = car.b.h * S * 0.6
	local dark = Color3.fromRGB(28, 29, 34)
	local glass = Color3.fromRGB(18, 22, 30)
	local style = car.b.style

	-- Chassis: the only physical part. Mass ≈ the car's real kerb weight.
	local chassis = part(model, "Chassis", Vector3.new(W, belt - ride, L), CFrame.new(0, g.chassisY, 0), body)
	chassis.CanCollide = true
	chassis.CanQuery = true
	chassis.CanTouch = true
	chassis.Massless = false
	chassis.CastShadow = true
	chassis.RootPriority = 127
	local vol = W * (belt - ride) * L
	chassis.CustomPhysicalProperties = PhysicalProperties.new(math.clamp(car.mass / vol, 0.1, 100), 0.15, 0.05, 100, 1)
	chassis.Reflectance = 0.08
	model.PrimaryPart = chassis

	local function weldAll()
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d ~= chassis and not d:GetAttribute("Wheel") and not d:GetAttribute("Jointed") then
				local w = Instance.new("WeldConstraint")
				w.Part0 = chassis
				w.Part1 = d
				w.Parent = d
			end
		end
	end

	-- greenhouse span along Z (front -> rear)
	local zf, zr
	if style == "notch" or style == "sedan" then
		zf, zr = -L * 0.16, L * 0.26
	elseif style == "roadster" then
		zf, zr = -L * 0.08, L * 0.12
	else -- hatch / fast
		zf, zr = -L * 0.14, L * (style == "hatch" and 0.44 or 0.40)
	end
	local cabH = H - belt
	local cw = W * 0.84
	if style ~= "roadster" then
		local ws = 0.55 * S * 1.4
		local rw = (style == "notch" or style == "sedan") and 0.45 * S * 1.3 or (zr - zf) * 0.45
		local boxLen = (zr - zf) - ws - rw
		local midZ = zf + ws + boxLen / 2
		part(model, "Glass", Vector3.new(cw, cabH - 0.15, boxLen), CFrame.new(0, belt + (cabH - 0.15) / 2, midZ), glass, Enum.Material.Glass).Transparency = 0.15
		part(model, "Roof", Vector3.new(cw * 0.98, 0.18, boxLen + 0.3), CFrame.new(0, H - 0.09, midZ), body).Reflectance = 0.08
		-- Pillars
		for _, sx in { -1, 1 } do
			part(model, "BPillar", Vector3.new(0.12, cabH - 0.15, 0.35), CFrame.new(sx * (cw / 2 - 0.03), belt + (cabH - 0.15) / 2, midZ + boxLen * 0.1), body)
		end
		-- Wedges slope down toward -Z by default: windscreen as-is, rear glass turned around.
		local wsPart = part(model, "Windscreen", Vector3.new(cw, cabH - 0.15, ws), CFrame.new(0, belt + (cabH - 0.15) / 2, zf + ws / 2), glass, Enum.Material.Glass, "WedgePart")
		wsPart.Transparency = 0.35
		local rwPart = part(model, "RearGlass", Vector3.new(cw, cabH - 0.15, rw), CFrame.new(0, belt + (cabH - 0.15) / 2, zr - rw / 2) * CFrame.Angles(0, math.pi, 0), glass, Enum.Material.Glass, "WedgePart")
		rwPart.Transparency = 0.2
	else
		-- roadster: low windscreen frame and a roll hoop
		local wsPart = part(model, "Windscreen", Vector3.new(cw, cabH * 0.55, 0.9), CFrame.new(0, belt + cabH * 0.275, zf + 0.45), glass, Enum.Material.Glass, "WedgePart")
		wsPart.Transparency = 0.35
		part(model, "Interior", Vector3.new(cw, 0.3, zr - zf), CFrame.new(0, belt - 0.1, (zf + zr) / 2), Color3.fromRGB(40, 30, 28), Enum.Material.Fabric)
		for _, sx in { -1, 1 } do
			part(model, "Hoop", Vector3.new(0.18, cabH * 0.6, 0.18), CFrame.new(sx * cw * 0.3, belt + cabH * 0.3, zr - 0.2), dark, Enum.Material.Metal)
		end
	end

	-- hood / bonnet line and lower trim
	part(model, "Hood", Vector3.new(W * 0.96, 0.12, L / 2 + zf - 0.2), CFrame.new(0, belt + 0.02, (-L / 2 + zf) / 2 + 0.1), body).Reflectance = 0.1
	part(model, "BumperF", Vector3.new(W * 1.01, 0.55, 0.4), CFrame.new(0, ride + 0.3, -L / 2 - 0.05), dark)
	part(model, "BumperR", Vector3.new(W * 1.01, 0.55, 0.4), CFrame.new(0, ride + 0.3, L / 2 + 0.05), dark)
	part(model, "SideSkirtL", Vector3.new(0.1, 0.35, car.b.wb * S * 0.7), CFrame.new(-W / 2 - 0.03, ride + 0.2, 0), dark)
	part(model, "SideSkirtR", Vector3.new(0.1, 0.35, car.b.wb * S * 0.7), CFrame.new(W / 2 + 0.03, ride + 0.2, 0), dark)
	if car.b.duck then
		part(model, "Ducktail", Vector3.new(W * 0.9, 0.2, 0.5), CFrame.new(0, belt + 0.1, L / 2 - 0.3) * CFrame.Angles(math.rad(-12), 0, 0), body)
	end
	if car.b.wing then
		for _, sx in { -1, 1 } do
			part(model, "WingPost", Vector3.new(0.15, 0.7, 0.3), CFrame.new(sx * W * 0.32, belt + 0.35, L / 2 - 0.5), dark)
		end
		part(model, "Wing", Vector3.new(W * 0.95, 0.12, 0.9), CFrame.new(0, belt + 0.75, L / 2 - 0.45) * CFrame.Angles(math.rad(-6), 0, 0), body)
	end

	-- lights
	local warmWhite = Color3.fromRGB(255, 244, 214)
	local headY = ride + (belt - ride) * 0.62
	if car.b.popups then
		for _, sx in { -1, 1 } do
			local pod = part(model, "PopUp", Vector3.new(W * 0.24, 0.55, 0.8), CFrame.new(sx * W * 0.3, belt + 0.3, -L / 2 + 0.75), body)
			pod.Reflectance = 0.08
			part(model, "HeadLamp", Vector3.new(W * 0.2, 0.4, 0.05), CFrame.new(sx * W * 0.3, belt + 0.3, -L / 2 + 0.34), warmWhite, Enum.Material.Neon)
		end
	else
		for _, sx in { -1, 1 } do
			part(model, "HeadLamp", Vector3.new(W * 0.24, 0.32, 0.06), CFrame.new(sx * W * 0.32, headY, -L / 2 - 0.02), warmWhite, Enum.Material.Neon)
		end
	end
	part(model, "TailLamps", Vector3.new(W * 0.92, 0.3, 0.06), CFrame.new(0, headY, L / 2 + 0.02), Color3.fromRGB(200, 20, 30), Enum.Material.Neon)
	part(model, "Exhaust", Vector3.new(0.6, 0.35, 0.35), CFrame.new(W * 0.3, ride + 0.25, L / 2 + 0.2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(150, 150, 150), Enum.Material.Metal, "Part").Shape = Enum.PartType.Cylinder

	local beam = Instance.new("SpotLight")
	beam.Name = "Headlights"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 80
	beam.Range = 60
	beam.Brightness = 4
	beam.Color = warmWhite
	beam.Shadows = false
	beam.Parent = chassis
	local tail = Instance.new("PointLight")
	tail.Name = "TailGlow"
	tail.Color = Color3.fromRGB(255, 40, 40)
	tail.Range = 8
	tail.Brightness = 0.6
	tail.Parent = model:FindFirstChild("TailLamps")

	-- driver seat (touch disabled so passers-by are never auto-seated; the server calls Seat:Sit)
	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.6, 0.3, 1.6)
	seat.CFrame = CFrame.new(W * 0.2, ride + 0.75, 0.15 * S)
	seat.Transparency = 1
	seat.Anchored = false
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Massless = true
	seat.Parent = model

	-- steering wheel (rotated by the client via its Weld)
	local swCF = CFrame.new(W * 0.2, belt + 0.1, 0.15 * S - 1.6) * CFrame.Angles(math.rad(-25), math.rad(90), 0)
	local sw = part(model, "SteeringWheel", Vector3.new(0.12, 1.1, 1.1), swCF, dark, Enum.Material.SmoothPlastic)
	sw.Shape = Enum.PartType.Cylinder
	sw:SetAttribute("Jointed", true)
	local swWeld = Instance.new("Weld")
	swWeld.Name = "SteerWeld"
	swWeld.Part0 = chassis
	swWeld.Part1 = sw
	swWeld.C0 = chassis.CFrame:ToObjectSpace(swCF)
	swWeld.Parent = sw
	sw:SetAttribute("BaseC0", swWeld.C0)

	-- wheels: tyre + rim, joined to the chassis by a Weld the client moves for suspension/steer/spin
	local R = g.radius
	local ww = 0.22 * S
	for _, w in g.wheels do
		local cf = CFrame.new(w.x, R, w.z)
		local tyre = part(model, w.name, Vector3.new(ww, R * 2, R * 2), cf, Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic)
		tyre.Shape = Enum.PartType.Cylinder
		tyre:SetAttribute("Wheel", true)
		tyre:SetAttribute("Front", w.front)
		local side = w.x < 0 and -1 or 1
		local rim = part(model, w.name .. "Rim", Vector3.new(ww + 0.08, R * 1.35, R * 1.35), cf * CFrame.new(side * 0.02, 0, 0), car.rim, Enum.Material.Metal)
		rim.Shape = Enum.PartType.Cylinder
		rim:SetAttribute("Jointed", true)
		local spoke = part(model, w.name .. "Spoke", Vector3.new(ww + 0.1, R * 1.2, 0.25), cf * CFrame.new(side * 0.02, 0, 0), car.rim:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.Metal)
		spoke:SetAttribute("Jointed", true)
		for _, p in { rim, spoke } do
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = tyre
			wc.Part1 = p
			wc.Parent = p
		end
		local joint = Instance.new("Weld")
		joint.Name = "Joint"
		joint.Part0 = chassis
		joint.Part1 = tyre
		joint.C0 = chassis.CFrame:ToObjectSpace(cf)
		joint.Parent = tyre
	end

	-- tyre smoke emitters at the rear contact patches
	for _, w in g.wheels do
		if not w.front then
			local a = Instance.new("Attachment")
			a.Name = "Smoke" .. w.name
			a.Position = Vector3.new(w.x, R * 0.5 - g.chassisY, w.z + 0.4)
			a.Parent = chassis
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "TyreSmoke"
			pe.Texture = Config.SMOKE_TEXTURE
			pe.Color = ColorSequence.new(Color3.fromRGB(225, 225, 230))
			pe.LightInfluence = 0.6
			pe.LightEmission = 0.05
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 9) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
			pe.Lifetime = NumberRange.new(1.4, 2.4)
			pe.Speed = NumberRange.new(2, 5)
			pe.SpreadAngle = Vector2.new(35, 35)
			pe.Acceleration = Vector3.new(0, 3, 0)
			pe.Drag = 1.5
			pe.Rotation = NumberRange.new(0, 360)
			pe.RotSpeed = NumberRange.new(-40, 40)
			pe.Rate = 0
			pe.Enabled = true
			pe.Parent = a
		end
	end

	local engine = Instance.new("Sound")
	engine.Name = "Engine"
	engine.SoundId = Config.ENGINE_SOUND_ID
	engine.Looped = true
	engine.Volume = 0.5
	engine.RollOffMaxDistance = 250
	engine.RollOffMinDistance = 12
	engine.Parent = chassis
	local skid = Instance.new("Sound")
	skid.Name = "Skid"
	skid.SoundId = Config.SKID_SOUND_ID
	skid.Looped = true
	skid.Volume = 0
	skid.RollOffMaxDistance = 200
	skid.Parent = chassis

	weldAll()
	model:SetAttribute("CarId", car.id)
	model:SetAttribute("OriginY", g.originY)
	model:SetAttribute("RestLen", g.restLen)
	model:SetAttribute("Radius", R)

	if at then
		model:PivotTo(at * CFrame.new(0, g.chassisY, 0))
	end
	return model
end

return CarBuilder
