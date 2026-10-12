--!strict
-- Builds the midnight mountain pass at server start from the shared Track centreline:
-- terrain hillsides + lake + Mt. Fuji, asphalt road, guardrails, street lamps, cedar forest,
-- and the lantern-lit village at the start line. Everything lives in workspace.KaidoMap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Track = require(Shared:WaitForChild("Track"))
local Config = require(Shared:WaitForChild("Config"))

local MapBuilder = {}

local terrain = Workspace.Terrain
local W = Track.WIDTH
local rng = Random.new(1989)

local ROAD_COLOR = Color3.fromRGB(46, 46, 52)
local RAIL_COLOR = Color3.fromRGB(196, 198, 204)
local POST_COLOR = Color3.fromRGB(110, 112, 118)
local WOOD = Color3.fromRGB(96, 62, 40)
local DARK_WOOD = Color3.fromRGB(58, 38, 26)
local ROOF = Color3.fromRGB(44, 46, 54)
local SHOJI = Color3.fromRGB(255, 214, 150)
local LANTERN = Color3.fromRGB(226, 70, 40)
local TORII = Color3.fromRGB(196, 38, 28)

local budget = 0
local function breathe()
	budget += 1
	if budget % 200 == 0 then
		task.wait()
	end
end

local function newPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = collide == true
	p.CanTouch = collide == true
	p.CanQuery = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	breathe()
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function v3(d: Track.TrackData, i: number): Vector3
	return Vector3.new(d.x[i], d.y[i], d.z[i])
end

local function right(d: Track.TrackData, i: number): Vector3
	return Vector3.new(-d.tz[i], 0, d.tx[i])
end

-- ---------------------------------------------------------------- terrain
local function buildTerrain(d: Track.TrackData)
	terrain:Clear()
	-- base valley floor (split so each fill stays modest)
	for _, b in { { -1600, 500 }, { 500, 2600 } } do
		for _, zz in { { -2600, -750 }, { -750, 1100 } } do
			local cx, sx = (b[1] + b[2]) / 2, b[2] - b[1]
			local cz, sz = (zz[1] + zz[2]) / 2, zz[2] - zz[1]
			terrain:FillBlock(CFrame.new(cx, -12, cz), Vector3.new(sx, 24, sz), Enum.Material.Grass)
			task.wait()
		end
	end
	-- Lake Ashi stand-in, west of the lakeside road
	terrain:FillBlock(CFrame.new(-150, -2, -400), Vector3.new(70, 6, 2300), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(-860, -8, -400), Vector3.new(1420, 14, 2300), Enum.Material.Water)
	task.wait()

	-- Distant Mt. Fuji across the lake (stacked cylinders, snow cap)
	local fuji = Vector3.new(-1500, -10, -3400)
	for k = 0, 13 do
		local r = 760 * (1 - k / 14) ^ 1.25 + 30
		local mat = k >= 10 and Enum.Material.Snow or Enum.Material.Rock
		terrain:FillCylinder(CFrame.new(fuji + Vector3.new(0, k * 42 + 21, 0)), 42, r, mat)
		task.wait()
	end

	-- Rolling hills, kept clear of the road surface
	local function clearOfRoad(c: Vector3, r: number): boolean
		for i = 1, d.n, 2 do
			local dx, dz = d.x[i] - c.X, d.z[i] - c.Z
			local hd = math.sqrt(dx * dx + dz * dz)
			local reach = math.max(hd - (W / 2 + 14), 0)
			if reach < r then
				local surf = c.Y + math.sqrt(r * r - reach * reach)
				if surf > d.y[i] - 8 then
					return false
				end
			end
		end
		return true
	end
	local placed = 0
	for _ = 1, 260 do
		local c = Vector3.new(rng:NextNumber(-100, 2400), rng:NextNumber(-260, -60), rng:NextNumber(-2500, 1000))
		local r = rng:NextNumber(140, 320)
		local inLake = c.X < -60
		if not inLake and clearOfRoad(c, r) then
			terrain:FillBall(c, r, if rng:NextNumber() < 0.3 then Enum.Material.Ground else Enum.Material.Grass)
			placed += 1
			task.wait()
		end
		if placed >= 70 then
			break
		end
	end

	-- Embankments / hillsides under the road, stepped so they read as slopes
	for i = 1, d.n do
		local j = i % d.n + 1
		local a, b = v3(d, i), v3(d, j)
		local mid = (a + b) / 2
		local yaw = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(b.X, 0, b.Z)).Rotation
		local segLen = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude + 6
		local top = math.min(a.Y, b.Y) - 2.5
		for k = 0, 4 do
			local t = top - k * 12
			if t <= 0.5 then
				break
			end
			local width = W + 10 + k * 44
			local h = t + 12
			terrain:FillBlock(CFrame.new(mid.X, t - h / 2, mid.Z) * yaw, Vector3.new(width, h, segLen + k * 6), if k == 0 then Enum.Material.Ground else Enum.Material.Grass)
		end
		if i % 20 == 0 then
			task.wait()
		end
	end
	-- carve the road corridor so no terrain sits on the asphalt
	for i = 1, d.n do
		local j = i % d.n + 1
		local a, b = v3(d, i), v3(d, j)
		local mid = (a + b) / 2
		local yaw = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(b.X, 0, b.Z)).Rotation
		local segLen = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude + 4
		local bottom = math.max(a.Y, b.Y) + 0.5
		terrain:FillBlock(CFrame.new(mid.X, bottom + 20, mid.Z) * yaw, Vector3.new(W + 8, 40, segLen), Enum.Material.Air)
		if i % 25 == 0 then
			task.wait()
		end
	end
end

-- ---------------------------------------------------------------- road + rails + lamps
local function buildRoad(d: Track.TrackData, map: Folder)
	local road = folder(map, "Road")
	local marks = folder(map, "Markings")
	local rails = folder(map, "Rails")
	local lamps = folder(map, "Lamps")

	for i = 1, d.n do
		local j = i % d.n + 1
		local a, b = v3(d, i), v3(d, j)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local stretch = len * (1 + (W / 2) * math.abs(d.curv[i])) + 1.5
		local cf = CFrame.lookAt(mid, b)
		local p = newPart(road, Vector3.new(W, 2, stretch), cf * CFrame.new(0, -1, 0), ROAD_COLOR, Enum.Material.Asphalt, true)
		p.Name = "Road"
		if i % 2 == 0 then
			local m = newPart(marks, Vector3.new(0.45, 0.06, 4.5), cf * CFrame.new(0, 0.03, 0), Color3.fromRGB(232, 226, 205))
			m.CastShadow = false
		end
		-- edge lines
		for _, s in { -1, 1 } do
			local m = newPart(marks, Vector3.new(0.35, 0.05, stretch), cf * CFrame.new(s * (W / 2 - 1.2), 0.025, 0), Color3.fromRGB(215, 215, 210))
			m.CastShadow = false
		end
	end
	task.wait()

	-- guardrails both sides, built from offset polylines so curves stay closed
	local railOff = W / 2 + 1.5
	for _, s in { -1, 1 } do
		for i = 1, d.n, 2 do
			local j = (i + 1) % d.n + 1
			local a = v3(d, i) + right(d, i) * s * railOff
			local b = v3(d, j) + right(d, j) * s * railOff
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt(mid, b)
			local r = newPart(rails, Vector3.new(0.5, 1.2, len + 0.6), cf * CFrame.new(0, 2.3, 0), RAIL_COLOR, Enum.Material.DiamondPlate, true)
			r.Name = "Rail"
			r.Reflectance = 0.15
			local post = newPart(rails, Vector3.new(0.45, 2.8, 0.45), CFrame.new(a + Vector3.new(0, 1.4, 0)) * cf.Rotation, POST_COLOR, Enum.Material.Metal, true)
			post.Name = "Post"
		end
	end
	task.wait()

	-- street lamps, alternating sides every ~110 studs
	local side = 1
	for i = 1, d.n, 11 do
		local base = v3(d, i) + right(d, i) * side * (W / 2 + 3.5)
		local inward = -right(d, i) * side
		local pole = newPart(lamps, Vector3.new(20, 0.8, 0.8), CFrame.new(base + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 72, 78), Enum.Material.Metal, true)
		pole.Shape = Enum.PartType.Cylinder
		pole.Name = "Pole"
		local armEnd = base + inward * 6 + Vector3.new(0, 19.6, 0)
		local armMid = (base + Vector3.new(0, 19.6, 0) + armEnd) / 2
		newPart(lamps, Vector3.new(0.5, 0.5, 6.4), CFrame.lookAt(armMid, armEnd), Color3.fromRGB(70, 72, 78), Enum.Material.Metal)
		local head = newPart(lamps, Vector3.new(2.4, 0.5, 1.4), CFrame.lookAt(armEnd - Vector3.new(0, 0.4, 0), armEnd - Vector3.new(0, 0.4, 0) + inward), Config.COLORS.lamp, Enum.Material.Neon)
		head.Name = "LampHead"
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 120
		light.Range = 52
		light.Brightness = 2.4
		light.Color = Config.COLORS.lamp
		light.Shadows = false
		light.Parent = head
		side = -side
	end

	-- start line
	local s0 = CFrame.lookAt(v3(d, 1), v3(d, 2))
	local line = newPart(marks, Vector3.new(W - 2, 0.07, 2.2), s0 * CFrame.new(0, 0.04, 0), Color3.fromRGB(240, 240, 240))
	line.Name = "StartLine"
	for k = 0, 7 do
		newPart(marks, Vector3.new((W - 2) / 16, 0.08, 1.1), s0 * CFrame.new(-(W - 2) / 2 + (k * 2 + 0.5) * (W - 2) / 16, 0.045, -0.55), Color3.fromRGB(20, 20, 20))
		newPart(marks, Vector3.new((W - 2) / 16, 0.08, 1.1), s0 * CFrame.new(-(W - 2) / 2 + (k * 2 + 1.5) * (W - 2) / 16, 0.045, 0.55), Color3.fromRGB(20, 20, 20))
	end
end

-- ---------------------------------------------------------------- village
local function lantern(parent: Instance, pos: Vector3, size: number?)
	local s = size or 1.8
	local p = newPart(parent, Vector3.new(s, s, s), CFrame.new(pos), LANTERN, Enum.Material.Neon)
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.08
	p.Name = "Lantern"
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
	mesh.Parent = p
	newPart(parent, Vector3.new(s * 0.75, 0.2, s * 0.75), CFrame.new(pos + Vector3.new(0, s * 0.6, 0)), Color3.fromRGB(20, 20, 20))
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 150, 80)
	l.Range = 18
	l.Brightness = 1.3
	l.Shadows = false
	l.Parent = p
end

local function house(parent: Instance, cx: number, cz: number, w: number, dpt: number, h: number, ground: number)
	local m = Instance.new("Model")
	m.Name = "Machiya"
	m.Parent = parent
	-- facing -X (the road): width along Z, depth along X
	newPart(m, Vector3.new(dpt + 1, 1.2, w + 1), CFrame.new(cx, ground + 0.6, cz), Color3.fromRGB(90, 90, 92), Enum.Material.Slate, true)
	newPart(m, Vector3.new(dpt, h, w), CFrame.new(cx, ground + 1.2 + h / 2, cz), WOOD, Enum.Material.WoodPlanks, true)
	-- dark timber frame posts
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			newPart(m, Vector3.new(0.8, h, 0.8), CFrame.new(cx + sx * (dpt / 2), ground + 1.2 + h / 2, cz + sz * (w / 2)), DARK_WOOD, Enum.Material.Wood)
		end
	end
	-- glowing shoji panels + door on the road side
	local front = cx - dpt / 2 - 0.05
	for k = -1, 1 do
		local panel = newPart(m, Vector3.new(0.2, h * 0.4, w * 0.22), CFrame.new(front, ground + 1.2 + h * 0.55, cz + k * w * 0.3), SHOJI, Enum.Material.Neon)
		panel.Transparency = 0.25
	end
	newPart(m, Vector3.new(0.3, h * 0.05, w * 1.02), CFrame.new(front - 0.1, ground + 1.2 + h * 0.78, cz), DARK_WOOD, Enum.Material.Wood)
	-- noren curtain over the door
	newPart(m, Vector3.new(0.15, 2.2, w * 0.25), CFrame.new(front - 0.3, ground + 1.2 + h * 0.7, cz), Color3.fromRGB(34, 50, 98), Enum.Material.Fabric)
	-- gable roof (ridge along Z) with deep eaves
	local a = math.rad(28)
	local half = dpt / 2 + 2.5
	local slabW = half / math.cos(a)
	local rise = math.tan(a) * half
	for _, sx in { -1, 1 } do
		newPart(m, Vector3.new(slabW, 0.7, w + 4), CFrame.new(cx + sx * half / 2, ground + 1.2 + h + rise / 2, cz) * CFrame.Angles(0, 0, -sx * a), ROOF, Enum.Material.Slate, true)
	end
	newPart(m, Vector3.new(1, 1, w + 4.4), CFrame.new(cx, ground + 1.2 + h + rise, cz), Color3.fromRGB(30, 30, 36), Enum.Material.Slate)
	lantern(m, Vector3.new(front - 1.4, ground + 1.2 + h * 0.62, cz - w * 0.32))
	lantern(m, Vector3.new(front - 1.4, ground + 1.2 + h * 0.62, cz + w * 0.32))
end

local function buildVillage(d: Track.TrackData, map: Folder): Vector3
	local village = folder(map, "Village")
	local ground = 3
	terrain:FillBlock(CFrame.new(118, ground - 6, 0), Vector3.new(200, 12, 330), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(118, ground - 0.5, 0), Vector3.new(200, 1, 330), Enum.Material.Cobblestone)
	terrain:FillBlock(CFrame.new(118, ground + 20, 0), Vector3.new(200, 40, 330), Enum.Material.Air)

	for _, h in {
		{ 62, -122, 22, 18, 12 }, { 62, -80, 20, 16, 11 }, { 62, 80, 20, 16, 11 }, { 62, 122, 22, 18, 12 },
		{ 160, -112, 26, 20, 14 }, { 160, -55, 20, 18, 12 }, { 160, 55, 22, 18, 12 }, { 160, 112, 26, 20, 14 },
	} do
		house(village, h[1], h[2], h[3], h[4], h[5], ground)
	end

	-- lantern posts along the village road edge
	for z = -125, 125, 25 do
		newPart(village, Vector3.new(0.6, 10, 0.6), CFrame.new(26, ground + 5, z), DARK_WOOD, Enum.Material.Wood, true)
		newPart(village, Vector3.new(3, 0.4, 0.4), CFrame.new(24.8, ground + 9.8, z), DARK_WOOD, Enum.Material.Wood)
		lantern(village, Vector3.new(23.6, ground + 8.2, z), 1.6)
	end

	-- vending machines, the true light source of rural Japan
	for k, col in { Color3.fromRGB(220, 230, 255), Color3.fromRGB(255, 240, 220) } do
		local x = 78 + (k - 1) * 3.6
		newPart(village, Vector3.new(3.2, 7, 2.8), CFrame.new(x, ground + 3.5, -38), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, true)
		local face = newPart(village, Vector3.new(2.6, 4.4, 0.1), CFrame.new(x, ground + 4.2, -36.55), col, Enum.Material.Neon)
		local l = Instance.new("SurfaceLight")
		l.Face = Enum.NormalId.Back
		l.Range = 14
		l.Brightness = 1.5
		l.Color = col
		l.Parent = face
	end

	-- torii gate over the start line
	local s0 = CFrame.lookAt(v3(d, 1), v3(d, 2))
	local gate = s0 * CFrame.new(0, 0, -30)
	for _, sx in { -1, 1 } do
		local pillar = newPart(village, Vector3.new(26, 1.8, 1.8), gate * CFrame.new(sx * (W / 2 + 4), 13, 0) * CFrame.Angles(0, 0, math.pi / 2), TORII, Enum.Material.SmoothPlastic, true)
		pillar.Shape = Enum.PartType.Cylinder
		newPart(village, Vector3.new(2.6, 1.4, 2.6), gate * CFrame.new(sx * (W / 2 + 4), 0.7, 0), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, true)
	end
	newPart(village, Vector3.new(W + 18, 2, 3), gate * CFrame.new(0, 27, 0), TORII)
	newPart(village, Vector3.new(W + 22, 0.8, 3.6), gate * CFrame.new(0, 28.3, 0), Color3.fromRGB(25, 25, 25))
	newPart(village, Vector3.new(W + 10, 1.4, 1.6), gate * CFrame.new(0, 22.5, 0), TORII)
	newPart(village, Vector3.new(1.4, 4.5, 1.4), gate * CFrame.new(0, 24.8, 0), TORII)
	-- string of lanterns under the gate
	for k = -3, 3 do
		lantern(village, (gate * CFrame.new(k * 4.2, 20.4, 0)).Position, 1.5)
	end

	-- leaderboard board facing the road/plaza
	local boardPos = Vector3.new(132, ground + 9, 0)
	local board = newPart(village, Vector3.new(22, 13, 1), CFrame.lookAt(boardPos, boardPos + Vector3.new(-1, 0, 0)), DARK_WOOD, Enum.Material.Wood, true)
	board.Name = "LeaderboardBoard"
	for _, sz in { -1, 1 } do
		newPart(village, Vector3.new(1, 15, 1), CFrame.new(boardPos + Vector3.new(0.8, -1.5, sz * 10.5)), DARK_WOOD, Enum.Material.Wood, true)
	end

	-- spawn point in the plaza
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "VillageSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(Vector3.new(104, ground + 0.5, 0), Vector3.new(0, ground + 0.5, 0))
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(70, 70, 74)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = village
	return boardPos
end

-- ---------------------------------------------------------------- forest
local function cedarTemplate(): Model
	local m = Instance.new("Model")
	m.Name = "Cedar"
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(30, 1.4, 1.4)
	trunk.CFrame = CFrame.new(0, 15, 0) * CFrame.Angles(0, 0, math.pi / 2)
	trunk.Color = Color3.fromRGB(70, 44, 30)
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.Parent = m
	local green = Color3.fromRGB(26, 52, 34)
	for k, s in { { 10, 16, 13 }, { 8, 13, 21 }, { 5.5, 10, 28 }, { 3, 6, 33 } } do
		local f = Instance.new("Part")
		f.Name = "Foliage" .. k
		f.Size = Vector3.new(s[1], s[2], s[1])
		f.CFrame = CFrame.new(0, s[3], 0)
		f.Color = green:Lerp(Color3.fromRGB(16, 36, 24), k / 5)
		f.Material = Enum.Material.Grass
		f.Anchored = true
		f.CanCollide = false
		f.CanQuery = false
		f.CanTouch = false
		f.CastShadow = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = f
		f.Parent = m
	end
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

local function buildForest(d: Track.TrackData, map: Folder)
	local trees = folder(map, "Trees")
	local template = cedarTemplate()
	-- spatial hash of road points for clearance checks
	local cell = 40
	local grid: { [number]: { number } } = {}
	local function key(x: number, z: number): number
		return math.floor(x / cell) * 100000 + math.floor(z / cell)
	end
	for i = 1, d.n do
		local k = key(d.x[i], d.z[i])
		grid[k] = grid[k] or {}
		table.insert(grid[k], i)
	end
	local function clear(x: number, z: number, r: number): boolean
		local cx, cz = math.floor(x / cell), math.floor(z / cell)
		for gx = cx - 1, cx + 1 do
			for gz = cz - 1, cz + 1 do
				local list = grid[gx * 100000 + gz]
				if list then
					for _, i in list do
						if (d.x[i] - x) ^ 2 + (d.z[i] - z) ^ 2 < r * r then
							return false
						end
					end
				end
			end
		end
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }

	local count = 0
	for i = 1, d.n, 2 do
		for _, s in { -1, 1 } do
			if rng:NextNumber() < 0.75 then
				local off = W / 2 + rng:NextNumber(16, 170)
				local p = v3(d, i) + right(d, i) * s * off + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
				local inVillage = p.X > 15 and p.X < 225 and p.Z > -170 and p.Z < 175
				local inLake = p.X < -110
				if not inVillage and not inLake and clear(p.X, p.Z, W / 2 + 12) then
					local hit = Workspace:Raycast(Vector3.new(p.X, 600, p.Z), Vector3.new(0, -800, 0), params)
					if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.6 then
						local t = template:Clone()
						t:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
						t:ScaleTo(rng:NextNumber(0.75, 1.35))
						t.Parent = trees
						count += 1
						breathe()
					end
				end
			end
		end
	end
	-- a darker band of forest further out for the skyline
	for _ = 1, 500 do
		local p = Vector3.new(rng:NextNumber(-100, 2300), 0, rng:NextNumber(-2300, 800))
		if p.X > 15 and p.X < 225 and p.Z > -170 and p.Z < 175 then
			continue
		end
		if clear(p.X, p.Z, W / 2 + 60) then
			local hit = Workspace:Raycast(Vector3.new(p.X, 600, p.Z), Vector3.new(0, -800, 0), params)
			if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.6 then
				local t = template:Clone()
				t:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				t:ScaleTo(rng:NextNumber(0.9, 1.6))
				t.Parent = trees
				count += 1
				breathe()
			end
		end
	end
	template:Destroy()
	return count
end

-- ---------------------------------------------------------------- entry
export type MapInfo = { boardPos: Vector3, trees: number, length: number }

function MapBuilder.build(): MapInfo
	local old = Workspace:FindFirstChild("KaidoMap")
	if old then
		old:Destroy()
	end
	local t0 = os.clock()
	local d = Track.build()
	local map = folder(Workspace, "KaidoMap")
	buildTerrain(d)
	buildRoad(d, map)
	local boardPos = buildVillage(d, map)
	local trees = buildForest(d, map)
	print(string.format("[Kaido] map built in %.1fs: %d road segments, %.0f studs (%.2f km), %d trees",
		os.clock() - t0, d.n, d.length, d.length * Config.METERS_PER_STUD / 1000, trees))
	return { boardPos = boardPos, trees = trees, length = d.length }
end

return MapBuilder
