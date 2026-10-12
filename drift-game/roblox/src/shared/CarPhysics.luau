-- Kaido Drift car physics: a line-for-line port of the browser game's four-tyre simulation (CarX-style).
-- Units are metres, kg, seconds; the client converts to studs (3.5 per metre) when placing the car.
-- Per-wheel loads with longitudinal and lateral transfer, load-sensitive combined-slip tyres, Ackermann
-- steering, ABS, a locked rear differential with its own wheel speed (integrated semi-implicitly), turbo
-- lag, clutch kicks, an automatic or manual gearbox, and the five assist levels.
local CarPhysics = {}

local G, HCG, KPK, APK, ENTRY_YAW = 9.81, 0.5, 0.1, 0.14, -1
local DEG = math.pi / 180
CarPhysics.RW = 0.31 -- wheel radius (m)
local RW = CarPhysics.RW

local function clamp(v, a, b) return if v < a then a elseif v > b then b else v end
local function lerp(a, b, t) return a + (b - a) * t end
local function smooth(e0, e1, x) local t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t) end
local function sign(x) return if x > 0 then 1 elseif x < 0 then -1 else 0 end
local function tyreCurve(s) return math.sin(1.35 * math.atan(2.36 * s)) end
local function tyreXY(kap, alpha, D)
	local sx, sy = kap / KPK, alpha / APK
	local s = math.sqrt(sx * sx + sy * sy)
	if s < 1e-6 then return 0, 0 end
	local F = D * tyreCurve(s)
	return F * sx / s, -F * sy / s
end
function CarPhysics.torqueAt(c, rpm)
	if rpm >= c.red + 150 then return 0 end
	if rpm < c.peak then return c.torque * (0.55 + 0.45 * math.sin(math.pi / 2 * clamp((rpm - 1000) / (c.peak - 1000), 0, 1))) end
	return c.torque * (1 - 0.3 * ((rpm - c.peak) / (c.red - c.peak)) ^ 2)
end
local function gearRatio(P, c) return (if P.gear < 0 then -3.4 else c.gears[P.gear]) * c.final end

-- the browser game's assist levels
CarPhysics.ASSISTS = {
	off = { counter = 0, steerRate = 4.5, speedSteer = false, abs = false, tcs = false, esp = 0, espAngle = 9, damp = 0, entry = 0, thrMod = false },
	low = { counter = 0.35, steerRate = 6, speedSteer = true, abs = true, tcs = false, esp = 0, espAngle = 9, damp = 0.6, entry = 0.35, thrMod = false },
	std = { counter = 0.7, steerRate = 7.5, speedSteer = true, abs = true, tcs = false, esp = 8, espAngle = 1.15, damp = 1.6, entry = 0.5, thrMod = false },
	high = { counter = 0.95, steerRate = 9, speedSteer = true, abs = true, tcs = true, esp = 16, espAngle = 0.95, damp = 2.8, entry = 0.7, thrMod = true },
	touch = { counter = 1, steerRate = 9, speedSteer = true, abs = true, tcs = false, esp = 12, espAngle = 1.0, damp = 2.4, entry = 1, thrMod = true },
}

function CarPhysics.new(x, z, h)
	return {
		x = x, z = z, h = h, vx = 0, vz = 0, r = 0, wr = 0, gear = 1, shiftT = 0, revT = 0, delta = 0, ax = 0, ay = 0,
		boost = 0, eng = 900, rpm = 900, slip = 0, drifting = false, rearSlip = 0, frontLock = false, limiter = false,
		bPrev = nil, entryT = 0, entryDir = 0, entryArmed = true, offT = 0, kickT = 0, u = 0, thrEff = 0, brkEff = 0, loads = { 1, 1, 1, 1 },
	}
end

function CarPhysics.shiftUp(P, c) if P.gear > 0 and P.gear < #c.gears then P.gear += 1; P.shiftT = 0.12 end end
function CarPhysics.shiftDown(P, c) if P.gear > 1 then P.gear -= 1; P.shiftT = 0.1 end end

-- one step. input = { throttle, brake, hand, steer (+ = right) }; settings = { assist, trans, sens }
function CarPhysics.step(P, c, input, settings, dt)
	local m, Lw = c.mass, c.b.wb
	local a, b = Lw * (1 - c.front), Lw * c.front
	local Iz = m * a * b * 1.1
	local fx, fz = math.sin(P.h), math.cos(P.h)
	local lx, lz = fz, -fx -- forward and left unit vectors
	local u, vy = P.vx * fx + P.vz * fz, P.vx * lx + P.vz * lz
	local sp = math.sqrt(P.vx * P.vx + P.vz * P.vz)
	local thr, brk = input.throttle, input.brake
	local hand = input.hand
	local A = CarPhysics.ASSISTS[settings.assist] or CarPhysics.ASSISTS.std
	-- throttle feed: past ~26° of slide the gas is eased off so a held GAS button holds the angle instead of spinning
	if A.thrMod and thr > 0.05 and P.gear > 0 then
		local ab = math.abs(P.bPrev or 0)
		if ab > 0.45 then thr *= clamp(1 - (ab - 0.45) / 0.4, 0.3, 1) end
	end
	-- drift entry: steer firmly with the gas on and the rear steps out (once per steer input; also links transitions)
	if A.entry > 0 and P.gear > 0 and u > 8 and u < 45 and thr > 0.6 and math.abs(input.steer) > 0.65 and P.entryArmed and math.abs(P.bPrev or 0) < 0.12 then
		P.entryT, P.entryDir, P.entryArmed = 0.5, sign(input.steer), false
	end
	if math.abs(input.steer) < 0.3 or thr < 0.1 then P.entryArmed = true end
	P.entryT = math.max(0, P.entryT - dt)
	local eK = A.entry * P.entryT / 0.5
	-- reverse: hold brake at a standstill
	if P.gear > 0 then
		if brk > 0.2 and thr < 0.05 and u < 0.4 then
			P.revT += dt
			if P.revT > 0.3 then P.gear, P.revT = -1, 0 end
		else
			P.revT = 0
		end
	elseif thr > 0.2 and u > -0.4 then
		P.gear = 1
	end
	if P.gear < 0 then thr, brk = brk, thr end
	local ratio = gearRatio(P, c)
	local ar = math.abs(ratio)
	-- automatic gearbox works from road speed, so wheelspin mid-drift holds the gear
	P.shiftT = math.max(0, P.shiftT - dt)
	if settings.trans ~= "manual" and P.gear > 0 and P.shiftT == 0 then
		local roadRpm = math.abs(u) / RW * ar * 9.549
		if roadRpm > c.red * 0.97 and P.gear < #c.gears then
			P.gear += 1; P.shiftT = 0.16
		elseif P.gear > 1 and roadRpm < c.red * 0.45 and math.abs(u) / RW * c.gears[P.gear - 1] * c.final * 9.549 < c.red * 0.88 then
			P.gear -= 1; P.shiftT = 0.1
		end
	end
	-- engine
	local wheelRpm = math.abs(P.wr) * ar * 9.549
	local clutchSlip = wheelRpm < 1200 or hand
	local eng = if clutchSlip then math.max(wheelRpm, 900 + thr * 3400) else wheelRpm
	-- clutch kick: a quick off-on of the gas while steering dumps the clutch and breaks the rear loose
	if thr < 0.15 then
		P.offT += dt
	else
		if P.offT > 0.03 and P.offT < 0.45 and thr > 0.6 and math.abs(input.steer) > 0.25 and u > 8 then P.kickT = 0.35 end
		P.offT = 0
	end
	P.kickT = math.max(0, P.kickT - dt)
	local tq = 0
	if P.shiftT > 0 or hand then
		tq = 0
	elseif thr > 0.02 then
		tq = if eng > c.red then 0 else CarPhysics.torqueAt(c, eng) * thr * (if c.turbo then 0.62 + 0.38 * P.boost else 1) * (if P.kickT > 0 then 1.8 else 1)
	elseif not clutchSlip then
		tq = -sign(P.wr * ratio) * c.torque * 0.14 * clamp(eng / c.red, 0.2, 1)
	end
	P.limiter = eng > c.red and thr > 0.02
	-- turbo: boost builds with revs and throttle (with lag) and dumps when you lift
	if c.turbo then
		local want = smooth(2400, 4300, eng) * (if thr > 0.05 and not hand then thr else 0)
		P.boost += (want - P.boost) * math.min(1, dt * (if want > P.boost then 2.2 else 5))
	else
		P.boost = 1
	end
	local Tdrive = tq * ratio * 0.85
	-- ===== four tyres: per-wheel load, slip and grip =====
	local tw = c.b.wid - 0.2
	local htw = tw / 2
	local Wf, Wr = m * G * b / Lw / 2, m * G * a / Lw / 2
	local dLong = m * P.ax * HCG / Lw / 2
	local dLatF, dLatR = m * P.ay * HCG / tw * 0.62, m * P.ay * HCG / tw * 0.38
	local minZ = m * G * 0.02
	local Fz = { math.max(minZ, Wf - dLong - dLatF), math.max(minZ, Wf - dLong + dLatF), math.max(minZ, Wr + dLong - dLatR), math.max(minZ, Wr + dLong + dLatR) }
	local function grip(i)
		local front = i <= 2
		return c.mu * (if front then 1.0 else 1.06 * (1 - 0.6 * eK)) * Fz[i] * (1 - 0.08 * (Fz[i] / (if front then Wf else Wr) - 1))
	end
	local WX = { a, a, -b, -b }
	local WY = { htw, -htw, htw, -htw }
	-- steering: driver input plus countersteer assist (front wheels follow the direction of travel)
	local beta = if sp > 1.5 and P.gear > 0 and u > -0.5 * sp then math.atan2(vy, math.max(u, 0.01)) else 0
	local lock = c.lock * DEG
	local dIn = -input.steer * settings.sens
	local betaR = if sp > 1.5 and P.gear > 0 and u > 0.5 then math.atan2(vy - b * P.r, u) else 0
	local betaF = if sp > 1.5 and P.gear > 0 and u > 0.5 then math.atan2(vy + a * P.r, u) else 0
	local sliding = smooth(0.1, 0.25, math.abs(betaR))
	local oversteer = if sign(betaF) == -sign(P.r) then 1 else 0
	local counter = sliding > 0 and sign(dIn) == sign(betaR)
	local inLock = if A.speedSteer and not counter then lerp(lock / (1 + (math.abs(u) / 14) ^ 1.5), lock, sliding) else lock
	local dT = clamp(dIn * inLock + A.counter * sliding * oversteer * betaF, -lock, lock)
	P.delta += clamp(dT - P.delta, -A.steerRate * dt, A.steerRate * dt)
	local d = P.delta
	local ack = sign(d) * math.min(0.06, math.abs(d) * 0.12)
	local DEL = { d + ack, d - ack, 0, 0 }
	-- brakes: 65 % front; ABS on every assist level except Pro
	local brakeTotal = brk * m * G * 0.95
	local Fxw, Fyw = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
	local lockF = false
	for i = 1, 2 do
		local ui, vi = u - P.r * WY[i], vy + P.r * WX[i]
		local cd, sd = math.cos(DEL[i]), math.sin(DEL[i])
		local uw, vw = ui * cd + vi * sd, -ui * sd + vi * cd
		local D = grip(i)
		local alpha = math.atan2(vw, math.max(math.abs(uw), 1.5))
		local bf = brakeTotal * 0.65 / 2
		if A.abs then bf = math.min(bf, D * 0.92) end
		if bf > D * 1.02 and math.abs(uw) > 2 then
			lockF = true
			local vv = math.sqrt(uw * uw + vw * vw)
			if vv == 0 then vv = 1 end
			Fxw[i], Fyw[i] = -uw / vv * D * 0.9, -vw / vv * D * 0.9
		else
			Fyw[i] = -D * sign(alpha) * tyreCurve(math.abs(alpha) / APK)
			Fxw[i] = if math.abs(uw) > 0.2 then -sign(uw) * bf else 0
			local t = math.sqrt(Fxw[i] ^ 2 + Fyw[i] ^ 2)
			if t > D then Fxw[i] *= D / t; Fyw[i] *= D / t end
		end
	end
	P.frontLock = lockF
	-- rear axle: locked differential, one shared wheel speed, integrated semi-implicitly against both tyres
	local Iw = 1.6 + c.engI * ratio * ratio * (if clutchSlip then 0.25 else 1)
	local rr = {}
	for _, i in { 3, 4 } do
		local ui, vi = u - P.r * WY[i], vy + P.r * WX[i]
		table.insert(rr, { i = i, ui = ui, vi = vi, den = math.max(math.abs(ui), 2), D = grip(i), alpha = math.atan2(vi, math.max(math.abs(ui), 1.5)) })
	end
	local Fx0, slope = 0, 0
	for _, w in rr do
		Fx0 += (tyreXY((P.wr * RW - w.ui) / w.den, w.alpha, w.D))
		slope += w.D * 1.35 * 2.36 / KPK * RW / w.den
	end
	local Tdr = Tdrive
	if A.tcs and thr > 0 then
		local spinS = P.wr * RW - u
		if spinS > 6 + math.abs(vy) then Tdr *= clamp(1 - (spinS - 6) / 10, 0.35, 1) end
	end
	local wr = P.wr + dt * (Tdr - RW * Fx0) / (Iw + dt * RW * slope)
	local Tb = brakeTotal * 0.35 * RW + (if hand then 4200 else 0)
	if Tb > 0 then
		local dw = Tb * dt / Iw
		wr = if math.abs(wr) <= dw then 0 else wr - sign(wr) * dw
	end
	P.wr = wr
	for _, w in rr do
		Fxw[w.i], Fyw[w.i] = tyreXY((wr * RW - w.ui) / w.den, w.alpha, w.D)
	end
	-- sum the four tyres into body forces and yaw moment
	local Fxb, Fyb, Mz = 0, 0, 0
	for i = 1, 4 do
		local cd, sd = math.cos(DEL[i]), math.sin(DEL[i])
		local fxb, fyb = Fxw[i] * cd - Fyw[i] * sd, Fxw[i] * sd + Fyw[i] * cd
		Fxb += fxb; Fyb += fyb
		Mz += WX[i] * fyb - WY[i] * fxb
	end
	Fxb -= 0.6 * c.CdA * u * math.abs(u) + m * G * 0.013 * clamp(u, -1, 1)
	-- stability control past the angle a skilled driver would hold (Medium/High); slide damping; drift entry yaw
	if A.esp > 0 and math.abs(beta) > A.espAngle and sp > 5 then Mz += A.esp * Iz * (beta - sign(beta) * A.espAngle) end
	local bRate = (betaR - (P.bPrev or betaR)) / dt
	P.bPrev = betaR
	if A.damp > 0 and sliding > 0 then Mz += A.damp * sliding * Iz * clamp(bRate, -4, 4) end
	if eK > 0 then Mz += ENTRY_YAW * P.entryDir * eK * Iz * 3.2 end
	local FzSum = Fz[1] + Fz[2] + Fz[3] + Fz[4]
	for i = 1, 4 do P.loads[i] = Fz[i] / FzSum * 4 end
	P.vx += (Fxb * fx + Fyb * lx) / m * dt
	P.vz += (Fxb * fz + Fyb * lz) / m * dt
	P.r += Mz / Iz * dt
	if sp < 2 then P.r *= 1 - math.min(1, (2 - sp) * 3 * dt) end
	if sp < 0.35 and thr < 0.05 and (brk > 0.05 or hand) then P.vx, P.vz, P.r, P.wr = 0, 0, 0, 0 end
	P.h += P.r * dt
	P.x += P.vx * dt
	P.z += P.vz * dt
	P.ax += (Fxb / m - P.ax) * math.min(1, dt * 10)
	P.ay += (Fyb / m - P.ay) * math.min(1, dt * 10)
	P.eng, P.u, P.thrEff, P.brkEff = eng, u, thr, brk
	P.slip = if sp > 1.5 then math.atan2(-vy, math.abs(u)) else 0 -- + = sliding toward the car's right
	P.rearSlip = math.sqrt((wr * RW - u) ^ 2 + (vy - b * P.r) ^ 2)
	local sp2 = math.sqrt(P.vx * P.vx + P.vz * P.vz)
	P.drifting = if P.drifting then (math.abs(P.slip) > 0.1 and sp2 > 5) else (math.abs(P.slip) > 0.19 and sp2 > 7)
end

-- a rigid-body impulse against a wall (as in the browser game). n = wall normal pointing back into the
-- road (x, z), depth = how far the corner went through, (rpx, rpz) = that corner relative to the centre
function CarPhysics.wallHit(P, c, nx, nz, depth, rpx, rpz)
	local m, Lw = c.mass, c.b.wb
	local a, b = Lw * (1 - c.front), Lw * c.front
	local Iz = m * a * b * 1.1
	P.x += nx * depth; P.z += nz * depth
	local vpx, vpz = P.vx + P.r * rpz, P.vz - P.r * rpx
	local vn = vpx * nx + vpz * nz
	if vn < 0 then
		local k = nx * rpz - nz * rpx
		local j = -1.25 * vn / (1 / m + k * k / Iz)
		P.vx += j * nx / m; P.vz += j * nz / m; P.r += j * k / Iz
		local tx, tz = -nz, nx
		local vt, kt = vpx * tx + vpz * tz, tx * rpz - tz * rpx
		local jt = clamp(-vt / (1 / m + kt * kt / Iz), -0.3 * j, 0.3 * j)
		P.vx += jt * tx / m; P.vz += jt * tz / m; P.r += jt * kt / Iz
		return -vn
	end
	return 0
end

-- engine rpm for the gauges and sound (browser updatePlayerVisual)
function CarPhysics.visual(P, c, dt)
	P.rpm += (P.eng - P.rpm) * math.min(1, dt * 14)
	if P.limiter then P.rpm = c.red - math.random() * 250 end
end

return CarPhysics
