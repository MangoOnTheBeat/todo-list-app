-- generic Roblox mock: enough to run the server build logic
local V = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); return v3(t.X / m, t.Y / m, t.Z / m) end
	if k == "Lerp" then return function(a, b, f) return a + (b - a) * f end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Cross" then return function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	if k == "Abs" then return function(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end end
	if k == "Min" or k == "Max" then return function(a, b) local f = k == "Min" and math.min or math.max; return v3(f(a.X, b.X), f(a.Y, b.Y), f(a.Z, b.Z)) end end
	error("Vector3 has no member " .. tostring(k), 2)
end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b) if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V.__div = function(a, b) if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end, zero = { X = 0, Y = 0 } }
local CF = {}
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mm(a, b) local o = {}; for i = 0, 2 do for j = 0, 2 do local s = 0; for k = 0, 2 do s += a[i * 3 + k + 1] * b[k * 3 + j + 1] end; o[i * 3 + j + 1] = s end end; return o end
local function mv(a, v) return v3(a[1] * v.X + a[2] * v.Y + a[3] * v.Z, a[4] * v.X + a[5] * v.Y + a[6] * v.Z, a[7] * v.X + a[8] * v.Y + a[9] * v.Z) end
local function cf(p, r) return setmetatable({ p = p, r = r }, CF) end
local function tr(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
CF.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "LookVector" then return v3(-t.r[3], -t.r[6], -t.r[9]) end
	if k == "RightVector" then return v3(t.r[1], t.r[4], t.r[7]) end
	if k == "UpVector" then return v3(t.r[2], t.r[5], t.r[8]) end
	if k == "X" then return t.p.X elseif k == "Y" then return t.p.Y elseif k == "Z" then return t.p.Z end
	if k == "Rotation" then return cf(v3(), t.r) end
	if k == "Inverse" then return function(a) local ri = tr(a.r); return cf(-mv(ri, a.p), ri) end end
	if k == "PointToWorldSpace" then return function(a, v) return a * v end end
	if k == "PointToObjectSpace" then return function(a, v) return mv(tr(a.r), v - a.p) end end
	if k == "VectorToWorldSpace" then return function(a, v) return mv(a.r, v) end end
	if k == "ToWorldSpace" then return function(a, b) return a * b end end
	if k == "Lerp" then return function(a, b, f) return cf(a.p + (b.p - a.p) * f, a.r) end end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b) if getmetatable(b) == CF then return cf(a.p + mv(a.r, b.p), mm(a.r, b.r)) end return a.p + mv(a.r, b) end
CF.__add = function(a, b) return cf(a.p + b, a.r) end
CF.__sub = function(a, b) return cf(a.p - b, a.r) end
local function rx(t) local c, s = math.cos(t), math.sin(t); return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(t) local c, s = math.cos(t), math.sin(t); return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(t) local c, s = math.cos(t), math.sin(t); return { c, -s, 0, s, c, 0, 0, 0, 1 } end
CFrame = {
	new = function(x, y, z, ...) if type(x) == "table" then if y then return CFrame.lookAt(x, y) end return cf(x, I) end return cf(v3(x, y, z), I) end,
	Angles = function(a, b, c) return cf(v3(), mm(mm(rx(a), ry(b)), rz(c))) end,
	fromEulerAnglesYXZ = function(a, b, c) return cf(v3(), mm(mm(ry(b), rx(a)), rz(c))) end,
	fromAxisAngle = function(ax, a) return cf(v3(), ry(a)) end,
	fromMatrix = function(p, r, u, b) b = b or r:Cross(u); return cf(p, { r.X, u.X, b.X, r.Y, u.Y, b.Y, r.Z, u.Z, b.Z }) end,
	lookAt = function(a, b, up)
		up = up or v3(0, 1, 0)
		local f = (b - a).Unit
		local r = f:Cross(up).Unit
		local u = r:Cross(f)
		return cf(a, { r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z })
	end,
	identity = cf(v3(), I),
}
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
local C3 = {}
C3.__index = function(t, k)
	if k == "Lerp" then return function(a, b, f) return setmetatable({ R = a.R + (b.R - a.R) * f, G = a.G + (b.G - a.G) * f, B = a.B + (b.B - a.B) * f }, C3) end end
	if k == "ToHSV" then return function() return 0, 0, 0 end end
	error("Color3 has no member " .. tostring(k), 2)
end
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
Color3 = { new = c3, fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end,
	fromHex = function(h) h = h:gsub("#", ""); return c3(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255) end,
	fromHSV = function() return c3(1, 1, 1) end }
Random = { new = function(seed) local s = seed or 1; local function nxt() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
	return { NextNumber = function(_, a, b) local r = nxt(); if a then return a + (b - a) * r end return r end, NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end } end }

-- any: a stand-in for every other Roblox object; reading an unset member gives another any, calling one gives any
local ANY = {}
local function any(name) return setmetatable({ __name = name }, ANY) end
ANY.__index = function(t, k)
	local v = any(rawget(t, "__name") .. "." .. tostring(k))
	return v
end
ANY.__call = function(f, ...) return any(rawget(f, "__name") .. "()") end
ANY.__tostring = function(t) return rawget(t, "__name") end
ANY.__iter = function() return next, {} end
for _, op in { "__add", "__sub", "__mul", "__div", "__unm", "__mod", "__pow", "__concat" } do
	ANY[op] = function(a, b) return any("arith") end
end
ANY.__lt = function() return false end
ANY.__le = function() return false end
local enumMeta = { __index = function(t, k) local e = setmetatable({}, { __index = function(_, m) return "Enum." .. k .. "." .. m end }); rawset(t, k, e); return e end }
Enum = setmetatable({}, enumMeta)
NumberSequence, ColorSequence, NumberSequenceKeypoint, ColorSequenceKeypoint = any("NumberSequence"), any("ColorSequence"), any("NSK"), any("CSK")
UDim, UDim2, TweenInfo, NumberRange, Font, PhysicalProperties = any("UDim"), any("UDim2"), any("TweenInfo"), any("NumberRange"), any("Font"), any("PhysicalProperties")
RaycastParams, OverlapParams, Region3, BrickColor, Rect = any("RaycastParams"), any("OverlapParams"), any("Region3"), any("BrickColor"), any("Rect")

-- instances: store whatever is set; children by Parent
PARTS, FILLS, SIZEBAD, ALL = 0, 0, {}, {}
local INST = {}
local function inst(class, name)
	return setmetatable({ ClassName = class, Name = name or class, __kids = {}, __attr = {} }, INST)
end
local methods = {}
function methods.SetAttribute(self, k, v) self.__attr[k] = v end
function methods.GetAttribute(self, k) return self.__attr[k] end
function methods.FindFirstChild(self, n) for _, c in self.__kids do if c.Name == n then return c end end return nil end
function methods.WaitForChild(self, n) return methods.FindFirstChild(self, n) or error("WaitForChild would hang: " .. n, 2) end
function methods.FindFirstChildOfClass(self, n) for _, c in self.__kids do if c.ClassName == n then return c end end return nil end
function methods.GetChildren(self) return table.clone(self.__kids) end
function methods.GetDescendants(self) local o = {}; local function w(x) for _, c in x.__kids do table.insert(o, c); w(c) end end; w(self); return o end
function methods.IsA(self, c) return self.ClassName == c or (c == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart" or self.ClassName == "MeshPart")) end
function methods.Destroy(self) self.Parent = nil end
function methods.Clone(self) local o = inst(self.ClassName, self.Name); for k, v in self do if k ~= "__kids" and k ~= "__attr" and k ~= "Parent" then rawset(o, k, v) end end; if o.ClassName == "Part" or o.ClassName == "WedgePart" then PARTS += 1 end; for _, c in self.__kids do c:Clone().Parent = o end; return o end
function methods.FillBlock(self, c, size, mat) FILLS += 1; assert(getmetatable(c) == CF and getmetatable(size) == V and type(mat) == "string", "bad FillBlock args") end
function methods.FillBall() end
function methods.FillCylinder() end
function methods.FillWedge() end
LOCALPLAYER = nil
function methods.InvokeServer(self, ...) return rawget(self, "OnServerInvoke")(LOCALPLAYER, ...) end
function methods.FireServer(self, ...) self.OnServerEvent:Fire(LOCALPLAYER, ...) end
function methods.FireClient(self, pl, ...) if pl == LOCALPLAYER then self.OnClientEvent:Fire(...) end end
function methods.FireAllClients(self, ...) self.OnClientEvent:Fire(...) end
function methods.GetAttributeChangedSignal() return any("Signal") end
function methods.IsDescendantOf() return true end
function methods.PivotTo(self, c) self.__pivot = c end
function methods.GetPivot(self) return self.__pivot or (self.PrimaryPart and self.PrimaryPart.CFrame) or CFrame.identity end
function methods.SetPrimaryPartCFrame(self, c) self.__pivot = c end
function methods.GetPropertyChangedSignal() return any("Signal") end
local SCRIPTABLE_ONLY_IN_STUDIO = { Decoration = true }
INST.__index = function(t, k)
	if methods[k] then return methods[k] end
	if k == "Position" and rawget(t, "CFrame") then return rawget(t, "CFrame").p end
	if k == "Parent" then return rawget(t, "__parent") end
	for _, c in rawget(t, "__kids") do if c.Name == k then return c end end
	if type(k) == "string" and (k:match("^On%u") or k:match("Added$") or k:match("Removing$") or k:match("Finished$") or k == "Error" or k:match("Stepped$") or k:match("^Input") or k == "Activated" or k == "TouchPinch") then
		local sig = rawget(t, "__sig_" .. k)
		if not sig then
			sig = { fns = {} }
			function sig.Connect(selfs, fn) table.insert(selfs.fns, fn); return any("Conn") end
			function sig.Fire(selfs, ...) for _, fn in selfs.fns do fn(...) end end
			rawset(t, "__sig_" .. k, sig)
		end
		return sig
	end
	return any(rawget(t, "ClassName") .. "." .. k)
end
INST.__newindex = function(t, k, v)
	if SCRIPTABLE_ONLY_IN_STUDIO[k] then error("cannot set " .. k .. " from a script", 2) end
	if k == "Parent" then
		local old = rawget(t, "__parent")
		if old then local kids = rawget(old, "__kids"); local i = table.find(kids, t); if i then table.remove(kids, i) end end
		if v then table.insert(rawget(v, "__kids"), t) end
		rawset(t, "__parent", v)
		return
	end
	if k == "Position" then local c = rawget(t, "CFrame"); rawset(t, "CFrame", c and cf(v, c.r) or cf(v, I)); return end
	if k == "Size" and getmetatable(v) == V then
		if v.X > 2048 or v.Y > 2048 or v.Z > 2048 then table.insert(SIZEBAD, t.Name .. " " .. v.X .. "x" .. v.Y .. "x" .. v.Z) end
		if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then error("NaN size", 2) end
	end
	if k == "CFrame" and getmetatable(v) ~= CF then error("CFrame set to non-CFrame", 2) end
	rawset(t, k, v)
end
Instance = { new = function(class, parent)
	local o = inst(class)
	if class == "Part" or class == "WedgePart" then PARTS += 1; table.insert(ALL, o) end
	if class == "Terrain" then end
	if parent then o.Parent = parent end
	return o
end }
local services = {}
workspace = inst("Workspace", "Workspace")
local terrain = inst("Terrain", "Terrain"); terrain.Parent = workspace
services.Workspace = workspace
game = inst("DataModel", "game")
rawset(game, "GetService", function(self, n)
	if not services[n] then services[n] = inst(n, n) end
	return services[n]
end)
local players = game:GetService("Players")
rawset(players, "GetPlayers", function() return {} end)
task = { wait = function() return 0 end, spawn = function() end, defer = function() end, delay = function() end }
wait = task.wait
tick = os.clock
warn = function(...) print("WARN", ...) end
typeof = function(v) local m = getmetatable(v); if m == V then return "Vector3" elseif m == CF then return "CFrame" elseif m == C3 then return "Color3" end return type(v) end

local __src, __cache = {}, {}
local function require(m)
	local id = rawget(m, "__mod") or (m.__attr and m.__attr.__mod)
	assert(id, "require of a non-module: " .. tostring(m.Name))
	if __cache[id] == nil then __cache[id] = __src[id](m) end
	return __cache[id]
end
local RS = game:GetService("ReplicatedStorage")
local SharedF = Instance.new("Folder"); SharedF.Name = "Shared"; SharedF.Parent = RS
local SSS = game:GetService("ServerScriptService")
local ServerF = Instance.new("Folder"); ServerF.Name = "KaidoServer"; ServerF.Parent = SSS
local function mod(name, parent) local m = Instance.new("ModuleScript"); m.Name = name; rawset(m, "__mod", name); m.Parent = parent; return m end
mod("Config", SharedF)
mod("Cars", SharedF)
mod("Track", SharedF)
mod("CourseData", SharedF)
mod("CarPhysics", SharedF)
mod("SoundIds", SharedF)
mod("City", ServerF)
__src["Config"] = function(script)
-- Kaido Drift (Roblox): shared settings. Cars come from the browser game (Cars.luau); physics and assist
-- numbers live in CarPhysics, exactly as in the browser.
local Config = {}

-- shown on the menus; goes up by one with every release
Config.VERSION = 4

Config.ROAD_HALF = 30 -- half the pass road width (studs): 60 studs = about 17 m at car scale, room to drift two abreast
Config.SEG = 13 -- pass road sample spacing (studs)
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
		pass = 2029130262, robux = 149, color = Color3.fromHex("#e8f0ff"), rim = Color3.fromHex("#ff7eb6"),
		mass = 1180, torque = 640, peak = 6800, red = 9500, mu = 1.2, lock = 64 }),
	special("jza", { id = "jzax", name = "Kaze JZA-80 Apex Omega", tag = "Special · 1,000 hp twin-turbo six · fastest on the mountain",
		pass = 2029784268, robux = 249, color = Color3.fromHex("#14141a"), rim = Color3.fromHex("#ffc94d"),
		mass = 1420, torque = 880, peak = 5200, red = 8200, mu = 1.22, lock = 65 }),
	special("r34", { id = "r34x", name = "Hoshi R-34 Raijin Z-Tune", tag = "Special · stroked twin-turbo · 6-speed · ultimate grip",
		pass = 2028884270, robux = 399, color = Color3.fromHex("#9aa3b2"), rim = Color3.fromHex("#59e3ff"),
		mass = 1460, torque = 860, peak = 5000, red = 8600, mu = 1.26, lock = 66 }),
}
for _, c in Config.Premium do table.insert(Config.Cars, c) end

-- free paints (index 0 = the car's own colour)
Config.Paints = {
	Color3.fromHex("e9e6df"), Color3.fromHex("111114"), Color3.fromHex("c81e2c"), Color3.fromHex("ff7eb6"),
	Color3.fromHex("59e3ff"), Color3.fromHex("2a54c8"), Color3.fromHex("ff6a00"), Color3.fromHex("ffcc00"),
	Color3.fromHex("2f6b46"), Color3.fromHex("7c8088"), Color3.fromHex("5a2a8c"), Color3.fromHex("8c1d2a"),
}

-- garage upgrades: bought per car with credits, three levels each. `apply` changes the car's real
-- drivetrain numbers, so the physics feel the difference (see Config.tuned).
Config.Upgrades = {
	{ key = "engine", name = "Engine", desc = "Ported head, cams and exhaust: +7% torque a level", cost = { 4000, 10000, 22000 },
		apply = function(c, l) c.torque *= 1 + 0.07 * l end },
	{ key = "turbo", name = "Turbo", desc = "Bigger turbo: more top-end, +6% torque and +250 rpm a level", cost = { 5000, 12000, 26000 },
		apply = function(c, l) c.torque *= 1 + 0.06 * l; c.peak += 250 * l; c.red += 250 * l end },
	{ key = "grip", name = "Tyres", desc = "Stickier compound: +2.5% grip a level", cost = { 3000, 8000, 18000 },
		apply = function(c, l) c.mu *= 1 + 0.025 * l end },
	{ key = "steer", name = "Steering angle", desc = "Angle kit: +3° of lock a level, for deeper drifts", cost = { 3000, 7000, 15000 },
		apply = function(c, l) c.lock += 3 * l end },
}
Config.UPGRADE_MAX = 3
-- cosmetics, per car: unlock once with credits, then pick any colour for free
Config.Cosmetics = {
	glow = { name = "Underglow neon", cost = 5000 },
	rims = { name = "Rim colour", cost = 2000 },
	kit = { name = "Stance kit (lowered body)", cost = 4000 },
}
Config.GlowColors = {
	Color3.fromHex("59e3ff"), Color3.fromHex("ff7eb6"), Color3.fromHex("a77bff"), Color3.fromHex("49ff8a"),
	Color3.fromHex("ff3b3b"), Color3.fromHex("ffc94d"), Color3.fromHex("ffffff"),
}
Config.RimColors = {
	Color3.fromHex("c3c6cc"), Color3.fromHex("2a2b30"), Color3.fromHex("c9a227"), Color3.fromHex("d8d8d8"),
	Color3.fromHex("ff7eb6"), Color3.fromHex("59e3ff"), Color3.fromHex("c81e2c"), Color3.fromHex("ffffff"),
}

-- a car with its upgrades applied (upg = { engine = 2, grip = 1, ... }); the original is left alone
function Config.tuned(car, upg)
	if type(upg) ~= "table" then return car end
	local any = false
	for _, u in Config.Upgrades do if (upg[u.key] or 0) > 0 then any = true end end
	if not any then return car end
	local c = table.clone(car)
	for _, u in Config.Upgrades do
		local l = math.clamp(math.floor(tonumber(upg[u.key]) or 0), 0, Config.UPGRADE_MAX)
		if l > 0 then u.apply(c, l) end
	end
	return c
end

-- daily challenges: the same three for everyone each day (picked from the day number)
Config.DailyPool = {
	{ kind = "one", text = "Score %s in one drift", goals = { 15000, 25000, 40000 }, reward = 6000 },
	{ kind = "total", text = "Bank %s drift points today", goals = { 100000, 200000, 350000 }, reward = 8000 },
	{ kind = "city", text = "Bank %s points drifting in the city", goals = { 40000, 80000 }, reward = 7000 },
	{ kind = "pass", text = "Bank %s points drifting on the Hakone pass", goals = { 40000, 80000 }, reward = 7000 },
	{ kind = "tandem", text = "Bank %s points in tandem drifts", goals = { 10000, 25000 }, reward = 10000 },
	{ kind = "lap", text = "Complete %s lap(s) of the Hakone pass", goals = { 1, 2 }, reward = 9000 },
	{ kind = "combo", text = "Reach a ×%s combo", goals = { 3, 4, 5 }, reward = 6000 },
}
function Config.dailyFor(day: number)
	local list, used = {}, {}
	local seed = day * 7919
	while #list < 3 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local k = seed % #Config.DailyPool + 1
		if not used[k] then
			used[k] = true
			local c = Config.DailyPool[k]
			seed = (seed * 1103515245 + 12345) % 2147483648
			local goal = c.goals[seed % #c.goals + 1]
			table.insert(list, { kind = c.kind, goal = goal, reward = c.reward, text = string.format(c.text, goal >= 1000 and string.format("%d,%03d", goal // 1000, goal % 1000) or tostring(goal)) })
		end
	end
	return list
end

-- admin panel: the game's owner is always an admin (once published under your account). To add more
-- people, put their Roblox user IDs here, e.g. { 12345678, 87654321 }. In Studio you are always admin.
Config.Admins = {}

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

end
__src["Cars"] = function(script)
-- The 13 cars from the browser game, with its exact drivetrain numbers (metres, kg, Nm). Generated from index.html.
return {
	{ id = "ps13", name = "Hoshi PS13 Spirit", tag = "Starter · 1.8 turbo four · pop-up lamps", price = 0, color = Color3.fromHex("#e9e6df"), rim = Color3.fromHex("#c3c6cc"),
		engine = "i4", turbo = true, mass = 1240, front = 0.53, torque = 255, peak = 4000, red = 7200,
		gears = { 3.32, 1.9, 1.31, 1.0, 0.76 }, final = 4.08, mu = 1.03, lock = 48, CdA = 0.68, engI = 0.13, pitch = 1.0,
		b = { len = 4.52, wid = 1.69, wb = 2.47, h = 1.29, style = "notch", popups = true, wing = false, duck = false, exhaust = 1 } },
	{ id = "ae8", name = "Kaze AE8 Hachi", tag = "Featherweight · revvy 1.6 non-turbo · very agile", price = 8000, color = Color3.fromHex("#f4f4f4"), rim = Color3.fromHex("#2a2b30"),
		engine = "i4", turbo = false, mass = 925, front = 0.52, torque = 155, peak = 6000, red = 8200,
		gears = { 3.59, 2.02, 1.38, 1.0, 0.86 }, final = 4.78, mu = 1.04, lock = 52, CdA = 0.64, engI = 0.09, pitch = 1.0,
		b = { len = 4.2, wid = 1.63, wb = 2.4, h = 1.33, style = "hatch", popups = true, wing = false, duck = true, exhaust = 1 } },
	{ id = "na5", name = "Akagi NA-5 Roadster", tag = "Tiny roadster · 960 kg · pop-up lamps", price = 12000, color = Color3.fromHex("#c81e2c"), rim = Color3.fromHex("#c3c6cc"),
		engine = "i4", turbo = false, mass = 960, front = 0.5, torque = 150, peak = 5500, red = 7200,
		gears = { 3.14, 1.89, 1.33, 1.0, 0.81 }, final = 4.3, mu = 1.03, lock = 50, CdA = 0.6, engI = 0.08, pitch = 1.0,
		b = { len = 3.97, wid = 1.68, wb = 2.27, h = 1.22, style = "roadster", popups = true, wing = false, duck = false, exhaust = 1 } },
	{ id = "c33", name = "Hoshi C-33 Laurelin", tag = "Four-door turbo six sedan · long wheelbase", price = 15000, color = Color3.fromHex("#2e3b4f"), rim = Color3.fromHex("#b8b8b8"),
		engine = "i6", turbo = true, mass = 1340, front = 0.54, torque = 270, peak = 4000, red = 7000,
		gears = { 3.32, 1.9, 1.31, 1.0, 0.76 }, final = 4.11, mu = 1.04, lock = 50, CdA = 0.72, engI = 0.13, pitch = 0.9,
		b = { len = 4.69, wid = 1.69, wb = 2.67, h = 1.39, style = "sedan", popups = false, wing = false, duck = false, exhaust = 1 } },
	{ id = "r32", name = "Hoshi R-32 Raijin", tag = "Twin-turbo six · big boost, heavy nose", price = 20000, color = Color3.fromHex("#2b303b"), rim = Color3.fromHex("#b8b8b8"),
		engine = "i6", turbo = true, mass = 1430, front = 0.56, torque = 410, peak = 4600, red = 7800,
		gears = { 3.21, 1.93, 1.3, 1.0, 0.75 }, final = 4.11, mu = 1.08, lock = 50, CdA = 0.7, engI = 0.14, pitch = 0.9,
		b = { len = 4.55, wid = 1.76, wb = 2.62, h = 1.34, style = "notch", popups = false, wing = true, duck = false, exhaust = 1 } },
	{ id = "fc3", name = "Akagi FC-3 Rotor", tag = "First-gen turbo rotary · pop-up lamps", price = 25000, color = Color3.fromHex("#f2f0ea"), rim = Color3.fromHex("#2a2b30"),
		engine = "rotary", turbo = true, mass = 1220, front = 0.51, torque = 270, peak = 5000, red = 8000,
		gears = { 3.48, 2.02, 1.39, 1.0, 0.76 }, final = 4.1, mu = 1.06, lock = 52, CdA = 0.62, engI = 0.08, pitch = 1.22,
		b = { len = 4.33, wid = 1.69, wb = 2.43, h = 1.27, style = "fast", popups = true, wing = false, duck = true, exhaust = 2 } },
	{ id = "zn6", name = "Kaze ZN-6 Hachi-R", tag = "Modern non-turbo coupe · revs to 7,500", price = 30000, color = Color3.fromHex("#ff5a1f"), rim = Color3.fromHex("#2a2b30"),
		engine = "i4", turbo = false, mass = 1240, front = 0.53, torque = 210, peak = 6400, red = 7500,
		gears = { 3.63, 2.19, 1.54, 1.21, 1.0, 0.77 }, final = 4.1, mu = 1.08, lock = 53, CdA = 0.62, engI = 0.1, pitch = 1.0,
		b = { len = 4.24, wid = 1.78, wb = 2.57, h = 1.29, style = "fast", popups = false, wing = false, duck = true, exhaust = 2 } },
	{ id = "fd7", name = "Akagi FD-7 Rotor", tag = "Twin-rotor · light, sharp, screams to 9,000", price = 35000, color = Color3.fromHex("#ffcc00"), rim = Color3.fromHex("#c9a227"),
		engine = "rotary", turbo = true, mass = 1250, front = 0.5, torque = 340, peak = 6000, red = 9000,
		gears = { 3.48, 2.02, 1.39, 1.0, 0.72 }, final = 4.1, mu = 1.1, lock = 54, CdA = 0.6, engI = 0.08, pitch = 1.22,
		b = { len = 4.3, wid = 1.76, wb = 2.43, h = 1.23, style = "fast", popups = true, wing = true, duck = false, exhaust = 2 } },
	{ id = "jzx", name = "Kaze JZX-100 Marque", tag = "Turbo six drift sedan · big angle", price = 45000, color = Color3.fromHex("#e9e6df"), rim = Color3.fromHex("#c9a227"),
		engine = "i6", turbo = true, mass = 1450, front = 0.55, torque = 450, peak = 4000, red = 7200,
		gears = { 3.25, 1.96, 1.31, 1.0, 0.75 }, final = 3.9, mu = 1.1, lock = 56, CdA = 0.7, engI = 0.14, pitch = 0.9,
		b = { len = 4.76, wid = 1.76, wb = 2.73, h = 1.4, style = "sedan", popups = false, wing = false, duck = true, exhaust = 2 } },
	{ id = "z33", name = "Hoshi Z-33 Zenith", tag = "Big non-turbo V6 · instant torque, long slides", price = 55000, color = Color3.fromHex("#b3121f"), rim = Color3.fromHex("#2a2b30"),
		engine = "v6", turbo = false, mass = 1450, front = 0.53, torque = 400, peak = 4800, red = 7200,
		gears = { 3.79, 2.32, 1.62, 1.27, 1.0, 0.79 }, final = 3.7, mu = 1.12, lock = 54, CdA = 0.66, engI = 0.14, pitch = 0.84,
		b = { len = 4.32, wid = 1.82, wb = 2.65, h = 1.3, style = "fast", popups = false, wing = false, duck = true, exhaust = 2 } },
	{ id = "jza", name = "Kaze JZA-80 Apex", tag = "Built twin-turbo six · fastest car here", price = 80000, color = Color3.fromHex("#ff6a00"), rim = Color3.fromHex("#c3c6cc"),
		engine = "i6", turbo = true, mass = 1490, front = 0.54, torque = 620, peak = 4500, red = 7400,
		gears = { 3.83, 2.36, 1.69, 1.31, 1.0, 0.79 }, final = 3.5, mu = 1.14, lock = 55, CdA = 0.64, engI = 0.15, pitch = 0.9,
		b = { len = 4.52, wid = 1.81, wb = 2.55, h = 1.27, style = "fast", popups = false, wing = true, duck = false, exhaust = 2 } },
	{ id = "r34", name = "Hoshi R-34 Raijin-GT", tag = "Twin-turbo six · 6-speed · flagship", price = 95000, color = Color3.fromHex("#2a54c8"), rim = Color3.fromHex("#c3c6cc"),
		engine = "i6", turbo = true, mass = 1520, front = 0.55, torque = 520, peak = 4400, red = 8000,
		gears = { 3.83, 2.36, 1.69, 1.31, 1.0, 0.79 }, final = 3.7, mu = 1.14, lock = 54, CdA = 0.66, engI = 0.14, pitch = 0.9,
		b = { len = 4.6, wid = 1.78, wb = 2.67, h = 1.36, style = "notch", popups = false, wing = true, duck = false, exhaust = 2 } },
	{ id = "ps15", name = "Hoshi PS15 Spirit-R", tag = "Pro drift build · 62° lock, sticky tyres", price = 120000, color = Color3.fromHex("#3a6cf4"), rim = Color3.fromHex("#d8d8d8"),
		engine = "i4", turbo = true, mass = 1220, front = 0.53, torque = 470, peak = 5000, red = 8000,
		gears = { 3.32, 2.08, 1.48, 1.17, 1.0, 0.81 }, final = 4.1, mu = 1.18, lock = 62, CdA = 0.64, engI = 0.11, pitch = 1.0,
		b = { len = 4.45, wid = 1.69, wb = 2.52, h = 1.28, style = "notch", popups = false, wing = true, duck = false, exhaust = 1 } },
}

end
__src["Track"] = function(script)
-- Kaido Drift (Roblox): the course. The browser game's real Hakone road (13.7 km, real climbs and
-- drops from elevation data) as a smooth loop. Server and client build it from the same numbers,
-- so the car never needs the map parts to know where the road is.
local Config = require(script.Parent.Config)
local Course = require(script.Parent.CourseData)

local Track = {}

local src = Course.POINTS
local cp = {}
for i = 1, #src, 4 do
	table.insert(cp, { src[i], src[i + 1], src[i + 2], src[i + 3] })
end
local n = #cp

-- closed Catmull-Rom through the points (they are evenly spaced), sampled densely
local dense = {}
for i = 1, n do
	local p0, p1, p2, p3 = cp[(i - 2) % n + 1], cp[i], cp[i % n + 1], cp[(i + 1) % n + 1]
	for k = 0, 19 do
		local t = k / 20
		local t2, t3 = t * t, t * t * t
		local function cr(c)
			local a, b, cc, d = p0[c], p1[c], p2[c], p3[c]
			return 0.5 * (2 * b + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
		end
		table.insert(dense, { cr(1), cr(2), cr(3), if t < 0.5 then p1[4] else p2[4] })
	end
end

-- resample every SEG studs along the ground
local px, py, pz, zone = {}, {}, {}, {}
do
	local seg, acc = Config.SEG, 0
	local m = #dense
	table.insert(px, dense[1][1]); table.insert(py, dense[1][2]); table.insert(pz, dense[1][3]); table.insert(zone, dense[1][4])
	for i = 1, m do
		local a, b = dense[i], dense[i % m + 1]
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local pos = 0
		while acc + (len - pos) >= seg do
			pos += seg - acc
			acc = 0
			local f = pos / len
			table.insert(px, a[1] + dx * f)
			table.insert(py, a[2] + (b[2] - a[2]) * f)
			table.insert(pz, a[3] + dz * f)
			table.insert(zone, a[4])
		end
		acc += len - pos
	end
	local l = #px
	if math.sqrt((px[l] - px[1]) ^ 2 + (pz[l] - pz[1]) ^ 2) < seg * 0.5 then
		table.remove(px); table.remove(py); table.remove(pz); table.remove(zone)
	end
end
local N = #px

local tx, tz, rx, rz = {}, {}, {}, {}
for i = 1, N do
	local a, b = (i - 2) % N + 1, i % N + 1
	local dx, dz = px[b] - px[a], pz[b] - pz[a]
	local l = math.sqrt(dx * dx + dz * dz)
	tx[i], tz[i] = dx / l, dz / l
	rx[i], rz[i] = -tz[i], tx[i] -- right-hand side when facing along the road
end

Track.N = N
Track.X, Track.Y, Track.Z, Track.ZONE = px, py, pz, zone
Track.TX, Track.TZ, Track.RX, Track.RZ = tx, tz, rx, rz
Track.LENGTH = N * Config.SEG
Track.ZONE_NAMES = { [0] = "湖尻 · Kojiri village", [1] = "箱根 · Hakone hills", [2] = "芦ノ湖 · Lake Ashi shore" }

-- spatial hash so "where is the road?" is quick anywhere on the map
local CELL = 80
local hash = {}
local function key(cx, cz) return cx * 100000 + cz end
for i = 1, N do
	local k = key(math.floor(px[i] / CELL), math.floor(pz[i] / CELL))
	local t = hash[k]
	if not t then t = {}; hash[k] = t end
	table.insert(t, i)
end

function Track.heading(i: number): number
	return math.atan2(tx[i], tz[i])
end

function Track.slope(i: number): number
	local a, b = (i - 2) % N + 1, i % N + 1
	return (py[b] - py[a]) / (2 * Config.SEG)
end

-- nearest road sample: searched along the road from the last one first (fast, and never jumps to a
-- road section above or below on a hairpin), then through the spatial hash
function Track.nearest(x: number, z: number, hint: number?): number
	local best, bi = math.huge, 1
	if hint then
		for k = -30, 30 do
			local i = (hint - 1 + k) % N + 1
			local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
			if d < best then best, bi = d, i end
		end
		if best < 30 * 30 then return bi end
	end
	local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
	for dx = -2, 2 do
		for dz = -2, 2 do
			local t = hash[key(cx + dx, cz + dz)]
			if t then
				for _, i in t do
					local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
					if d < best then best, bi = d, i end
				end
			end
		end
	end
	if best == math.huge then
		for i = 1, N do
			local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
			if d < best then best, bi = d, i end
		end
	end
	return bi
end

-- every road sample within r studs (for building scenery)
function Track.near(x: number, z: number, r: number): { number }
	local out = {}
	local cx, cz, span = math.floor(x / CELL), math.floor(z / CELL), math.ceil(r / CELL)
	for dx = -span, span do
		for dz = -span, span do
			local t = hash[key(cx + dx, cz + dz)]
			if t then
				for _, i in t do
					if (px[i] - x) ^ 2 + (pz[i] - z) ^ 2 < r * r then table.insert(out, i) end
				end
			end
		end
	end
	return out
end

-- sideways offset from the centre line and road height at (x, z) near sample i
function Track.at(x: number, z: number, i: number): (number, number)
	local dx, dz = x - px[i], z - pz[i]
	local along = dx * tx[i] + dz * tz[i]
	return dx * rx[i] + dz * rz[i], py[i] + Track.slope(i) * along
end

return Track

end
__src["CourseData"] = function(script)
-- Generated by tools/make_course.py from the browser game's Hakone course and elevation data. Do not edit.
-- POINTS: x, y, z (studs), zone (0 Kojiri village, 1 Hakone hills, 2 Lake Ashi shore) every 20 m of road.
-- CELLS: hill columns beside the road: x, top y, z, lake flag (40 m = 88-stud cells). LAKES: open-water cells (120 m).
return {
	POINTS = {-881.7,121.8,-4518.0,0,-932.7,123.2,-4487.4,0,-991.5,124.7,-4476.2,0,-1050.7,126.1,-4466.2,0,-1106.5,127.5,-4445.2,0,-1150.6,129.0,-4405.3,0,-1173.6,130.4,-4350.1,0,-1186.5,131.7,-4291.5,0,-1205.2,132.8,-4234.5,0,-1241.5,133.7,-4187.5,0,-1293.5,134.4,-4158.2,0,-1351.1,134.9,-4141.4,0,-1408.9,135.4,-4125.6,0,-1460.4,135.7,-4095.3,0,-1493.5,136.0,-4045.9,0,-1510.1,136.2,-3988.5,0,-1521.5,136.3,-3929.6,0,-1538.8,136.4,-3872.3,0,-1574.2,135.1,-3824.3,0,-1626.2,133.7,-3795.0,0,-1683.1,132.3,-3776.2,0,-1739.9,130.9,-3756.8,0,-1791.2,129.6,-3726.6,0,-1827.1,128.2,-3678.9,0,-1844.1,126.9,-3621.5,0,-1852.9,125.6,-3562.2,0,-1864.5,124.3,-3503.3,0,-1889.9,123.0,-3449.5,0,-1934.7,121.7,-3410.3,0,-1990.0,120.4,-3387.1,0,-2047.6,119.1,-3370.2,0,-2103.5,117.7,-3348.5,0,-2150.4,116.3,-3311.8,0,-2178.9,114.8,-3259.5,0,-2190.7,113.4,-3200.8,0,-2195.9,111.9,-3141.0,0,-2204.6,110.5,-3081.7,0,-2229.5,109.1,-3027.4,0,-2274.5,107.6,-2988.6,0,-2329.6,106.2,-2965.2,0,-2387.2,104.7,-2948.5,0,-2443.8,103.3,-2928.7,0,-2493.0,101.9,-2894.7,0,-2522.0,100.4,-2843.0,0,-2531.1,99.0,-2783.9,0,-2530.6,97.5,-2723.9,0,-2530.6,96.1,-2663.9,0,-2545.2,94.7,-2606.0,0,-2584.4,93.2,-2561.7,0,-2638.3,91.8,-2535.9,0,-2696.1,90.3,-2519.7,0,-2753.6,88.9,-2502.7,0,-2804.5,87.5,-2471.4,0,-2833.0,86.2,-2420.1,0,-2835.9,85.1,-2360.3,0,-2825.6,84.0,-2301.3,0,-2815.8,82.9,-2242.1,0,-2821.7,81.9,-2183.0,0,-2858.2,80.9,-2137.2,0,-2914.1,79.9,-2115.4,0,-2972.5,78.9,-2101.9,0,-3029.3,78.0,-2083.0,0,-3075.5,77.0,-2047.1,0,-3084.3,76.1,-1988.3,0,-3069.3,75.1,-1930.5,0,-3051.4,74.1,-1873.2,0,-3039.0,73.0,-1814.9,0,-3068.4,71.9,-1764.2,0,-3123.3,70.7,-1742.5,0,-3182.4,69.4,-1732.3,0,-3241.2,68.0,-1720.5,0,-3281.6,66.5,-1680.2,0,-3280.9,65.1,-1621.3,0,-3252.1,63.7,-1568.8,0,-3226.7,62.2,-1514.5,0,-3215.6,60.8,-1457.4,0,-3266.6,59.3,-1428.1,0,-3324.6,57.9,-1413.5,0,-3383.8,56.5,-1404.0,0,-3427.1,55.0,-1364.7,0,-3423.1,53.6,-1308.5,0,-3385.1,52.1,-1262.1,0,-3350.2,50.7,-1213.4,0,-3329.1,49.3,-1159.7,0,-3375.4,47.8,-1123.1,0,-3430.1,46.4,-1098.9,0,-3486.5,44.9,-1078.8,0,-3520.3,43.5,-1031.2,0,-3502.7,42.1,-977.8,0,-3454.5,40.6,-942.2,0,-3408.9,39.2,-903.3,0,-3375.5,37.7,-856.2,0,-3411.5,36.3,-809.5,0,-3459.1,34.9,-773.3,0,-3509.7,33.4,-741.2,0,-3532.9,32.0,-687.6,0,-3505.8,30.5,-638.2,0,-3452.1,29.1,-611.5,0,-3400.7,27.7,-580.6,0,-3361.0,26.2,-538.9,0,-3388.4,24.8,-486.5,0,-3427.6,23.3,-441.4,0,-3467.9,21.9,-397.2,0,-3469.8,20.5,-338.6,0,-3427.5,19.0,-300.0,0,-3370.2,17.6,-282.0,0,-3314.3,16.5,-260.4,0,-3289.2,15.8,-212.5,0,-3303.3,15.1,-154.2,0,-3324.4,14.3,-98.0,0,-3317.4,13.6,-40.3,0,-3272.3,12.9,-5.0,0,-3213.1,12.2,-13.4,0,-3154.8,11.5,-27.3,0,-3098.9,10.7,-23.0,0,-3067.3,10.0,27.9,0,-3043.3,9.3,82.9,0,-3002.4,8.6,124.7,0,-2944.6,7.9,128.4,0,-2897.6,7.1,91.4,0,-2848.0,6.4,57.6,0,-2792.4,5.7,46.2,0,-2749.4,5.6,87.5,0,-2721.2,5.6,140.2,0,-2686.5,5.6,187.8,0,-2630.0,5.6,200.6,0,-2576.1,5.6,174.4,0,-2517.9,5.6,160.6,0,-2462.2,5.6,173.4,0,-2444.3,5.6,230.1,0,-2448.3,5.6,289.4,0,-2448.3,5.6,348.5,0,-2412.8,5.6,395.0,0,-2353.8,5.6,404.5,0,-2295.8,5.6,419.4,0,-2249.9,5.6,453.8,0,-2252.8,5.6,513.3,0,-2275.4,5.6,568.5,0,-2291.5,5.6,625.2,0,-2268.4,5.6,678.8,0,-2213.4,5.6,702.1,0,-2160.5,5.6,730.2,0,-2123.1,5.6,773.8,0,-2140.0,5.6,830.8,0,-2173.8,5.6,880.1,0,-2200.7,5.6,932.5,0,-2188.9,5.6,989.6,0,-2141.0,5.6,1025.4,0,-2100.7,5.6,1069.7,0,-2085.5,5.6,1125.1,0,-2117.5,5.6,1175.4,0,-2167.4,5.6,1208.0,0,-2216.7,5.6,1242.0,0,-2246.2,5.6,1291.5,0,-2233.9,5.6,1350.0,0,-2211.1,5.6,1405.5,0,-2197.7,5.6,1463.6,0,-2213.3,5.6,1519.3,0,-2264.4,5.6,1550.3,0,-2320.6,5.6,1570.9,0,-2373.7,5.6,1598.1,0,-2410.5,5.6,1643.7,0,-2397.7,5.6,1701.6,0,-2366.9,5.6,1752.8,0,-2331.1,5.6,1800.7,0,-2308.8,5.6,1856.0,1,-2343.0,5.6,1902.3,1,-2390.1,5.6,1939.5,1,-2438.0,5.6,1975.4,1,-2464.1,5.6,2028.4,1,-2443.4,5.6,2080.2,1,-2389.2,5.6,2105.7,1,-2333.6,5.6,2128.1,1,-2277.1,5.6,2148.0,1,-2265.0,5.6,2200.5,1,-2295.2,5.6,2251.8,1,-2339.5,5.6,2292.2,1,-2375.4,5.6,2339.8,1,-2391.5,5.6,2396.7,1,-2344.9,5.6,2428.7,1,-2286.4,5.6,2442.1,1,-2226.8,5.6,2448.4,1,-2169.4,5.6,2462.6,1,-2150.7,5.6,2517.5,1,-2176.9,5.6,2570.5,1,-2212.5,5.6,2618.7,1,-2238.4,5.6,2672.8,1,-2246.2,5.6,2730.1,1,-2191.9,5.6,2752.3,1,-2132.3,5.6,2755.1,1,-2073.2,5.6,2744.4,1,-2013.8,5.6,2745.7,1,-1967.3,5.6,2777.9,1,-1980.7,5.6,2835.9,1,-1995.5,5.6,2894.0,1,-2007.2,5.6,2952.8,1,-1995.3,5.6,3008.9,1,-1940.1,5.6,3029.2,1,-1885.2,5.6,3007.7,1,-1836.5,5.6,2972.6,1,-1787.1,5.6,2938.6,1,-1734.6,5.6,2912.6,1,-1700.0,5.6,2959.1,1,-1680.7,5.6,3015.8,1,-1668.2,5.6,3074.5,1,-1640.5,5.6,3127.2,1,-1593.2,5.6,3160.6,1,-1542.5,5.6,3130.2,1,-1499.7,5.6,3088.3,1,-1462.8,5.6,3041.0,1,-1412.7,5.6,3009.2,1,-1358.2,5.6,3022.4,1,-1317.3,5.6,3066.3,1,-1272.8,5.6,3106.6,1,-1219.2,5.6,3130.8,1,-1161.8,5.6,3118.1,1,-1134.7,5.6,3065.6,1,-1125.5,5.6,3006.6,1,-1129.3,5.6,2946.8,1,-1104.7,5.6,2893.3,1,-1049.2,5.6,2873.6,1,-990.1,5.6,2863.2,1,-931.7,6.7,2850.3,1,-889.4,8.1,2809.6,1,-886.1,9.5,2751.5,1,-904.5,10.9,2694.4,1,-921.1,12.3,2636.8,1,-915.9,13.7,2578.3,1,-875.5,15.2,2535.9,1,-816.2,16.6,2530.2,1,-758.3,18.0,2543.9,1,-704.0,19.5,2569.0,1,-645.4,20.9,2566.3,1,-606.2,22.4,2521.4,1,-572.3,23.8,2472.0,1,-536.7,25.2,2424.0,1,-484.1,26.6,2396.1,1,-429.3,27.8,2412.9,1,-388.0,28.8,2456.4,1,-357.2,29.7,2507.8,1,-322.3,30.5,2556.5,1,-273.7,31.1,2587.2,1,-218.3,31.5,2565.4,1,-168.6,31.8,2532.0,1,-117.2,32.0,2501.6,1,-59.2,31.9,2487.1,1,-6.5,31.8,2510.2,1,20.4,31.5,2563.1,1,14.0,31.1,2622.4,1,-3.1,30.6,2679.8,1,-25.3,30.1,2735.3,1,-4.5,29.5,2789.9,1,46.6,28.9,2820.5,1,99.8,28.3,2848.1,1,151.5,27.7,2878.4,1,188.5,27.2,2924.8,1,188.2,26.6,2981.8,1,145.8,26.0,3024.0,1,96.8,25.4,3058.4,1,44.6,24.7,3087.9,1,-2.3,24.0,3125.3,1,-19.1,23.2,3177.3,1,18.5,22.4,3223.8,1,64.3,21.5,3262.4,1,112.0,20.6,3298.8,1,154.4,19.7,3341.3,1,182.3,18.8,3392.6,1,152.1,17.8,3442.9,1,99.0,16.9,3469.2,1,39.6,15.9,3477.7,1,-20.1,14.9,3483.1,1,-80.0,13.9,3484.9,1,-123.1,12.9,3522.4,1,-120.2,11.8,3580.8,1,-97.1,10.7,3636.1,1,-76.0,9.6,3692.3,1,-59.1,8.5,3749.6,1,-70.9,7.3,3807.7,1,-122.1,6.1,3832.1,1,-182.1,5.6,3833.2,1,-242.1,5.6,3832.5,1,-301.0,5.6,3841.3,1,-352.5,5.6,3871.1,1,-361.8,5.6,3928.1,1,-341.2,5.6,3984.1,1,-302.8,5.6,4030.1,1,-260.5,5.6,4072.5,1,-227.6,5.6,4119.0,1,-255.3,5.6,4171.8,1,-295.1,5.6,4216.6,1,-333.6,5.6,4262.5,1,-367.6,5.6,4311.9,1,-361.9,5.6,4368.3,1,-316.6,5.6,4406.2,1,-258.2,5.6,4419.4,1,-199.1,5.6,4429.9,1,-139.8,5.6,4438.4,1,-102.2,5.6,4480.8,1,-109.9,5.6,4539.0,1,-138.9,5.6,4591.5,1,-162.3,5.6,4646.7,1,-180.2,5.6,4703.8,1,-155.5,5.6,4755.6,1,-100.3,5.6,4774.8,1,-41.4,5.6,4764.1,1,16.5,5.6,4748.3,1,72.5,5.6,4726.9,1,123.7,5.6,4748.6,1,139.5,5.6,4805.6,1,147.8,5.6,4864.9,1,168.0,5.6,4921.4,1,202.9,5.6,4968.7,1,261.6,5.6,4968.6,1,307.0,5.6,4931.2,1,340.5,5.6,4881.4,1,375.1,5.6,4832.4,1,416.2,5.6,4790.6,1,470.3,5.6,4812.4,1,510.0,5.6,4856.9,1,544.8,5.6,4905.7,1,589.0,5.6,4946.2,1,643.2,5.6,4961.5,1,683.7,5.6,4918.0,1,707.9,5.6,4863.5,1,723.7,5.6,4805.6,1,753.0,5.6,4753.4,1,805.5,5.6,4741.3,1,858.1,5.6,4770.1,1,909.6,5.6,4800.7,1,964.8,5.6,4821.9,1,1020.4,5.6,4802.3,1,1035.3,5.6,4747.0,1,1026.0,5.6,4687.7,1,1008.9,5.6,4630.4,1,1009.1,6.1,4573.3,1,1059.4,6.9,4542.1,1,1119.0,8.3,4536.2,1,1177.4,9.7,4523.7,1,1229.8,11.2,4495.6,1,1227.8,12.6,4439.5,1,1200.2,14.1,4386.2,1,1164.2,15.5,4338.3,1,1148.3,16.9,4282.0,1,1176.8,18.4,4232.1,1,1234.2,19.8,4215.2,1,1291.6,21.3,4197.9,1,1344.8,22.7,4172.4,1,1346.5,24.1,4113.9,1,1328.3,25.6,4057.0,1,1313.6,27.0,3999.5,1,1329.0,28.5,3942.1,1,1381.7,29.9,3921.7,1,1440.9,31.3,3931.1,1,1495.3,32.8,3956.4,1,1551.2,34.2,3945.5,1,1589.6,35.7,3900.2,1,1623.3,37.1,3850.9,1,1672.4,38.5,3816.9,1,1725.3,40.0,3834.2,1,1764.2,41.4,3879.9,1,1794.9,42.8,3931.4,1,1843.0,44.1,3963.0,1,1898.8,45.5,3947.0,1,1932.8,46.8,3897.8,1,1966.5,48.2,3848.2,1,2006.0,49.5,3804.5,1,2057.4,50.7,3831.3,1,2102.0,51.9,3871.4,1,2143.7,53.1,3914.4,1,2199.9,54.0,3927.6,1,2244.4,54.8,3891.8,1,2258.4,55.6,3833.5,1,2274.3,56.3,3775.7,1,2294.4,57.0,3719.5,1,2349.4,57.7,3717.5,1,2402.4,58.3,3745.4,1,2449.0,59.0,3783.2,1,2503.6,59.7,3805.8,1,2559.1,60.4,3791.4,1,2574.0,61.2,3733.9,1,2582.8,62.0,3674.6,1,2588.6,62.9,3614.9,1,2627.3,63.8,3576.2,1,2686.2,64.8,3583.8,1,2738.2,65.8,3613.7,1,2793.2,66.9,3636.9,1,2852.2,68.0,3644.2,1,2879.5,69.1,3595.5,1,2882.8,70.2,3535.7,1,2875.1,71.3,3476.2,1,2879.3,72.4,3417.2,1,2920.2,73.6,3378.1,1,2979.0,74.7,3389.1,1,3038.5,75.9,3395.6,1,3098.3,77.1,3394.4,1,3138.3,78.3,3355.1,1,3136.2,79.5,3296.1,1,3103.8,80.7,3245.8,1,3071.1,82.0,3195.6,1,3042.1,83.1,3143.3,1,3072.8,84.2,3098.0,1,3127.1,85.3,3072.7,1,3184.8,86.2,3056.5,1,3234.7,86.9,3024.6,1,3258.6,87.5,2971.8,1,3226.2,87.9,2922.0,1,3187.1,88.1,2876.5,1,3150.5,88.2,2829.6,1,3148.4,88.0,2770.5,1,3178.6,87.8,2719.1,1,3203.5,87.4,2664.7,1,3206.4,86.9,2605.6,1,3186.5,86.4,2549.1,1,3155.0,85.9,2498.1,1,3113.3,85.4,2455.1,1,3063.6,85.0,2421.8,1,3007.8,84.6,2399.9,1,2949.3,84.4,2386.9,1,2889.7,84.2,2380.2,1,2832.4,84.2,2396.2,1,2782.3,84.2,2428.9,1,2732.5,84.3,2461.8,1,2675.0,84.5,2474.7,1,2621.0,84.7,2449.5,1,2581.0,84.9,2405.4,1,2542.8,85.2,2359.4,1,2491.5,85.4,2334.0,1,2437.7,85.6,2360.0,1,2385.3,85.8,2389.1,1,2329.6,86.0,2410.1,1,2270.3,86.1,2405.5,1,2232.6,86.1,2361.4,1,2222.4,86.1,2302.7,1,2236.9,86.0,2244.6,1,2253.9,85.8,2187.1,1,2248.1,85.6,2130.6,1,2203.2,85.4,2091.2,1,2150.3,85.2,2062.9,1,2102.5,85.0,2026.7,1,2066.9,84.9,1979.7,1,2074.7,84.8,1921.2,1,2117.0,84.8,1880.2,1,2170.4,85.0,1853.0,1,2226.6,85.3,1831.9,1,2277.2,85.7,1801.2,1,2293.7,86.2,1747.0,1,2263.1,86.9,1695.5,1,2235.6,87.6,1642.2,1,2212.0,88.5,1587.2,1,2211.5,89.5,1527.7,1,2241.5,90.5,1478.1,1,2300.6,91.5,1472.6,1,2358.8,92.6,1485.8,1,2412.1,93.7,1513.4,1,2466.6,94.8,1538.4,1,2523.6,95.9,1553.4,1,2560.8,96.9,1508.4,1,2577.5,98.0,1451.1,1,2587.3,99.0,1391.9,1,2605.5,100.0,1334.7,1,2640.4,100.9,1288.1,1,2699.3,101.8,1284.1,1,2751.6,102.7,1312.4,1,2798.8,103.6,1349.6,1,2843.3,104.4,1389.7,1,2900.8,105.3,1402.2,1,2954.1,106.2,1377.2,1,2997.9,107.1,1336.2,1,3038.6,108.0,1292.1,1,3084.8,109.0,1254.1,1,3144.0,110.0,1249.8,1,3203.9,111.0,1246.6,1,3261.6,111.9,1230.9,1,3308.8,112.9,1195.5,1,3321.8,113.7,1137.7,1,3303.2,114.6,1081.5,1,3271.2,115.3,1030.8,1,3236.0,115.9,982.4,1,3245.1,116.5,924.9,1,3282.3,116.9,878.2,1,3319.0,117.2,830.8,1,3348.4,117.4,778.7,1,3339.9,117.4,721.6,1,3294.8,117.3,683.9,1,3235.9,117.2,673.0,1,3176.2,116.9,668.3,1,3117.3,116.6,661.3,1,3083.8,116.2,613.5,1,3078.3,115.8,553.8,1,3061.1,115.4,496.4,1,3030.0,115.0,445.8,1,2973.7,114.6,428.7,1,2921.7,114.3,454.8,1,2880.3,114.0,498.2,1,2837.4,113.7,540.2,1,2783.1,113.5,558.9,1,2729.8,113.4,533.0,1,2692.2,113.3,486.3,1,2650.7,113.3,443.0,1,2596.8,113.3,422.3,1,2539.6,113.4,439.5,1,2489.1,113.5,471.8,1,2432.2,113.6,490.5,1,2373.1,113.4,484.2,1,2324.2,112.7,451.0,1,2292.1,112.1,400.5,1,2266.2,111.5,346.7,1,2227.2,110.8,301.1,1,2186.1,110.2,257.6,1,2155.3,109.5,206.3,1,2163.1,108.9,148.6,1,2200.9,108.3,102.9,1,2251.6,107.6,71.0,1,2283.9,107.0,21.7,1,2265.7,106.3,-34.6,1,2242.4,105.7,-89.8,1,2222.9,105.0,-146.4,1,2249.1,104.3,-194.5,1,2306.5,103.6,-210.1,1,2365.9,102.8,-201.8,1,2425.6,102.0,-198.5,1,2483.9,101.2,-209.6,1,2494.7,100.3,-265.5,1,2485.6,99.3,-324.8,1,2471.1,98.2,-382.9,1,2477.8,97.0,-442.0,1,2516.0,95.7,-484.4,1,2575.7,94.3,-482.5,1,2634.2,92.8,-470.2,2,2692.7,91.4,-458.1,2,2751.3,89.9,-468.2,2,2784.5,88.5,-516.4,2,2799.7,87.1,-574.3,2,2810.0,85.6,-633.3,2,2831.1,84.2,-689.3,2,2876.9,82.7,-726.5,2,2934.9,81.3,-740.3,2,2994.7,79.9,-745.1,2,3053.9,78.4,-753.6,2,3108.9,77.0,-777.2,2,3152.1,75.5,-818.4,2,3179.5,74.1,-871.5,2,3195.8,72.7,-929.2,2,3207.0,71.2,-988.1,2,3221.0,69.8,-1046.4,2,3247.5,68.3,-1100.1,2,3286.8,66.9,-1145.3,2,3330.6,65.5,-1186.3,2,3373.2,64.0,-1228.6,2,3409.8,62.6,-1276.0,2,3434.8,61.1,-1330.3,2,3444.3,59.7,-1389.4,2,3439.7,58.3,-1449.1,2,3427.0,56.8,-1507.7,2,3412.1,55.4,-1565.9,2,3401.4,53.9,-1624.9,2,3400.1,52.5,-1684.8,2,3411.0,51.1,-1743.7,2,3431.4,49.8,-1800.1,2,3456.1,48.5,-1854.7,2,3480.2,47.2,-1909.7,2,3499.0,46.0,-1966.6,2,3507.7,44.8,-2025.9,2,3503.5,43.7,-2085.6,2,3486.7,42.6,-2143.1,2,3461.3,41.5,-2197.5,2,3432.1,40.5,-2249.9,2,3403.2,39.4,-2302.5,2,3378.7,38.4,-2357.2,2,3363.9,37.4,-2415.3,2,3360.8,36.4,-2475.1,2,3366.6,35.4,-2534.8,2,3376.4,34.5,-2594.0,2,3385.3,33.6,-2653.3,2,3388.6,32.7,-2713.2,2,3381.5,31.9,-2772.6,2,3360.5,31.1,-2828.7,2,3326.6,30.3,-2878.0,2,3285.0,29.5,-2921.2,2,3239.8,28.7,-2960.7,2,3194.6,27.8,-3000.1,2,3153.6,26.9,-3043.8,2,3123.3,25.8,-3095.1,2,3123.3,24.7,-3154.9,2,3111.6,23.5,-3213.6,2,3100.4,22.3,-3272.5,2,3074.7,21.0,-3325.8,2,3038.1,19.7,-3373.3,2,2997.0,19.5,-3416.2,2,2945.9,19.8,-3447.4,2,2902.7,20.0,-3489.0,2,2858.2,20.4,-3529.3,2,2812.7,20.9,-3568.5,2,2766.4,21.5,-3606.6,2,2717.4,22.2,-3641.3,2,2666.8,23.0,-3673.5,2,2614.6,23.9,-3703.0,2,2568.3,24.9,-3740.2,2,2531.3,26.1,-3787.3,2,2492.4,27.4,-3833.0,2,2454.7,28.9,-3879.7,2,2415.6,30.3,-3925.2,2,2375.2,31.7,-3969.6,2,2332.9,33.2,-4012.1,2,2288.1,34.6,-4052.0,2,2252.3,36.1,-4100.1,2,2216.4,37.5,-4148.1,2,2164.2,38.9,-4169.1,2,2106.9,40.4,-4151.5,2,2054.3,41.8,-4122.6,2,1999.7,43.3,-4131.3,2,1965.7,44.7,-4180.1,2,1949.3,46.1,-4237.8,2,1925.0,47.6,-4292.6,2,1883.8,49.0,-4332.1,2,1828.4,50.5,-4310.9,2,1780.0,51.9,-4275.8,2,1734.0,53.3,-4237.6,2,1675.4,54.7,-4233.6,2,1639.3,55.8,-4277.4,2,1625.7,56.6,-4335.9,2,1605.9,57.3,-4392.5,2,1568.1,57.8,-4433.3,2,1512.5,58.1,-4412.0,2,1463.6,58.2,-4377.6,2,1415.9,58.3,-4341.6,2,1357.3,58.3,-4343.2,2,1326.0,58.3,-4391.0,2,1315.0,58.3,-4449.9,2,1296.8,58.3,-4507.1,2,1259.1,58.0,-4547.4,2,1203.3,58.1,-4526.4,2,1154.2,58.4,-4492.4,2,1106.3,58.7,-4456.6,2,1047.7,59.2,-4457.6,2,1015.7,59.8,-4504.9,2,1004.1,60.6,-4563.8,2,985.0,61.5,-4620.7,2,946.4,62.6,-4660.0,2,891.0,63.9,-4638.0,2,842.4,65.3,-4603.2,2,795.0,66.8,-4566.8,2,736.4,68.2,-4567.5,2,704.1,69.6,-4614.8,2,690.3,71.1,-4673.2,2,668.2,72.5,-4729.0,2,625.4,74.0,-4762.9,2,571.0,75.4,-4738.4,2,524.7,76.8,-4700.7,2,478.2,78.3,-4663.5,2,419.6,79.7,-4665.5,2,388.4,81.2,-4714.3,2,370.6,82.6,-4771.5,2,346.5,84.0,-4826.5,2,298.2,85.5,-4849.2,2,244.4,86.9,-4822.9,2,198.7,88.0,-4784.1,2,147.5,88.9,-4755.3,2,91.1,89.7,-4769.8,2,66.8,90.6,-4824.0,2,43.5,91.5,-4879.1,2,11.9,92.4,-4929.8,2,-43.5,93.4,-4927.0,2,-92.5,94.4,-4892.6,0,-131.3,95.5,-4846.9,0,-184.2,96.7,-4821.9,0,-236.1,97.9,-4845.6,0,-270.9,99.2,-4894.4,0,-316.2,100.5,-4933.7,0,-371.0,102.0,-4945.2,0,-411.0,103.4,-4901.1,0,-433.2,104.9,-4845.8,0,-455.9,106.3,-4791.1,0,-507.7,107.7,-4763.9,0,-563.4,109.2,-4784.6,0,-620.0,110.6,-4804.1,0,-678.9,112.1,-4809.1,0,-714.4,113.5,-4762.7,0,-726.2,114.9,-4704.4,0,-732.4,116.4,-4645.0,0,-759.5,117.8,-4592.0,0,-816.6,119.3,-4585.7,0,-862.6,120.7,-4558.4,0},
	CELLS = {-4193,6.9,-1410,0,-4193,7.0,-1290,0,-4193,4.6,-1170,0,-4193,2.5,-1050,0,-4193,4.8,-930,0,-4193,7.8,-810,0,-4193,8.9,-690,0,-4193,6.5,-570,0,-4193,4.0,-450,0,-4193,2.4,-330,0,-4193,1.7,-210,0,-4193,4.0,-90,0,-4073,6.5,-1770,0,-4073,9.5,-1650,0,-4073,15.5,-1530,0,-4073,15.8,-1410,0,-4073,13.3,-1290,0,-4073,9.8,-1170,0,-4073,10.7,-1050,0,-4073,11.7,-930,0,-4073,13.6,-810,0,-4073,11.1,-690,0,-4073,4.7,-570,0,-4073,-2.8,-450,0,-4073,-8.3,-330,0,-4073,-10.9,-210,0,-4073,-8.5,-90,0,-4073,-2.2,30,0,-4073,5.2,150,0,-3953,9.0,-2010,0,-3953,12.0,-1890,0,-3953,13.7,-1770,0,-3953,18.8,-1650,0,-3953,29.5,-1530,0,-3953,29.1,-1410,0,-3953,24.3,-1290,0,-3953,20.1,-1170,0,-3953,24.0,-1050,0,-3953,22.2,-930,0,-3953,19.1,-810,0,-3953,8.7,-690,0,-3953,-1.0,-570,0,-3953,-8.6,-450,0,-3953,-14.7,-330,0,-3953,-17.7,-210,0,-3953,-13.5,-90,0,-3953,-7.9,30,0,-3953,-3.7,150,0,-3953,-0.6,270,0,-3953,4.7,390,0,-3833,16.6,-2130,0,-3833,24.9,-2010,0,-3833,28.0,-1890,0,-3833,28.8,-1770,0,-3833,37.3,-1650,0,-3833,44.6,-1530,0,-3833,38.5,-1410,0,-3833,31.9,-1290,0,-3833,30.2,-1170,0,-3833,29.7,-1050,0,-3833,26.2,-930,0,-3833,20.2,-810,0,-3833,7.1,-690,0,-3833,0.6,-570,0,-3833,-4.9,-450,0,-3833,-7.6,-330,0,-3833,-10.1,-210,0,-3833,-8.5,-90,0,-3833,-6.5,30,0,-3833,-6.6,150,0,-3833,-5.7,270,0,-3833,-3.5,390,0,-3833,2.6,510,0,-3713,6.5,-2490,0,-3713,14.8,-2370,0,-3713,22.5,-2250,0,-3713,35.1,-2130,0,-3713,50.4,-2010,0,-3713,48.7,-1890,0,-3713,45.9,-1770,0,-3713,45.3,-1650,0,-3713,51.8,-1530,0,-3713,47.7,-1410,0,-3713,40.7,-1290,0,-3713,36.0,-1170,0,-3713,30.8,-1050,0,-3713,25.8,-930,0,-3713,19.2,-810,0,-3713,12.2,-690,0,-3713,9.0,-570,0,-3713,4.7,-450,0,-3713,1.1,-330,0,-3713,0.1,-210,0,-3713,1.6,-90,0,-3713,0.6,30,0,-3713,-3.5,150,0,-3713,-9.5,270,0,-3713,-9.1,390,0,-3713,-4.1,510,0,-3713,4.6,630,0,-3593,8.6,-2610,0,-3593,21.1,-2490,0,-3593,33.8,-2370,0,-3593,48.9,-2250,0,-3593,61.7,-2130,0,-3593,65.7,-2010,0,-3593,62.6,-1890,0,-3593,57.9,-1770,0,-3593,52.8,-1650,0,-3593,56.3,-1530,0,-3593,53.9,-1410,0,-3593,48.4,-1290,0,-3593,37.7,-1170,0,-3593,30.8,-1050,0,-3593,27.7,-930,0,-3593,24.1,-810,0,-3593,21.4,-690,0,-3593,17.5,-570,0,-3593,13.9,-450,0,-3593,9.5,-330,0,-3593,9.0,-210,0,-3593,7.9,-90,0,-3593,1.9,30,0,-3593,-5.9,150,0,-3593,-12.0,270,0,-3593,-15.6,390,0,-3593,-10.4,510,0,-3593,-2.4,630,0,-3473,8.9,-2850,0,-3473,18.6,-2730,0,-3473,26.2,-2610,0,-3473,41.1,-2490,0,-3473,61.8,-2370,0,-3473,67.7,-2250,0,-3473,71.9,-2130,0,-3473,72.3,-2010,0,-3473,69.6,-1890,0,-3473,63.6,-1770,0,-3473,61.6,-1650,0,-3473,58.7,-1530,0,-3473,52.8,-1410,0,-3473,50.6,-1290,0,-3473,43.4,-1170,0,-3473,37.6,-1050,0,-3473,35.1,-930,0,-3473,31.9,-810,0,-3473,27.6,-690,0,-3473,25.2,-570,0,-3473,19.7,-450,0,-3473,15.2,-330,0,-3473,12.1,-210,0,-3473,5.6,-90,0,-3473,-4.5,30,0,-3473,-12.2,150,0,-3473,-19.5,270,0,-3473,-23.4,390,0,-3473,-21.4,510,0,-3473,-10.4,630,0,-3353,14.2,-2970,0,-3353,30.1,-2850,0,-3353,44.2,-2730,0,-3353,56.3,-2610,0,-3353,66.6,-2490,0,-3353,74.1,-2370,0,-3353,78.1,-2250,0,-3353,81.4,-2130,0,-3353,82.2,-2010,0,-3353,73.1,-1890,0,-3353,67.1,-1770,0,-3353,63.6,-1650,0,-3353,57.9,-1530,0,-3353,53.5,-1410,0,-3353,49.2,-1290,0,-3353,45.6,-1170,0,-3353,42.3,-1050,0,-3353,36.2,-930,0,-3353,34.1,-810,0,-3353,28.3,-690,0,-3353,23.3,-570,0,-3353,18.8,-450,0,-3353,14.0,-330,0,-3353,7.2,-210,0,-3353,-1.0,-90,0,-3353,-11.6,30,0,-3353,-19.4,150,0,-3353,-30.9,270,0,-3353,-37.5,390,0,-3353,-36.9,510,0,-3353,-22.3,630,0,-3353,-6.2,750,0,-3233,12.5,-3090,0,-3233,34.5,-2970,0,-3233,55.7,-2850,0,-3233,72.3,-2730,0,-3233,74.6,-2610,0,-3233,78.5,-2490,0,-3233,85.8,-2370,0,-3233,90.2,-2250,0,-3233,81.3,-2130,0,-3233,78.7,-2010,0,-3233,71.8,-1890,0,-3233,65.8,-1770,0,-3233,62.2,-1650,0,-3233,58.6,-1530,0,-3233,56.4,-1410,0,-3233,52.2,-1290,0,-3233,48.7,-1170,0,-3233,44.9,-1050,0,-3233,38.2,-930,0,-3233,32.0,-810,0,-3233,25.4,-690,0,-3233,18.1,-570,0,-3233,11.3,-450,0,-3233,5.3,-330,0,-3233,-1.0,-210,0,-3233,-8.6,-90,0,-3233,-20.8,30,0,-3233,-29.6,150,0,-3233,-39.0,270,0,-3233,-46.3,390,0,-3233,-48.1,510,0,-3233,-40.4,630,0,-3233,-20.4,750,0,-3233,5.9,870,0,-3233,3.1,1950,0,-3233,2.2,2070,0,-3113,13.0,-3330,0,-3113,30.4,-3210,0,-3113,42.5,-3090,0,-3113,58.0,-2970,0,-3113,79.7,-2850,0,-3113,83.7,-2730,0,-3113,86.1,-2610,0,-3113,88.3,-2490,0,-3113,95.6,-2370,0,-3113,82.5,-2250,0,-3113,75.5,-2130,0,-3113,73.6,-2010,0,-3113,72.1,-1890,0,-3113,67.9,-1770,0,-3113,66.5,-1650,0,-3113,61.8,-1530,0,-3113,61.2,-1410,0,-3113,52.4,-1290,0,-3113,45.4,-1170,0,-3113,39.2,-1050,0,-3113,32.0,-930,0,-3113,25.0,-810,0,-3113,17.5,-690,0,-3113,9.9,-570,0,-3113,3.2,-450,0,-3113,-4.1,-330,0,-3113,-10.3,-210,0,-3113,-17.2,-90,0,-3113,-29.4,30,0,-3113,-39.3,150,0,-3113,-47.6,270,0,-3113,-51.8,390,0,-3113,-54.9,510,0,-3113,-58.2,630,0,-3113,-32.0,750,0,-3113,-2.3,870,0,-3113,-0.1,1350,0,-3113,-13.6,1470,0,-3113,-21.3,1590,0,-3113,-21.1,1710,0,-3113,-31.1,1830,0,-3113,-41.3,1950,0,-3113,-41.2,2070,0,-3113,-31.0,2190,0,-3113,-16.9,2310,0,-3113,-7.8,2430,0,-3113,-2.8,2550,0,-3113,4.5,2670,0,-2993,16.8,-3450,0,-2993,41.7,-3330,0,-2993,61.1,-3210,0,-2993,79.0,-3090,0,-2993,88.4,-2970,0,-2993,91.1,-2850,0,-2993,97.0,-2730,0,-2993,97.6,-2610,0,-2993,90.3,-2490,0,-2993,88.2,-2370,0,-2993,81.5,-2250,0,-2993,76.0,-2130,0,-2993,74.6,-2010,0,-2993,71.5,-1890,0,-2993,70.4,-1770,0,-2993,73.0,-1650,0,-2993,66.5,-1530,0,-2993,54.0,-1410,0,-2993,46.5,-1290,0,-2993,39.0,-1170,0,-2993,30.8,-1050,0,-2993,24.3,-930,0,-2993,16.4,-810,0,-2993,9.0,-690,0,-2993,3.0,-570,0,-2993,-5.4,-450,0,-2993,-13.8,-330,0,-2993,-20.9,-210,0,-2993,-28.0,-90,0,-2993,-37.4,30,0,-2993,-43.9,150,0,-2993,-47.4,270,0,-2993,-50.1,390,0,-2993,-55.7,510,0,-2993,-62.1,630,0,-2993,-35.6,750,0,-2993,-5.2,870,0,-2993,3.4,1110,0,-2993,-10.3,1230,0,-2993,-28.9,1350,0,-2993,-46.7,1470,0,-2993,-55.8,1590,0,-2993,-55.6,1710,0,-2993,-62.2,1830,0,-2993,-76.4,1950,0,-2993,-80.2,2070,0,-2993,-68.2,2190,0,-2993,-48.4,2310,0,-2993,-37.4,2430,0,-2993,-26.5,2550,0,-2993,-15.1,2670,0,-2993,-4.1,2790,0,-2993,4.0,2910,0,-2873,13.3,-3570,0,-2873,42.4,-3450,0,-2873,70.1,-3330,0,-2873,92.0,-3210,0,-2873,95.0,-3090,0,-2873,99.0,-2970,0,-2873,103.3,-2850,0,-2873,105.7,-2730,0,-2873,90.4,-2610,0,-2873,84.7,-2490,0,-2873,82.5,-2370,0,-2873,80.4,-2250,0,-2873,77.9,-2130,0,-2873,75.1,-2010,0,-2873,70.6,-1890,0,-2873,68.6,-1770,0,-2873,64.0,-1650,0,-2873,56.4,-1530,0,-2873,46.8,-1410,0,-2873,40.1,-1290,0,-2873,33.5,-1170,0,-2873,24.0,-1050,0,-2873,16.4,-930,0,-2873,8.5,-810,0,-2873,1.6,-690,0,-2873,-6.6,-570,0,-2873,-13.7,-450,0,-2873,-23.1,-330,0,-2873,-30.9,-210,0,-2873,-34.8,-90,0,-2873,-37.0,30,0,-2873,-38.8,150,0,-2873,-41.5,270,0,-2873,-44.5,390,0,-2873,-51.6,510,0,-2873,-56.1,630,0,-2873,-40.7,750,0,-2873,-28.6,870,0,-2873,-15.7,990,0,-2873,-18.2,1110,0,-2873,-26.8,1230,0,-2873,-48.0,1350,0,-2873,-62.4,1470,0,-2873,-63.3,1590,0,-2873,-67.4,1710,0,-2873,-71.8,1830,0,-2873,-77.9,1950,0,-2873,-82.5,2070,0,-2873,-78.1,2190,0,-2873,-67.7,2310,0,-2873,-56.3,2430,0,-2873,-45.0,2550,0,-2873,-31.3,2670,0,-2873,-18.4,2790,0,-2873,-14.6,2910,0,-2873,-9.7,3030,0,-2873,0.7,3150,0,-2753,33.5,-3690,0,-2753,54.2,-3570,0,-2753,69.3,-3450,0,-2753,103.0,-3330,0,-2753,105.0,-3210,0,-2753,107.6,-3090,0,-2753,111.8,-2970,0,-2753,112.4,-2850,0,-2753,110.3,-2730,0,-2753,89.0,-2610,0,-2753,85.3,-2490,0,-2753,83.1,-2370,0,-2753,80.9,-2250,0,-2753,73.0,-2130,0,-2753,65.0,-2010,0,-2753,60.4,-1890,0,-2753,56.0,-1770,0,-2753,50.5,-1650,0,-2753,44.3,-1530,0,-2753,38.4,-1410,0,-2753,32.4,-1290,0,-2753,24.4,-1170,0,-2753,14.6,-1050,0,-2753,8.5,-930,0,-2753,4.5,-810,0,-2753,0.3,-690,0,-2753,-5.1,-570,0,-2753,-19.5,-450,0,-2753,-27.4,-330,0,-2753,-29.5,-210,0,-2753,-29.3,-90,0,-2753,-28.4,30,0,-2753,-31.1,150,0,-2753,-35.8,270,0,-2753,-41.3,390,0,-2753,-48.9,510,0,-2753,-52.8,630,0,-2753,-50.8,750,0,-2753,-45.0,870,0,-2753,-30.4,990,0,-2753,-31.1,1110,0,-2753,-37.9,1230,0,-2753,-43.4,1350,0,-2753,-45.7,1470,0,-2753,-49.7,1590,0,-2753,-58.4,1710,0,-2753,-66.6,1830,0,-2753,-73.5,1950,0,-2753,-75.6,2070,0,-2753,-70.1,2190,0,-2753,-61.4,2310,0,-2753,-51.3,2430,0,-2753,-39.9,2550,0,-2753,-34.3,2670,0,-2753,-31.8,2790,0,-2753,-31.9,2910,0,-2753,-29.7,3030,0,-2753,-19.7,3150,0,-2753,-2.0,3270,0,-2633,43.7,-3810,0,-2633,74.6,-3690,0,-2633,99.0,-3570,0,-2633,113.5,-3450,0,-2633,115.7,-3330,0,-2633,118.8,-3210,0,-2633,118.5,-3090,0,-2633,104.2,-2970,0,-2633,99.9,-2850,0,-2633,97.0,-2730,0,-2633,89.6,-2610,0,-2633,88.1,-2490,0,-2633,78.8,-2370,0,-2633,71.3,-2250,0,-2633,64.1,-2130,0,-2633,57.0,-2010,0,-2633,50.5,-1890,0,-2633,43.2,-1770,0,-2633,39.2,-1650,0,-2633,34.9,-1530,0,-2633,25.3,-1410,0,-2633,17.4,-1290,0,-2633,11.7,-1170,0,-2633,7.6,-1050,0,-2633,5.8,-930,0,-2633,5.0,-810,0,-2633,3.9,-690,0,-2633,-5.9,-570,0,-2633,-20.3,-450,0,-2633,-23.6,-330,0,-2633,-21.6,-210,0,-2633,-20.2,-90,0,-2633,-18.9,30,0,-2633,-22.0,150,0,-2633,-32.0,270,0,-2633,-41.1,390,0,-2633,-46.5,510,0,-2633,-48.4,630,0,-2633,-46.6,750,0,-2633,-39.7,870,0,-2633,-28.8,990,0,-2633,-25.3,1110,0,-2633,-26.5,1230,0,-2633,-32.4,1350,0,-2633,-36.9,1470,0,-2633,-44.1,1590,0,-2633,-55.6,1710,0,-2633,-65.8,1830,0,-2633,-71.3,1950,0,-2633,-68.8,2070,0,-2633,-64.2,2190,0,-2633,-58.3,2310,0,-2633,-48.4,2430,0,-2633,-34.7,2550,0,-2633,-30.6,2670,0,-2633,-30.9,2790,0,-2633,-36.7,2910,0,-2633,-43.0,3030,0,-2633,-35.0,3150,0,-2633,-15.2,3270,0,-2633,-0.6,3390,0,-2513,6.0,-4050,0,-2513,39.3,-3930,0,-2513,81.2,-3810,0,-2513,117.5,-3690,0,-2513,122.8,-3570,0,-2513,123.1,-3450,0,-2513,124.0,-3330,0,-2513,121.8,-3210,0,-2513,107.1,-3090,0,-2513,100.4,-2970,0,-2513,97.5,-2850,0,-2513,94.6,-2730,0,-2513,87.6,-2610,0,-2513,78.0,-2490,0,-2513,69.6,-2370,0,-2513,63.9,-2250,0,-2513,56.5,-2130,0,-2513,49.8,-2010,0,-2513,42.9,-1890,0,-2513,38.1,-1770,0,-2513,27.9,-1650,0,-2513,20.1,-1530,0,-2513,12.8,-1410,0,-2513,7.7,-1290,0,-2513,6.3,-1170,0,-2513,-1.8,-570,0,-2513,-10.3,-450,0,-2513,-13.6,-330,0,-2513,-13.2,-210,0,-2513,-14.5,-90,0,-2513,-16.8,30,0,-2513,-23.8,150,0,-2513,-33.8,270,0,-2513,-40.3,390,0,-2513,-40.3,510,0,-2513,-38.7,630,0,-2513,-37.9,750,0,-2513,-33.6,870,0,-2513,-24.8,990,0,-2513,-17.7,1110,0,-2513,-18.9,1230,0,-2513,-26.1,1350,0,-2513,-34.0,1470,0,-2513,-44.4,1590,0,-2513,-55.4,1710,0,-2513,-63.7,1830,0,-2513,-65.2,1950,0,-2513,-61.3,2070,0,-2513,-58.6,2190,0,-2513,-54.1,2310,0,-2513,-42.3,2430,0,-2513,-32.7,2550,0,-2513,-28.7,2670,0,-2513,-29.2,2790,0,-2513,-35.3,2910,0,-2513,-40.3,3030,0,-2513,-41.2,3150,0,-2513,-26.0,3270,0,-2513,-16.1,3390,0,-2513,-4.3,3510,0,-2393,24.7,-4170,0,-2393,60.7,-4050,0,-2393,85.9,-3930,0,-2393,118.9,-3810,0,-2393,134.6,-3690,0,-2393,135.1,-3570,0,-2393,134.5,-3450,0,-2393,128.4,-3330,0,-2393,118.1,-3210,0,-2393,106.8,-3090,0,-2393,101.1,-2970,0,-2393,96.2,-2850,0,-2393,87.1,-2730,0,-2393,78.9,-2610,0,-2393,70.9,-2490,0,-2393,64.8,-2370,0,-2393,58.7,-2250,0,-2393,50.2,-2130,0,-2393,43.1,-2010,0,-2393,38.6,-1890,0,-2393,26.2,-1770,0,-2393,14.5,-1650,0,-2393,9.9,-1530,0,-2393,6.8,-1410,0,-2393,4.3,-570,0,-2393,0.2,-450,0,-2393,-5.9,-330,0,-2393,-10.8,-210,0,-2393,-16.6,-90,0,-2393,-23.0,30,0,-2393,-29.1,150,0,-2393,-33.6,270,0,-2393,-33.9,390,0,-2393,-31.3,510,0,-2393,-29.6,630,0,-2393,-30.5,750,0,-2393,-28.7,870,0,-2393,-21.0,990,0,-2393,-13.5,1110,0,-2393,-17.0,1230,0,-2393,-25.4,1350,0,-2393,-35.9,1470,0,-2393,-46.0,1590,0,-2393,-54.2,1710,0,-2393,-55.3,1830,0,-2393,-50.9,1950,0,-2393,-47.9,2070,0,-2393,-48.5,2190,0,-2393,-48.3,2310,0,-2393,-39.0,2430,0,-2393,-29.8,2550,0,-2393,-26.5,2670,0,-2393,-28.5,2790,0,-2393,-34.0,2910,0,-2393,-37.7,3030,0,-2393,-34.8,3150,0,-2393,-31.9,3270,0,-2393,-26.9,3390,0,-2393,-16.9,3510,0,-2393,-1.7,3630,0,-2273,26.1,-4290,0,-2273,75.1,-4170,0,-2273,117.6,-4050,0,-2273,148.0,-3930,0,-2273,145.7,-3810,0,-2273,143.7,-3690,0,-2273,143.5,-3570,0,-2273,120.8,-3450,0,-2273,115.5,-3330,0,-2273,111.2,-3210,0,-2273,106.8,-3090,0,-2273,104.0,-2970,0,-2273,95.7,-2850,0,-2273,85.6,-2730,0,-2273,75.5,-2610,0,-2273,67.7,-2490,0,-2273,59.3,-2370,0,-2273,53.3,-2250,0,-2273,41.4,-2130,0,-2273,30.7,-2010,0,-2273,23.2,-1890,0,-2273,14.8,-1770,0,-2273,7.8,-1650,0,-2273,5.9,-570,0,-2273,2.3,-450,0,-2273,-6.0,-330,0,-2273,-14.3,-210,0,-2273,-20.9,-90,0,-2273,-26.5,30,0,-2273,-28.2,150,0,-2273,-25.5,270,0,-2273,-22.2,390,0,-2273,-19.6,510,0,-2273,-21.9,630,0,-2273,-25.2,750,0,-2273,-21.5,870,0,-2273,-14.9,990,0,-2273,-10.7,1110,0,-2273,-17.6,1230,0,-2273,-27.7,1350,0,-2273,-38.5,1470,0,-2273,-46.7,1590,0,-2273,-50.1,1710,0,-2273,-46.5,1830,0,-2273,-38.4,1950,0,-2273,-36.8,2070,0,-2273,-41.1,2190,0,-2273,-41.4,2310,0,-2273,-35.1,2430,0,-2273,-25.3,2550,0,-2273,-24.1,2670,0,-2273,-29.7,2790,0,-2273,-33.6,2910,0,-2273,-31.4,3030,0,-2273,-26.5,3150,0,-2273,-27.0,3270,0,-2273,-31.5,3390,0,-2273,-26.4,3510,0,-2273,-11.6,3630,0,-2153,20.3,-4410,0,-2153,68.6,-4290,0,-2153,127.0,-4170,0,-2153,160.7,-4050,0,-2153,154.9,-3930,0,-2153,151.7,-3810,0,-2153,150.4,-3690,0,-2153,145.6,-3570,0,-2153,117.8,-3450,0,-2153,113.3,-3330,0,-2153,110.4,-3210,0,-2153,108.3,-3090,0,-2153,105.7,-2970,0,-2153,95.1,-2850,0,-2153,86.2,-2730,0,-2153,75.4,-2610,0,-2153,67.8,-2490,0,-2153,59.7,-2370,0,-2153,49.4,-2250,0,-2153,30.9,-2130,0,-2153,17.2,-2010,0,-2153,11.7,-1890,0,-2153,3.1,-450,0,-2153,-4.6,-330,0,-2153,-13.8,-210,0,-2153,-15.3,-90,0,-2153,-17.9,30,0,-2153,-16.5,150,0,-2153,-11.7,270,0,-2153,-12.7,390,0,-2153,-14.0,510,0,-2153,-17.8,630,0,-2153,-17.7,750,0,-2153,-14.4,870,0,-2153,-9.8,990,0,-2153,-8.8,1110,0,-2153,-17.2,1230,0,-2153,-29.0,1350,0,-2153,-38.4,1470,0,-2153,-41.8,1590,0,-2153,-39.1,1710,0,-2153,-36.5,1830,0,-2153,-30.1,1950,0,-2153,-27.0,2070,0,-2153,-30.4,2190,0,-2153,-31.5,2310,0,-2153,-28.1,2430,0,-2153,-19.4,2550,0,-2153,-21.6,2670,0,-2153,-27.9,2790,0,-2153,-25.8,2910,0,-2153,-22.7,3030,0,-2153,-21.0,3150,0,-2153,-23.9,3270,0,-2153,-28.8,3390,0,-2153,-31.5,3510,0,-2153,-17.4,3630,0,-2153,0.4,3750,0,-2033,41.2,-4530,0,-2033,81.8,-4410,0,-2033,118.6,-4290,0,-2033,170.4,-4170,0,-2033,163.3,-4050,0,-2033,157.0,-3930,0,-2033,151.1,-3810,0,-2033,132.4,-3690,0,-2033,124.8,-3570,0,-2033,117.6,-3450,0,-2033,115.5,-3330,0,-2033,114.8,-3210,0,-2033,107.2,-3090,0,-2033,97.8,-2970,0,-2033,91.9,-2850,0,-2033,84.9,-2730,0,-2033,75.0,-2610,0,-2033,63.0,-2490,0,-2033,49.1,-2370,0,-2033,34.0,-2250,0,-2033,20.3,-2130,0,-2033,6.4,-2010,0,-2033,5.3,-450,0,-2033,0.7,-330,0,-2033,-2.2,-210,0,-2033,-5.1,-90,0,-2033,-5.1,30,0,-2033,-4.8,150,0,-2033,-4.7,270,0,-2033,-7.9,390,0,-2033,-7.9,510,0,-2033,-10.3,630,0,-2033,-11.5,750,0,-2033,-9.2,870,0,-2033,-5.8,990,0,-2033,-7.7,1110,0,-2033,-17.5,1230,0,-2033,-29.5,1350,0,-2033,-36.1,1470,0,-2033,-33.2,1590,0,-2033,-25.4,1710,0,-2033,-23.7,1830,0,-2033,-20.7,1950,0,-2033,-19.3,2070,0,-2033,-20.5,2190,0,-2033,-20.6,2310,0,-2033,-17.6,2430,0,-2033,-14.3,2550,0,-2033,-19.7,2670,0,-2033,-21.9,2790,0,-2033,-19.6,2910,0,-2033,-18.4,3030,0,-2033,-19.2,3150,0,-2033,-21.7,3270,0,-2033,-26.3,3390,0,-2033,-31.3,3510,0,-2033,-20.1,3630,0,-2033,-2.3,3750,0,-1913,44.9,-4650,0,-1913,99.0,-4530,0,-1913,148.8,-4410,0,-1913,174.3,-4290,0,-1913,169.0,-4170,0,-1913,161.4,-4050,0,-1913,153.2,-3930,0,-1913,131.3,-3810,0,-1913,126.1,-3690,0,-1913,122.8,-3570,0,-1913,119.6,-3450,0,-1913,116.3,-3330,0,-1913,108.6,-3210,0,-1913,99.6,-3090,0,-1913,92.1,-2970,0,-1913,86.8,-2850,0,-1913,79.8,-2730,0,-1913,68.9,-2610,0,-1913,41.1,-2490,0,-1913,27.1,-2370,0,-1913,16.4,-2250,0,-1913,5.5,-330,0,-1913,5.7,-210,0,-1913,6.3,-90,0,-1913,5.5,30,0,-1913,2.8,150,0,-1913,-0.7,270,0,-1913,-4.3,390,0,-1913,-4.4,510,0,-1913,-5.0,630,0,-1913,-6.8,750,0,-1913,-5.3,870,0,-1913,-5.6,990,0,-1913,-13.7,1110,0,-1913,-21.3,1230,0,-1913,-27.6,1350,0,-1913,-26.6,1470,0,-1913,-19.9,1590,0,-1913,-13.8,1710,0,-1913,-11.3,1830,0,-1913,-12.4,1950,0,-1913,-11.2,2070,0,-1913,-10.6,2190,0,-1913,-9.1,2310,0,-1913,-7.5,2430,0,-1913,-8.5,2550,0,-1913,-15.3,2670,0,-1913,-19.4,2790,0,-1913,-16.8,2910,0,-1913,-15.8,3030,0,-1913,-17.6,3150,0,-1913,-21.4,3270,0,-1913,-26.7,3390,0,-1913,-30.0,3510,0,-1913,-21.5,3630,0,-1913,-8.1,3750,0,-1913,5.7,3870,0,-1793,31.6,-4770,0,-1793,92.2,-4650,0,-1793,156.5,-4530,0,-1793,179.2,-4410,0,-1793,173.2,-4290,0,-1793,165.2,-4170,0,-1793,159.1,-4050,0,-1793,135.2,-3930,0,-1793,128.1,-3810,0,-1793,125.4,-3690,0,-1793,123.4,-3570,0,-1793,117.2,-3450,0,-1793,111.5,-3330,0,-1793,104.6,-3210,0,-1793,96.4,-3090,0,-1793,87.7,-2970,0,-1793,81.3,-2850,0,-1793,71.0,-2730,0,-1793,47.7,-2610,0,-1793,26.2,-2490,0,-1793,6.4,-210,0,-1793,9.6,-90,0,-1793,12.0,30,0,-1793,8.7,150,0,-1793,2.2,270,0,-1793,0.4,390,0,-1793,1.6,510,0,-1793,0.4,630,0,-1793,-1.0,750,0,-1793,-4.2,870,0,-1793,-11.4,990,0,-1793,-19.0,1110,0,-1793,-22.4,1230,0,-1793,-22.9,1350,0,-1793,-17.5,1470,0,-1793,-13.2,1590,0,-1793,-2.3,1710,0,-1793,1.9,1830,0,-1793,0.2,1950,0,-1793,0.5,2070,0,-1793,2.4,2190,0,-1793,1.2,2310,0,-1793,-2.5,2430,0,-1793,-4.9,2550,0,-1793,-10.6,2670,0,-1793,-15.8,2790,0,-1793,-14.1,2910,0,-1793,-11.1,3030,0,-1793,-12.6,3150,0,-1793,-18.5,3270,0,-1793,-24.7,3390,0,-1793,-23.9,3510,0,-1793,-21.5,3630,0,-1793,-11.3,3750,0,-1793,0.7,3870,0,-1673,45.2,-4890,0,-1673,92.0,-4770,0,-1673,132.7,-4650,0,-1673,177.5,-4530,0,-1673,172.2,-4410,0,-1673,165.0,-4290,0,-1673,158.8,-4170,0,-1673,140.0,-4050,0,-1673,135.2,-3930,0,-1673,129.4,-3810,0,-1673,129.4,-3690,0,-1673,122.2,-3570,0,-1673,115.0,-3450,0,-1673,107.0,-3330,0,-1673,98.9,-3210,0,-1673,92.9,-3090,0,-1673,85.3,-2970,0,-1673,61.4,-2850,0,-1673,45.2,-2730,0,-1673,28.0,-2610,0,-1673,7.8,-2490,0,-1673,9.6,30,0,-1673,9.7,150,0,-1673,7.1,270,0,-1673,7.8,390,0,-1673,8.0,510,0,-1673,5.3,630,0,-1673,2.1,750,0,-1673,-7.3,870,0,-1673,-15.3,990,0,-1673,-19.4,1110,0,-1673,-18.1,1230,0,-1673,-13.4,1350,0,-1673,-5.3,1470,0,-1673,-2.1,1590,0,-1673,5.8,1710,0,-1673,7.7,1830,0,-1673,6.3,1950,0,-1673,6.1,2070,0,-1673,6.6,2190,0,-1673,4.1,2310,0,-1673,0.3,2430,0,-1673,-5.2,2550,0,-1673,-9.8,2670,0,-1673,-11.9,2790,0,-1673,-8.0,2910,0,-1673,-6.5,3030,0,-1673,-9.9,3150,0,-1673,-17.3,3270,0,-1673,-21.7,3390,0,-1673,-17.8,3510,0,-1673,-16.7,3630,0,-1673,-12.9,3750,0,-1673,-2.6,3870,0,-1553,38.8,-5010,0,-1553,89.2,-4890,0,-1553,136.1,-4770,0,-1553,162.4,-4650,0,-1553,169.5,-4530,0,-1553,165.9,-4410,0,-1553,157.8,-4290,0,-1553,136.5,-4170,0,-1553,134.4,-4050,0,-1553,134.2,-3930,0,-1553,132.2,-3810,0,-1553,129.2,-3690,0,-1553,121.5,-3570,0,-1553,112.9,-3450,0,-1553,104.6,-3330,0,-1553,98.2,-3210,0,-1553,93.2,-3090,0,-1553,67.7,-2970,0,-1553,36.1,-2850,0,-1553,18.4,-2730,0,-1553,6.8,150,0,-1553,8.1,270,0,-1553,9.9,390,0,-1553,11.2,510,0,-1553,9.6,630,0,-1553,4.1,750,0,-1553,-3.7,870,0,-1553,-12.2,990,0,-1553,-12.8,1110,0,-1553,-6.8,1230,0,-1553,0.3,1350,0,-1553,4.8,1470,0,-1553,7.1,1590,0,-1553,9.0,1710,0,-1553,7.4,1830,0,-1553,6.7,1950,0,-1553,6.8,2070,0,-1553,7.2,2190,0,-1553,5.4,2310,0,-1553,-0.8,2430,0,-1553,-6.7,2550,0,-1553,-10.9,2670,0,-1553,-7.1,2790,0,-1553,-3.7,2910,0,-1553,-4.9,3030,0,-1553,-10.6,3150,0,-1553,-16.9,3270,0,-1553,-19.1,3390,0,-1553,-13.7,3510,0,-1553,-15.0,3630,0,-1553,-14.7,3750,0,-1553,-4.3,3870,0,-1433,16.0,-5130,0,-1433,66.7,-5010,0,-1433,116.8,-4890,0,-1433,144.2,-4770,0,-1433,152.6,-4650,0,-1433,162.7,-4530,0,-1433,161.1,-4410,0,-1433,138.7,-4290,0,-1433,133.4,-4170,0,-1433,133.9,-4050,0,-1433,134.7,-3930,0,-1433,130.8,-3810,0,-1433,125.4,-3690,0,-1433,119.1,-3570,0,-1433,111.2,-3450,0,-1433,105.5,-3330,0,-1433,98.8,-3210,0,-1433,73.6,-3090,0,-1433,45.3,-2970,0,-1433,15.9,-2850,0,-1433,8.3,510,0,-1433,9.0,630,0,-1433,5.8,750,0,-1433,2.2,870,0,-1433,-1.1,990,0,-1433,0.5,1110,0,-1433,4.0,1230,0,-1433,7.0,1350,0,-1433,7.1,1470,0,-1433,6.3,1590,0,-1433,7.5,2070,0,-1433,8.1,2190,0,-1433,5.3,2310,0,-1433,0.3,2430,0,-1433,-7.0,2550,0,-1433,-8.7,2670,0,-1433,-0.4,2790,0,-1433,-0.3,2910,0,-1433,-5.0,3030,0,-1433,-9.8,3150,0,-1433,-13.7,3270,0,-1433,-14.4,3390,0,-1433,-13.2,3510,0,-1433,-16.7,3630,0,-1433,-14.7,3750,0,-1433,-2.3,3870,0,-1313,11.8,-5250,0,-1313,39.0,-5130,0,-1313,80.1,-5010,0,-1313,122.1,-4890,0,-1313,134.4,-4770,0,-1313,147.8,-4650,0,-1313,134.4,-4530,0,-1313,132.4,-4410,0,-1313,132.9,-4290,0,-1313,132.2,-4170,0,-1313,134.3,-4050,0,-1313,135.0,-3930,0,-1313,129.7,-3810,0,-1313,123.5,-3690,0,-1313,118.7,-3570,0,-1313,113.6,-3450,0,-1313,91.7,-3330,0,-1313,64.8,-3210,0,-1313,41.9,-3090,0,-1313,16.4,-2970,0,-1313,5.9,1110,0,-1313,6.0,1230,0,-1313,7.8,1950,0,-1313,9.1,2070,0,-1313,6.2,2190,0,-1313,2.0,2310,0,-1313,-0.8,2430,0,-1313,0.2,2550,0,-1313,1.6,2670,0,-1313,5.0,2790,0,-1313,2.3,2910,0,-1313,-3.6,3030,0,-1313,-8.7,3150,0,-1313,-10.1,3270,0,-1313,-11.3,3390,0,-1313,-14.4,3510,0,-1313,-21.7,3630,0,-1313,-13.6,3750,0,-1313,1.0,3870,0,-1193,13.0,-5370,0,-1193,44.9,-5250,0,-1193,72.5,-5130,0,-1193,96.8,-5010,0,-1193,115.0,-4890,0,-1193,128.5,-4770,0,-1193,142.9,-4650,0,-1193,128.5,-4530,0,-1193,126.0,-4410,0,-1193,128.2,-4290,0,-1193,130.8,-4170,0,-1193,136.0,-4050,0,-1193,138.3,-3930,0,-1193,132.7,-3810,0,-1193,128.0,-3690,0,-1193,122.5,-3570,0,-1193,108.4,-3450,0,-1193,70.1,-3330,0,-1193,29.1,-3210,0,-1193,6.3,1830,0,-1193,10.8,1950,0,-1193,10.3,2070,0,-1193,3.7,2190,0,-1193,1.5,2310,0,-1193,2.5,2430,0,-1193,8.5,2550,0,-1193,9.3,2670,0,-1193,6.4,2790,0,-1193,2.3,2910,0,-1193,-1.7,3030,0,-1193,-5.1,3150,0,-1193,-6.8,3270,0,-1193,-9.2,3390,0,-1193,-14.4,3510,0,-1193,-21.2,3630,0,-1193,-11.3,3750,0,-1193,1.3,3870,0,-1073,37.0,-5370,0,-1073,67.7,-5250,0,-1073,97.0,-5130,0,-1073,104.4,-5010,0,-1073,115.8,-4890,0,-1073,128.7,-4770,0,-1073,129.8,-4650,0,-1073,123.9,-4530,0,-1073,123.9,-4410,0,-1073,130.3,-4290,0,-1073,135.1,-4170,0,-1073,148.9,-4050,0,-1073,144.7,-3930,0,-1073,138.6,-3810,0,-1073,132.9,-3690,0,-1073,108.4,-3570,0,-1073,75.1,-3450,0,-1073,39.0,-3330,0,-1073,9.0,1830,0,-1073,13.5,1950,0,-1073,12.3,2070,0,-1073,7.1,2190,0,-1073,8.7,2310,0,-1073,11.9,2430,0,-1073,13.2,2550,0,-1073,10.0,2670,0,-1073,4.1,2790,0,-1073,2.1,2910,0,-1073,1.8,3030,0,-1073,-0.4,3150,0,-1073,-3.2,3270,0,-1073,-6.7,3390,0,-1073,-13.9,3510,0,-1073,-17.8,3630,0,-1073,-6.0,3750,0,-1073,-0.7,3870,0,-1073,-1.9,3990,0,-1073,0.8,4110,0,-1073,-1.0,4230,0,-1073,-2.1,4350,0,-1073,-3.9,4470,0,-1073,-0.5,4590,0,-953,19.5,-5490,0,-953,52.9,-5370,0,-953,86.9,-5250,0,-953,94.4,-5130,0,-953,103.5,-5010,0,-953,116.4,-4890,0,-953,128.9,-4770,0,-953,121.2,-4650,0,-953,119.2,-4530,0,-953,121.7,-4410,0,-953,128.8,-4290,0,-953,158.1,-4170,0,-953,158.3,-4050,0,-953,153.4,-3930,0,-953,145.9,-3810,0,-953,107.5,-3690,0,-953,64.1,-3570,0,-953,34.1,-3450,0,-953,10.6,1830,0,-953,15.1,1950,0,-953,13.6,2070,0,-953,11.6,2190,0,-953,17.4,2310,0,-953,16.2,2430,0,-953,10.8,2550,0,-953,8.7,2670,0,-953,4.1,2790,0,-953,4.1,2910,0,-953,5.6,3030,0,-953,2.4,3150,0,-953,-2.6,3270,0,-953,-6.4,3390,0,-953,-12.6,3510,0,-953,-11.2,3630,0,-953,-5.8,3750,0,-953,-10.1,3870,0,-953,-12.8,3990,0,-953,-10.2,4110,0,-953,-11.0,4230,0,-953,-13.9,4350,0,-953,-19.5,4470,0,-953,-18.3,4590,0,-953,-8.0,4710,0,-953,2.5,4830,0,-833,27.3,-5490,0,-833,59.9,-5370,0,-833,83.5,-5250,0,-833,93.6,-5130,0,-833,106.2,-5010,0,-833,116.2,-4890,0,-833,114.3,-4770,0,-833,115.6,-4650,0,-833,116.3,-4530,0,-833,122.5,-4410,0,-833,144.2,-4290,0,-833,157.7,-4170,0,-833,162.7,-4050,0,-833,159.0,-3930,0,-833,128.5,-3810,0,-833,77.3,-3690,0,-833,26.1,-3570,0,-833,7.1,1710,0,-833,13.4,1830,0,-833,15.1,1950,0,-833,15.5,2070,0,-833,17.1,2190,0,-833,21.2,2310,0,-833,15.6,2430,0,-833,12.2,2550,0,-833,8.7,2670,0,-833,5.9,2790,0,-833,7.2,2910,0,-833,9.2,3030,0,-833,3.5,3150,0,-833,-1.1,3270,0,-833,-5.8,3390,0,-833,-10.5,3510,0,-833,-8.2,3630,0,-833,-9.4,3750,0,-833,-12.9,3870,0,-833,-14.7,3990,0,-833,-14.1,4110,0,-833,-13.2,4230,0,-833,-18.5,4350,0,-833,-28.1,4470,0,-833,-32.8,4590,0,-833,-21.5,4710,0,-833,-7.7,4830,0,-833,-1.4,4950,0,-833,2.9,5070,0,-713,13.6,-5610,0,-713,38.8,-5490,0,-713,64.8,-5370,0,-713,79.5,-5250,0,-713,90.1,-5130,0,-713,101.0,-5010,0,-713,110.2,-4890,0,-713,109.8,-4770,0,-713,108.9,-4650,0,-713,110.7,-4530,0,-713,122.7,-4410,0,-713,139.2,-4290,0,-713,153.2,-4170,0,-713,162.1,-4050,0,-713,123.3,-3930,0,-713,83.0,-3810,0,-713,36.0,-3690,0,-713,11.4,1710,0,-713,17.0,1830,0,-713,18.0,1950,0,-713,19.1,2070,0,-713,24.2,2190,0,-713,26.1,2310,0,-713,18.6,2430,0,-713,15.8,2550,0,-713,14.5,2670,0,-713,12.4,2790,0,-713,13.5,2910,0,-713,12.5,3030,0,-713,8.8,3150,0,-713,3.4,3270,0,-713,-3.3,3390,0,-713,-6.1,3510,0,-713,-6.6,3630,0,-713,-7.0,3750,0,-713,-8.3,3870,0,-713,-8.7,3990,0,-713,-9.4,4110,0,-713,-9.6,4230,0,-713,-16.1,4350,0,-713,-23.8,4470,0,-713,-29.0,4590,0,-713,-29.0,4710,0,-713,-17.5,4830,0,-713,-9.1,4950,0,-713,-4.3,5070,0,-713,-0.3,5190,0,-593,22.9,-5610,0,-593,48.8,-5490,0,-593,69.1,-5370,0,-593,76.8,-5250,0,-593,84.1,-5130,0,-593,89.2,-5010,0,-593,96.3,-4890,0,-593,100.1,-4770,0,-593,102.2,-4650,0,-593,108.0,-4530,0,-593,121.6,-4410,0,-593,137.4,-4290,0,-593,151.4,-4170,0,-593,141.3,-4050,0,-593,85.1,-3930,0,-593,28.2,-3810,0,-593,13.1,1710,0,-593,19.2,1830,0,-593,22.1,1950,0,-593,24.1,2070,0,-593,27.7,2190,0,-593,26.5,2310,0,-593,20.9,2430,0,-593,18.7,2550,0,-593,20.7,2670,0,-593,18.7,2790,0,-593,15.8,2910,0,-593,14.4,3030,0,-593,11.7,3150,0,-593,5.2,3270,0,-593,-1.7,3390,0,-593,-0.5,3510,0,-593,-0.2,3630,0,-593,-2.6,3750,0,-593,-4.2,3870,0,-593,-3.2,3990,0,-593,-5.7,4110,0,-593,-8.0,4230,0,-593,-11.9,4350,0,-593,-19.4,4470,0,-593,-25.8,4590,0,-593,-24.2,4710,0,-593,-16.6,4830,0,-593,-12.2,4950,0,-593,-12.2,5070,0,-593,-10.3,5190,0,-593,-2.6,5310,0,-473,26.5,-5610,0,-473,52.1,-5490,0,-473,66.4,-5370,0,-473,72.5,-5250,0,-473,76.1,-5130,0,-473,78.4,-5010,0,-473,84.6,-4890,0,-473,91.0,-4770,0,-473,100.9,-4650,0,-473,111.6,-4530,0,-473,123.7,-4410,0,-473,137.4,-4290,0,-473,151.1,-4170,0,-473,105.4,-4050,0,-473,47.8,-3930,0,-473,13.2,1710,0,-473,20.7,1830,0,-473,26.8,1950,0,-473,30.3,2070,0,-473,32.3,2190,0,-473,25.1,2310,0,-473,23.0,2430,0,-473,24.2,2550,0,-473,23.1,2670,0,-473,19.7,2790,0,-473,16.6,2910,0,-473,15.0,3030,0,-473,10.5,3150,0,-473,4.7,3270,0,-473,2.5,3390,0,-473,6.9,3510,0,-473,4.7,3630,0,-473,0.8,3750,0,-473,-0.7,3870,0,-473,-0.1,3990,0,-473,-3.8,4110,0,-473,-7.0,4230,0,-473,-10.2,4350,0,-473,-16.9,4470,0,-473,-22.1,4590,0,-473,-17.7,4710,0,-473,-11.8,4830,0,-473,-10.6,4950,0,-473,-15.6,5070,0,-473,-19.1,5190,0,-473,-8.9,5310,0,-473,2.1,5430,0,-353,27.2,-5610,0,-353,50.9,-5490,0,-353,62.3,-5370,0,-353,68.5,-5250,0,-353,72.6,-5130,0,-353,76.9,-5010,0,-353,82.7,-4890,0,-353,90.4,-4770,0,-353,100.5,-4650,0,-353,113.9,-4530,0,-353,126.7,-4410,0,-353,139.1,-4290,0,-353,112.1,-4170,0,-353,68.7,-4050,0,-353,8.2,-3930,0,-353,13.4,1710,0,-353,23.4,1830,0,-353,31.4,1950,0,-353,35.0,2070,0,-353,36.2,2190,0,-353,28.9,2310,0,-353,26.3,2430,0,-353,27.8,2550,0,-353,25.0,2670,0,-353,22.2,2790,0,-353,18.4,2910,0,-353,14.5,3030,0,-353,10.2,3150,0,-353,9.1,3270,0,-353,9.5,3390,0,-353,10.5,3510,0,-353,8.5,3630,0,-353,4.5,3750,0,-353,1.4,3870,0,-353,-0.1,3990,0,-353,-3.0,4110,0,-353,-7.2,4230,0,-353,-12.0,4350,0,-353,-18.4,4470,0,-353,-18.9,4590,0,-353,-13.9,4710,0,-353,-9.1,4830,0,-353,-9.7,4950,0,-353,-14.4,5070,0,-353,-16.6,5190,0,-353,-10.4,5310,0,-353,-2.5,5430,0,-233,24.5,-5610,0,-233,48.5,-5490,0,-233,63.0,-5370,0,-233,68.7,-5250,0,-233,75.6,-5130,0,-233,78.4,-5010,0,-233,85.5,-4890,0,-233,93.8,-4770,0,-233,101.0,-4650,0,-233,114.7,-4530,0,-233,126.4,-4410,0,-233,127.1,-4290,0,-233,77.5,-4170,0,-233,21.1,-4050,0,-233,11.7,1710,0,-233,24.0,1830,0,-233,36.0,1950,0,-233,37.5,2070,0,-233,38.5,2190,0,-233,38.4,2310,0,-233,31.8,2430,0,-233,29.0,2550,0,-233,28.6,2670,0,-233,25.9,2790,0,-233,20.2,2910,0,-233,14.9,3030,0,-233,13.3,3150,0,-233,15.0,3270,0,-233,13.3,3390,0,-233,11.8,3510,0,-233,10.5,3630,0,-233,4.1,3750,0,-233,2.8,3870,0,-233,0.8,3990,0,-233,-3.0,4110,0,-233,-8.1,4230,0,-233,-13.3,4350,0,-233,-16.7,4470,0,-233,-16.4,4590,0,-233,-10.2,4710,0,-233,-6.3,4830,0,-233,-9.5,4950,0,-233,-13.0,5070,0,-233,-12.0,5190,0,-233,-11.0,5310,0,-233,-9.0,5430,0,-233,-1.1,5550,0,-113,22.7,-5610,0,-113,49.4,-5490,0,-113,67.7,-5370,0,-113,73.8,-5250,0,-113,77.2,-5130,0,-113,77.5,-5010,0,-113,83.8,-4890,0,-113,92.9,-4770,0,-113,100.7,-4650,0,-113,112.8,-4530,0,-113,126.8,-4410,0,-113,135.6,-4290,0,-113,87.8,-4170,0,-113,28.1,-4050,0,-113,7.4,1710,0,-113,21.1,1830,0,-113,37.5,1950,0,-113,41.5,2070,0,-113,41.5,2190,0,-113,36.7,2310,0,-113,30.4,2430,0,-113,30.2,2550,0,-113,30.2,2670,0,-113,26.1,2790,0,-113,20.0,2910,0,-113,16.1,3030,0,-113,18.3,3150,0,-113,20.9,3270,0,-113,13.5,3390,0,-113,10.3,3510,0,-113,8.1,3630,0,-113,4.1,3750,0,-113,1.8,3870,0,-113,-1.9,3990,0,-113,-5.4,4110,0,-113,-10.4,4230,0,-113,-13.5,4350,0,-113,-11.4,4470,0,-113,-10.5,4590,0,-113,-6.2,4710,0,-113,-4.0,4830,0,-113,-6.6,4950,0,-113,-8.1,5070,0,-113,-8.6,5190,0,-113,-13.7,5310,0,-113,-17.6,5430,0,-113,-9.4,5550,0,-113,4.6,5670,0,7,25.0,-5610,0,7,53.8,-5490,0,7,70.2,-5370,0,7,72.9,-5250,0,7,71.4,-5130,0,7,69.2,-5010,0,7,74.7,-4890,0,7,85.5,-4770,0,7,92.1,-4650,0,7,107.3,-4530,0,7,124.2,-4410,0,7,141.9,-4290,0,7,106.2,-4170,0,7,43.7,-4050,0,7,22.8,1830,0,7,39.8,1950,0,7,45.4,2070,0,7,45.2,2190,0,7,36.7,2310,0,7,30.3,2430,0,7,29.6,2550,0,7,28.6,2670,0,7,23.6,2790,0,7,20.7,2910,0,7,21.7,3030,0,7,20.9,3150,0,7,19.6,3270,0,7,13.9,3390,0,7,12.4,3510,0,7,9.5,3630,0,7,5.4,3750,0,7,-1.7,3870,0,7,-6.5,3990,0,7,-8.6,4110,0,7,-11.7,4230,0,7,-12.0,4350,0,7,-7.6,4470,0,7,-6.3,4590,0,7,-4.2,4710,0,7,-2.2,4830,0,7,-1.9,4950,0,7,-1.9,5070,0,7,-5.4,5190,0,7,-13.3,5310,0,7,-21.9,5430,0,7,-13.4,5550,0,7,0.6,5670,0,127,21.1,-5610,0,127,46.0,-5490,0,127,65.6,-5370,0,127,66.7,-5250,0,127,64.7,-5130,0,127,65.4,-5010,0,127,73.8,-4890,0,127,82.7,-4770,0,127,88.9,-4650,0,127,109.1,-4530,0,127,124.1,-4410,0,127,140.0,-4290,0,127,116.1,-4170,0,127,60.9,-4050,0,127,21.0,1830,0,127,40.2,1950,0,127,49.9,2070,0,127,50.1,2190,0,127,47.7,2310,0,127,34.7,2430,0,127,31.6,2550,0,127,27.2,2670,0,127,24.7,2790,0,127,25.1,2910,0,127,23.6,3030,0,127,22.9,3150,0,127,18.2,3270,0,127,15.4,3390,0,127,11.7,3510,0,127,7.0,3630,0,127,0.4,3750,0,127,-6.3,3870,0,127,-9.3,3990,0,127,-9.6,4110,0,127,-9.7,4230,0,127,-8.0,4350,0,127,-4.0,4470,0,127,-2.8,4590,0,127,-1.2,4710,0,127,0.7,4830,0,127,1.8,4950,0,127,0.9,5070,0,127,-4.2,5190,0,127,-14.0,5310,0,127,-21.2,5430,0,127,-13.9,5550,0,127,-0.8,5670,0,247,13.7,-5610,0,247,32.6,-5490,0,247,54.6,-5370,0,247,57.1,-5250,0,247,58.8,-5130,0,247,64.9,-5010,0,247,72.8,-4890,0,247,82.0,-4770,0,247,83.4,-4650,0,247,111.5,-4530,0,247,121.6,-4410,0,247,136.0,-4290,0,247,138.2,-4170,0,247,78.6,-4050,0,247,18.2,-3930,0,247,16.5,1830,0,247,36.2,1950,0,247,53.2,2070,0,247,51.9,2190,0,247,46.7,2310,0,247,40.3,2430,0,247,32.8,2550,0,247,27.6,2670,0,247,29.0,2790,0,247,25.1,2910,0,247,24.8,3030,0,247,26.1,3150,0,247,20.1,3270,0,247,16.8,3390,0,247,10.9,3510,0,247,2.3,3630,0,247,-3.9,3750,0,247,-6.6,3870,0,247,-6.3,3990,0,247,-5.1,4110,0,247,-4.4,4230,0,247,-1.8,4350,0,247,-1.0,4470,0,247,-0.8,4590,0,247,1.5,4710,0,247,3.4,4830,0,247,3.8,4950,0,247,0.8,5070,0,247,-6.3,5190,0,247,-15.3,5310,0,247,-19.8,5430,0,247,-12.3,5550,0,247,-0.8,5670,0,367,7.7,-5610,0,367,23.4,-5490,0,367,43.3,-5370,0,367,49.9,-5250,0,367,55.8,-5130,0,367,65.3,-5010,0,367,71.9,-4890,0,367,78.9,-4770,0,367,77.5,-4650,0,367,81.8,-4530,0,367,112.0,-4410,0,367,124.8,-4290,0,367,131.8,-4170,0,367,82.3,-4050,0,367,27.0,-3930,0,367,7.5,1830,0,367,26.1,1950,0,367,41.0,2070,0,367,48.2,2190,0,367,42.5,2310,0,367,37.6,2430,0,367,33.9,2550,0,367,33.4,2670,0,367,38.5,2790,0,367,31.1,2910,0,367,31.3,3030,0,367,31.3,3150,0,367,22.6,3270,0,367,16.3,3390,0,367,8.6,3510,0,367,1.4,3630,0,367,-2.2,3750,0,367,-0.9,3870,0,367,0.9,3990,0,367,0.7,4110,0,367,0.1,4230,0,367,0.6,4350,0,367,0.6,4470,0,367,1.7,4590,0,367,4.1,4710,0,367,4.1,4830,0,367,3.1,4950,0,367,-2.5,5070,0,367,-10.2,5190,0,367,-17.1,5310,0,367,-15.3,5430,0,367,-6.5,5550,0,367,1.5,5670,0,487,6.2,-5610,0,487,18.5,-5490,0,487,36.5,-5370,0,487,48.9,-5250,0,487,59.4,-5130,0,487,71.1,-5010,0,487,72.8,-4890,0,487,73.9,-4770,0,487,74.6,-4650,0,487,79.9,-4530,0,487,100.0,-4410,0,487,110.5,-4290,0,487,118.9,-4170,0,487,89.9,-4050,0,487,45.0,-3930,0,487,12.2,1950,0,487,25.4,2070,0,487,34.4,2190,0,487,42.1,2310,0,487,41.9,2430,0,487,38.7,2550,0,487,41.4,2670,0,487,44.3,2790,0,487,43.2,2910,0,487,38.3,3030,0,487,30.7,3150,0,487,22.4,3270,0,487,14.0,3390,0,487,5.7,3510,0,487,0.6,3630,0,487,2.0,3750,0,487,7.2,3870,0,487,7.3,3990,0,487,6.5,4110,0,487,5.2,4230,0,487,2.9,4350,0,487,2.1,4470,0,487,2.8,4590,0,487,4.3,4710,0,487,3.0,4830,0,487,-1.6,4950,0,487,-8.1,5070,0,487,-14.1,5190,0,487,-15.0,5310,0,487,-9.2,5430,0,487,-1.5,5550,0,487,3.8,5670,0,607,15.0,-5490,0,607,32.7,-5370,0,607,52.1,-5250,0,607,61.7,-5130,0,607,67.3,-5010,0,607,63.2,-4890,0,607,66.3,-4770,0,607,68.9,-4650,0,607,69.8,-4530,0,607,74.0,-4410,0,607,93.8,-4290,0,607,101.6,-4170,0,607,92.5,-4050,0,607,51.8,-3930,0,607,10.6,-3810,0,607,10.1,2070,0,607,20.8,2190,0,607,29.6,2310,0,607,34.6,2430,0,607,40.0,2550,0,607,49.8,2670,0,607,47.2,2790,0,607,43.7,2910,0,607,38.5,3030,0,607,32.0,3150,0,607,22.5,3270,0,607,12.5,3390,0,607,7.0,3510,0,607,5.9,3630,0,607,8.7,3750,0,607,10.1,3870,0,607,10.5,3990,0,607,9.2,4110,0,607,5.8,4230,0,607,2.9,4350,0,607,2.0,4470,0,607,2.4,4590,0,607,1.0,4710,0,607,-1.7,4830,0,607,-7.1,4950,0,607,-12.9,5070,0,607,-11.1,5190,0,607,-6.0,5310,0,607,-3.5,5430,0,607,2.2,5550,0,607,5.2,5670,0,727,11.8,-5490,0,727,32.4,-5370,0,727,54.1,-5250,0,727,57.3,-5130,0,727,57.5,-5010,0,727,52.5,-4890,0,727,51.7,-4770,0,727,59.5,-4650,0,727,65.3,-4530,0,727,69.7,-4410,0,727,78.2,-4290,0,727,87.0,-4170,0,727,89.1,-4050,0,727,59.0,-3930,0,727,27.0,-3810,0,727,11.5,2310,0,727,17.1,2430,0,727,27.3,2550,0,727,36.7,2670,0,727,40.1,2790,0,727,38.1,2910,0,727,33.2,3030,0,727,25.9,3150,0,727,19.6,3270,0,727,14.0,3390,0,727,11.5,3510,0,727,11.6,3630,0,727,11.2,3750,0,727,13.3,3870,0,727,13.8,3990,0,727,9.2,4110,0,727,3.2,4230,0,727,-0.7,4350,0,727,-2.8,4470,0,727,-2.1,4590,0,727,-2.8,4710,0,727,-4.2,4830,0,727,-6.3,4950,0,727,-7.5,5070,0,727,-3.5,5190,0,727,0.6,5310,0,727,0.2,5430,0,727,3.8,5550,0,727,5.5,5670,0,847,8.2,-5490,0,847,23.9,-5370,0,847,42.4,-5250,0,847,43.7,-5130,0,847,45.8,-5010,0,847,45.2,-4890,0,847,43.7,-4770,0,847,49.1,-4650,0,847,54.4,-4530,0,847,57.8,-4410,0,847,66.4,-4290,0,847,75.4,-4170,0,847,79.5,-4050,0,847,71.1,-3930,0,847,40.4,-3810,0,847,9.9,2550,0,847,17.9,2670,0,847,22.0,2790,0,847,22.1,2910,0,847,20.2,3030,0,847,16.1,3150,0,847,14.4,3270,0,847,13.0,3390,0,847,12.9,3510,0,847,16.6,3630,0,847,17.3,3750,0,847,16.0,3870,0,847,12.0,3990,0,847,10.1,4110,0,847,5.8,4230,0,847,1.3,4350,0,847,-2.2,4470,0,847,-4.5,4590,0,847,-6.0,4710,0,847,-5.0,4830,0,847,-2.2,4950,0,847,-0.9,5070,0,847,0.9,5190,0,847,2.5,5310,0,847,1.7,5430,0,847,3.4,5550,0,847,5.2,5670,0,967,15.1,-5370,0,967,26.8,-5250,0,967,32.0,-5130,0,967,33.5,-5010,0,967,35.5,-4890,0,967,36.5,-4770,0,967,40.8,-4650,0,967,48.6,-4530,0,967,56.9,-4410,0,967,63.6,-4290,0,967,68.0,-4170,0,967,76.1,-4050,0,967,74.9,-3930,0,967,44.1,-3810,0,967,12.3,-3690,0,967,7.2,2910,0,967,6.8,3030,0,967,8.1,3270,0,967,16.0,3390,0,967,21.4,3510,0,967,22.3,3630,0,967,18.8,3750,0,967,15.8,3870,0,967,15.3,3990,0,967,14.9,4110,0,967,10.7,4230,0,967,5.5,4350,0,967,1.8,4470,0,967,-1.4,4590,0,967,-1.8,4710,0,967,1.7,4830,0,967,5.4,4950,0,967,7.6,5070,0,967,5.7,5190,0,967,2.4,5310,0,967,1.9,5430,0,967,3.4,5550,0,967,6.0,5670,0,1087,9.9,-5370,0,1087,18.1,-5250,0,1087,25.8,-5130,0,1087,25.9,-5010,0,1087,29.0,-4890,0,1087,32.9,-4770,0,1087,40.4,-4650,0,1087,48.2,-4530,0,1087,57.0,-4410,0,1087,62.3,-4290,0,1087,71.2,-4170,0,1087,77.9,-4050,0,1087,82.1,-3930,0,1087,57.5,-3810,0,1087,28.0,-3690,0,1087,14.4,3270,0,1087,23.5,3390,0,1087,27.7,3510,0,1087,23.9,3630,0,1087,21.7,3750,0,1087,20.2,3870,0,1087,20.8,3990,0,1087,20.2,4110,0,1087,14.5,4230,0,1087,11.5,4350,0,1087,5.4,4470,0,1087,2.9,4590,0,1087,3.2,4710,0,1087,4.1,4830,0,1087,9.0,4950,0,1087,10.8,5070,0,1087,7.8,5190,0,1087,3.1,5310,0,1087,2.9,5430,0,1087,5.0,5550,0,1207,6.6,-5370,0,1207,12.2,-5250,0,1207,21.3,-5130,0,1207,24.0,-5010,0,1207,25.9,-4890,0,1207,32.1,-4770,0,1207,40.5,-4650,0,1207,49.2,-4530,0,1207,57.8,-4410,0,1207,60.8,-4290,0,1207,72.9,-4170,0,1207,77.3,-4050,0,1207,80.5,-3930,0,1207,68.0,-3810,0,1207,37.8,-3690,0,1207,20.2,3270,0,1207,29.9,3390,0,1207,29.1,3510,0,1207,27.1,3630,0,1207,28.0,3750,0,1207,26.4,3870,0,1207,25.7,3990,0,1207,19.5,4110,0,1207,15.4,4230,0,1207,11.1,4350,0,1207,7.5,4470,0,1207,7.1,4590,0,1207,7.4,4710,0,1207,9.0,4830,0,1207,9.5,4950,0,1207,8.6,5070,0,1207,6.0,5190,0,1207,4.0,5310,0,1207,4.7,5430,0,1207,5.8,5550,0,1327,9.8,-5250,0,1327,17.0,-5130,0,1327,26.8,-5010,0,1327,31.3,-4890,0,1327,37.8,-4770,0,1327,49.8,-4650,0,1327,56.1,-4530,0,1327,56.8,-4410,0,1327,56.8,-4290,0,1327,62.5,-4170,0,1327,72.5,-4050,0,1327,77.6,-3930,0,1327,75.8,-3810,0,1327,44.3,-3690,0,1327,15.1,-3570,0,1327,6.7,1710,0,1327,13.3,1830,0,1327,15.7,1950,0,1327,14.2,2070,0,1327,8.4,2190,0,1327,10.4,3150,0,1327,24.4,3270,0,1327,34.1,3390,0,1327,34.0,3510,0,1327,33.1,3630,0,1327,32.0,3750,0,1327,27.0,3870,0,1327,23.4,3990,0,1327,19.8,4110,0,1327,18.3,4230,0,1327,14.3,4350,0,1327,10.4,4470,0,1327,12.8,4590,0,1327,12.7,4710,0,1327,9.3,4830,0,1327,7.5,4950,0,1327,7.5,5070,0,1327,6.6,5190,0,1327,5.8,5310,0,1327,5.9,5430,0,1447,7.0,-5250,0,1447,14.9,-5130,0,1447,31.6,-5010,0,1447,36.4,-4890,0,1447,46.6,-4770,0,1447,59.4,-4650,0,1447,59.8,-4530,0,1447,56.4,-4410,0,1447,56.7,-4290,0,1447,62.4,-4170,0,1447,70.0,-4050,0,1447,75.6,-3930,0,1447,79.2,-3810,0,1447,57.6,-3690,0,1447,27.7,-3570,0,1447,6.6,-210,0,1447,14.8,-90,0,1447,26.1,30,0,1447,30.4,150,0,1447,28.8,270,0,1447,22.0,390,0,1447,9.1,510,0,1447,9.4,1470,0,1447,22.9,1590,0,1447,34.3,1710,0,1447,42.8,1830,0,1447,46.4,1950,0,1447,44.0,2070,0,1447,34.7,2190,0,1447,23.2,2310,0,1447,9.9,2430,0,1447,18.0,3150,0,1447,32.0,3270,0,1447,37.6,3390,0,1447,38.5,3510,0,1447,38.5,3630,0,1447,34.6,3750,0,1447,28.4,3870,0,1447,27.1,3990,0,1447,23.2,4110,0,1447,23.4,4230,0,1447,21.6,4350,0,1447,18.1,4470,0,1447,17.6,4590,0,1447,13.7,4710,0,1447,9.6,4830,0,1447,10.1,4950,0,1447,12.8,5070,0,1447,9.7,5190,0,1447,6.7,5310,0,1447,6.0,5430,0,1567,6.1,-5250,0,1567,9.9,-5130,0,1567,4.3,-5010,0,1567,36.7,-4890,0,1567,48.8,-4770,0,1567,59.1,-4650,0,1567,57.2,-4530,0,1567,55.1,-4410,0,1567,53.8,-4290,0,1567,55.8,-4170,0,1567,75.2,-4050,0,1567,74.8,-3930,0,1567,75.2,-3810,0,1567,62.9,-3690,0,1567,33.7,-3570,0,1567,10.0,-570,0,1567,28.9,-450,0,1567,43.1,-330,0,1567,49.1,-210,0,1567,54.0,-90,0,1567,65.9,30,0,1567,71.1,150,0,1567,69.5,270,0,1567,60.9,390,0,1567,45.6,510,0,1567,25.5,630,0,1567,11.7,1110,0,1567,27.0,1230,0,1567,36.4,1350,0,1567,40.2,1470,0,1567,49.5,1590,0,1567,63.9,1710,0,1567,75.8,1830,0,1567,77.8,1950,0,1567,75.2,2070,0,1567,63.1,2190,0,1567,48.8,2310,0,1567,33.5,2430,0,1567,27.1,2550,0,1567,17.2,2670,0,1567,24.2,3150,0,1567,40.9,3270,0,1567,43.3,3390,0,1567,45.1,3510,0,1567,43.6,3630,0,1567,37.7,3750,0,1567,32.7,3870,0,1567,31.3,3990,0,1567,31.2,4110,0,1567,29.3,4230,0,1567,26.7,4350,0,1567,22.6,4470,0,1567,20.2,4590,0,1567,15.4,4710,0,1567,12.7,4830,0,1567,15.3,4950,0,1567,14.1,5070,0,1567,10.2,5190,0,1567,6.7,5310,0,1687,7.8,-5130,0,1687,17.0,-5010,0,1687,30.6,-4890,0,1687,44.1,-4770,0,1687,53.8,-4650,0,1687,59.9,-4530,0,1687,54.5,-4410,0,1687,50.4,-4290,0,1687,51.8,-4170,0,1687,58.5,-4050,0,1687,73.9,-3930,0,1687,72.2,-3810,0,1687,62.6,-3690,0,1687,38.5,-3570,0,1687,14.1,-3450,0,1687,18.2,-690,0,1687,45.9,-570,0,1687,70.1,-450,0,1687,89.5,-330,0,1687,94.9,-210,0,1687,93.4,-90,0,1687,98.1,30,0,1687,97.4,150,0,1687,99.2,270,0,1687,98.1,390,0,1687,83.2,510,0,1687,60.0,630,0,1687,33.6,750,0,1687,12.1,870,0,1687,19.6,990,0,1687,43.4,1110,0,1687,59.3,1230,0,1687,68.2,1350,0,1687,72.5,1470,0,1687,76.3,1590,0,1687,77.0,1710,0,1687,79.6,1830,0,1687,78.7,1950,0,1687,74.8,2070,0,1687,73.4,2190,0,1687,75.3,2310,0,1687,67.2,2430,0,1687,58.5,2550,0,1687,44.0,2670,0,1687,27.2,2790,0,1687,9.2,2910,0,1687,29.3,3150,0,1687,48.2,3270,0,1687,50.4,3390,0,1687,49.9,3510,0,1687,43.4,3630,0,1687,36.3,3750,0,1687,34.9,3870,0,1687,36.4,3990,0,1687,35.8,4110,0,1687,33.5,4230,0,1687,30.0,4350,0,1687,24.8,4470,0,1687,22.8,4590,0,1687,19.5,4710,0,1687,16.3,4830,0,1687,15.2,4950,0,1687,10.1,5070,0,1687,6.4,5190,0,1807,6.8,-5130,0,1807,11.4,-5010,0,1807,20.7,-4890,0,1807,35.9,-4770,0,1807,49.2,-4650,0,1807,64.1,-4530,0,1807,49.2,-4410,0,1807,47.5,-4290,0,1807,47.9,-4170,0,1807,49.4,-4050,0,1807,66.9,-3930,0,1807,65.6,-3810,0,1807,63.6,-3690,0,1807,46.1,-3570,0,1807,23.6,-3450,0,1807,13.9,-810,0,1807,48.4,-690,0,1807,81.0,-570,0,1807,107.4,-450,0,1807,110.4,-330,0,1807,108.8,-210,0,1807,104.5,-90,0,1807,101.2,30,0,1807,102.6,150,0,1807,103.8,270,0,1807,103.0,390,0,1807,102.7,510,0,1807,94.2,630,0,1807,69.4,750,0,1807,44.1,870,0,1807,47.0,990,0,1807,71.8,1110,0,1807,85.9,1230,0,1807,82.1,1350,0,1807,80.5,1470,0,1807,79.0,1590,0,1807,80.9,1710,0,1807,81.2,1830,0,1807,77.3,1950,0,1807,75.1,2070,0,1807,77.8,2190,0,1807,82.4,2310,0,1807,81.3,2430,0,1807,78.2,2550,0,1807,72.4,2670,0,1807,50.9,2790,0,1807,29.1,2910,0,1807,6.6,3030,0,1807,28.7,3150,0,1807,51.1,3270,0,1807,57.4,3390,0,1807,55.8,3510,0,1807,52.1,3630,0,1807,40.4,3750,0,1807,38.5,3870,0,1807,40.6,3990,0,1807,39.0,4110,0,1807,34.6,4230,0,1807,30.1,4350,0,1807,25.5,4470,0,1807,17.9,4590,0,1807,14.4,4710,0,1807,13.2,4830,0,1807,9.6,4950,0,1927,6.4,-5010,0,1927,13.1,-4890,0,1927,30.3,-4770,0,1927,43.3,-4650,0,1927,54.8,-4530,0,1927,46.8,-4410,0,1927,43.9,-4290,0,1927,41.8,-4170,0,1927,43.3,-4050,0,1927,53.5,-3930,0,1927,53.1,-3810,0,1927,55.0,-3690,0,1927,47.5,-3570,0,1927,28.0,-3450,0,1927,11.5,-3330,0,1927,25.0,-930,0,1927,50.1,-810,0,1927,75.6,-690,0,1927,107.0,-570,0,1927,107.9,-450,0,1927,110.8,-330,0,1927,110.2,-210,0,1927,108.6,-90,0,1927,108.2,30,0,1927,110.3,150,0,1927,108.7,270,0,1927,107.0,390,0,1927,105.8,510,0,1927,101.6,630,0,1927,99.4,750,0,1927,75.1,870,0,1927,71.9,990,0,1927,90.9,1110,0,1927,88.1,1230,0,1927,84.5,1350,0,1927,82.6,1470,0,1927,81.0,1590,0,1927,81.8,1710,0,1927,79.5,1830,0,1927,77.6,1950,0,1927,79.4,2070,0,1927,84.1,2190,0,1927,85.4,2310,0,1927,82.9,2430,0,1927,79.7,2550,0,1927,77.5,2670,0,1927,73.2,2790,0,1927,46.5,2910,0,1927,21.3,3030,0,1927,33.3,3150,0,1927,58.6,3270,0,1927,63.6,3390,0,1927,59.3,3510,0,1927,54.6,3630,0,1927,47.3,3750,0,1927,44.0,3870,0,1927,42.6,3990,0,1927,41.4,4110,0,1927,35.0,4230,0,1927,29.8,4350,0,1927,24.2,4470,0,1927,14.3,4590,0,1927,9.0,4710,0,1927,6.5,4830,0,2047,5.0,-5010,0,2047,8.9,-4890,0,2047,32.8,-4770,0,2047,38.7,-4650,0,2047,54.9,-4530,0,2047,51.4,-4410,0,2047,42.7,-4290,0,2047,38.2,-4170,0,2047,39.6,-4050,0,2047,38.2,-3930,0,2047,37.7,-3810,0,2047,40.7,-3690,0,2047,46.5,-3570,0,2047,41.2,-3450,0,2047,30.7,-3330,0,2047,14.5,-3210,0,2047,24.1,-1050,0,2047,58.9,-930,0,2047,89.7,-810,0,2047,107.1,-690,0,2047,109.3,-570,0,2047,111.6,-450,0,2047,112.8,-330,0,2047,109.2,-210,0,2047,109.7,-90,0,2047,111.9,30,0,2047,109.4,150,0,2047,110.7,270,0,2047,110.6,390,0,2047,108.4,510,0,2047,103.3,630,0,2047,100.0,750,0,2047,100.1,870,0,2047,92.9,990,0,2047,92.4,1110,0,2047,87.3,1230,0,2047,85.1,1350,0,2047,85.2,1470,0,2047,83.2,1590,0,2047,82.5,1710,0,2047,81.1,1830,0,2047,79.3,1950,0,2047,83.4,2070,0,2047,86.7,2190,0,2047,86.2,2310,0,2047,84.4,2430,0,2047,81.9,2550,0,2047,79.4,2670,0,2047,75.0,2790,0,2047,60.3,2910,0,2047,34.0,3030,0,2047,45.6,3150,0,2047,70.7,3270,0,2047,68.7,3390,0,2047,64.2,3510,0,2047,53.9,3630,0,2047,48.0,3750,0,2047,46.7,3870,0,2047,48.4,3990,0,2047,43.4,4110,0,2047,36.4,4230,0,2047,30.6,4350,0,2047,22.1,4470,0,2047,13.1,4590,0,2047,6.7,4710,0,2167,7.4,-5010,0,2167,13.9,-4890,0,2167,34.2,-4770,0,2167,39.9,-4650,0,2167,47.1,-4530,0,2167,44.6,-4410,0,2167,38.4,-4290,0,2167,30.8,-4170,0,2167,30.5,-4050,0,2167,24.6,-3930,0,2167,21.9,-3810,0,2167,28.1,-3690,0,2167,39.9,-3570,0,2167,52.1,-3450,0,2167,48.0,-3330,0,2167,31.7,-3210,0,2167,11.0,-3090,0,2167,9.8,-1170,0,2167,48.5,-1050,0,2167,88.1,-930,0,2167,110.4,-810,0,2167,110.6,-690,0,2167,115.3,-570,0,2167,116.4,-450,0,2167,107.5,-330,0,2167,102.8,-210,0,2167,103.5,-90,0,2167,106.1,30,0,2167,106.5,150,0,2167,107.7,270,0,2167,110.9,390,0,2167,111.4,510,0,2167,106.4,630,0,2167,102.8,750,0,2167,101.1,870,0,2167,97.7,990,0,2167,94.2,1110,0,2167,90.3,1230,0,2167,90.1,1350,0,2167,88.0,1470,0,2167,85.1,1590,0,2167,82.7,1710,0,2167,82.5,1830,0,2167,83.2,1950,0,2167,83.5,2070,0,2167,84.3,2190,0,2167,84.5,2310,0,2167,84.6,2430,0,2167,82.6,2550,0,2167,80.2,2670,0,2167,75.8,2790,0,2167,74.5,2910,0,2167,45.1,3030,0,2167,59.9,3150,0,2167,77.1,3270,0,2167,74.1,3390,0,2167,70.0,3510,0,2167,60.0,3630,0,2167,52.6,3750,0,2167,49.8,3870,0,2167,49.6,3990,0,2167,42.9,4110,0,2167,36.2,4230,0,2167,29.9,4350,0,2167,21.9,4470,0,2167,13.8,4590,0,2287,9.0,-4890,0,2287,22.8,-4770,0,2287,39.3,-4650,0,2287,37.6,-4530,0,2287,34.6,-4410,0,2287,32.2,-4290,0,2287,25.8,-4170,0,2287,17.9,-4050,0,2287,13.9,-3930,0,2287,12.4,-3810,0,2287,19.1,-3690,0,2287,35.9,-3570,0,2287,48.4,-3450,0,2287,56.3,-3330,0,2287,43.8,-3210,0,2287,23.5,-3090,0,2287,26.4,-1170,0,2287,68.3,-1050,0,2287,107.9,-930,0,2287,108.9,-810,0,2287,111.0,-690,0,2287,116.5,-570,0,2287,102.1,-450,0,2287,103.3,-330,0,2287,101.3,-210,0,2287,103.5,-90,0,2287,104.8,30,0,2287,106.1,150,0,2287,109.0,270,0,2287,109.6,390,0,2287,110.9,510,0,2287,110.1,630,0,2287,105.0,750,0,2287,101.1,870,0,2287,96.8,990,0,2287,95.0,1110,0,2287,94.1,1230,0,2287,92.0,1350,0,2287,88.0,1470,0,2287,85.7,1590,0,2287,84.2,1710,0,2287,82.5,1830,0,2287,82.7,1950,0,2287,83.9,2070,0,2287,84.1,2190,0,2287,84.5,2310,0,2287,84.4,2430,0,2287,84.2,2550,0,2287,81.2,2670,0,2287,78.4,2790,0,2287,81.5,2910,0,2287,52.7,3030,0,2287,73.7,3150,0,2287,78.3,3270,0,2287,73.9,3390,0,2287,63.1,3510,0,2287,55.5,3630,0,2287,54.1,3750,0,2287,52.9,3870,0,2287,48.7,3990,0,2287,41.3,4110,0,2287,36.4,4230,0,2287,31.2,4350,0,2287,25.2,4470,0,2287,15.6,4590,0,2407,5.8,-4890,0,2407,13.5,-4770,0,2407,25.3,-4650,0,2407,26.6,-4530,0,2407,23.3,-4410,0,2407,17.7,-4290,0,2407,12.3,-4170,0,2407,14.1,-4050,0,2407,12.2,-3930,0,2407,9.4,-3810,0,2407,14.8,-3690,0,2407,27.8,-3570,0,2407,37.3,-3450,0,2407,45.2,-3330,0,2407,47.3,-3210,0,2407,34.0,-3090,0,2407,17.0,-2970,0,2407,9.7,-2850,0,2407,24.0,-1290,0,2407,57.7,-1170,0,2407,89.2,-1050,0,2407,108.1,-930,0,2407,110.3,-810,0,2407,111.9,-690,0,2407,97.6,-570,0,2407,94.8,-450,0,2407,96.7,-330,0,2407,99.2,-210,0,2407,102.2,-90,0,2407,108.0,30,0,2407,111.1,150,0,2407,113.8,270,0,2407,112.5,390,0,2407,111.6,510,0,2407,110.5,630,0,2407,106.3,750,0,2407,102.4,870,0,2407,98.4,990,0,2407,96.4,1110,0,2407,97.7,1230,0,2407,94.6,1350,0,2407,90.6,1470,0,2407,91.1,1590,0,2407,87.0,1710,0,2407,83.4,1830,0,2407,84.8,1950,0,2407,87.5,2070,0,2407,88.4,2190,0,2407,83.9,2310,0,2407,84.1,2430,0,2407,84.3,2550,0,2407,82.4,2670,0,2407,81.3,2790,0,2407,84.5,2910,0,2407,61.9,3030,0,2407,82.4,3150,0,2407,77.1,3270,0,2407,73.0,3390,0,2407,69.1,3510,0,2407,57.6,3630,0,2407,55.8,3750,0,2407,52.3,3870,0,2407,46.0,3990,0,2407,39.0,4110,0,2407,35.6,4230,0,2407,33.4,4350,0,2407,26.3,4470,0,2407,14.2,4590,0,2527,8.0,-4770,0,2527,13.8,-4650,0,2527,20.3,-4530,0,2527,5.5,-4410,0,2527,11.2,-4290,0,2527,8.9,-4170,0,2527,7.3,-4050,0,2527,7.3,-3930,0,2527,9.6,-3810,0,2527,10.7,-3690,0,2527,16.9,-3570,0,2527,23.2,-3450,0,2527,30.4,-3330,0,2527,40.3,-3210,0,2527,41.6,-3090,0,2527,33.3,-2970,0,2527,26.0,-2850,0,2527,17.1,-2730,0,2527,8.6,-2610,0,2527,10.1,-1410,0,2527,48.6,-1290,0,2527,89.0,-1170,0,2527,110.7,-1050,0,2527,110.2,-930,0,2527,110.7,-810,0,2527,101.0,-690,0,2527,93.5,-570,0,2527,92.0,-450,0,2527,96.7,-330,0,2527,98.3,-210,0,2527,102.4,-90,0,2527,112.7,30,0,2527,113.1,150,0,2527,112.9,270,0,2527,111.8,390,0,2527,111.8,510,0,2527,110.6,630,0,2527,108.8,750,0,2527,105.7,870,0,2527,100.7,990,0,2527,97.6,1110,0,2527,99.0,1230,0,2527,97.0,1350,0,2527,93.3,1470,0,2527,91.4,1590,0,2527,87.2,1710,0,2527,85.8,1830,0,2527,88.2,1950,0,2527,89.5,2070,0,2527,88.0,2190,0,2527,83.6,2310,0,2527,83.2,2430,0,2527,84.8,2550,0,2527,85.1,2670,0,2527,85.8,2790,0,2527,85.5,2910,0,2527,81.3,3030,0,2527,81.7,3150,0,2527,77.7,3270,0,2527,72.3,3390,0,2527,63.4,3510,0,2527,60.1,3630,0,2527,57.2,3750,0,2527,52.0,3870,0,2527,45.4,3990,0,2527,39.7,4110,0,2527,37.1,4230,0,2527,33.6,4350,0,2527,21.6,4470,0,2527,9.7,4590,0,2647,6.2,-4770,0,2647,6.8,-4650,0,2647,8.2,-4530,0,2647,7.9,-4410,0,2647,6.1,-4290,0,2647,3.0,-4170,1,2647,3.0,-4050,1,2647,3.0,-3930,1,2647,5.7,-3810,0,2647,9.7,-3690,0,2647,8.4,-3570,0,2647,15.6,-3450,0,2647,18.4,-3330,0,2647,29.9,-3210,0,2647,38.5,-3090,0,2647,40.3,-2970,0,2647,35.8,-2850,0,2647,27.3,-2730,0,2647,19.9,-2610,0,2647,14.8,-2490,0,2647,15.7,-2370,0,2647,14.2,-2250,0,2647,8.9,-2130,0,2647,6.7,-1890,0,2647,11.9,-1770,0,2647,14.4,-1650,0,2647,19.7,-1530,0,2647,43.3,-1410,0,2647,69.2,-1290,0,2647,110.7,-1170,0,2647,112.0,-1050,0,2647,107.5,-930,0,2647,105.3,-810,0,2647,88.9,-690,0,2647,89.6,-570,0,2647,89.2,-450,0,2647,93.2,-330,0,2647,103.5,-210,0,2647,106.9,-90,0,2647,111.1,30,0,2647,111.7,150,0,2647,111.6,270,0,2647,111.8,390,0,2647,111.5,510,0,2647,110.1,630,0,2647,109.8,750,0,2647,108.0,870,0,2647,106.0,990,0,2647,105.3,1110,0,2647,98.9,1230,0,2647,97.5,1350,0,2647,95.4,1470,0,2647,92.8,1590,0,2647,88.2,1710,0,2647,87.9,1830,0,2647,89.9,1950,0,2647,90.4,2070,0,2647,88.1,2190,0,2647,85.3,2310,0,2647,82.8,2430,0,2647,82.9,2550,0,2647,89.1,2670,0,2647,91.4,2790,0,2647,87.5,2910,0,2647,82.8,3030,0,2647,81.8,3150,0,2647,78.4,3270,0,2647,68.7,3390,0,2647,61.8,3510,0,2647,60.5,3630,0,2647,58.5,3750,0,2647,52.6,3870,0,2647,46.3,3990,0,2647,42.1,4110,0,2647,38.2,4230,0,2647,30.9,4350,0,2647,16.2,4470,0,2767,6.0,-4650,0,2767,5.4,-4530,0,2767,3.0,-4410,1,2767,3.0,-4290,1,2767,3.0,-4170,1,2767,3.0,-4050,1,2767,3.0,-3930,1,2767,3.0,-3810,1,2767,7.1,-3690,0,2767,11.4,-3570,0,2767,15.2,-3450,0,2767,14.6,-3330,0,2767,20.5,-3210,0,2767,27.4,-3090,0,2767,28.8,-2970,0,2767,28.9,-2850,0,2767,31.7,-2730,0,2767,28.6,-2610,0,2767,32.8,-2490,0,2767,36.0,-2370,0,2767,36.8,-2250,0,2767,32.6,-2130,0,2767,24.5,-2010,0,2767,34.1,-1890,0,2767,41.4,-1770,0,2767,48.1,-1650,0,2767,50.8,-1530,0,2767,77.2,-1410,0,2767,100.9,-1290,0,2767,102.8,-1170,0,2767,104.0,-1050,0,2767,101.6,-930,0,2767,84.7,-810,0,2767,82.0,-690,0,2767,84.1,-570,0,2767,87.0,-450,0,2767,91.9,-330,0,2767,101.6,-210,0,2767,104.6,-90,0,2767,109.4,30,0,2767,111.9,150,0,2767,112.0,270,0,2767,113.1,390,0,2767,111.7,510,0,2767,110.2,630,0,2767,109.6,750,0,2767,109.4,870,0,2767,109.2,990,0,2767,106.7,1110,0,2767,100.3,1230,0,2767,100.3,1350,0,2767,100.0,1470,0,2767,95.6,1590,0,2767,91.0,1710,0,2767,91.3,1830,0,2767,91.6,1950,0,2767,91.8,2070,0,2767,88.2,2190,0,2767,84.3,2310,0,2767,82.2,2430,0,2767,82.8,2550,0,2767,89.7,2670,0,2767,95.4,2790,0,2767,92.9,2910,0,2767,85.8,3030,0,2767,82.4,3150,0,2767,77.2,3270,0,2767,72.7,3390,0,2767,65.0,3510,0,2767,63.3,3630,0,2767,58.5,3750,0,2767,52.3,3870,0,2767,46.7,3990,0,2767,43.4,4110,0,2767,40.9,4230,0,2767,28.9,4350,0,2767,13.9,4470,0,2887,3.0,-4530,1,2887,3.0,-4410,1,2887,3.0,-4290,1,2887,3.0,-4170,1,2887,3.0,-4050,1,2887,3.0,-3930,1,2887,3.0,-3810,1,2887,5.5,-3690,0,2887,8.8,-3570,0,2887,13.8,-3450,0,2887,11.8,-3330,0,2887,14.4,-3210,0,2887,19.3,-3090,0,2887,24.2,-2970,0,2887,30.4,-2850,0,2887,34.8,-2730,0,2887,40.2,-2610,0,2887,46.8,-2490,0,2887,50.2,-2370,0,2887,55.1,-2250,0,2887,53.2,-2130,0,2887,47.2,-2010,0,2887,56.7,-1890,0,2887,65.6,-1770,0,2887,75.5,-1650,0,2887,79.1,-1530,0,2887,87.3,-1410,0,2887,91.5,-1290,0,2887,90.9,-1170,0,2887,95.3,-1050,0,2887,86.4,-930,0,2887,79.8,-810,0,2887,79.1,-690,0,2887,84.8,-570,0,2887,89.4,-450,0,2887,92.4,-330,0,2887,96.5,-210,0,2887,101.3,-90,0,2887,108.1,30,0,2887,112.2,150,0,2887,114.4,270,0,2887,112.6,390,0,2887,112.1,510,0,2887,110.9,630,0,2887,109.1,750,0,2887,109.8,870,0,2887,112.1,990,0,2887,112.7,1110,0,2887,105.8,1230,0,2887,102.1,1350,0,2887,101.7,1470,0,2887,99.5,1590,0,2887,96.2,1710,0,2887,95.2,1830,0,2887,94.1,1950,0,2887,92.9,2070,0,2887,87.8,2190,0,2887,82.7,2310,0,2887,81.5,2430,0,2887,82.2,2550,0,2887,90.9,2670,0,2887,96.5,2790,0,2887,94.5,2910,0,2887,87.3,3030,0,2887,81.7,3150,0,2887,74.0,3270,0,2887,69.8,3390,0,2887,67.6,3510,0,2887,65.4,3630,0,2887,57.1,3750,0,2887,49.6,3870,0,2887,46.5,3990,0,2887,44.1,4110,0,2887,38.0,4230,0,2887,23.5,4350,0,2887,9.4,4470,0,3007,3.0,-4410,1,3007,3.0,-4290,1,3007,3.0,-4170,1,3007,3.0,-4050,1,3007,3.0,-3930,1,3007,3.0,-3810,1,3007,3.0,-3690,1,3007,7.2,-3570,0,3007,5.8,-3450,0,3007,13.5,-3330,0,3007,17.6,-3210,0,3007,22.3,-3090,0,3007,28.9,-2970,0,3007,36.1,-2850,0,3007,40.3,-2730,0,3007,42.9,-2610,0,3007,45.2,-2490,0,3007,46.1,-2370,0,3007,47.8,-2250,0,3007,50.2,-2130,0,3007,52.7,-2010,0,3007,55.5,-1890,0,3007,60.5,-1770,0,3007,64.1,-1650,0,3007,69.7,-1530,0,3007,78.3,-1410,0,3007,84.3,-1290,0,3007,85.4,-1170,0,3007,76.6,-1050,0,3007,77.4,-930,0,3007,76.2,-810,0,3007,76.9,-690,0,3007,83.4,-570,0,3007,83.9,-450,0,3007,85.1,-330,0,3007,94.7,-210,0,3007,100.4,-90,0,3007,104.6,30,0,3007,109.3,150,0,3007,113.5,270,0,3007,112.9,390,0,3007,113.1,510,0,3007,113.1,630,0,3007,111.0,750,0,3007,111.8,870,0,3007,114.1,990,0,3007,111.7,1110,0,3007,106.1,1230,0,3007,104.2,1350,0,3007,104.0,1470,0,3007,102.0,1590,0,3007,99.8,1710,0,3007,98.6,1830,0,3007,96.0,1950,0,3007,92.6,2070,0,3007,88.0,2190,0,3007,83.0,2310,0,3007,81.4,2430,0,3007,83.8,2550,0,3007,90.1,2670,0,3007,90.1,2790,0,3007,89.9,2910,0,3007,82.2,3030,0,3007,80.5,3150,0,3007,75.3,3270,0,3007,72.1,3390,0,3007,67.9,3510,0,3007,61.3,3630,0,3007,54.0,3750,0,3007,48.9,3870,0,3007,47.2,3990,0,3007,45.4,4110,0,3007,31.4,4230,0,3007,15.2,4350,0,3127,3.0,-4290,1,3127,3.0,-4170,1,3127,3.0,-4050,1,3127,3.0,-3930,1,3127,3.0,-3810,1,3127,3.0,-3690,1,3127,6.3,-3570,0,3127,5.2,-3450,0,3127,16.6,-3330,0,3127,20.8,-3210,0,3127,22.6,-3090,0,3127,25.4,-2970,0,3127,31.3,-2850,0,3127,38.3,-2730,0,3127,38.4,-2610,0,3127,41.0,-2490,0,3127,41.3,-2370,0,3127,43.2,-2250,0,3127,45.0,-2130,0,3127,46.2,-2010,0,3127,48.4,-1890,0,3127,52.6,-1770,0,3127,53.2,-1650,0,3127,58.1,-1530,0,3127,70.0,-1410,0,3127,76.7,-1290,0,3127,70.1,-1170,0,3127,67.9,-1050,0,3127,68.3,-930,0,3127,72.6,-810,0,3127,75.5,-690,0,3127,76.5,-570,0,3127,74.2,-450,0,3127,79.3,-330,0,3127,88.7,-210,0,3127,87.9,-90,0,3127,100.7,30,0,3127,106.7,150,0,3127,113.7,270,0,3127,115.4,390,0,3127,113.7,510,0,3127,114.3,630,0,3127,114.9,750,0,3127,113.9,870,0,3127,113.0,990,0,3127,110.6,1110,0,3127,107.0,1230,0,3127,106.1,1350,0,3127,103.1,1470,0,3127,102.8,1590,0,3127,101.4,1710,0,3127,97.8,1830,0,3127,95.3,1950,0,3127,91.3,2070,0,3127,86.8,2190,0,3127,83.0,2310,0,3127,82.2,2430,0,3127,83.9,2550,0,3127,85.7,2670,0,3127,86.3,2790,0,3127,86.6,2910,0,3127,82.7,3030,0,3127,79.8,3150,0,3127,76.8,3270,0,3127,74.0,3390,0,3127,67.9,3510,0,3127,63.0,3630,0,3127,58.0,3750,0,3127,55.7,3870,0,3127,51.3,3990,0,3127,43.6,4110,0,3127,27.2,4230,0,3127,9.6,4350,0,3247,3.0,-4170,1,3247,3.0,-4050,1,3247,3.0,-3930,1,3247,3.0,-3810,1,3247,3.0,-3690,1,3247,5.9,-3570,0,3247,7.5,-3450,0,3247,19.2,-3330,0,3247,25.3,-3210,0,3247,26.7,-3090,0,3247,25.8,-2970,0,3247,27.6,-2850,0,3247,29.0,-2730,0,3247,28.6,-2610,0,3247,35.0,-2490,0,3247,38.5,-2370,0,3247,38.6,-2250,0,3247,41.9,-2130,0,3247,42.4,-2010,0,3247,41.3,-1890,0,3247,41.5,-1770,0,3247,44.6,-1650,0,3247,49.8,-1530,0,3247,57.6,-1410,0,3247,62.6,-1290,0,3247,61.4,-1170,0,3247,58.9,-1050,0,3247,60.0,-930,0,3247,65.6,-810,0,3247,69.6,-690,0,3247,67.7,-570,0,3247,67.1,-450,0,3247,72.2,-330,0,3247,70.7,-210,0,3247,70.6,-90,0,3247,100.2,30,0,3247,108.3,150,0,3247,117.3,270,0,3247,118.3,390,0,3247,117.3,510,0,3247,115.4,630,0,3247,115.5,750,0,3247,114.7,870,0,3247,113.4,990,0,3247,111.8,1110,0,3247,109.0,1230,0,3247,108.2,1350,0,3247,106.0,1470,0,3247,104.5,1590,0,3247,101.1,1710,0,3247,86.5,1830,0,3247,91.9,1950,0,3247,89.4,2070,0,3247,86.5,2190,0,3247,83.8,2310,0,3247,83.4,2430,0,3247,84.7,2550,0,3247,85.4,2670,0,3247,87.3,2790,0,3247,85.8,2910,0,3247,84.7,3030,0,3247,83.9,3150,0,3247,78.9,3270,0,3247,75.1,3390,0,3247,72.7,3510,0,3247,67.5,3630,0,3247,63.6,3750,0,3247,59.8,3870,0,3247,50.6,3990,0,3247,32.4,4110,0,3247,18.2,4230,0,3367,3.0,-4050,1,3367,3.0,-3930,1,3367,3.0,-3810,1,3367,3.0,-3690,1,3367,5.7,-3570,0,3367,3.8,-3450,0,3367,18.3,-3330,0,3367,22.1,-3210,0,3367,19.6,-3090,0,3367,20.0,-2970,0,3367,17.3,-2850,0,3367,17.1,-2730,0,3367,19.0,-2610,0,3367,27.1,-2490,0,3367,31.0,-2370,0,3367,32.9,-2250,0,3367,37.2,-2130,0,3367,39.7,-2010,0,3367,35.6,-1890,0,3367,36.4,-1770,0,3367,40.3,-1650,0,3367,42.6,-1530,0,3367,45.8,-1410,0,3367,50.7,-1290,0,3367,49.9,-1170,0,3367,50.2,-1050,0,3367,51.3,-930,0,3367,55.6,-810,0,3367,58.4,-690,0,3367,59.8,-570,0,3367,63.5,-450,0,3367,69.7,-330,0,3367,50.6,-210,0,3367,52.4,-90,0,3367,90.7,30,0,3367,109.7,150,0,3367,118.6,270,0,3367,122.3,390,0,3367,122.3,510,0,3367,115.8,630,0,3367,115.7,750,0,3367,115.4,870,0,3367,114.8,990,0,3367,111.8,1110,0,3367,110.9,1230,0,3367,113.3,1350,0,3367,109.3,1470,0,3367,103.9,1590,0,3367,100.8,1710,0,3367,65.1,1830,0,3367,74.8,1950,0,3367,89.2,2070,0,3367,87.1,2190,0,3367,84.4,2310,0,3367,82.5,2430,0,3367,83.6,2550,0,3367,87.3,2670,0,3367,89.1,2790,0,3367,88.7,2910,0,3367,87.2,3030,0,3367,81.7,3150,0,3367,78.6,3270,0,3367,77.5,3390,0,3367,74.4,3510,0,3367,69.6,3630,0,3367,65.3,3750,0,3367,54.0,3870,0,3367,35.0,3990,0,3367,20.2,4110,0,3367,6.1,4230,0,3487,3.0,-3930,1,3487,3.0,-3810,1,3487,3.0,-3690,1,3487,4.7,-3570,0,3487,7.1,-3450,0,3487,15.9,-3330,0,3487,15.7,-3210,0,3487,15.6,-3090,0,3487,19.2,-2970,0,3487,17.5,-2850,0,3487,14.9,-2730,0,3487,15.7,-2610,0,3487,18.5,-2490,0,3487,18.8,-2370,0,3487,21.4,-2250,0,3487,27.2,-2130,0,3487,30.0,-2010,0,3487,27.7,-1890,0,3487,32.1,-1770,0,3487,38.3,-1650,0,3487,37.0,-1530,0,3487,35.8,-1410,0,3487,38.4,-1290,0,3487,39.0,-1170,0,3487,41.0,-1050,0,3487,45.7,-930,0,3487,47.6,-810,0,3487,49.0,-690,0,3487,55.2,-570,0,3487,65.0,-450,0,3487,55.6,-330,0,3487,34.9,-210,0,3487,29.6,-90,0,3487,59.7,30,0,3487,93.7,150,0,3487,114.3,270,0,3487,119.7,390,0,3487,123.7,510,0,3487,121.5,630,0,3487,119.2,750,0,3487,120.8,870,0,3487,120.3,990,0,3487,117.4,1110,0,3487,117.4,1230,0,3487,116.1,1350,0,3487,113.1,1470,0,3487,107.4,1590,0,3487,95.5,1710,0,3487,52.8,1830,0,3487,54.1,1950,0,3487,82.1,2070,0,3487,88.4,2190,0,3487,83.9,2310,0,3487,81.4,2430,0,3487,82.4,2550,0,3487,86.4,2670,0,3487,88.3,2790,0,3487,87.3,2910,0,3487,86.5,3030,0,3487,84.1,3150,0,3487,82.2,3270,0,3487,79.8,3390,0,3487,75.2,3510,0,3487,71.1,3630,0,3487,66.0,3750,0,3487,42.5,3870,0,3487,19.1,3990,0,3607,3.0,-3810,1,3607,3.0,-3690,1,3607,3.0,-3570,1,3607,6.7,-3450,0,3607,7.5,-3330,0,3607,12.6,-3210,0,3607,11.0,-3090,0,3607,12.8,-2970,0,3607,15.6,-2850,0,3607,14.0,-2730,0,3607,14.2,-2610,0,3607,14.1,-2490,0,3607,12.7,-2370,0,3607,13.8,-2250,0,3607,15.6,-2130,0,3607,18.4,-2010,0,3607,20.7,-1890,0,3607,26.1,-1770,0,3607,32.8,-1650,0,3607,32.7,-1530,0,3607,30.0,-1410,0,3607,28.8,-1290,0,3607,29.1,-1170,0,3607,34.0,-1050,0,3607,37.6,-930,0,3607,39.9,-810,0,3607,45.6,-690,0,3607,53.9,-570,0,3607,48.9,-450,0,3607,34.9,-330,0,3607,13.1,-210,0,3607,27.9,30,0,3607,61.4,150,0,3607,103.0,270,0,3607,112.5,390,0,3607,119.3,510,0,3607,126.5,630,0,3607,131.5,750,0,3607,131.3,870,0,3607,128.3,990,0,3607,125.2,1110,0,3607,122.0,1230,0,3607,119.6,1350,0,3607,116.2,1470,0,3607,110.2,1590,0,3607,75.9,1710,0,3607,36.8,1830,0,3607,30.0,1950,0,3607,55.2,2070,0,3607,75.3,2190,0,3607,82.2,2310,0,3607,80.2,2430,0,3607,81.1,2550,0,3607,84.9,2670,0,3607,87.8,2790,0,3607,87.5,2910,0,3607,87.3,3030,0,3607,86.5,3150,0,3607,84.3,3270,0,3607,80.9,3390,0,3607,76.8,3510,0,3607,65.1,3630,0,3607,46.7,3750,0,3607,26.2,3870,0,3607,6.8,3990,0,3727,3.0,-3690,1,3727,3.0,-3570,1,3727,5.9,-3450,0,3727,6.6,-3330,0,3727,8.1,-3210,0,3727,8.7,-3090,0,3727,8.9,-2970,0,3727,8.9,-2850,0,3727,8.8,-2730,0,3727,8.1,-2610,0,3727,9.4,-2490,0,3727,10.1,-2370,0,3727,8.8,-2250,0,3727,11.7,-2130,0,3727,13.8,-2010,0,3727,12.5,-1890,0,3727,16.3,-1770,0,3727,22.5,-1650,0,3727,23.0,-1530,0,3727,21.4,-1410,0,3727,22.8,-1290,0,3727,23.0,-1170,0,3727,26.1,-1050,0,3727,29.8,-930,0,3727,31.4,-810,0,3727,35.0,-690,0,3727,34.8,-570,0,3727,26.8,-450,0,3727,11.9,-330,0,3727,36.4,150,0,3727,69.2,270,0,3727,106.9,390,0,3727,115.9,510,0,3727,126.0,630,0,3727,133.5,750,0,3727,135.1,870,0,3727,133.1,990,0,3727,129.6,1110,0,3727,125.3,1230,0,3727,121.0,1350,0,3727,114.7,1470,0,3727,85.5,1590,0,3727,50.6,1710,0,3727,15.3,1830,0,3727,26.9,2070,0,3727,45.9,2190,0,3727,59.9,2310,0,3727,69.6,2430,0,3727,77.2,2550,0,3727,82.2,2670,0,3727,88.7,2790,0,3727,87.7,2910,0,3727,86.8,3030,0,3727,85.0,3150,0,3727,71.8,3270,0,3727,56.6,3390,0,3727,49.8,3510,0,3727,38.1,3630,0,3727,23.6,3750,0,3727,7.1,3870,0,3847,3.0,-3450,1,3847,5.8,-3330,0,3847,6.0,-3210,0,3847,6.3,-3090,0,3847,6.3,-2970,0,3847,6.2,-2850,0,3847,5.9,-2730,0,3847,5.9,-2610,0,3847,6.1,-2490,0,3847,6.7,-2370,0,3847,7.6,-2250,0,3847,8.7,-2130,0,3847,10.1,-2010,0,3847,5.3,-1890,0,3847,6.6,-1770,0,3847,12.0,-1650,0,3847,14.1,-1530,0,3847,13.4,-1410,0,3847,15.0,-1290,0,3847,16.7,-1170,0,3847,22.6,-1050,0,3847,22.6,-930,0,3847,19.7,-810,0,3847,16.3,-690,0,3847,13.0,-570,0,3847,11.6,150,0,3847,37.7,270,0,3847,67.8,390,0,3847,98.0,510,0,3847,123.9,630,0,3847,132.7,750,0,3847,134.6,870,0,3847,118.6,990,0,3847,123.0,1110,0,3847,116.7,1230,0,3847,100.9,1350,0,3847,77.8,1470,0,3847,50.7,1590,0,3847,19.4,1710,0,3847,14.6,2190,0,3847,29.4,2310,0,3847,40.2,2430,0,3847,45.3,2550,0,3847,47.2,2670,0,3847,57.2,2790,0,3847,63.9,2910,0,3847,60.9,3030,0,3847,52.7,3150,0,3847,40.2,3270,0,3847,24.0,3390,0,3847,19.1,3510,0,3847,10.6,3630,0,3967,3.0,-3210,1,3967,3.0,-3090,1,3967,3.0,-2970,1,3967,3.0,-2850,1,3967,3.0,-2730,1,3967,3.0,-2610,1,3967,3.0,-2490,1,3967,3.0,-2370,1,3967,3.0,-2250,1,3967,5.3,-2130,0,3967,5.8,-2010,0,3967,6.1,-1890,0,3967,6.0,-1770,0,3967,6.9,-1650,0,3967,8.3,-1530,0,3967,9.6,-1410,0,3967,6.8,-1290,0,3967,11.3,-1170,0,3967,12.7,-1050,0,3967,13.1,-930,0,3967,9.7,-810,0,3967,8.1,270,0,3967,29.6,390,0,3967,51.5,510,0,3967,70.0,630,0,3967,80.1,750,0,3967,77.2,870,0,3967,64.2,990,0,3967,66.9,1110,0,3967,62.8,1230,0,3967,51.5,1350,0,3967,34.0,1470,0,3967,11.1,1590,0,3967,11.2,2550,0,3967,12.5,2670,0,3967,21.1,2790,0,3967,27.1,2910,0,3967,26.1,3030,0,3967,19.7,3150,0,3967,10.2,3270,0,4087,3.0,-3090,1,4087,3.0,-2970,1,4087,3.0,-2850,1,4087,3.0,-2730,1,4087,3.0,-2610,1,4087,3.0,-2490,1,4087,3.0,-2370,1,4087,3.0,-2250,1,4087,3.0,-2130,1,4087,3.0,-2010,1,4087,3.0,-1890,1,4087,3.0,-1770,1,4087,3.0,-1650,1,4087,3.0,-1530,1,4087,6.1,-1410,0,4087,6.8,-1290,0,4087,6.5,-1170,0,4087,6.8,-1050,0,4087,6.6,-930,0,4087,8.1,510,0,4087,19.7,630,0,4087,24.9,750,0,4087,21.7,870,0,4087,11.2,990,0,4087,12.2,1110,0,4087,10.2,1230,0,4207,3.0,-2370,1,4207,3.0,-2250,1,4207,3.0,-2130,1,4207,3.0,-2010,1,4207,3.0,-1890,1,4207,3.0,-1770,1,4207,3.0,-1650,1,4207,3.0,-1530,1,4207,3.0,-1410,1,4207,3.0,-1290,1},
	CELL = 120.0,
	LAKECELL = 360.0,
	LAKES = {780,-6420,1140,-7500,1140,-7140,1140,-6780,1140,-6420,1140,-6060,1500,-7500,1500,-7140,1500,-6780,1500,-6420,1500,-6060,1500,-5700,1860,-7500,1860,-7140,1860,-6780,1860,-6420,1860,-6060,1860,-5700,1860,-5340,2220,-7500,2220,-7140,2220,-6780,2220,-6420,2220,-6060,2220,-5700,2220,-5340,2580,-7500,2580,-7140,2580,-6780,2580,-6420,2580,-6060,2580,-5700,2580,-5340,2940,-7500,2940,-7140,2940,-6780,2940,-6420,2940,-6060,2940,-5700,2940,-5340,2940,-4980,2940,-4620,2940,-4260,2940,-3900,3300,-7500,3300,-7140,3300,-6780,3300,-6420,3300,-6060,3300,-5700,3300,-5340,3300,-4980,3300,-4620,3300,-4260,3300,-3900,3660,-7500,3660,-7140,3660,-6780,3660,-6420,3660,-6060,3660,-5700,3660,-5340,3660,-4980,3660,-4620,3660,-4260,3660,-3900,4020,-7500,4020,-7140,4020,-6780,4020,-6420,4020,-6060,4020,-5700,4020,-5340,4020,-4980,4020,-4620,4020,-4260,4020,-3900,4020,-3540,4020,-3180,4020,-2820,4020,-2460,4020,-2100,4020,-1740,4380,-7140,4380,-6780,4380,-6420,4380,-6060,4380,-5700,4380,-5340,4380,-4980,4380,-4620,4380,-4260,4380,-3900,4380,-3540,4380,-3180,4380,-2820,4380,-2460,4380,-2100,4380,-1740,4380,-1380,4380,-1020,4740,-6780,4740,-6420,4740,-6060,4740,-5700,4740,-5340,4740,-4980,4740,-4620,4740,-4260,4740,-3900,4740,-3540,4740,-3180,4740,-2820,4740,-2460,4740,-2100,4740,-1740,4740,-1380,4740,-1020,5100,-6780,5100,-6420,5100,-6060,5100,-5700,5100,-5340,5100,-4980,5100,-4620,5100,-4260,5100,-3900,5100,-3540,5100,-3180,5100,-2820,5100,-2460,5460,-6420,5460,-6060,5460,-5700,5460,-5340,5460,-4980,5460,-4620,5460,-4260,5460,-3900,5460,-3540,5460,-3180,5460,-2820,5460,-2460,5820,-6420,5820,-6060,5820,-5700,5820,-5340,5820,-4980,5820,-4620,5820,-4260,5820,-3900,5820,-3540,5820,-3180,5820,-2820,5820,-2460,6180,-6060,6180,-5700,6180,-5340,6180,-4980,6180,-4620,6180,-4260,6180,-3900,6180,-3540,6180,-3180,6180,-2820,6180,-2460,6540,-5700,6540,-5340,6540,-4980,6540,-4620,6540,-4260,6540,-3900,6540,-3540,6540,-3180,6540,-2820,6540,-2460,6540,-2100,6900,-5340,6900,-4980,6900,-4620,6900,-4260,6900,-3900,6900,-3540,6900,-3180,6900,-2820,6900,-2460,6900,-2100,7260,-5340,7260,-4980,7260,-4620,7260,-4260,7260,-3900,7260,-3540,7260,-3180,7260,-2820,7260,-2460,7260,-2100,7260,-1740,7620,-4980,7620,-4620,7620,-4260,7620,-3900,7620,-3540,7620,-3180,7620,-2820,7620,-2460,7620,-2100,7620,-1740,7620,-1380,7620,-1020},
	LAKE_Y = 4.8,
	FUJI = { -11770, -9298 },
}

end
__src["CarPhysics"] = function(script)
-- Kaido Drift car physics: a line-for-line port of the browser game's four-tyre simulation (CarX-style).
-- Units are metres, kg, seconds; the client converts to studs (3.5 per metre) when placing the car.
-- Per-wheel loads with longitudinal and lateral transfer, load-sensitive combined-slip tyres, Ackermann
-- steering, ABS, a locked rear differential with its own wheel speed (integrated semi-implicitly), turbo
-- lag, clutch kicks, an automatic or manual gearbox, and the five assist levels.
local CarPhysics = {}

local G, HCG, KPK, APK, ENTRY_YAW = 9.81, 0.5, 0.1, 0.14, -1
local DEG = math.pi / 180
CarPhysics.RW = 0.31 -- wheel radius (m)
local RW = CarPhysics.RW

local function clamp(v, a, b) return if v < a then a elseif v > b then b else v end
local function lerp(a, b, t) return a + (b - a) * t end
local function smooth(e0, e1, x) local t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t) end
local function sign(x) return if x > 0 then 1 elseif x < 0 then -1 else 0 end
local function tyreCurve(s) return math.sin(1.35 * math.atan(2.36 * s)) end
local function tyreXY(kap, alpha, D)
	local sx, sy = kap / KPK, alpha / APK
	local s = math.sqrt(sx * sx + sy * sy)
	if s < 1e-6 then return 0, 0 end
	local F = D * tyreCurve(s)
	return F * sx / s, -F * sy / s
end
function CarPhysics.torqueAt(c, rpm)
	if rpm >= c.red + 150 then return 0 end
	if rpm < c.peak then return c.torque * (0.55 + 0.45 * math.sin(math.pi / 2 * clamp((rpm - 1000) / (c.peak - 1000), 0, 1))) end
	return c.torque * (1 - 0.3 * ((rpm - c.peak) / (c.red - c.peak)) ^ 2)
end
local function gearRatio(P, c) return (if P.gear < 0 then -3.4 else c.gears[P.gear]) * c.final end

-- the browser game's assist levels
CarPhysics.ASSISTS = {
	off = { counter = 0, steerRate = 4.5, speedSteer = false, abs = false, tcs = false, esp = 0, espAngle = 9, damp = 0, entry = 0, thrMod = false },
	low = { counter = 0.35, steerRate = 6, speedSteer = true, abs = true, tcs = false, esp = 0, espAngle = 9, damp = 0.6, entry = 0.35, thrMod = false },
	std = { counter = 0.7, steerRate = 7.5, speedSteer = true, abs = true, tcs = false, esp = 8, espAngle = 1.15, damp = 1.6, entry = 0.5, thrMod = false },
	high = { counter = 0.95, steerRate = 9, speedSteer = true, abs = true, tcs = true, esp = 16, espAngle = 0.95, damp = 2.8, entry = 0.7, thrMod = true },
	touch = { counter = 1, steerRate = 9, speedSteer = true, abs = true, tcs = false, esp = 12, espAngle = 1.0, damp = 2.4, entry = 1, thrMod = true },
}

function CarPhysics.new(x, z, h)
	return {
		x = x, z = z, h = h, vx = 0, vz = 0, r = 0, wr = 0, gear = 1, shiftT = 0, revT = 0, delta = 0, ax = 0, ay = 0,
		boost = 0, eng = 900, rpm = 900, slip = 0, drifting = false, rearSlip = 0, frontLock = false, limiter = false,
		bPrev = nil, entryT = 0, entryDir = 0, entryArmed = true, offT = 0, kickT = 0, u = 0, thrEff = 0, brkEff = 0, loads = { 1, 1, 1, 1 },
	}
end

function CarPhysics.shiftUp(P, c) if P.gear > 0 and P.gear < #c.gears then P.gear += 1; P.shiftT = 0.12 end end
function CarPhysics.shiftDown(P, c) if P.gear > 1 then P.gear -= 1; P.shiftT = 0.1 end end

-- one step. input = { throttle, brake, hand, steer (+ = right) }; settings = { assist, trans, sens }
function CarPhysics.step(P, c, input, settings, dt)
	local m, Lw = c.mass, c.b.wb
	local a, b = Lw * (1 - c.front), Lw * c.front
	local Iz = m * a * b * 1.1
	local fx, fz = math.sin(P.h), math.cos(P.h)
	local lx, lz = fz, -fx -- forward and left unit vectors
	local u, vy = P.vx * fx + P.vz * fz, P.vx * lx + P.vz * lz
	local sp = math.sqrt(P.vx * P.vx + P.vz * P.vz)
	local thr, brk = input.throttle, input.brake
	local hand = input.hand
	local A = CarPhysics.ASSISTS[settings.assist] or CarPhysics.ASSISTS.std
	-- throttle feed: past ~26° of slide the gas is eased off so a held GAS button holds the angle instead of spinning
	if A.thrMod and thr > 0.05 and P.gear > 0 then
		local ab = math.abs(P.bPrev or 0)
		if ab > 0.45 then thr *= clamp(1 - (ab - 0.45) / 0.4, 0.3, 1) end
	end
	-- drift entry: steer firmly with the gas on and the rear steps out (once per steer input; also links transitions)
	if A.entry > 0 and P.gear > 0 and u > 8 and u < 45 and thr > 0.6 and math.abs(input.steer) > 0.65 and P.entryArmed and math.abs(P.bPrev or 0) < 0.12 then
		P.entryT, P.entryDir, P.entryArmed = 0.5, sign(input.steer), false
	end
	if math.abs(input.steer) < 0.3 or thr < 0.1 then P.entryArmed = true end
	P.entryT = math.max(0, P.entryT - dt)
	local eK = A.entry * P.entryT / 0.5
	-- reverse: hold brake at a standstill
	if P.gear > 0 then
		if brk > 0.2 and thr < 0.05 and u < 0.4 then
			P.revT += dt
			if P.revT > 0.3 then P.gear, P.revT = -1, 0 end
		else
			P.revT = 0
		end
	elseif thr > 0.2 and u > -0.4 then
		P.gear = 1
	end
	if P.gear < 0 then thr, brk = brk, thr end
	local ratio = gearRatio(P, c)
	local ar = math.abs(ratio)
	-- automatic gearbox works from road speed, so wheelspin mid-drift holds the gear
	P.shiftT = math.max(0, P.shiftT - dt)
	if settings.trans ~= "manual" and P.gear > 0 and P.shiftT == 0 then
		local roadRpm = math.abs(u) / RW * ar * 9.549
		if roadRpm > c.red * 0.97 and P.gear < #c.gears then
			P.gear += 1; P.shiftT = 0.16
		elseif P.gear > 1 and roadRpm < c.red * 0.45 and math.abs(u) / RW * c.gears[P.gear - 1] * c.final * 9.549 < c.red * 0.88 then
			P.gear -= 1; P.shiftT = 0.1
		end
	end
	-- engine
	local wheelRpm = math.abs(P.wr) * ar * 9.549
	local clutchSlip = wheelRpm < 1200 or hand
	local eng = if clutchSlip then math.max(wheelRpm, 900 + thr * 3400) else wheelRpm
	-- clutch kick: a quick off-on of the gas while steering dumps the clutch and breaks the rear loose
	if thr < 0.15 then
		P.offT += dt
	else
		if P.offT > 0.03 and P.offT < 0.45 and thr > 0.6 and math.abs(input.steer) > 0.25 and u > 8 then P.kickT = 0.35 end
		P.offT = 0
	end
	P.kickT = math.max(0, P.kickT - dt)
	local tq = 0
	if P.shiftT > 0 or hand then
		tq = 0
	elseif thr > 0.02 then
		tq = if eng > c.red then 0 else CarPhysics.torqueAt(c, eng) * thr * (if c.turbo then 0.62 + 0.38 * P.boost else 1) * (if P.kickT > 0 then 1.8 else 1)
	elseif not clutchSlip then
		tq = -sign(P.wr * ratio) * c.torque * 0.14 * clamp(eng / c.red, 0.2, 1)
	end
	P.limiter = eng > c.red and thr > 0.02
	-- turbo: boost builds with revs and throttle (with lag) and dumps when you lift
	if c.turbo then
		local want = smooth(2400, 4300, eng) * (if thr > 0.05 and not hand then thr else 0)
		P.boost += (want - P.boost) * math.min(1, dt * (if want > P.boost then 2.2 else 5))
	else
		P.boost = 1
	end
	local Tdrive = tq * ratio * 0.85
	-- ===== four tyres: per-wheel load, slip and grip =====
	local tw = c.b.wid - 0.2
	local htw = tw / 2
	local Wf, Wr = m * G * b / Lw / 2, m * G * a / Lw / 2
	local dLong = m * P.ax * HCG / Lw / 2
	local dLatF, dLatR = m * P.ay * HCG / tw * 0.62, m * P.ay * HCG / tw * 0.38
	local minZ = m * G * 0.02
	local Fz = { math.max(minZ, Wf - dLong - dLatF), math.max(minZ, Wf - dLong + dLatF), math.max(minZ, Wr + dLong - dLatR), math.max(minZ, Wr + dLong + dLatR) }
	local function grip(i)
		local front = i <= 2
		return c.mu * (if front then 1.0 else 1.06 * (1 - 0.6 * eK)) * Fz[i] * (1 - 0.08 * (Fz[i] / (if front then Wf else Wr) - 1))
	end
	local WX = { a, a, -b, -b }
	local WY = { htw, -htw, htw, -htw }
	-- steering: driver input plus countersteer assist (front wheels follow the direction of travel)
	local beta = if sp > 1.5 and P.gear > 0 and u > -0.5 * sp then math.atan2(vy, math.max(u, 0.01)) else 0
	local lock = c.lock * DEG
	local dIn = -input.steer * settings.sens
	local betaR = if sp > 1.5 and P.gear > 0 and u > 0.5 then math.atan2(vy - b * P.r, u) else 0
	local betaF = if sp > 1.5 and P.gear > 0 and u > 0.5 then math.atan2(vy + a * P.r, u) else 0
	local sliding = smooth(0.1, 0.25, math.abs(betaR))
	local oversteer = if sign(betaF) == -sign(P.r) then 1 else 0
	local counter = sliding > 0 and sign(dIn) == sign(betaR)
	local inLock = if A.speedSteer and not counter then lerp(lock / (1 + (math.abs(u) / 14) ^ 1.5), lock, sliding) else lock
	local dT = clamp(dIn * inLock + A.counter * sliding * oversteer * betaF, -lock, lock)
	P.delta += clamp(dT - P.delta, -A.steerRate * dt, A.steerRate * dt)
	local d = P.delta
	local ack = sign(d) * math.min(0.06, math.abs(d) * 0.12)
	local DEL = { d + ack, d - ack, 0, 0 }
	-- brakes: 65 % front; ABS on every assist level except Pro
	local brakeTotal = brk * m * G * 0.95
	local Fxw, Fyw = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
	local lockF = false
	for i = 1, 2 do
		local ui, vi = u - P.r * WY[i], vy + P.r * WX[i]
		local cd, sd = math.cos(DEL[i]), math.sin(DEL[i])
		local uw, vw = ui * cd + vi * sd, -ui * sd + vi * cd
		local D = grip(i)
		local alpha = math.atan2(vw, math.max(math.abs(uw), 1.5))
		local bf = brakeTotal * 0.65 / 2
		if A.abs then bf = math.min(bf, D * 0.92) end
		if bf > D * 1.02 and math.abs(uw) > 2 then
			lockF = true
			local vv = math.sqrt(uw * uw + vw * vw)
			if vv == 0 then vv = 1 end
			Fxw[i], Fyw[i] = -uw / vv * D * 0.9, -vw / vv * D * 0.9
		else
			Fyw[i] = -D * sign(alpha) * tyreCurve(math.abs(alpha) / APK)
			Fxw[i] = if math.abs(uw) > 0.2 then -sign(uw) * bf else 0
			local t = math.sqrt(Fxw[i] ^ 2 + Fyw[i] ^ 2)
			if t > D then Fxw[i] *= D / t; Fyw[i] *= D / t end
		end
	end
	P.frontLock = lockF
	-- rear axle: locked differential, one shared wheel speed, integrated semi-implicitly against both tyres
	local Iw = 1.6 + c.engI * ratio * ratio * (if clutchSlip then 0.25 else 1)
	local rr = {}
	for _, i in { 3, 4 } do
		local ui, vi = u - P.r * WY[i], vy + P.r * WX[i]
		table.insert(rr, { i = i, ui = ui, vi = vi, den = math.max(math.abs(ui), 2), D = grip(i), alpha = math.atan2(vi, math.max(math.abs(ui), 1.5)) })
	end
	local Fx0, slope = 0, 0
	for _, w in rr do
		Fx0 += (tyreXY((P.wr * RW - w.ui) / w.den, w.alpha, w.D))
		slope += w.D * 1.35 * 2.36 / KPK * RW / w.den
	end
	local Tdr = Tdrive
	if A.tcs and thr > 0 then
		local spinS = P.wr * RW - u
		if spinS > 6 + math.abs(vy) then Tdr *= clamp(1 - (spinS - 6) / 10, 0.35, 1) end
	end
	local wr = P.wr + dt * (Tdr - RW * Fx0) / (Iw + dt * RW * slope)
	local Tb = brakeTotal * 0.35 * RW + (if hand then 4200 else 0)
	if Tb > 0 then
		local dw = Tb * dt / Iw
		wr = if math.abs(wr) <= dw then 0 else wr - sign(wr) * dw
	end
	P.wr = wr
	for _, w in rr do
		Fxw[w.i], Fyw[w.i] = tyreXY((wr * RW - w.ui) / w.den, w.alpha, w.D)
	end
	-- sum the four tyres into body forces and yaw moment
	local Fxb, Fyb, Mz = 0, 0, 0
	for i = 1, 4 do
		local cd, sd = math.cos(DEL[i]), math.sin(DEL[i])
		local fxb, fyb = Fxw[i] * cd - Fyw[i] * sd, Fxw[i] * sd + Fyw[i] * cd
		Fxb += fxb; Fyb += fyb
		Mz += WX[i] * fyb - WY[i] * fxb
	end
	Fxb -= 0.6 * c.CdA * u * math.abs(u) + m * G * 0.013 * clamp(u, -1, 1)
	-- stability control past the angle a skilled driver would hold (Medium/High); slide damping; drift entry yaw
	if A.esp > 0 and math.abs(beta) > A.espAngle and sp > 5 then Mz += A.esp * Iz * (beta - sign(beta) * A.espAngle) end
	local bRate = (betaR - (P.bPrev or betaR)) / dt
	P.bPrev = betaR
	if A.damp > 0 and sliding > 0 then Mz += A.damp * sliding * Iz * clamp(bRate, -4, 4) end
	if eK > 0 then Mz += ENTRY_YAW * P.entryDir * eK * Iz * 3.2 end
	local FzSum = Fz[1] + Fz[2] + Fz[3] + Fz[4]
	for i = 1, 4 do P.loads[i] = Fz[i] / FzSum * 4 end
	P.vx += (Fxb * fx + Fyb * lx) / m * dt
	P.vz += (Fxb * fz + Fyb * lz) / m * dt
	P.r += Mz / Iz * dt
	if sp < 2 then P.r *= 1 - math.min(1, (2 - sp) * 3 * dt) end
	if sp < 0.35 and thr < 0.05 and (brk > 0.05 or hand) then P.vx, P.vz, P.r, P.wr = 0, 0, 0, 0 end
	P.h += P.r * dt
	P.x += P.vx * dt
	P.z += P.vz * dt
	P.ax += (Fxb / m - P.ax) * math.min(1, dt * 10)
	P.ay += (Fyb / m - P.ay) * math.min(1, dt * 10)
	P.eng, P.u, P.thrEff, P.brkEff = eng, u, thr, brk
	P.slip = if sp > 1.5 then math.atan2(-vy, math.abs(u)) else 0 -- + = sliding toward the car's right
	P.rearSlip = math.sqrt((wr * RW - u) ^ 2 + (vy - b * P.r) ^ 2)
	local sp2 = math.sqrt(P.vx * P.vx + P.vz * P.vz)
	P.drifting = if P.drifting then (math.abs(P.slip) > 0.1 and sp2 > 5) else (math.abs(P.slip) > 0.19 and sp2 > 7)
end

-- a rigid-body impulse against a wall (as in the browser game). n = wall normal pointing back into the
-- road (x, z), depth = how far the corner went through, (rpx, rpz) = that corner relative to the centre
function CarPhysics.wallHit(P, c, nx, nz, depth, rpx, rpz)
	local m, Lw = c.mass, c.b.wb
	local a, b = Lw * (1 - c.front), Lw * c.front
	local Iz = m * a * b * 1.1
	P.x += nx * depth; P.z += nz * depth
	local vpx, vpz = P.vx + P.r * rpz, P.vz - P.r * rpx
	local vn = vpx * nx + vpz * nz
	if vn < 0 then
		local k = nx * rpz - nz * rpx
		local j = -1.25 * vn / (1 / m + k * k / Iz)
		P.vx += j * nx / m; P.vz += j * nz / m; P.r += j * k / Iz
		local tx, tz = -nz, nx
		local vt, kt = vpx * tx + vpz * tz, tx * rpz - tz * rpx
		local jt = clamp(-vt / (1 / m + kt * kt / Iz), -0.3 * j, 0.3 * j)
		P.vx += jt * tx / m; P.vz += jt * tz / m; P.r += jt * kt / Iz
		return -vn
	end
	return 0
end

-- engine rpm for the gauges and sound (browser updatePlayerVisual)
function CarPhysics.visual(P, c, dt)
	P.rpm += (P.eng - P.rpm) * math.min(1, dt * 14)
	if P.limiter then P.rpm = c.red - math.random() * 250 end
end

return CarPhysics

end
__src["SoundIds"] = function(script)
-- Kaido Drift sound IDs.
-- Easiest: upload the 7 files in roblox/sounds (Studio: Home > Asset Manager > Bulk Import, or Creator Hub),
-- then drag each one from the Toolbox (Inventory > My Audio) into Workspace or SoundService. The game finds
-- them by name (kaido_engine_low, kaido_engine_mid, ...) on its own.
-- Or paste the IDs here: just the number works ("1234567890"), or "rbxassetid://1234567890".
return {
	kaido_engine_low = "",
	kaido_engine_mid = "",
	kaido_engine_high = "",
	kaido_engine_off = "",
	kaido_skid = "",
	kaido_blowoff = "",
	kaido_wind = "",
}

end
__src["City"] = function(script)
-- Kaido Drift: Shin-Hakone, a big night city east of the pass. A street grid with a downtown of glass
-- towers, mid-rise blocks with lit floors and vertical neon signs, low houses and parks at the edges,
-- a lattice tower, a scramble crossing with giant screens, an elevated expressway loop with a ramp,
-- and a road linking it all to the Hakone pass. Everything solid goes in City/Solid (cars hit it);
-- everything drivable goes in City/Ground.
local City = {}

local GRID = 24 -- blocks per side
local BLOCK = 200 -- block size (studs)
local STREET = 48 -- street width (studs)
local PITCH = BLOCK + STREET
local GY = 6.6 -- street surface height
local CURB = 0.6 -- sidewalk height above the street
local RING = 5 -- the expressway runs along the streets RING blocks out from the centre
local RING_Y = 58 -- expressway deck height
local DECK = 44 -- expressway deck width

local SIGNS = { "ラーメン", "カラオケ", "居酒屋", "寿司", "ホテル", "薬", "焼肉", "ゲーム", "喫茶", "酒", "書店", "質", "パチンコ", "駐車場", "整骨院", "そば", "うどん", "コンビニ", "銭湯", "麻雀" }
local SIGN_COLORS = { Color3.fromRGB(255, 70, 110), Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(150, 255, 120), Color3.fromRGB(255, 120, 40), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 255, 255) }
-- ground-floor shops you'd see on a Japanese street. col: facade, glow: lit interior, sign: board colour,
-- text: what the sign says, ink: text colour
local SHOPS = {
	boba = { col = Color3.fromRGB(255, 214, 226), glow = Color3.fromRGB(255, 236, 214), sign = Color3.fromRGB(120, 230, 214), text = "BOBA TEA  タピオカ", ink = Color3.fromRGB(70, 30, 60) },
	ramen = { col = Color3.fromRGB(70, 44, 30), glow = Color3.fromRGB(255, 200, 130), sign = Color3.fromRGB(230, 40, 40), text = "ラーメン  RAMEN", ink = Color3.fromRGB(255, 240, 220) },
	konbini = { col = Color3.fromRGB(244, 244, 240), glow = Color3.fromRGB(235, 250, 255), sign = Color3.fromRGB(40, 160, 90), text = "コンビニ  24h", ink = Color3.fromRGB(255, 255, 255) },
	cafe = { col = Color3.fromRGB(120, 84, 60), glow = Color3.fromRGB(255, 214, 160), sign = Color3.fromRGB(240, 226, 200), text = "喫茶  CAFÉ", ink = Color3.fromRGB(70, 44, 30) },
	arcade = { col = Color3.fromRGB(26, 22, 40), glow = Color3.fromRGB(190, 120, 255), sign = Color3.fromRGB(255, 70, 160), text = "ゲーム  GAME", ink = Color3.fromRGB(255, 255, 255) },
	sushi = { col = Color3.fromRGB(226, 214, 190), glow = Color3.fromRGB(255, 230, 190), sign = Color3.fromRGB(30, 50, 110), text = "寿司  SUSHI", ink = Color3.fromRGB(255, 255, 255) },
	karaoke = { col = Color3.fromRGB(46, 30, 70), glow = Color3.fromRGB(255, 120, 220), sign = Color3.fromRGB(160, 80, 255), text = "カラオケ", ink = Color3.fromRGB(255, 255, 255) },
	drug = { col = Color3.fromRGB(240, 240, 236), glow = Color3.fromRGB(250, 250, 240), sign = Color3.fromRGB(255, 214, 40), text = "薬  DRUG", ink = Color3.fromRGB(30, 30, 30) },
}
local DOWNTOWN_SHOPS = { "boba", "boba", "ramen", "konbini", "konbini", "cafe", "arcade", "arcade", "sushi", "karaoke", "karaoke", "drug" }
local SUBURB_SHOPS = { "boba", "ramen", "ramen", "konbini", "konbini", "cafe", "sushi", "drug" }
local WINDOW = { Color3.fromRGB(255, 214, 150), Color3.fromRGB(255, 236, 200), Color3.fromRGB(190, 220, 255), Color3.fromRGB(150, 200, 255) }

function City.build(ctx)
	local Track, rng, breathe = ctx.Track, ctx.rng, ctx.breathe
	local FLOOR, HALF = ctx.FLOOR, ctx.HALF
	local root = Instance.new("Folder")
	root.Name = "City"
	root.Parent = ctx.map
	local ground = Instance.new("Folder"); ground.Name = "Ground"; ground.Parent = root
	local solid = Instance.new("Folder"); solid.Name = "Solid"; solid.Parent = root
	local deco = Instance.new("Folder"); deco.Name = "Deco"; deco.Parent = root
	local lights = Instance.new("Folder"); lights.Name = "Lights"; lights.Parent = root
	local signs = Instance.new("Folder"); signs.Name = "Signs"; signs.Parent = root

	local nLight = 0
	local function part(parent, size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	-- a long flat part, split into pieces no bigger than Roblox's 2048-stud limit
	local function slab(parent, x0, z0, x1, z1, y, h, color, mat)
		local lx, lz = x1 - x0, z1 - z0
		local nx, nz = math.ceil(lx / 2000), math.ceil(lz / 2000)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local sx, sz = lx / nx, lz / nz
				part(parent, Vector3.new(sx, h, sz), CFrame.new(x0 + sx * (i + 0.5), y - h / 2, z0 + sz * (j + 0.5)), color, mat)
			end
		end
	end

	-- place the city east of the pass
	local maxX, minZ, maxZ = -math.huge, math.huge, -math.huge
	for i = 1, Track.N do
		maxX = math.max(maxX, Track.X[i])
		minZ, maxZ = math.min(minZ, Track.Z[i]), math.max(maxZ, Track.Z[i])
	end
	local SIZE = GRID * PITCH + STREET
	local X0 = maxX + 900
	local Z0 = (minZ + maxZ) / 2 - SIZE / 2
	local cx, cz = X0 + SIZE / 2, Z0 + SIZE / 2
	local function streetX(i) return X0 + i * PITCH + STREET / 2 end -- centre line of the i-th north-south street
	local function streetZ(j) return Z0 + j * PITCH + STREET / 2 end

	-- terrain under the city: cleared from 4 studs below street level up (terrain uses 4-stud voxels and
	-- would bulge through the streets otherwise); the street slab is thick enough to hide the gap
	for gx = X0 - 200, X0 + SIZE + 200, 1024 do
		for gz = Z0 - 200, Z0 + SIZE + 200, 1024 do
			workspace.Terrain:FillBlock(CFrame.new(gx + 512, GY - 4 + 8, gz + 512), Vector3.new(1024, 16, 1024), Enum.Material.Air)
			workspace.Terrain:FillBlock(CFrame.new(gx + 512, GY - 4 - 6, gz + 512), Vector3.new(1024, 12, 1024), Enum.Material.Concrete)
			breathe()
		end
	end

	-- streets: one asphalt sheet, then lane lines
	local asphalt = Color3.fromRGB(40, 41, 46)
	slab(ground, X0, Z0, X0 + SIZE, Z0 + SIZE, GY, 6, asphalt, Enum.Material.Asphalt)
	local lineCol = Color3.fromRGB(236, 232, 214)
	local yellow = Color3.fromRGB(240, 188, 40)
	local function mark(x, z, sx, sz, col)
		local p = part(deco, Vector3.new(sx, 0.06, sz), CFrame.new(x, GY + 0.03, z), col)
		p.CanCollide, p.CanQuery = false, false
	end
	-- every fourth street is an avenue: double yellow centre line and white lane lines; others a white centre line
	for i = 0, GRID do
		local avenue = i % 4 == 0
		for j = 0, GRID - 1 do
			local a0 = Z0 + j * PITCH + STREET + 8 -- this block's stretch, clear of the junctions
			local l = BLOCK - 16
			local mid = a0 + l / 2
			local x = streetX(i)
			local z = streetZ(i)
			local b0 = X0 + j * PITCH + STREET + 8
			local midx = b0 + l / 2
			if avenue then
				mark(x - 0.55, mid, 0.4, l, yellow); mark(x + 0.55, mid, 0.4, l, yellow)
				mark(x - STREET / 4, mid, 0.35, l, lineCol); mark(x + STREET / 4, mid, 0.35, l, lineCol)
				mark(midx, z - 0.55, l, 0.4, yellow); mark(midx, z + 0.55, l, 0.4, yellow)
				mark(midx, z - STREET / 4, l, 0.35, lineCol); mark(midx, z + STREET / 4, l, 0.35, lineCol)
			else
				mark(x, mid, 0.45, l, lineCol)
				mark(midx, z, l, 0.45, lineCol)
			end
		end
		breathe()
	end
	local function district(x, z)
		local d = math.max(math.abs(x - cx), math.abs(z - cz)) / (SIZE / 2)
		return d
	end

	-- buildings
	local buildingCount = 0
	local function windowBands(b, size, cf, faces, color, every, tier, minY)
		-- strips of lit windows on the street faces (local -Z / +Z / -X / +X): towers get many, others five
		every = math.max(every, (size.Y - 4) / (if size.Y > 140 then 16 else 5))
		for _, f in faces do
			local horiz = f == "z-" or f == "z+"
			local w = horiz and size.X or size.Z
			for y = every, size.Y - 4, every do
				if y >= (minY or 0) and rng:NextNumber() < 0.78 then
					local len = w * (0.35 + rng:NextNumber() * 0.55)
					local off = (rng:NextNumber() - 0.5) * (w - len)
					local pos
					if f == "z-" then pos = CFrame.new(off, -size.Y / 2 + y, -size.Z / 2 - 0.08)
					elseif f == "z+" then pos = CFrame.new(off, -size.Y / 2 + y, size.Z / 2 + 0.08)
					elseif f == "x-" then pos = CFrame.new(-size.X / 2 - 0.08, -size.Y / 2 + y, off)
					else pos = CFrame.new(size.X / 2 + 0.08, -size.Y / 2 + y, off) end
					local s = horiz and Vector3.new(len, 1.6, 0.15) or Vector3.new(0.15, 1.6, len)
					local p = part(b, s, cf * pos, color, Enum.Material.Neon)
					p.CanCollide, p.CanQuery = false, false
					p.Name = "Window"
					p:SetAttribute("Tier", tier)
				end
			end
		end
	end
	local function sign(b, cf, height, text, color)
		local s = part(b, Vector3.new(3.2, height, 0.8), cf, Color3.fromRGB(18, 18, 22))
		s.CanCollide, s.CanQuery = false, false
		s.Name = "Sign"
		local face = part(b, Vector3.new(2.8, height - 0.6, 0.2), cf * CFrame.new(0, 0, -0.45), color, Enum.Material.Neon)
		face.CanCollide, face.CanQuery = false, false
		face.Name = "SignFace"
		face.Transparency = 0.15
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.PixelsPerStud = 24
		g.LightInfluence = 0
		g.Parent = face
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.fromRGB(20, 12, 24)
		t.Text = table.concat(string.split(text, ""), "\n")
		t.Parent = g
		signs:SetAttribute("n", (signs:GetAttribute("n") or 0) + 1)
	end

	-- text on a sign face (hidden on low graphics, like the other signs)
	local function signText(face, label, ink)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.PixelsPerStud = 20
		g.LightInfluence = 0
		g.Parent = face
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = ink
		t.Text = label
		t.Parent = g
	end
	-- the frame of a street face of a box: origin at the ground in the middle of that face, -Z pointing out
	local function faceFrame(cf, w, l, h, f)
		local out = if f == "z-" then Vector3.new(0, 0, -1) elseif f == "z+" then Vector3.new(0, 0, 1) elseif f == "x-" then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
		local half = if f == "z-" or f == "z+" then l / 2 else w / 2
		local width = if f == "z-" or f == "z+" then w else l
		local base = cf.Position + out * half - Vector3.new(0, h / 2, 0)
		return CFrame.lookAt(base, base + out), width
	end
	-- a themed shop on the ground floor of a building face
	local function shopFront(b, F, faceW, kind)
		local k = SHOPS[kind]
		local W = math.min(faceW * 0.86, 46)
		local function at(x, y, z) return F * CFrame.new(x, y, z) end
		local function deco(size, cf, color, mat, shape)
			local q = part(b, size, cf, color, mat, shape); q.CanCollide, q.CanQuery = false, false; return q
		end
		deco(Vector3.new(W, 9, 0.4), at(0, 4.5, -0.25), k.col, if kind == "ramen" or kind == "cafe" then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic)
		local glass = deco(Vector3.new(W * 0.8, 5.4, 0.12), at(0, 3.1, -0.5), k.glow, Enum.Material.Neon)
		glass.Name = "Window"; glass:SetAttribute("Tier", 1); glass.Transparency = 0.1
		deco(Vector3.new(W * 0.8, 5.4, 0.1), at(0, 3.1, -0.45), Color3.fromRGB(150, 170, 190), Enum.Material.Glass).Transparency = 0.5
		local board = deco(Vector3.new(W * 0.74, 2.4, 0.5), at(0, 7.6, -0.75), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
		local face = deco(Vector3.new(W * 0.72, 2.1, 0.12), board.CFrame * CFrame.new(0, 0, -0.3), k.sign, Enum.Material.Neon)
		face.Name = "SignFace"
		signText(face, k.text, k.ink)
		if kind == "boba" then
			-- a giant tapioca cup on the sign: clear cup, pink tea, black pearls, a neon straw
			local c0 = at(W * 0.3, 12.5, -1.4)
			deco(Vector3.new(6, 4.6, 4.6), c0 * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 190, 210), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.25
			deco(Vector3.new(0.6, 4.9, 4.9), c0 * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			for p = 1, 3 do deco(Vector3.new(1.2, 1.2, 1.2), c0 * CFrame.new((p - 2) * 1.2, -2.2, (p % 2) * 0.6 - 0.3), Color3.fromRGB(30, 20, 20), Enum.Material.SmoothPlastic, Enum.PartType.Ball) end
			deco(Vector3.new(0.5, 6, 0.5), c0 * CFrame.new(0.6, 4.6, 0) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(80, 230, 255), Enum.Material.Neon)
			deco(Vector3.new(W * 0.8, 0.3, 3), at(0, 6.2, -1.9) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(150, 230, 220), Enum.Material.Fabric)
		elseif kind == "ramen" or kind == "sushi" then
			-- noren curtains over the door, paper lanterns either side
			local cloth = if kind == "ramen" then Color3.fromRGB(150, 24, 30) else Color3.fromRGB(28, 44, 96)
			for n = -1, 1 do deco(Vector3.new(2.2, 3.2, 0.1), at(n * 2.4, 4.6, -0.75), cloth, Enum.Material.Fabric) end
			for _, x in { -W * 0.42, W * 0.42 } do
				local lan = deco(Vector3.new(1.8, 2.6, 1.8), at(x, 5.2, -1.3), if kind == "ramen" then Color3.fromRGB(240, 50, 40) else Color3.fromRGB(255, 244, 220), Enum.Material.Neon, Enum.PartType.Ball)
				lan.Name = "Lantern"
			end
		elseif kind == "konbini" then
			-- the stripe band, bins and parked bikes out front
			deco(Vector3.new(W, 0.7, 0.2), at(0, 6.1, -0.55), Color3.fromRGB(255, 140, 30), Enum.Material.SmoothPlastic)
			deco(Vector3.new(W, 0.7, 0.2), at(0, 6.8, -0.55), Color3.fromRGB(40, 160, 90), Enum.Material.SmoothPlastic)
			for n = 0, 1 do deco(Vector3.new(1.4, 2.6, 1.4), at(-W * 0.36 + n * 1.8, 1.3, -1.6), Color3.fromRGB(70, 110, 160), Enum.Material.SmoothPlastic) end
			for n = 0, 1 do
				local bx = W * 0.3 + n * 1.6
				for _, z in { -2.4, -4.8 } do deco(Vector3.new(0.15, 2, 2), at(bx, 1, z) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) end
				deco(Vector3.new(0.2, 0.25, 2.6), at(bx, 1.5, -3.6), Color3.fromRGB(200, 40, 50), Enum.Material.Metal)
			end
		elseif kind == "cafe" then
			for n = 0, 3 do
				deco(Vector3.new(W * 0.8 / 4, 0.3, 3), at(-W * 0.3 + n * W * 0.2, 6.2, -1.9) * CFrame.Angles(math.rad(-14), 0, 0), if n % 2 == 0 then Color3.fromRGB(30, 90, 60) else Color3.fromRGB(240, 236, 226), Enum.Material.Fabric)
			end
			for _, x in { -W * 0.44, W * 0.44 } do
				deco(Vector3.new(1.6, 1.6, 1.6), at(x, 0.8, -1.4), Color3.fromRGB(120, 70, 50), Enum.Material.Brick)
				deco(Vector3.new(2.4, 2.4, 2.4), at(x, 2.6, -1.4), Color3.fromRGB(50, 110, 56), Enum.Material.Grass, Enum.PartType.Ball)
			end
		elseif kind == "arcade" then
			for n = -1, 1 do deco(Vector3.new(0.4, 8, 0.3), at(n * W * 0.45, 4.5, -0.6), SIGN_COLORS[(n + 2) * 2], Enum.Material.Neon) end
			for n = 0, 1 do
				local cm = at(-W * 0.3 + n * 3.4, 0, -2)
				deco(Vector3.new(3, 5.2, 3), cm * CFrame.new(0, 2.6, 0), Color3.fromRGB(180, 220, 255), Enum.Material.Glass).Transparency = 0.45
				deco(Vector3.new(3.1, 0.8, 3.1), cm * CFrame.new(0, 5.6, 0), Color3.fromRGB(255, 80, 180), Enum.Material.Neon)
			end
		elseif kind == "karaoke" or kind == "drug" then
			deco(Vector3.new(W, 0.6, 0.2), at(0, 6.4, -0.55), k.sign, Enum.Material.Neon)
		end
	end

	local function building(x0, z0, x1, z1, d, streetSides)
		local w, l = x1 - x0, z1 - z0
		local h, col, mat, every
		local tier = rng:NextInteger(1, 3)
		if d < 0.24 then
			h = 160 + rng:NextNumber() ^ 1.6 * 380
			col = ({ Color3.fromRGB(30, 44, 66), Color3.fromRGB(22, 30, 40), Color3.fromRGB(40, 60, 70), Color3.fromRGB(56, 60, 70) })[rng:NextInteger(1, 4)]
			mat = Enum.Material.Glass
			every = 7
		elseif d < 0.6 then
			h = 34 + rng:NextNumber() ^ 1.3 * 120
			-- Japanese mid-rise: tiled apartment facades, brick, board-marked concrete, rendered plaster
			local look = ({
				{ Color3.fromRGB(196, 190, 178), Enum.Material.CeramicTiles }, { Color3.fromRGB(150, 120, 100), Enum.Material.CeramicTiles },
				{ Color3.fromRGB(122, 74, 58), Enum.Material.Brick }, { Color3.fromRGB(96, 70, 60), Enum.Material.Brick },
				{ Color3.fromRGB(150, 148, 142), Enum.Material.Concrete }, { Color3.fromRGB(112, 114, 118), Enum.Material.Concrete },
				{ Color3.fromRGB(214, 206, 190), Enum.Material.Plaster }, { Color3.fromRGB(84, 92, 104), Enum.Material.Plaster },
			})[rng:NextInteger(1, 8)]
			col, mat = look[1], look[2]
			every = 9
		else
			h = 12 + rng:NextNumber() * 12
			-- houses: rendered plaster, dark timber cladding or brick
			local look = ({
				{ Color3.fromRGB(224, 216, 200), Enum.Material.Plaster }, { Color3.fromRGB(200, 188, 166), Enum.Material.Plaster },
				{ Color3.fromRGB(176, 186, 190), Enum.Material.Plaster }, { Color3.fromRGB(92, 64, 46), Enum.Material.WoodPlanks },
				{ Color3.fromRGB(70, 54, 42), Enum.Material.WoodPlanks }, { Color3.fromRGB(140, 86, 64), Enum.Material.Brick },
			})[rng:NextInteger(1, 6)]
			col, mat = look[1], look[2]
			every = 6
		end
		local b = Instance.new("Model")
		b.Name = "Building"
		local cf = CFrame.new((x0 + x1) / 2, GY + CURB + h / 2, (z0 + z1) / 2)
		local size = Vector3.new(w, h, l)
		local body = part(b, size, cf, col, mat)
		body.Name = "Body"
		if mat == Enum.Material.Glass then
			body.Reflectance = 0.18
			-- a faint glow behind the glass on the street faces, so towers read as lit glass at night
			for _, f in streetSides do
				local horiz = f == "z-" or f == "z+"
				local off = if f == "z-" then CFrame.new(0, 0, -l / 2 - 0.05) elseif f == "z+" then CFrame.new(0, 0, l / 2 + 0.05) elseif f == "x-" then CFrame.new(-w / 2 - 0.05, 0, 0) else CFrame.new(w / 2 + 0.05, 0, 0)
				local glow = part(b, if horiz then Vector3.new(w - 1, h - 6, 0.1) else Vector3.new(0.1, h - 6, l - 1), cf * off, Color3.fromRGB(40, 70, 110), Enum.Material.Neon)
				glow.Transparency = 0.82; glow.CanCollide, glow.CanQuery = false, false; glow.Name = "Window"; glow:SetAttribute("Tier", 1)
			end
		end
		-- base and top: a stone podium and metal crown on towers, a parapet on mid-rise roofs
		if mat == Enum.Material.Glass then
			part(b, Vector3.new(w + 1.2, 8, l + 1.2), cf * CFrame.new(0, -h / 2 + 4, 0), Color3.fromRGB(64, 66, 72), Enum.Material.Granite).CanQuery = false
			part(b, Vector3.new(w + 0.8, 3, l + 0.8), cf * CFrame.new(0, h / 2 - 1.5, 0), Color3.fromRGB(46, 50, 58), Enum.Material.Metal).CanQuery = false
		elseif d < 0.6 then
			local dark = Color3.new(col.R * 0.75, col.G * 0.75, col.B * 0.75)
			part(b, Vector3.new(w + 0.6, 1.4, l + 0.6), cf * CFrame.new(0, h / 2 + 0.7, 0), dark, Enum.Material.Concrete).CanQuery = false
		end
		-- roof: plant rooms and, on towers, red aviation lights
		if d < 0.6 then
			part(b, Vector3.new(w * 0.4, 5, l * 0.4), cf * CFrame.new(0, h / 2 + 2.5, 0), Color3.fromRGB(70, 72, 78), Enum.Material.Metal).CanQuery = false
			if h > 140 then
				for _, c in { { -1, -1 }, { 1, 1 } } do
					local a = part(b, Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(c[1] * (w / 2 - 1), h / 2 + 0.6, c[2] * (l / 2 - 1)), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
					a.Name = "AirLight"; a.CanQuery = false
				end
			end
		else
			local roof = Instance.new("WedgePart")
			-- kawara clay tiles: mostly blue-grey, some terracotta
			local tile = if rng:NextNumber() < 0.75 then Color3.fromRGB(62, 66, 78) else Color3.fromRGB(146, 70, 48)
			roof.Anchored, roof.Size, roof.Color, roof.Material = true, Vector3.new(w + 2, 5, l / 2 + 1), tile, Enum.Material.ClayRoofTiles
			-- a stone plinth along the bottom of the walls
			part(b, Vector3.new(w + 0.4, 1.6, l + 0.4), cf * CFrame.new(0, -h / 2 + 0.8, 0), Color3.fromRGB(96, 94, 90), Enum.Material.Cobblestone).CanQuery = false
			roof.CFrame = cf * CFrame.new(0, h / 2 + 2.5, -(l / 4 + 0.5))
			roof.Parent = b
			local roof2 = roof:Clone()
			roof2.CFrame = cf * CFrame.new(0, h / 2 + 2.5, l / 4 + 0.5) * CFrame.Angles(0, math.pi, 0)
			roof2.Parent = b
		end
		if d >= 0.18 and d < 0.6 and #streetSides > 0 then
			-- a shop on the main street face of every mid-rise block, and sometimes round the corner too
			for n, f in streetSides do
				if n == 1 or rng:NextNumber() < 0.35 then
					local F, fw = faceFrame(cf, w, l, h, f)
					shopFront(b, F, fw, DOWNTOWN_SHOPS[rng:NextInteger(1, #DOWNTOWN_SHOPS)])
				end
			end
		elseif d >= 0.6 and d < 0.9 and #streetSides > 0 and rng:NextNumber() < 0.4 then
			-- a corner shop in a house
			local F, fw = faceFrame(cf, w, l, h, streetSides[1])
			shopFront(b, F, fw, SUBURB_SHOPS[rng:NextInteger(1, #SUBURB_SHOPS)])
			b:SetAttribute("Shop", true)
		end
		if d < 0.6 then
			windowBands(b, size, cf, streetSides, WINDOW[rng:NextInteger(1, #WINDOW)], every, tier, if mat == Enum.Material.Glass then 0 else 14) -- keep clear of the shops below
		elseif #streetSides > 0 and not b:GetAttribute("Shop") then
			-- a house: one lit window toward the street
			local f = streetSides[1]
			local off = if f == "z-" then CFrame.new(0, 1, -l / 2 - 0.08) elseif f == "z+" then CFrame.new(0, 1, l / 2 + 0.08) elseif f == "x-" then CFrame.new(-w / 2 - 0.08, 1, 0) else CFrame.new(w / 2 + 0.08, 1, 0)
			local horiz = f == "z-" or f == "z+"
			local ww = math.min(6, (if horiz then w else l) * 0.4)
			local frame = part(b, if horiz then Vector3.new(ww + 0.8, 3.8, 0.12) else Vector3.new(0.12, 3.8, ww + 0.8), cf * off, Color3.fromRGB(58, 44, 34), Enum.Material.Wood)
			frame.CanCollide, frame.CanQuery = false, false
			local win = part(b, if horiz then Vector3.new(ww, 3, 0.15) else Vector3.new(0.15, 3, ww), cf * off * (if horiz then CFrame.new(0, 0, (f == "z-") and -0.03 or 0.03) else CFrame.new((f == "x-") and -0.03 or 0.03, 0, 0)), WINDOW[1], Enum.Material.Neon)
			win.Name = "Window"; win.CanCollide, win.CanQuery = false, false
			win:SetAttribute("Tier", tier)
			-- front door beside the window
			local along = (if horiz then w else l) * 0.36
			local doorOff = if horiz then CFrame.new(along, -h / 2 - 1 + 3.5, 0) else CFrame.new(0, -h / 2 - 1 + 3.5, along)
			local door = part(b, if horiz then Vector3.new(3, 7, 0.2) else Vector3.new(0.2, 7, 3), cf * off * doorOff, Color3.fromRGB(70, 48, 34), Enum.Material.WoodPlanks)
			door.CanCollide, door.CanQuery = false, false
		end
		-- vertical neon signs on mid-rise and low shop fronts facing a street
		if d >= 0.18 and d < 0.75 and rng:NextNumber() < 0.42 and #streetSides > 0 then
			local f = streetSides[1]
			local sh = math.min(h - 4, 10 + rng:NextNumber() * 14)
			local y = -h / 2 + 6 + sh / 2
			local pos
			if f == "z-" then pos = CFrame.new(w / 2 - 3, y, -l / 2 - 2.2)
			elseif f == "z+" then pos = CFrame.new(-w / 2 + 3, y, l / 2 + 2.2) * CFrame.Angles(0, math.pi, 0)
			elseif f == "x-" then pos = CFrame.new(-w / 2 - 2.2, y, -l / 2 + 3) * CFrame.Angles(0, -math.pi / 2, 0)
			else pos = CFrame.new(w / 2 + 2.2, y, l / 2 - 3) * CFrame.Angles(0, math.pi / 2, 0) end
			sign(b, cf * pos * CFrame.Angles(0, math.pi / 2, 0), sh, SIGNS[rng:NextInteger(1, #SIGNS)], SIGN_COLORS[rng:NextInteger(1, #SIGN_COLORS)])
		end
		b.Parent = solid
		buildingCount += 1
	end

	-- the expressway ring sits over these streets; keep its pillars clear of buildings
	local ringLo, ringHi = GRID // 2 - RING, GRID // 2 + RING
	local centreI, centreJ = GRID // 2, GRID // 2

	for i = 0, GRID - 1 do
		for j = 0, GRID - 1 do
			local bx0 = X0 + STREET + i * PITCH
			local bz0 = Z0 + STREET + j * PITCH
			local bx1, bz1 = bx0 + BLOCK, bz0 + BLOCK
			-- sidewalk / block base
			local base = part(ground, Vector3.new(BLOCK, CURB + 0.6, BLOCK), CFrame.new(bx0 + BLOCK / 2, GY + CURB / 2 - 0.3, bz0 + BLOCK / 2), Color3.fromRGB(128, 126, 122), Enum.Material.Pavement)
			base.Name = "Block"
			-- kerb stones around the block
			local kc = Color3.fromRGB(190, 188, 182)
			for _, k in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
				local kx, kz = bx0 + BLOCK / 2 + k[1] * (BLOCK / 2 - 0.6), bz0 + BLOCK / 2 + k[2] * (BLOCK / 2 - 0.6)
				local kp = part(deco, if k[1] == 0 then Vector3.new(BLOCK, CURB + 0.66, 1.2) else Vector3.new(1.2, CURB + 0.66, BLOCK), CFrame.new(kx, GY + CURB / 2 - 0.27, kz), kc, Enum.Material.Concrete)
				kp.CanCollide, kp.CanQuery = false, false
			end
			local d = district(bx0 + BLOCK / 2, bz0 + BLOCK / 2)
			if i == centreI - 1 and j == centreJ - 1 then
				-- the tower plaza
				local tx, tz = bx0 + BLOCK / 2, bz0 + BLOCK / 2
				local red, white = Color3.fromRGB(214, 52, 30), Color3.fromRGB(236, 236, 236)
				local tower = Instance.new("Model"); tower.Name = "Tower"
				local H = 640
				for k = 0, 15 do
					local f0, f1 = k / 16, (k + 1) / 16
					local spread0, spread1 = 70 * (1 - f0) ^ 1.7 + 4, 70 * (1 - f1) ^ 1.7 + 4
					local y0, y1 = GY + CURB + f0 * H, GY + CURB + f1 * H
					for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
						local a = Vector3.new(tx + c[1] * spread0, y0, tz + c[2] * spread0)
						local bb = Vector3.new(tx + c[1] * spread1, y1, tz + c[2] * spread1)
						local leg = part(tower, Vector3.new(3, 3, (bb - a).Magnitude), CFrame.lookAt((a + bb) / 2, bb), (k % 2 == 0) and red or white, Enum.Material.Metal)
						leg.CanQuery = k < 2
					end
					if k == 5 or k == 10 then
						local deckP = part(tower, Vector3.new(spread1 * 2 + 14, 10, spread1 * 2 + 14), CFrame.new(tx, y1, tz), Color3.fromRGB(240, 240, 240), Enum.Material.Glass)
						deckP.CanQuery = false
						local glow = part(tower, Vector3.new(spread1 * 2 + 15, 1.5, spread1 * 2 + 15), CFrame.new(tx, y1 + 3, tz), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
						glow.CanQuery = false
					end
				end
				local tip = part(tower, Vector3.new(3, 60, 3), CFrame.new(tx, GY + CURB + H + 30, tz), white, Enum.Material.Metal); tip.CanQuery = false
				local beacon = part(tower, Vector3.new(4, 4, 4), CFrame.new(tx, GY + CURB + H + 62, tz), Color3.fromRGB(255, 40, 40), Enum.Material.Neon); beacon.Name = "AirLight"; beacon.CanQuery = false
				tower.Parent = solid
			elseif (i == ringLo or i == ringHi - 1 or j == ringLo or j == ringHi - 1) and i >= ringLo and i < ringHi and j >= ringLo and j < ringHi then
				-- blocks under the expressway: low parking decks
				part(solid, Vector3.new(BLOCK - 30, 14, BLOCK - 30), CFrame.new(bx0 + BLOCK / 2, GY + CURB + 7, bz0 + BLOCK / 2), Color3.fromRGB(96, 98, 104), Enum.Material.Concrete).Name = "Parking"
			elseif d > 0.62 and rng:NextNumber() < 0.12 then
				-- a small park
				for _ = 1, 7 do
					local tx, tz = bx0 + 20 + rng:NextNumber() * (BLOCK - 40), bz0 + 20 + rng:NextNumber() * (BLOCK - 40)
					local t = Instance.new("Model"); t.Name = "Tree"; t:SetAttribute("Tier", rng:NextInteger(1, 3))
					part(t, Vector3.new(10, 1.4, 1.4), CFrame.new(tx, GY + CURB + 5, tz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(72, 52, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
					part(t, Vector3.new(14, 11, 14), CFrame.new(tx, GY + CURB + 13, tz), Color3.fromRGB(40, 86, 46), Enum.Material.Grass, Enum.PartType.Ball)
					t.Parent = solid
				end
				part(deco, Vector3.new(BLOCK - 8, 0.2, BLOCK - 8), CFrame.new(bx0 + BLOCK / 2, GY + CURB + 0.05, bz0 + BLOCK / 2), Color3.fromRGB(60, 96, 52), Enum.Material.Grass).CanCollide = false
			else
				-- split the block into lots: towers take a whole quarter, low-rise packs in
				local n = if d < 0.6 then 2 else 3
				local lot = (BLOCK - 8) / n
				for a = 0, n - 1 do
					for c = 0, n - 1 do
						if not (n >= 3 and a > 0 and a < n - 1 and c > 0 and c < n - 1) then -- inner lots stay courtyards
							local x0 = bx0 + 4 + a * lot + 2
							local z0 = bz0 + 4 + c * lot + 2
							local sides = {}
							-- east-west streets first: that's where you start and where the lantern strings hang
							if c == 0 then table.insert(sides, "z-") end
							if c == n - 1 then table.insert(sides, "z+") end
							if a == 0 then table.insert(sides, "x-") end
							if a == n - 1 then table.insert(sides, "x+") end
							local inset = if d < 0.24 then 6 else 2
							if d < 0.6 or rng:NextNumber() < 0.72 then -- some suburban lots stay open
								building(x0 + inset, z0 + inset, x0 + lot - 4 - inset, z0 + lot - 4 - inset, d, sides)
							end
						end
					end
				end
			end
			breathe()
		end
	end

	-- street lights on every corner (lights shared out by the graphics level), crosswalks downtown
	for i = 0, GRID do
		for j = 0, GRID do
			local x, z = streetX(i), streetZ(j)
			local px, pz = x + STREET / 2 + 2, z + STREET / 2 + 2
			part(solid, Vector3.new(0.8, 20, 0.8), CFrame.new(px, GY + CURB + 10, pz), Color3.fromRGB(70, 72, 76), Enum.Material.Metal).Name = "Pole"
			local head = part(lights, Vector3.new(2.6, 0.5, 1.4), CFrame.new(px - 4, GY + CURB + 19.6, pz - 4), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
			head.Name = "LampHead"
			nLight += 1
			head:SetAttribute("N", nLight)
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 214, 160), 48, 2.2, false
			l.Parent = head
			local jd = district(x, z)
			if jd < 0.48 then
				-- zebra crossings on all four sides and stop lines before them
				for side = -1, 1, 2 do
					for k = -3, 3 do
						mark(x + k * 6.2, z + side * (STREET / 2 + 6), 3, 10, lineCol)
						mark(x + side * (STREET / 2 + 6), z + k * 6.2, 10, 3, lineCol)
					end
					mark(x + side * STREET / 4, z + side * (STREET / 2 + 13), STREET / 2 - 2, 0.8, lineCol)
					mark(x - side * (STREET / 2 + 13), z + side * STREET / 4, 0.8, STREET / 2 - 2, lineCol)
				end
			end
			if i % 4 == 0 and j % 4 == 0 then
				-- traffic lights on the corners of avenue junctions
				for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
					local px2, pz2 = x + c[1] * (STREET / 2 + 3), z + c[2] * (STREET / 2 + 3)
					part(solid, Vector3.new(0.9, 16, 0.9), CFrame.new(px2, GY + CURB + 8, pz2), Color3.fromRGB(70, 72, 76), Enum.Material.Metal).Name = "Pole"
					local arm = part(deco, Vector3.new(0.6, 0.6, 12), CFrame.new(px2, GY + CURB + 15.4, pz2 - c[2] * 6), Color3.fromRGB(70, 72, 76), Enum.Material.Metal)
					arm.CanCollide, arm.CanQuery = false, false
					local box = part(deco, Vector3.new(6.5, 2.2, 1.4), CFrame.new(px2, GY + CURB + 14.6, pz2 - c[2] * 11), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
					box.CanCollide, box.CanQuery = false, false
					local lamp = part(deco, Vector3.new(1.6, 1.6, 0.3), CFrame.new(px2 + (((i + j) // 4) % 2 == 0 and -2 or 2), GY + CURB + 14.6, pz2 - c[2] * 11 - c[2] * 0.75), ((i + j) // 4) % 2 == 0 and Color3.fromRGB(60, 255, 150) or Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
					lamp.CanCollide, lamp.CanQuery = false, false
					lamp.Name = "Signal"
				end
			end
		end
		breathe()
	end

	-- street life: utility poles and overhead wires in the suburbs, vending machines on corners, paper lantern
	-- strings across the shopping streets
	local poleCol, wireCol = Color3.fromRGB(150, 146, 136), Color3.fromRGB(26, 26, 28)
	local function wire(a, b2)
		local m = (a + b2) / 2
		local wp = part(deco, Vector3.new(0.14, 0.14, (b2 - a).Magnitude), CFrame.lookAt(m, b2), wireCol, Enum.Material.SmoothPlastic)
		wp.CanCollide, wp.CanQuery, wp.CastShadow = false, false, false
	end
	for j = 0, GRID do
		local z = streetZ(j)
		for i = 0, GRID - 1 do
			local bx0 = X0 + i * PITCH + STREET
			local d = district(bx0 + BLOCK / 2, z)
			if d >= 0.55 then
				-- two concrete poles per block on the north pavement, wired to each other and to the next block
				local pz = z - STREET / 2 - 2.5
				local tops = {}
				for n, px in { bx0 + 20, bx0 + 120 } do
					part(solid, Vector3.new(1.1, 26, 1.1), CFrame.new(px, GY + CURB + 13, pz), poleCol, Enum.Material.Concrete).Name = "Pole"
					local arm = part(deco, Vector3.new(0.4, 0.4, 7), CFrame.new(px, GY + CURB + 24, pz), poleCol, Enum.Material.Concrete)
					arm.CanCollide, arm.CanQuery = false, false
					if n == 2 and rng:NextNumber() < 0.4 then
						local tr = part(deco, Vector3.new(1.8, 2.6, 1.8), CFrame.new(px, GY + CURB + 20, pz + 1.2), Color3.fromRGB(120, 124, 128), Enum.Material.Metal, Enum.PartType.Cylinder)
						tr.CFrame = tr.CFrame * CFrame.Angles(0, 0, math.pi / 2); tr.CanCollide, tr.CanQuery = false, false
					end
					tops[n] = px
				end
				for _, dz in { -2.8, 2.8 } do
					local y = GY + CURB + 24
					wire(Vector3.new(tops[1], y, pz + dz), Vector3.new(tops[2], y, pz + dz))
					if i < GRID - 1 then wire(Vector3.new(tops[2], y, pz + dz), Vector3.new(tops[1] + PITCH, y, pz + dz)) end
				end
			elseif d >= 0.2 and d < 0.6 and j % 2 == 0 and j < GRID then
				-- a string of paper lanterns across the shopping street, mid-block
				local lx = bx0 + BLOCK / 2
				local y = GY + CURB + 17
				wire(Vector3.new(lx, y + 0.8, z - STREET / 2 - 2), Vector3.new(lx, y + 0.8, z + STREET / 2 + 2))
				for n = 0, 6 do
					local lz = z - STREET / 2 + 3 + n * (STREET - 6) / 6
					local lan = part(deco, Vector3.new(1.6, 2.2, 1.6), CFrame.new(lx, y - (math.sin(n / 6 * math.pi) * 1.2), lz), if n % 2 == 0 then Color3.fromRGB(240, 50, 40) else Color3.fromRGB(255, 240, 210), Enum.Material.Neon, Enum.PartType.Ball)
					lan.Name = "Lantern"; lan.CanCollide, lan.CanQuery = false, false
				end
			end
		end
		breathe()
	end
	-- vending machines: a pair or three on a pavement corner, glowing day and night
	local VEND = { Color3.fromRGB(230, 236, 246), Color3.fromRGB(200, 30, 40), Color3.fromRGB(30, 90, 200), Color3.fromRGB(40, 160, 90) }
	for i = 0, GRID do
		for j = 0, GRID do
			local x, z = streetX(i), streetZ(j)
			local d = district(x, z)
			if d > 0.22 and d < 0.9 and rng:NextNumber() < 0.35 then
				local n = rng:NextInteger(2, 3)
				for k = 0, n - 1 do
					local base = Vector3.new(x - STREET / 2 - 3.2, GY + CURB, z + STREET / 2 + 8 + k * 3.8)
					local face = CFrame.lookAt(base, base + Vector3.new(1, 0, 0))
					part(solid, Vector3.new(3.6, 6.2, 2.4), face * CFrame.new(0, 3.1, 0), VEND[rng:NextInteger(1, #VEND)], Enum.Material.SmoothPlastic).Name = "Vending"
					local glow = part(deco, Vector3.new(3, 3.4, 0.12), face * CFrame.new(0, 3.8, -1.22), Color3.fromRGB(200, 236, 255), Enum.Material.Neon)
					glow.Name = "VendingFace"; glow.CanCollide, glow.CanQuery = false, false
				end
			end
		end
		breathe()
	end

	-- the scramble crossing: giant screens on the corner buildings
	do
		local x, z = streetX(centreI), streetZ(centreJ)
		local texts = { "KAIDO DRIFT", "峠", "新箱根", "DRIFT KING" }
		for k, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			local sx, sz = x + c[1] * (STREET / 2 + 34), z + c[2] * (STREET / 2 + 34)
			local look = CFrame.lookAt(Vector3.new(sx, GY + 70, sz), Vector3.new(x, GY + 70, z))
			local screen = part(signs, Vector3.new(44, 26, 1), look * CFrame.new(0, 0, 1), Color3.fromRGB(30, 30, 40), Enum.Material.Neon)
			screen.Name = "Screen"; screen.CanQuery = false
			local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.PixelsPerStud = 12; g.LightInfluence = 0; g.Parent = screen
			local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = SIGN_COLORS[k]; bg.Parent = g
			local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.TextColor3 = Color3.fromRGB(12, 12, 18); t.Text = texts[k]; t.Parent = g
		end
	end

	-- the elevated expressway (Shuto-style) loop around downtown, with a ramp up from the west
	local expressway = Instance.new("Folder"); expressway.Name = "Expressway"; expressway.Parent = root
	local ex0, ex1 = streetX(ringLo), streetX(ringHi)
	local ez0, ez1 = streetZ(ringLo), streetZ(ringHi)
	local deckCol, wallCol = Color3.fromRGB(46, 47, 52), Color3.fromRGB(150, 152, 156)
	local rampZ = streetZ(centreJ)
	local function deck(a: Vector3, b: Vector3, gapSide: number?)
		-- in sections: Roblox parts can't be longer than 2,048 studs
		local total = (b - a).Magnitude
		local n = math.max(1, math.ceil(total / 600))
		for s = 0, n - 1 do
			local p0, p1 = a:Lerp(b, s / n), a:Lerp(b, (s + 1) / n)
			local len = (p1 - p0).Magnitude
			local ext = if s == 0 or s == n - 1 then DECK / 2 else 0.5
			local cf = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, 0, if s == 0 then ext / 2 - 0.25 elseif s == n - 1 then -(ext / 2 - 0.25) else 0)
			local d = part(ground, Vector3.new(DECK, 2, len + ext + 0.5), cf * CFrame.new(0, -1, 0), deckCol, Enum.Material.Asphalt)
			d.Name = "Deck"
			for _, side in { -1, 1 } do
				if side ~= gapSide then
					part(solid, Vector3.new(1.4, 4.5, len + ext + 0.5), cf * CFrame.new(side * (DECK / 2 - 0.7), 2.25, 0), wallCol, Enum.Material.Concrete).Name = "Barrier"
				end
			end
			local ln = part(deco, Vector3.new(0.5, 0.08, len), cf * CFrame.new(0, 0.04, 0), lineCol)
			ln.CanCollide = false
			-- warm sodium lights along the deck
			if s % 2 == 0 then
				local head = part(lights, Vector3.new(2.4, 0.5, 1.2), cf * CFrame.new(DECK / 2 - 3, 14, 0), Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
				head.Name = "LampHead"
				nLight += 1
				head:SetAttribute("N", nLight)
				local l = Instance.new("PointLight")
				l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 186, 112), 50, 2.4, false
				l.Parent = head
				part(solid, Vector3.new(0.7, 14, 0.7), cf * CFrame.new(DECK / 2 - 0.7, 7, 0), Color3.fromRGB(70, 72, 76), Enum.Material.Metal).Name = "Pole"
			end
		end
	end
	local corners = { Vector3.new(ex0, RING_Y, ez0), Vector3.new(ex1, RING_Y, ez0), Vector3.new(ex1, RING_Y, ez1), Vector3.new(ex0, RING_Y, ez1) }
	for k = 1, 4 do
		local a, b = corners[k], corners[k % 4 + 1]
		if k == 4 then
			-- the west side has the ramp joining in the middle: split it and leave the outer wall open there
			local mid = Vector3.new(ex0, RING_Y, rampZ)
			deck(a, mid + Vector3.new(0, 0, DECK * 0.6))
			deck(mid - Vector3.new(0, 0, DECK * 0.6), b)
			part(ground, Vector3.new(DECK, 2, DECK * 1.4), CFrame.new(mid - Vector3.new(0, 1, 0)), deckCol, Enum.Material.Asphalt).Name = "Deck"
		else
			deck(a, b)
		end
		-- pillars every two blocks
		local n = math.floor((b - a).Magnitude / (PITCH * 2))
		for s = 0, n do
			local p = a:Lerp(b, s / math.max(n, 1))
			part(solid, Vector3.new(10, RING_Y - GY - 2, 10), CFrame.new(p.X, (RING_Y - 2 + GY) / 2, p.Z), Color3.fromRGB(120, 122, 126), Enum.Material.Concrete).Name = "Pillar"
		end
		breathe()
	end
	-- ramp: from street level on the westmost avenue up to the ring
	local rampStart = Vector3.new(ex0 - 760, GY, rampZ)
	local rampEnd = Vector3.new(ex0 - DECK / 2, RING_Y, rampZ)
	do
		local steps = 16
		for s = 0, steps - 1 do
			local a = rampStart:Lerp(rampEnd, s / steps)
			local b = rampStart:Lerp(rampEnd, (s + 1) / steps)
			-- ease in and out so the car does not launch
			local function ease(v, t) return Vector3.new(v.X, GY + (RING_Y - GY) * (t * t * (3 - 2 * t)), v.Z) end
			a, b = ease(a, s / steps), ease(b, (s + 1) / steps)
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt((a + b) / 2, b)
			part(ground, Vector3.new(DECK - 8, 2, len + 1), cf * CFrame.new(0, -1, 0), deckCol, Enum.Material.Asphalt).Name = "Ramp"
			for _, side in { -1, 1 } do
				part(solid, Vector3.new(1.4, 4.5, len + 1), cf * CFrame.new(side * ((DECK - 8) / 2 - 0.7), 2.25, 0), wallCol, Enum.Material.Concrete).Name = "Barrier"
			end
			if a.Y > GY + 6 then
				part(solid, Vector3.new(8, a.Y - GY, 8), CFrame.new(a.X, (a.Y + GY) / 2 - 1, a.Z), Color3.fromRGB(120, 122, 126), Enum.Material.Concrete).Name = "Pillar"
			end
		end
	end

	-- the link road from the Hakone pass: leaves the pass at its eastern-most point, drops to street level
	local jIdx, side = ctx.junction, ctx.junctionSide
	local jx = Track.X[jIdx] + Track.RX[jIdx] * side * HALF
	local jz = Track.Z[jIdx] + Track.RZ[jIdx] * side * HALF
	local jy = Track.Y[jIdx]
	local entryZ = streetZ(math.clamp(math.floor((jz - Z0) / PITCH + 0.5), 0, GRID))
	local pts = {
		Vector3.new(jx, jy, jz),
		Vector3.new(jx + 160, jy, jz),
		Vector3.new(jx + 160 + (X0 - jx - 160) * 0.5, (jy + GY) / 2, (jz + entryZ) / 2),
		Vector3.new(X0 - 40, GY, entryZ),
		Vector3.new(X0 + STREET / 2, GY, entryZ),
	}
	-- smooth the polyline into short pieces
	local path = {}
	for k = 1, #pts - 1 do
		local p0, p1, p2, p3 = pts[math.max(1, k - 1)], pts[k], pts[k + 1], pts[math.min(#pts, k + 2)]
		local segs = math.max(2, math.floor((p2 - p1).Magnitude / 30))
		for s = 0, segs - 1 do
			local t = s / segs
			local t2, t3 = t * t, t * t * t
			table.insert(path, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
		end
	end
	table.insert(path, pts[#pts])
	local link = Instance.new("Folder"); link.Name = "Link"; link.Parent = root
	for k = 1, #path - 1 do
		local a, b = path[k], path[k + 1]
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		part(ground, Vector3.new(HALF * 2, 4, len + 2), cf * CFrame.new(0, -2, 0), asphalt, Enum.Material.Asphalt).Name = "Link"
		workspace.Terrain:FillBlock(cf * CFrame.new(0, -5.5, 0), Vector3.new(HALF * 2 + 4, 4, len + 2), Enum.Material.Ground)
		workspace.Terrain:FillBlock(cf * CFrame.new(0, 13.5, 0), Vector3.new(HALF * 2 + 12, 33, len + 4), Enum.Material.Air)
		if k > 3 then
			for _, sd in { -1, 1 } do
				part(solid, Vector3.new(0.5, 1.2, len + 1), cf * CFrame.new(sd * (HALF + 0.9), 1.6, 0), Color3.fromRGB(172, 174, 178), Enum.Material.DiamondPlate).Name = "Rail"
			end
		end
		if (a.Y + b.Y) / 2 > FLOOR + 1 then
			local m = (a + b) / 2
			local flat = CFrame.lookAt(Vector3.new(m.X, (m.Y + FLOOR) / 2 - 1, m.Z), Vector3.new(b.X, (m.Y + FLOOR) / 2 - 1, b.Z))
			part(link, Vector3.new(HALF * 2 + 6, m.Y - FLOOR, len + 2), flat, Color3.fromRGB(96, 88, 78), Enum.Material.Slate)
		end
	end

	return {
		bounds = { X0, Z0, X0 + SIZE, Z0 + SIZE },
		junction = jIdx,
		junctionSide = side,
		-- start downtown on a shopping street (lantern strings, shops both sides), facing +X
		spawn = { streetX(6), GY, streetZ(8), 0 },
		grid = { X0 = X0, Z0 = Z0, PITCH = PITCH, STREET = STREET, GRID = GRID },
		ring = { ex0, ez0, ex1, ez1 },
		buildings = buildingCount,
	}
end

return City

end
do
local script = Instance.new("Script"); script.Name = "Watchdog"; script.Parent = ServerF
;(function()
-- Kaido Drift: if a server script fails while building the map, tell the players' loading screens why
-- (instead of loading forever).
local ScriptContext = game:GetService("ScriptContext")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ScriptContext.Error:Connect(function(message, trace)
	if ReplicatedStorage:GetAttribute("KaidoError") then return end
	ReplicatedStorage:SetAttribute("KaidoError", tostring(message) .. "\n" .. tostring(trace))
end)

end)()
end
do
local script = Instance.new("Script"); script.Name = "Main"; script.Parent = ServerF
;(function()
-- Kaido Drift (Roblox) server: builds the Hakone pass (real course and elevation, hills, Lake Ashi,
-- Kojiri village, Mt. Fuji on the horizon), keeps every player's progress and settings on Roblox's
-- servers (DataStore), checks drift scores and laps, and relays cars between players on the public map.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Track = require(Shared.Track)
local Course = require(Shared.CourseData)
local City = require(script.Parent:WaitForChild("City"))

-- ===================== remotes =====================
local remotes = Instance.new("Folder")
remotes.Name = "KaidoRemotes"
local function remote(class, name)
	local ok, r = pcall(Instance.new, class)
	if not ok then r = Instance.new("RemoteEvent") end
	r.Name = name
	r.Parent = remotes
	return r
end
local GetProfile = remote("RemoteFunction", "GetProfile")
local Buy = remote("RemoteFunction", "Buy")
local SelectCar = remote("RemoteFunction", "Select")
local Paint = remote("RemoteFunction", "Paint")
local Erase = remote("RemoteFunction", "Erase")
local SaveSettings = remote("RemoteEvent", "SaveSettings")
local SetMode = remote("RemoteEvent", "SetMode")
local Bank = remote("RemoteEvent", "Bank")
local Lap = remote("RemoteEvent", "Lap")
local State = remote("UnreliableRemoteEvent", "State")
local Others = remote("UnreliableRemoteEvent", "Others")
local ProfileChanged = remote("RemoteEvent", "Profile")
local Tune = remote("RemoteFunction", "Tune")
local Admin = remote("RemoteFunction", "Admin")
local Announce = remote("RemoteEvent", "Announce")
local AdminEvent = remote("RemoteEvent", "AdminEvent") -- admin commands sent to one player's game (teleport, freeze, message)
local BuySpecial = remote("RemoteEvent", "BuySpecial")
remotes.Parent = ReplicatedStorage

-- ===================== lighting (each player can change the time of day for themselves) =====================
Lighting.ClockTime = 0
Lighting.Brightness = 1.4
Lighting.Ambient = Color3.fromRGB(34, 38, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(58, 64, 100)
Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.7
local atmo = Instance.new("Atmosphere")
atmo.Density, atmo.Offset, atmo.Haze, atmo.Glare = 0.3, 0.12, 1.1, 0
atmo.Color, atmo.Decay = Color3.fromRGB(72, 82, 122), Color3.fromRGB(22, 24, 42)
atmo.Parent = Lighting
local sky = Instance.new("Sky")
sky.StarCount, sky.CelestialBodiesShown, sky.MoonAngularSize = 6000, true, 13
sky.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "KaidoBloom"
bloom.Intensity, bloom.Size, bloom.Threshold = 0.55, 28, 1.6
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "KaidoGrade"
cc.Contrast, cc.Saturation = 0.08, 0.06
cc.Parent = Lighting

-- ===================== map =====================
local map = Instance.new("Folder")
map.Name = "KaidoMap"
map.Parent = workspace
local rng = Random.new(1989)
local N, X, Y, Z = Track.N, Track.X, Track.Y, Track.Z
local HALF = Config.ROAD_HALF
local FLOOR = 6 -- the open ground a little above the lake
local terrain = workspace.Terrain
local work = 0
local function breathe() work += 1; if work % 120 == 0 then task.wait() end end

local function block(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then p.Shape = shape end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ground, hills and Lake Ashi (terrain)
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 1, N do
	minX, maxX = math.min(minX, X[i]), math.max(maxX, X[i])
	minZ, maxZ = math.min(minZ, Z[i]), math.max(maxZ, Z[i])
end
local margin = 2400
for gx = minX - margin, maxX + margin, 2048 do
	for gz = minZ - margin, maxZ + margin, 2048 do
		terrain:FillBlock(CFrame.new(gx + 1024, FLOOR - 6, gz + 1024), Vector3.new(2048, 12, 2048), Enum.Material.Grass)
		breathe()
	end
end
local LAKE_Y = Course.LAKE_Y
local function lakeCell(x, z, size)
	terrain:FillBlock(CFrame.new(x, LAKE_Y + 6, z), Vector3.new(size, 12, size), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(x, LAKE_Y - 6, z), Vector3.new(size, 12, size), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(x, LAKE_Y - 16, z), Vector3.new(size, 8, size), Enum.Material.Sand)
end
local L = Course.LAKES
for k = 1, #L, 2 do lakeCell(L[k], L[k + 1], Course.LAKECELL); breathe() end
local C, CS = Course.CELLS, Course.CELL
local hillTops = {}
for k = 1, #C, 4 do
	local x, top, z, lake = C[k], C[k + 1], C[k + 2], C[k + 3]
	if lake == 1 then
		lakeCell(x, z, CS)
	elseif top > FLOOR + 0.5 then
		local mat = if top > 60 then Enum.Material.LeafyGrass else Enum.Material.Grass
		terrain:FillBlock(CFrame.new(x, (top + FLOOR - 4) / 2, z), Vector3.new(CS, top - FLOOR + 4, CS), mat)
		table.insert(hillTops, { x, top, z })
	else
		table.insert(hillTops, { x, FLOOR, z })
	end
	breathe()
end

-- where the link road to the city leaves the pass: its eastern-most point (no guardrail on that side there)
local junction, junctionSide = 1, 1
do
	local best = -math.huge
	for k = 1, N do if X[k] > best then best, junction = X[k], k end end
	junctionSide = if Track.RX[junction] > 0 then 1 else -1
end
local function nearJunction(k)
	local d = math.abs(k - junction)
	return math.min(d, N - d) <= 5
end

-- road: straight runs are merged into long parts, curves use short ones
local road = Instance.new("Folder")
road.Name = "Road"
road.Parent = map
local rails = Instance.new("Folder")
rails.Name = "Rails"
rails.Parent = map
local asphalt, rail, rock = Color3.fromRGB(44, 45, 50), Color3.fromRGB(172, 174, 178), Color3.fromRGB(96, 88, 78)
local EDGE = Color3.fromRGB(89, 227, 255)
local function turnBetween(i, j)
	return math.abs(math.atan2(Track.TX[i] * Track.TZ[j] - Track.TZ[i] * Track.TX[j], Track.TX[i] * Track.TX[j] + Track.TZ[i] * Track.TZ[j]))
end
local i = 1
while i <= N do
	local j = i + 1
	while j - i < 8 and j <= N and turnBetween(i, ((j - 1) % N) + 1) < math.rad(1.5) and math.abs(Track.slope(i) - Track.slope(((j - 1) % N) + 1)) < 0.01 do j += 1 end
	local jj = ((j - 1) % N) + 1
	local a, b = Vector3.new(X[i], Y[i], Z[i]), Vector3.new(X[jj], Y[jj], Z[jj])
	local mid = (a + b) / 2
	local len = (b - a).Magnitude + 1.2 + HALF * 2 * turnBetween(((j - 2) % N) + 1, jj)
	local cf = CFrame.lookAt(mid, b)
	-- a thick road slab, and no terrain from 3 studs below its surface upwards: terrain is built from 4-stud
	-- voxels and bulges over a thin part, so it must stay well clear of the road
	block(road, Vector3.new(HALF * 2, 4, len), cf * CFrame.new(0, -2, 0), asphalt, Enum.Material.Asphalt).Name = "Road"
	terrain:FillBlock(cf * CFrame.new(0, -5.5, 0), Vector3.new(HALF * 2 + 4, 4, len + 2), Enum.Material.Ground) -- no grass blades under it
	terrain:FillBlock(cf * CFrame.new(0, 13.5, 0), Vector3.new(HALF * 2 + 12, 33, len + 4), Enum.Material.Air)
	for _, side in { -1, 1 } do
		if side == junctionSide and (nearJunction(i) or nearJunction(jj)) then continue end
		local ra = a + Vector3.new(Track.RX[i], 0, Track.RZ[i]) * side * (HALF + 0.9)
		local rb = b + Vector3.new(Track.RX[jj], 0, Track.RZ[jj]) * side * (HALF + 0.9)
		local rcf = CFrame.lookAt((ra + rb) / 2, rb)
		block(rails, Vector3.new(0.5, 1.2, (rb - ra).Magnitude + 0.8), rcf * CFrame.new(0, 1.6, 0), rail, Enum.Material.DiamondPlate).Name = "Rail"
		block(rails, Vector3.new(0.4, 2.2, 0.4), CFrame.new(ra + Vector3.new(0, 1.1, 0)), Color3.fromRGB(120, 122, 126), Enum.Material.Metal).Name = "Post"
		-- glowing edge line just outside the asphalt, so the road reads at night
		local ea = a + Vector3.new(Track.RX[i], 0, Track.RZ[i]) * side * (HALF + 0.3)
		local eb = b + Vector3.new(Track.RX[jj], 0, Track.RZ[jj]) * side * (HALF + 0.3)
		local edge = block(rails, Vector3.new(0.5, 0.3, (eb - ea).Magnitude + 0.6), CFrame.lookAt((ea + eb) / 2, eb) * CFrame.new(0, -0.1, 0), EDGE, Enum.Material.Neon)
		edge.Name, edge.CanCollide, edge.CanQuery = "Edge", false, false
	end
	-- embankment below the road (hidden inside hills where the ground is high)
	if mid.Y > FLOOR + 1 then
		local flat = CFrame.lookAt(Vector3.new(mid.X, (mid.Y + FLOOR) / 2 - 1, mid.Z), Vector3.new(b.X, (mid.Y + FLOOR) / 2 - 1, b.Z))
		block(road, Vector3.new(HALF * 2 + 6, mid.Y - FLOOR, len), flat, rock, Enum.Material.Slate).Name = "Bank"
	end
	breathe()
	i = j
end
-- kerbs on the bends, dashed centre line on the straights
local roadDeco = Instance.new("Folder")
roadDeco.Name = "RoadDeco"
roadDeco.Parent = map
for k = 1, N do
	local nx = k % N + 1
	local a, b = Vector3.new(X[k], Y[k], Z[k]), Vector3.new(X[nx], Y[nx], Z[nx])
	local cf = CFrame.lookAt((a + b) / 2, b)
	local len = (b - a).Magnitude + 0.4
	if turnBetween(k, ((k + 1) % N) + 1) > math.rad(2.2) then
		for _, side in { -1, 1 } do
			local kp = block(roadDeco, Vector3.new(1.6, 0.22, len), cf * CFrame.new(side * (HALF - 0.8), 0.06, 0), (k // 1) % 2 == 0 and Color3.fromRGB(205, 36, 40) or Color3.fromRGB(236, 236, 236), Enum.Material.SmoothPlastic)
			kp.CanCollide = false
		end
	elseif k % 4 == 0 then
		local line = block(roadDeco, Vector3.new(0.45, 0.08, len * 1.6), cf * CFrame.new(0, 0.02, 0), Color3.fromRGB(240, 236, 220), Enum.Material.SmoothPlastic)
		line.CanCollide = false
	end
	if k % 200 == 0 then task.wait() end
end

-- chevron boards on the outside of the tight corners, pointing the way the road turns
local signs = Instance.new("Folder")
signs.Name = "Chevrons"
signs.Parent = map
do
	local function turnAt(k)
		local a, b = ((k - 4) % N) + 1, ((k + 2) % N) + 1
		return math.asin(math.clamp(Track.TX[a] * Track.TZ[b] - Track.TZ[a] * Track.TX[b], -1, 1))
	end
	local k, placed = 1, 0
	while k <= N do
		local t = turnAt(k)
		if 6 * Config.SEG / math.max(math.abs(t), 1e-6) < 68 and not nearJunction(k) then
			-- a tight corner starts here: boards from a little before it, every 20 studs, up to 5
			local a, b = ((k - 4) % N) + 1, ((k + 2) % N) + 1
			local inward = (Track.TX[b] - Track.TX[a]) * Track.RX[k] + (Track.TZ[b] - Track.TZ[a]) * Track.RZ[k]
			local s = if inward > 0 then 1 else -1 -- side of the road the corner turns towards
			for n = 0, 4 do
				local q = ((k - 3 + n * 2 - 1) % N) + 1
				local T = Vector3.new(Track.TX[q], 0, Track.TZ[q])
				local Rv = Vector3.new(Track.RX[q], 0, Track.RZ[q])
				local base = Vector3.new(X[q], Y[q], Z[q]) - Rv * s * (HALF + 4.5)
				local board = CFrame.lookAt(base + Vector3.new(0, 3.2, 0), base + Vector3.new(0, 3.2, 0) - T)
				block(signs, Vector3.new(0.4, 3, 0.4), CFrame.new(base + Vector3.new(0, 1.5, 0)), Color3.fromRGB(62, 64, 68), Enum.Material.Metal)
				block(signs, Vector3.new(3.6, 2.6, 0.3), board, Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic)
				local dir = if (Rv * s):Dot(board.RightVector) > 0 then 1 else -1
				for _, up in { 1, -1 } do
					local bar = block(signs, Vector3.new(1.7, 0.42, 0.12), board * CFrame.new(0, up * 0.42, -0.2) * CFrame.Angles(0, 0, -up * dir * math.rad(38)), Color3.fromRGB(255, 200, 40), Enum.Material.Neon)
					bar.CanCollide, bar.CanQuery = false, false
				end
				placed += 1
			end
			k += 14 -- skip the rest of this corner
		else
			k += 1
		end
		breathe()
	end
	signs:SetAttribute("Count", placed)
end

-- street lamps (warm sodium light)
local lamps = Instance.new("Folder")
lamps.Name = "Lamps"
lamps.Parent = map
local lampCount = 0
for k = 1, N, 18 do
	local side = (k // 18) % 2 == 0 and 1 or -1
	local base = Vector3.new(X[k] + Track.RX[k] * side * (HALF + 3), Y[k], Z[k] + Track.RZ[k] * side * (HALF + 3))
	local inward = Vector3.new(-Track.RX[k] * side, 0, -Track.RZ[k] * side)
	local pole = Color3.fromRGB(62, 64, 68)
	block(lamps, Vector3.new(0.8, 18, 0.8), CFrame.new(base + Vector3.new(0, 9, 0)), pole, Enum.Material.Metal)
	block(lamps, Vector3.new(0.5, 0.5, 6), CFrame.lookAt(base + Vector3.new(0, 18, 0) + inward * 3, base + Vector3.new(0, 18, 0) + inward * 6), pole, Enum.Material.Metal)
	local head = block(lamps, Vector3.new(2.2, 0.5, 1.2), CFrame.new(base + Vector3.new(0, 17.6, 0) + inward * 5.5), Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
	head.Name = "LampHead"
	lampCount += 1
	head:SetAttribute("N", lampCount)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 186, 112), 44, 2.4, false
	light.Parent = head
	breathe()
end

-- Kojiri village: wooden houses with lit windows and lanterns, and glowing vending machines
local village = Instance.new("Folder")
village.Name = "Village"
village.Parent = map
local wood, roofC = Color3.fromRGB(98, 68, 48), Color3.fromRGB(58, 62, 74)
local houses = 0
for k = 1, N, 9 do
	if Track.ZONE[k] == 0 then
		local side = (k // 9) % 2 == 0 and 1 or -1
		local dist = HALF + 24 + rng:NextNumber() * 10
		local c = Vector3.new(X[k] + Track.RX[k] * side * dist, Y[k], Z[k] + Track.RZ[k] * side * dist)
		if #Track.near(c.X, c.Z, HALF + 18) == 0 then
			houses += 1
			local face = CFrame.lookAt(c, c - Vector3.new(Track.RX[k] * side, 0, Track.RZ[k] * side))
			block(village, Vector3.new(30, c.Y - FLOOR + 2, 26), CFrame.new(c - Vector3.new(0, (c.Y - FLOOR + 2) / 2, 0)), Color3.fromRGB(82, 76, 68), Enum.Material.Cobblestone)
			local w, d, h = 20 + rng:NextInteger(0, 6), 14 + rng:NextInteger(0, 4), 11 + rng:NextInteger(0, 5)
			-- dark timber walls over a white plaster upper storey, on a stone plinth (a Hakone inn look)
			block(village, Vector3.new(w, h * 0.55, d), face * CFrame.new(0, h * 0.275, 0), wood, Enum.Material.WoodPlanks)
			block(village, Vector3.new(w - 0.4, h * 0.45, d - 0.4), face * CFrame.new(0, h * 0.775, 0), Color3.fromRGB(226, 220, 206), Enum.Material.Plaster)
			block(village, Vector3.new(w + 0.6, 1.4, d + 0.6), face * CFrame.new(0, 0.7, 0), Color3.fromRGB(104, 100, 94), Enum.Material.Cobblestone)
			block(village, Vector3.new(w + 1.2, 0.5, d + 1.2), face * CFrame.new(0, h * 0.55, 0), Color3.fromRGB(58, 62, 74), Enum.Material.ClayRoofTiles) -- small eave between storeys
			block(village, Vector3.new(4, 7, 0.3), face * CFrame.new(0, 3.5, -d / 2 - 0.1), Color3.fromRGB(64, 44, 32), Enum.Material.WoodPlanks) -- door
			local r1 = Instance.new("WedgePart")
			r1.Anchored, r1.Size, r1.Color, r1.Material = true, Vector3.new(w + 2, 5, d / 2 + 1), roofC, Enum.Material.ClayRoofTiles
			r1.CFrame = face * CFrame.new(0, h + 2.5, -(d / 4 + 0.5))
			r1.Parent = village
			local r2 = r1:Clone()
			r2.CFrame = face * CFrame.new(0, h + 2.5, d / 4 + 0.5) * CFrame.Angles(0, math.pi, 0)
			r2.Parent = village
			for wx = -1, 1, 2 do
				block(village, Vector3.new(3.2, 3, 0.3), face * CFrame.new(wx * w / 4, h * 0.3, -d / 2 - 0.05), Color3.fromRGB(255, 202, 128), Enum.Material.Neon).Name = "Window"
			end
			local lantern = block(village, Vector3.new(1.6, 2.2, 1.6), face * CFrame.new(0, h * 0.7, -d / 2 - 1.2), Color3.fromRGB(236, 56, 40), Enum.Material.Neon, Enum.PartType.Ball)
			lantern.Name = "Lantern"
			local pl = Instance.new("PointLight")
			pl.Color, pl.Range, pl.Brightness = Color3.fromRGB(255, 140, 90), 22, 2
			pl.Parent = lantern
			if houses % 3 == 0 then
				local vm = block(village, Vector3.new(3.6, 6, 2.4), face * CFrame.new(w / 2 + 3, 3, -d / 2 + 1), Color3.fromRGB(230, 236, 246), Enum.Material.SmoothPlastic)
				vm.Name = "Vending"
				block(village, Vector3.new(3, 3.4, 0.2), face * CFrame.new(w / 2 + 3, 3.6, -d / 2 - 0.25), Color3.fromRGB(150, 220, 255), Enum.Material.Neon).Name = "VendingFace"
			end
		end
		breathe()
	end
end

-- trees on the hillsides: cedars and autumn maples; Tier lets each player's graphics level thin them out
local trees = Instance.new("Folder")
trees.Name = "Trees"
trees.Parent = map
local placed = 0
for _, cell in hillTops do
	if placed >= 1800 then break end
	for _ = 1, 2 do
		local x, z = cell[1] + rng:NextNumber(-40, 40), cell[3] + rng:NextNumber(-40, 40)
		if #Track.near(x, z, HALF + 14) == 0 and rng:NextNumber() < 0.75 then
			local s = 0.8 + rng:NextNumber() * 0.8
			local ground = Vector3.new(x, cell[2] - 0.5, z)
			local tree = Instance.new("Model")
			tree.Name = "Tree"
			tree:SetAttribute("Tier", rng:NextInteger(1, 3))
			local maple = rng:NextNumber() < 0.22
			block(tree, Vector3.new(14 * s, 1.6 * s, 1.6 * s), CFrame.new(ground + Vector3.new(0, 7 * s, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(72, 52, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
			if maple then
				local leaf = rng:NextNumber() < 0.5 and Color3.fromRGB(180, 54, 32) or Color3.fromRGB(216, 142, 44)
				block(tree, Vector3.new(15 * s, 11 * s, 15 * s), CFrame.new(ground + Vector3.new(0, 14 * s, 0)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
				block(tree, Vector3.new(10 * s, 8 * s, 10 * s), CFrame.new(ground + Vector3.new(2 * s, 19 * s, -1 * s)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
			else
				local leaf = Color3.fromRGB(26 + rng:NextInteger(0, 14), 64 + rng:NextInteger(0, 18), 38)
				for t = 0, 2 do
					local r = (8.5 - t * 2.4) * s
					block(tree, Vector3.new(r * 2, r * 1.7, r * 2), CFrame.new(ground + Vector3.new(0, (11 + t * 6.5) * s, 0)), leaf, Enum.Material.Grass, Enum.PartType.Ball)
				end
			end
			tree.Parent = trees
			placed += 1
		end
	end
	breathe()
end

-- the start gate (torii) and Mt. Fuji on the horizon
do
	local k = 1
	local c = Vector3.new(X[k], Y[k], Z[k])
	local face = CFrame.lookAt(c, c + Vector3.new(Track.TX[k], 0, Track.TZ[k]))
	local red = Color3.fromRGB(196, 30, 34)
	for _, s in { -1, 1 } do block(map, Vector3.new(1.8, 24, 1.8), face * CFrame.new(s * (HALF + 3), 12, 0), red, Enum.Material.Wood) end
	block(map, Vector3.new(HALF * 2 + 16, 1.8, 2.6), face * CFrame.new(0, 23, 0), red, Enum.Material.Wood)
	block(map, Vector3.new(HALF * 2 + 11, 1.2, 1.8), face * CFrame.new(0, 20, 0), Color3.fromRGB(28, 28, 30), Enum.Material.Wood)
	local fuji = Instance.new("Folder")
	fuji.Name = "Fuji"
	fuji.Parent = map
	local fx, fz = Course.FUJI[1], Course.FUJI[2]
	for t = 0, 11 do
		local r = 1024 * (1 - t / 12) ^ 1.15
		local hgt = 95
		local col = if t >= 8 then Color3.fromRGB(236, 240, 246) else Color3.fromRGB(64 + t * 3, 72 + t * 3, 96 + t * 2)
		local p = block(fuji, Vector3.new(hgt, r * 2, r * 2), CFrame.new(fx, FLOOR + hgt / 2 + t * hgt, fz) * CFrame.Angles(0, 0, math.pi / 2), col, if t >= 8 then Enum.Material.Snow else Enum.Material.Rock, Enum.PartType.Cylinder)
		p.CanCollide = false
	end
end

-- Shin-Hakone city and the link road
local city = City.build({ Track = Track, rng = rng, breathe = breathe, FLOOR = FLOOR, HALF = HALF, map = map, junction = junction, junctionSide = junctionSide })
map:SetAttribute("CitySpawn", Vector3.new(city.spawn[1], city.spawn[2], city.spawn[3]))
map:SetAttribute("CityMin", Vector2.new(city.bounds[1], city.bounds[2]))
map:SetAttribute("CityMax", Vector2.new(city.bounds[3], city.bounds[4]))
map:SetAttribute("CityRing", Vector3.new(city.ring[1], city.ring[2], city.ring[3]))
map:SetAttribute("CityRing2", city.ring[4])
map:SetAttribute("CityPitch", city.grid.PITCH)
map:SetAttribute("CityStreet", city.grid.STREET)
map:SetAttribute("CityGrid", city.grid.GRID)
map:SetAttribute("Junction", junction)
print(string.format("Kaido Drift map ready: pass %d samples, city %d buildings", N, city.buildings))

map:SetAttribute("Ready", true)

-- ===================== players: progress and settings on Roblox's servers =====================
local store
pcall(function() store = DataStoreService:GetDataStore("KaidoDrift_v2") end)
local profiles, lastBank, lastLap, publicMode, dirty = {}, {}, {}, {}, {}
-- admins: the owner (or the owning group's owner), anyone listed in Config.Admins, and you in Studio.
-- Every admin action below is checked here on the server, so a hacked client can't use the panel.
local adminCache = {}
local function isAdmin(player)
	if adminCache[player] ~= nil then return adminCache[player] end
	local ok = table.find(Config.Admins, player.UserId) ~= nil
	if not ok and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId and game.CreatorId ~= 0 then ok = true end
	if not ok and game.CreatorType == Enum.CreatorType.Group then
		local okRank, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		ok = okRank and rank == 255
	end
	if not ok and RunService:IsStudio() then ok = true end
	adminCache[player] = ok
	return ok
end

-- global leaderboards (best single drift, total points banked)
local bestStore, totalStore
pcall(function()
	bestStore = DataStoreService:GetOrderedDataStore("KaidoBestDrift")
	totalStore = DataStoreService:GetOrderedDataStore("KaidoTotalPoints")
end)
local boardDirty = {}

local function newProfile()
	return { credits = 0, owned = { ps13 = true }, selected = "ps13", best = 0, laps = 0, total = 0, paint = {}, upg = {}, cos = {}, daily = nil, settings = Config.cleanSettings({}) }
end

local function stats(player, p)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		for _, n in { "Credits", "Best drift" } do
			local v = Instance.new("IntValue")
			v.Name = n
			v.Parent = ls
		end
		ls.Parent = player
	end
	ls.Credits.Value = p.credits
	ls["Best drift"].Value = p.best
end

local function load(player)
	local p = newProfile()
	if store then
		local ok, data = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(data) == "table" then
			p.credits = math.max(0, math.floor(tonumber(data.credits) or 0))
			p.best = math.max(0, math.floor(tonumber(data.best) or 0))
			p.laps = math.max(0, math.floor(tonumber(data.laps) or 0))
			if type(data.owned) == "table" then
				-- special cars come only from owning their game pass (checked below), never from saved data
				for id, v in data.owned do if v and Config.car(id).id == id and not Config.car(id).premium then p.owned[id] = true end end
			end
			if type(data.selected) == "string" then p.wantSelected = data.selected end
			if type(data.paint) == "table" then
				for id, v in data.paint do
					if Config.car(id).id == id and type(v) == "number" and v >= 0 and v <= #Config.Paints then p.paint[id] = math.floor(v) end
				end
			end
			p.settings = Config.cleanSettings(data.settings)
			p.total = math.max(0, math.floor(tonumber(data.total) or 0))
			-- upgrades and cosmetics per car, checked against the known keys and ranges
			if type(data.upg) == "table" then
				for id, u in data.upg do
					if Config.car(id).id == id and type(u) == "table" then
						local clean = {}
						for _, up in Config.Upgrades do clean[up.key] = math.clamp(math.floor(tonumber(u[up.key]) or 0), 0, Config.UPGRADE_MAX) end
						p.upg[id] = clean
					end
				end
			end
			if type(data.cos) == "table" then
				for id, c in data.cos do
					if Config.car(id).id == id and type(c) == "table" then
						p.cos[id] = {
							glowOwned = c.glowOwned == true, rimsOwned = c.rimsOwned == true, kit = c.kit == true,
							glow = math.clamp(math.floor(tonumber(c.glow) or 0), 0, #Config.GlowColors),
							rims = math.clamp(math.floor(tonumber(c.rims) or 0), 0, #Config.RimColors),
						}
					end
				end
			end
			if type(data.daily) == "table" and type(data.daily.day) == "number" and type(data.daily.prog) == "table" and type(data.daily.done) == "table" then
				p.daily = { day = data.daily.day, prog = {}, done = {} }
				for k = 1, 3 do
					p.daily.prog[k] = math.max(0, tonumber(data.daily.prog[k]) or 0)
					p.daily.done[k] = data.daily.done[k] == true
				end
			end
		end
	end
	for _, car in Config.Premium do
		if car.pass and car.pass > 0 then
			local ok, has = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, car.pass) end)
			if ok and has then p.owned[car.id] = true end
		end
	end
	if p.wantSelected and p.owned[p.wantSelected] then p.selected = p.wantSelected end
	p.wantSelected = nil
	p.admin = isAdmin(player)
	profiles[player] = p
	stats(player, p)
end

local function save(player)
	local p = profiles[player]
	if p and store then
		dirty[player] = nil
		pcall(function() store:SetAsync("p_" .. player.UserId, p) end)
	end
end

-- today's challenges for this profile (a new set each UTC day)
local function today() return os.time() // 86400 end
local function daily(p)
	local d = today()
	if not p.daily or p.daily.day ~= d then p.daily = { day = d, prog = { 0, 0, 0 }, done = { false, false, false } } end
	return p.daily
end

local function view(p)
	local owned = {}
	for id in p.owned do table.insert(owned, id) end
	local dl = daily(p)
	local list = Config.dailyFor(dl.day)
	local ch = {}
	for k, c in list do ch[k] = { text = c.text, goal = c.goal, reward = c.reward, prog = math.min(dl.prog[k], c.goal), done = dl.done[k] } end
	return { credits = p.credits, owned = owned, selected = p.selected, best = p.best, laps = p.laps, total = p.total, paint = p.paint,
		upg = p.upg, cos = p.cos, daily = ch, settings = p.settings, admin = p.admin == true }
end

Players.PlayerAdded:Connect(load)
for _, pl in Players:GetPlayers() do task.spawn(load, pl) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	local p = profiles[player]
	if p and boardDirty[player] then
		pcall(function() if bestStore then bestStore:SetAsync(tostring(player.UserId), p.best) end end)
		pcall(function() if totalStore then totalStore:SetAsync(tostring(player.UserId), p.total) end end)
	end
	boardDirty[player] = nil
	profiles[player], lastBank[player], lastLap[player], publicMode[player], dirty[player] = nil, nil, nil, nil, nil
end)
game:BindToClose(function()
	for _, pl in Players:GetPlayers() do save(pl) end
end)
task.spawn(function()
	while true do
		task.wait(60)
		for pl in dirty do if pl.Parent then save(pl) end end
	end
end)

GetProfile.OnServerInvoke = function(player)
	while not profiles[player] do task.wait(0.1) end
	return view(profiles[player])
end

Buy.OnServerInvoke = function(player, id)
	local p = profiles[player]
	if not p or type(id) ~= "string" then return nil end
	local car = Config.car(id)
	if car.id == id and not car.premium and not p.owned[id] and p.credits >= car.price then
		p.credits -= car.price
		p.owned[id] = true
		p.selected = id
		stats(player, p)
		task.spawn(save, player)
	end
	return view(p)
end

-- special cars: the client asks, Roblox shows its own purchase window with the real Robux price
BuySpecial.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" then return end
	local car = Config.car(id)
	if car.id == id and car.premium and car.pass and car.pass > 0 then
		MarketplaceService:PromptGamePassPurchase(player, car.pass)
	end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	local p = profiles[player]
	if not (p and bought) then return end
	for _, car in Config.Premium do
		if car.pass == passId then
			p.owned[car.id] = true
			p.selected = car.id
			dirty[player] = true
			ProfileChanged:FireClient(player, view(p))
		end
	end
end)

SelectCar.OnServerInvoke = function(player, id)
	local p = profiles[player]
	if p and type(id) == "string" and p.owned[id] then p.selected = id; dirty[player] = true end
	return p and view(p)
end

Paint.OnServerInvoke = function(player, id, idx)
	local p = profiles[player]
	if p and type(id) == "string" and Config.car(id).id == id and type(idx) == "number" and idx >= 0 and idx <= #Config.Paints then
		p.paint[id] = math.floor(idx)
		dirty[player] = true
	end
	return p and view(p)
end

-- garage: upgrades (next level) and cosmetics (unlock once per car, then colours are free)
Tune.OnServerInvoke = function(player, id, action, value)
	local p = profiles[player]
	if not p or type(id) ~= "string" or type(action) ~= "string" or Config.car(id).id ~= id or not p.owned[id] then return p and view(p) end
	local function pay(cost)
		if p.credits < cost then return false end
		p.credits -= cost
		stats(player, p)
		return true
	end
	p.upg[id] = p.upg[id] or {}
	p.cos[id] = p.cos[id] or { glowOwned = false, rimsOwned = false, kit = false, glow = 0, rims = 0 }
	local u, c = p.upg[id], p.cos[id]
	for _, up in Config.Upgrades do
		if action == "up_" .. up.key then
			local l = u[up.key] or 0
			if l < Config.UPGRADE_MAX and pay(up.cost[l + 1]) then u[up.key] = l + 1 end
		end
	end
	if action == "glowOwn" and not c.glowOwned and pay(Config.Cosmetics.glow.cost) then c.glowOwned = true; c.glow = 1 end
	if action == "rimsOwn" and not c.rimsOwned and pay(Config.Cosmetics.rims.cost) then c.rimsOwned = true; c.rims = 1 end
	if action == "kitOwn" and not c.kit and pay(Config.Cosmetics.kit.cost) then c.kit = true end
	if action == "kitOff" then c.kit = false end -- removing the kit is free (buy again to refit)
	if action == "glow" and c.glowOwned and type(value) == "number" then c.glow = math.clamp(math.floor(value), 0, #Config.GlowColors) end
	if action == "rims" and c.rimsOwned and type(value) == "number" then c.rims = math.clamp(math.floor(value), 1, #Config.RimColors) end
	dirty[player] = true
	task.spawn(save, player)
	return view(p)
end

SaveSettings.OnServerEvent:Connect(function(player, s)
	local p = profiles[player]
	if p then p.settings = Config.cleanSettings(s); dirty[player] = true end
end)

Erase.OnServerInvoke = function(player)
	local p = profiles[player]
	if not p then return nil end
	local keep, old = p.settings, p.owned
	p = newProfile()
	p.settings = keep
	p.admin = isAdmin(player)
	-- paid cars stay: erasing progress never takes away something bought with Robux
	for _, car in Config.Premium do if old[car.id] then p.owned[car.id] = true end end
	profiles[player] = p
	stats(player, p)
	task.spawn(save, player)
	return view(p)
end

-- a finished drift: capped, and no faster than a real drift could earn
-- daily challenge progress: kind, and how much to add (or the value reached, for "best of" kinds)
local function progress(player, p, kind, amount)
	local dl = daily(p)
	local list = Config.dailyFor(dl.day)
	local changed = false
	for k, c in list do
		if c.kind == kind and not dl.done[k] then
			if kind == "one" or kind == "combo" then dl.prog[k] = math.max(dl.prog[k], amount) else dl.prog[k] += amount end
			changed = true
			if dl.prog[k] >= c.goal then
				dl.done[k] = true
				p.credits += c.reward
				stats(player, p)
				ProfileChanged:FireClient(player, view(p), "Challenge complete  ·  " .. c.text .. "  ·  +" .. c.reward .. " CR")
			end
		end
	end
	if changed then dirty[player] = true end
end

-- the neon leaderboard gantry over the street just ahead of the city spawn
local updateNeonBoard
do
	-- the car starts facing +X along an east-west street; the gantry spans it half a block ahead
	local sx, sy, sz = city.spawn[1], city.spawn[2], city.spawn[3]
	local gx = sx + 70 -- clear of the mid-block lantern string
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboard"
	folder.Parent = map
	local steel = Color3.fromRGB(44, 46, 52)
	for _, side in { -1, 1 } do
		block(folder, Vector3.new(2.4, 40, 2.4), CFrame.new(gx, sy + 20, sz + side * 27), steel, Enum.Material.Metal).Name = "Pillar"
	end
	block(folder, Vector3.new(2.4, 2, 58), CFrame.new(gx, sy + 39, sz), steel, Enum.Material.Metal)
	local centre = Vector3.new(gx, sy + 27, sz)
	local face = block(folder, Vector3.new(50, 22, 0.8), CFrame.lookAt(centre, centre - Vector3.new(10, 0, 0)), Color3.fromRGB(10, 10, 18), Enum.Material.SmoothPlastic)
	face.Name = "BoardFace"
	face.CanCollide = false
	for _, e in { { 0, 11.2, 50.6, 0.5 }, { 0, -11.2, 50.6, 0.5 }, { 25.2, 0, 0.5, 22.8 }, { -25.2, 0, 0.5, 22.8 } } do
		local n = block(folder, Vector3.new(e[3], e[4], 1), face.CFrame * CFrame.new(e[1], e[2], 0), Color3.fromRGB(255, 126, 182), Enum.Material.Neon)
		n.CanCollide = false
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1000, 440)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = face
	local function label(text, x, y, w, h, size, color, align)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		t.Text, t.TextSize, t.TextColor3 = text, size, color
		t.Font = Enum.Font.GothamBlack
		t.TextXAlignment = align or Enum.TextXAlignment.Left
		t.Parent = gui
		return t
	end
	label("KAIDO LEADERBOARD", 0, 8, 1000, 50, 40, Color3.fromRGB(255, 126, 182), Enum.TextXAlignment.Center)
	label("BEST DRIFT", 40, 64, 440, 36, 26, Color3.fromRGB(255, 201, 77))
	label("TOTAL POINTS", 530, 64, 440, 36, 26, Color3.fromRGB(89, 227, 255))
	local rows = { best = {}, total = {} }
	for k = 1, 8 do
		for col, key in { "best", "total" } do
			local x = col == 1 and 40 or 530
			rows[key][k] = {
				label("", x, 64 + k * 40, 330, 36, 24, Color3.fromRGB(240, 238, 232)),
				label("", x + 300, 64 + k * 40, 130, 36, 24, Color3.fromRGB(240, 238, 232), Enum.TextXAlignment.Right),
			}
		end
	end
	local function commas(n)
		local s2 = tostring(math.floor(n))
		local out = s2:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end
	updateNeonBoard = function(boards)
		for _, key in { "best", "total" } do
			for k = 1, 8 do
				local e = boards[key][k]
				rows[key][k][1].Text = e and (k .. "  " .. e[1]) or ""
				rows[key][k][2].Text = e and commas(e[2]) or ""
			end
		end
	end
	updateNeonBoard({ best = {}, total = {} })
end

-- global leaderboards: best single drift and total points banked

Bank.OnServerEvent:Connect(function(player, points, zone, tandemPts, combo)
	local p = profiles[player]
	if not p or type(points) ~= "number" or points ~= points or points <= 0 then return end
	local now = os.clock()
	local since = now - (lastBank[player] or 0)
	lastBank[player] = now
	points = math.floor(math.min(points, 600000, since * 30000))
	if points <= 0 then return end
	-- one credit per ten drift points (as in the browser game), times any admin "double credits" event
	local mult = if (ReplicatedStorage:GetAttribute("KaidoMultUntil") or 0) > os.time() then (ReplicatedStorage:GetAttribute("KaidoMult") or 1) else 1
	p.credits += (points // 10) * mult
	p.best = math.max(p.best, points)
	p.total += points
	stats(player, p)
	dirty[player] = true
	boardDirty[player] = true
	progress(player, p, "one", points)
	progress(player, p, "total", points)
	if zone == "city" then progress(player, p, "city", points) elseif zone == "pass" then progress(player, p, "pass", points) end
	if type(tandemPts) == "number" and tandemPts == tandemPts and tandemPts > 0 then progress(player, p, "tandem", math.min(tandemPts, points)) end
	if type(combo) == "number" and combo == combo then progress(player, p, "combo", math.clamp(combo, 1, 5)) end
end)

-- push changed scores to the leaderboards, then read the top 10 for everyone (every 60 s)
local names = {}
local function nameOf(uid)
	if names[uid] then return names[uid] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
	names[uid] = ok and n or ("Driver " .. uid)
	return names[uid]
end
local function readBoard(store)
	local out = {}
	if not store then return out end
	local ok, pages = pcall(function() return store:GetSortedAsync(false, 10) end)
	if not ok then return out end
	for _, e in pages:GetCurrentPage() do
		local uid = tonumber(e.key)
		if uid then table.insert(out, { nameOf(uid), e.value }) end
	end
	return out
end
local function refreshBoards()
	for pl in boardDirty do
		local p = profiles[pl]
		if p then
			pcall(function() if bestStore then bestStore:SetAsync(tostring(pl.UserId), p.best) end end)
			pcall(function() if totalStore then totalStore:SetAsync(tostring(pl.UserId), p.total) end end)
		end
		boardDirty[pl] = nil
	end
	local boards = { best = readBoard(bestStore), total = readBoard(totalStore) }
	ReplicatedStorage:SetAttribute("Boards", HttpService:JSONEncode(boards))
	if updateNeonBoard then updateNeonBoard(boards) end
end
task.spawn(function()
	task.wait(5)
	while true do
		refreshBoards()
		task.wait(60)
	end
end)

-- a lap: +2,000, no more than one every 3 minutes (the record pace is well over that)
Lap.OnServerEvent:Connect(function(player)
	local p = profiles[player]
	local now = os.clock()
	if p and now - (lastLap[player] or -1e9) > 180 then
		lastLap[player] = now
		p.credits += 2000
		p.laps += 1
		stats(player, p)
		dirty[player] = true
		progress(player, p, "lap", 1)
	end
end)

-- solo players are hidden from the public map and see no one
SetMode.OnServerEvent:Connect(function(player, mode)
	publicMode[player] = mode == "public"
end)

local lastPos = {}
State.OnServerEvent:Connect(function(player, x, y, z, h, carId, paint, drifting)
	if not publicMode[player] then return end
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or type(h) ~= "number" or type(carId) ~= "string" then return end
	if x ~= x or y ~= y or z ~= z or h ~= h then return end
	lastPos[player] = { x, y, z, h }
	paint = type(paint) == "number" and math.clamp(math.floor(paint), 0, #Config.Paints) or 0
	for _, other in Players:GetPlayers() do
		if other ~= player and publicMode[other] then
			Others:FireClient(other, player.UserId, x, y, z, h, carId, paint, drifting == true)
		end
	end
end)

-- ===================== admin panel (owner only, checked on the server) =====================
-- Every action is checked here: the panel is only drawn for admins, but this is what actually protects it.
local banStore
pcall(function() banStore = DataStoreService:GetDataStore("KaidoBans_v1") end)
local bans = {} -- [userId] = { name, reason, by, untilTime (0 = forever) }
local adminLog = {}
local frozen, muted = {}, {}
local serverStart = os.time()
local setMuted
local function log(admin, text)
	table.insert(adminLog, 1, os.date("!%H:%M", os.time()) .. "  " .. admin.Name .. ": " .. text)
	if #adminLog > 60 then table.remove(adminLog) end
end
local bansLoaded = -math.huge
local function loadBans()
	if not banStore then return end
	bansLoaded = os.clock()
	local ok, data = pcall(function() return banStore:GetAsync("list") end)
	if ok and type(data) == "table" then bans = {} for k, v in data do if tonumber(k) and type(v) == "table" then bans[tonumber(k)] = v end end end
end
-- write one person's ban (or unban) into the saved list without undoing other servers' changes
local function saveBans(uid)
	if not banStore then return end
	pcall(function()
		banStore:UpdateAsync("list", function(old)
			old = type(old) == "table" and old or {}
			old[tostring(uid)] = bans[uid]
			return old
		end)
	end)
end
task.spawn(loadBans)
local function banActive(uid)
	local b = bans[uid]
	if not b then return nil end
	if b.untilTime and b.untilTime > 0 and os.time() > b.untilTime then bans[uid] = nil; return nil end
	return b
end
local function banMessage(b)
	local when = if b.untilTime and b.untilTime > 0 then ("until " .. os.date("!%d %b %H:%M UTC", b.untilTime)) else "permanently"
	return "You are banned from Kaido Drift " .. when .. ". Reason: " .. (b.reason or "none")
end
-- banned players and (when the server is locked) everyone but admins are turned away at the door
Players.PlayerAdded:Connect(function(pl)
	if os.clock() - bansLoaded > 20 then loadBans() end -- pick up bans made in other servers
	local b = banActive(pl.UserId)
	if b then pl:Kick(banMessage(b)); return end
	if ReplicatedStorage:GetAttribute("KaidoLocked") and not isAdmin(pl) then pl:Kick("This server is locked by the game owner. Try another server.") end
	if muted[pl.UserId] then task.delay(3, function() setMuted(pl, true) end) end
end)

-- chat mute through TextChatService (the player's TextSource in every channel)
setMuted = function(pl, on)
	muted[pl.UserId] = on or nil
	local ok, channels = pcall(function() return game:GetService("TextChatService"):FindFirstChild("TextChannels") end)
	if not (ok and channels) then return end
	for _, ch in channels:GetChildren() do
		for _, src in ch:GetChildren() do
			if src:IsA("TextSource") and src.UserId == pl.UserId then src.CanSend = not on end
		end
	end
end

local function playerList()
	local out = {}
	for _, pl in Players:GetPlayers() do
		local p = profiles[pl]
		local ping = 0
		pcall(function() ping = math.floor(pl:GetNetworkPing() * 1000) end)
		table.insert(out, {
			id = pl.UserId, name = pl.DisplayName .. " (@" .. pl.Name .. ")", credits = p and p.credits or 0, best = p and p.best or 0,
			car = p and Config.car(p.selected).name or "?", public = publicMode[pl] == true, ping = ping,
			frozen = frozen[pl] == true, muted = muted[pl.UserId] == true, admin = isAdmin(pl),
		})
	end
	return out
end
local function serverInfo()
	local mem, fps = 0, 0
	pcall(function() mem = math.floor(tonumber(game:GetService("Stats"):GetTotalMemoryUsageMb()) or 0) end)
	pcall(function() fps = math.floor(tonumber(workspace:GetRealPhysicsFPS()) or 0) end)
	local banList = {}
	for uid, b in bans do
		if banActive(uid) then table.insert(banList, { id = uid, name = b.name, reason = b.reason, untilTime = b.untilTime or 0, by = b.by }) end
	end
	return {
		players = #Players:GetPlayers(), maxPlayers = tonumber(Players.MaxPlayers) or 0, uptime = os.time() - serverStart, memory = mem,
		fps = fps, locked = ReplicatedStorage:GetAttribute("KaidoLocked") == true,
		mult = ReplicatedStorage:GetAttribute("KaidoMult") or 1, multUntil = ReplicatedStorage:GetAttribute("KaidoMultUntil") or 0,
		timeOverride = ReplicatedStorage:GetAttribute("KaidoTime"), jobId = game.JobId, bans = banList, log = adminLog,
	}
end
local function filtered(text, fromId, toId)
	text = string.sub(tostring(text), 1, 160)
	local ok, res = pcall(function()
		local f = TextService:FilterStringAsync(text, fromId)
		if toId then return f:GetNonChatStringForUserAsync(toId) end
		return f:GetNonChatStringForBroadcastAsync()
	end)
	return ok and res or nil
end

-- ===== every server at once, and players who aren't in this server =====
-- MessagingService carries commands to all running servers; offline players are changed in their saved data.
local MessagingService = game:GetService("MessagingService")
local TOPIC = "KaidoAdmin"
local function publish(msg)
	msg.job = game.JobId
	task.spawn(function() pcall(function() MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode(msg)) end) end)
end
local function shutdownHere(reason)
	for _, pl in Players:GetPlayers() do
		save(pl)
		task.defer(function() pl:Kick(reason) end)
	end
end
-- the changes that work on a saved profile (offline) and on a live one alike
local OFFLINE = {
	credits = function(p, v) p.credits = math.max(0, (tonumber(p.credits) or 0) + math.clamp(math.floor(tonumber(v) or 0), -1e9, 1e9)); return "Changed credits" end,
	setCredits = function(p, v) p.credits = math.clamp(math.floor(tonumber(v) or 0), 0, 1e9); return "Set credits to " .. p.credits end,
	unlockAll = function(p) p.owned = type(p.owned) == "table" and p.owned or {}; for _, c in Config.Cars do if not c.premium then p.owned[c.id] = true end end; return "Unlocked every garage car" end,
	setBest = function(p, v) p.best = math.max(0, math.floor(tonumber(v) or 0)); return "Set best drift to " .. p.best end,
	erase = function(p)
		local fresh = newProfile()
		fresh.settings, fresh.admin = p.settings or fresh.settings, p.admin
		local owned = type(p.owned) == "table" and p.owned or {}
		for _, c in Config.Premium do if owned[c.id] then fresh.owned[c.id] = true end end -- paid cars stay
		for k, v in fresh do p[k] = v end
		for k in p do if fresh[k] == nil then p[k] = nil end end
		return "Erased all progress"
	end,
}
-- apply to a player in this server, if they're here
local function applyLive(uid, op, value)
	local pl = Players:GetPlayerByUserId(uid)
	local p = pl and profiles[pl]
	if not p then return nil end
	local msg = OFFLINE[op](p, value)
	stats(pl, p); dirty[pl] = true; boardDirty[pl] = true
	ProfileChanged:FireClient(pl, view(p), nil, "admin")
	return msg
end
pcall(function()
	MessagingService:SubscribeAsync(TOPIC, function(packet)
		local ok, msg = pcall(function() return HttpService:JSONDecode(packet.Data) end)
		if not ok or type(msg) ~= "table" or msg.job == game.JobId then return end
		if msg.kind == "announce" then
			Announce:FireAllClients(tostring(msg.text), tostring(msg.from))
		elseif msg.kind == "event" then
			ReplicatedStorage:SetAttribute("KaidoMult", math.clamp(tonumber(msg.mult) or 1, 1, 10))
			ReplicatedStorage:SetAttribute("KaidoMultUntil", tonumber(msg.untilTime) or 0)
		elseif msg.kind == "shutdown" then
			shutdownHere(tostring(msg.reason))
		elseif msg.kind == "kick" then
			local pl = Players:GetPlayerByUserId(tonumber(msg.uid) or 0)
			if pl then save(pl); pl:Kick(tostring(msg.reason)) end
		elseif msg.kind == "bans" then
			loadBans()
			local pl = msg.kick and Players:GetPlayerByUserId(tonumber(msg.kick) or 0)
			local b = pl and banActive(pl.UserId)
			if b then save(pl); pl:Kick(banMessage(b)) end
		elseif msg.kind == "profile" and OFFLINE[msg.op] then
			applyLive(tonumber(msg.uid) or 0, msg.op, msg.value)
		end
	end)
end)
-- name or user ID typed in the panel -> user ID and name
local function findUser(q)
	q = string.gsub(tostring(q or ""), "^%s*@?(.-)%s*$", "%1")
	if q == "" then return nil end
	local uid = tonumber(q)
	if not uid then
		local ok, res = pcall(function() return Players:GetUserIdFromNameAsync(q) end)
		if not ok then return nil end
		uid = res
	end
	local name
	local ok = pcall(function() name = Players:GetNameFromUserIdAsync(uid) end)
	if not ok then return nil end
	return uid, name
end
local function lookup(uid, name)
	local here = Players:GetPlayerByUserId(uid)
	local data = here and profiles[here]
	if not data and store then
		local ok, res = pcall(function() return store:GetAsync("p_" .. uid) end)
		data = ok and type(res) == "table" and res or nil
	end
	local cars = 0
	if data and type(data.owned) == "table" then for _ in data.owned do cars += 1 end end
	return { id = uid, name = name, played = data ~= nil, here = here ~= nil, credits = data and tonumber(data.credits) or 0, best = data and tonumber(data.best) or 0,
		total = data and tonumber(data.total) or 0, cars = cars, banned = banActive(uid) ~= nil }
end

Admin.OnServerInvoke = function(player, action, targetId, value)
	if not isAdmin(player) then
		warn("Kaido Drift: non-admin " .. player.Name .. " tried the admin panel")
		return { ok = false, msg = "Not allowed" }
	end
	if type(action) ~= "string" then return { ok = false, msg = "Bad request" } end
	local function result(ok, msg, extra)
		local r = { ok = ok, msg = msg, players = playerList(), server = serverInfo() }
		if extra then for k, v in extra do r[k] = v end end
		return r
	end
	if action == "list" then return result(true, "") end

	-- ===== every server =====
	if action == "announceAll" then
		if type(value) ~= "string" or #value == 0 then return result(false, "Type a message first") end
		local text = filtered(value, player.UserId)
		if not text then return result(false, "Roblox's text filter didn't answer, try again") end
		Announce:FireAllClients(text, player.DisplayName)
		publish({ kind = "announce", text = text, from = player.DisplayName })
		log(player, "announced in every server: " .. text)
		return result(true, "Announced in every server")
	elseif action == "eventAll" or action == "endEventAll" then
		local mult = math.clamp(math.floor(tonumber(type(value) == "table" and value[1]) or 2), 1, 10)
		local mins = math.clamp(math.floor(tonumber(type(value) == "table" and value[2]) or 15), 1, 720)
		local untilTime = if action == "eventAll" then os.time() + mins * 60 else 0
		ReplicatedStorage:SetAttribute("KaidoMult", mult)
		ReplicatedStorage:SetAttribute("KaidoMultUntil", untilTime)
		publish({ kind = "event", mult = mult, untilTime = untilTime })
		log(player, if untilTime > 0 then string.format("started a ×%d event in every server for %d min", mult, mins) else "ended the event in every server")
		return result(true, if untilTime > 0 then string.format("×%d credits for %d minutes in every server", mult, mins) else "Event ended in every server")
	elseif action == "shutdownAll" then
		local reason = type(value) == "string" and value ~= "" and string.sub(value, 1, 80) or "Kaido Drift is updating. Rejoin in a minute!"
		publish({ kind = "shutdown", reason = reason })
		log(player, "shut down every server")
		task.delay(1, shutdownHere, reason)
		return result(true, "Shutting down every server…")

	-- ===== anyone, in any server or offline (value = { name or ID, ... }) =====
	elseif action == "find" then
		local uid, name = findUser(value)
		if not uid then return result(false, "No Roblox user called that") end
		local f = lookup(uid, name)
		return result(true, f.played and ("Found " .. name) or (name .. " has never played Kaido Drift"), { found = f })
	elseif action == "anyKick" then
		local uid = tonumber(type(value) == "table" and value[1])
		if not uid then return result(false, "Find someone first") end
		if uid == player.UserId then return result(false, "You can't kick yourself") end
		local reason = type(value[2]) == "string" and value[2] ~= "" and string.sub(value[2], 1, 80) or "Removed by the game owner"
		local pl = Players:GetPlayerByUserId(uid)
		if pl then save(pl); pl:Kick(reason) end
		publish({ kind = "kick", uid = uid, reason = reason })
		log(player, "kicked user " .. uid .. " from any server")
		return result(true, "Kicked from whichever server they're in")
	elseif action == "anyProfile" then
		-- value = { userId, op, amount }
		local uid, op, arg = tonumber(type(value) == "table" and value[1]), type(value) == "table" and value[2], type(value) == "table" and value[3] or nil
		if not uid or not OFFLINE[op] then return result(false, "Find someone first") end
		local name = "user " .. uid
		pcall(function() name = Players:GetNameFromUserIdAsync(uid) end)
		local msg = applyLive(uid, op, arg)
		if not msg then
			-- tell their server if they're playing somewhere else, and change their saved data too
			publish({ kind = "profile", uid = uid, op = op, value = arg })
			if not store then return result(false, "Saving isn't available (turn on API access in Game Settings › Security)") end
			local ok, err = pcall(function()
				store:UpdateAsync("p_" .. uid, function(old)
					local p = type(old) == "table" and old or newProfile()
					msg = OFFLINE[op](p, arg)
					return p
				end)
			end)
			if not ok then return result(false, "Couldn't save: " .. tostring(err)) end
		end
		if op == "erase" then
			pcall(function() if bestStore then bestStore:RemoveAsync(tostring(uid)) end end)
			pcall(function() if totalStore then totalStore:RemoveAsync(tostring(uid)) end end)
		elseif op == "setBest" then
			pcall(function() if bestStore then bestStore:SetAsync(tostring(uid), math.max(0, math.floor(tonumber(arg) or 0))) end end)
		end
		log(player, tostring(msg) .. " (" .. name .. ", any server)")
		return result(true, tostring(msg) .. " for " .. name, { found = lookup(uid, name) })
	end

	-- ===== whole server =====
	if action == "announce" then
		if type(value) ~= "string" or #value == 0 then return result(false, "Type a message first") end
		local text = filtered(value, player.UserId)
		if not text then return result(false, "Roblox's text filter didn't answer, try again") end
		Announce:FireAllClients(text, player.DisplayName)
		log(player, "announced: " .. text)
		return result(true, "Announced to everyone")
	elseif action == "giveAll" then
		local n = math.clamp(math.floor(tonumber(value) or 0), -10000000, 10000000)
		for pl, p in profiles do
			p.credits = math.max(0, p.credits + n); stats(pl, p); dirty[pl] = true
			ProfileChanged:FireClient(pl, view(p), nil, "admin")
		end
		log(player, string.format("gave everyone %d CR", n))
		return result(true, string.format("Gave everyone %d CR", n))
	elseif action == "event" then
		-- value = { mult, minutes }
		local mult = math.clamp(math.floor(tonumber(type(value) == "table" and value[1]) or 2), 1, 10)
		local mins = math.clamp(math.floor(tonumber(type(value) == "table" and value[2]) or 15), 1, 720)
		ReplicatedStorage:SetAttribute("KaidoMult", mult)
		ReplicatedStorage:SetAttribute("KaidoMultUntil", os.time() + mins * 60)
		log(player, string.format("started a ×%d credits event for %d min", mult, mins))
		return result(true, string.format("×%d credits for %d minutes, for everyone", mult, mins))
	elseif action == "endEvent" then
		ReplicatedStorage:SetAttribute("KaidoMultUntil", 0)
		log(player, "ended the credits event")
		return result(true, "Credits event ended")
	elseif action == "time" then
		local t = tonumber(value)
		ReplicatedStorage:SetAttribute("KaidoTime", if t then math.clamp(t, 0, 23.99) else nil)
		log(player, t and ("set everyone's time to " .. t) or "gave everyone their own time back")
		return result(true, t and "Time of day set for everyone" or "Everyone's own time of day is back")
	elseif action == "tpAll" then
		local where = if value == "pass" then "pass" else "city"
		for _, pl in Players:GetPlayers() do AdminEvent:FireClient(pl, "send", where) end
		log(player, "sent everyone to the " .. where)
		return result(true, "Sent everyone to the " .. where)
	elseif action == "freezeAll" then
		for _, pl in Players:GetPlayers() do if pl ~= player then frozen[pl] = value == true; AdminEvent:FireClient(pl, "freeze", value == true) end end
		log(player, value and "froze everyone" or "unfroze everyone")
		return result(true, value and "Everyone else is frozen" or "Everyone is unfrozen")
	elseif action == "lock" then
		ReplicatedStorage:SetAttribute("KaidoLocked", value == true)
		log(player, value and "locked the server" or "unlocked the server")
		return result(true, value and "Server locked: only admins can join" or "Server unlocked")
	elseif action == "kickAll" or action == "shutdown" then
		local reason = type(value) == "string" and value ~= "" and string.sub(value, 1, 80) or (action == "shutdown" and "The server was shut down by the game owner. Rejoin to play!" or "Removed by the game owner")
		for _, pl in Players:GetPlayers() do
			if pl ~= player or action == "shutdown" then
				if pl ~= player then save(pl) end
				task.defer(function() pl:Kick(reason) end)
			end
		end
		if action == "shutdown" then save(player) end
		log(player, action == "shutdown" and "shut the server down" or "kicked everyone")
		return result(true, action == "shutdown" and "Shutting down…" or "Kicked everyone else")
	elseif action == "unban" then
		local uid = tonumber(value)
		if uid and bans[uid] then
			log(player, "unbanned " .. tostring(bans[uid].name))
			bans[uid] = nil; saveBans(uid); publish({ kind = "bans" })
			return result(true, "Unbanned")
		end
		return result(false, "Not on the ban list")
	elseif action == "banId" then
		-- ban someone who isn't in this server, by user ID
		local uid = tonumber(type(value) == "table" and value[1])
		if not uid or uid <= 0 then return result(false, "Type a user ID") end
		if uid == player.UserId then return result(false, "You can't ban yourself") end
		local hours = tonumber(value[3]) or 0
		local name = "user " .. uid
		pcall(function() name = Players:GetNameFromUserIdAsync(uid) end)
		bans[uid] = { name = name, reason = tostring(value[2] or "Banned"):sub(1, 80), by = player.Name, untilTime = if hours > 0 then os.time() + hours * 3600 else 0 }
		saveBans(uid)
		publish({ kind = "bans", kick = uid })
		local pl = Players:GetPlayerByUserId(uid)
		if pl then pl:Kick(banMessage(bans[uid])) end
		log(player, "banned " .. name)
		return result(true, "Banned " .. name)
	end

	-- ===== one player =====
	local target = type(targetId) == "number" and Players:GetPlayerByUserId(targetId) or nil
	local tp = target and profiles[target]
	if not (target and tp) then return result(false, "Pick a player first") end
	local function done(msg)
		stats(target, tp)
		dirty[target] = true
		ProfileChanged:FireClient(target, view(tp), nil, "admin")
		log(player, msg .. " (" .. target.Name .. ")")
		return result(true, msg)
	end
	if action == "credits" then
		local n = math.clamp(math.floor(tonumber(value) or 0), -10000000, 10000000)
		tp.credits = math.max(0, tp.credits + n)
		return done(string.format("%s %d CR", n >= 0 and "Gave" or "Took", math.abs(n)))
	elseif action == "setCredits" then
		tp.credits = math.clamp(math.floor(tonumber(value) or 0), 0, 1000000000)
		return done("Set credits to " .. tp.credits)
	elseif action == "unlockAll" then
		for _, c in Config.Cars do if not c.premium then tp.owned[c.id] = true end end
		return done("Unlocked every garage car")
	elseif action == "giveCar" or action == "removeCar" or action == "setCar" then
		local c = type(value) == "string" and Config.car(value)
		if not c or c.id ~= value then return result(false, "Unknown car") end
		if action == "giveCar" then tp.owned[c.id] = true; return done("Gave " .. c.name) end
		if action == "removeCar" then
			if c.id == "ps13" then return result(false, "Everyone keeps the starter car") end
			tp.owned[c.id] = nil
			if tp.selected == c.id then tp.selected = "ps13" end
			return done("Took away " .. c.name)
		end
		tp.owned[c.id] = true; tp.selected = c.id
		return done("Put them in the " .. c.name)
	elseif action == "maxUpgrades" or action == "resetUpgrades" then
		local u = {}
		for _, up in Config.Upgrades do u[up.key] = if action == "maxUpgrades" then Config.UPGRADE_MAX else 0 end
		tp.upg[tp.selected] = u
		return done((action == "maxUpgrades" and "Maxed" or "Reset") .. " the upgrades on " .. Config.car(tp.selected).name)
	elseif action == "resetChallenges" then
		tp.daily = nil
		return done("Today's challenges reset")
	elseif action == "completeChallenges" then
		local dl = daily(tp)
		for k, c in Config.dailyFor(dl.day) do
			if not dl.done[k] then dl.done[k] = true; dl.prog[k] = c.goal; tp.credits += c.reward end
		end
		return done("Completed today's challenges (rewards paid)")
	elseif action == "setBest" then
		tp.best = math.max(0, math.floor(tonumber(value) or 0)); boardDirty[target] = true
		return done("Set best drift to " .. tp.best)
	elseif action == "removeFromBoards" then
		pcall(function() if bestStore then bestStore:RemoveAsync(tostring(target.UserId)) end end)
		pcall(function() if totalStore then totalStore:RemoveAsync(tostring(target.UserId)) end end)
		tp.best, tp.total = 0, 0
		boardDirty[target] = nil
		return done("Removed from the leaderboards")
	elseif action == "erase" then
		local keepSettings, keepOwned, keepAdmin = tp.settings, tp.owned, tp.admin
		local fresh = newProfile()
		fresh.settings, fresh.admin = keepSettings, keepAdmin
		for _, c in Config.Premium do if keepOwned[c.id] then fresh.owned[c.id] = true end end -- paid cars stay
		for k, v in fresh do tp[k] = v end
		for k in tp do if fresh[k] == nil then tp[k] = nil end end
		return done("Erased all progress")
	elseif action == "goto" then
		local pos = lastPos[target]
		if not pos then return result(false, "They need to be on the public map") end
		log(player, "teleported to " .. target.Name)
		return result(true, "Teleported to " .. target.DisplayName, { pos = pos })
	elseif action == "bring" then
		-- value = the admin's own position { x, y, z, h }
		if type(value) ~= "table" then return result(false, "Bad position") end
		local x, y, z, h = tonumber(value[1]), tonumber(value[2]), tonumber(value[3]), tonumber(value[4]) or 0
		if not (x and y and z) or x ~= x or y ~= y or z ~= z then return result(false, "Bad position") end
		AdminEvent:FireClient(target, "tp", x + 14, y, z, h)
		log(player, "brought " .. target.Name)
		return result(true, "Brought " .. target.DisplayName .. " to you")
	elseif action == "send" then
		local where = if value == "pass" then "pass" else "city"
		AdminEvent:FireClient(target, "send", where)
		log(player, "sent " .. target.Name .. " to the " .. where)
		return result(true, "Sent " .. target.DisplayName .. " to the " .. where)
	elseif action == "freeze" then
		if target == player then return result(false, "You can't freeze yourself") end
		frozen[target] = value == true
		AdminEvent:FireClient(target, "freeze", value == true)
		log(player, (value and "froze " or "unfroze ") .. target.Name)
		return result(true, (value and "Froze " or "Unfroze ") .. target.DisplayName)
	elseif action == "mute" then
		if target == player then return result(false, "You can't mute yourself") end
		setMuted(target, value == true)
		log(player, (value and "muted " or "unmuted ") .. target.Name)
		return result(true, (value and "Muted " or "Unmuted ") .. target.DisplayName .. " in chat")
	elseif action == "message" then
		if type(value) ~= "string" or #value == 0 then return result(false, "Type a message first") end
		local text = filtered(value, player.UserId, target.UserId)
		if not text then return result(false, "Roblox's text filter didn't answer, try again") end
		AdminEvent:FireClient(target, "message", text, player.DisplayName)
		log(player, "messaged " .. target.Name .. ": " .. text)
		return result(true, "Message sent to " .. target.DisplayName)
	elseif action == "kick" then
		if target == player then return result(false, "You can't kick yourself") end
		local reason = type(value) == "string" and value ~= "" and string.sub(value, 1, 80) or "Removed by the game owner"
		save(target)
		target:Kick(reason)
		log(player, "kicked " .. target.Name .. ": " .. reason)
		return result(true, "Kicked " .. target.DisplayName)
	elseif action == "ban" then
		-- value = { reason, hours (0 = forever) }
		if target == player then return result(false, "You can't ban yourself") end
		if isAdmin(target) then return result(false, "Admins can't be banned") end
		local reason = type(value) == "table" and tostring(value[1] or "") or ""
		if reason == "" then reason = "Banned by the game owner" end
		local hours = tonumber(type(value) == "table" and value[2]) or 0
		bans[target.UserId] = { name = target.Name, reason = reason:sub(1, 80), by = player.Name, untilTime = if hours > 0 then os.time() + hours * 3600 else 0 }
		saveBans(target.UserId)
		publish({ kind = "bans" })
		save(target)
		target:Kick(banMessage(bans[target.UserId]))
		log(player, "banned " .. target.Name .. (hours > 0 and (" for " .. hours .. "h") or " forever") .. ": " .. reason)
		return result(true, "Banned " .. target.DisplayName)
	end
	return result(false, "Unknown action")
end
Players.PlayerRemoving:Connect(function(pl) adminCache[pl], lastPos[pl], frozen[pl] = nil, nil, nil end)

end)()
end

local map = workspace:FindFirstChild("KaidoMap")
local RSm = game:GetService("ReplicatedStorage")
local rem = RSm:FindFirstChild("KaidoRemotes")
local pl = Instance.new("Player"); pl.UserId = 77; pl.Name = "Tester"
local plrs = game:GetService("Players")
plrs.PlayerAdded:Fire(pl)
local function inv(name, ...) local f = rawget(rem:FindFirstChild(name), "OnServerInvoke"); return f(pl, ...) end
local function fire(name, ...) rem:FindFirstChild(name).OnServerEvent:Fire(pl, ...) end
local v = inv("GetProfile")
print("profile credits", v.credits, "daily", v.daily[1].text, v.daily[2].text, v.daily[3].text)
os_clock_base = 0
fire("Bank", 30000, "city", 5000, 3)
v = inv("GetProfile")
print("after bank credits", v.credits, "total", v.total, "prog", v.daily[1].prog, v.daily[2].prog, v.daily[3].prog)
v = inv("Tune", "ps13", "up_engine")
print("engine upgrade, credits", v.credits, "engine lvl", v.upg.ps13 and v.upg.ps13.engine)
v = inv("Tune", "ps13", "glowOwn"); print("glow owned", v.cos.ps13.glowOwned, v.cos.ps13.glow, "credits", v.credits)
v = inv("Tune", "ps13", "glow", 3); print("glow colour", v.cos.ps13.glow)
v = inv("Tune", "r34", "up_engine"); print("not-owned car upgrade blocked:", v.upg.r34 == nil)
fire("Lap")
plrs.PlayerRemoving:Fire(pl)
print("READY", map and map:GetAttribute("Ready"), "parts", PARTS, "fills", FILLS)
for _, b in SIZEBAD do print("TOO BIG", b) end
for _, k in { "CitySpawn", "CityMin", "CityMax", "Junction" } do print(k, map and map:GetAttribute(k)) end
