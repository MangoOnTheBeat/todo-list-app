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
function methods.Destroy(self) end
function methods.Clone(self) local o = inst(self.ClassName, self.Name); for k, v in self do if k ~= "__kids" and k ~= "__attr" and k ~= "Parent" then rawset(o, k, v) end end; if o.ClassName == "Part" or o.ClassName == "WedgePart" then PARTS += 1 end; for _, c in self.__kids do c:Clone().Parent = o end; return o end
function methods.FillBlock(self, c, size, mat) FILLS += 1; assert(getmetatable(c) == CF and getmetatable(size) == V and type(mat) == "string", "bad FillBlock args") end
function methods.FillBall() end
function methods.FillCylinder() end
function methods.FillWedge() end
LOCALPLAYER = nil
function methods.InvokeServer(self, ...) return rawget(self, "OnServerInvoke")(LOCALPLAYER, ...) end
function methods.FireServer(self, ...) self.OnServerEvent:Fire(LOCALPLAYER, ...) end
function methods.FireClient(self, pl, ...) self.OnClientEvent:Fire(...) end
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
