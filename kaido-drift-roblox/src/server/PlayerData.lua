--!strict
-- Credits, owned cars, selected car and best drift, persisted with DataStoreService.
-- Falls back to session-only data (with a warning) when API access is off, e.g. an unpublished Studio place.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Kaido")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))

export type Profile = {
	credits: number,
	owned: { [string]: boolean },
	selected: string,
	best: number,
	total: number,
	easyDrift: boolean,
}

local PlayerData = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Kaido] DataStore unavailable, progress will not be saved this session:", result)
	end
end

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local function default(): Profile
	return {
		credits = Config.START_CREDITS,
		owned = { [Cars.DEFAULT] = true },
		selected = Cars.DEFAULT,
		best = 0,
		total = 0,
		easyDrift = true,
	}
end

local function sanitize(raw: any): Profile
	local p = default()
	if type(raw) ~= "table" then
		return p
	end
	if type(raw.credits) == "number" then
		p.credits = math.max(0, math.floor(raw.credits))
	end
	if type(raw.owned) == "table" then
		for id, v in raw.owned do
			if Cars.byId[id] and v == true then
				p.owned[id] = true
			end
		end
	end
	if type(raw.selected) == "string" and p.owned[raw.selected] then
		p.selected = raw.selected
	end
	if type(raw.best) == "number" then
		p.best = math.max(0, math.floor(raw.best))
	end
	if type(raw.total) == "number" then
		p.total = math.max(0, math.floor(raw.total))
	end
	if type(raw.easyDrift) == "boolean" then
		p.easyDrift = raw.easyDrift
	end
	return p
end

local function retry<T>(fn: () -> T): (boolean, T | string)
	local lastErr: any
	for attempt = 1, 3 do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(attempt)
	end
	return false, tostring(lastErr)
end

function PlayerData.load(player: Player): Profile
	local profile = default()
	local st = store
	if st then
		local ok, res = retry(function()
			return st:GetAsync("u" .. player.UserId)
		end)
		if ok then
			profile = sanitize(res)
		else
			warn("[Kaido] load failed for", player.Name, res)
		end
	end
	profiles[player] = profile
	loaded[player] = true
	return profile
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.markDirty(player: Player)
	dirty[player] = true
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	local st = store
	if not profile or not st or not loaded[player] then
		return
	end
	dirty[player] = nil
	local ok, err = retry(function()
		st:UpdateAsync("u" .. player.UserId, function()
			return profile
		end)
		return true
	end)
	if not ok then
		warn("[Kaido] save failed for", player.Name, err)
		dirty[player] = true
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
	loaded[player] = nil
	dirty[player] = nil
end

function PlayerData.saveAll()
	local threads = {}
	for player in profiles do
		table.insert(threads, task.spawn(PlayerData.save, player))
	end
	-- give the saves a few seconds to finish (BindToClose allows ~30s)
	local t = os.clock()
	while os.clock() - t < 8 do
		local busy = false
		for player in profiles do
			if dirty[player] then
				busy = true
			end
		end
		if not busy then
			break
		end
		task.wait(0.5)
	end
end

-- autosave
task.spawn(function()
	while true do
		task.wait(90)
		for player in profiles do
			if dirty[player] and player.Parent == Players then
				task.spawn(PlayerData.save, player)
			end
		end
	end
end)

return PlayerData
