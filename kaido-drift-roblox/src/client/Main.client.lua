--!strict
-- Kaido Drift client entry: menu flow, driving loop, drift banking, camera and HUD updates.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local Cars = require(Shared:WaitForChild("Cars"))

local here = script.Parent
local Input = require(here:WaitForChild("Input"))
local Drive = require(here:WaitForChild("Drive"))
local Drift = require(here:WaitForChild("Drift"))
local CameraRig = require(here:WaitForChild("CameraRig"))
local Visuals = require(here:WaitForChild("Visuals"))
local UI = require(here:WaitForChild("UI"))

-- the game drives the character itself; keep Roblox's walk/jump controls (and touch jump button) off
task.spawn(function()
	local ok, err = pcall(function()
		local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		PlayerModule:GetControls():Disable()
	end)
	if not ok then
		warn("[Kaido] could not disable default controls:", err)
	end
end)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

CameraRig.start()
Visuals.start()
UI.showTitle()
UI.setMapReady(Workspace:GetAttribute("MapReady") == true)
Workspace:GetAttributeChangedSignal("MapReady"):Connect(function()
	UI.setMapReady(Workspace:GetAttribute("MapReady") == true)
end)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetProfile = remotes:WaitForChild("GetProfile") :: RemoteFunction
local BuyCar = remotes:WaitForChild("BuyCar") :: RemoteFunction
local SelectCar = remotes:WaitForChild("SelectCar") :: RemoteFunction
local SetEasyDrift = remotes:WaitForChild("SetEasyDrift") :: RemoteEvent
local RequestSpawn = remotes:WaitForChild("RequestSpawn") :: RemoteEvent
local Despawn = remotes:WaitForChild("Despawn") :: RemoteEvent
local CarState = remotes:WaitForChild("CarState") :: RemoteEvent
local BankDrift = remotes:WaitForChild("BankDrift") :: RemoteEvent
local ProfileChanged = remotes:WaitForChild("ProfileChanged") :: RemoteEvent
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent

local profile: any = GetProfile:InvokeServer()
if profile then
	UI.setProfile(profile)
end
ProfileChanged.OnClientEvent:Connect(function(p)
	profile = p
	UI.setProfile(p)
end)
Notify.OnClientEvent:Connect(function(text)
	if type(text) == "string" then
		UI.notice(text)
	end
end)

local mode: string = "title" -- "title" | "garage" | "spawning" | "driving"
local myCar: Model? = nil
local carsFolder = Workspace:WaitForChild("Cars")
local wallFolders: { Instance } = {}
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
local touchConn: RBXScriptConnection? = nil
local lastCrash = 0
local lastSpeed = 0

local function bank(result: Drift.Result?)
	if not result then
		return
	end
	if result.kind == "bank" then
		BankDrift:FireServer(result.points, result.duration)
		UI.toast(string.format("%s  +%s  ·  CR +%s", result.tier, UI.fmt(result.points), UI.fmt(result.credits)), Config.COLORS.gold)
	else
		UI.toast(string.format("CRASH  ·  %s lost", UI.fmt(result.points)), Config.COLORS.danger)
	end
end

local function crash()
	local now = os.clock()
	if now - lastCrash < 0.5 then
		return
	end
	lastCrash = now
	bank(Drift.crash())
end

local function stopDriving()
	bank(Drift.finish())
	Drive.stop()
	if touchConn then
		touchConn:Disconnect()
		touchConn = nil
	end
	myCar = nil
	CameraRig.target = nil
	CameraRig.setMode("title")
end

local function startDriving(model: Model)
	myCar = model
	mode = "driving"
	local chassis = model:WaitForChild("Chassis") :: BasePart
	Drive.start(model, profile == nil or profile.easyDrift ~= false)
	local spec = Cars.get(model:GetAttribute("CarId") :: string?)
	CameraRig.seat = CarBuilder.geometry(spec).seat
	CameraRig.target = model
	CameraRig.setMode("chase")
	UI.showHUD()
	local map = Workspace:WaitForChild("KaidoMap")
	wallFolders = {}
	for _, name in { "Rails", "Lamps", "Trees", "Village" } do
		local f = map:FindFirstChild(name)
		if f then
			table.insert(wallFolders, f)
		end
	end
	wallParams.FilterDescendantsInstances = { map:FindFirstChild("Rails") :: Instance }
	touchConn = chassis.Touched:Connect(function(hit)
		for _, f in wallFolders do
			if hit:IsDescendantOf(f) then
				crash()
				return
			end
		end
	end)
	UI.toast("GO", Config.COLORS.sakura)
end

-- our car shows up in workspace.Cars after RequestSpawn
carsFolder.ChildAdded:Connect(function(child: Instance)
	if mode == "spawning" and child:IsA("Model") and child:GetAttribute("Owner") == player.UserId then
		startDriving(child)
	end
end)
carsFolder.ChildRemoved:Connect(function(child)
	if child == myCar then
		stopDriving()
		mode = "title"
		UI.showTitle()
	end
end)

-- ---------------------------------------------------------------- menu callbacks
UI.callbacks.play = function()
	if mode ~= "title" then
		return
	end
	mode = "spawning"
	RequestSpawn:FireServer()
	task.delay(5, function()
		if (mode :: string) == "spawning" then
			mode = "title"
			UI.toast("Could not spawn, try again", Config.COLORS.danger)
		end
	end)
end
UI.callbacks.garage = function()
	mode = "garage"
	UI.showGarage()
end
UI.callbacks.back = function()
	mode = "title"
	UI.showTitle()
end
UI.callbacks.buy = function(id)
	local ok, res = BuyCar:InvokeServer(id)
	if ok then
		profile = res
		UI.setProfile(res)
		UI.garageMessage("")
	else
		UI.garageMessage(tostring(res))
	end
end
UI.callbacks.select = function(id)
	local ok, res = SelectCar:InvokeServer(id)
	if ok then
		profile = res
		UI.setProfile(res)
	end
end
UI.callbacks.easy = function()
	if not profile then
		return
	end
	profile.easyDrift = not profile.easyDrift
	SetEasyDrift:FireServer(profile.easyDrift)
	Drive.easyDrift = profile.easyDrift
	UI.setProfile(profile)
end
UI.callbacks.menu = function()
	if mode == "driving" then
		stopDriving()
		Despawn:FireServer()
	end
	mode = "title"
	UI.showTitle()
end
UI.callbacks.camera = function()
	CameraRig.toggle()
end
UI.callbacks.reset = function()
	if mode == "driving" then
		Drift.cancel()
		Drive.respawn()
	end
end

-- keyboard / gamepad shortcuts (sunk so the default camera/character don't react)
ContextActionService:BindAction("KaidoCamera", function(_, state)
	if state == Enum.UserInputState.Begin and mode == "driving" then
		CameraRig.toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("KaidoReset", function(_, state)
	if state == Enum.UserInputState.Begin then
		UI.callbacks.reset()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonSelect)
ContextActionService:BindActionAtPriority("KaidoSinkJump", function()
	return if mode == "driving" then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

-- ---------------------------------------------------------------- per-frame
local stateTimer = 0
RunService.Heartbeat:Connect(function(dt)
	if mode ~= "driving" or not myCar or not myCar.PrimaryPart then
		return
	end
	local tel = Drive.telemetry
	local chassis = myCar.PrimaryPart :: BasePart

	-- crash by sudden stop (walls the touch event may miss)
	if lastSpeed > 40 and tel.kmh < lastSpeed * 0.55 then
		crash()
	end
	lastSpeed = tel.kmh

	local cf = chassis.CFrame
	local nearWall = false
	if Drift.active then
		for _, s in { -1, 1 } do
			if Workspace:Raycast(cf.Position, cf.RightVector * s * 9, wallParams) then
				nearWall = true
			end
		end
	end
	local tandem = Drift.active and Visuals.tandem(cf.Position, 30)
	bank(Drift.update(dt, tel.kmh, tel.slipDeg, tel.forward, nearWall, tandem))
	UI.updateHUD(tel, Drift, myCar)

	stateTimer += dt
	if stateTimer > 0.1 then
		stateTimer = 0
		CarState:FireServer(tel.steerNorm, tel.rpm, Drift.active)
	end
	local _ = Input
end)
