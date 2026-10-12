--!strict
-- Kaido Drift server: lighting, map, player data, car spawning, drift banking, leaderboard.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local Track = require(Shared:WaitForChild("Track"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))

-- ---------------------------------------------------------------- world settings
Workspace.Gravity = Config.GRAVITY
Lighting.ClockTime = 0
Lighting.GeographicLatitude = 35
Lighting.Brightness = 1.2
Lighting.Ambient = Color3.fromRGB(18, 20, 34)
Lighting.OutdoorAmbient = Color3.fromRGB(40, 46, 72)
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.25
Lighting.GlobalShadows = true
-- Lighting.Technology cannot be set from a script; default.project.json sets it to Future.
for _, c in Lighting:GetChildren() do
	if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
		c:Destroy()
	end
end
local sky = Instance.new("Sky")
sky.StarCount = 5000
sky.CelestialBodiesShown = true
sky.MoonAngularSize = 14
sky.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.12
atmosphere.Color = Color3.fromRGB(60, 70, 110)
atmosphere.Decay = Color3.fromRGB(20, 22, 40)
atmosphere.Glare = 0
atmosphere.Haze = 1.4
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.4
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.08
cc.Saturation = 0.05
cc.TintColor = Color3.fromRGB(235, 236, 255)
cc.Parent = Lighting

-- ---------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function rf(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = remotes
	return r
end
local function re(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local GetProfile = rf("GetProfile")
local BuyCar = rf("BuyCar")
local SelectCar = rf("SelectCar")
local SetEasyDrift = re("SetEasyDrift")
local RequestSpawn = re("RequestSpawn")
local Despawn = re("Despawn")
local CarState = re("CarState")
local BankDrift = re("BankDrift")
local ProfileChanged = re("ProfileChanged")
local Notify = re("Notify")


local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = Workspace

-- ---------------------------------------------------------------- map
Players.CharacterAutoLoads = false
Workspace:SetAttribute("MapReady", false)
local mapInfo = MapBuilder.build()
Workspace:SetAttribute("MapReady", true)
Players.CharacterAutoLoads = true
Leaderboard.start(mapInfo.boardPos)

-- ---------------------------------------------------------------- players
local activeCar: { [Player]: Model } = {}
local lastBank: { [Player]: number } = {}

local function snapshot(p: PlayerData.Profile): { [string]: any }
	local owned = {}
	for id in p.owned do
		table.insert(owned, id)
	end
	return { credits = p.credits, owned = owned, selected = p.selected, best = p.best, total = p.total, easyDrift = p.easyDrift }
end

local function pushProfile(player: Player)
	local p = PlayerData.get(player)
	if p then
		Leaderboard.update(player, p.best, p.credits)
		ProfileChanged:FireClient(player, snapshot(p))
	end
end

local function removeCar(player: Player)
	local car = activeCar[player]
	activeCar[player] = nil
	if car then
		car:Destroy()
	end
end

local function spawnSlot(): CFrame
	local d = Track.build()
	for row = 0, 7 do
		local i = (d.n - 3 - row * 2 - 1) % d.n + 1
		local p = Vector3.new(d.x[i], d.y[i], d.z[i])
		local t = Vector3.new(d.tx[i], 0, d.tz[i])
		local r = Vector3.new(-t.Z, 0, t.X)
		for _, lane in { -6.5, 6.5 } do
			local pos = p + r * lane
			local free = true
			for _, c in carsFolder:GetChildren() do
				if c:IsA("Model") and (c:GetPivot().Position - pos).Magnitude < 14 then
					free = false
				end
			end
			if free then
				return CFrame.lookAt(pos + Vector3.new(0, 0.3, 0), pos + t + Vector3.new(0, 0.3, 0))
			end
		end
	end
	local p = Vector3.new(d.x[1], d.y[1] + 6, d.z[1])
	return CFrame.lookAt(p, p + Vector3.new(d.tx[1], 0, d.tz[1]))
end

local function spawnCar(player: Player)
	if not Workspace:GetAttribute("MapReady") then
		return
	end
	local profile = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	removeCar(player)
	local spec = Cars.get(profile.selected)
	local model = CarBuilder.build(spec, spawnSlot())
	model.Name = player.Name
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Steer", 0)
	model:SetAttribute("Rpm", 900)
	model:SetAttribute("Drift", false)
	model.Parent = carsFolder
	activeCar[player] = model
	local seat = model:FindFirstChild("DriverSeat") :: Seat
	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	local chassis = model.PrimaryPart :: BasePart
	task.defer(function()
		if chassis.Parent and player.Parent then
			pcall(function()
				chassis:SetNetworkOwner(player)
			end)
		end
	end)
end

local function onCharacter(player: Player, character: Model)
	removeCar(player)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.Died:Connect(function()
		removeCar(player)
	end)
end

local function onPlayer(player: Player)
	local profile = PlayerData.load(player)
	if player.Parent ~= Players then
		PlayerData.release(player)
		return
	end
	Leaderboard.setup(player, profile.best, profile.credits)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	pushProfile(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayer, p)
end
-- characters that were held back while the map was building
for _, p in Players:GetPlayers() do
	task.spawn(function()
		p:LoadCharacter()
	end)
end

Players.PlayerRemoving:Connect(function(player)
	removeCar(player)
	Leaderboard.flush(player)
	PlayerData.release(player)
	lastBank[player] = nil
end)

game:BindToClose(function()
	PlayerData.saveAll()
end)

-- ---------------------------------------------------------------- remote handlers
GetProfile.OnServerInvoke = function(player)
	local p = PlayerData.get(player)
	while not p and player.Parent do
		task.wait(0.2)
		p = PlayerData.get(player)
	end
	return if p then snapshot(p) else nil
end

BuyCar.OnServerInvoke = function(player, id)
	local p = PlayerData.get(player)
	if not p or type(id) ~= "string" then
		return false, "Not ready"
	end
	local spec = Cars.byId[id]
	if not spec then
		return false, "Unknown car"
	end
	if p.owned[id] then
		return false, "Already owned"
	end
	if p.credits < spec.price then
		return false, "Not enough credits"
	end
	p.credits -= spec.price
	p.owned[id] = true
	p.selected = id
	PlayerData.markDirty(player)
	task.spawn(PlayerData.save, player)
	pushProfile(player)
	return true, snapshot(p)
end

SelectCar.OnServerInvoke = function(player, id)
	local p = PlayerData.get(player)
	if not p or type(id) ~= "string" or not p.owned[id] then
		return false, "Not owned"
	end
	p.selected = id
	PlayerData.markDirty(player)
	pushProfile(player)
	return true, snapshot(p)
end

SetEasyDrift.OnServerEvent:Connect(function(player, on)
	local p = PlayerData.get(player)
	if p and type(on) == "boolean" then
		p.easyDrift = on
		PlayerData.markDirty(player)
	end
end)

RequestSpawn.OnServerEvent:Connect(function(player)
	spawnCar(player)
end)

Despawn.OnServerEvent:Connect(function(player)
	removeCar(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid then
		humanoid.Sit = false
		local spawn = Workspace:FindFirstChild("VillageSpawn", true) :: BasePart?
		if spawn then
			character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0))
		end
	end
end)

local lastState: { [Player]: number } = {}
CarState.OnServerEvent:Connect(function(player, steer, rpm, drifting)
	local now = os.clock()
	if (lastState[player] or 0) > now - 0.05 then
		return
	end
	lastState[player] = now
	local car = activeCar[player]
	if not car or type(steer) ~= "number" or type(rpm) ~= "number" then
		return
	end
	car:SetAttribute("Steer", math.clamp(steer, -1.2, 1.2))
	car:SetAttribute("Rpm", math.clamp(rpm, 0, 10000))
	car:SetAttribute("Drift", drifting == true)
end)

BankDrift.OnServerEvent:Connect(function(player, score, duration)
	local p = PlayerData.get(player)
	if not p or type(score) ~= "number" or type(duration) ~= "number" or score ~= score then
		return
	end
	if not activeCar[player] then
		return
	end
	local now = os.clock()
	local since = now - (lastBank[player] or 0)
	duration = math.clamp(duration, 0, math.min(since + 2, 180))
	-- generous plausibility cap: ~30k points per second at the 5x multiplier ceiling
	score = math.clamp(math.floor(score), 0, math.floor(duration * 30000 * Config.DRIFT_MULT_MAX))
	if score < Config.DRIFT_MIN_BANK then
		return
	end
	lastBank[player] = now
	local credits = math.floor(score * Config.CREDITS_PER_POINT)
	p.credits += credits
	p.total += score
	local newBest = score > p.best
	if newBest then
		p.best = score
		Leaderboard.submit(player, score)
		if score >= 3000 then
			Notify:FireAllClients(string.format("%s set a new best drift: %s", player.DisplayName, Leaderboard.fmt(score)))
		end
	end
	PlayerData.markDirty(player)
	pushProfile(player)
end)

-- parent last so clients only see the remotes once every handler is connected
remotes.Parent = ReplicatedStorage
print("[Kaido] server ready")
