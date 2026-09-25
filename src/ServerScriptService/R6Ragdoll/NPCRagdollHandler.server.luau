-- SERVICES --
local CS = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")

-- TAG --
local Tag = "NPC"

-- MODULE --
local RagdollModule = require(SSS.R6Ragdoll.RagdollBuilder)

-- FUNCTIONS --
for i, v in pairs(CS:GetTagged(Tag)) do
	if v:IsA("Model") then
		v:SetAttribute("Status",0)
		RagdollModule:Setup(v)
	end
end

-- EXTRA --
CS:GetInstanceAddedSignal(Tag):Connect(function(v)
	if v:IsA("Model") then
		v:SetAttribute("Status",0)
		RagdollModule:Setup(v)
	end
end)
