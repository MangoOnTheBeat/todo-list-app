-- ===== client environment =====
local plrs = game:GetService("Players")
LOCALPLAYER = Instance.new("Player"); LOCALPLAYER.Name = "Tester"; LOCALPLAYER.UserId = 77; LOCALPLAYER.DisplayName = "Tester"
local pg = Instance.new("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = LOCALPLAYER
rawset(plrs, "LocalPlayer", LOCALPLAYER)
PLAYERS = { LOCALPLAYER }
rawset(plrs, "GetPlayers", function() return table.clone(PLAYERS) end)
rawset(plrs, "GetPlayerByUserId", function(_, id) for _, p in PLAYERS do if p.UserId == id then return p end end return nil end)
plrs.PlayerAdded:Fire(LOCALPLAYER)
local camera = Instance.new("Camera"); camera.ViewportSize = Vector2.new(1280, 720); camera.CFrame = CFrame.identity; camera.FieldOfView = 70
rawset(workspace, "CurrentCamera", camera)
local UIS = game:GetService("UserInputService")
KEYS = {}
rawset(UIS, "IsKeyDown", function(_, k) return KEYS[k] == true end)
rawset(UIS, "IsMouseButtonPressed", function() return false end)
rawset(UIS, "IsGamepadButtonDown", function() return false end)
rawset(UIS, "GetFocusedTextBox", function() return nil end)
rawset(UIS, "GetGamepadState", function() return {} end)
rawset(UIS, "TouchEnabled", false); rawset(UIS, "KeyboardEnabled", true); rawset(UIS, "GamepadEnabled", false); rawset(UIS, "MouseEnabled", true)
rawset(workspace, "Raycast", function(_, o, d) return { Position = Vector3.new(o.X, 6.6, o.Z), Normal = Vector3.yAxis, Distance = 1, Instance = workspace } end)
rawset(workspace, "Blockcast", function() return nil end)
rawset(workspace, "GetPartBoundsInBox", function() return {} end)
-- from here on, background tasks run (each loop yields once and is then dropped)
local function run(f, ...)
	local co = coroutine.create(f)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error("task error: " .. tostring(err)) end
end
task.spawn = run
task.defer = run
task.delay = function(_, f, ...) if type(f) == "function" then run(f, ...) end end
task.wait = function() if coroutine.isyieldable() then coroutine.yield() end return 0 end
-- a sound inserted from the Toolbox (not the game's own files)
local tb = Instance.new("Sound"); tb.Name = "Car Engine Loop"; tb.SoundId = "rbxassetid://123"; tb.Parent = workspace
local tb2 = Instance.new("Sound"); tb2.Name = "Tire Screech"; tb2.SoundId = "rbxassetid://456"; tb2.Parent = workspace
rawset(workspace, "GetServerTimeNow", function() return os.time() end)
