--!strict
-- Kaido pass centreline. Pure Luau (no Roblox API at module level) so the server map builder,
-- the client minimap and offline tests all derive the exact same road from the same numbers.
-- Units are studs (1 stud = 0.28 m). +X = east, -Z = north, +Y = up.

export type Pt = { x: number, y: number, z: number }
export type TrackData = {
	x: { number },
	y: { number },
	z: { number },
	tx: { number }, -- unit tangent (horizontal), per point
	tz: { number },
	curv: { number }, -- signed horizontal curvature (1/studs)
	n: number,
	length: number,
	segment: number,
}

local Track = {}

Track.WIDTH = 32 -- road width (≈ 9 m)
Track.SEGMENT = 10 -- resample spacing

local cp: { Pt } = {}
local function P(x: number, y: number, z: number)
	table.insert(cp, { x = x, y = y, z = z })
end

-- Arc helper for hairpins: centre (cx, cz), radius r, angle a0 -> a1 (radians, 0 = +X, pi/2 = +Z).
local function arc(cx: number, cz: number, r: number, a0: number, a1: number, y0: number, y1: number, steps: number)
	for i = 0, steps do
		local t = i / steps
		local a = a0 + (a1 - a0) * t
		P(cx + math.cos(a) * r, y0 + (y1 - y0) * t, cz + math.sin(a) * r)
	end
end

local pi = math.pi
local R = 55 -- hairpin radius

-- Kojiri village start line, heading north along the lake shore
P(0, 4, 0)
P(-25, 5, -260)
P(15, 6, -560)
P(-15, 8, -840)
-- right-hand sweeper away from the lake
P(30, 10, -1060)
P(150, 13, -1190)
-- S-bends heading east, climbing
P(300, 16, -1200)
P(430, 20, -1120)
P(570, 25, -1210)
P(700, 30, -1120)
P(830, 36, -1210)
P(950, 40, -1305)
-- hairpin ladder up the hillside (legs run east/west, 110 studs apart)
P(1100, 46, -1305)
P(1220, 52, -1305)
arc(1300, -1360, R, pi / 2, -pi / 2, 56, 62, 8) -- H1 (left)
P(1180, 66, -1415)
P(1060, 72, -1415)
arc(1000, -1470, R, pi / 2, 3 * pi / 2, 76, 82, 8) -- H2 (right)
P(1120, 86, -1525)
P(1240, 92, -1525)
arc(1300, -1580, R, pi / 2, -pi / 2, 96, 102, 8) -- H3 (left)
P(1180, 106, -1635)
P(1060, 112, -1635)
arc(1000, -1690, R, pi / 2, 3 * pi / 2, 116, 122, 8) -- H4 (right)
-- summit run east, then a long fast right-hander to the south
P(1150, 128, -1745)
P(1320, 133, -1790)
P(1480, 135, -1780)
P(1610, 133, -1700)
P(1680, 128, -1560)
-- descent south: S-bends and sweepers
P(1660, 120, -1380)
P(1580, 112, -1220)
P(1640, 102, -1040)
P(1740, 94, -880)
P(1720, 85, -700)
P(1620, 76, -540)
P(1560, 66, -360)
P(1620, 56, -180)
P(1700, 46, -20)
P(1660, 36, 150)
-- tight right onto the valley road back west
P(1560, 30, 280)
P(1400, 26, 320)
P(1220, 22, 280)
P(1060, 18, 340)
P(880, 15, 290)
P(700, 12, 350)
P(520, 9, 300)
P(340, 7, 340)
P(180, 5, 330)
-- last right-hander into the village
P(60, 4, 280)
P(5, 4, 170)

-- centripetal Catmull-Rom (closed loop)
local function cr(p0: Pt, p1: Pt, p2: Pt, p3: Pt, t: number): Pt
	local function tj(ti: number, a: Pt, b: Pt): number
		local d = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
		return ti + math.sqrt(math.max(d, 1e-4))
	end
	local t0 = 0
	local t1 = tj(t0, p0, p1)
	local t2 = tj(t1, p1, p2)
	local t3 = tj(t2, p2, p3)
	local tt = t1 + (t2 - t1) * t
	local function lerp(a: Pt, b: Pt, ta: number, tb: number): Pt
		local u = (tt - ta) / (tb - ta)
		return { x = a.x + (b.x - a.x) * u, y = a.y + (b.y - a.y) * u, z = a.z + (b.z - a.z) * u }
	end
	local a1 = lerp(p0, p1, t0, t1)
	local a2 = lerp(p1, p2, t1, t2)
	local a3 = lerp(p2, p3, t2, t3)
	local b1 = lerp(a1, a2, t0, t2)
	local b2 = lerp(a2, a3, t1, t3)
	return lerp(b1, b2, t1, t2)
end

local cached: TrackData? = nil

function Track.build(): TrackData
	if cached then
		return cached
	end
	local n = #cp
	-- dense sample
	local dense: { Pt } = {}
	for i = 1, n do
		local p0 = cp[(i - 2) % n + 1]
		local p1 = cp[i]
		local p2 = cp[i % n + 1]
		local p3 = cp[(i + 1) % n + 1]
		for s = 0, 39 do
			table.insert(dense, cr(p0, p1, p2, p3, s / 40))
		end
	end
	-- resample at even spacing along the horizontal arc length
	local seg = Track.SEGMENT
	local xs, ys, zs = {}, {}, {}
	local acc = 0
	local nd = #dense
	table.insert(xs, dense[1].x)
	table.insert(ys, dense[1].y)
	table.insert(zs, dense[1].z)
	local total = 0
	for i = 1, nd do
		local a = dense[i]
		local b = dense[i % nd + 1]
		local d = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		total += d
		local start = 0
		while acc + (d - start) >= seg do
			local need = seg - acc
			start += need
			local u = start / d
			table.insert(xs, a.x + (b.x - a.x) * u)
			table.insert(ys, a.y + (b.y - a.y) * u)
			table.insert(zs, a.z + (b.z - a.z) * u)
			acc = 0
		end
		acc += d - start
	end
	-- drop a final point that lands on top of the first
	local m = #xs
	if (xs[m] - xs[1]) ^ 2 + (zs[m] - zs[1]) ^ 2 < (seg * 0.5) ^ 2 then
		table.remove(xs)
		table.remove(ys)
		table.remove(zs)
		m -= 1
	end
	local tx, tz, curv = {}, {}, {}
	for i = 1, m do
		local ip = (i - 2) % m + 1
		local inx = i % m + 1
		local dx, dz = xs[inx] - xs[ip], zs[inx] - zs[ip]
		local l = math.sqrt(dx * dx + dz * dz)
		tx[i], tz[i] = dx / l, dz / l
	end
	for i = 1, m do
		local ip = (i - 2) % m + 1
		local inx = i % m + 1
		-- heading change per stud; positive = turning right (clockwise seen from above)
		local a0 = math.atan2(tz[ip], tx[ip])
		local a1 = math.atan2(tz[inx], tx[inx])
		local da = (a1 - a0 + pi) % (2 * pi) - pi
		curv[i] = da / (2 * seg)
	end
	local data: TrackData = {
		x = xs,
		y = ys,
		z = zs,
		tx = tx,
		tz = tz,
		curv = curv,
		n = m,
		length = total,
		segment = seg,
	}
	cached = data
	return data
end

-- Index of the closest centreline point to (x, z) (linear scan; ~800 points, call sparingly).
function Track.nearest(x: number, z: number): number
	local d = Track.build()
	local best, bi = math.huge, 1
	for i = 1, d.n do
		local dd = (d.x[i] - x) ^ 2 + (d.z[i] - z) ^ 2
		if dd < best then
			best, bi = dd, i
		end
	end
	return bi
end

return Track
