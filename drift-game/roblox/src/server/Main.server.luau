-- Kaido Drift (Roblox) server: builds the Hakone pass (real course and elevation, hills, Lake Ashi,
-- Kojiri village, Mt. Fuji on the horizon), keeps every player's progress and settings on Roblox's
-- servers (DataStore), checks drift scores and laps, and relays cars between players on the public map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
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
	block(road, Vector3.new(HALF * 2, 1, len), cf * CFrame.new(0, -0.5, 0), asphalt, Enum.Material.Asphalt).Name = "Road"
	for _, side in { -1, 1 } do
		if side == junctionSide and (nearJunction(i) or nearJunction(jj)) then continue end
		local ra = a + Vector3.new(Track.RX[i], 0, Track.RZ[i]) * side * (HALF + 0.9)
		local rb = b + Vector3.new(Track.RX[jj], 0, Track.RZ[jj]) * side * (HALF + 0.9)
		local rcf = CFrame.lookAt((ra + rb) / 2, rb)
		block(rails, Vector3.new(0.5, 1.2, (rb - ra).Magnitude + 0.8), rcf * CFrame.new(0, 1.6, 0), rail, Enum.Material.DiamondPlate).Name = "Rail"
		block(rails, Vector3.new(0.4, 2.2, 0.4), CFrame.new(ra + Vector3.new(0, 1.1, 0)), Color3.fromRGB(120, 122, 126), Enum.Material.Metal).Name = "Post"
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
local wood, roofC = Color3.fromRGB(98, 68, 48), Color3.fromRGB(42, 44, 50)
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
			block(village, Vector3.new(w, h, d), face * CFrame.new(0, h / 2, 0), wood, Enum.Material.WoodPlanks)
			local r1 = Instance.new("WedgePart")
			r1.Anchored, r1.Size, r1.Color, r1.Material = true, Vector3.new(w + 2, 5, d / 2 + 1), roofC, Enum.Material.Slate
			r1.CFrame = face * CFrame.new(0, h + 2.5, -(d / 4 + 0.5))
			r1.Parent = village
			local r2 = r1:Clone()
			r2.CFrame = face * CFrame.new(0, h + 2.5, d / 4 + 0.5) * CFrame.Angles(0, math.pi, 0)
			r2.Parent = village
			for wx = -1, 1, 2 do
				block(village, Vector3.new(3.2, 3, 0.3), face * CFrame.new(wx * w / 4, h * 0.55, -d / 2 - 0.05), Color3.fromRGB(255, 202, 128), Enum.Material.Neon).Name = "Window"
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

local function newProfile()
	return { credits = 0, owned = { ps13 = true }, selected = "ps13", best = 0, laps = 0, paint = {}, settings = Config.cleanSettings({}) }
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
				for id, v in data.owned do if v and Config.car(id).id == id then p.owned[id] = true end end
			end
			if type(data.selected) == "string" and p.owned[data.selected] then p.selected = data.selected end
			if type(data.paint) == "table" then
				for id, v in data.paint do
					if Config.car(id).id == id and type(v) == "number" and v >= 0 and v <= #Config.Paints then p.paint[id] = math.floor(v) end
				end
			end
			p.settings = Config.cleanSettings(data.settings)
		end
	end
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

local function view(p)
	local owned = {}
	for id in p.owned do table.insert(owned, id) end
	return { credits = p.credits, owned = owned, selected = p.selected, best = p.best, laps = p.laps, paint = p.paint, settings = p.settings }
end

Players.PlayerAdded:Connect(load)
for _, pl in Players:GetPlayers() do task.spawn(load, pl) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
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
	if car.id == id and not p.owned[id] and p.credits >= car.price then
		p.credits -= car.price
		p.owned[id] = true
		p.selected = id
		stats(player, p)
		task.spawn(save, player)
	end
	return view(p)
end

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

SaveSettings.OnServerEvent:Connect(function(player, s)
	local p = profiles[player]
	if p then p.settings = Config.cleanSettings(s); dirty[player] = true end
end)

Erase.OnServerInvoke = function(player)
	local p = profiles[player]
	if not p then return nil end
	local keep = p.settings
	p = newProfile()
	p.settings = keep
	profiles[player] = p
	stats(player, p)
	task.spawn(save, player)
	return view(p)
end

-- a finished drift: capped, and no faster than a real drift could earn
Bank.OnServerEvent:Connect(function(player, points)
	local p = profiles[player]
	if not p or type(points) ~= "number" or points ~= points or points <= 0 then return end
	local now = os.clock()
	local since = now - (lastBank[player] or 0)
	lastBank[player] = now
	points = math.floor(math.min(points, 600000, since * 30000))
	if points <= 0 then return end
	p.credits += points // 10 -- as in the browser game: one credit per ten drift points
	p.best = math.max(p.best, points)
	stats(player, p)
	dirty[player] = true
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
