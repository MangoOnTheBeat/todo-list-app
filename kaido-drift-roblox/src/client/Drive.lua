--!strict
-- Client-side raycast-suspension drift physics for the local player's car.
-- The client owns the car's network physics, so impulses applied here replicate to everyone.
--
-- Model: 4 raycast springs; each tyre gets a longitudinal + lateral force limited by a friction
-- circle (mu × load). Rear tyres spend grip on drive force first, so power (or the handbrake)
-- leaves little lateral grip and the tail steps out. Easy Drift adds a yaw "kick" on hard steer
-- with gas, eases throttle past ~30° of slide and damps yaw so slides don't turn into spins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local Track = require(Shared:WaitForChild("Track"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local Input = require(script.Parent:WaitForChild("Input"))

local Drive = {}

export type Telemetry = {
	kmh: number,
	forward: number, -- signed forward speed, studs/s
	rpm: number,
	red: number,
	gear: string,
	slipDeg: number, -- signed slide angle
	sliding: boolean,
	grounded: number,
	steerAngle: number, -- radians, + = right
	steerNorm: number,
	throttle: number,
	handbrake: boolean,
	contacts: { Vector3? },
}

Drive.telemetry = {
	kmh = 0, forward = 0, rpm = 900, red = 7000, gear = "N", slipDeg = 0, sliding = false,
	grounded = 0, steerAngle = 0, steerNorm = 0, throttle = 0, handbrake = false, contacts = {},
} :: Telemetry
Drive.easyDrift = true
Drive.model = nil :: Model?

local M_PER_STUD = Config.METERS_PER_STUD
local ACC = Config.ACC
local IDLE = 900
local LAT_GRIP = 0.6 -- fraction of a corner's lateral velocity a gripping tyre removes per frame

local conn: RBXScriptConnection? = nil
local spec: Cars.Car
local geo: CarBuilder.Geometry
local chassis: BasePart
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local gear = 1
local rpm = IDLE
local shiftTimer = 0
local steerAngle = 0
local kickTimer = 0
local kickCooldown = 0
local flipTimer = 0
local offTrackTimer = 0
local reversing = false

local function torqueAt(r: number): number
	local peak, red = spec.peak, spec.red
	if r <= peak then
		return spec.torque * (0.55 + 0.45 * math.clamp(r / peak, 0, 1))
	end
	local u = math.clamp((r - peak) / math.max(red - peak, 1), 0, 1)
	return spec.torque * (1 - 0.38 * u * u)
end

local function rpmForSpeed(vF: number, g: number): number
	local wheelRps = math.abs(vF) * M_PER_STUD / Config.WHEEL_RADIUS_M / (2 * math.pi)
	return wheelRps * 60 * spec.gears[g] * spec.final
end

function Drive.respawn()
	if not chassis or not chassis.Parent then
		return
	end
	local d = Track.build()
	local p = chassis.Position
	local i = Track.nearest(p.X, p.Z)
	local pos = Vector3.new(d.x[i], d.y[i] + geo.chassisY + 1.5, d.z[i])
	local look = pos + Vector3.new(d.tx[i], 0, d.tz[i])
	local model = Drive.model
	if model then
		model:PivotTo(CFrame.lookAt(pos, look))
	end
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
	gear, rpm, steerAngle = 1, IDLE, 0
	flipTimer, offTrackTimer = 0, 0
end

local function step(dt: number)
	if not chassis or not chassis.Parent then
		return
	end
	dt = math.min(dt, 1 / 20)
	local inp = Input.update(dt)
	local tel = Drive.telemetry
	local easy = Drive.easyDrift

	local cf = chassis.CFrame
	local up, fwd, rgt = cf.UpVector, cf.LookVector, cf.RightVector
	local M = chassis.AssemblyMass
	local G = Workspace.Gravity
	local com = chassis.AssemblyCenterOfMass
	local v = chassis.AssemblyLinearVelocity
	local w = chassis.AssemblyAngularVelocity

	local vF = v:Dot(fwd)
	local vL = v:Dot(rgt)
	local planar = math.sqrt(vF * vF + vL * vL)
	local kmh = planar * Config.KMH_PER_SPS
	local beta = if vF > 1 and planar > 4 then math.atan2(vL, vF) else 0 -- + = velocity points right of the nose
	local slipDeg = math.deg(beta)
	local absSlip = math.abs(slipDeg)

	-- ------------------------------------------------ steering
	local lock = math.rad(spec.lock)
	local sliding = absSlip > 8 and kmh > 15
	local speedFactor = if sliding then 1 else 1 - 0.7 * math.clamp(kmh / 150, 0, 1)
	local assist = if easy then 0.9 else 0.7
	local steerTarget = inp.steer * lock * speedFactor + beta * assist
	steerTarget = math.clamp(steerTarget, -lock, lock)
	local steerRate = if math.sign(steerTarget - steerAngle) ~= math.sign(steerAngle) then 7 else 4.5
	steerAngle += math.clamp(steerTarget - steerAngle, -steerRate * dt, steerRate * dt)

	-- ------------------------------------------------ easy drift helpers
	local throttle = inp.throttle
	kickCooldown = math.max(0, kickCooldown - dt)
	kickTimer = math.max(0, kickTimer - dt)
	if easy and throttle > 0.5 and math.abs(inp.steer) > 0.6 and kmh > 30 and absSlip < 12 and kickCooldown <= 0 and tel.grounded >= 3 then
		-- flick the tail out: yaw toward the steer direction (+Y rotation = left)
		local kick = -math.sign(inp.steer) * (0.7 + 0.3 * math.clamp((kmh - 30) / 80, 0, 1))
		w += up * kick
		kickTimer = 0.35
		kickCooldown = 1.0
	end
	if easy and absSlip > 30 then
		throttle *= math.clamp(1 - (absSlip - 30) / 30, 0.4, 1)
	end
	if inp.handbrake then
		throttle = 0 -- clutch in
	end

	-- ------------------------------------------------ stability: damp roll/pitch, limit spin
	local rollRate, pitchRate, yawRate = w:Dot(fwd), w:Dot(rgt), w:Dot(up)
	w -= fwd * rollRate * math.min(1, 5 * dt) + rgt * pitchRate * math.min(1, 2.5 * dt)
	local spinLimit = if easy then 55 else 75
	if absSlip > spinLimit then
		w -= up * yawRate * math.min(1, dt * 4 * (absSlip - spinLimit) / 20)
	elseif easy and absSlip > 20 and math.sign(yawRate) == -math.sign(beta) then
		-- yaw that grows the slide angle gets gently resisted, so angle is held, not spun
		w -= up * yawRate * math.min(1, dt * 1.2)
	end
	chassis.AssemblyAngularVelocity = w

	-- ------------------------------------------------ engine & gearbox
	local nG = #spec.gears
	shiftTimer = math.max(0, shiftTimer - dt)
	if inp.brake > 0.1 and throttle < 0.1 and vF < 1.5 then
		reversing = true
	elseif throttle > 0.1 or vF > 3 then
		reversing = false
	end
	local wheelRpm = rpmForSpeed(vF, gear)
	if not reversing and shiftTimer <= 0 then
		local upAt = spec.red * (if sliding then 0.985 else 0.93)
		if wheelRpm > upAt and gear < nG then
			gear += 1
			shiftTimer = 0.2
		elseif gear > 1 then
			local lower = rpmForSpeed(vF, gear - 1)
			if lower < spec.red * 0.78 and wheelRpm < spec.peak * 0.7 then
				gear -= 1
				shiftTimer = 0.15
			end
		end
	end
	wheelRpm = rpmForSpeed(vF, gear)
	local rpmTarget = math.max(IDLE, wheelRpm)
	if throttle > 0.05 and (sliding or kmh < 12) then
		-- wheelspin / clutch slip lets the engine rev past road speed
		rpmTarget = math.max(rpmTarget, IDLE + (spec.red * 0.92 - IDLE) * throttle * (if sliding then 0.85 else 0.55))
	end
	if inp.handbrake and throttle == 0 and inp.throttle > 0.05 then
		rpmTarget = math.max(rpmTarget, spec.red * 0.8 * inp.throttle)
	end
	rpm += (rpmTarget - rpm) * math.min(1, dt * 10)
	rpm = math.clamp(rpm, IDLE * 0.9, spec.red)

	local driveN = 0 -- Newtons at the rear axle (real units)
	if reversing then
		if math.abs(vF) * Config.KMH_PER_SPS < 25 then
			driveN = -inp.brake * spec.torque * 3.4 * spec.final * 0.85 / Config.WHEEL_RADIUS_M * 0.6
		end
	elseif shiftTimer <= 0 and throttle > 0 then
		local limiter = wheelRpm >= spec.red * 0.995
		if not limiter then
			local effRpm = math.max(wheelRpm, math.min(rpm, spec.peak))
			driveN = torqueAt(effRpm) * spec.gears[gear] * spec.final * 0.85 / Config.WHEEL_RADIUS_M * throttle
			if spec.turbo then
				driveN *= 0.85 + 0.15 * math.clamp((rpm - 2500) / 2000, 0, 1)
			end
		end
	end
	local driveAccel = driveN / spec.mass -- m/s²
	local driveForce = driveAccel * ACC * M -- Roblox force units, whole axle

	-- aero drag + rolling resistance at the centre of mass
	local vFm = vF * M_PER_STUD
	local dragA = 0.5 * 1.2 * spec.CdA * vFm * math.abs(vFm) / spec.mass + 0.12 * math.sign(vF) * math.min(1, math.abs(vF))
	chassis:ApplyImpulse(-fwd * dragA * ACC * M * dt)

	local brakeForce = if reversing then 0 else inp.brake * 11 * ACC * M -- whole car

	-- momentum assist: sliding sideways scrubs speed; a push along the direction of travel keeps
	-- held drifts flowing (arcade, tuned offline against a planar port of this model)
	if sliding and throttle > 0.1 and vF > 0 and planar > 0 then
		local flatV = Vector3.new(v.X, 0, v.Z)
		if flatV.Magnitude > 0.1 then
			local push = throttle * math.min(1, absSlip / 25) * (if easy then 1.5 else 0.9)
			chassis:ApplyImpulse(flatV.Unit * push * ACC * M * dt)
		end
	end

	-- ------------------------------------------------ tyres
	local mu = spec.mu
	local rearGrip = 1
	if inp.handbrake then
		rearGrip *= 0.42
	end
	if kickTimer > 0 then
		rearGrip *= 0.65
	end
	if sliding and throttle > 0.3 then
		rearGrip *= 0.9
	elseif not sliding and not inp.handbrake and kickTimer <= 0 then
		rearGrip *= 1.08 -- a touch of stability when gripping, so plain cornering understeers instead of spinning
	end
	local excess = driveAccel / (mu * 9.81)
	rearGrip *= 1 - throttle * math.clamp(excess * 0.35, 0, 0.3)
	local frontGrip = 1 + (spec.front - 0.5) * 0.6

	local restLen, R = geo.restLen, geo.radius
	local k = M * G / 4 / 0.45
	local c = 2 * 0.55 * math.sqrt(k * M / 4)
	local quarter = M / 4
	-- same grip per second at any frame rate (0.6 of the slip removed per 60 Hz frame)
	local latFrac = 1 - (1 - LAT_GRIP) ^ (dt * 60)
	local grounded = 0
	local parked = throttle == 0 and inp.brake == 0 and not inp.handbrake and planar < 1.2

	for i, wd in geo.wheels do
		local origin = cf:PointToWorldSpace(Vector3.new(wd.x, geo.originY, wd.z))
		local hit = Workspace:Raycast(origin, -up * (restLen + R), rayParams)
		if not hit then
			tel.contacts[i] = nil
			continue
		end
		grounded += 1
		tel.contacts[i] = hit.Position
		local dist = (hit.Position - origin).Magnitude
		local comp = restLen + R - dist
		local pv = v + w:Cross(hit.Position - com)
		local compVel = -pv:Dot(up)
		local Fs = k * comp + c * compVel
		if dist < R * 0.75 then
			Fs += k * 3 * (R * 0.75 - dist) -- bump stop
		end
		Fs = math.max(Fs, 0)
		chassis:ApplyImpulseAtPosition(up * Fs * dt, origin)

		-- tyre frame on the ground plane
		local n = hit.Normal
		local wf = fwd
		if wd.front then
			wf = CFrame.fromAxisAngle(up, -steerAngle) * fwd
		end
		wf = (wf - n * wf:Dot(n)).Unit
		local wr = wf:Cross(n)
		local vx, vy = pv:Dot(wf), pv:Dot(wr)

		local maxF = mu * Fs * (if wd.front then frontGrip else rearGrip)
		local fx = 0
		local fy = -vy * quarter / dt * latFrac
		if parked then
			fx = -vx * quarter / dt * 0.5
		else
			fx -= math.sign(vx) * math.min(brakeForce * (if wd.front then 0.3 else 0.2), math.abs(vx) * quarter / dt)
		end
		if not wd.front then
			fx += driveForce / 2
			if inp.handbrake and math.abs(vx) > 0.5 then
				fx -= math.sign(vx) * maxF * 0.8
			end
			-- rear: drive first, lateral gets what is left of the friction circle
			fx = math.clamp(fx, -maxF * 0.95, maxF * 0.95)
			-- keep some side grip even at full wheelspin so the angle stays controllable
			local fyCap = math.max(math.sqrt(math.max(maxF * maxF - fx * fx, 0)), maxF * (if inp.handbrake then 0.3 else 0.55))
			fy = math.clamp(fy, -fyCap, fyCap)
		else
			local total = math.sqrt(fx * fx + fy * fy)
			if total > maxF and total > 0 then
				fx *= maxF / total
				fy *= maxF / total
			end
		end
		-- apply near centre-of-mass height so cornering doesn't roll the car over
		local at = hit.Position + up * ((com - hit.Position):Dot(up) * 0.7)
		chassis:ApplyImpulseAtPosition((wf * fx + wr * fy) * dt, at)
	end

	-- ------------------------------------------------ recovery
	if up.Y < 0.25 and planar < 8 then
		flipTimer += dt
	else
		flipTimer = 0
	end
	if chassis.Position.Y < -30 then
		offTrackTimer += dt * 3
	else
		offTrackTimer = 0
	end
	if flipTimer > 2 or offTrackTimer > 3 then
		Drive.respawn()
	end
	if grounded == 0 and up.Y < 0.97 then
		-- gently self-level in the air
		local axis = up:Cross(Vector3.yAxis)
		chassis.AssemblyAngularVelocity += axis * math.min(1, dt * 3) * 2
	end

	-- ------------------------------------------------ telemetry
	tel.kmh = kmh
	tel.forward = vF
	tel.rpm = rpm
	tel.red = spec.red
	tel.gear = if reversing then "R" elseif planar < 0.5 and throttle == 0 then "N" else tostring(gear)
	tel.slipDeg = slipDeg
	tel.sliding = sliding
	tel.grounded = grounded
	tel.steerAngle = steerAngle
	tel.steerNorm = steerAngle / lock
	tel.throttle = inp.throttle
	tel.handbrake = inp.handbrake
end

function Drive.start(model: Model, easy: boolean)
	Drive.stop()
	Drive.model = model
	spec = Cars.get(model:GetAttribute("CarId") :: string?)
	geo = CarBuilder.geometry(spec)
	chassis = (model.PrimaryPart or model:WaitForChild("Chassis")) :: BasePart
	Drive.easyDrift = easy
	local map = Workspace:WaitForChild("KaidoMap")
	rayParams.FilterDescendantsInstances = { map:WaitForChild("Road"), Workspace.Terrain }
	gear, rpm, steerAngle, shiftTimer, kickTimer, kickCooldown = 1, IDLE, 0, 0, 0, 0
	flipTimer, offTrackTimer, reversing = 0, 0, false
	Input.reset()
	conn = RunService.PreSimulation:Connect(step)
end

function Drive.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	Drive.model = nil
	local tel = Drive.telemetry
	tel.kmh, tel.rpm, tel.slipDeg, tel.sliding, tel.throttle = 0, IDLE, 0, false, 0
end

return Drive
