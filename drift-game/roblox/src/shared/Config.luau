-- Kaido Drift (Roblox): cars and shared settings.
local Config = {}

Config.ROAD_HALF = 15 -- half the road width in studs
Config.SEG = 10 -- road segment length in studs

-- Fictional JDM-style cars. power = drive, grip = tyre grip, top = top speed (km/h), lock = steering lock (rad)
Config.Cars = {
	{ id = "ps13", name = "Hoshi PS13 Spirit", price = 0, power = 900, grip = 1.00, top = 190, lock = 0.62, color = Color3.fromRGB(236, 236, 240), wing = false },
	{ id = "ae8", name = "Kaze AE8 Trueno", price = 12000, power = 760, grip = 1.06, top = 175, lock = 0.66, color = Color3.fromRGB(240, 240, 240), wing = false, two = Color3.fromRGB(30, 30, 34) },
	{ id = "fc3", name = "Rota FC3 Seven", price = 25000, power = 1050, grip = 1.03, top = 205, lock = 0.64, color = Color3.fromRGB(196, 28, 36), wing = true },
	{ id = "jzx", name = "Toyo JZX Chaser", price = 45000, power = 1250, grip = 1.00, top = 220, lock = 0.62, color = Color3.fromRGB(28, 40, 74), wing = false },
	{ id = "z33", name = "Fair Z33", price = 60000, power = 1400, grip = 1.06, top = 235, lock = 0.63, color = Color3.fromRGB(240, 120, 20), wing = true },
	{ id = "r34", name = "Skyward R34", price = 95000, power = 1650, grip = 1.10, top = 250, lock = 0.62, color = Color3.fromRGB(30, 70, 190), wing = true },
}

function Config.car(id: string)
	for _, c in Config.Cars do
		if c.id == id then return c end
	end
	return Config.Cars[1]
end

-- physics numbers for a car (drag set so top speed matches)
function Config.physics(c)
	local top = c.top / 3.6 * 3.5
	return { power = c.power, grip = c.grip, drag = c.power / (top ^ 3), lock = c.lock }
end

return Config
