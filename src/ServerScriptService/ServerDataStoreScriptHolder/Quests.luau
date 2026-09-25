local Quest = {}

Quest.Quests = {
	["Prologue"] = {
		
	},
}

Quest.GetQuestInformation = function(QuestName, Information)
	if Quest.Quests[QuestName] then
		return Quest.Quests[QuestName][Information]
	end
end

return Quest
