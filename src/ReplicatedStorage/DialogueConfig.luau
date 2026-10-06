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

-- A tree: where it starts, and its nodes by id. A node is what the giver says (the first
-- line whose conditions are met) and what you can say back.
export type Line = { requires: { [string]: any }?, text: string }
export type Choice = { id: string, text: string, requires: { [string]: any }?, action: { kind: string, node: string? } }
export type Node = { body: { Line }, choices: { Choice } }
export type Tree = { entry: string, nodes: { [string]: Node } }

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
	-- The giver's next job waits on ZEE TOWER's boss.
	towerLocked = true,
}

DialogueConfig.Trees = ({
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
					{ requires = { towerLocked = true },
					  text = "The ferries past the Crossing are shut to anyone who hasn't dealt with ZEE TOWER. The Don runs this city from the top floor. Go Downtown, work your way up, and bring him down -- then we'll talk about the Flats." },
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
} :: { [string]: Tree })

-- Downtown's fixer. Standing here is Street Cred: the "Downtown" faction.
DialogueConfig.Trees.Fixer = ({
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
} :: Tree)

-- Hanami City's elder, at the shrine off the station square: the city's story, one step at a time.
DialogueConfig.Trees.Elder = ({
	entry = "root",
	nodes = {
		root = {
			body = {
				{ requires = { hasActive = true },
				  text = "{quest} -- {progress} of {goal}. The city is patient, but the clan is not. Go on." },
				{ requires = { hasOffer = true, completedAtLeast = 20 }, text = "You return, and the blossoms with you. @offer" },
				{ requires = { hasOffer = true }, text = "@offer" },
				{ requires = { minLevel = 14 },
				  text = "It is done, or it is waiting for you to grow. Either way: sit, rest, ring the bell at the shrine. The city owes you its spring." },
				{ text = "Not yet, child. The clan would eat you. Come back with a few more levels behind you." },
			},
			choices = {
				{ id = "accept",   text = "I'll do it.",                  requires = { hasOffer = true }, action = { kind = "AcceptQuest" } },
				{ id = "progress", text = "How far have I come?",         requires = { hasActive = true }, action = { kind = "Goto", node = "progress" } },
				{ id = "abandon",  text = "I must set this aside.",       requires = { hasActive = true }, action = { kind = "Goto", node = "confirmAbandon" } },
				{ id = "valley",   text = "What happened to this city?",  action = { kind = "Goto", node = "valley" } },
				{ id = "shogun",   text = "Who is the Shogun?",           action = { kind = "Goto", node = "shogun" } },
				{ id = "leave",    text = "Farewell.",                    action = { kind = "Close" } },
			},
		},
		progress = {
			body = {
				{ requires = { hasActive = true },
				  text = "{quest}. {objective} -- {progress} of {goal}. Pays {coins} coins and {xp} experience." },
				{ text = "You carry no task of mine." },
			},
			choices = {
				{ id = "back",  text = "Right.", action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Farewell.", action = { kind = "Close" } },
			},
		},

		confirmAbandon = {
			body = {
				{ requires = { hasActive = true }, text = "Set {quest} aside? What you have done of it will be lost." },
				{ text = "There is nothing to set aside." },
			},
			choices = {
				{ id = "confirm", text = "Set it aside.", requires = { hasActive = true }, action = { kind = "AbandonQuest" } },
				{ id = "back",    text = "No -- I'll see it through.", action = { kind = "Goto", node = "root" } },
			},
		},

		valley = {
			body = {
				{ text = "Hanami was a city of cherry trees and festivals, lanterns on every alley. Then the Don's crates came in on the night trains -- iron, powder, guns -- and the Kurogane clan came to collect them. Lantern Row is theirs now, the Steelworks run day and night, and the black castle on the hill takes a cut of everything we sell." },
			},
			choices = {
				{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Farewell.", action = { kind = "Close" } },
			},
		},

		shogun = {
			body = {
				{ requires = { minLevel = 12 },
				  text = "He was the city's guardian, sworn at this very shrine. The Don's iron made him strong and then made him iron. He waits in his court at the top of the Thousand Gates. When he is hurt, blossoms fall like blades -- and at the very end, he does not slow down." },
				{ text = "A name you are not ready to carry. Grow first." },
			},
			choices = {
				{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Farewell.", action = { kind = "Close" } },
			},
		},
	},
} :: Tree)

-- Captain Rei, at the red bridge: the city guard's bounties on the clan's specialists.
DialogueConfig.Trees.Captain = ({
	entry = "root",
	nodes = {
		root = {
			body = {
				{ requires = { hasActive = true },
				  text = "Still on {quest}: {progress} of {goal}. Get it done." },
				{ requires = { hasOffer = true }, text = "@offer" },
				{ text = "Nothing for you right now. The clan will give me something soon enough -- come back stronger." },
			},
			choices = {
				{ id = "accept",   text = "Consider it done.",            requires = { hasOffer = true }, action = { kind = "AcceptQuest" } },
				{ id = "progress", text = "Status?",                      requires = { hasActive = true }, action = { kind = "Goto", node = "progress" } },
				{ id = "abandon",  text = "I'm dropping this one.",       requires = { hasActive = true }, action = { kind = "Goto", node = "confirmAbandon" } },
				{ id = "clan",     text = "What should I know about the clan?", action = { kind = "Goto", node = "clan" } },
				{ id = "leave",    text = "Later.",                       action = { kind = "Close" } },
			},
		},
		progress = {
			body = {
				{ requires = { hasActive = true },
				  text = "{quest}. {objective} -- {progress} of {goal}. Pays {coins} coins and {xp} experience." },
				{ text = "You carry no task of mine." },
			},
			choices = {
				{ id = "back",  text = "Right.", action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Farewell.", action = { kind = "Close" } },
			},
		},

		confirmAbandon = {
			body = {
				{ requires = { hasActive = true }, text = "Set {quest} aside? What you have done of it will be lost." },
				{ text = "There is nothing to set aside." },
			},
			choices = {
				{ id = "confirm", text = "Set it aside.", requires = { hasActive = true }, action = { kind = "AbandonQuest" } },
				{ id = "back",    text = "No -- I'll see it through.", action = { kind = "Goto", node = "root" } },
			},
		},

		clan = {
			body = {
				{ text = "Ronin are swords for hire -- they run at you. Riflemen sit on roofs. Shieldbearers walk behind iron: break the shield or flank it. Shinobi dash at you from a distance -- step aside. Juggernauts are slow and armoured and never stop. And the Oni are the Shogun's own: grenades, good rifles, no mercy." },
			},
			choices = {
				{ id = "back",  text = "Back.",  action = { kind = "Goto", node = "root" } },
				{ id = "leave", text = "Later.", action = { kind = "Close" } },
			},
		},
	},
} :: Tree)

function DialogueConfig.Tree(giverId: string)
	return DialogueConfig.Trees[giverId]
end

return DialogueConfig
