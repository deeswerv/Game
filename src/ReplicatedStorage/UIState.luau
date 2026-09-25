--!strict
-- Which panels currently have the screen.
--
-- `UIOpen` used to be a single boolean that six separate panels each assigned directly, so
-- the last writer won: closing the inventory while the shop was still up stamped "nothing
-- is open" over the top of the shop, and any panel that missed its close path left the flag
-- stuck TRUE forever.
--
-- Stuck true is not a cosmetic problem. ShiftLock reads this to decide whether the player is
-- in a menu, so it disables sprint and hands the cursor back -- with nothing on screen to
-- explain why. That is exactly how this was found: sprint appeared broken, every other
-- condition checked out, and the flag had simply been left on by a panel nobody could see.
--
-- Counting who is open, rather than assigning a shared boolean, makes the flag correct no
-- matter what order panels open and close in, and lets each one clear its own entry without
-- stamping on anybody else's.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local UIState = {}

local openPanels: { [string]: boolean } = {}

-- `panel` is just a name unique to the caller; it never reaches the server.
function UIState.SetOpen(panel: string, isOpen: boolean)
	if isOpen then
		openPanels[panel] = true
	else
		openPanels[panel] = nil
	end
	player:SetAttribute("UIOpen", next(openPanels) ~= nil)
end

function UIState.IsAnyOpen(): boolean
	return next(openPanels) ~= nil
end

-- An escape hatch for a panel that has been destroyed or reset mid-open.
function UIState.Clear(panel: string)
	UIState.SetOpen(panel, false)
end

return UIState
