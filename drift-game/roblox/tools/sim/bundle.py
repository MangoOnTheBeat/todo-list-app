import sys, os, pathlib
root = pathlib.Path(sys.argv[1])
shared = ["Config", "Cars", "Track", "CourseData", "CarPhysics", "SoundIds"]
out = [open("prelude.luau").read()]
out.append('''
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
''')
for n in shared:
    out.append(f'mod("{n}", SharedF)\n')
out.append('mod("City", ServerF)\n')
for n in shared:
    src = (root / "src/shared" / f"{n}.luau").read_text()
    out.append(f'__src["{n}"] = function(script)\n{src}\nend\n')
out.append('__src["City"] = function(script)\n' + (root / "src/server/City.luau").read_text() + '\nend\n')
for n in ["Watchdog", "Main"]:
    src = (root / f"src/server/{n}.server.luau").read_text()
    out.append(f'do\nlocal script = Instance.new("Script"); script.Name = "{n}"; script.Parent = ServerF\n;(function()\n{src}\nend)()\nend\n')
out.append('''
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
''')
open("bundle.luau", "w").write("".join(out))
