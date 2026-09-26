--!strict
-- Dialogue trees.
--
-- Data only. Every `requires` here is a condition the SERVER evaluates against the real
-- profile: the client never evaluates one, is never sent a choice it cannot take, and a
-- choice coming back is re-checked against the node it claims to come from before it does
-- anything. Adding conversation is a table entry.
--
-- Body text may carry tokens the server fills in:
--   {quest} {objective} {goal} {progress} {coins} {xp} {completed} {total} {level}

local DialogueConfig = {}

-- Conditions understood by the resolver. Anything not listed is treated as unmet rather
-- than ignored, so a typo hides the line instead of silently always showing it.
DialogueConfig.Conditions = {
	minLevel = true,
	maxLevel = true,
	hasOffer = true,
	hasActive = true,
	completedAtLeast = true,
	-- Standing with a faction: { minRep = { faction = "Guard", value = 30 } }
	minRep = true,
	maxRep = true,
	-- Crystals, so the Quartermaster can offer to work them without a second screen.
	minCrystals = true,
}

DialogueConfig.Trees = {
	Quartermaster = {
		entry = "root",
		nodes = {

			root = {
				-- First variant whose requires are met wins, so order matters: the most
				-- specific state is listed first. Standing is checked BEFORE anything else,
				-- because a man who has been killing the guard has nothing else to discuss.
				body = {
					{ requires = { maxRep = { faction = "Guard", value = -50 } },
					  text = "You've got nerve showing your face here after what you've done to my people. Get out." },
					{ requires = { maxRep = { faction = "Guard", value = -15 } },
					  text = "I've heard about you. Say what you came to say and move along." },
					{ requires = { hasActive = true },
					  text = "Still carrying that job, are you. {quest} — {progress} of {goal} done. Don't come back light." },
					{ requires = { hasOffer = true, minRep = { faction = "Guard", value = 30 } },
					  text = "Good to see you. @offer" },
					{ requires = { hasOffer = true }, text = "@offer" },
					{ text = "Nothing for you right now. Come back when you've grown a little." },
				},
				choices = {
					-- Work dries up entirely once the town has turned on you.
					{ id = "accept",   text = "I'll take it.",          requires = { hasOffer = true, minRep = { faction = "Guard", value = -49 } },  action = { kind = "AcceptQuest" } },
					{ id = "standing", text = "What do people make of me?", action = { kind = "Goto", node = "standing" } },
					{ id = "craft",    text = "I've been pulling crystals out of the ground.", requires = { minCrystals = 1 }, action = { kind = "Goto", node = "crystals" } },
					{ id = "progress", text = "How am I doing?",        requires = { hasActive = true }, action = { kind = "Goto", node = "progress" } },
					{ id = "abandon",  text = "I'm dropping this one.", requires = { hasActive = true }, action = { kind = "Goto", node = "confirmAbandon" } },
					{ id = "record",   text = "How have I done so far?", requires = { completedAtLeast = 1 }, action = { kind = "Goto", node = "record" } },
					{ id = "about",    text = "What is this place?",     action = { kind = "Goto", node = "lore" } },
					{ id = "leave",    text = "Later.",                  action = { kind = "Close" } },
				},
			},

			progress = {
				body = {
					{ requires = { hasActive = true },
					  text = "{quest}. {objective} — {progress} of {goal}. Pays {coins} coins and {xp} experience when it's done." },
					{ text = "You're not carrying anything for me." },
				},
				choices = {
					{ id = "back",  text = "Right.",  action = { kind = "Goto", node = "root" } },
					{ id = "leave", text = "Later.",  action = { kind = "Close" } },
				},
			},

			confirmAbandon = {
				body = {
					{ requires = { hasActive = true },
					  text = "Walk away from {quest}? The progress goes with it. I'd want to be sure." },
					{ text = "There's nothing to walk away from." },
				},
				choices = {
					{ id = "confirm", text = "I'm sure. Drop it.", requires = { hasActive = true }, action = { kind = "AbandonQuest" } },
					{ id = "back",    text = "On second thought, no.", action = { kind = "Goto", node = "root" } },
				},
			},

			record = {
				body = {
					{ text = "You've closed {completed} of {total} jobs on my board. Level {level}. That's the measure of you around here." },
				},
				choices = {
					{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
					{ id = "leave", text = "Later.", action = { kind = "Close" } },
				},
			},

			crystals = {
				body = {
					{ requires = { minCrystals = 12 },
					  text = "Crystals, is it. Twelve of them and I'll work you something to wear -- whatever I can make of what you bring. You've got {crystals}." },
					{ text = "Crystals are worth something to me -- twelve buys a piece of work. You've only got {crystals}." },
				},
				choices = {
					{ id = "doCraft", text = "Do it. Twelve crystals.", requires = { minCrystals = 12 }, action = { kind = "CraftCosmetic" } },
					{ id = "back",    text = "Not yet.", action = { kind = "Goto", node = "root" } },
				},
			},

			standing = {
				body = {
					{ requires = { maxRep = { faction = "Guard", value = -50 } },
					  text = "Honestly? They'd cheer if you didn't come back. You've buried too many of ours for anything else." },
					{ requires = { maxRep = { faction = "Guard", value = -15 } },
					  text = "People are wary of you. There's talk, and none of it's kind." },
					{ requires = { minRep = { faction = "Guard", value = 75 } },
					  text = "They think well of you here. That's not nothing — this town doesn't hand that out." },
					{ requires = { minRep = { faction = "Guard", value = 30 } },
					  text = "You've been useful. People have noticed, and they remember." },
					{ text = "You're a stranger here, near enough. Nobody's decided about you yet." },
				},
				choices = {
					{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
					{ id = "leave", text = "Later.", action = { kind = "Close" } },
				},
			},

			lore = {
				body = {
					{ text = "The Harbour? Quiet, mostly. It's west you want to worry about — the Flats crawl with them, and they're meaner the further out you go." },
				},
				choices = {
					{ id = "who",   text = "Who are they?", action = { kind = "Goto", node = "loreWho" } },
					{ id = "back",  text = "Back.",         action = { kind = "Goto", node = "root" } },
					{ id = "leave", text = "Later.",        action = { kind = "Close" } },
				},
			},

			loreWho = {
				body = {
					{ requires = { minLevel = 5 },
					  text = "Bandits, mostly, and whatever the Flats have made of them. You've seen enough of it by now to know I'm not exaggerating." },
					{ text = "Bandits. Start with the ones near the water — the ones further out will take you apart." },
				},
				choices = {
					{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
					{ id = "leave", text = "Later.", action = { kind = "Close" } },
				},
			},
		},
	},
}

-- Downtown's fixer. Standing here is Street Cred: the "Downtown" faction.
DialogueConfig.Trees.Fixer = {
	entry = "root",
	nodes = {
		root = {
			body = {
				{ requires = { hasActive = true },
				  text = "You're on a job -- {quest}, {progress} of {goal}. Finish it, then we talk." },
				{ requires = { hasOffer = true, minRep = { faction = "Downtown", value = 75 } },
				  text = "Well, look who it is. The whole street knows your name. @offer" },
				{ requires = { hasOffer = true, minRep = { faction = "Downtown", value = 30 } },
				  text = "Good to see you around. @offer" },
				{ requires = { hasOffer = true }, text = "@offer" },
				{ requires = { minRep = { faction = "Downtown", value = 75 } },
				  text = "Nothing left I can ask of you. Downtown's quiet because of you -- for now." },
				{ text = "Nothing for you yet. Come back when you've got a few more levels on you." },
			},
			choices = {
				{ id = "accept",   text = "I'll take it.",               requires = { hasOffer = true }, action = { kind = "AcceptQuest" } },
				{ id = "progress", text = "How am I doing?",             requires = { hasActive = true }, action = { kind = "Goto", node = "progress" } },
				{ id = "abandon",  text = "I'm dropping this one.",      requires = { hasActive = true }, action = { kind = "Goto", node = "confirmAbandon" } },
				{ id = "cred",     text = "What's my name worth down here?", action = { kind = "Goto", node = "cred" } },
				{ id = "turf",     text = "How do the turf wars work?",  action = { kind = "Goto", node = "turf" } },
				{ id = "kingpin",  text = "Who runs these crews?",       action = { kind = "Goto", node = "kingpin" } },
				{ id = "leave",    text = "Later.",                      action = { kind = "Close" } },
			},
		},

		progress = {
			body = {
				{ requires = { hasActive = true },
				  text = "{quest}. {objective} -- {progress} of {goal}. Pays {coins} coins and {xp} experience." },
				{ text = "You're not carrying anything." },
			},
			choices = {
				{ id = "back",  text = "Right.", action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Later.", action = { kind = "Close" } },
			},
		},

		confirmAbandon = {
			body = {
				{ requires = { hasActive = true }, text = "Walk away from {quest}? The progress goes with it." },
				{ text = "There's nothing to walk away from." },
			},
			choices = {
				{ id = "confirm", text = "Drop it.", requires = { hasActive = true }, action = { kind = "AbandonQuest" } },
				{ id = "back",    text = "No -- I'll finish it.", action = { kind = "Goto", node = "root" } },
			},
		},

		cred = {
			body = {
				{ requires = { minRep = { faction = "Downtown", value = 75 } },
				  text = "Street Cred? You're a legend. Crews pay you a quarter more just to leave them be -- that's what winning a war earns you now." },
				{ requires = { minRep = { faction = "Downtown", value = 30 } },
				  text = "People know you. Win a war and the street tips you a tenth on top. Keep going -- legends get a quarter." },
				{ text = "Nobody knows you yet. Win turf wars, finish my jobs, take down the big one -- that's how a name gets made. A known name gets paid more." },
			},
			choices = {
				{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Later.", action = { kind = "Close" } },
			},
		},

		turf = {
			body = {
				{ text = "Four patches -- the car park, the courts, the alley, the park. Red ring means a crew's waiting: step in and they come. Win, and the patch goes quiet for a few minutes. Every win pushes the threat up and the next crew comes bigger -- and pays better." },
			},
			choices = {
				{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Later.", action = { kind = "Close" } },
			},
		},

		kingpin = {
			body = {
				{ requires = { minLevel = 12 },
				  text = "The Kingpin. Never seen without a hat. Push the threat all the way to five and win, and the Kingpin comes out to settle it -- with backup. Drop them and the crews scatter." },
				{ text = "Someone at the top keeps sending them. You're not ready to meet them. Get some levels first." },
			},
			choices = {
				{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Later.", action = { kind = "Close" } },
			},
		},
	},
}

function DialogueConfig.Tree(giverId: string)
	return DialogueConfig.Trees[giverId]
end

return DialogueConfig
