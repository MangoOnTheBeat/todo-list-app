--!strict
-- Drift scoring, same rules as the browser game: while sliding > 10° above 25 km/h,
-- score += km/h × angle × 0.5 per second (× bonus tags); the multiplier grows +0.5 every 1.6 s
-- held (max ×5). The drift banks as credits after 1.4 s of not sliding, and is lost on a wall hit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))

local Drift = {}

Drift.active = false
Drift.score = 0
Drift.time = 0
Drift.idle = 0
Drift.mult = 1
Drift.tags = {} :: { string }

export type Result = { kind: "bank" | "lost", points: number, credits: number, tier: string, duration: number }

local function reset()
	Drift.active = false
	Drift.score = 0
	Drift.time = 0
	Drift.idle = 0
	Drift.mult = 1
	table.clear(Drift.tags)
end

function Drift.total(): number
	return math.floor(Drift.score * Drift.mult)
end

-- Returns a Result when a drift ends this frame.
function Drift.update(dt: number, kmh: number, slipDeg: number, forward: number, nearWall: boolean, tandem: boolean): Result?
	local angle = math.min(math.abs(slipDeg), 90)
	local drifting = angle > Config.DRIFT_MIN_ANGLE and kmh > Config.DRIFT_MIN_KMH and forward > 0
	if drifting then
		if not Drift.active then
			reset()
			Drift.active = true
		end
		Drift.idle = 0
		Drift.time += dt
		local bonus = 1
		table.clear(Drift.tags)
		if tandem then
			bonus *= 1.5
			table.insert(Drift.tags, "TANDEM")
		end
		if nearWall then
			bonus *= 1.35
			table.insert(Drift.tags, "NEAR WALL")
		end
		if angle > 45 then
			bonus *= 1.15
			table.insert(Drift.tags, "ANGLE")
		end
		if kmh > 110 then
			bonus *= 1.15
			table.insert(Drift.tags, "SPEED")
		end
		Drift.mult = math.min(Config.DRIFT_MULT_MAX, 1 + math.floor(Drift.time / Config.DRIFT_MULT_STEP) * 0.5)
		Drift.score += kmh * angle * 0.5 * dt * bonus
	elseif Drift.active then
		Drift.idle += dt
		if Drift.idle > Config.DRIFT_END_IDLE then
			return Drift.finish()
		end
	end
	return nil
end

function Drift.finish(): Result?
	if not Drift.active then
		return nil
	end
	local points = Drift.total()
	local duration = Drift.time + Drift.idle
	reset()
	if points < Config.DRIFT_MIN_BANK then
		return nil
	end
	return {
		kind = "bank",
		points = points,
		credits = math.floor(points * Config.CREDITS_PER_POINT),
		tier = Config.tierFor(points),
		duration = duration,
	}
end

function Drift.crash(): Result?
	if not Drift.active then
		return nil
	end
	local points = Drift.total()
	reset()
	return { kind = "lost", points = points, credits = 0, tier = "CRASH", duration = 0 }
end

function Drift.cancel()
	reset()
end

return Drift
