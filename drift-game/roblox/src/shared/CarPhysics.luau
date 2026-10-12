--!strict
-- Drift car physics for Kaido Drift (Roblox). Pure maths, no Roblox APIs, so it is tested outside Studio.
-- Units are studs and seconds (3.5 studs per metre). Mass is 1, so forces are accelerations.
-- Two-axle model: front and rear slip angles, a driven rear axle that loses side grip when it spins,
-- weight transfer, a hand brake, a gearbox (auto or manual) with rpm and rev limiter, clutch kicks,
-- and assist levels from Pro (none) to Easy drift.

local CarPhysics = {}

local G = 34.3
local HCG = 1.7
local APK = 0.14
local IDLE = 900

local function curve(s: number): number
	return math.sin(1.35 * math.atan(2.36 * s))
end
local function sign(x: number): number
	return if x > 0 then 1 elseif x < 0 then -1 else 0
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
-- engine torque against rpm fraction (0 = idle, 1 = redline): pulls hardest near the top
local function torque(x: number): number
	return math.clamp(0.55 + 0.75 * x - 0.45 * x * x, 0.35, 1)
end
-- top road speed in each gear, as a share of the car's top speed
local function gearTop(car, g: number): number
	if g < 0 then return car.top * 0.22 end
	local n = car.gears
	return car.top * (0.32 * (1 / 0.32) ^ ((g - 1) / (n - 1)))
end

function CarPhysics.new(x: number, z: number, h: number)
	return {
		x = x, z = z, h = h, vx = 0, vz = 0, r = 0, delta = 0, ax = 0,
		entryT = 0, entryDir = 0, entryArmed = true, bPrev = 0,
		gear = 1, rpm = IDLE, shiftT = 0, revT = 0, offT = 0, kickT = 0,
		u = 0, speed = 0, beta = 0, sliding = 0, spin = false, limiter = false, thrEff = 0,
	}
end

function CarPhysics.shift(s, car, dir: number)
	if s.shiftT > 0 then return end
	if dir > 0 then
		if s.gear < 0 then s.gear = 1 elseif s.gear < car.gears then s.gear += 1 end
	else
		if s.gear > 1 then s.gear -= 1 elseif s.gear == 1 and s.u < 2 then s.gear = -1 end
	end
	s.shiftT = 0.12
end

function CarPhysics.step(s, inp, car, as, manual: boolean, dt: number)
	-- centre of mass to front axle (A) and rear axle (B): longer cars are calmer, nose-heavy cars push
	local A, B = car.a, car.b
	local WB = A + B
	local IZ = A * B * 1.1
	local fx, fz = math.sin(s.h), math.cos(s.h)
	local rx, rz = -fz, fx
	local u = s.vx * fx + s.vz * fz
	local v = s.vx * rx + s.vz * rz
	local sp = math.sqrt(u * u + v * v)
	local au = math.max(math.abs(u), 3)
	local thr, brk = inp.thr, inp.brk

	-- reverse: hold the brake at a standstill; in reverse the pedals swap, gas takes you forward again
	if s.gear > 0 then
		if brk > 0.2 and thr < 0.05 and u < 0.8 then
			s.revT += dt
			if s.revT > 0.35 then s.gear, s.revT = -1, 0 end
		else
			s.revT = 0
		end
	elseif thr > 0.2 and u > -1 then
		s.gear = 1
	end
	if s.gear < 0 then thr, brk = brk, thr end

	local betaR = math.atan2(v - s.r * B, au)
	local betaF = math.atan2(v + s.r * A, au)
	local beta = if sp > 3 and u > -0.5 * sp then math.atan2(v, au) else 0
	local sliding = math.clamp((math.abs(betaR) - 0.08) / 0.15, 0, 1)

	-- assists: throttle feed and drift entry
	if as.thrMod and thr > 0.05 and math.abs(beta) > 0.45 then
		thr *= math.clamp(1 - (math.abs(beta) - 0.45) / 0.4, 0.3, 1)
	end
	if as.entry > 0 and s.gear > 0 and u > 25 and u < 160 and thr > 0.6 and math.abs(inp.steer) > 0.65 and s.entryArmed and math.abs(betaR) < 0.12 then
		s.entryT, s.entryDir, s.entryArmed = 0.45, sign(inp.steer), false
	end
	if math.abs(inp.steer) < 0.3 or thr < 0.1 then s.entryArmed = true end
	s.entryT = math.max(0, s.entryT - dt)
	local eK = as.entry * s.entryT / 0.45

	-- clutch kick: a quick lift and stab of the gas while steering
	if thr < 0.15 then
		s.offT += dt
	else
		if s.offT > 0.03 and s.offT < 0.45 and thr > 0.6 and math.abs(inp.steer) > 0.25 and u > 12 then s.kickT = 0.35 end
		s.offT = 0
	end
	s.kickT = math.max(0, s.kickT - dt)

	-- gearbox
	s.shiftT = math.max(0, s.shiftT - dt)
	local gTop = gearTop(car, s.gear)
	local wheel = math.abs(u)
	local x = math.clamp(wheel / gTop, 0, 1.08)
	if not manual and s.gear > 0 and s.shiftT == 0 then
		if x > 0.96 and s.gear < car.gears then
			s.gear += 1; s.shiftT = 0.16
		elseif s.gear > 1 and x < 0.45 and wheel / gearTop(car, s.gear - 1) < 0.85 then
			s.gear -= 1; s.shiftT = 0.1
		end
		gTop = gearTop(car, s.gear)
		x = math.clamp(wheel / gTop, 0, 1.08)
	end

	-- steering
	local lock = car.lock
	local maxSteer = if as.speedSteer then lerp(lock / (1 + (math.max(u, 0) / 70) ^ 1.5), lock, sliding) else lock
	local target = inp.steer * maxSteer
	local oversteer = sign(betaF) == -sign(s.r)
	if oversteer and u > 5 then target += as.counter * sliding * betaF end
	target = math.clamp(target, -lock, lock)
	s.delta += math.clamp(target - s.delta, -as.steerRate * dt, as.steerRate * dt)

	-- axle loads
	local Fzf = math.max(0.1, G * B / WB - s.ax * HCG / WB)
	local Fzr = math.max(0.1, G * A / WB + s.ax * HCG / WB)

	local alphaF = math.atan2(v + s.r * A, au) - s.delta
	local Fyf = -car.grip * Fzf * curve(alphaF / APK)

	-- rear axle: engine, wheelspin, hand brake
	local muR = car.grip * 1.06 * (1 - 0.6 * eK)
	if inp.hand then muR *= 0.55 end
	local capR = muR * Fzr
	local Fxr, latCap = 0, capR
	local limiter = false
	local drive = 0
	if s.shiftT == 0 and not inp.hand and thr > 0.02 then
		if x >= 1 then
			limiter = true
		else
			drive = thr * car.power / gTop * torque(x) * 1.25 * (if s.kickT > 0 then 1.8 else 1)
		end
	end
	if s.gear < 0 then
		Fxr = -drive
	else
		if as.tcs then drive = math.min(drive, capR * (1.05 + 0.6 * sliding)) end
		local k = drive / capR
		Fxr = math.min(drive, capR)
		latCap = if k >= 1 then capR * 0.32 else capR * math.sqrt(1 - math.min(k, 0.97) ^ 2)
	end
	s.spin = s.gear > 0 and drive >= capR
	-- engine braking when off the gas in gear
	if thr <= 0.02 and not inp.hand and math.abs(u) > 2 then Fxr -= sign(u) * 2.2 * x end
	if inp.hand and math.abs(u) > 1 then Fxr -= sign(u) * capR * 0.5; latCap *= 0.6 end
	local alphaR = math.atan2(v - s.r * B, au)
	local Fyr = -latCap * curve(alphaR / APK)

	-- brakes (with ABS on every level except Pro), drag, rolling
	local Fb = brk * G * (if as.speedSteer then 0.95 else 1.05)
	local stopF = math.min(Fb + 0.4, math.abs(u) / dt)
	local Fx = Fxr - Fyf * math.sin(s.delta) - car.drag * u * math.abs(u) - sign(u) * stopF
	local Fy = Fyr + Fyf * math.cos(s.delta)
	local Mz = A * Fyf * math.cos(s.delta) - B * Fyr

	if eK > 0 then Mz += s.entryDir * eK * IZ * 3.2 end
	local bRate = (betaR - s.bPrev) / dt
	s.bPrev = betaR
	if sliding > 0 and as.damp > 0 then Mz += as.damp * sliding * IZ * math.clamp(bRate, -4, 4) end
	if as.esp > 0 and math.abs(beta) > as.espAngle and sp > 5 then Mz -= sign(s.r) * IZ * as.esp * (math.abs(beta) - as.espAngle) end

	s.vx += (Fx * fx + Fy * rx) * dt
	s.vz += (Fx * fz + Fy * rz) * dt
	s.r += Mz / IZ * dt
	if sp < 2 then s.r *= 1 - math.min(1, (2 - sp) * 3 * dt) end
	s.h -= s.r * dt
	s.x += s.vx * dt
	s.z += s.vz * dt
	s.ax += (Fx - s.ax) * math.min(1, dt * 10)
	-- park when stopped with the brake on (never while reversing)
	if sp < 0.6 and inp.thr < 0.05 and s.gear > 0 and s.revT == 0 and inp.hand then s.vx, s.vz, s.r = 0, 0, 0 end

	-- rpm: from the road speed, flaring when the rear spins or the clutch slips
	local target_rpm = IDLE + (car.red - IDLE) * math.clamp(x, 0, 1.02)
	if s.spin or s.kickT > 0 then target_rpm = math.max(target_rpm, car.red * (0.85 + 0.15 * thr)) end
	if wheel < 4 then target_rpm = math.max(target_rpm, IDLE + thr * 3200) end
	if inp.hand and thr > 0.05 then target_rpm = math.max(target_rpm, IDLE + thr * (car.red - IDLE) * 0.9) end
	if limiter then target_rpm = car.red * (0.97 + 0.03 * math.sin(os.clock() * 60)) end
	s.rpm += (target_rpm - s.rpm) * math.min(1, dt * 12)

	s.u, s.speed, s.beta, s.sliding, s.limiter, s.thrEff = u, sp, beta, sliding, limiter, thr
end

function CarPhysics.kmh(speed: number): number
	return speed / 3.5 * 3.6
end

return CarPhysics
