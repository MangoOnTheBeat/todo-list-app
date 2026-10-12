--!strict
-- Per-frame cosmetics for every car on the server (not just ours): wheel suspension/steer/spin,
-- steering wheel, tyre smoke, skid marks, engine pitch and tyre squeal. Runs on each client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local Drive = require(script.Parent:WaitForChild("Drive"))

local Visuals = {}

type WheelVis = { part: BasePart, joint: Weld, x: number, z: number, front: boolean, spin: number, last: Vector3? }
type CarVis = {
	model: Model,
	chassis: BasePart,
	spec: Cars.Car,
	geo: CarBuilder.Geometry,
	wheels: { WheelVis },
	emitters: { ParticleEmitter },
	engine: Sound?,
	skid: Sound?,
	steerWeld: Weld?,
	steerBase: CFrame?,
	steer: number,
}

local tracked: { [Model]: CarVis } = {}
local localPlayer = Players.LocalPlayer

local skidFolder = Instance.new("Folder")
skidFolder.Name = "KaidoSkids"
skidFolder.Parent = Workspace
local skidPool: { BasePart } = {}
local skidIndex = 0
local MAX_SKIDS = 700

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function skidMark(a: Vector3, b: Vector3, normal: Vector3, alpha: number)
	local len = (b - a).Magnitude
	if len < 0.2 or len > 8 then
		return
	end
	skidIndex = skidIndex % MAX_SKIDS + 1
	local p = skidPool[skidIndex]
	if not p then
		local np = Instance.new("Part")
		np.Anchored = true
		np.CanCollide = false
		np.CanQuery = false
		np.CanTouch = false
		np.CastShadow = false
		np.Material = Enum.Material.SmoothPlastic
		np.Color = Color3.fromRGB(12, 12, 12)
		np.Parent = skidFolder
		skidPool[skidIndex] = np
		p = np
	end
	local mid = (a + b) / 2 + normal * 0.04
	p.Size = Vector3.new(0.75, 0.04, len + 0.1)
	p.CFrame = CFrame.lookAt(mid, mid + (b - a), normal)
	p.Transparency = 1 - alpha
end

local function track(model: Model)
	if tracked[model] then
		return
	end
	local chassis = model:WaitForChild("Chassis", 5) :: BasePart?
	if not chassis then
		return
	end
	local id = model:GetAttribute("CarId") :: string?
	local spec = Cars.get(id)
	local geo = CarBuilder.geometry(spec)
	local vis: CarVis = {
		model = model,
		chassis = chassis,
		spec = spec,
		geo = geo,
		wheels = {},
		emitters = {},
		engine = chassis:FindFirstChild("Engine") :: Sound?,
		skid = chassis:FindFirstChild("Skid") :: Sound?,
		steer = 0,
	}
	for _, wd in geo.wheels do
		local part = model:WaitForChild(wd.name, 5) :: BasePart?
		local joint = part and part:WaitForChild("Joint", 5) :: Weld?
		if part and joint then
			table.insert(vis.wheels, { part = part, joint = joint, x = wd.x, z = wd.z, front = wd.front, spin = 0 })
		end
	end
	for _, d in chassis:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(vis.emitters, d)
		end
	end
	local sw = model:FindFirstChild("SteeringWheel")
	if sw then
		vis.steerWeld = sw:FindFirstChild("SteerWeld") :: Weld?
		vis.steerBase = sw:GetAttribute("BaseC0") :: CFrame?
	end
	local engine = vis.engine
	if engine and engine.SoundId ~= "" then
		engine:Play()
	end
	local skid = vis.skid
	if skid and skid.SoundId ~= "" then
		skid:Play()
	end
	tracked[model] = vis
end

local function update(dt: number)
	local map = Workspace:FindFirstChild("KaidoMap")
	local road = map and map:FindFirstChild("Road")
	if not road then
		return
	end
	rayParams.FilterDescendantsInstances = { road, Workspace.Terrain }
	local camPos = Workspace.CurrentCamera.CFrame.Position

	for model, vis in tracked do
		if not model.Parent or not vis.chassis.Parent then
			tracked[model] = nil
			continue
		end
		local chassis = vis.chassis
		local cf = chassis.CFrame
		local far = (cf.Position - camPos).Magnitude > 600
		local v = chassis.AssemblyLinearVelocity
		local vF = v:Dot(cf.LookVector)
		local vL = v:Dot(cf.RightVector)
		local planar = math.sqrt(vF * vF + vL * vL)
		local kmh = planar * Config.KMH_PER_SPS
		local slip = if vF > 1 and planar > 4 then math.abs(math.deg(math.atan2(vL, vF))) else 0
		local mine = model == Drive.model
		local steerAngle, rpm, handbrake, throttle
		if mine then
			local tel = Drive.telemetry
			steerAngle, rpm, handbrake, throttle = tel.steerAngle, tel.rpm, tel.handbrake, tel.throttle
		else
			local s = (model:GetAttribute("Steer") :: number?) or 0
			vis.steer += (s - vis.steer) * math.min(1, dt * 10)
			steerAngle = vis.steer * math.rad(vis.spec.lock)
			rpm = (model:GetAttribute("Rpm") :: number?) or 900
			handbrake, throttle = false, 0.5
		end
		local sliding = kmh > 20 and (slip > 12 or (handbrake and kmh > 25))
		local intensity = if sliding then math.clamp((slip - 8) / 30, 0.35, 1) else 0

		-- wheels
		local geo = vis.geo
		local R = geo.radius
		for _, wv in vis.wheels do
			local yLocal = geo.originY - geo.restLen
			local contact: Vector3? = nil
			local normal = Vector3.yAxis
			if not far then
				local origin = cf:PointToWorldSpace(Vector3.new(wv.x, geo.originY, wv.z))
				local hit = Workspace:Raycast(origin, -cf.UpVector * (geo.restLen + R), rayParams)
				if hit then
					yLocal = geo.originY - (hit.Position - origin).Magnitude + R
					contact = hit.Position
					normal = hit.Normal
				end
			end
			wv.spin = (wv.spin - vF / R * dt) % (2 * math.pi)
			local rot = CFrame.Angles(wv.spin, 0, 0)
			if wv.front then
				rot = CFrame.Angles(0, -steerAngle, 0) * rot
			end
			wv.joint.C0 = CFrame.new(wv.x, yLocal, wv.z) * rot
			-- skid marks from the rear tyres (and fronts at big angle)
			if contact and sliding and (not wv.front or slip > 30) then
				local last = wv.last
				if last then
					skidMark(last, contact, normal, 0.35 + 0.45 * intensity)
				end
				wv.last = contact
			else
				wv.last = nil
			end
		end

		-- steering wheel
		local sw, base = vis.steerWeld, vis.steerBase
		if sw and base then
			sw.C0 = base * CFrame.Angles(-steerAngle * 6, 0, 0)
		end

		-- smoke
		for _, e in vis.emitters do
			e.Rate = if sliding then 25 + 70 * intensity else 0
		end

		-- sound
		local engine = vis.engine
		if engine and engine.IsPlaying then
			engine.PlaybackSpeed = math.clamp(rpm / Config.ENGINE_BASE_RPM, 0.35, 3)
			engine.Volume = (if mine then 0.35 else 0.25) + 0.3 * throttle
		end
		local skid = vis.skid
		if skid and skid.IsPlaying then
			skid.Volume += ((if sliding then 0.25 + 0.35 * intensity else 0) - skid.Volume) * math.min(1, dt * 8)
		end
	end
end

function Visuals.start()
	local folder = Workspace:WaitForChild("Cars")
	folder.ChildAdded:Connect(function(c)
		if c:IsA("Model") then
			task.spawn(track, c)
		end
	end)
	for _, c in folder:GetChildren() do
		if c:IsA("Model") then
			task.spawn(track, c)
		end
	end
	RunService.RenderStepped:Connect(update)
	local _ = localPlayer
end

-- other cars currently drifting within `radius` of `pos` (for the TANDEM bonus)
function Visuals.tandem(pos: Vector3, radius: number): boolean
	for model, vis in tracked do
		if model ~= Drive.model and model:GetAttribute("Drift") and (vis.chassis.Position - pos).Magnitude < radius then
			return true
		end
	end
	return false
end

return Visuals
