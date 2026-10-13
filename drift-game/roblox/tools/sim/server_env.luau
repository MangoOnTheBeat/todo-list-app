-- a saved profile for the test player, so purchases and cosmetics are exercised
local DSS = game:GetService("DataStoreService")
local SAVED = { credits = 200000, owned = { ps13 = true }, selected = "ps13", best = 0, laps = 0, total = 0,
	upg = { ps13 = { engine = 1 } }, cos = { ps13 = { glowOwned = true, glow = 2, rimsOwned = true, rims = 3, kit = true } }, paint = {}, settings = {} }
rawset(DSS, "GetDataStore", function() return { GetAsync = function() return SAVED end, SetAsync = function() end } end)
-- published game owned by user 77 (the test player); not running in Studio
rawset(game:GetService("RunService"), "IsStudio", function() return false end)
rawset(game, "CreatorType", Enum.CreatorType.User)
rawset(game, "CreatorId", 77)
