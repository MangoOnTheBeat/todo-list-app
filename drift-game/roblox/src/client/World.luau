-- Kaido Drift world contact for free roaming: the ground under the car (raycast down onto roads, the
-- city, ramps, the expressway and terrain) and walls (a swept box against buildings, barriers, pillars
-- and the link road rails). The Hakone pass guardrails are handled separately with the road geometry.
local World = {}

local map = workspace:WaitForChild("KaidoMap")
local city = map:WaitForChild("City", 30)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { map:WaitForChild("Road"), city and city:WaitForChild("Ground") or map, workspace.Terrain }
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
wallParams.FilterDescendantsInstances = { city and city:WaitForChild("Solid") or map }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = wallParams.FilterDescendantsInstances

-- ground below (x, z) starting a little above y; returns height and surface normal, or nil
function World.ground(x: number, y: number, z: number): (number?, Vector3?)
	-- surfaces more than 3.2 studs above the car (a ramp or deck overhead) are skipped, not treated as ground
	local top = y + 7
	for _ = 1, 4 do
		local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top - y) - 73, 0), groundParams)
		if not hit then return nil, nil end
		if hit.Position.Y <= y + 3.2 then return hit.Position.Y, hit.Normal end
		top = hit.Position.Y - 0.6
		if top <= y - 70 then return nil, nil end
	end
	return nil, nil
end

-- sweep the car's box (size in studs, at height y) from a to b; returns the first wall hit
function World.sweep(a: Vector3, b: Vector3, heading: number, size: Vector3): RaycastResult?
	local d = b - a
	if d.Magnitude < 1e-3 then return nil end
	local fwd = Vector3.new(math.sin(heading), 0, math.cos(heading))
	local cf = CFrame.lookAt(a, a + fwd)
	local ok, hit = pcall(workspace.Blockcast, workspace, cf, size, d, wallParams)
	return ok and hit or nil
end

-- if the car's box overlaps any wall, the smallest push (in the ground plane) that moves it clear, plus the
-- wall's outward normal. Separating-axis test of the car's box against each part's box, seen from above.
function World.pushOut(p: Vector3, heading: number, size: Vector3): (Vector3?, Vector3?)
	local fx, fz = math.sin(heading), math.cos(heading)
	local hl, hw = size.Z / 2, size.X / 2
	local parts = workspace:GetPartBoundsInBox(CFrame.lookAt(p, p + Vector3.new(fx, 0, fz)), size, overlap)
	local total, normal = Vector3.zero, nil
	for _, part in parts do
		local cf, ps = part.CFrame, part.Size
		local r, l = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z), Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		if r.Magnitude < 0.2 or l.Magnitude < 0.2 then continue end -- lying on its side: not a wall seen from above
		r, l = r.Unit, l.Unit
		local hx, hz = ps.X / 2, ps.Z / 2
		local dx, dz = p.X + total.X - cf.X, p.Z + total.Z - cf.Z
		local best, bx, bz = math.huge, 0, 0
		for _, ax in { { fx, fz }, { fz, -fx }, { r.X, r.Z }, { l.X, l.Z } } do
			local nx, nz = ax[1], ax[2]
			local rA = hl * math.abs(fx * nx + fz * nz) + hw * math.abs(fz * nx - fx * nz)
			local rB = hx * math.abs(r.X * nx + r.Z * nz) + hz * math.abs(l.X * nx + l.Z * nz)
			local d = dx * nx + dz * nz
			local o = rA + rB - math.abs(d)
			if o <= 0 then best = nil; break end
			if o < best then
				local sg = if d >= 0 then 1 else -1
				best, bx, bz = o, nx * sg, nz * sg
			end
		end
		if best then
			total += Vector3.new(bx, 0, bz) * (best + 0.03)
			normal = Vector3.new(bx, 0, bz)
		end
	end
	if normal then return total, normal end
	return nil, nil
end

return World
