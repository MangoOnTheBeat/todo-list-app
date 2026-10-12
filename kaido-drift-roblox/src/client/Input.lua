--!strict
-- Merges keyboard, gamepad and on-screen touch controls into one analog driving input.
local UserInputService = game:GetService("UserInputService")

local Input = {}

export type State = { throttle: number, brake: number, steer: number, handbrake: boolean }

Input.state = { throttle = 0, brake = 0, steer = 0, handbrake = false } :: State
-- written by the touch UI
Input.touch = { throttle = 0, brake = 0, steer = 0, handbrake = false, steerActive = false }
Input.lastDevice = "keyboard" -- "keyboard" | "gamepad" | "touch"

local kbSteer = 0

local function key(k: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(k)
end

local function deadzone(x: number, dz: number): number
	if math.abs(x) < dz then
		return 0
	end
	return math.sign(x) * (math.abs(x) - dz) / (1 - dz)
end

UserInputService.LastInputTypeChanged:Connect(function(t: Enum.UserInputType)
	if t == Enum.UserInputType.Touch then
		Input.lastDevice = "touch"
	elseif string.sub(t.Name, 1, 7) == "Gamepad" then
		Input.lastDevice = "gamepad"
	elseif t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseMovement then
		Input.lastDevice = "keyboard"
	end
end)

function Input.update(dt: number): State
	local typing = UserInputService:GetFocusedTextBox() ~= nil

	-- keyboard
	local kThrottle, kBrake, kHand, kTarget = 0, 0, false, 0
	if not typing then
		if key(Enum.KeyCode.W) or key(Enum.KeyCode.Up) then
			kThrottle = 1
		end
		if key(Enum.KeyCode.S) or key(Enum.KeyCode.Down) then
			kBrake = 1
		end
		if key(Enum.KeyCode.A) or key(Enum.KeyCode.Left) then
			kTarget -= 1
		end
		if key(Enum.KeyCode.D) or key(Enum.KeyCode.Right) then
			kTarget += 1
		end
		kHand = key(Enum.KeyCode.Space)
	end
	-- digital steering ramps in, snaps back faster
	local rate = if kTarget == 0 or math.sign(kTarget) ~= math.sign(kbSteer) then 7 else 3.2
	kbSteer += math.clamp(kTarget - kbSteer, -rate * dt, rate * dt)

	-- gamepad
	local gThrottle, gBrake, gSteer, gHand = 0, 0, 0, false
	if UserInputService.GamepadEnabled then
		for _, io in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			local kc = io.KeyCode
			if kc == Enum.KeyCode.ButtonR2 then
				gThrottle = io.Position.Z
			elseif kc == Enum.KeyCode.ButtonL2 then
				gBrake = io.Position.Z
			elseif kc == Enum.KeyCode.Thumbstick1 then
				gSteer = deadzone(io.Position.X, 0.12)
			elseif (kc == Enum.KeyCode.ButtonB or kc == Enum.KeyCode.ButtonX or kc == Enum.KeyCode.ButtonR1) and io.UserInputState == Enum.UserInputState.Begin then
				gHand = true
			elseif kc == Enum.KeyCode.ButtonA and io.UserInputState == Enum.UserInputState.Begin then
				gThrottle = math.max(gThrottle, 1)
			end
		end
	end

	local t = Input.touch
	local s = Input.state
	s.throttle = math.clamp(math.max(kThrottle, gThrottle, t.throttle), 0, 1)
	s.brake = math.clamp(math.max(kBrake, gBrake, t.brake), 0, 1)
	local steer = kbSteer
	if math.abs(gSteer) > math.abs(steer) then
		steer = gSteer
	end
	if t.steerActive then
		steer = t.steer
	end
	s.steer = math.clamp(steer, -1, 1)
	s.handbrake = kHand or gHand or t.handbrake
	return s
end

function Input.reset()
	kbSteer = 0
	local s = Input.state
	s.throttle, s.brake, s.steer, s.handbrake = 0, 0, 0, false
end

return Input
