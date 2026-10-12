-- Kaido Drift (Roblox): shared settings. Cars come from the browser game (Cars.luau); physics and assist
-- numbers live in CarPhysics, exactly as in the browser.
local Config = {}

Config.ROAD_HALF = 22 -- half the pass road width (studs): a wide, two-car road
Config.SEG = 10 -- pass road sample spacing (studs)
Config.SCALE = 3.5 -- studs per metre for cars and physics

Config.Cars = require(script.Parent.Cars)

-- Special cars, sold for Robux as game passes. Each one beats the fastest credit car (JZA-80 Apex) and
-- uses a browser body. To put one on sale: Creator Hub › your game › Monetization › Passes › create a
-- pass at the price below, then paste its ID into `pass`. While `pass` is 0 the car shows "Coming soon".
-- `robux` must match the pass price you set on Roblox (100 or more; lower only for a marked deal).
local function special(base: string, t)
	local src
	for _, c in Config.Cars do if c.id == base then src = c end end
	local car = table.clone(src)
	for k, v in t do car[k] = v end
	car.mesh, car.premium = base, true
	car.price = 0
	return car
end
Config.Premium = {
	special("fd7", { id = "fd7x", name = "Akagi FD-7 Spirit Rotor", tag = "Special · 1,180 kg triple-rotor · screams to 9,500",
		pass = 0, robux = 149, color = Color3.fromHex("#e8f0ff"), rim = Color3.fromHex("#ff7eb6"),
		mass = 1180, torque = 640, peak = 6800, red = 9500, mu = 1.2, lock = 64 }),
	special("jza", { id = "jzax", name = "Kaze JZA-80 Apex Omega", tag = "Special · 1,000 hp twin-turbo six · fastest on the mountain",
		pass = 0, robux = 249, color = Color3.fromHex("#14141a"), rim = Color3.fromHex("#ffc94d"),
		mass = 1420, torque = 880, peak = 5200, red = 8200, mu = 1.22, lock = 65 }),
	special("r34", { id = "r34x", name = "Hoshi R-34 Raijin Z-Tune", tag = "Special · stroked twin-turbo · 6-speed · ultimate grip",
		pass = 0, robux = 399, color = Color3.fromHex("#9aa3b2"), rim = Color3.fromHex("#59e3ff"),
		mass = 1460, torque = 860, peak = 5000, red = 8600, mu = 1.26, lock = 66 }),
}
for _, c in Config.Premium do table.insert(Config.Cars, c) end

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

Config.DefaultSettings = { quality = "auto", time = 0, trans = "auto", assist = "", cam = 0, sens = 1, sound = true, volume = 0.8, start = "city", v = 2 }

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
	-- everyone starts in the city; the pass is kept only if picked after the city became the default (v2)
	out.start = (t.v == 2 and t.start == "pass") and "pass" or "city"
	out.v = 2
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
