-- Kaido Drift engine audio: three on-throttle layers (1,800 / 4,200 / 7,000 rpm) crossfaded and
-- pitched to the live rpm, an off-throttle layer with decel crackle, tyre screech, wind, a turbo
-- blow-off when you lift at high revs, and a stutter on the rev limiter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Audio = {}
Audio.__index = Audio

local NAMES = { "kaido_engine_low", "kaido_engine_mid", "kaido_engine_high", "kaido_engine_off", "kaido_skid", "kaido_blowoff", "kaido_wind" }
local LAYER_RPM = { 1800, 4200, 7000 }

-- find each sound: a Sound named after it anywhere players can see, or an ID in SoundIds
local ids = {}
local function scan()
	local pasted = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundIds"))
	for _, n in NAMES do
		if pasted[n] and pasted[n] ~= "" then ids[n] = pasted[n] end
	end
	for _, where in { workspace, ReplicatedStorage, SoundService } do
		for _, d in where:GetDescendants() do
			if d:IsA("Sound") and d.SoundId ~= "" then
				local key = string.lower(d.Name):gsub("%.ogg$", ""):gsub("%.mp3$", "")
				for _, n in NAMES do
					if key == n then ids[n] = d.SoundId end
				end
			end
		end
	end
end
scan()

function Audio.available(): boolean
	return ids.kaido_engine_mid ~= nil
end

-- how many of the 7 sound files this place has
function Audio.count(): number
	local n = 0
	for _, name in NAMES do if ids[name] then n += 1 end end
	return n
end

local function snd(parent, name, looped, spatial)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = ids[name] or ""
	s.Looped = looped
	s.Volume = 0
	if spatial then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance, s.RollOffMaxDistance = 20, 400
	end
	s.Parent = parent
	if s.SoundId ~= "" and looped then s:Play() end
	return s
end

-- own = the player's car (heard in stereo); others are positioned in the world
function Audio.new(carModel: Model, car, own: boolean)
	local self = setmetatable({}, Audio)
	local parent = own and SoundService or carModel.PrimaryPart
	self.layers = {}
	for k = 1, 3 do self.layers[k] = snd(parent, NAMES[k], true, not own) end
	self.off = snd(parent, "kaido_engine_off", true, not own)
	self.skid = snd(parent, "kaido_skid", true, not own)
	self.wind = own and snd(parent, "kaido_wind", true, false) or nil
	self.blow = snd(parent, "kaido_blowoff", false, not own)
	self.car = car
	self.load = 0
	self.lastThr = 0
	self.own = own
	self.t = 0
	return self
end

-- rpm, throttle (0..1), slide (0..1), speed in km/h, limiter on, master volume (0..1)
function Audio:update(dt: number, rpm: number, thr: number, slide: number, kmh: number, limiter: boolean, master: number)
	self.t += dt
	local car = self.car
	local pitch = car.pitch or 1
	-- engine load follows the throttle a little behind, like a real intake
	self.load += (thr - self.load) * math.min(1, dt * 8)
	local norm = rpm * (7000 / car.red) -- keep each engine's character across its rev range
	local chop = (limiter and (math.sin(self.t * 2 * math.pi * 16) > 0)) and 0.35 or 1
	local vol = (self.own and 0.9 or 0.7) * master * chop
	for k, s in self.layers do
		local c = LAYER_RPM[k]
		local w = math.clamp(1 - math.abs(math.log(norm / c) / math.log(2.1)), 0, 1)
		if k == 1 and norm < c then w = 1 end
		if k == 3 and norm > c then w = 1 end
		s.PlaybackSpeed = math.clamp(norm / c * pitch, 0.4, 2.2)
		s.Volume = vol * w * (0.25 + 0.75 * self.load)
	end
	self.off.PlaybackSpeed = math.clamp(norm / 3500 * pitch, 0.4, 2.2)
	self.off.Volume = vol * 0.8 * (1 - self.load) * math.clamp((norm - 1100) / 1200, 0.15, 1)
	-- tyres
	self.skid.Volume = master * 0.65 * math.clamp(slide, 0, 1) * math.clamp(kmh / 30, 0, 1)
	self.skid.PlaybackSpeed = 0.85 + 0.25 * math.clamp(slide, 0, 1)
	if self.wind then
		self.wind.Volume = master * 0.5 * math.clamp((kmh - 30) / 170, 0, 1)
		self.wind.PlaybackSpeed = 0.8 + kmh / 400
	end
	-- turbo blow-off on a sharp lift at high revs
	if car.turbo and self.lastThr > 0.7 and thr < 0.2 and rpm > car.red * 0.55 and self.blow.SoundId ~= "" then
		self.blow.Volume = master * 0.55
		self.blow.PlaybackSpeed = 0.9 + math.random() * 0.2
		self.blow:Play()
	end
	self.lastThr = thr
end

function Audio:mute()
	for _, s in self.layers do s.Volume = 0 end
	self.off.Volume, self.skid.Volume = 0, 0
	if self.wind then self.wind.Volume = 0 end
end

function Audio:destroy()
	for _, s in self.layers do s:Destroy() end
	self.off:Destroy(); self.skid:Destroy(); self.blow:Destroy()
	if self.wind then self.wind:Destroy() end
end

return Audio
