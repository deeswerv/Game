local Items = {}

Items.Info = {
	["Basic Katana"] = {
		Damage = 7,
		Price = 100,
		Description = "A basic weapon made out of steel.",
		Icon = "rbxassetid://8231510683",
		Level = 5
	},
	
	["Golf Bat"] = {
		Damage = 14,
		Price = 1000,
		Description = "Simple, but powerful.",
		Icon = "rbxassetid://8231511661",
		Level = 10
	},
	
	["Shiva"] = {
		Damage = 25,
		Price = 100000,
		Description = "A godly weapon...",
		Icon = "rbxassetid://8231513138",
		Level = 20
	},
	
	["Winterthorn"] = {
		Damage = 55,
		Price = 1000000,
		Description = "A noble and sharp spear once used by a god...",
		Icon = "rbxassetid://8231508764",
		Level = 20
	},
}

Items.GetItemInfo = function(ItemName, Information)
	if Items.Info[ItemName] then
		return Items.Info[ItemName][Information]
	end
end

return Items
