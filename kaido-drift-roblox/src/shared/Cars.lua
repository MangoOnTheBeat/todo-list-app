--!strict
-- Garage catalogue. Numbers come from the browser game's car list (kaido-drift.html).
-- torque Nm, peak/red rpm, mass kg, mu = tyre grip, lock = max steering degrees, CdA = drag area.
export type Body = {
	len: number, wid: number, h: number, wb: number,
	style: string, popups: boolean, wing: boolean, duck: boolean,
}
export type Car = {
	id: string, name: string, tag: string, price: number, color: Color3, rim: Color3,
	hp: number, torque: number, peak: number, red: number, mass: number, front: number,
	gears: { number }, final: number, mu: number, lock: number, CdA: number, turbo: boolean,
	b: Body,
}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end

local list: { Car } = {
	{
		id = "ps13", name = "Hoshi PS13 Spirit", tag = "Starter · 1.8 turbo four · pop-up lamps",
		price = 0, color = rgb("#e9e6df"), rim = rgb("#c3c6cc"),
		hp = 205, torque = 255, peak = 4000, red = 7200, mass = 1240, front = 0.53,
		gears = { 3.32, 1.9, 1.31, 1, 0.76 }, final = 4.08, mu = 1.03, lock = 48, CdA = 0.68, turbo = true,
		b = { len = 4.52, wid = 1.69, h = 1.29, wb = 2.47, style = "notch", popups = true, wing = false, duck = false },
	},
	{
		id = "ae8", name = "Kaze AE8 Hachi", tag = "Featherweight · revvy 1.6 · very agile",
		price = 8000, color = rgb("#f4f4f4"), rim = rgb("#2a2b30"),
		hp = 130, torque = 155, peak = 6000, red = 8200, mass = 925, front = 0.52,
		gears = { 3.59, 2.02, 1.38, 1, 0.86 }, final = 4.78, mu = 1.04, lock = 52, CdA = 0.64, turbo = false,
		b = { len = 4.2, wid = 1.63, h = 1.33, wb = 2.4, style = "hatch", popups = true, wing = false, duck = true },
	},
	{
		id = "na5", name = "Akagi NA-5 Roadster", tag = "Tiny roadster · 960 kg · pop-up lamps",
		price = 12000, color = rgb("#c81e2c"), rim = rgb("#c3c6cc"),
		hp = 120, torque = 150, peak = 5500, red = 7200, mass = 960, front = 0.5,
		gears = { 3.14, 1.89, 1.33, 1, 0.81 }, final = 4.3, mu = 0.98, lock = 50, CdA = 0.6, turbo = false,
		b = { len = 3.97, wid = 1.68, h = 1.22, wb = 2.27, style = "roadster", popups = true, wing = false, duck = false },
	},
	{
		id = "r32", name = "Hoshi R-32 Raijin", tag = "Twin-turbo six · big boost, heavy nose",
		price = 20000, color = rgb("#2b303b"), rim = rgb("#b8b8b8"),
		hp = 280, torque = 410, peak = 4600, red = 7800, mass = 1430, front = 0.56,
		gears = { 3.21, 1.93, 1.3, 1, 0.75 }, final = 4.11, mu = 1.08, lock = 50, CdA = 0.7, turbo = true,
		b = { len = 4.55, wid = 1.76, h = 1.34, wb = 2.62, style = "notch", popups = false, wing = true, duck = false },
	},
	{
		id = "fc3", name = "Akagi FC-3 Rotor", tag = "Turbo rotary · light and balanced",
		price = 25000, color = rgb("#f2f0ea"), rim = rgb("#2a2b30"),
		hp = 215, torque = 270, peak = 5000, red = 8000, mass = 1220, front = 0.51,
		gears = { 3.48, 2.02, 1.39, 1, 0.76 }, final = 4.1, mu = 1.06, lock = 52, CdA = 0.62, turbo = true,
		b = { len = 4.33, wid = 1.69, h = 1.27, wb = 2.43, style = "fast", popups = true, wing = false, duck = true },
	},
	{
		id = "jzx", name = "Kaze JZX-100 Marque", tag = "Turbo six drift sedan · big angle",
		price = 45000, color = rgb("#e9e6df"), rim = rgb("#c9a227"),
		hp = 330, torque = 450, peak = 4000, red = 7200, mass = 1450, front = 0.55,
		gears = { 3.25, 1.96, 1.31, 1, 0.75 }, final = 3.9, mu = 1.1, lock = 58, CdA = 0.7, turbo = true,
		b = { len = 4.76, wid = 1.76, h = 1.4, wb = 2.73, style = "sedan", popups = false, wing = false, duck = true },
	},
	{
		id = "z33", name = "Hoshi Z-33 Zenith", tag = "Big non-turbo V6 · instant torque",
		price = 55000, color = rgb("#b3121f"), rim = rgb("#2a2b30"),
		hp = 300, torque = 400, peak = 4800, red = 7200, mass = 1450, front = 0.53,
		gears = { 3.79, 2.32, 1.62, 1.27, 1, 0.79 }, final = 3.7, mu = 1.12, lock = 54, CdA = 0.66, turbo = false,
		b = { len = 4.32, wid = 1.82, h = 1.3, wb = 2.65, style = "fast", popups = false, wing = false, duck = true },
	},
	{
		id = "jza", name = "Kaze JZA-80 Apex", tag = "Built twin-turbo six · fastest car here",
		price = 80000, color = rgb("#ff6a00"), rim = rgb("#c3c6cc"),
		hp = 520, torque = 620, peak = 4500, red = 7400, mass = 1490, front = 0.54,
		gears = { 3.83, 2.36, 1.69, 1.31, 1, 0.79 }, final = 3.5, mu = 1.16, lock = 55, CdA = 0.64, turbo = true,
		b = { len = 4.52, wid = 1.81, h = 1.27, wb = 2.55, style = "fast", popups = false, wing = true, duck = false },
	},
}

local byId: { [string]: Car } = {}
for _, c in list do
	byId[c.id] = c
end

local Cars = {}
Cars.list = list
Cars.byId = byId
Cars.DEFAULT = "ps13"

function Cars.get(id: string?): Car
	return (id and byId[id]) or byId[Cars.DEFAULT]
end

return Cars
