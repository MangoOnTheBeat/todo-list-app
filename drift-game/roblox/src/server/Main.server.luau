-- Kaido Drift (Roblox) server: builds the night mountain pass, keeps everyone's credits and cars
-- (DataStore), checks drift scores, and relays car positions between players on the public map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Track = require(Shared.Track)

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
local SetMode = remote("RemoteEvent", "SetMode")
local Bank = remote("RemoteEvent", "Bank")
local State = remote("UnreliableRemoteEvent", "State")
local Others = remote("UnreliableRemoteEvent", "Others")
remotes.Parent = ReplicatedStorage

-- ===================== lighting: midnight with stars =====================
Lighting.ClockTime = 0
Lighting.Brightness = 1.2
Lighting.Ambient = Color3.fromRGB(40, 44, 70)
Lighting.OutdoorAmbient = Color3.fromRGB(55, 60, 95)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
local atmo = Instance.new("Atmosphere")
atmo.Density, atmo.Offset, atmo.Haze, atmo.Glare = 0.32, 0.1, 1.2, 0
atmo.Color, atmo.Decay = Color3.fromRGB(70, 80, 120), Color3.fromRGB(20, 22, 40)
atmo.Parent = Lighting
local sky = Instance.new("Sky")
sky.StarCount, sky.CelestialBodiesShown, sky.MoonAngularSize = 5000, true, 14
sky.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity, bloom.Size, bloom.Threshold = 0.6, 28, 1.6
bloom.Parent = Lighting

-- ===================== the map =====================
local map = Instance.new("Folder")
map.Name = "KaidoMap"
map.Parent = workspace
local rng = Random.new(1989)
local N, X, Y, Z = Track.N, Track.X, Track.Y, Track.Z
local HALF = Config.ROAD_HALF

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

-- ground: grass terrain over the whole area
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, N do
	minX, maxX = math.min(minX, X[i]), math.max(maxX, X[i])
	minZ, maxZ = math.min(minZ, Z[i]), math.max(maxZ, Z[i])
end
local margin = 700
local terrain = workspace.Terrain
for gx = minX - margin, maxX + margin, 2000 do
	for gz = minZ - margin, maxZ + margin, 2000 do
		terrain:FillBlock(CFrame.new(gx + 1000, -4, gz + 1000), Vector3.new(2000, 8, 2000), Enum.Material.Grass)
	end
end

-- lake: the open spot inside the loop furthest from the road
local function inside(x, z)
	local c = false
	local j = N
	for i = 1, N do
		if ((Z[i] > z) ~= (Z[j] > z)) and (x < (X[j] - X[i]) * (z - Z[i]) / (Z[j] - Z[i]) + X[i]) then c = not c end
		j = i
	end
	return c
end
local function roadDist(x, z)
	local best = math.huge
	for i = 1, N, 2 do best = math.min(best, (X[i] - x) ^ 2 + (Z[i] - z) ^ 2) end
	return math.sqrt(best)
end
local lakeX, lakeZ, lakeD = 0, 0, 0
for x = minX, maxX, 120 do
	for z = minZ, maxZ, 120 do
		if inside(x, z) then
			local d = roadDist(x, z)
			if d > lakeD then lakeX, lakeZ, lakeD = x, z, d end
		end
	end
end
local lakeR = math.clamp(lakeD - 90, 0, 650)
if lakeR > 60 then
	terrain:FillCylinder(CFrame.new(lakeX, -1, lakeZ), 4, lakeR, Enum.Material.Water)
end

-- road, rails, centre line, embankment
local road = Instance.new("Folder")
road.Name = "Road"
road.Parent = map
local asphalt, rail, rock = Color3.fromRGB(46, 47, 52), Color3.fromRGB(170, 172, 176), Color3.fromRGB(92, 84, 74)
for i = 1, N do
	local j = i % N + 1
	local a, b = Vector3.new(X[i], Y[i], Z[i]), Vector3.new(X[j], Y[j], Z[j])
	local mid = (a + b) / 2
	local turn = math.abs(math.atan2(Track.TX[i] * Track.TZ[j] - Track.TZ[i] * Track.TX[j], Track.TX[i] * Track.TX[j] + Track.TZ[i] * Track.TZ[j]))
	local len = (b - a).Magnitude + 1 + HALF * 2 * turn
	local cf = CFrame.lookAt(mid, b)
	local seg = block(road, Vector3.new(HALF * 2, 1, len), cf * CFrame.new(0, -0.5, 0), asphalt, Enum.Material.Asphalt)
	seg.Name = "Road"
	for _, side in { -1, 1 } do
		local r = block(road, Vector3.new(0.6, 2.4, len), cf * CFrame.new(side * (HALF + 0.9), 1.0, 0), rail, Enum.Material.DiamondPlate)
		r.Name = "Rail"
		local kerb = block(road, Vector3.new(1.2, 0.2, len), cf * CFrame.new(side * (HALF - 0.6), 0.05, 0), (i // 2) % 2 == 0 and Color3.fromRGB(210, 40, 40) or Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		kerb.CanCollide = false
	end
	if i % 3 == 0 then
		local line = block(road, Vector3.new(0.5, 0.1, Config.SEG * 1.4), cf * CFrame.new(0, 0.02, 0), Color3.fromRGB(240, 236, 220), Enum.Material.SmoothPlastic)
		line.CanCollide = false
	end
	if i % 2 == 0 and mid.Y > 2 then
		local flat = CFrame.lookAt(Vector3.new(mid.X, mid.Y / 2 - 1, mid.Z), Vector3.new(b.X, mid.Y / 2 - 1, b.Z))
		block(road, Vector3.new(HALF * 2 + 8, mid.Y, len * 2 + 2), flat, rock, Enum.Material.Slate)
	end
end

-- street lamps
local lamps = Instance.new("Folder")
lamps.Name = "Lamps"
lamps.Parent = map
for i = 1, N, 14 do
	local side = (i // 14) % 2 == 0 and 1 or -1
	local base = Vector3.new(X[i] + Track.RX[i] * side * (HALF + 3), Y[i], Z[i] + Track.RZ[i] * side * (HALF + 3))
	local inward = Vector3.new(-Track.RX[i] * side, 0, -Track.RZ[i] * side)
	block(lamps, Vector3.new(0.8, 18, 0.8), CFrame.new(base + Vector3.new(0, 9, 0)), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
	block(lamps, Vector3.new(0.5, 0.5, 6), CFrame.lookAt(base + Vector3.new(0, 18, 0) + inward * 3, base + Vector3.new(0, 18, 0) + inward * 6), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
	local head = block(lamps, Vector3.new(2.2, 0.5, 1.2), CFrame.new(base + Vector3.new(0, 17.6, 0) + inward * 5.5), Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 190, 120), 42, 2.2, false
	light.Parent = head
end

-- cedar and maple trees on the hillsides
local trees = Instance.new("Folder")
trees.Name = "Trees"
trees.Parent = map
local placed = 0
for _ = 1, 4000 do
	if placed >= 900 then break end
	local i = rng:NextInteger(1, N)
	local off = (HALF + 14 + rng:NextNumber() ^ 1.4 * 320) * (rng:NextNumber() < 0.5 and -1 or 1)
	local x, z = X[i] + Track.RX[i] * off, Z[i] + Track.RZ[i] * off
	if roadDist(x, z) > HALF + 12 and (lakeR <= 60 or (x - lakeX) ^ 2 + (z - lakeZ) ^ 2 > (lakeR + 20) ^ 2) then
		local s = 0.8 + rng:NextNumber() * 0.9
		local ground = Vector3.new(x, 0, z)
		block(trees, Vector3.new(14 * s, 1.6 * s, 1.6 * s), CFrame.new(ground + Vector3.new(0, 7 * s, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 50, 38), Enum.Material.Wood, Enum.PartType.Cylinder)
		local maple = rng:NextNumber() < 0.25
		local leaf = maple and (rng:NextNumber() < 0.5 and Color3.fromRGB(176, 52, 30) or Color3.fromRGB(214, 140, 40)) or Color3.fromRGB(28 + rng:NextInteger(0, 16), 66 + rng:NextInteger(0, 20), 38)
		for k = 0, 2 do
			local r = (9 - k * 2.4) * s
			block(trees, Vector3.new(r * 2, r * 1.5, r * 2), CFrame.new(ground + Vector3.new(0, (12 + k * 6) * s, 0)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
		end
		placed += 1
	end
end

-- Kojiri village by the start: wooden houses with lantern-lit doors, on platforms at road height
local village = Instance.new("Folder")
village.Name = "Village"
village.Parent = map
local wood, roofC = Color3.fromRGB(96, 66, 46), Color3.fromRGB(40, 42, 48)
for n = 0, 9 do
	local i = (n * 6) % N + 1
	local side = n % 2 == 0 and 1 or -1
	local dist = HALF + 26 + (n % 3) * 6
	local c = Vector3.new(X[i] + Track.RX[i] * side * dist, Y[i], Z[i] + Track.RZ[i] * side * dist)
	local face = CFrame.lookAt(c, c - Vector3.new(Track.RX[i] * side, 0, Track.RZ[i] * side))
	block(village, Vector3.new(30, Y[i] + 2, 30), CFrame.new(c - Vector3.new(0, (Y[i] + 2) / 2, 0)), Color3.fromRGB(80, 74, 66), Enum.Material.Cobblestone)
	block(village, Vector3.new(22, 12, 16), face * CFrame.new(0, 6, 0), wood, Enum.Material.WoodPlanks)
	local r1 = Instance.new("WedgePart")
	r1.Anchored, r1.Size, r1.Color, r1.Material = true, Vector3.new(24, 5, 9), roofC, Enum.Material.Slate
	r1.CFrame = face * CFrame.new(0, 14.5, -4.5) -- tall edge toward the ridge
	r1.Parent = village
	local r2 = r1:Clone()
	r2.CFrame = face * CFrame.new(0, 14.5, 4.5) * CFrame.Angles(0, math.pi, 0)
	r2.Parent = village
	for w = -1, 1, 2 do
		block(village, Vector3.new(3, 3, 0.3), face * CFrame.new(w * 6, 7, -8.05), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	end
	local lantern = block(village, Vector3.new(1.6, 2.2, 1.6), face * CFrame.new(0, 9, -9), Color3.fromRGB(240, 60, 40), Enum.Material.Neon, Enum.PartType.Ball)
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = Color3.fromRGB(255, 140, 90), 22, 2
	pl.Parent = lantern
end

-- the start gate
do
	local i = 1
	local c = Vector3.new(X[i], Y[i], Z[i])
	local face = CFrame.lookAt(c, c + Vector3.new(Track.TX[i], 0, Track.TZ[i]))
	local red = Color3.fromRGB(196, 30, 34)
	for _, s in { -1, 1 } do block(map, Vector3.new(1.6, 22, 1.6), face * CFrame.new(s * (HALF + 3), 11, 0), red, Enum.Material.Wood) end
	block(map, Vector3.new(HALF * 2 + 14, 1.6, 2.4), face * CFrame.new(0, 21, 0), red, Enum.Material.Wood)
	block(map, Vector3.new(HALF * 2 + 10, 1.2, 1.8), face * CFrame.new(0, 18.5, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Wood)
end

map:SetAttribute("Ready", true)

-- ===================== player data =====================
local store
pcall(function() store = DataStoreService:GetDataStore("KaidoDrift_v1") end)
local profiles, lastBank, publicMode = {}, {}, {}

local function defaultProfile()
	return { credits = 0, owned = { ps13 = true }, selected = "ps13", best = 0 }
end

local function stats(player, p)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local c = Instance.new("IntValue")
		c.Name = "Credits"
		c.Parent = ls
		local b = Instance.new("IntValue")
		b.Name = "Best drift"
		b.Parent = ls
		ls.Parent = player
	end
	ls.Credits.Value = p.credits
	ls["Best drift"].Value = p.best
end

local function load(player)
	local p = defaultProfile()
	if store then
		local ok, data = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(data) == "table" then
			p.credits = tonumber(data.credits) or 0
			p.best = tonumber(data.best) or 0
			if type(data.owned) == "table" then
				for id, v in data.owned do
					if v and Config.car(id).id == id then p.owned[id] = true end
				end
			end
			if type(data.selected) == "string" and p.owned[data.selected] then p.selected = data.selected end
		end
	end
	profiles[player] = p
	stats(player, p)
end

local function save(player)
	local p = profiles[player]
	if p and store then
		pcall(function() store:SetAsync("p_" .. player.UserId, p) end)
	end
end

local function view(p)
	local owned = {}
	for id in p.owned do table.insert(owned, id) end
	return { credits = p.credits, owned = owned, selected = p.selected, best = p.best }
end

Players.PlayerAdded:Connect(load)
for _, pl in Players:GetPlayers() do task.spawn(load, pl) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	profiles[player], lastBank[player], publicMode[player] = nil, nil, nil
end)
game:BindToClose(function()
	for _, pl in Players:GetPlayers() do save(pl) end
end)
task.spawn(function()
	while true do
		task.wait(90)
		for _, pl in Players:GetPlayers() do save(pl) end
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
	if p and type(id) == "string" and p.owned[id] then p.selected = id end
	return p and view(p)
end

-- a finished drift: capped, and no faster than a real drift could earn
Bank.OnServerEvent:Connect(function(player, points)
	local p = profiles[player]
	if not p or type(points) ~= "number" or points ~= points or points <= 0 then return end
	local now = os.clock()
	local since = now - (lastBank[player] or 0)
	lastBank[player] = now
	points = math.floor(math.min(points, 60000, since * 4000))
	if points <= 0 then return end
	p.credits += points
	p.best = math.max(p.best, points)
	stats(player, p)
end)

-- solo players are hidden from the public map and see no one
SetMode.OnServerEvent:Connect(function(player, mode)
	publicMode[player] = mode == "public"
end)

State.OnServerEvent:Connect(function(player, x, y, z, h, carId, drifting)
	if not publicMode[player] then return end
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or type(h) ~= "number" or type(carId) ~= "string" then return end
	if x ~= x or y ~= y or z ~= z or h ~= h then return end
	for _, other in Players:GetPlayers() do
		if other ~= player and publicMode[other] then
			Others:FireClient(other, player.UserId, x, y, z, h, carId, drifting == true)
		end
	end
end)
