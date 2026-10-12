--!strict
-- Drift car physics for Kaido Drift (Roblox). Pure maths, no Roblox APIs, so it can be tested outside Studio.
-- Units are studs and seconds. Mass is 1, so forces are accelerations.
-- Two-axle model: front and rear tyre slip angles, a driven rear axle that loses side grip when it spins,
-- weight transfer, a hand brake, and the "Easy drift" assist (drift entry, throttle feed, countersteer).

local CarPhysics = {}

local G = 34.3 -- 9.81 m/s² at 3.5 studs per metre
local A, B = 4.5, 4.5 -- centre of mass to front / rear axle
local WB = A + B
local HCG = 1.7
local IZ = A * B * 1.1
local APK = 0.14 -- slip angle (rad) where a tyre grips hardest

local function curve(s: number): number
	return math.sin(1.35 * math.atan(2.36 * s)) -- peaks at s = 1, then slides at ~85 %
end

local function sign(x: number): number
	return if x > 0 then 1 elseif x < 0 then -1 else 0
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

export type State = {
	x: number, z: number, h: number, -- position and heading (forward = (sin h, cos h))
	vx: number, vz: number, r: number, -- world velocity and yaw rate (positive = turning right)
	delta: number, -- front wheel angle (positive = right)
	ax: number, -- smoothed longitudinal acceleration (weight transfer)
	entryT: number, entryDir: number, entryArmed: boolean, bPrev: number,
	-- outputs
	u: number, speed: number, beta: number, sliding: number, spin: boolean,
}

export type Car = { power: number, grip: number, drag: number, lock: number }
export type Input = { thr: number, brk: number, hand: boolean, steer: number }

function CarPhysics.new(x: number, z: number, h: number): State
	return {
		x = x, z = z, h = h, vx = 0, vz = 0, r = 0, delta = 0, ax = 0,
		entryT = 0, entryDir = 0, entryArmed = true, bPrev = 0,
		u = 0, speed = 0, beta = 0, sliding = 0, spin = false,
	}
end

function CarPhysics.step(s: State, inp: Input, car: Car, easy: boolean, dt: number)
	local fx, fz = math.sin(s.h), math.cos(s.h)
	local rx, rz = -fz, fx -- right-hand side of the car
	local u = s.vx * fx + s.vz * fz
	local v = s.vx * rx + s.vz * rz
	local sp = math.sqrt(u * u + v * v)
	local au = math.max(math.abs(u), 3)
	local thr, brk = inp.thr, inp.brk

	local reverse = brk > 0.2 and thr < 0.1 and u < 1
	local betaR = math.atan2(v - s.r * B, au)
	local betaF = math.atan2(v + s.r * A, au)
	local beta = if sp > 3 then math.atan2(v, au) else 0
	local sliding = math.clamp((math.abs(betaR) - 0.08) / 0.15, 0, 1)

	-- Easy drift: ease the gas off past ~26° of slide so a held gas button holds the angle
	if easy and thr > 0.05 and math.abs(beta) > 0.45 then
		thr *= math.clamp(1 - (math.abs(beta) - 0.45) / 0.4, 0.3, 1)
	end
	-- Easy drift: a firm steer with the gas on kicks the rear out (once per steer input)
	if easy and u > 25 and u < 160 and thr > 0.6 and math.abs(inp.steer) > 0.65 and s.entryArmed and math.abs(betaR) < 0.12 then
		s.entryT, s.entryDir, s.entryArmed = 0.45, sign(inp.steer), false
	end
	if math.abs(inp.steer) < 0.3 or thr < 0.1 then s.entryArmed = true end
	s.entryT = math.max(0, s.entryT - dt)
	local eK = if easy then s.entryT / 0.45 else 0

	-- steering: less lock at speed unless sliding; countersteer assist follows the front of the car
	local lock = car.lock
	local maxSteer = lerp(lock / (1 + (math.max(u, 0) / 70) ^ 1.5), lock, sliding)
	local target = inp.steer * maxSteer
	local oversteer = sign(betaF) == -sign(s.r)
	if easy and oversteer and u > 5 then target += 0.95 * sliding * betaF end
	if not easy and oversteer and u > 5 then target += 0.35 * sliding * betaF end
	target = math.clamp(target, -lock, lock)
	s.delta += math.clamp(target - s.delta, -7 * dt, 7 * dt)

	-- axle loads with weight transfer
	local Fzf = math.max(0.1, G * B / WB - s.ax * HCG / WB)
	local Fzr = math.max(0.1, G * A / WB + s.ax * HCG / WB)

	-- front tyres
	local alphaF = math.atan2(v + s.r * A, au) - s.delta
	local Fyf = -car.grip * Fzf * curve(alphaF / APK)

	-- rear tyres: drive, wheelspin, hand brake
	local muR = car.grip * 1.02 * (1 - 0.6 * eK)
	if inp.hand then muR *= 0.4 end
	local capR = muR * Fzr
	local Fxr, latCap = 0, capR
	if reverse then
		Fxr = -brk * G * 0.22
	else
		local demand = thr * math.min(car.power / math.max(au, 6), capR * 1.8)
		local k = demand / capR
		Fxr = math.min(demand, capR)
		latCap = if k >= 1 then capR * 0.32 else capR * math.sqrt(1 - math.min(k, 0.97) ^ 2)
	end
	s.spin = not reverse and thr > 0.05 and Fxr >= capR * 0.999
	if inp.hand and math.abs(u) > 1 then Fxr -= sign(u) * capR * 0.6; latCap *= 0.45 end
	local alphaR = math.atan2(v - s.r * B, au)
	local Fyr = -latCap * curve(alphaR / APK)

	-- brakes, drag, rolling
	local Fb = if reverse then 0 else brk * G * 0.95
	local Fx = Fxr - Fyf * math.sin(s.delta) - car.drag * u * math.abs(u) - sign(u) * (0.4 + math.min(Fb, math.abs(u) / dt))
	local Fy = Fyr + Fyf * math.cos(s.delta)
	local Mz = A * Fyf * math.cos(s.delta) - B * Fyr

	if eK > 0 then Mz += s.entryDir * eK * IZ * 3.2 end
	local bRate = (betaR - s.bPrev) / dt
	s.bPrev = betaR
	if sliding > 0 then Mz += (if easy then 2.4 else 0.6) * sliding * IZ * math.clamp(bRate, -4, 4) end
	if easy and math.abs(beta) > 1.05 and sp > 5 then Mz -= sign(s.r) * IZ * 6 * (math.abs(beta) - 1.05) end

	s.vx += (Fx * fx + Fy * rx) * dt
	s.vz += (Fx * fz + Fy * rz) * dt
	s.r += Mz / IZ * dt
	if sp < 2 then s.r *= 1 - math.min(1, (2 - sp) * 3 * dt) end
	s.h -= s.r * dt
	s.x += s.vx * dt
	s.z += s.vz * dt
	s.ax += (Fx - s.ax) * math.min(1, dt * 10)
	if sp < 0.6 and thr < 0.05 and (brk > 0.05 or inp.hand) then s.vx, s.vz, s.r = 0, 0, 0 end

	s.u, s.speed, s.beta, s.sliding = u, sp, beta, sliding
end

-- km/h from studs per second
function CarPhysics.kmh(speed: number): number
	return speed / 3.5 * 3.6
end

return CarPhysics
