-- Kaido Drift effects on this device: skid marks laid by the rear tyres, exhaust backfire flames, underglow,
-- and the tandem link line to the car you're drifting with. Everything is pooled or short-lived so phones
-- keep their frame rate.
local Debris = game:GetService("Debris")

local Fx = {}

-- ===================== skid marks =====================
local folder = Instance.new("Folder")
folder.Name = "KaidoSkids"
folder.Parent = workspace
local pool, nextMark, poolSize = {}, 1, 0
local MARK = Color3.fromRGB(16, 16, 18)
local function getMark(): Part
	local p = pool[nextMark]
	if not p then
		p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = MARK
		p.Parent = folder
		pool[nextMark] = p
	end
	nextMark = nextMark % poolSize + 1
	return p
end

-- how many marks stay on the road (oldest are reused): fewer on low graphics
function Fx.setSkidLimit(n: number)
	poolSize = n
	for k = #pool, n + 1, -1 do pool[k]:Destroy(); pool[k] = nil end
	if nextMark > n then nextMark = 1 end
end
Fx.setSkidLimit(400)

-- trail per wheel: the last point laid, so each mark joins the previous one
local trails = {}
-- key: wheel name; pos: contact point on the road; up: road normal; strength 0..1 (darkness); width in studs
function Fx.skid(key: string, pos: Vector3, up: Vector3, strength: number, width: number)
	local t = trails[key]
	if strength <= 0 then trails[key] = nil; return end
	if not t then trails[key] = pos; return end
	local d = pos - t
	local len = d.Magnitude
	if len < 1.6 then return end -- lay a mark every ~1.6 studs
	if len > 12 then trails[key] = pos; return end -- teleported or jumped: start a new trail
	local mid = (pos + t) / 2 + up * 0.04
	local fwd = d.Unit
	local p = getMark()
	p.Size = Vector3.new(width, 0.04, len + 0.15)
	p.CFrame = CFrame.lookAt(mid, mid + fwd, up)
	p.Transparency = 0.82 - 0.5 * math.clamp(strength, 0, 1)
	trails[key] = pos
end
function Fx.clearSkids()
	table.clear(trails)
	for _, p in pool do p.Transparency = 1 end
end

-- ===================== backfire =====================
local FLAME = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 170, 255) }
-- a short burst of flame from each exhaust tip (exhausts: CFrames pointing backwards out of the tips)
function Fx.backfire(tips: { CFrame }, big: boolean)
	for _, tip in tips do
		local n = big and 3 or 2
		for k = 1, n do
			task.delay((k - 1) * 0.045, function()
				local s = (big and 1.3 or 0.9) * (0.7 + math.random() * 0.6)
				local p = Instance.new("Part")
				p.Shape = Enum.PartType.Ball
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Material = Enum.Material.Neon
				p.Color = FLAME[math.random(1, if big then 3 else 2)]
				p.Size = Vector3.new(s, s, s)
				p.CFrame = tip * CFrame.new(0, 0, -s * 0.4)
				p.Transparency = 0.15
				local l = Instance.new("PointLight")
				l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 150, 60), 14, 3, false
				l.Parent = p
				p.Parent = workspace
				Debris:AddItem(p, 0.07)
			end)
		end
	end
end

-- ===================== underglow =====================
-- a neon strip under the car that lights the road around it (colour nil = off)
function Fx.underglow(model: Model, color: Color3?, size: Vector3)
	local root = model.PrimaryPart
	if not root then return end
	local old = model:FindFirstChild("Underglow")
	if old then old:Destroy() end
	if not color then return end
	local p = Instance.new("Part")
	p.Name = "Underglow"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false, false
	p.Massless = true
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(size.X * 0.8, 0.12, size.Z * 0.75)
	p.CFrame = root.CFrame * CFrame.new(0, 0.35, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, p
	w.Parent = p
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, 16, 2.4, false
	l.Parent = p
	local sl = Instance.new("SurfaceLight")
	sl.Face, sl.Color, sl.Range, sl.Brightness, sl.Angle = Enum.NormalId.Bottom, color, 12, 3, 120
	sl.Parent = p
	p.Parent = model
end

-- ===================== tandem link =====================
local beam, a0, a1
-- draw a glowing line between your car and the car you're tandem drifting with (target nil hides it)
function Fx.tandem(myRoot: BasePart?, otherRoot: BasePart?, strength: number)
	if not (myRoot and otherRoot) then
		if beam then beam.Enabled = false end
		return
	end
	if not beam or not beam.Parent or a0.Parent ~= myRoot then
		if beam then beam:Destroy(); a0:Destroy() end
		a0 = Instance.new("Attachment"); a0.Name = "TandemA"; a0.Position = Vector3.new(0, 2, 0); a0.Parent = myRoot
		beam = Instance.new("Beam")
		beam.Name = "TandemLink"
		beam.Attachment0 = a0
		beam.FaceCamera = true
		beam.LightEmission, beam.LightInfluence = 1, 0
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureSpeed, beam.TextureLength = 2, 6
		beam.Segments = 12
		beam.CurveSize0, beam.CurveSize1 = 2, -2
		beam.Parent = myRoot
	end
	local target = otherRoot:FindFirstChild("TandemB")
	if not target then
		target = Instance.new("Attachment"); target.Name = "TandemB"; target.Position = Vector3.new(0, 2, 0); target.Parent = otherRoot
	end
	a1 = target
	beam.Attachment1 = a1
	local c = Color3.fromRGB(89, 227, 255):Lerp(Color3.fromRGB(255, 126, 182), math.clamp(strength, 0, 1))
	beam.Color = ColorSequence.new(c)
	beam.Width0, beam.Width1 = 0.4 + strength * 0.8, 0.4 + strength * 0.8
	beam.Transparency = NumberSequence.new(0.35 - 0.25 * strength)
	beam.Enabled = true
end

return Fx
