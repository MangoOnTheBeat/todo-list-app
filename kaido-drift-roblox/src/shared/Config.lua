--!strict
-- Tunables shared by server and client.
local Config = {}

Config.METERS_PER_STUD = 0.28
Config.STUDS_PER_M = 1 / 0.28
Config.KMH_PER_SPS = 0.28 * 3.6 -- km/h per stud/s (≈ 1.0)

-- Gravity for the whole place. 9.81 m/s² would be 35 studs/s²; a little extra makes the cars feel planted.
Config.GRAVITY = 52
-- studs/s² per m/s² for engine, brake and drag forces (same arcade boost as gravity so grip vs power stays realistic)
Config.ACC = Config.GRAVITY / 9.81

Config.WHEEL_RADIUS_M = 0.31

-- Drift scoring (matches the browser game)
Config.DRIFT_MIN_ANGLE = 10 -- degrees of slide before it counts
Config.DRIFT_MIN_KMH = 25
Config.DRIFT_END_IDLE = 1.4 -- seconds of not sliding before the drift banks
Config.DRIFT_MULT_STEP = 1.6 -- seconds held per +0.5 multiplier
Config.DRIFT_MULT_MAX = 5
Config.CREDITS_PER_POINT = 1 / 10
Config.DRIFT_MIN_BANK = 50
Config.TIERS = ({
	{ 0, "DRIFT" },
	{ 3000, "GREAT DRIFT" },
	{ 8000, "AWESOME DRIFT" },
	{ 15000, "INSANE DRIFT" },
	{ 30000, "UNBELIEVABLE DRIFT" },
} :: { { any } })

-- Audio. Paste a looping engine sample's asset id (Creator Store → Audio → search "engine loop"), e.g. "rbxassetid://1234567".
-- Empty = silent engine; everything else (pitch/volume following RPM) is already wired up.
Config.ENGINE_SOUND_ID = ""
Config.ENGINE_BASE_RPM = 3000 -- RPM at which the sample plays at its natural pitch
Config.SKID_SOUND_ID = ""

Config.SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

Config.DATASTORE_NAME = "KaidoDrift_v1"
Config.BEST_STORE_NAME = "KaidoDrift_Best_v1"
Config.START_CREDITS = 0

-- Colours (from the browser game's palette)
Config.COLORS = {
	ink = Color3.fromRGB(12, 13, 22),
	panel = Color3.fromRGB(21, 22, 38),
	text = Color3.fromRGB(243, 239, 231),
	dim = Color3.fromRGB(169, 166, 184),
	sakura = Color3.fromRGB(255, 126, 182),
	neon = Color3.fromRGB(89, 227, 255),
	gold = Color3.fromRGB(255, 201, 77),
	danger = Color3.fromRGB(255, 90, 90),
	lamp = Color3.fromRGB(255, 184, 110),
}

function Config.tierFor(score: number): string
	local name = Config.TIERS[1][2] :: string
	for _, t in Config.TIERS do
		if score >= (t[1] :: number) then
			name = t[2] :: string
		end
	end
	return name
end

return Config
