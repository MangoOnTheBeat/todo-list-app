-- Kaido Drift (Roblox): cars, paints, assist levels, graphics levels and settings.
local Config = {}

Config.ROAD_HALF = 16 -- half the road width in studs
Config.SEG = 10 -- road sample spacing in studs

-- the 13 cars from the browser game (see Cars.luau)
Config.Cars = require(script.Parent.Cars)

-- free paints (index 0 = the car's own colour)
Config.Paints = {
	Color3.fromRGB(236, 236, 240), Color3.fromRGB(18, 18, 22), Color3.fromRGB(196, 28, 36), Color3.fromRGB(255, 126, 182),
	Color3.fromRGB(89, 227, 255), Color3.fromRGB(30, 70, 190), Color3.fromRGB(240, 120, 20), Color3.fromRGB(255, 201, 77),
	Color3.fromRGB(40, 120, 70), Color3.fromRGB(120, 124, 132), Color3.fromRGB(90, 40, 140), Color3.fromRGB(150, 20, 40),
}

-- Drift assist levels, easiest first. Every level uses the same tyre physics.
Config.Assists = {
	{ id = "touch", name = "Easy drift", desc = "Best for touch: auto drift entry, throttle feed, countersteer", counter = 1.0, entry = 1.0, thrMod = true, damp = 2.4, esp = 6, espAngle = 1.05, tcs = false, speedSteer = true, steerRate = 9 },
	{ id = "high", name = "High", desc = "Auto countersteer, stability, traction control", counter = 0.95, entry = 0.7, thrMod = true, damp = 2.8, esp = 8, espAngle = 0.95, tcs = true, speedSteer = true, steerRate = 9 },
	{ id = "std", name = "Medium", desc = "Auto countersteer, stability", counter = 0.7, entry = 0.5, thrMod = false, damp = 1.6, esp = 4, espAngle = 1.15, tcs = false, speedSteer = true, steerRate = 7.5 },
	{ id = "low", name = "Low", desc = "Light countersteer only", counter = 0.35, entry = 0.3, thrMod = false, damp = 0.6, esp = 0, espAngle = 9, tcs = false, speedSteer = true, steerRate = 6 },
	{ id = "off", name = "Pro", desc = "No assists, pure simulation", counter = 0, entry = 0, thrMod = false, damp = 0, esp = 0, espAngle = 9, tcs = false, speedSteer = false, steerRate = 4.5 },
}

-- Graphics levels (applied on each player's own device)
Config.Quality = {
	low = { trees = 1, lights = 3, shadows = false, bloom = false, smoke = 0.5 },
	medium = { trees = 2, lights = 2, shadows = true, bloom = false, smoke = 0.8 },
	high = { trees = 3, lights = 1, shadows = true, bloom = true, smoke = 1 },
}

Config.DefaultSettings = { quality = "auto", time = 0, trans = "auto", assist = "", cam = 0, sens = 1, sound = true, volume = 0.8 }

-- keep whatever a client sends to safe values
function Config.cleanSettings(t)
	local d = Config.DefaultSettings
	t = type(t) == "table" and t or {}
	local out = {}
	out.quality = (t.quality == "low" or t.quality == "medium" or t.quality == "high") and t.quality or "auto"
	out.time = type(t.time) == "number" and t.time == t.time and math.clamp(t.time, 0, 23.75) or d.time
	out.trans = t.trans == "manual" and "manual" or "auto"
	out.assist = ""
	for _, a in Config.Assists do if t.assist == a.id then out.assist = a.id end end
	out.cam = type(t.cam) == "number" and math.clamp(math.floor(t.cam), 0, 3) or 0
	out.sens = type(t.sens) == "number" and t.sens == t.sens and math.clamp(t.sens, 0.5, 1.6) or 1
	out.sound = t.sound ~= false
	out.volume = type(t.volume) == "number" and t.volume == t.volume and math.clamp(t.volume, 0, 1) or d.volume
	return out
end

function Config.car(id: string)
	for _, c in Config.Cars do
		if c.id == id then return c end
	end
	return Config.Cars[1]
end

function Config.assist(id: string)
	for _, a in Config.Assists do
		if a.id == id then return a end
	end
	return Config.Assists[3]
end

-- physics numbers for a car (drag set so top speed matches)
function Config.physics(c)
	local top = c.top / 3.6 * 3.5
	return { power = c.power, grip = c.grip, drag = c.power / (top ^ 3), lock = c.lock, top = top, gears = c.gears, red = c.red,
		a = c.wb * (1 - c.front), b = c.wb * c.front }
end

return Config
