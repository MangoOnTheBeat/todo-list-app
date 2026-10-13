-- Builds the browser game's car models in Roblox: the exported triangles (packed in Shared/CarMeshes)
-- become EditableMeshes and then MeshParts, grouped by material (paint, glass, lamps, chrome, trim).
-- Wheels are separate so they spin and steer. Each car is built once and cloned after that.
-- If this device or game can't create meshes, build() returns nil and the caller uses the block car.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarMesh = {}
local folder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarMeshes")
local templates = {}
CarMesh.lastError = nil

local B64 = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #chars do B64[string.byte(chars, i)] = i - 1 end
end
local function decode64(s: string): buffer
	local n = #s
	local pad = 0
	if string.sub(s, -2) == "==" then pad = 2 elseif string.sub(s, -1) == "=" then pad = 1 end
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = bit32.lshift(B64[a], 18) + bit32.lshift(B64[b], 12) + bit32.lshift(B64[c] or 0, 6) + (B64[d] or 0)
		if o < buffer.len(out) then buffer.writeu8(out, o, bit32.rshift(v, 16)); o += 1 end
		if o < buffer.len(out) then buffer.writeu8(out, o, bit32.band(bit32.rshift(v, 8), 255)); o += 1 end
		if o < buffer.len(out) then buffer.writeu8(out, o, bit32.band(v, 255)); o += 1 end
	end
	return out
end

local function meshPart(data: string): MeshPart
	local buf = decode64(data)
	local nv, ni = buffer.readu16(buf, 0), buffer.readu16(buf, 2)
	local em = AssetService:CreateEditableMesh()
	local vids, nids = table.create(nv), table.create(nv)
	local po, no, io = 4, 4 + nv * 6, 4 + nv * 9
	for k = 0, nv - 1 do
		local x = buffer.readi16(buf, po + k * 6) / 2000
		local y = buffer.readi16(buf, po + k * 6 + 2) / 2000
		local z = buffer.readi16(buf, po + k * 6 + 4) / 2000
		vids[k + 1] = em:AddVertex(Vector3.new(x, y, z))
		local nx, ny, nz = buffer.readi8(buf, no + k * 3) / 127, buffer.readi8(buf, no + k * 3 + 1) / 127, buffer.readi8(buf, no + k * 3 + 2) / 127
		nids[k + 1] = em:AddNormal(Vector3.new(nx, ny, nz))
	end
	for t = 0, ni // 3 - 1 do
		local a = buffer.readu16(buf, io + t * 6) + 1
		local b = buffer.readu16(buf, io + t * 6 + 2) + 1
		local c = buffer.readu16(buf, io + t * 6 + 4) + 1
		local f = em:AddTriangle(vids[a], vids[b], vids[c])
		em:SetFaceNormals(f, { nids[a], nids[b], nids[c] })
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	return part
end

local function style(p: BasePart, kind: string, color: string, glow: string?, opacity: number?)
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	if kind == "paint" then
		p.Reflectance = 0.08
		p:SetAttribute("Paint", true)
	elseif kind == "glass" then
		p.Material = Enum.Material.Glass
		p.Transparency = math.clamp(1 - (opacity or 0.7), 0.15, 0.85)
		p:SetAttribute("Cabin", true)
	elseif kind == "lamp" then
		p.Material = Enum.Material.Neon
		if glow then p.Color = Color3.fromHex(glow) end
		p:SetAttribute("Lamp", true)
	elseif kind == "metal" then
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.3
	end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.CastShadow = kind ~= "glass"
end

local function weld(root: BasePart, p: BasePart, c0: CFrame)
	p.CFrame = root.CFrame * c0
	local w = Instance.new("Weld")
	w.Name = "W"
	w.Part0, w.Part1, w.C0 = root, p, c0
	w.Parent = p
end

-- build (or clone) the browser model of car `def`
function CarMesh.build(def, name: string, paint: Color3?)
	local key = def.mesh or def.id -- special cars reuse a browser body
	-- another call is already building this car: wait for it instead of building it twice
	while templates[key] == "busy" do task.wait() end
	local tpl = templates[key]
	if tpl == false then return nil end
	if not tpl then
		templates[key] = "busy"
		local ok, res = pcall(function()
			-- the "lite" install has no car shapes at all: use the block car straight away instead of waiting
			if folder:FindFirstChild("_lite") then error("lite build: no car meshes") end
			local src = require(folder:WaitForChild(key, 5))
			local m = Instance.new("Model")
			m.Name = key
			local root = Instance.new("Part")
			root.Name = "Root"
			root.Size = Vector3.new(1, 1, 1)
			root.Transparency = 1
			root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
			root.CFrame = CFrame.new(0, 1e4, 0)
			root.Parent = m
			m.PrimaryPart = root
			for _, g in src.body do
				local p = meshPart(g.data)
				p.Name = g.kind
				style(p, g.kind, g.color, g.glow, g.opacity)
				weld(root, p, CFrame.new(g.center[1], g.center[2], g.center[3]))
				p.Parent = m
			end
			for k, w in src.wheels do
				for _, g in w.parts do
					local p = meshPart(g.data)
					p.Name = "Wheel" .. k
					style(p, g.kind, g.color, nil)
					p:SetAttribute("Wheel", k)
					p:SetAttribute("Spin", g.spin)
					p:SetAttribute("Front", w.front)
					p:SetAttribute("Hub", Vector3.new(w.pos[1], w.pos[2], w.pos[3]))
					p:SetAttribute("Off", Vector3.new(g.center[1], g.center[2], g.center[3]))
					weld(root, p, CFrame.new(w.pos[1] + g.center[1], w.pos[2] + g.center[2], w.pos[3] + g.center[3]))
					p.Parent = m
				end
			end
			return m
		end)
		if not ok then
			CarMesh.lastError = tostring(res)
			templates[key] = false
			return nil
		end
		tpl = res
		templates[key] = tpl
	end
	local m = tpl:Clone()
	m.Name = name
	local wheels = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			if paint and p:GetAttribute("Paint") then p.Color = paint end
			if p:GetAttribute("Wheel") then
				table.insert(wheels, { weld = p:FindFirstChild("W"), hub = CFrame.new(p:GetAttribute("Hub")), off = CFrame.new(p:GetAttribute("Off")), spin = p:GetAttribute("Spin"), front = p:GetAttribute("Front") })
			end
		end
	end
	-- smoke points and headlight beam, like the block car
	local root = m.PrimaryPart
	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Range, beam.Angle, beam.Brightness = 80, 70, 4
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Parent = root
	local hw, rz = def.b.wid * 3.5 / 2, def.b.wb * 3.5 / 2
	for _, s in { { "SmokeL", -1 }, { "SmokeR", 1 } } do
		local a = Instance.new("Attachment")
		a.Name = s[1]
		a.Position = Vector3.new(s[2] * (hw - 0.6), 0.5, rz + 0.4)
		a.Parent = root
	end
	CarMesh.wheels = CarMesh.wheels or setmetatable({}, { __mode = "k" })
	CarMesh.wheels[m] = wheels
	return m
end

-- place: ground point cf, front wheel angle (+ = right), wheel roll angles (front, rear)
function CarMesh.place(m: Model, cf: CFrame, steer: number, rollF: number, rollR: number)
	m.PrimaryPart.CFrame = cf
	local list = CarMesh.wheels and CarMesh.wheels[m]
	if not list then return end
	local turn = CFrame.Angles(0, -steer, 0)
	for _, w in list do
		local spin = if w.spin then CFrame.Angles(-(if w.front then rollF else rollR), 0, 0) else CFrame.identity
		w.weld.C0 = w.hub * (if w.front then turn else CFrame.identity) * spin * w.off
	end
end

return CarMesh
