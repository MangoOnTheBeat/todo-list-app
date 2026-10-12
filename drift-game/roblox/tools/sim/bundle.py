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
print("READY", map and map:GetAttribute("Ready"), "parts", PARTS, "fills", FILLS)
for _, b in SIZEBAD do print("TOO BIG", b) end
for _, k in { "CitySpawn", "CityMin", "CityMax", "Junction" } do print(k, map and map:GetAttribute(k)) end
''')
open("bundle.luau", "w").write("".join(out))
