-- Kaido Drift admin panel (only drawn for admins; the server re-checks every action).
-- Tabs: Players (everything for one player), Server (everyone at once), Bans, Log, Me (your own tools).
-- Also owns the announcement banner and the credits-event pill that every player sees.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminPanel = {}

function AdminPanel.init(ctx)
	local Ui, R, U, gui, player, Config = ctx.Ui, ctx.R, ctx.U, ctx.gui, ctx.player, ctx.Config
	local make, text, fmt = Ui.make, Ui.text, Ui.fmt
	local self = {}

	-- ===================== banner (announcements, private messages) for everyone =====================
	local banner = Ui.glass(make("Frame", { Size = UDim2.new(0, 560, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70), Visible = false, ZIndex = 40, Parent = gui }, { Ui.pad(18, 12, 18, 14), Ui.list(4) }), 18, 0.25)
	local bTitle = text({ Text = "ANNOUNCEMENT", TextSize = 13, FontFace = Ui.BOLD, TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41, LayoutOrder = 1, Parent = banner })
	local bText = text({ Text = "", TextSize = 20, FontFace = Ui.BOLD, TextColor3 = Ui.TEXT, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41, LayoutOrder = 2, Parent = banner })
	local bFrom = text({ Text = "", TextSize = 12, TextColor3 = Ui.DIM, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41, LayoutOrder = 3, Parent = banner })
	local bannerT = 0
	function self.banner(title, body, from, color)
		bTitle.Text, bTitle.TextColor3 = title, color or Ui.GOLD
		bText.Text = body
		bFrom.Text = from and ("from " .. from) or ""
		banner.Visible = true
		bannerT = 7
		Ui.pop(banner, 1.12)
	end
	-- credits event pill ("×2 CREDITS · 12:34")
	local pill = Ui.glass(make("TextLabel", { Size = UDim2.new(0, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34), Text = "", TextSize = 14, FontFace = Ui.BOLD, TextColor3 = Ui.GOLD, Visible = false, ZIndex = 39, Parent = gui },
		{ Ui.pad(14, 0, 14, 0) }), 15, 0.3)
	RunService.RenderStepped:Connect(function(dt)
		if bannerT > 0 then
			bannerT -= dt
			if bannerT <= 0 then banner.Visible = false end
		end
		local untilT = ReplicatedStorage:GetAttribute("KaidoMultUntil") or 0
		local left = untilT - workspace:GetServerTimeNow()
		if left > 0 then
			pill.Visible = true
			pill.Text = string.format("×%d CREDITS EVENT  ·  %d:%02d", ReplicatedStorage:GetAttribute("KaidoMult") or 1, left // 60, math.floor(left % 60))
		else
			pill.Visible = false
		end
	end)
	R.Announce.OnClientEvent:Connect(function(message, from)
		self.banner("ANNOUNCEMENT", message, from, Ui.GOLD)
	end)
	-- commands the game owner sends to this player
	R.AdminEvent.OnClientEvent:Connect(function(cmd, a, b, c, d)
		if cmd == "tp" and type(a) == "number" then
			ctx.placeAt(a, b, c, d or 0)
			self.banner("TELEPORTED", "The game owner brought you to them", nil, Ui.NEON)
		elseif cmd == "send" then
			if a == "pass" then ctx.goPass() else ctx.goCity() end
			self.banner("TELEPORTED", "The game owner sent you to the " .. (a == "pass" and "Hakone pass" or "city"), nil, Ui.NEON)
		elseif cmd == "freeze" then
			U.frozen = a == true
			self.banner(a and "FROZEN" or "UNFROZEN", a and "The game owner froze your car" or "You can drive again", nil, a and Ui.DANGER or Ui.NEON)
		elseif cmd == "message" then
			self.banner("PRIVATE MESSAGE", tostring(a), b, Ui.VIOLET)
		end
	end)

	-- ===================== the panel =====================
	local root, col = Ui.sheet(gui, true)
	self.root = root
	Ui.heading("Admin", "管理", 1, col)
	local status = text({ Text = "Only you can see this. Everything here is checked by the server.", TextSize = 14, FontFace = Ui.BOLD, TextColor3 = Ui.DIM, LayoutOrder = 2, Parent = col })
	local tab = "players"
	local body = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = col }, { Ui.list(14) })
	local back = Ui.button("Back", nil, nil, 5, col)
	back.Activated:Connect(function() ctx.setMode(U.adminFrom or "title") end)
	local data = { players = {}, server = nil }
	local target = player.UserId
	local carPick = Config.Cars[1].id
	local render

	-- small pill buttons in wrapping rows
	local function row(parent, order)
		return make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }, {
			make("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	local KIND = { primary = { Ui.SAKURA, Ui.INK }, danger = { Ui.DANGER, Color3.new(1, 1, 1) }, good = { Ui.NEON, Ui.INK } }
	local function act(parent, label, kind, fn, confirm)
		local k = KIND[kind]
		local b = make("TextButton", { Size = UDim2.new(0, 0, 0, 38), AutomaticSize = Enum.AutomaticSize.X, Text = label, TextSize = 14, FontFace = Ui.BOLD,
			TextColor3 = k and k[2] or Ui.TEXT, AutoButtonColor = false, Parent = parent }, { Ui.pad(14, 0, 14, 0) })
		if k then
			b.BackgroundColor3 = k[1]; b.BackgroundTransparency = 0
			make("UICorner", { CornerRadius = UDim.new(0, 19), Parent = b })
		else
			Ui.glass(b, 19, 0.4)
		end
		Ui.bouncy(b)
		local armed = false
		b.Activated:Connect(function()
			if confirm and not armed then
				armed = true
				b.Text = "Tap again to confirm"
				task.delay(3, function() if armed then armed = false; b.Text = label end end)
				return
			end
			armed = false
			b.Text = label
			fn()
		end)
		return b
	end
	local function box(parent, placeholder, order, numeric)
		local t = make("TextBox", { Size = UDim2.new(1, 0, 0, 40), Text = "", PlaceholderText = placeholder, ClearTextOnFocus = false,
			TextColor3 = Ui.TEXT, PlaceholderColor3 = Ui.DIM, FontFace = Ui.BODY, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order or 0, Parent = parent }, { Ui.pad(12, 0, 12, 0) })
		Ui.glass(t, 12, 0.45)
		if numeric then t:GetPropertyChangedSignal("Text"):Connect(function() local c = t.Text:gsub("[^%d%-]", ""); if c ~= t.Text then t.Text = c end end) end
		return t
	end
	local function section(title, order)
		local f = Ui.field(title, order, body)
		return f
	end

	-- talk to the server
	local function run(action, value, noTarget, forId)
		status.Text, status.TextColor3 = "Working…", Ui.DIM
		local who = if noTarget then nil else (forId or target) -- fixed now, not when the request goes out
		task.spawn(function()
			local ok, res = pcall(function() return R.Admin:InvokeServer(action, who, value) end)
			if not ok or not res then status.Text, status.TextColor3 = "No answer from the server", Ui.DANGER; return end
			status.Text, status.TextColor3 = res.msg ~= "" and res.msg or "Ready", res.ok and Ui.NEON or Ui.DANGER
			Ui.pop(status, 1.08)
			if res.players then data.players = res.players end
			if res.server then data.server = res.server end
			if res.pos then ctx.placeAt(res.pos[1] + 14, res.pos[2] + 0.5, res.pos[3], res.pos[4]); ctx.setMode("play"); return end
			render()
		end)
	end
	self.refresh = function() run("list", nil, true) end

	local function clear() for _, c in body:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end end
	local function playerById(id) for _, p in data.players do if p.id == id then return p end end end
	local function hms(sec) sec = math.max(0, math.floor(sec)); return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60) end

	local tabs = { { "players", "Players" }, { "server", "Server" }, { "bans", "Bans" }, { "log", "Log" }, { "me", "Me" } }
	Ui.chips(tabs, tab, function(v) tab = v; render() end, 3, col)

	-- ===== Players =====
	local function renderPlayers()
		local f = section("Players in this server (" .. #data.players .. ")", 1)
		for k, p in data.players do
			local sel = p.id == target
			local r = make("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = k, Parent = f })
			Ui.glass(r, 12, sel and 0.15 or 0.5)
			if sel then Ui.stroke(Ui.SAKURA, 2, 0).Parent = r end
			Ui.bouncy(r)
			local tags = {}
			if p.id == player.UserId then table.insert(tags, "YOU") end
			if p.admin then table.insert(tags, "ADMIN") end
			if p.frozen then table.insert(tags, "FROZEN") end
			if p.muted then table.insert(tags, "MUTED") end
			if p.public then table.insert(tags, "PUBLIC MAP") end
			text({ Text = p.name, TextSize = 15, FontFace = Ui.BOLD, TextColor3 = sel and Ui.SAKURA or Ui.TEXT, AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -200, 0, 20), Position = UDim2.new(0, 14, 0, 4), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
			text({ Text = table.concat(tags, " · ") .. (#tags > 0 and "  ·  " or "") .. p.car .. "  ·  " .. p.ping .. " ms", TextSize = 11, TextColor3 = Ui.DIM, AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -200, 0, 16), Position = UDim2.new(0, 14, 0, 24), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
			text({ Text = fmt(p.credits) .. " CR", TextSize = 14, FontFace = Ui.BOLD, TextColor3 = Ui.GOLD, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 170, 1, 0),
				Position = UDim2.new(1, -184, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false, Parent = r })
			r.Activated:Connect(function() target = p.id; render() end)
		end
		local p = playerById(target)
		if not p then return end
		local who = p.name:match("^(.-) %(") or p.name

		local c = section("Credits · " .. who, 2)
		local amount = box(c, "Amount, e.g. 50000", 1, true)
		local r1 = row(c, 2)
		act(r1, "Give", "primary", function() run("credits", tonumber(amount.Text) or 0) end)
		act(r1, "Take", nil, function() run("credits", -(tonumber(amount.Text) or 0)) end)
		act(r1, "Set to this", nil, function() run("setCredits", tonumber(amount.Text) or 0) end)

		local cars = section("Cars · " .. who .. " is driving the " .. p.car, 3)
		local opts = {}
		for _, car in Config.Cars do table.insert(opts, { car.id, (car.premium and "★ " or "") .. car.name:gsub("^%S+ ", "") }) end
		Ui.chips(opts, carPick, function(v) carPick = v end, 1, cars)
		local r2 = row(cars, 2)
		act(r2, "Give this car", "primary", function() run("giveCar", carPick) end)
		act(r2, "Put them in it", nil, function() run("setCar", carPick) end)
		act(r2, "Take it away", nil, function() run("removeCar", carPick) end)
		act(r2, "Unlock all garage cars", nil, function() run("unlockAll") end)
		act(r2, "Max upgrades", "good", function() run("maxUpgrades") end)
		act(r2, "Reset upgrades", nil, function() run("resetUpgrades") end)

		local prog = section("Progress", 4)
		local best = box(prog, "Best drift score, e.g. 25000", 1, true)
		local r3 = row(prog, 2)
		act(r3, "Set best drift", nil, function() run("setBest", tonumber(best.Text) or 0) end)
		act(r3, "Complete today's challenges", "good", function() run("completeChallenges") end)
		act(r3, "Reset today's challenges", nil, function() run("resetChallenges") end)
		act(r3, "Remove from leaderboards", nil, function() run("removeFromBoards") end, true)
		act(r3, "Erase all progress", "danger", function() run("erase") end, true)

		local move = section("Move & watch", 5)
		local r4 = row(move, 1)
		act(r4, "Go to them", "primary", function() run("goto") end)
		act(r4, "Bring them here", nil, function() local x, y, z, h = ctx.getPos(); run("bring", { x, y, z, h }) end)
		act(r4, "Send to city", nil, function() run("send", "city") end)
		act(r4, "Send to pass", nil, function() run("send", "pass") end)
		act(r4, U.spectate == target and "Stop spectating" or "Spectate", nil, function()
			U.spectate = if U.spectate == target then nil else target
			if U.spectate then ctx.setMode("play"); status.Text = "Spectating · open the panel again to stop" end
			render()
		end)
		Ui.fine("Go to, bring and spectate need you both on the public map (Play with others).", 2, move)

		local ctl = section("Control", 6)
		local r5 = row(ctl, 1)
		act(r5, p.frozen and "Unfreeze" or "Freeze", p.frozen and "good" or nil, function() run("freeze", not p.frozen) end)
		act(r5, p.muted and "Unmute chat" or "Mute chat", p.muted and "good" or nil, function() run("mute", not p.muted) end)
		local pm = box(ctl, "Private message to " .. who, 2)
		local r6 = row(ctl, 3)
		act(r6, "Send private message", "primary", function() run("message", pm.Text); pm.Text = "" end)

		local pun = section("Punish", 7)
		local reason = box(pun, "Reason (shown to them)", 1)
		local r7 = row(pun, 2)
		act(r7, "Kick", "danger", function() run("kick", reason.Text) end, true)
		act(r7, "Ban 1 hour", "danger", function() run("ban", { reason.Text, 1 }) end, true)
		act(r7, "Ban 1 day", "danger", function() run("ban", { reason.Text, 24 }) end, true)
		act(r7, "Ban 7 days", "danger", function() run("ban", { reason.Text, 168 }) end, true)
		act(r7, "Ban forever", "danger", function() run("ban", { reason.Text, 0 }) end, true)
	end

	-- ===== Server =====
	local function renderServer()
		local s = data.server
		local info = section("This server", 1)
		if s then
			local ev = if s.multUntil > os.time() then string.format("×%d credits event, %s left", s.mult, hms(s.multUntil - os.time())) else "no credits event"
			Ui.fine(string.format("%d / %d players  ·  up %s  ·  %d MB  ·  %d FPS  ·  %s  ·  %s  ·  time: %s",
				s.players, s.maxPlayers, hms(s.uptime), s.memory, s.fps, s.locked and "LOCKED" or "open", ev,
				s.timeOverride and string.format("forced %02d:00", s.timeOverride) or "players' own"), 1, info)
		end
		act(row(info, 2), "Refresh", nil, function() run("list", nil, true) end)

		local an = section("Announcement to everyone", 2)
		local msg = box(an, "Message (filtered by Roblox, as its rules require)", 1)
		act(row(an, 2), "Send announcement", "primary", function() run("announce", msg.Text, true); msg.Text = "" end)

		local cr = section("Credits for everyone", 3)
		local amount = box(cr, "Amount, e.g. 10000", 1, true)
		local rA = row(cr, 2)
		act(rA, "Give everyone", "primary", function() run("giveAll", tonumber(amount.Text) or 0, true) end, true)
		local mult, mins = 2, 30
		Ui.chips({ { 2, "×2" }, { 3, "×3" }, { 5, "×5" }, { 10, "×10" } }, mult, function(v) mult = v end, 3, cr)
		Ui.chips({ { 10, "10 min" }, { 30, "30 min" }, { 60, "1 hour" }, { 180, "3 hours" } }, mins, function(v) mins = v end, 4, cr)
		local rB = row(cr, 5)
		act(rB, "Start credits event", "good", function() run("event", { mult, mins }, true) end)
		act(rB, "End event", nil, function() run("endEvent", nil, true) end)

		local w = section("World", 4)
		Ui.fine("Force the time of day for everyone:", 1, w)
		local rC = row(w, 2)
		for _, t in { { "Dawn", 5.75 }, { "Noon", 12.5 }, { "Sunset", 17.25 }, { "Midnight", 0 } } do
			act(rC, t[1], nil, function() run("time", t[2], true) end)
		end
		act(rC, "Everyone's own", "good", function() run("time", nil, true) end)
		local rD = row(w, 3)
		act(rD, "Everyone to city", nil, function() run("tpAll", "city", true) end, true)
		act(rD, "Everyone to pass", nil, function() run("tpAll", "pass", true) end, true)
		act(rD, "Freeze everyone", nil, function() run("freezeAll", true, true) end, true)
		act(rD, "Unfreeze everyone", "good", function() run("freezeAll", false, true) end)

		local dz = section("Danger zone", 5)
		local reason = box(dz, "Reason / message (optional)", 1)
		local rE = row(dz, 2)
		local locked = s and s.locked
		act(rE, locked and "Unlock server" or "Lock server (only admins can join)", locked and "good" or nil, function() run("lock", not locked, true) end)
		act(rE, "Kick everyone else", "danger", function() run("kickAll", reason.Text, true) end, true)
		act(rE, "Shut down server", "danger", function() run("shutdown", reason.Text, true) end, true)
	end

	-- ===== Bans =====
	local function renderBans()
		local s = data.server
		local f = section("Banned players", 1)
		if not s or #s.bans == 0 then Ui.fine("Nobody is banned.", 1, f) end
		for k, b in (s and s.bans or {}) do
			local r = row(f, k)
			local whenT = if b.untilTime > 0 then ("until " .. os.date("%d %b %H:%M", b.untilTime)) else "forever"
			text({ Text = string.format("%s  ·  %s  ·  %s  ·  by %s", b.name or "?", b.reason or "", whenT, b.by or "?"), TextSize = 13, TextColor3 = Ui.TEXT,
				AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false, LayoutOrder = 1, Parent = r })
			act(r, "Unban", "good", function() run("unban", b.id, true) end, true)
		end
		local add = section("Ban someone who isn't here (by user ID)", 2)
		local uid = box(add, "Roblox user ID (the number in their profile link)", 1, true)
		local reason = box(add, "Reason", 2)
		local r = row(add, 3)
		for _, d in { { "1 day", 24 }, { "7 days", 168 }, { "Forever", 0 } } do
			act(r, "Ban " .. d[1], "danger", function() run("banId", { tonumber(uid.Text), reason.Text, d[2] }, true) end, true)
		end
	end

	-- ===== Log =====
	local function renderLog()
		local f = section("What admins did in this server", 1)
		local lines = data.server and data.server.log or {}
		if #lines == 0 then Ui.fine("Nothing yet.", 1, f) end
		for k, line in lines do Ui.fine(line, k, f) end
		act(row(f, 999), "Refresh", nil, function() run("list", nil, true) end)
	end

	-- ===== Me =====
	local function renderMe()
		local f = section("Your own tools (only affect you)", 1)
		local r = row(f, 1)
		act(r, U.noclip and "Ghost mode: ON" or "Ghost mode: off", U.noclip and "good" or nil, function()
			U.noclip = not U.noclip; status.Text = U.noclip and "Ghost mode on: you drive through walls and barriers" or "Ghost mode off"; render()
		end)
		act(r, U.boost and "Speed boost: ON" or "Speed boost: off", U.boost and "good" or nil, function()
			U.boost = not U.boost; ctx.setBoost(U.boost); status.Text = U.boost and "Speed boost on: double power, more grip" or "Speed boost off"; render()
		end)
		if U.spectate then act(r, "Stop spectating", "primary", function() U.spectate = nil; render() end) end
		local r2 = row(f, 2)
		act(r2, "Go to city", nil, function() ctx.goCity(); ctx.setMode("play") end)
		act(r2, "Go to pass", nil, function() ctx.goPass(); ctx.setMode("play") end)
		act(r2, "Give me 1,000,000 CR", nil, function() run("credits", 1000000, false, player.UserId) end)
		act(r2, "Unlock everything for me", "good", function()
			run("unlockAll", nil, false, player.UserId)
			for _, c in Config.Premium do run("giveCar", c.id, false, player.UserId) end
		end)
		Ui.fine("Press F2 any time to open this panel.", 3, f)
	end

	render = function()
		clear()
		if tab == "players" then renderPlayers()
		elseif tab == "server" then renderServer()
		elseif tab == "bans" then renderBans()
		elseif tab == "log" then renderLog()
		else renderMe() end
	end
	render()
	return self
end

return AdminPanel
