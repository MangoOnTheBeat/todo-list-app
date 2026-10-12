-- Kaido Drift: if a server script fails while building the map, tell the players' loading screens why
-- (instead of loading forever).
local ScriptContext = game:GetService("ScriptContext")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ScriptContext.Error:Connect(function(message, trace)
	if ReplicatedStorage:GetAttribute("KaidoError") then return end
	ReplicatedStorage:SetAttribute("KaidoError", tostring(message) .. "\n" .. tostring(trace))
end)
