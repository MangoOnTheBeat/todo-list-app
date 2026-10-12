-- Kaido Drift (Roblox): the course. A closed loop through hairpins and S-bends (the browser game's
-- Kojiri layout, scaled to studs), with smooth climbs and drops. Server and client both build it from
-- the same numbers, so the car never needs the map parts to know where the road is.
local Config = require(script.Parent.Config)

local Track = {}

local CP = {
	{ -718.3, 279.1 }, { -688.5, 20.3 }, { -628.0, -233.0 }, { -534.2, -427.7 }, { -395.7, -502.3 }, { -275.5, -434.9 },
	{ -136.2, -476.3 }, { -47.4, -605.9 }, { 119.8, -655.6 }, { 223.7, -571.3 }, { 203.4, -456.0 }, { 294.5, -374.0 },
	{ 400.0, -447.8 }, { 448.1, -571.3 }, { 585.2, -599.9 }, { 669.5, -479.5 }, { 616.9, -330.3 }, { 680.1, -240.0 },
	{ 717.0, -75.1 }, { 661.7, 14.2 }, { 603.7, 43.6 }, { 543.5, -26.5 }, { 495.0, -50.9 }, { 445.2, -30.6 },
	{ 408.3, 28.9 }, { 426.8, 111.4 }, { 462.5, 170.5 }, { 439.6, 225.8 }, { 369.9, 246.5 }, { 306.3, 195.7 },
	{ 260.7, 154.7 }, { 207.7, 178.3 }, { 183.9, 253.3 }, { 177.9, 437.1 }, { 61.2, 574.9 }, { -110.5, 650.3 },
	{ -294.2, 644.3 }, { -438.8, 566.0 }, { -594.0, 472.6 }, { -697.9, 388.3 },
}
local SCALE = 3.5

-- closed Catmull-Rom through the control points, sampled densely
local dense = {}
local n = #CP
for i = 1, n do
	local p0, p1, p2, p3 = CP[(i - 2) % n + 1], CP[i], CP[i % n + 1], CP[(i + 1) % n + 1]
	for k = 0, 39 do
		local t = k / 40
		local t2, t3 = t * t, t * t * t
		local function cr(a, b, c, d)
			return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
		end
		table.insert(dense, { cr(p0[1], p1[1], p2[1], p3[1]) * SCALE, cr(p0[2], p1[2], p2[2], p3[2]) * SCALE })
	end
end

-- resample at an even spacing
local px, pz = {}, {}
do
	local acc, seg = 0, Config.SEG
	px[1], pz[1] = dense[1][1], dense[1][2]
	for i = 1, #dense do
		local a, b = dense[i], dense[i % #dense + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local pos = 0
		while acc + (len - pos) >= seg do
			pos += seg - acc
			acc = 0
			local f = pos / len
			table.insert(px, a[1] + dx * f)
			table.insert(pz, a[2] + dz * f)
		end
		acc += len - pos
	end
	-- drop a final point that lands on top of the start
	local l = #px
	if math.sqrt((px[l] - px[1]) ^ 2 + (pz[l] - pz[1]) ^ 2) < seg * 0.5 then
		table.remove(px)
		table.remove(pz)
	end
end

local N = #px
-- centre the course on the origin
local cx, cz = 0, 0
for i = 1, N do cx += px[i]; cz += pz[i] end
cx /= N; cz /= N
for i = 1, N do px[i] -= cx; pz[i] -= cz end

-- elevation: smooth climbs and drops, closed around the loop, under ~7 % grade
local py = {}
for i = 1, N do
	local th = (i - 1) / N * math.pi * 2
	py[i] = 46 + 24 * math.sin(3 * th - math.pi / 2) + 12 * math.sin(7 * th)
end

local tx, tz, rx, rz = {}, {}, {}, {}
for i = 1, N do
	local a, b = (i - 2) % N + 1, i % N + 1
	local dx, dz = px[b] - px[a], pz[b] - pz[a]
	local l = math.sqrt(dx * dx + dz * dz)
	tx[i], tz[i] = dx / l, dz / l
	rx[i], rz[i] = -tz[i], tx[i] -- right-hand side when facing along the road
end

Track.N = N
Track.X, Track.Y, Track.Z = px, py, pz
Track.TX, Track.TZ, Track.RX, Track.RZ = tx, tz, rx, rz
Track.LENGTH = N * Config.SEG

function Track.heading(i: number): number
	return math.atan2(tx[i], tz[i])
end

function Track.slope(i: number): number
	local a, b = (i - 2) % N + 1, i % N + 1
	return (py[b] - py[a]) / (2 * Config.SEG)
end

-- nearest road sample to (x, z), searching around a hint first
function Track.nearest(x: number, z: number, hint: number?): number
	local best, bi = math.huge, 1
	if hint then
		for k = -40, 40 do
			local i = (hint - 1 + k) % N + 1
			local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
			if d < best then best, bi = d, i end
		end
		if best < 40 * 40 then return bi end
	end
	for i = 1, N do
		local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
		if d < best then best, bi = d, i end
	end
	return bi
end

-- sideways offset from the centre line and road height at (x, z) near sample i
function Track.at(x: number, z: number, i: number): (number, number)
	local dx, dz = x - px[i], z - pz[i]
	local along = dx * tx[i] + dz * tz[i]
	return dx * rx[i] + dz * rz[i], py[i] + Track.slope(i) * along
end

return Track
