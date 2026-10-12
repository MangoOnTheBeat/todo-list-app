-- Kaido Drift (Roblox): the course. The browser game's real Hakone road (13.7 km, real climbs and
-- drops from elevation data) as a smooth loop. Server and client build it from the same numbers,
-- so the car never needs the map parts to know where the road is.
local Config = require(script.Parent.Config)
local Course = require(script.Parent.CourseData)

local Track = {}

local src = Course.POINTS
local cp = {}
for i = 1, #src, 4 do
	table.insert(cp, { src[i], src[i + 1], src[i + 2], src[i + 3] })
end
local n = #cp

-- closed Catmull-Rom through the points (they are evenly spaced), sampled densely
local dense = {}
for i = 1, n do
	local p0, p1, p2, p3 = cp[(i - 2) % n + 1], cp[i], cp[i % n + 1], cp[(i + 1) % n + 1]
	for k = 0, 19 do
		local t = k / 20
		local t2, t3 = t * t, t * t * t
		local function cr(c)
			local a, b, cc, d = p0[c], p1[c], p2[c], p3[c]
			return 0.5 * (2 * b + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
		end
		table.insert(dense, { cr(1), cr(2), cr(3), if t < 0.5 then p1[4] else p2[4] })
	end
end

-- resample every SEG studs along the ground
local px, py, pz, zone = {}, {}, {}, {}
do
	local seg, acc = Config.SEG, 0
	local m = #dense
	table.insert(px, dense[1][1]); table.insert(py, dense[1][2]); table.insert(pz, dense[1][3]); table.insert(zone, dense[1][4])
	for i = 1, m do
		local a, b = dense[i], dense[i % m + 1]
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local pos = 0
		while acc + (len - pos) >= seg do
			pos += seg - acc
			acc = 0
			local f = pos / len
			table.insert(px, a[1] + dx * f)
			table.insert(py, a[2] + (b[2] - a[2]) * f)
			table.insert(pz, a[3] + dz * f)
			table.insert(zone, a[4])
		end
		acc += len - pos
	end
	local l = #px
	if math.sqrt((px[l] - px[1]) ^ 2 + (pz[l] - pz[1]) ^ 2) < seg * 0.5 then
		table.remove(px); table.remove(py); table.remove(pz); table.remove(zone)
	end
end
local N = #px

local tx, tz, rx, rz = {}, {}, {}, {}
for i = 1, N do
	local a, b = (i - 2) % N + 1, i % N + 1
	local dx, dz = px[b] - px[a], pz[b] - pz[a]
	local l = math.sqrt(dx * dx + dz * dz)
	tx[i], tz[i] = dx / l, dz / l
	rx[i], rz[i] = -tz[i], tx[i] -- right-hand side when facing along the road
end

Track.N = N
Track.X, Track.Y, Track.Z, Track.ZONE = px, py, pz, zone
Track.TX, Track.TZ, Track.RX, Track.RZ = tx, tz, rx, rz
Track.LENGTH = N * Config.SEG
Track.ZONE_NAMES = { [0] = "湖尻 · Kojiri village", [1] = "箱根 · Hakone hills", [2] = "芦ノ湖 · Lake Ashi shore" }

-- spatial hash so "where is the road?" is quick anywhere on the map
local CELL = 80
local hash = {}
local function key(cx, cz) return cx * 100000 + cz end
for i = 1, N do
	local k = key(math.floor(px[i] / CELL), math.floor(pz[i] / CELL))
	local t = hash[k]
	if not t then t = {}; hash[k] = t end
	table.insert(t, i)
end

function Track.heading(i: number): number
	return math.atan2(tx[i], tz[i])
end

function Track.slope(i: number): number
	local a, b = (i - 2) % N + 1, i % N + 1
	return (py[b] - py[a]) / (2 * Config.SEG)
end

-- nearest road sample: searched along the road from the last one first (fast, and never jumps to a
-- road section above or below on a hairpin), then through the spatial hash
function Track.nearest(x: number, z: number, hint: number?): number
	local best, bi = math.huge, 1
	if hint then
		for k = -30, 30 do
			local i = (hint - 1 + k) % N + 1
			local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
			if d < best then best, bi = d, i end
		end
		if best < 30 * 30 then return bi end
	end
	local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
	for dx = -2, 2 do
		for dz = -2, 2 do
			local t = hash[key(cx + dx, cz + dz)]
			if t then
				for _, i in t do
					local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
					if d < best then best, bi = d, i end
				end
			end
		end
	end
	if best == math.huge then
		for i = 1, N do
			local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
			if d < best then best, bi = d, i end
		end
	end
	return bi
end

-- every road sample within r studs (for building scenery)
function Track.near(x: number, z: number, r: number): { number }
	local out = {}
	local cx, cz, span = math.floor(x / CELL), math.floor(z / CELL), math.ceil(r / CELL)
	for dx = -span, span do
		for dz = -span, span do
			local t = hash[key(cx + dx, cz + dz)]
			if t then
				for _, i in t do
					if (px[i] - x) ^ 2 + (pz[i] - z) ^ 2 < r * r then table.insert(out, i) end
				end
			end
		end
	end
	return out
end

-- sideways offset from the centre line and road height at (x, z) near sample i
function Track.at(x: number, z: number, i: number): (number, number)
	local dx, dz = x - px[i], z - pz[i]
	local along = dx * tx[i] + dz * tz[i]
	return dx * rx[i] + dz * rz[i], py[i] + Track.slope(i) * along
end

return Track
