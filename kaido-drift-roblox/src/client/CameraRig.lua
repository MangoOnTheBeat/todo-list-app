--!strict
-- Title orbit, chase cam (leans toward the direction of travel while sliding) and cockpit cam.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraRig = {}

CameraRig.mode = "title" -- "title" | "chase" | "cockpit"
CameraRig.target = nil :: Model?
CameraRig.seat = Vector3.new(1, 2, 0) -- driver head, chassis space

local camera = Workspace.CurrentCamera
local smoothCF: CFrame? = nil
local orbit = 0
local lookYaw = 0
local camParams = RaycastParams.new()
camParams.FilterType = Enum.RaycastFilterType.Include

local function setCharacterHidden(hidden: boolean)
	local char = Players.LocalPlayer.Character
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function CameraRig.setMode(mode: string)
	CameraRig.mode = mode
	smoothCF = nil
	setCharacterHidden(mode == "cockpit")
end

function CameraRig.toggle()
	if CameraRig.mode == "chase" then
		CameraRig.setMode("cockpit")
	elseif CameraRig.mode == "cockpit" then
		CameraRig.setMode("chase")
	end
end

local function update(dt: number)
	camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local mode = CameraRig.mode
	local car = CameraRig.target
	local chassis = car and car.PrimaryPart
	if mode == "title" or not chassis then
		orbit += dt * 0.06
		local centre = Vector3.new(40, 18, 0)
		local pos = centre + Vector3.new(math.cos(orbit) * 150, 42, math.sin(orbit) * 150)
		camera.CFrame = CFrame.lookAt(pos, centre)
		camera.FieldOfView = 60
		return
	end
	local cf = chassis.CFrame
	local v = chassis.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if mode == "cockpit" then
		setCharacterHidden(true)
		-- glance a little into the slide
		local vLocal = cf:VectorToObjectSpace(v)
		local slip = if -vLocal.Z > 3 then math.atan2(vLocal.X, -vLocal.Z) else 0
		lookYaw += (math.clamp(-slip * 0.5, -0.6, 0.6) - lookYaw) * math.min(1, dt * 4)
		camera.CFrame = cf * CFrame.new(CameraRig.seat) * CFrame.Angles(0, lookYaw, 0) * CFrame.Angles(math.rad(-4), 0, 0)
		camera.FieldOfView = 72 + math.min(speed * 0.06, 12)
		return
	end
	-- chase: blend car heading with velocity heading so drifts show the car's angle
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flatLook.Magnitude < 0.1 then
		flatLook = Vector3.new(0, 0, -1)
	end
	flatLook = flatLook.Unit
	local dir = flatLook
	if speed > 6 then
		local vel = Vector3.new(v.X, 0, v.Z).Unit
		if vel:Dot(flatLook) > -0.2 then
			dir = (flatLook * 0.45 + vel * 0.55).Unit
		end
	end
	local base = chassis.Position
	local camPos = base - dir * 15 + Vector3.new(0, 5.2, 0)
	local map = Workspace:FindFirstChild("KaidoMap")
	if map then
		camParams.FilterDescendantsInstances = { Workspace.Terrain, map:FindFirstChild("Village") or map }
		local from = base + Vector3.new(0, 2.5, 0)
		local hit = Workspace:Raycast(from, camPos - from, camParams)
		if hit then
			camPos = hit.Position + (from - camPos).Unit * 0.8
		end
	end
	local desired = CFrame.lookAt(camPos, base + dir * 6 + Vector3.new(0, 1.6, 0))
	local prev = smoothCF or desired
	local a = 1 - math.exp(-dt * 7)
	local pos = prev.Position:Lerp(desired.Position, a)
	local look = prev.LookVector:Lerp(desired.LookVector, 1 - math.exp(-dt * 9))
	smoothCF = CFrame.lookAt(pos, pos + look)
	camera.CFrame = smoothCF :: CFrame
	camera.FieldOfView = 70 + math.min(speed * 0.1, 18)
end

function CameraRig.start()
	RunService:BindToRenderStep("KaidoCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraRig
