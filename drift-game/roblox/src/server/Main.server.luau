-- Kaido Drift (Roblox) server: builds the Hakone pass (real course and elevation, hills, Lake Ashi,
-- Kojiri village, Mt. Fuji on the horizon), keeps every player's progress and settings on Roblox's
-- servers (DataStore), checks drift scores and laps, and relays cars between players on the public map.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Track = require(Shared.Track)
local Course = require(Shared.CourseData)
local City = require(script.Parent:WaitForChild("City"))

-- ===================== remotes =====================
local remotes = Instance.new("Folder")
remotes.Name = "KaidoRemotes"
local function remote(class, name)
	local ok, r = pcall(Instance.new, class)
	if not ok then r = Instance.new("RemoteEvent") end
	r.Name = name
	r.Parent = remotes
	return r
end
local GetProfile = remote("RemoteFunction", "GetProfile")
local Buy = remote("RemoteFunction", "Buy")
local SelectCar = remote("RemoteFunction", "Select")
local Paint = remote("RemoteFunction", "Paint")
local Erase = remote("RemoteFunction", "Erase")
local SaveSettings = remote("RemoteEvent", "SaveSettings")
local SetMode = remote("RemoteEvent", "SetMode")
local Bank = remote("RemoteEvent", "Bank")
local Lap = remote("RemoteEvent", "Lap")
local State = remote("UnreliableRemoteEvent", "State")
local Others = remote("UnreliableRemoteEvent", "Others")
local ProfileChanged = remote("RemoteEvent", "Profile")
local Tune = remote("RemoteFunction", "Tune")
local BuySpecial = remote("RemoteEvent", "BuySpecial")
remotes.Parent = ReplicatedStorage

-- ===================== lighting (each player can change the time of day for themselves) =====================
Lighting.ClockTime = 0
Lighting.Brightness = 1.4
Lighting.Ambient = Color3.fromRGB(34, 38, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(58, 64, 100)
Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.7
local atmo = Instance.new("Atmosphere")
atmo.Density, atmo.Offset, atmo.Haze, atmo.Glare = 0.3, 0.12, 1.1, 0
atmo.Color, atmo.Decay = Color3.fromRGB(72, 82, 122), Color3.fromRGB(22, 24, 42)
atmo.Parent = Lighting
local sky = Instance.new("Sky")
sky.StarCount, sky.CelestialBodiesShown, sky.MoonAngularSize = 6000, true, 13
sky.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "KaidoBloom"
bloom.Intensity, bloom.Size, bloom.Threshold = 0.55, 28, 1.6
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "KaidoGrade"
cc.Contrast, cc.Saturation = 0.08, 0.06
cc.Parent = Lighting

-- ===================== map =====================
local map = Instance.new("Folder")
map.Name = "KaidoMap"
map.Parent = workspace
local rng = Random.new(1989)
local N, X, Y, Z = Track.N, Track.X, Track.Y, Track.Z
local HALF = Config.ROAD_HALF
local FLOOR = 6 -- the open ground a little above the lake
local terrain = workspace.Terrain
local work = 0
local function breathe() work += 1; if work % 120 == 0 then task.wait() end end

local function block(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then p.Shape = shape end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ground, hills and Lake Ashi (terrain)
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, N do
	minX, maxX = math.min(minX, X[i]), math.max(maxX, X[i])
	minZ, maxZ = math.min(minZ, Z[i]), math.max(maxZ, Z[i])
end
local margin = 2400
for gx = minX - margin, maxX + margin, 2048 do
	for gz = minZ - margin, maxZ + margin, 2048 do
		terrain:FillBlock(CFrame.new(gx + 1024, FLOOR - 6, gz + 1024), Vector3.new(2048, 12, 2048), Enum.Material.Grass)
		breathe()
	end
end
local LAKE_Y = Course.LAKE_Y
local function lakeCell(x, z, size)
	terrain:FillBlock(CFrame.new(x, LAKE_Y + 6, z), Vector3.new(size, 12, size), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(x, LAKE_Y - 6, z), Vector3.new(size, 12, size), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(x, LAKE_Y - 16, z), Vector3.new(size, 8, size), Enum.Material.Sand)
end
local L = Course.LAKES
for k = 1, #L, 2 do lakeCell(L[k], L[k + 1], Course.LAKECELL); breathe() end
local C, CS = Course.CELLS, Course.CELL
local hillTops = {}
for k = 1, #C, 4 do
	local x, top, z, lake = C[k], C[k + 1], C[k + 2], C[k + 3]
	if lake == 1 then
		lakeCell(x, z, CS)
	elseif top > FLOOR + 0.5 then
		local mat = if top > 60 then Enum.Material.LeafyGrass else Enum.Material.Grass
		terrain:FillBlock(CFrame.new(x, (top + FLOOR - 4) / 2, z), Vector3.new(CS, top - FLOOR + 4, CS), mat)
		table.insert(hillTops, { x, top, z })
	else
		table.insert(hillTops, { x, FLOOR, z })
	end
	breathe()
end

-- where the link road to the city leaves the pass: its eastern-most point (no guardrail on that side there)
local junction, junctionSide = 1, 1
do
	local best = -math.huge
	for k = 1, N do if X[k] > best then best, junction = X[k], k end end
	junctionSide = if Track.RX[junction] > 0 then 1 else -1
end
local function nearJunction(k)
	local d = math.abs(k - junction)
	return math.min(d, N - d) <= 5
end

-- road: straight runs are merged into long parts, curves use short ones
local road = Instance.new("Folder")
road.Name = "Road"
road.Parent = map
local rails = Instance.new("Folder")
rails.Name = "Rails"
rails.Parent = map
local asphalt, rail, rock = Color3.fromRGB(44, 45, 50), Color3.fromRGB(172, 174, 178), Color3.fromRGB(96, 88, 78)
local EDGE = Color3.fromRGB(89, 227, 255)
local function turnBetween(i, j)
	return math.abs(math.atan2(Track.TX[i] * Track.TZ[j] - Track.TZ[i] * Track.TX[j], Track.TX[i] * Track.TX[j] + Track.TZ[i] * Track.TZ[j]))
end
local i = 1
while i <= N do
	local j = i + 1
	while j - i < 8 and j <= N and turnBetween(i, ((j - 1) % N) + 1) < math.rad(1.5) and math.abs(Track.slope(i) - Track.slope(((j - 1) % N) + 1)) < 0.01 do j += 1 end
	local jj = ((j - 1) % N) + 1
	local a, b = Vector3.new(X[i], Y[i], Z[i]), Vector3.new(X[jj], Y[jj], Z[jj])
	local mid = (a + b) / 2
	local len = (b - a).Magnitude + 1.2 + HALF * 2 * turnBetween(((j - 2) % N) + 1, jj)
	local cf = CFrame.lookAt(mid, b)
	-- a thick road slab, and no terrain from 3 studs below its surface upwards: terrain is built from 4-stud
	-- voxels and bulges over a thin part, so it must stay well clear of the road
	block(road, Vector3.new(HALF * 2, 4, len), cf * CFrame.new(0, -2, 0), asphalt, Enum.Material.Asphalt).Name = "Road"
	terrain:FillBlock(cf * CFrame.new(0, -5.5, 0), Vector3.new(HALF * 2 + 4, 4, len + 2), Enum.Material.Ground) -- no grass blades under it
	terrain:FillBlock(cf * CFrame.new(0, 13.5, 0), Vector3.new(HALF * 2 + 12, 33, len + 4), Enum.Material.Air)
	for _, side in { -1, 1 } do
		if side == junctionSide and (nearJunction(i) or nearJunction(jj)) then continue end
		local ra = a + Vector3.new(Track.RX[i], 0, Track.RZ[i]) * side * (HALF + 0.9)
		local rb = b + Vector3.new(Track.RX[jj], 0, Track.RZ[jj]) * side * (HALF + 0.9)
		local rcf = CFrame.lookAt((ra + rb) / 2, rb)
		block(rails, Vector3.new(0.5, 1.2, (rb - ra).Magnitude + 0.8), rcf * CFrame.new(0, 1.6, 0), rail, Enum.Material.DiamondPlate).Name = "Rail"
		block(rails, Vector3.new(0.4, 2.2, 0.4), CFrame.new(ra + Vector3.new(0, 1.1, 0)), Color3.fromRGB(120, 122, 126), Enum.Material.Metal).Name = "Post"
		-- glowing edge line just outside the asphalt, so the road reads at night
		local ea = a + Vector3.new(Track.RX[i], 0, Track.RZ[i]) * side * (HALF + 0.3)
		local eb = b + Vector3.new(Track.RX[jj], 0, Track.RZ[jj]) * side * (HALF + 0.3)
		local edge = block(rails, Vector3.new(0.5, 0.3, (eb - ea).Magnitude + 0.6), CFrame.lookAt((ea + eb) / 2, eb) * CFrame.new(0, -0.1, 0), EDGE, Enum.Material.Neon)
		edge.Name, edge.CanCollide, edge.CanQuery = "Edge", false, false
	end
	-- embankment below the road (hidden inside hills where the ground is high)
	if mid.Y > FLOOR + 1 then
		local flat = CFrame.lookAt(Vector3.new(mid.X, (mid.Y + FLOOR) / 2 - 1, mid.Z), Vector3.new(b.X, (mid.Y + FLOOR) / 2 - 1, b.Z))
		block(road, Vector3.new(HALF * 2 + 6, mid.Y - FLOOR, len), flat, rock, Enum.Material.Slate).Name = "Bank"
	end
	breathe()
	i = j
end
-- kerbs on the bends, dashed centre line on the straights
local roadDeco = Instance.new("Folder")
roadDeco.Name = "RoadDeco"
roadDeco.Parent = map
for k = 1, N do
	local nx = k % N + 1
	local a, b = Vector3.new(X[k], Y[k], Z[k]), Vector3.new(X[nx], Y[nx], Z[nx])
	local cf = CFrame.lookAt((a + b) / 2, b)
	local len = (b - a).Magnitude + 0.4
	if turnBetween(k, ((k + 1) % N) + 1) > math.rad(2.2) then
		for _, side in { -1, 1 } do
			local kp = block(roadDeco, Vector3.new(1.6, 0.22, len), cf * CFrame.new(side * (HALF - 0.8), 0.06, 0), (k // 1) % 2 == 0 and Color3.fromRGB(205, 36, 40) or Color3.fromRGB(236, 236, 236), Enum.Material.SmoothPlastic)
			kp.CanCollide = false
		end
	elseif k % 4 == 0 then
		local line = block(roadDeco, Vector3.new(0.45, 0.08, len * 1.6), cf * CFrame.new(0, 0.02, 0), Color3.fromRGB(240, 236, 220), Enum.Material.SmoothPlastic)
		line.CanCollide = false
	end
	if k % 200 == 0 then task.wait() end
end

-- chevron boards on the outside of the tight corners, pointing the way the road turns
local signs = Instance.new("Folder")
signs.Name = "Chevrons"
signs.Parent = map
do
	local function turnAt(k)
		local a, b = ((k - 4) % N) + 1, ((k + 2) % N) + 1
		return math.asin(math.clamp(Track.TX[a] * Track.TZ[b] - Track.TZ[a] * Track.TX[b], -1, 1))
	end
	local k, placed = 1, 0
	while k <= N do
		local t = turnAt(k)
		if 60 / math.max(math.abs(t), 1e-6) < 50 and not nearJunction(k) then
			-- a tight corner starts here: boards from a little before it, every 20 studs, up to 5
			local a, b = ((k - 4) % N) + 1, ((k + 2) % N) + 1
			local inward = (Track.TX[b] - Track.TX[a]) * Track.RX[k] + (Track.TZ[b] - Track.TZ[a]) * Track.RZ[k]
			local s = if inward > 0 then 1 else -1 -- side of the road the corner turns towards
			for n = 0, 4 do
				local q = ((k - 3 + n * 2 - 1) % N) + 1
				local T = Vector3.new(Track.TX[q], 0, Track.TZ[q])
				local Rv = Vector3.new(Track.RX[q], 0, Track.RZ[q])
				local base = Vector3.new(X[q], Y[q], Z[q]) - Rv * s * (HALF + 4.5)
				local board = CFrame.lookAt(base + Vector3.new(0, 3.2, 0), base + Vector3.new(0, 3.2, 0) - T)
				block(signs, Vector3.new(0.4, 3, 0.4), CFrame.new(base + Vector3.new(0, 1.5, 0)), Color3.fromRGB(62, 64, 68), Enum.Material.Metal)
				block(signs, Vector3.new(3.6, 2.6, 0.3), board, Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic)
				local dir = if (Rv * s):Dot(board.RightVector) > 0 then 1 else -1
				for _, up in { 1, -1 } do
					local bar = block(signs, Vector3.new(1.7, 0.42, 0.12), board * CFrame.new(0, up * 0.42, -0.2) * CFrame.Angles(0, 0, -up * dir * math.rad(38)), Color3.fromRGB(255, 200, 40), Enum.Material.Neon)
					bar.CanCollide, bar.CanQuery = false, false
				end
				placed += 1
			end
			k += 14 -- skip the rest of this corner
		else
			k += 1
		end
		breathe()
	end
	signs:SetAttribute("Count", placed)
end

-- street lamps (warm sodium light)
local lamps = Instance.new("Folder")
lamps.Name = "Lamps"
lamps.Parent = map
local lampCount = 0
for k = 1, N, 18 do
	local side = (k // 18) % 2 == 0 and 1 or -1
	local base = Vector3.new(X[k] + Track.RX[k] * side * (HALF + 3), Y[k], Z[k] + Track.RZ[k] * side * (HALF + 3))
	local inward = Vector3.new(-Track.RX[k] * side, 0, -Track.RZ[k] * side)
	local pole = Color3.fromRGB(62, 64, 68)
	block(lamps, Vector3.new(0.8, 18, 0.8), CFrame.new(base + Vector3.new(0, 9, 0)), pole, Enum.Material.Metal)
	block(lamps, Vector3.new(0.5, 0.5, 6), CFrame.lookAt(base + Vector3.new(0, 18, 0) + inward * 3, base + Vector3.new(0, 18, 0) + inward * 6), pole, Enum.Material.Metal)
	local head = block(lamps, Vector3.new(2.2, 0.5, 1.2), CFrame.new(base + Vector3.new(0, 17.6, 0) + inward * 5.5), Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
	head.Name = "LampHead"
	lampCount += 1
	head:SetAttribute("N", lampCount)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 186, 112), 44, 2.4, false
	light.Parent = head
	breathe()
end

-- Kojiri village: wooden houses with lit windows and lanterns, and glowing vending machines
local village = Instance.new("Folder")
village.Name = "Village"
village.Parent = map
local wood, roofC = Color3.fromRGB(98, 68, 48), Color3.fromRGB(58, 62, 74)
local houses = 0
for k = 1, N, 9 do
	if Track.ZONE[k] == 0 then
		local side = (k // 9) % 2 == 0 and 1 or -1
		local dist = HALF + 24 + rng:NextNumber() * 10
		local c = Vector3.new(X[k] + Track.RX[k] * side * dist, Y[k], Z[k] + Track.RZ[k] * side * dist)
		if #Track.near(c.X, c.Z, HALF + 18) == 0 then
			houses += 1
			local face = CFrame.lookAt(c, c - Vector3.new(Track.RX[k] * side, 0, Track.RZ[k] * side))
			block(village, Vector3.new(30, c.Y - FLOOR + 2, 26), CFrame.new(c - Vector3.new(0, (c.Y - FLOOR + 2) / 2, 0)), Color3.fromRGB(82, 76, 68), Enum.Material.Cobblestone)
			local w, d, h = 20 + rng:NextInteger(0, 6), 14 + rng:NextInteger(0, 4), 11 + rng:NextInteger(0, 5)
			-- dark timber walls over a white plaster upper storey, on a stone plinth (a Hakone inn look)
			block(village, Vector3.new(w, h * 0.55, d), face * CFrame.new(0, h * 0.275, 0), wood, Enum.Material.WoodPlanks)
			block(village, Vector3.new(w - 0.4, h * 0.45, d - 0.4), face * CFrame.new(0, h * 0.775, 0), Color3.fromRGB(226, 220, 206), Enum.Material.Plaster)
			block(village, Vector3.new(w + 0.6, 1.4, d + 0.6), face * CFrame.new(0, 0.7, 0), Color3.fromRGB(104, 100, 94), Enum.Material.Cobblestone)
			block(village, Vector3.new(w + 1.2, 0.5, d + 1.2), face * CFrame.new(0, h * 0.55, 0), Color3.fromRGB(58, 62, 74), Enum.Material.ClayRoofTiles) -- small eave between storeys
			block(village, Vector3.new(4, 7, 0.3), face * CFrame.new(0, 3.5, -d / 2 - 0.1), Color3.fromRGB(64, 44, 32), Enum.Material.WoodPlanks) -- door
			local r1 = Instance.new("WedgePart")
			r1.Anchored, r1.Size, r1.Color, r1.Material = true, Vector3.new(w + 2, 5, d / 2 + 1), roofC, Enum.Material.ClayRoofTiles
			r1.CFrame = face * CFrame.new(0, h + 2.5, -(d / 4 + 0.5))
			r1.Parent = village
			local r2 = r1:Clone()
			r2.CFrame = face * CFrame.new(0, h + 2.5, d / 4 + 0.5) * CFrame.Angles(0, math.pi, 0)
			r2.Parent = village
			for wx = -1, 1, 2 do
				block(village, Vector3.new(3.2, 3, 0.3), face * CFrame.new(wx * w / 4, h * 0.3, -d / 2 - 0.05), Color3.fromRGB(255, 202, 128), Enum.Material.Neon).Name = "Window"
			end
			local lantern = block(village, Vector3.new(1.6, 2.2, 1.6), face * CFrame.new(0, h * 0.7, -d / 2 - 1.2), Color3.fromRGB(236, 56, 40), Enum.Material.Neon, Enum.PartType.Ball)
			lantern.Name = "Lantern"
			local pl = Instance.new("PointLight")
			pl.Color, pl.Range, pl.Brightness = Color3.fromRGB(255, 140, 90), 22, 2
			pl.Parent = lantern
			if houses % 3 == 0 then
				local vm = block(village, Vector3.new(3.6, 6, 2.4), face * CFrame.new(w / 2 + 3, 3, -d / 2 + 1), Color3.fromRGB(230, 236, 246), Enum.Material.SmoothPlastic)
				vm.Name = "Vending"
				block(village, Vector3.new(3, 3.4, 0.2), face * CFrame.new(w / 2 + 3, 3.6, -d / 2 - 0.25), Color3.fromRGB(150, 220, 255), Enum.Material.Neon).Name = "VendingFace"
			end
		end
		breathe()
	end
end

-- trees on the hillsides: cedars and autumn maples; Tier lets each player's graphics level thin them out
local trees = Instance.new("Folder")
trees.Name = "Trees"
trees.Parent = map
local placed = 0
for _, cell in hillTops do
	if placed >= 1800 then break end
	for _ = 1, 2 do
		local x, z = cell[1] + rng:NextNumber(-40, 40), cell[3] + rng:NextNumber(-40, 40)
		if #Track.near(x, z, HALF + 14) == 0 and rng:NextNumber() < 0.75 then
			local s = 0.8 + rng:NextNumber() * 0.8
			local ground = Vector3.new(x, cell[2] - 0.5, z)
			local tree = Instance.new("Model")
			tree.Name = "Tree"
			tree:SetAttribute("Tier", rng:NextInteger(1, 3))
			local maple = rng:NextNumber() < 0.22
			block(tree, Vector3.new(14 * s, 1.6 * s, 1.6 * s), CFrame.new(ground + Vector3.new(0, 7 * s, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(72, 52, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
			if maple then
				local leaf = rng:NextNumber() < 0.5 and Color3.fromRGB(180, 54, 32) or Color3.fromRGB(216, 142, 44)
				block(tree, Vector3.new(15 * s, 11 * s, 15 * s), CFrame.new(ground + Vector3.new(0, 14 * s, 0)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
				block(tree, Vector3.new(10 * s, 8 * s, 10 * s), CFrame.new(ground + Vector3.new(2 * s, 19 * s, -1 * s)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
			else
				local leaf = Color3.fromRGB(26 + rng:NextInteger(0, 14), 64 + rng:NextInteger(0, 18), 38)
				for t = 0, 2 do
					local r = (8.5 - t * 2.4) * s
					block(tree, Vector3.new(r * 2, r * 1.7, r * 2), CFrame.new(ground + Vector3.new(0, (11 + t * 6.5) * s, 0)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
				end
			end
			tree.Parent = trees
			placed += 1
		end
	end
	breathe()
end

-- the start gate (torii) and Mt. Fuji on the horizon
do
	local k = 1
	local c = Vector3.new(X[k], Y[k], Z[k])
	local face = CFrame.lookAt(c, c + Vector3.new(Track.TX[k], 0, Track.TZ[k]))
	local red = Color3.fromRGB(196, 30, 34)
	for _, s in { -1, 1 } do block(map, Vector3.new(1.8, 24, 1.8), face * CFrame.new(s * (HALF + 3), 12, 0), red, Enum.Material.Wood) end
	block(map, Vector3.new(HALF * 2 + 16, 1.8, 2.6), face * CFrame.new(0, 23, 0), red, Enum.Material.Wood)
	block(map, Vector3.new(HALF * 2 + 11, 1.2, 1.8), face * CFrame.new(0, 20, 0), Color3.fromRGB(28, 28, 30), Enum.Material.Wood)
	local fuji = Instance.new("Folder")
	fuji.Name = "Fuji"
	fuji.Parent = map
	local fx, fz = Course.FUJI[1], Course.FUJI[2]
	for t = 0, 11 do
		local r = 1024 * (1 - t / 12) ^ 1.15
		local hgt = 95
		local col = if t >= 8 then Color3.fromRGB(236, 240, 246) else Color3.fromRGB(64 + t * 3, 72 + t * 3, 96 + t * 2)
		local p = block(fuji, Vector3.new(hgt, r * 2, r * 2), CFrame.new(fx, FLOOR + hgt / 2 + t * hgt, fz) * CFrame.Angles(0, 0, math.pi / 2), col, if t >= 8 then Enum.Material.Snow else Enum.Material.Rock, Enum.PartType.Cylinder)
		p.CanCollide = false
	end
end

-- Shin-Hakone city and the link road
local city = City.build({ Track = Track, rng = rng, breathe = breathe, FLOOR = FLOOR, HALF = HALF, map = map, junction = junction, junctionSide = junctionSide })
map:SetAttribute("CitySpawn", Vector3.new(city.spawn[1], city.spawn[2], city.spawn[3]))
map:SetAttribute("CityMin", Vector2.new(city.bounds[1], city.bounds[2]))
map:SetAttribute("CityMax", Vector2.new(city.bounds[3], city.bounds[4]))
map:SetAttribute("CityRing", Vector3.new(city.ring[1], city.ring[2], city.ring[3]))
map:SetAttribute("CityRing2", city.ring[4])
map:SetAttribute("CityPitch", city.grid.PITCH)
map:SetAttribute("CityStreet", city.grid.STREET)
map:SetAttribute("CityGrid", city.grid.GRID)
map:SetAttribute("Junction", junction)
print(string.format("Kaido Drift map ready: pass %d samples, city %d buildings", N, city.buildings))

map:SetAttribute("Ready", true)

-- ===================== players: progress and settings on Roblox's servers =====================
local store
pcall(function() store = DataStoreService:GetDataStore("KaidoDrift_v2") end)
local profiles, lastBank, lastLap, publicMode, dirty = {}, {}, {}, {}, {}
-- global leaderboards (best single drift, total points banked)
local bestStore, totalStore
pcall(function()
	bestStore = DataStoreService:GetOrderedDataStore("KaidoBestDrift")
	totalStore = DataStoreService:GetOrderedDataStore("KaidoTotalPoints")
end)
local boardDirty = {}

local function newProfile()
	return { credits = 0, owned = { ps13 = true }, selected = "ps13", best = 0, laps = 0, total = 0, paint = {}, upg = {}, cos = {}, daily = nil, settings = Config.cleanSettings({}) }
end

local function stats(player, p)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		for _, n in { "Credits", "Best drift" } do
			local v = Instance.new("IntValue")
			v.Name = n
			v.Parent = ls
		end
		ls.Parent = player
	end
	ls.Credits.Value = p.credits
	ls["Best drift"].Value = p.best
end

local function load(player)
	local p = newProfile()
	if store then
		local ok, data = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(data) == "table" then
			p.credits = math.max(0, math.floor(tonumber(data.credits) or 0))
			p.best = math.max(0, math.floor(tonumber(data.best) or 0))
			p.laps = math.max(0, math.floor(tonumber(data.laps) or 0))
			if type(data.owned) == "table" then
				-- special cars come only from owning their game pass (checked below), never from saved data
				for id, v in data.owned do if v and Config.car(id).id == id and not Config.car(id).premium then p.owned[id] = true end end
			end
			if type(data.selected) == "string" then p.wantSelected = data.selected end
			if type(data.paint) == "table" then
				for id, v in data.paint do
					if Config.car(id).id == id and type(v) == "number" and v >= 0 and v <= #Config.Paints then p.paint[id] = math.floor(v) end
				end
			end
			p.settings = Config.cleanSettings(data.settings)
			p.total = math.max(0, math.floor(tonumber(data.total) or 0))
			-- upgrades and cosmetics per car, checked against the known keys and ranges
			if type(data.upg) == "table" then
				for id, u in data.upg do
					if Config.car(id).id == id and type(u) == "table" then
						local clean = {}
						for _, up in Config.Upgrades do clean[up.key] = math.clamp(math.floor(tonumber(u[up.key]) or 0), 0, Config.UPGRADE_MAX) end
						p.upg[id] = clean
					end
				end
			end
			if type(data.cos) == "table" then
				for id, c in data.cos do
					if Config.car(id).id == id and type(c) == "table" then
						p.cos[id] = {
							glowOwned = c.glowOwned == true, rimsOwned = c.rimsOwned == true, kit = c.kit == true,
							glow = math.clamp(math.floor(tonumber(c.glow) or 0), 0, #Config.GlowColors),
							rims = math.clamp(math.floor(tonumber(c.rims) or 0), 0, #Config.RimColors),
						}
					end
				end
			end
			if type(data.daily) == "table" and type(data.daily.day) == "number" and type(data.daily.prog) == "table" and type(data.daily.done) == "table" then
				p.daily = { day = data.daily.day, prog = {}, done = {} }
				for k = 1, 3 do
					p.daily.prog[k] = math.max(0, tonumber(data.daily.prog[k]) or 0)
					p.daily.done[k] = data.daily.done[k] == true
				end
			end
		end
	end
	for _, car in Config.Premium do
		if car.pass and car.pass > 0 then
			local ok, has = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, car.pass) end)
			if ok and has then p.owned[car.id] = true end
		end
	end
	if p.wantSelected and p.owned[p.wantSelected] then p.selected = p.wantSelected end
	p.wantSelected = nil
	profiles[player] = p
	stats(player, p)
end

local function save(player)
	local p = profiles[player]
	if p and store then
		dirty[player] = nil
		pcall(function() store:SetAsync("p_" .. player.UserId, p) end)
	end
end

-- today's challenges for this profile (a new set each UTC day)
local function today() return os.time() // 86400 end
local function daily(p)
	local d = today()
	if not p.daily or p.daily.day ~= d then p.daily = { day = d, prog = { 0, 0, 0 }, done = { false, false, false } } end
	return p.daily
end

local function view(p)
	local owned = {}
	for id in p.owned do table.insert(owned, id) end
	local dl = daily(p)
	local list = Config.dailyFor(dl.day)
	local ch = {}
	for k, c in list do ch[k] = { text = c.text, goal = c.goal, reward = c.reward, prog = math.min(dl.prog[k], c.goal), done = dl.done[k] } end
	return { credits = p.credits, owned = owned, selected = p.selected, best = p.best, laps = p.laps, total = p.total, paint = p.paint,
		upg = p.upg, cos = p.cos, daily = ch, settings = p.settings }
end

Players.PlayerAdded:Connect(load)
for _, pl in Players:GetPlayers() do task.spawn(load, pl) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	local p = profiles[player]
	if p and boardDirty[player] then
		pcall(function() if bestStore then bestStore:SetAsync(tostring(player.UserId), p.best) end end)
		pcall(function() if totalStore then totalStore:SetAsync(tostring(player.UserId), p.total) end end)
	end
	boardDirty[player] = nil
	profiles[player], lastBank[player], lastLap[player], publicMode[player], dirty[player] = nil, nil, nil, nil, nil
end)
game:BindToClose(function()
	for _, pl in Players:GetPlayers() do save(pl) end
end)
task.spawn(function()
	while true do
		task.wait(60)
		for pl in dirty do if pl.Parent then save(pl) end end
	end
end)

GetProfile.OnServerInvoke = function(player)
	while not profiles[player] do task.wait(0.1) end
	return view(profiles[player])
end

Buy.OnServerInvoke = function(player, id)
	local p = profiles[player]
	if not p or type(id) ~= "string" then return nil end
	local car = Config.car(id)
	if car.id == id and not car.premium and not p.owned[id] and p.credits >= car.price then
		p.credits -= car.price
		p.owned[id] = true
		p.selected = id
		stats(player, p)
		task.spawn(save, player)
	end
	return view(p)
end

-- special cars: the client asks, Roblox shows its own purchase window with the real Robux price
BuySpecial.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" then return end
	local car = Config.car(id)
	if car.id == id and car.premium and car.pass and car.pass > 0 then
		MarketplaceService:PromptGamePassPurchase(player, car.pass)
	end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	local p = profiles[player]
	if not (p and bought) then return end
	for _, car in Config.Premium do
		if car.pass == passId then
			p.owned[car.id] = true
			p.selected = car.id
			dirty[player] = true
			ProfileChanged:FireClient(player, view(p))
		end
	end
end)

SelectCar.OnServerInvoke = function(player, id)
	local p = profiles[player]
	if p and type(id) == "string" and p.owned[id] then p.selected = id; dirty[player] = true end
	return p and view(p)
end

Paint.OnServerInvoke = function(player, id, idx)
	local p = profiles[player]
	if p and type(id) == "string" and Config.car(id).id == id and type(idx) == "number" and idx >= 0 and idx <= #Config.Paints then
		p.paint[id] = math.floor(idx)
		dirty[player] = true
	end
	return p and view(p)
end

-- garage: upgrades (next level) and cosmetics (unlock once per car, then colours are free)
Tune.OnServerInvoke = function(player, id, action, value)
	local p = profiles[player]
	if not p or type(id) ~= "string" or type(action) ~= "string" or Config.car(id).id ~= id or not p.owned[id] then return p and view(p) end
	local function pay(cost)
		if p.credits < cost then return false end
		p.credits -= cost
		stats(player, p)
		return true
	end
	p.upg[id] = p.upg[id] or {}
	p.cos[id] = p.cos[id] or { glowOwned = false, rimsOwned = false, kit = false, glow = 0, rims = 0 }
	local u, c = p.upg[id], p.cos[id]
	for _, up in Config.Upgrades do
		if action == "up_" .. up.key then
			local l = u[up.key] or 0
			if l < Config.UPGRADE_MAX and pay(up.cost[l + 1]) then u[up.key] = l + 1 end
		end
	end
	if action == "glowOwn" and not c.glowOwned and pay(Config.Cosmetics.glow.cost) then c.glowOwned = true; c.glow = 1 end
	if action == "rimsOwn" and not c.rimsOwned and pay(Config.Cosmetics.rims.cost) then c.rimsOwned = true; c.rims = 1 end
	if action == "kitOwn" and not c.kit and pay(Config.Cosmetics.kit.cost) then c.kit = true end
	if action == "kitOff" then c.kit = false end -- removing the kit is free (buy again to refit)
	if action == "glow" and c.glowOwned and type(value) == "number" then c.glow = math.clamp(math.floor(value), 0, #Config.GlowColors) end
	if action == "rims" and c.rimsOwned and type(value) == "number" then c.rims = math.clamp(math.floor(value), 1, #Config.RimColors) end
	dirty[player] = true
	task.spawn(save, player)
	return view(p)
end

SaveSettings.OnServerEvent:Connect(function(player, s)
	local p = profiles[player]
	if p then p.settings = Config.cleanSettings(s); dirty[player] = true end
end)

Erase.OnServerInvoke = function(player)
	local p = profiles[player]
	if not p then return nil end
	local keep, old = p.settings, p.owned
	p = newProfile()
	p.settings = keep
	-- paid cars stay: erasing progress never takes away something bought with Robux
	for _, car in Config.Premium do if old[car.id] then p.owned[car.id] = true end end
	profiles[player] = p
	stats(player, p)
	task.spawn(save, player)
	return view(p)
end

-- a finished drift: capped, and no faster than a real drift could earn
-- daily challenge progress: kind, and how much to add (or the value reached, for "best of" kinds)
local function progress(player, p, kind, amount)
	local dl = daily(p)
	local list = Config.dailyFor(dl.day)
	local changed = false
	for k, c in list do
		if c.kind == kind and not dl.done[k] then
			if kind == "one" or kind == "combo" then dl.prog[k] = math.max(dl.prog[k], amount) else dl.prog[k] += amount end
			changed = true
			if dl.prog[k] >= c.goal then
				dl.done[k] = true
				p.credits += c.reward
				stats(player, p)
				ProfileChanged:FireClient(player, view(p), "Challenge complete  ·  " .. c.text .. "  ·  +" .. c.reward .. " CR")
			end
		end
	end
	if changed then dirty[player] = true end
end

-- the neon leaderboard gantry over the street just ahead of the city spawn
local updateNeonBoard
do
	-- the car starts facing +X along an east-west street; the gantry spans it half a block ahead
	local sx, sy, sz = city.spawn[1], city.spawn[2], city.spawn[3]
	local gx = sx + 124
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboard"
	folder.Parent = map
	local steel = Color3.fromRGB(44, 46, 52)
	for _, side in { -1, 1 } do
		block(folder, Vector3.new(2.4, 40, 2.4), CFrame.new(gx, sy + 20, sz + side * 27), steel, Enum.Material.Metal).Name = "Pillar"
	end
	block(folder, Vector3.new(2.4, 2, 58), CFrame.new(gx, sy + 39, sz), steel, Enum.Material.Metal)
	local centre = Vector3.new(gx, sy + 27, sz)
	local face = block(folder, Vector3.new(50, 22, 0.8), CFrame.lookAt(centre, centre - Vector3.new(10, 0, 0)), Color3.fromRGB(10, 10, 18), Enum.Material.SmoothPlastic)
	face.Name = "BoardFace"
	face.CanCollide = false
	for _, e in { { 0, 11.2, 50.6, 0.5 }, { 0, -11.2, 50.6, 0.5 }, { 25.2, 0, 0.5, 22.8 }, { -25.2, 0, 0.5, 22.8 } } do
		local n = block(folder, Vector3.new(e[3], e[4], 1), face.CFrame * CFrame.new(e[1], e[2], 0), Color3.fromRGB(255, 126, 182), Enum.Material.Neon)
		n.CanCollide = false
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1000, 440)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = face
	local function label(text, x, y, w, h, size, color, align)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		t.Text, t.TextSize, t.TextColor3 = text, size, color
		t.Font = Enum.Font.GothamBlack
		t.TextXAlignment = align or Enum.TextXAlignment.Left
		t.Parent = gui
		return t
	end
	label("KAIDO LEADERBOARD", 0, 8, 1000, 50, 40, Color3.fromRGB(255, 126, 182), Enum.TextXAlignment.Center)
	label("BEST DRIFT", 40, 64, 440, 36, 26, Color3.fromRGB(255, 201, 77))
	label("TOTAL POINTS", 530, 64, 440, 36, 26, Color3.fromRGB(89, 227, 255))
	local rows = { best = {}, total = {} }
	for k = 1, 8 do
		for col, key in { "best", "total" } do
			local x = col == 1 and 40 or 530
			rows[key][k] = {
				label("", x, 64 + k * 40, 330, 36, 24, Color3.fromRGB(240, 238, 232)),
				label("", x + 300, 64 + k * 40, 130, 36, 24, Color3.fromRGB(240, 238, 232), Enum.TextXAlignment.Right),
			}
		end
	end
	local function commas(n)
		local s2 = tostring(math.floor(n))
		local out = s2:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end
	updateNeonBoard = function(boards)
		for _, key in { "best", "total" } do
			for k = 1, 8 do
				local e = boards[key][k]
				rows[key][k][1].Text = e and (k .. "  " .. e[1]) or ""
				rows[key][k][2].Text = e and commas(e[2]) or ""
			end
		end
	end
	updateNeonBoard({ best = {}, total = {} })
end

-- global leaderboards: best single drift and total points banked

Bank.OnServerEvent:Connect(function(player, points, zone, tandemPts, combo)
	local p = profiles[player]
	if not p or type(points) ~= "number" or points ~= points or points <= 0 then return end
	local now = os.clock()
	local since = now - (lastBank[player] or 0)
	lastBank[player] = now
	points = math.floor(math.min(points, 600000, since * 30000))
	if points <= 0 then return end
	p.credits += points // 10 -- as in the browser game: one credit per ten drift points
	p.best = math.max(p.best, points)
	p.total += points
	stats(player, p)
	dirty[player] = true
	boardDirty[player] = true
	progress(player, p, "one", points)
	progress(player, p, "total", points)
	if zone == "city" then progress(player, p, "city", points) elseif zone == "pass" then progress(player, p, "pass", points) end
	if type(tandemPts) == "number" and tandemPts == tandemPts and tandemPts > 0 then progress(player, p, "tandem", math.min(tandemPts, points)) end
	if type(combo) == "number" and combo == combo then progress(player, p, "combo", math.clamp(combo, 1, 5)) end
end)

-- push changed scores to the leaderboards, then read the top 10 for everyone (every 60 s)
local names = {}
local function nameOf(uid)
	if names[uid] then return names[uid] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
	names[uid] = ok and n or ("Driver " .. uid)
	return names[uid]
end
local function readBoard(store)
	local out = {}
	if not store then return out end
	local ok, pages = pcall(function() return store:GetSortedAsync(false, 10) end)
	if not ok then return out end
	for _, e in pages:GetCurrentPage() do
		local uid = tonumber(e.key)
		if uid then table.insert(out, { nameOf(uid), e.value }) end
	end
	return out
end
local function refreshBoards()
	for pl in boardDirty do
		local p = profiles[pl]
		if p then
			pcall(function() if bestStore then bestStore:SetAsync(tostring(pl.UserId), p.best) end end)
			pcall(function() if totalStore then totalStore:SetAsync(tostring(pl.UserId), p.total) end end)
		end
		boardDirty[pl] = nil
	end
	local boards = { best = readBoard(bestStore), total = readBoard(totalStore) }
	ReplicatedStorage:SetAttribute("Boards", HttpService:JSONEncode(boards))
	if updateNeonBoard then updateNeonBoard(boards) end
end
task.spawn(function()
	task.wait(5)
	while true do
		refreshBoards()
		task.wait(60)
	end
end)

-- a lap: +2,000, no more than one every 3 minutes (the record pace is well over that)
Lap.OnServerEvent:Connect(function(player)
	local p = profiles[player]
	local now = os.clock()
	if p and now - (lastLap[player] or -1e9) > 180 then
		lastLap[player] = now
		p.credits += 2000
		p.laps += 1
		stats(player, p)
		dirty[player] = true
		progress(player, p, "lap", 1)
	end
end)

-- solo players are hidden from the public map and see no one
SetMode.OnServerEvent:Connect(function(player, mode)
	publicMode[player] = mode == "public"
end)

State.OnServerEvent:Connect(function(player, x, y, z, h, carId, paint, drifting)
	if not publicMode[player] then return end
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or type(h) ~= "number" or type(carId) ~= "string" then return end
	if x ~= x or y ~= y or z ~= z or h ~= h then return end
	paint = type(paint) == "number" and math.clamp(math.floor(paint), 0, #Config.Paints) or 0
	for _, other in Players:GetPlayers() do
		if other ~= player and publicMode[other] then
			Others:FireClient(other, player.UserId, x, y, z, h, carId, paint, drifting == true)
		end
	end
end)
