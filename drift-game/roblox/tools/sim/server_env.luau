-- a saved profile for the test player, so purchases and cosmetics are exercised
local DSS = game:GetService("DataStoreService")
local SAVED = { credits = 200000, owned = { ps13 = true }, selected = "ps13", best = 0, laps = 0, total = 0,
	upg = { ps13 = { engine = 1 } }, cos = { ps13 = { glowOwned = true, glow = 2, rimsOwned = true, rims = 3, kit = true } }, paint = {}, settings = {} }
-- one table per store, by key; profiles nobody saved yet read as the test player's profile
STORES = {}
rawset(DSS, "GetDataStore", function(_, name)
	local data = STORES[name] or {}
	STORES[name] = data
	local function get(k) if data[k] ~= nil then return data[k] end return if string.match(k, "^p_") then SAVED else nil end
	return {
		GetAsync = function(_, k) return get(k) end,
		SetAsync = function(_, k, v) data[k] = v end,
		UpdateAsync = function(_, k, fn) local v = fn(get(k)); if v ~= nil then data[k] = v end; return v end,
		RemoveAsync = function(_, k) data[k] = nil end,
	}
end)
-- published game owned by user 77 (the test player); not running in Studio
rawset(game:GetService("RunService"), "IsStudio", function() return false end)
rawset(game, "CreatorType", Enum.CreatorType.User)
rawset(game, "CreatorId", 77)
