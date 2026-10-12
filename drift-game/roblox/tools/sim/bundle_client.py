import sys, pathlib
root = pathlib.Path(sys.argv[1])
shared = ["Config", "Cars", "Track", "CourseData", "CarPhysics", "SoundIds", "CarModel"]
client = ["Ui", "Audio", "CarMesh", "Fx", "World"]
out = [open("prelude.luau").read()]
out.append('''
local __src, __cache = {}, {}
local function require(m)
	local id = rawget(m, "__mod")
	assert(id, "require of a non-module: " .. tostring(m.Name))
	if __cache[id] == nil then __cache[id] = __src[id](m) end
	return __cache[id]
end
local _new = Instance.new
Instance.new = function(class, parent)
	local o = _new(class, parent)
	if class:match("Gui$") or class:match("Frame$") or class:match("^Text") or class:match("^Image") or class == "CanvasGroup" then
		rawset(o, "AbsoluteSize", Vector2.new(1280, 720)); rawset(o, "AbsolutePosition", Vector2.new(0, 0))
	end
	return o
end
local RS = game:GetService("ReplicatedStorage")
local SharedF = Instance.new("Folder"); SharedF.Name = "Shared"; SharedF.Parent = RS
local meshes = Instance.new("Folder"); meshes.Name = "CarMeshes"; meshes.Parent = SharedF
local SSS = game:GetService("ServerScriptService")
local ServerF = Instance.new("Folder"); ServerF.Name = "KaidoServer"; ServerF.Parent = SSS
local ClientF = Instance.new("Folder"); ClientF.Name = "KaidoClient"
local function mod(name, parent) local m = Instance.new("ModuleScript"); m.Name = name; rawset(m, "__mod", name); m.Parent = parent; return m end
''')
for n in shared: out.append(f'mod("{n}", SharedF)\n')
out.append('mod("City", ServerF)\n')
for n in client: out.append(f'mod("{n}", ClientF)\n')
for n in shared:
    out.append(f'__src["{n}"] = function(script)\n{(root/"src/shared"/f"{n}.luau").read_text()}\nend\n')
out.append('__src["City"] = function(script)\n' + (root/"src/server/City.luau").read_text() + '\nend\n')
for n in client:
    out.append(f'__src["{n}"] = function(script)\n{(root/"src/client"/f"{n}.luau").read_text()}\nend\n')
out.append(open("server_env.luau").read())
for n in ["Watchdog", "Main"]:
    out.append(f'do\nlocal script = Instance.new("Script"); script.Name = "{n}"; script.Parent = ServerF\n;(function()\n{(root/f"src/server/{n}.server.luau").read_text()}\nend)()\nend\n')
out.append(open("client_env.luau").read())
out.append('do\nlocal script = Instance.new("LocalScript"); script.Name = "Main"; script.Parent = ClientF\n;(function()\n' + (root/"src/client/Main.client.luau").read_text() + '\nend)()\nend\n')
out.append(open("client_drive.luau").read())
txt = "".join(out)
a = "\t\tFx.tandem(tandemWith and m.PrimaryPart or nil"
txt = txt.replace(a, "\t\tMYPOS = Vector3.new(X, posY, Z); DBG_T = { P.drifting, tandem }; DBG_MAX = math.max(DBG_MAX or 0, tandem); if P.drifting then DBG_DF = (DBG_DF or 0) + 1 end; if tandemWith then DBG_LINK = true end\n" + a, 1)
txt = txt.replace('print("tandem link beams on:"', 'print("DBG max tandem", DBG_MAX, "drift frames", DBG_DF, "linked", DBG_LINK); print("tandem link beams on:"')
open("bundle_client.luau", "w").write(txt)
