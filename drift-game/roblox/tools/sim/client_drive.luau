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
key("F2"); frames(5)
for _, d in gui:GetDescendants() do if d.ClassName == "TextBox" and rawget(d, "PlaceholderText") and string.find(d.PlaceholderText, "Amount") then d.Text = "50000" end end
local before = rem:FindFirstChild("GetProfile"):InvokeServer().credits
click("Give credits"); frames(5)
local after = rem:FindFirstChild("GetProfile"):InvokeServer().credits
print("admin give credits:", before, "->", after)
click("Unlock every garage car"); frames(5)
print("owned after unlock:", #rem:FindFirstChild("GetProfile"):InvokeServer().owned)
-- a cheater (not the owner) calling the admin remote directly
local cheater = Instance.new("Player"); cheater.Name = "Cheater"; cheater.UserId = 88
game:GetService("Players").PlayerAdded:Fire(cheater)
local res = rawget(rem:FindFirstChild("Admin"), "OnServerInvoke")(cheater, "credits", 88, 999999)
print("cheater admin call:", res.ok, res.msg)
print("cheater sees admin flag:", rawget(rem:FindFirstChild("GetProfile"), "OnServerInvoke")(cheater).admin)
print("CLIENT SIM OK")
