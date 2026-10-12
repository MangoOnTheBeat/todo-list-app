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
	local hit = workspace:Raycast(Vector3.new(x, y + 7, z), Vector3.new(0, -80, 0), groundParams)
	if hit then return hit.Position.Y, hit.Normal end
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

-- is the box already inside a wall (after turning on the spot)?
function World.inside(p: Vector3, heading: number, size: Vector3): BasePart?
	local fwd = Vector3.new(math.sin(heading), 0, math.cos(heading))
	local parts = workspace:GetPartBoundsInBox(CFrame.lookAt(p, p + fwd), size, overlap)
	return parts[1]
end

return World
