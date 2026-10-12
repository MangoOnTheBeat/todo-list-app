-- Kaido Drift (Roblox): shared settings. Cars come from the browser game (Cars.luau); physics and assist
-- numbers live in CarPhysics, exactly as in the browser.
local Config = {}

Config.ROAD_HALF = 16 -- half the pass road width (studs)
Config.SEG = 10 -- pass road sample spacing (studs)
Config.SCALE = 3.5 -- studs per metre for cars and physics

Config.Cars = require(script.Parent.Cars)

-- free paints (index 0 = the car's own colour)
Config.Paints = {
	Color3.fromHex("e9e6df"), Color3.fromHex("111114"), Color3.fromHex("c81e2c"), Color3.fromHex("ff7eb6"),
	Color3.fromHex("59e3ff"), Color3.fromHex("2a54c8"), Color3.fromHex("ff6a00"), Color3.fromHex("ffcc00"),
	Color3.fromHex("2f6b46"), Color3.fromHex("7c8088"), Color3.fromHex("5a2a8c"), Color3.fromHex("8c1d2a"),
}

-- assist levels (names and descriptions as in the browser settings)
Config.Assists = {
	{ id = "touch", name = "Easy drift", desc = "Best for touch: auto drift entry, throttle feed, countersteer" },
	{ id = "high", name = "High", desc = "Auto countersteer, stability, traction control" },
	{ id = "std", name = "Medium", desc = "Auto countersteer, stability" },
	{ id = "low", name = "Low", desc = "Light countersteer only" },
	{ id = "off", name = "Pro", desc = "No assists, pure simulation" },
}

-- graphics levels (applied on each player's own device)
Config.Quality = {
	low = { trees = 1, lights = 4, shadows = false, bloom = false, smoke = 0.5, windows = 1, signs = false },
	medium = { trees = 2, lights = 2, shadows = true, bloom = false, smoke = 0.8, windows = 2, signs = true },
	high = { trees = 3, lights = 1, shadows = true, bloom = true, smoke = 1, windows = 3, signs = true },
}

Config.DefaultSettings = { quality = "auto", time = 0, trans = "auto", assist = "", cam = 0, sens = 1, sound = true, volume = 0.8, start = "pass" }

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
	out.start = t.start == "city" and "city" or "pass"
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

return Config
