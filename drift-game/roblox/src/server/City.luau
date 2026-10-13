-- Kaido Drift: Shin-Hakone, a big night city east of the pass. A street grid with a downtown of glass
-- towers, mid-rise blocks with lit floors and vertical neon signs, low houses and parks at the edges,
-- a lattice tower, a scramble crossing with giant screens, an elevated expressway loop with a ramp,
-- and a road linking it all to the Hakone pass. Everything solid goes in City/Solid (cars hit it);
-- everything drivable goes in City/Ground.
local City = {}

local GRID = 24 -- blocks per side
local BLOCK = 200 -- block size (studs)
local STREET = 48 -- street width (studs)
local PITCH = BLOCK + STREET
local GY = 6.6 -- street surface height
local CURB = 0.6 -- sidewalk height above the street
local RING = 5 -- the expressway runs along the streets RING blocks out from the centre
local RING_Y = 58 -- expressway deck height
local DECK = 44 -- expressway deck width

local SIGNS = { "ラーメン", "カラオケ", "居酒屋", "寿司", "ホテル", "薬", "焼肉", "ゲーム", "喫茶", "酒", "書店", "質", "パチンコ", "駐車場", "整骨院", "そば", "うどん", "コンビニ", "銭湯", "麻雀" }
local SIGN_COLORS = { Color3.fromRGB(255, 70, 110), Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(150, 255, 120), Color3.fromRGB(255, 120, 40), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 255, 255) }
-- ground-floor shops you'd see on a Japanese street. col: facade, glow: lit interior, sign: board colour,
-- text: what the sign says, ink: text colour
local SHOPS = {
	boba = { col = Color3.fromRGB(255, 214, 226), glow = Color3.fromRGB(255, 236, 214), sign = Color3.fromRGB(120, 230, 214), text = "BOBA TEA  タピオカ", ink = Color3.fromRGB(70, 30, 60) },
	ramen = { col = Color3.fromRGB(70, 44, 30), glow = Color3.fromRGB(255, 200, 130), sign = Color3.fromRGB(230, 40, 40), text = "ラーメン  RAMEN", ink = Color3.fromRGB(255, 240, 220) },
	konbini = { col = Color3.fromRGB(244, 244, 240), glow = Color3.fromRGB(235, 250, 255), sign = Color3.fromRGB(40, 160, 90), text = "コンビニ  24h", ink = Color3.fromRGB(255, 255, 255) },
	cafe = { col = Color3.fromRGB(120, 84, 60), glow = Color3.fromRGB(255, 214, 160), sign = Color3.fromRGB(240, 226, 200), text = "喫茶  CAFÉ", ink = Color3.fromRGB(70, 44, 30) },
	arcade = { col = Color3.fromRGB(26, 22, 40), glow = Color3.fromRGB(190, 120, 255), sign = Color3.fromRGB(255, 70, 160), text = "ゲーム  GAME", ink = Color3.fromRGB(255, 255, 255) },
	sushi = { col = Color3.fromRGB(226, 214, 190), glow = Color3.fromRGB(255, 230, 190), sign = Color3.fromRGB(30, 50, 110), text = "寿司  SUSHI", ink = Color3.fromRGB(255, 255, 255) },
	karaoke = { col = Color3.fromRGB(46, 30, 70), glow = Color3.fromRGB(255, 120, 220), sign = Color3.fromRGB(160, 80, 255), text = "カラオケ", ink = Color3.fromRGB(255, 255, 255) },
	drug = { col = Color3.fromRGB(240, 240, 236), glow = Color3.fromRGB(250, 250, 240), sign = Color3.fromRGB(255, 214, 40), text = "薬  DRUG", ink = Color3.fromRGB(30, 30, 30) },
}
local DOWNTOWN_SHOPS = { "boba", "boba", "ramen", "konbini", "konbini", "cafe", "arcade", "arcade", "sushi", "karaoke", "karaoke", "drug" }
local SUBURB_SHOPS = { "boba", "ramen", "ramen", "konbini", "konbini", "cafe", "sushi", "drug" }
local WINDOW = { Color3.fromRGB(255, 214, 150), Color3.fromRGB(255, 236, 200), Color3.fromRGB(190, 220, 255), Color3.fromRGB(150, 200, 255) }

function City.build(ctx)
	local Track, rng, breathe = ctx.Track, ctx.rng, ctx.breathe
	local FLOOR, HALF = ctx.FLOOR, ctx.HALF
	local root = Instance.new("Folder")
	root.Name = "City"
	root.Parent = ctx.map
	local ground = Instance.new("Folder"); ground.Name = "Ground"; ground.Parent = root
	local solid = Instance.new("Folder"); solid.Name = "Solid"; solid.Parent = root
	local deco = Instance.new("Folder"); deco.Name = "Deco"; deco.Parent = root
	local lights = Instance.new("Folder"); lights.Name = "Lights"; lights.Parent = root
	local signs = Instance.new("Folder"); signs.Name = "Signs"; signs.Parent = root

	local nLight = 0
	local function part(parent, size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	-- a long flat part, split into pieces no bigger than Roblox's 2048-stud limit
	local function slab(parent, x0, z0, x1, z1, y, h, color, mat)
		local lx, lz = x1 - x0, z1 - z0
		local nx, nz = math.ceil(lx / 2000), math.ceil(lz / 2000)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local sx, sz = lx / nx, lz / nz
				part(parent, Vector3.new(sx, h, sz), CFrame.new(x0 + sx * (i + 0.5), y - h / 2, z0 + sz * (j + 0.5)), color, mat)
			end
		end
	end

	-- place the city east of the pass
	local maxX, minZ, maxZ = -math.huge, math.huge, -math.huge
	for i = 1, Track.N do
		maxX = math.max(maxX, Track.X[i])
		minZ, maxZ = math.min(minZ, Track.Z[i]), math.max(maxZ, Track.Z[i])
	end
	local SIZE = GRID * PITCH + STREET
	local X0 = maxX + 900
	local Z0 = (minZ + maxZ) / 2 - SIZE / 2
	local cx, cz = X0 + SIZE / 2, Z0 + SIZE / 2
	local function streetX(i) return X0 + i * PITCH + STREET / 2 end -- centre line of the i-th north-south street
	local function streetZ(j) return Z0 + j * PITCH + STREET / 2 end

	-- terrain under the city: cleared from 4 studs below street level up (terrain uses 4-stud voxels and
	-- would bulge through the streets otherwise); the street slab is thick enough to hide the gap
	for gx = X0 - 200, X0 + SIZE + 200, 1024 do
		for gz = Z0 - 200, Z0 + SIZE + 200, 1024 do
			workspace.Terrain:FillBlock(CFrame.new(gx + 512, GY - 4 + 8, gz + 512), Vector3.new(1024, 16, 1024), Enum.Material.Air)
			workspace.Terrain:FillBlock(CFrame.new(gx + 512, GY - 4 - 6, gz + 512), Vector3.new(1024, 12, 1024), Enum.Material.Concrete)
			breathe()
		end
	end

	-- streets: one asphalt sheet, then lane lines
	local asphalt = Color3.fromRGB(40, 41, 46)
	slab(ground, X0, Z0, X0 + SIZE, Z0 + SIZE, GY, 6, asphalt, Enum.Material.Asphalt)
	local lineCol = Color3.fromRGB(236, 232, 214)
	local yellow = Color3.fromRGB(240, 188, 40)
	local function mark(x, z, sx, sz, col)
		local p = part(deco, Vector3.new(sx, 0.06, sz), CFrame.new(x, GY + 0.03, z), col)
		p.CanCollide, p.CanQuery = false, false
	end
	-- every fourth street is an avenue: double yellow centre line and white lane lines; others a white centre line
	for i = 0, GRID do
		local avenue = i % 4 == 0
		for j = 0, GRID - 1 do
			local a0 = Z0 + j * PITCH + STREET + 8 -- this block's stretch, clear of the junctions
			local l = BLOCK - 16
			local mid = a0 + l / 2
			local x = streetX(i)
			local z = streetZ(i)
			local b0 = X0 + j * PITCH + STREET + 8
			local midx = b0 + l / 2
			if avenue then
				mark(x - 0.55, mid, 0.4, l, yellow); mark(x + 0.55, mid, 0.4, l, yellow)
				mark(x - STREET / 4, mid, 0.35, l, lineCol); mark(x + STREET / 4, mid, 0.35, l, lineCol)
				mark(midx, z - 0.55, l, 0.4, yellow); mark(midx, z + 0.55, l, 0.4, yellow)
				mark(midx, z - STREET / 4, l, 0.35, lineCol); mark(midx, z + STREET / 4, l, 0.35, lineCol)
			else
				mark(x, mid, 0.45, l, lineCol)
				mark(midx, z, l, 0.45, lineCol)
			end
		end
		breathe()
	end
	local function district(x, z)
		local d = math.max(math.abs(x - cx), math.abs(z - cz)) / (SIZE / 2)
		return d
	end

	-- buildings
	local buildingCount = 0
	local function windowBands(b, size, cf, faces, color, every, tier, minY)
		-- strips of lit windows on the street faces (local -Z / +Z / -X / +X): towers get many, others five
		every = math.max(every, (size.Y - 4) / (if size.Y > 140 then 16 else 5))
		for _, f in faces do
			local horiz = f == "z-" or f == "z+"
			local w = horiz and size.X or size.Z
			for y = every, size.Y - 4, every do
				if y >= (minY or 0) and rng:NextNumber() < 0.78 then
					local len = w * (0.35 + rng:NextNumber() * 0.55)
					local off = (rng:NextNumber() - 0.5) * (w - len)
					local pos
					if f == "z-" then pos = CFrame.new(off, -size.Y / 2 + y, -size.Z / 2 - 0.08)
					elseif f == "z+" then pos = CFrame.new(off, -size.Y / 2 + y, size.Z / 2 + 0.08)
					elseif f == "x-" then pos = CFrame.new(-size.X / 2 - 0.08, -size.Y / 2 + y, off)
					else pos = CFrame.new(size.X / 2 + 0.08, -size.Y / 2 + y, off) end
					local s = horiz and Vector3.new(len, 1.6, 0.15) or Vector3.new(0.15, 1.6, len)
					local p = part(b, s, cf * pos, color, Enum.Material.Neon)
					p.CanCollide, p.CanQuery = false, false
					p.Name = "Window"
					p:SetAttribute("Tier", tier)
				end
			end
		end
	end
	local function sign(b, cf, height, text, color)
		local s = part(b, Vector3.new(3.2, height, 0.8), cf, Color3.fromRGB(18, 18, 22))
		s.CanCollide, s.CanQuery = false, false
		s.Name = "Sign"
		local face = part(b, Vector3.new(2.8, height - 0.6, 0.2), cf * CFrame.new(0, 0, -0.45), color, Enum.Material.Neon)
		face.CanCollide, face.CanQuery = false, false
		face.Name = "SignFace"
		face.Transparency = 0.15
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.PixelsPerStud = 24
		g.LightInfluence = 0
		g.Parent = face
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.fromRGB(20, 12, 24)
		t.Text = table.concat(string.split(text, ""), "\n")
		t.Parent = g
		signs:SetAttribute("n", (signs:GetAttribute("n") or 0) + 1)
	end

	-- text on a sign face (hidden on low graphics, like the other signs)
	local function signText(face, label, ink)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.PixelsPerStud = 20
		g.LightInfluence = 0
		g.Parent = face
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = ink
		t.Text = label
		t.Parent = g
	end
	-- the frame of a street face of a box: origin at the ground in the middle of that face, -Z pointing out
	local function faceFrame(cf, w, l, h, f)
		local out = if f == "z-" then Vector3.new(0, 0, -1) elseif f == "z+" then Vector3.new(0, 0, 1) elseif f == "x-" then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
		local half = if f == "z-" or f == "z+" then l / 2 else w / 2
		local width = if f == "z-" or f == "z+" then w else l
		local base = cf.Position + out * half - Vector3.new(0, h / 2, 0)
		return CFrame.lookAt(base, base + out), width
	end
	-- a themed shop on the ground floor of a building face
	local function shopFront(b, F, faceW, kind)
		local k = SHOPS[kind]
		local W = math.min(faceW * 0.86, 46)
		local function at(x, y, z) return F * CFrame.new(x, y, z) end
		local function deco(size, cf, color, mat, shape)
			local q = part(b, size, cf, color, mat, shape); q.CanCollide, q.CanQuery = false, false; return q
		end
		deco(Vector3.new(W, 9, 0.4), at(0, 4.5, -0.25), k.col, if kind == "ramen" or kind == "cafe" then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic)
		local glass = deco(Vector3.new(W * 0.8, 5.4, 0.12), at(0, 3.1, -0.5), k.glow, Enum.Material.Neon)
		glass.Name = "Window"; glass:SetAttribute("Tier", 1); glass.Transparency = 0.1
		deco(Vector3.new(W * 0.8, 5.4, 0.1), at(0, 3.1, -0.45), Color3.fromRGB(150, 170, 190), Enum.Material.Glass).Transparency = 0.5
		local board = deco(Vector3.new(W * 0.74, 2.4, 0.5), at(0, 7.6, -0.75), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
		local face = deco(Vector3.new(W * 0.72, 2.1, 0.12), board.CFrame * CFrame.new(0, 0, -0.3), k.sign, Enum.Material.Neon)
		face.Name = "SignFace"
		signText(face, k.text, k.ink)
		if kind == "boba" then
			-- a giant tapioca cup on the sign: clear cup, pink tea, black pearls, a neon straw
			local c0 = at(W * 0.3, 12.5, -1.4)
			deco(Vector3.new(6, 4.6, 4.6), c0 * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 190, 210), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.25
			deco(Vector3.new(0.6, 4.9, 4.9), c0 * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			for p = 1, 3 do deco(Vector3.new(1.2, 1.2, 1.2), c0 * CFrame.new((p - 2) * 1.2, -2.2, (p % 2) * 0.6 - 0.3), Color3.fromRGB(30, 20, 20), Enum.Material.SmoothPlastic, Enum.PartType.Ball) end
			deco(Vector3.new(0.5, 6, 0.5), c0 * CFrame.new(0.6, 4.6, 0) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(80, 230, 255), Enum.Material.Neon)
			deco(Vector3.new(W * 0.8, 0.3, 3), at(0, 6.2, -1.9) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(150, 230, 220), Enum.Material.Fabric)
		elseif kind == "ramen" or kind == "sushi" then
			-- noren curtains over the door, paper lanterns either side
			local cloth = if kind == "ramen" then Color3.fromRGB(150, 24, 30) else Color3.fromRGB(28, 44, 96)
			for n = -1, 1 do deco(Vector3.new(2.2, 3.2, 0.1), at(n * 2.4, 4.6, -0.75), cloth, Enum.Material.Fabric) end
			for _, x in { -W * 0.42, W * 0.42 } do
				local lan = deco(Vector3.new(1.8, 2.6, 1.8), at(x, 5.2, -1.3), if kind == "ramen" then Color3.fromRGB(240, 50, 40) else Color3.fromRGB(255, 244, 220), Enum.Material.Neon, Enum.PartType.Ball)
				lan.Name = "Lantern"
			end
		elseif kind == "konbini" then
			-- the stripe band, bins and parked bikes out front
			deco(Vector3.new(W, 0.7, 0.2), at(0, 6.1, -0.55), Color3.fromRGB(255, 140, 30), Enum.Material.SmoothPlastic)
			deco(Vector3.new(W, 0.7, 0.2), at(0, 6.8, -0.55), Color3.fromRGB(40, 160, 90), Enum.Material.SmoothPlastic)
			for n = 0, 1 do deco(Vector3.new(1.4, 2.6, 1.4), at(-W * 0.36 + n * 1.8, 1.3, -1.6), Color3.fromRGB(70, 110, 160), Enum.Material.SmoothPlastic) end
			for n = 0, 1 do
				local bx = W * 0.3 + n * 1.6
				for _, z in { -2.4, -4.8 } do deco(Vector3.new(0.15, 2, 2), at(bx, 1, z) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) end
				deco(Vector3.new(0.2, 0.25, 2.6), at(bx, 1.5, -3.6), Color3.fromRGB(200, 40, 50), Enum.Material.Metal)
			end
		elseif kind == "cafe" then
			for n = 0, 3 do
				deco(Vector3.new(W * 0.8 / 4, 0.3, 3), at(-W * 0.3 + n * W * 0.2, 6.2, -1.9) * CFrame.Angles(math.rad(-14), 0, 0), if n % 2 == 0 then Color3.fromRGB(30, 90, 60) else Color3.fromRGB(240, 236, 226), Enum.Material.Fabric)
			end
			for _, x in { -W * 0.44, W * 0.44 } do
				deco(Vector3.new(1.6, 1.6, 1.6), at(x, 0.8, -1.4), Color3.fromRGB(120, 70, 50), Enum.Material.Brick)
				deco(Vector3.new(2.4, 2.4, 2.4), at(x, 2.6, -1.4), Color3.fromRGB(50, 110, 56), Enum.Material.Grass, Enum.PartType.Ball)
			end
		elseif kind == "arcade" then
			for n = -1, 1 do deco(Vector3.new(0.4, 8, 0.3), at(n * W * 0.45, 4.5, -0.6), SIGN_COLORS[(n + 2) * 2], Enum.Material.Neon) end
			for n = 0, 1 do
				local cm = at(-W * 0.3 + n * 3.4, 0, -2)
				deco(Vector3.new(3, 5.2, 3), cm * CFrame.new(0, 2.6, 0), Color3.fromRGB(180, 220, 255), Enum.Material.Glass).Transparency = 0.45
				deco(Vector3.new(3.1, 0.8, 3.1), cm * CFrame.new(0, 5.6, 0), Color3.fromRGB(255, 80, 180), Enum.Material.Neon)
			end
		elseif kind == "karaoke" or kind == "drug" then
			deco(Vector3.new(W, 0.6, 0.2), at(0, 6.4, -0.55), k.sign, Enum.Material.Neon)
		end
	end

	local function building(x0, z0, x1, z1, d, streetSides)
		local w, l = x1 - x0, z1 - z0
		local h, col, mat, every
		local tier = rng:NextInteger(1, 3)
		if d < 0.24 then
			h = 160 + rng:NextNumber() ^ 1.6 * 380
			col = ({ Color3.fromRGB(30, 44, 66), Color3.fromRGB(22, 30, 40), Color3.fromRGB(40, 60, 70), Color3.fromRGB(56, 60, 70) })[rng:NextInteger(1, 4)]
			mat = Enum.Material.Glass
			every = 7
		elseif d < 0.6 then
			h = 34 + rng:NextNumber() ^ 1.3 * 120
			-- Japanese mid-rise: tiled apartment facades, brick, board-marked concrete, rendered plaster
			local look = ({
				{ Color3.fromRGB(196, 190, 178), Enum.Material.CeramicTiles }, { Color3.fromRGB(150, 120, 100), Enum.Material.CeramicTiles },
				{ Color3.fromRGB(122, 74, 58), Enum.Material.Brick }, { Color3.fromRGB(96, 70, 60), Enum.Material.Brick },
				{ Color3.fromRGB(150, 148, 142), Enum.Material.Concrete }, { Color3.fromRGB(112, 114, 118), Enum.Material.Concrete },
				{ Color3.fromRGB(214, 206, 190), Enum.Material.Plaster }, { Color3.fromRGB(84, 92, 104), Enum.Material.Plaster },
			})[rng:NextInteger(1, 8)]
			col, mat = look[1], look[2]
			every = 9
		else
			h = 12 + rng:NextNumber() * 12
			-- houses: rendered plaster, dark timber cladding or brick
			local look = ({
				{ Color3.fromRGB(224, 216, 200), Enum.Material.Plaster }, { Color3.fromRGB(200, 188, 166), Enum.Material.Plaster },
				{ Color3.fromRGB(176, 186, 190), Enum.Material.Plaster }, { Color3.fromRGB(92, 64, 46), Enum.Material.WoodPlanks },
				{ Color3.fromRGB(70, 54, 42), Enum.Material.WoodPlanks }, { Color3.fromRGB(140, 86, 64), Enum.Material.Brick },
			})[rng:NextInteger(1, 6)]
			col, mat = look[1], look[2]
			every = 6
		end
		local b = Instance.new("Model")
		b.Name = "Building"
		local cf = CFrame.new((x0 + x1) / 2, GY + CURB + h / 2, (z0 + z1) / 2)
		local size = Vector3.new(w, h, l)
		local body = part(b, size, cf, col, mat)
		body.Name = "Body"
		if mat == Enum.Material.Glass then
			body.Reflectance = 0.18
			-- a faint glow behind the glass on the street faces, so towers read as lit glass at night
			for _, f in streetSides do
				local horiz = f == "z-" or f == "z+"
				local off = if f == "z-" then CFrame.new(0, 0, -l / 2 - 0.05) elseif f == "z+" then CFrame.new(0, 0, l / 2 + 0.05) elseif f == "x-" then CFrame.new(-w / 2 - 0.05, 0, 0) else CFrame.new(w / 2 + 0.05, 0, 0)
				local glow = part(b, if horiz then Vector3.new(w - 1, h - 6, 0.1) else Vector3.new(0.1, h - 6, l - 1), cf * off, Color3.fromRGB(40, 70, 110), Enum.Material.Neon)
				glow.Transparency = 0.82; glow.CanCollide, glow.CanQuery = false, false; glow.Name = "Window"; glow:SetAttribute("Tier", 1)
			end
		end
		-- base and top: a stone podium and metal crown on towers, a parapet on mid-rise roofs
		if mat == Enum.Material.Glass then
			part(b, Vector3.new(w + 1.2, 8, l + 1.2), cf * CFrame.new(0, -h / 2 + 4, 0), Color3.fromRGB(64, 66, 72), Enum.Material.Granite).CanQuery = false
			part(b, Vector3.new(w + 0.8, 3, l + 0.8), cf * CFrame.new(0, h / 2 - 1.5, 0), Color3.fromRGB(46, 50, 58), Enum.Material.Metal).CanQuery = false
		elseif d < 0.6 then
			local dark = Color3.new(col.R * 0.75, col.G * 0.75, col.B * 0.75)
			part(b, Vector3.new(w + 0.6, 1.4, l + 0.6), cf * CFrame.new(0, h / 2 + 0.7, 0), dark, Enum.Material.Concrete).CanQuery = false
		end
		-- roof: plant rooms and, on towers, red aviation lights
		if d < 0.6 then
			part(b, Vector3.new(w * 0.4, 5, l * 0.4), cf * CFrame.new(0, h / 2 + 2.5, 0), Color3.fromRGB(70, 72, 78), Enum.Material.Metal).CanQuery = false
			if h > 140 then
				for _, c in { { -1, -1 }, { 1, 1 } } do
					local a = part(b, Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(c[1] * (w / 2 - 1), h / 2 + 0.6, c[2] * (l / 2 - 1)), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
					a.Name = "AirLight"; a.CanQuery = false
				end
			end
		else
			local roof = Instance.new("WedgePart")
			-- kawara clay tiles: mostly blue-grey, some terracotta
			local tile = if rng:NextNumber() < 0.75 then Color3.fromRGB(62, 66, 78) else Color3.fromRGB(146, 70, 48)
			roof.Anchored, roof.Size, roof.Color, roof.Material = true, Vector3.new(w + 2, 5, l / 2 + 1), tile, Enum.Material.ClayRoofTiles
			-- a stone plinth along the bottom of the walls
			part(b, Vector3.new(w + 0.4, 1.6, l + 0.4), cf * CFrame.new(0, -h / 2 + 0.8, 0), Color3.fromRGB(96, 94, 90), Enum.Material.Cobblestone).CanQuery = false
			roof.CFrame = cf * CFrame.new(0, h / 2 + 2.5, -(l / 4 + 0.5))
			roof.Parent = b
			local roof2 = roof:Clone()
			roof2.CFrame = cf * CFrame.new(0, h / 2 + 2.5, l / 4 + 0.5) * CFrame.Angles(0, math.pi, 0)
			roof2.Parent = b
		end
		if d >= 0.18 and d < 0.6 and #streetSides > 0 then
			-- a shop on the main street face of every mid-rise block, and sometimes round the corner too
			for n, f in streetSides do
				if n == 1 or rng:NextNumber() < 0.35 then
					local F, fw = faceFrame(cf, w, l, h, f)
					shopFront(b, F, fw, DOWNTOWN_SHOPS[rng:NextInteger(1, #DOWNTOWN_SHOPS)])
				end
			end
		elseif d >= 0.6 and d < 0.9 and #streetSides > 0 and rng:NextNumber() < 0.4 then
			-- a corner shop in a house
			local F, fw = faceFrame(cf, w, l, h, streetSides[1])
			shopFront(b, F, fw, SUBURB_SHOPS[rng:NextInteger(1, #SUBURB_SHOPS)])
			b:SetAttribute("Shop", true)
		end
		if d < 0.6 then
			windowBands(b, size, cf, streetSides, WINDOW[rng:NextInteger(1, #WINDOW)], every, tier, if mat == Enum.Material.Glass then 0 else 14) -- keep clear of the shops below
		elseif #streetSides > 0 and not b:GetAttribute("Shop") then
			-- a house: one lit window toward the street
			local f = streetSides[1]
			local off = if f == "z-" then CFrame.new(0, 1, -l / 2 - 0.08) elseif f == "z+" then CFrame.new(0, 1, l / 2 + 0.08) elseif f == "x-" then CFrame.new(-w / 2 - 0.08, 1, 0) else CFrame.new(w / 2 + 0.08, 1, 0)
			local horiz = f == "z-" or f == "z+"
			local ww = math.min(6, (if horiz then w else l) * 0.4)
			local frame = part(b, if horiz then Vector3.new(ww + 0.8, 3.8, 0.12) else Vector3.new(0.12, 3.8, ww + 0.8), cf * off, Color3.fromRGB(58, 44, 34), Enum.Material.Wood)
			frame.CanCollide, frame.CanQuery = false, false
			local win = part(b, if horiz then Vector3.new(ww, 3, 0.15) else Vector3.new(0.15, 3, ww), cf * off * (if horiz then CFrame.new(0, 0, (f == "z-") and -0.03 or 0.03) else CFrame.new((f == "x-") and -0.03 or 0.03, 0, 0)), WINDOW[1], Enum.Material.Neon)
			win.Name = "Window"; win.CanCollide, win.CanQuery = false, false
			win:SetAttribute("Tier", tier)
			-- front door beside the window
			local along = (if horiz then w else l) * 0.36
			local doorOff = if horiz then CFrame.new(along, -h / 2 - 1 + 3.5, 0) else CFrame.new(0, -h / 2 - 1 + 3.5, along)
			local door = part(b, if horiz then Vector3.new(3, 7, 0.2) else Vector3.new(0.2, 7, 3), cf * off * doorOff, Color3.fromRGB(70, 48, 34), Enum.Material.WoodPlanks)
			door.CanCollide, door.CanQuery = false, false
		end
		-- vertical neon signs on mid-rise and low shop fronts facing a street
		if d >= 0.18 and d < 0.75 and rng:NextNumber() < 0.42 and #streetSides > 0 then
			local f = streetSides[1]
			local sh = math.min(h - 4, 10 + rng:NextNumber() * 14)
			local y = -h / 2 + 6 + sh / 2
			local pos
			if f == "z-" then pos = CFrame.new(w / 2 - 3, y, -l / 2 - 2.2)
			elseif f == "z+" then pos = CFrame.new(-w / 2 + 3, y, l / 2 + 2.2) * CFrame.Angles(0, math.pi, 0)
			elseif f == "x-" then pos = CFrame.new(-w / 2 - 2.2, y, -l / 2 + 3) * CFrame.Angles(0, -math.pi / 2, 0)
			else pos = CFrame.new(w / 2 + 2.2, y, l / 2 - 3) * CFrame.Angles(0, math.pi / 2, 0) end
			sign(b, cf * pos * CFrame.Angles(0, math.pi / 2, 0), sh, SIGNS[rng:NextInteger(1, #SIGNS)], SIGN_COLORS[rng:NextInteger(1, #SIGN_COLORS)])
		end
		b.Parent = solid
		buildingCount += 1
	end

	-- the expressway ring sits over these streets; keep its pillars clear of buildings
	local ringLo, ringHi = GRID // 2 - RING, GRID // 2 + RING
	local centreI, centreJ = GRID // 2, GRID // 2

	for i = 0, GRID - 1 do
		for j = 0, GRID - 1 do
			local bx0 = X0 + STREET + i * PITCH
			local bz0 = Z0 + STREET + j * PITCH
			local bx1, bz1 = bx0 + BLOCK, bz0 + BLOCK
			-- sidewalk / block base
			local base = part(ground, Vector3.new(BLOCK, CURB + 0.6, BLOCK), CFrame.new(bx0 + BLOCK / 2, GY + CURB / 2 - 0.3, bz0 + BLOCK / 2), Color3.fromRGB(128, 126, 122), Enum.Material.Pavement)
			base.Name = "Block"
			-- kerb stones around the block
			local kc = Color3.fromRGB(190, 188, 182)
			for _, k in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
				local kx, kz = bx0 + BLOCK / 2 + k[1] * (BLOCK / 2 - 0.6), bz0 + BLOCK / 2 + k[2] * (BLOCK / 2 - 0.6)
				local kp = part(deco, if k[1] == 0 then Vector3.new(BLOCK, CURB + 0.66, 1.2) else Vector3.new(1.2, CURB + 0.66, BLOCK), CFrame.new(kx, GY + CURB / 2 - 0.27, kz), kc, Enum.Material.Concrete)
				kp.CanCollide, kp.CanQuery = false, false
			end
			local d = district(bx0 + BLOCK / 2, bz0 + BLOCK / 2)
			if i == centreI - 1 and j == centreJ - 1 then
				-- the tower plaza
				local tx, tz = bx0 + BLOCK / 2, bz0 + BLOCK / 2
				local red, white = Color3.fromRGB(214, 52, 30), Color3.fromRGB(236, 236, 236)
				local tower = Instance.new("Model"); tower.Name = "Tower"
				local H = 640
				for k = 0, 15 do
					local f0, f1 = k / 16, (k + 1) / 16
					local spread0, spread1 = 70 * (1 - f0) ^ 1.7 + 4, 70 * (1 - f1) ^ 1.7 + 4
					local y0, y1 = GY + CURB + f0 * H, GY + CURB + f1 * H
					for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
						local a = Vector3.new(tx + c[1] * spread0, y0, tz + c[2] * spread0)
						local bb = Vector3.new(tx + c[1] * spread1, y1, tz + c[2] * spread1)
						local leg = part(tower, Vector3.new(3, 3, (bb - a).Magnitude), CFrame.lookAt((a + bb) / 2, bb), (k % 2 == 0) and red or white, Enum.Material.Metal)
						leg.CanQuery = k < 2
					end
					if k == 5 or k == 10 then
						local deckP = part(tower, Vector3.new(spread1 * 2 + 14, 10, spread1 * 2 + 14), CFrame.new(tx, y1, tz), Color3.fromRGB(240, 240, 240), Enum.Material.Glass)
						deckP.CanQuery = false
						local glow = part(tower, Vector3.new(spread1 * 2 + 15, 1.5, spread1 * 2 + 15), CFrame.new(tx, y1 + 3, tz), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
						glow.CanQuery = false
					end
				end
				local tip = part(tower, Vector3.new(3, 60, 3), CFrame.new(tx, GY + CURB + H + 30, tz), white, Enum.Material.Metal); tip.CanQuery = false
				local beacon = part(tower, Vector3.new(4, 4, 4), CFrame.new(tx, GY + CURB + H + 62, tz), Color3.fromRGB(255, 40, 40), Enum.Material.Neon); beacon.Name = "AirLight"; beacon.CanQuery = false
				tower.Parent = solid
			elseif (i == ringLo or i == ringHi - 1 or j == ringLo or j == ringHi - 1) and i >= ringLo and i < ringHi and j >= ringLo and j < ringHi then
				-- blocks under the expressway: low parking decks
				part(solid, Vector3.new(BLOCK - 30, 14, BLOCK - 30), CFrame.new(bx0 + BLOCK / 2, GY + CURB + 7, bz0 + BLOCK / 2), Color3.fromRGB(96, 98, 104), Enum.Material.Concrete).Name = "Parking"
			elseif d > 0.62 and rng:NextNumber() < 0.12 then
				-- a small park
				for _ = 1, 7 do
					local tx, tz = bx0 + 20 + rng:NextNumber() * (BLOCK - 40), bz0 + 20 + rng:NextNumber() * (BLOCK - 40)
					local t = Instance.new("Model"); t.Name = "Tree"; t:SetAttribute("Tier", rng:NextInteger(1, 3))
					part(t, Vector3.new(10, 1.4, 1.4), CFrame.new(tx, GY + CURB + 5, tz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(72, 52, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
					part(t, Vector3.new(14, 11, 14), CFrame.new(tx, GY + CURB + 13, tz), Color3.fromRGB(40, 86, 46), Enum.Material.Grass, Enum.PartType.Ball)
					t.Parent = solid
				end
				part(deco, Vector3.new(BLOCK - 8, 0.2, BLOCK - 8), CFrame.new(bx0 + BLOCK / 2, GY + CURB + 0.05, bz0 + BLOCK / 2), Color3.fromRGB(60, 96, 52), Enum.Material.Grass).CanCollide = false
			else
				-- split the block into lots: towers take a whole quarter, low-rise packs in
				local n = if d < 0.6 then 2 else 3
				local lot = (BLOCK - 8) / n
				for a = 0, n - 1 do
					for c = 0, n - 1 do
						if not (n >= 3 and a > 0 and a < n - 1 and c > 0 and c < n - 1) then -- inner lots stay courtyards
							local x0 = bx0 + 4 + a * lot + 2
							local z0 = bz0 + 4 + c * lot + 2
							local sides = {}
							-- east-west streets first: that's where you start and where the lantern strings hang
							if c == 0 then table.insert(sides, "z-") end
							if c == n - 1 then table.insert(sides, "z+") end
							if a == 0 then table.insert(sides, "x-") end
							if a == n - 1 then table.insert(sides, "x+") end
							local inset = if d < 0.24 then 6 else 2
							if d < 0.6 or rng:NextNumber() < 0.72 then -- some suburban lots stay open
								building(x0 + inset, z0 + inset, x0 + lot - 4 - inset, z0 + lot - 4 - inset, d, sides)
							end
						end
					end
				end
			end
			breathe()
		end
	end

	-- street lights on every corner (lights shared out by the graphics level), crosswalks downtown
	for i = 0, GRID do
		for j = 0, GRID do
			local x, z = streetX(i), streetZ(j)
			local px, pz = x + STREET / 2 + 2, z + STREET / 2 + 2
			part(solid, Vector3.new(0.8, 20, 0.8), CFrame.new(px, GY + CURB + 10, pz), Color3.fromRGB(70, 72, 76), Enum.Material.Metal).Name = "Pole"
			local head = part(lights, Vector3.new(2.6, 0.5, 1.4), CFrame.new(px - 4, GY + CURB + 19.6, pz - 4), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
			head.Name = "LampHead"
			nLight += 1
			head:SetAttribute("N", nLight)
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 214, 160), 48, 2.2, false
			l.Parent = head
			local jd = district(x, z)
			if jd < 0.48 then
				-- zebra crossings on all four sides and stop lines before them
				for side = -1, 1, 2 do
					for k = -3, 3 do
						mark(x + k * 6.2, z + side * (STREET / 2 + 6), 3, 10, lineCol)
						mark(x + side * (STREET / 2 + 6), z + k * 6.2, 10, 3, lineCol)
					end
					mark(x + side * STREET / 4, z + side * (STREET / 2 + 13), STREET / 2 - 2, 0.8, lineCol)
					mark(x - side * (STREET / 2 + 13), z + side * STREET / 4, 0.8, STREET / 2 - 2, lineCol)
				end
			end
			if i % 4 == 0 and j % 4 == 0 then
				-- traffic lights on the corners of avenue junctions
				for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
					local px2, pz2 = x + c[1] * (STREET / 2 + 3), z + c[2] * (STREET / 2 + 3)
					part(solid, Vector3.new(0.9, 16, 0.9), CFrame.new(px2, GY + CURB + 8, pz2), Color3.fromRGB(70, 72, 76), Enum.Material.Metal).Name = "Pole"
					local arm = part(deco, Vector3.new(0.6, 0.6, 12), CFrame.new(px2, GY + CURB + 15.4, pz2 - c[2] * 6), Color3.fromRGB(70, 72, 76), Enum.Material.Metal)
					arm.CanCollide, arm.CanQuery = false, false
					local box = part(deco, Vector3.new(6.5, 2.2, 1.4), CFrame.new(px2, GY + CURB + 14.6, pz2 - c[2] * 11), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
					box.CanCollide, box.CanQuery = false, false
					local lamp = part(deco, Vector3.new(1.6, 1.6, 0.3), CFrame.new(px2 + (((i + j) // 4) % 2 == 0 and -2 or 2), GY + CURB + 14.6, pz2 - c[2] * 11 - c[2] * 0.75), ((i + j) // 4) % 2 == 0 and Color3.fromRGB(60, 255, 150) or Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
					lamp.CanCollide, lamp.CanQuery = false, false
					lamp.Name = "Signal"
				end
			end
		end
		breathe()
	end

	-- street life: utility poles and overhead wires in the suburbs, vending machines on corners, paper lantern
	-- strings across the shopping streets
	local poleCol, wireCol = Color3.fromRGB(150, 146, 136), Color3.fromRGB(26, 26, 28)
	local function wire(a, b2)
		local m = (a + b2) / 2
		local wp = part(deco, Vector3.new(0.14, 0.14, (b2 - a).Magnitude), CFrame.lookAt(m, b2), wireCol, Enum.Material.SmoothPlastic)
		wp.CanCollide, wp.CanQuery, wp.CastShadow = false, false, false
	end
	for j = 0, GRID do
		local z = streetZ(j)
		for i = 0, GRID - 1 do
			local bx0 = X0 + i * PITCH + STREET
			local d = district(bx0 + BLOCK / 2, z)
			if d >= 0.55 then
				-- two concrete poles per block on the north pavement, wired to each other and to the next block
				local pz = z - STREET / 2 - 2.5
				local tops = {}
				for n, px in { bx0 + 20, bx0 + 120 } do
					part(solid, Vector3.new(1.1, 26, 1.1), CFrame.new(px, GY + CURB + 13, pz), poleCol, Enum.Material.Concrete).Name = "Pole"
					local arm = part(deco, Vector3.new(0.4, 0.4, 7), CFrame.new(px, GY + CURB + 24, pz), poleCol, Enum.Material.Concrete)
					arm.CanCollide, arm.CanQuery = false, false
					if n == 2 and rng:NextNumber() < 0.4 then
						local tr = part(deco, Vector3.new(1.8, 2.6, 1.8), CFrame.new(px, GY + CURB + 20, pz + 1.2), Color3.fromRGB(120, 124, 128), Enum.Material.Metal, Enum.PartType.Cylinder)
						tr.CFrame = tr.CFrame * CFrame.Angles(0, 0, math.pi / 2); tr.CanCollide, tr.CanQuery = false, false
					end
					tops[n] = px
				end
				for _, dz in { -2.8, 2.8 } do
					local y = GY + CURB + 24
					wire(Vector3.new(tops[1], y, pz + dz), Vector3.new(tops[2], y, pz + dz))
					if i < GRID - 1 then wire(Vector3.new(tops[2], y, pz + dz), Vector3.new(tops[1] + PITCH, y, pz + dz)) end
				end
			elseif d >= 0.2 and d < 0.6 and j % 2 == 0 and j < GRID then
				-- a string of paper lanterns across the shopping street, mid-block
				local lx = bx0 + BLOCK / 2
				local y = GY + CURB + 17
				wire(Vector3.new(lx, y + 0.8, z - STREET / 2 - 2), Vector3.new(lx, y + 0.8, z + STREET / 2 + 2))
				for n = 0, 6 do
					local lz = z - STREET / 2 + 3 + n * (STREET - 6) / 6
					local lan = part(deco, Vector3.new(1.6, 2.2, 1.6), CFrame.new(lx, y - (math.sin(n / 6 * math.pi) * 1.2), lz), if n % 2 == 0 then Color3.fromRGB(240, 50, 40) else Color3.fromRGB(255, 240, 210), Enum.Material.Neon, Enum.PartType.Ball)
					lan.Name = "Lantern"; lan.CanCollide, lan.CanQuery = false, false
				end
			end
		end
		breathe()
	end
	-- vending machines: a pair or three on a pavement corner, glowing day and night
	local VEND = { Color3.fromRGB(230, 236, 246), Color3.fromRGB(200, 30, 40), Color3.fromRGB(30, 90, 200), Color3.fromRGB(40, 160, 90) }
	for i = 0, GRID do
		for j = 0, GRID do
			local x, z = streetX(i), streetZ(j)
			local d = district(x, z)
			if d > 0.22 and d < 0.9 and rng:NextNumber() < 0.35 then
				local n = rng:NextInteger(2, 3)
				for k = 0, n - 1 do
					local base = Vector3.new(x - STREET / 2 - 3.2, GY + CURB, z + STREET / 2 + 8 + k * 3.8)
					local face = CFrame.lookAt(base, base + Vector3.new(1, 0, 0))
					part(solid, Vector3.new(3.6, 6.2, 2.4), face * CFrame.new(0, 3.1, 0), VEND[rng:NextInteger(1, #VEND)], Enum.Material.SmoothPlastic).Name = "Vending"
					local glow = part(deco, Vector3.new(3, 3.4, 0.12), face * CFrame.new(0, 3.8, -1.22), Color3.fromRGB(200, 236, 255), Enum.Material.Neon)
					glow.Name = "VendingFace"; glow.CanCollide, glow.CanQuery = false, false
				end
			end
		end
		breathe()
	end

	-- the scramble crossing: giant screens on the corner buildings
	do
		local x, z = streetX(centreI), streetZ(centreJ)
		local texts = { "KAIDO DRIFT", "峠", "新箱根", "DRIFT KING" }
		for k, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			local sx, sz = x + c[1] * (STREET / 2 + 34), z + c[2] * (STREET / 2 + 34)
			local look = CFrame.lookAt(Vector3.new(sx, GY + 70, sz), Vector3.new(x, GY + 70, z))
			local screen = part(signs, Vector3.new(44, 26, 1), look * CFrame.new(0, 0, 1), Color3.fromRGB(30, 30, 40), Enum.Material.Neon)
			screen.Name = "Screen"; screen.CanQuery = false
			local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.PixelsPerStud = 12; g.LightInfluence = 0; g.Parent = screen
			local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = SIGN_COLORS[k]; bg.Parent = g
			local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.TextColor3 = Color3.fromRGB(12, 12, 18); t.Text = texts[k]; t.Parent = g
		end
	end

	-- the elevated expressway (Shuto-style) loop around downtown, with a ramp up from the west
	local expressway = Instance.new("Folder"); expressway.Name = "Expressway"; expressway.Parent = root
	local ex0, ex1 = streetX(ringLo), streetX(ringHi)
	local ez0, ez1 = streetZ(ringLo), streetZ(ringHi)
	local deckCol, wallCol = Color3.fromRGB(46, 47, 52), Color3.fromRGB(150, 152, 156)
	local rampZ = streetZ(centreJ)
	local function deck(a: Vector3, b: Vector3, gapSide: number?)
		-- in sections: Roblox parts can't be longer than 2,048 studs
		local total = (b - a).Magnitude
		local n = math.max(1, math.ceil(total / 600))
		for s = 0, n - 1 do
			local p0, p1 = a:Lerp(b, s / n), a:Lerp(b, (s + 1) / n)
			local len = (p1 - p0).Magnitude
			local ext = if s == 0 or s == n - 1 then DECK / 2 else 0.5
			local cf = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, 0, if s == 0 then ext / 2 - 0.25 elseif s == n - 1 then -(ext / 2 - 0.25) else 0)
			local d = part(ground, Vector3.new(DECK, 2, len + ext + 0.5), cf * CFrame.new(0, -1, 0), deckCol, Enum.Material.Asphalt)
			d.Name = "Deck"
			for _, side in { -1, 1 } do
				if side ~= gapSide then
					part(solid, Vector3.new(1.4, 4.5, len + ext + 0.5), cf * CFrame.new(side * (DECK / 2 - 0.7), 2.25, 0), wallCol, Enum.Material.Concrete).Name = "Barrier"
				end
			end
			local ln = part(deco, Vector3.new(0.5, 0.08, len), cf * CFrame.new(0, 0.04, 0), lineCol)
			ln.CanCollide = false
			-- warm sodium lights along the deck
			if s % 2 == 0 then
				local head = part(lights, Vector3.new(2.4, 0.5, 1.2), cf * CFrame.new(DECK / 2 - 3, 14, 0), Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
				head.Name = "LampHead"
				nLight += 1
				head:SetAttribute("N", nLight)
				local l = Instance.new("PointLight")
				l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 186, 112), 50, 2.4, false
				l.Parent = head
				part(solid, Vector3.new(0.7, 14, 0.7), cf * CFrame.new(DECK / 2 - 0.7, 7, 0), Color3.fromRGB(70, 72, 76), Enum.Material.Metal).Name = "Pole"
			end
		end
	end
	local corners = { Vector3.new(ex0, RING_Y, ez0), Vector3.new(ex1, RING_Y, ez0), Vector3.new(ex1, RING_Y, ez1), Vector3.new(ex0, RING_Y, ez1) }
	for k = 1, 4 do
		local a, b = corners[k], corners[k % 4 + 1]
		if k == 4 then
			-- the west side has the ramp joining in the middle: split it and leave the outer wall open there
			local mid = Vector3.new(ex0, RING_Y, rampZ)
			deck(a, mid + Vector3.new(0, 0, DECK * 0.6))
			deck(mid - Vector3.new(0, 0, DECK * 0.6), b)
			part(ground, Vector3.new(DECK, 2, DECK * 1.4), CFrame.new(mid - Vector3.new(0, 1, 0)), deckCol, Enum.Material.Asphalt).Name = "Deck"
		else
			deck(a, b)
		end
		-- pillars every two blocks
		local n = math.floor((b - a).Magnitude / (PITCH * 2))
		for s = 0, n do
			local p = a:Lerp(b, s / math.max(n, 1))
			part(solid, Vector3.new(10, RING_Y - GY - 2, 10), CFrame.new(p.X, (RING_Y - 2 + GY) / 2, p.Z), Color3.fromRGB(120, 122, 126), Enum.Material.Concrete).Name = "Pillar"
		end
		breathe()
	end
	-- ramp: from street level on the westmost avenue up to the ring
	local rampStart = Vector3.new(ex0 - 760, GY, rampZ)
	local rampEnd = Vector3.new(ex0 - DECK / 2, RING_Y, rampZ)
	do
		local steps = 16
		for s = 0, steps - 1 do
			local a = rampStart:Lerp(rampEnd, s / steps)
			local b = rampStart:Lerp(rampEnd, (s + 1) / steps)
			-- ease in and out so the car does not launch
			local function ease(v, t) return Vector3.new(v.X, GY + (RING_Y - GY) * (t * t * (3 - 2 * t)), v.Z) end
			a, b = ease(a, s / steps), ease(b, (s + 1) / steps)
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt((a + b) / 2, b)
			part(ground, Vector3.new(DECK - 8, 2, len + 1), cf * CFrame.new(0, -1, 0), deckCol, Enum.Material.Asphalt).Name = "Ramp"
			for _, side in { -1, 1 } do
				part(solid, Vector3.new(1.4, 4.5, len + 1), cf * CFrame.new(side * ((DECK - 8) / 2 - 0.7), 2.25, 0), wallCol, Enum.Material.Concrete).Name = "Barrier"
			end
			if a.Y > GY + 6 then
				part(solid, Vector3.new(8, a.Y - GY, 8), CFrame.new(a.X, (a.Y + GY) / 2 - 1, a.Z), Color3.fromRGB(120, 122, 126), Enum.Material.Concrete).Name = "Pillar"
			end
		end
	end

	-- the link road from the Hakone pass: leaves the pass at its eastern-most point, drops to street level
	local jIdx, side = ctx.junction, ctx.junctionSide
	local jx = Track.X[jIdx] + Track.RX[jIdx] * side * HALF
	local jz = Track.Z[jIdx] + Track.RZ[jIdx] * side * HALF
	local jy = Track.Y[jIdx]
	local entryZ = streetZ(math.clamp(math.floor((jz - Z0) / PITCH + 0.5), 0, GRID))
	local pts = {
		Vector3.new(jx, jy, jz),
		Vector3.new(jx + 160, jy, jz),
		Vector3.new(jx + 160 + (X0 - jx - 160) * 0.5, (jy + GY) / 2, (jz + entryZ) / 2),
		Vector3.new(X0 - 40, GY, entryZ),
		Vector3.new(X0 + STREET / 2, GY, entryZ),
	}
	-- smooth the polyline into short pieces
	local path = {}
	for k = 1, #pts - 1 do
		local p0, p1, p2, p3 = pts[math.max(1, k - 1)], pts[k], pts[k + 1], pts[math.min(#pts, k + 2)]
		local segs = math.max(2, math.floor((p2 - p1).Magnitude / 30))
		for s = 0, segs - 1 do
			local t = s / segs
			local t2, t3 = t * t, t * t * t
			table.insert(path, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
		end
	end
	table.insert(path, pts[#pts])
	local link = Instance.new("Folder"); link.Name = "Link"; link.Parent = root
	for k = 1, #path - 1 do
		local a, b = path[k], path[k + 1]
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		part(ground, Vector3.new(HALF * 2, 4, len + 2), cf * CFrame.new(0, -2, 0), asphalt, Enum.Material.Asphalt).Name = "Link"
		workspace.Terrain:FillBlock(cf * CFrame.new(0, -5.5, 0), Vector3.new(HALF * 2 + 4, 4, len + 2), Enum.Material.Ground)
		workspace.Terrain:FillBlock(cf * CFrame.new(0, 13.5, 0), Vector3.new(HALF * 2 + 12, 33, len + 4), Enum.Material.Air)
		if k > 3 then
			for _, sd in { -1, 1 } do
				part(solid, Vector3.new(0.5, 1.2, len + 1), cf * CFrame.new(sd * (HALF + 0.9), 1.6, 0), Color3.fromRGB(172, 174, 178), Enum.Material.DiamondPlate).Name = "Rail"
			end
		end
		if (a.Y + b.Y) / 2 > FLOOR + 1 then
			local m = (a + b) / 2
			local flat = CFrame.lookAt(Vector3.new(m.X, (m.Y + FLOOR) / 2 - 1, m.Z), Vector3.new(b.X, (m.Y + FLOOR) / 2 - 1, b.Z))
			part(link, Vector3.new(HALF * 2 + 6, m.Y - FLOOR, len + 2), flat, Color3.fromRGB(96, 88, 78), Enum.Material.Slate)
		end
	end

	return {
		bounds = { X0, Z0, X0 + SIZE, Z0 + SIZE },
		junction = jIdx,
		junctionSide = side,
		-- start downtown on a shopping street (lantern strings, shops both sides), facing +X
		spawn = { streetX(6), GY, streetZ(8), 0 },
		grid = { X0 = X0, Z0 = Z0, PITCH = PITCH, STREET = STREET, GRID = GRID },
		ring = { ex0, ez0, ex1, ez1 },
		buildings = buildingCount,
	}
end

return City
