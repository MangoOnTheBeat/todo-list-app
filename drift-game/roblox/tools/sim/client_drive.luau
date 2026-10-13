-- ===== drive the client like a player =====
local RunS = game:GetService("RunService")
local function frames(n) for _ = 1, n do RunS.RenderStepped:Fire(1 / 60) end end
local gui = pg
local function findButton(label)
	label = string.lower(label)
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextLabel" or d.ClassName == "TextButton" then
			local t = rawget(d, "Text")
			if type(t) == "string" and string.find(string.lower(t), label, 1, true) then
				local b = d
				while b and b.ClassName ~= "TextButton" do b = rawget(b, "__parent") end
				if b then return b end
			end
		end
	end
	error("no button: " .. label)
end
local function click(label) findButton(label).Activated:Fire(); print("clicked", label) end
local function key(k) UIS.InputBegan:Fire({ KeyCode = "Enum.KeyCode." .. k, UserInputType = "Enum.UserInputType.Keyboard" }, false) end
frames(20)
click("Play solo")
frames(60)
KEYS["Enum.KeyCode.W"] = true
frames(240)
KEYS["Enum.KeyCode.D"] = true
KEYS["Enum.KeyCode.Space"] = true
frames(20)
KEYS["Enum.KeyCode.Space"] = nil
frames(400)
KEYS["Enum.KeyCode.D"] = nil; KEYS["Enum.KeyCode.A"] = true
frames(200)
KEYS["Enum.KeyCode.A"] = nil; KEYS["Enum.KeyCode.W"] = nil
frames(200)
local rem = RS:FindFirstChild("KaidoRemotes")
local pr = rem:FindFirstChild("GetProfile"):InvokeServer()
local skids = 0
for _, p in workspace:FindFirstChild("KaidoSkids").__kids do if rawget(p, "Size") then skids += 1 end end
local snds = {}
for _, d in game:GetService("SoundService").__kids do if d.ClassName == "Sound" and rawget(d, "SoundId") and d.SoundId ~= "" then table.insert(snds, d.Name .. "=" .. d.SoundId .. " vol " .. string.format("%.2f", rawget(d, "Volume") or 0)) end end
print("own car sounds:", table.concat(snds, ", "))
print("driving ok · server credits", pr.credits, "total points", pr.total, "best", pr.best, "skid marks laid", skids)
key("Escape"); frames(10)
click("Photo mode"); frames(30)
UIS.InputChanged:Fire({ UserInputType = "Enum.UserInputType.MouseWheel", Position = Vector3.new(0, 0, 1), Delta = Vector3.new(0, 0, 0) }, false)
click("Done"); frames(10)
click("Garage"); frames(30)
click("Engine"); frames(10)
click("Remove stance kit"); frames(10); click("Fit stance kit"); frames(10)
click("Back"); frames(10)
click("Main menu"); frames(10)
click("Leaderboards"); frames(10)
click("Back"); frames(10)
click("Settings"); frames(10)
pr = rem:FindFirstChild("GetProfile"):InvokeServer()
print("after garage: credits", pr.credits, "engine", pr.upg.ps13 and pr.upg.ps13.engine, "glow", pr.cos.ps13 and pr.cos.ps13.glowOwned)
-- tandem: a second driver sliding right next to us on the public map
click("Back"); frames(5)
click("Play with others"); frames(30)
KEYS["Enum.KeyCode.W"] = true; frames(200); KEYS["Enum.KeyCode.D"] = true; KEYS["Enum.KeyCode.Space"] = true; frames(15); KEYS["Enum.KeyCode.Space"] = nil
local others = rem:FindFirstChild("Others")
local beams = 0
for i = 1, 300 do
	local me = MYPOS or Vector3.zero
	others.OnClientEvent:Fire(99, me.X + 8, me.Y, me.Z + 3, 0, "ae8", 0, true)
	frames(1)
end
for _, d in workspace:FindFirstChild("MyCar"):GetDescendants() do if d.ClassName == "Beam" and rawget(d, "Enabled") then beams += 1 end end
print("tandem link beams on:", beams, "ghost exists:", workspace:FindFirstChild("Driver99") ~= nil)
for _, d in gui:GetDescendants() do local t = rawget(d, "Text"); if type(t) == "string" and (t:find("TANDEM") or t:find("ANGLE")) then print("tag:", t) end end
local myc = workspace:FindFirstChild("MyCar")
for _, d in myc.PrimaryPart.__kids do print("root child", d.ClassName, d.Name) end
-- admin panel: owner gives themself credits through the UI
local function clickExact(label)
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextButton" and rawget(d, "Text") == label then d.Activated:Fire(); print("clicked", label); return end
	end
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextLabel" and rawget(d, "Text") == label then
			local b = d
			while b and b.ClassName ~= "TextButton" do b = rawget(b, "__parent") end
			if b then b.Activated:Fire(); print("clicked", label); return end
		end
	end
	error("no exact button: " .. label)
end
local function typeInto(placeholderStart, value)
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextBox" and rawget(d, "PlaceholderText") and string.find(d.PlaceholderText, placeholderStart, 1, true) then d.Text = value; return end
	end
	error("no box: " .. placeholderStart)
end
key("F2"); frames(5)
for _, d in gui:GetDescendants() do local t = rawget(d, "Text"); if type(t) == "string" and (t:find("Players in") or t:find("Only you") or t:find("Working") or t:find("PLAYERS IN") or t:find("No answer")) then print("PANEL:", t) end end
typeInto("Amount, e.g. 50000", "50000")
local before = rem:FindFirstChild("GetProfile"):InvokeServer().credits
clickExact("Give"); frames(5)
local after = rem:FindFirstChild("GetProfile"):InvokeServer().credits
print("admin give credits:", before, "->", after)
clickExact("Unlock all garage cars"); frames(5)
print("owned after unlock:", #rem:FindFirstChild("GetProfile"):InvokeServer().owned)
clickExact("Max upgrades"); frames(5)
print("upgrades:", rem:FindFirstChild("GetProfile"):InvokeServer().upg.ps13.engine)
-- server tab: announcement shows the banner
clickExact("Server"); frames(3)
typeInto("Message (filtered", "Drift event at the city in 5 minutes!")
clickExact("Send announcement"); frames(3)
local bannerShown = false
for _, d in gui:GetDescendants() do if d.ClassName == "TextLabel" and rawget(d, "Text") == "ANNOUNCEMENT" and rawget(d.__parent, "Visible") then bannerShown = true end end
print("announcement banner visible:", bannerShown)
clickExact("×2"); clickExact("Start credits event"); frames(3)
print("credits event mult:", RS:GetAttribute("KaidoMult"), "running:", (RS:GetAttribute("KaidoMultUntil") or 0) > os.time())
clickExact("Noon"); frames(3)
print("forced time:", RS:GetAttribute("KaidoTime"))
-- me tab: ghost mode + boost, then drive
clickExact("Me"); frames(3)
clickExact("Ghost mode: off"); clickExact("Speed boost: off"); frames(3)
click("Back"); frames(5)
KEYS["Enum.KeyCode.W"] = true; frames(120); KEYS["Enum.KeyCode.W"] = nil
print("drove with ghost mode + boost")
-- a cheater (not the owner) calling the admin remote directly
local cheater = Instance.new("Player"); cheater.Name = "Cheater"; cheater.UserId = 88
table.insert(PLAYERS, cheater)
game:GetService("Players").PlayerAdded:Fire(cheater)
local res = rawget(rem:FindFirstChild("Admin"), "OnServerInvoke")(cheater, "credits", 88, 999999)
print("cheater admin call:", res.ok, res.msg)
print("cheater sees admin flag:", rawget(rem:FindFirstChild("GetProfile"), "OnServerInvoke")(cheater).admin)
-- ===== multiplayer: a burst of updates (as after a hitch) must not stack copies of one car =====
click("Play with others"); frames(10)
local function count(name) local n = 0 for _, m in workspace:GetChildren() do if m.Name == name then n += 1 end end return n end
for i = 1, 120 do others.OnClientEvent:Fire(55, 10 + i, 6, 10, 0, "jza", 0, i % 2 == 0) end
frames(3)
print("cars for driver 55 after 120 updates:", count("Driver55"))
others.OnClientEvent:Fire(55, 10, 6, 10, 0, "jza", 2, false); frames(3)
print("cars for driver 55 after a repaint:", count("Driver55"))
print("my cars:", count("MyCar"))
local ghostSounds, ourId = 0, nil
for _, d in workspace:GetDescendants() do
	if d.ClassName == "Sound" and d.Name == "kaido_engine_low" then ghostSounds += 1; ourId = rawget(d, "SoundId") end
end
print("ghost engine sounds:", ghostSounds, "low layer stays empty in simple mode:", ourId == "")
-- a crowd: only the nearest two make engine noise
for uid = 200, 205 do others.OnClientEvent:Fire(uid, 30 * (uid - 199), 6, 10, 0, "ae8", 0, false) end
frames(3)
local mids = 0
for _, d in workspace:GetDescendants() do if d.ClassName == "Sound" and d.Name == "kaido_engine_mid" then mids += 1 end end
print("engine sounds with 7 drivers around:", mids)
-- ===== admin: anyone, in any server or offline =====
local plrs = game:GetService("Players")
rawset(plrs, "GetUserIdFromNameAsync", function(_, n) if n == "OfflineFriend" then return 4242 end error("no user") end)
rawset(plrs, "GetNameFromUserIdAsync", function(_, id) return if id == 4242 then "OfflineFriend" else "user" .. id end)
key("F2"); frames(5)
clickExact("Anywhere"); frames(3)
typeInto("Their username", "OfflineFriend"); clickExact("Find"); frames(3)
local found = false
for _, d in gui:GetDescendants() do local t = rawget(d, "Text"); if type(t) == "string" and t:find("OfflineFriend  ·  ID 4242", 1, true) then found = true end end
print("found offline player:", found)
typeInto("Amount, e.g. 50000", "12345"); clickExact("Set credits"); frames(3)
for _, d in gui:GetDescendants() do local t = rawget(d, "Text"); if type(t) == "string" and (t:find("12345") or t:find("Couldn") or t:find("Find someone") or t:find("for OfflineFriend")) then print("UI:", d.ClassName, t) end end
print("offline credits saved:", STORES.KaidoDrift_v2.p_4242 and STORES.KaidoDrift_v2.p_4242.credits)
local realDelay = task.delay; task.delay = function() end -- keep the "tap again" confirm armed
clickExact("Ban forever"); clickExact("Tap again to confirm"); frames(3)
task.delay = realDelay
for _, d in gui:GetDescendants() do local t = rawget(d, "Text"); if type(t) == "string" and (t:find("Banned") or t:find("ban")) then print("UI:", d.ClassName, t) end end
print("offline ban saved:", STORES.KaidoBans_v1.list and STORES.KaidoBans_v1.list["4242"] ~= nil)
typeInto("Message (filtered", "Server restart soon"); clickExact("Announce everywhere"); frames(3)
clickExact("Start everywhere"); frames(3)
print("event everywhere running:", (RS:GetAttribute("KaidoMultUntil") or 0) > os.time())
print("CLIENT SIM OK")
