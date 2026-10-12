--!strict
-- Best-drift leaderboards: in-server leaderstats (player list) plus a global top-10 board in the village.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))

local Leaderboard = {}

local ordered: OrderedDataStore? = nil
pcall(function()
	ordered = DataStoreService:GetOrderedDataStore(Config.BEST_STORE_NAME)
end)

local rows: { TextLabel } = {}
local pendingSubmit: { [number]: number } = {}

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
Leaderboard.fmt = fmt

function Leaderboard.setup(player: Player, best: number, credits: number)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local b = Instance.new("IntValue")
	b.Name = "Best Drift"
	b.Value = best
	b.Parent = stats
	local c = Instance.new("IntValue")
	c.Name = "Credits"
	c.Value = credits
	c.Parent = stats
	stats.Parent = player
end

function Leaderboard.update(player: Player, best: number, credits: number)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local b = stats:FindFirstChild("Best Drift") :: IntValue?
	local c = stats:FindFirstChild("Credits") :: IntValue?
	if b then
		b.Value = best
	end
	if c then
		c.Value = credits
	end
end

function Leaderboard.submit(player: Player, best: number)
	pendingSubmit[player.UserId] = best
end

local function buildBoard(boardPos: Vector3)
	local map = Workspace:WaitForChild("KaidoMap")
	local board = map:FindFirstChild("LeaderboardBoard", true) :: BasePart?
	if not board then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Config.COLORS.ink
	bg.BackgroundTransparency = 0.1
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.BackgroundTransparency = 1
	title.Text = "峠  BEST DRIFTS"
	title.TextColor3 = Config.COLORS.sakura
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = bg
	for i = 1, 10 do
		local r = Instance.new("TextLabel")
		r.Size = UDim2.new(0.9, 0, 0.075, 0)
		r.Position = UDim2.new(0.05, 0, 0.18 + (i - 1) * 0.08, 0)
		r.BackgroundTransparency = 1
		r.TextXAlignment = Enum.TextXAlignment.Left
		r.TextColor3 = if i == 1 then Config.COLORS.gold else Config.COLORS.text
		r.Font = Enum.Font.GothamBold
		r.TextScaled = true
		r.Text = ""
		r.Parent = bg
		rows[i] = r
	end
	local _ = boardPos
end

local function refresh()
	local entries: { { name: string, score: number } } = {}
	local ok = false
	local store = ordered
	if store then
		-- flush pending submissions first
		for userId, best in pendingSubmit do
			pcall(function()
				store:UpdateAsync(tostring(userId), function(old: number?)
					return math.max(old or 0, best)
				end)
			end)
			pendingSubmit[userId] = nil
		end
		local success, pages = pcall(function()
			return store:GetSortedAsync(false, 10)
		end)
		if success and pages then
			ok = true
			for _, item in pages:GetCurrentPage() do
				local id = tonumber(item.key) or 0
				local nameOk, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
				table.insert(entries, { name = if nameOk then name else ("#" .. item.key), score = item.value })
			end
		end
	end
	if not ok then
		-- session-only fallback: everyone in this server
		for _, p in Players:GetPlayers() do
			local stats = p:FindFirstChild("leaderstats")
			local b = stats and stats:FindFirstChild("Best Drift") :: IntValue?
			if b and b.Value > 0 then
				table.insert(entries, { name = p.DisplayName, score = b.Value })
			end
		end
		table.sort(entries, function(a, b)
			return a.score > b.score
		end)
	end
	for i, r in rows do
		local e = entries[i]
		r.Text = if e then string.format("%d.  %s   %s", i, e.name, fmt(e.score)) else ""
	end
end

function Leaderboard.start(boardPos: Vector3)
	buildBoard(boardPos)
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(60)
		end
	end)
end

function Leaderboard.flush(player: Player)
	local store = ordered
	local best = pendingSubmit[player.UserId]
	if store and best then
		pendingSubmit[player.UserId] = nil
		pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(old: number?)
				return math.max(old or 0, best)
			end)
		end)
	end
end

return Leaderboard
